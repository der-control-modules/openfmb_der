#!/usr/bin/env bash
set -euo pipefail

# charge_discharge_scenario.sh
# Simulate matched solar generation and ESS charge/discharge sequence
# Publishes OpenFMB-style JSON to the MQTT broker so the MQTT->Influx bridge
# stores 'power' and 'soc' measurements. Uses host mosquitto_pub if present,
# otherwise falls back to docker exec openfmb-mosquitto.

usage(){
  cat <<EOF
Usage: $0 [options]

Options:
  -d DURATION    total run time in seconds (default: 60)
  -i INTERVAL    publish interval in seconds (default: 5)
  -s SOLAR_MRID  solar MRID (default: solar-1)
  -e ESS_MRID    ess MRID (default: ess-1)
  -c CAPACITY    ESS capacity in Wh (default: 10000)
  -a ALPHA       fraction of solar that ESS will absorb when charging (0..1) default 0.8
  -h             show this help

Example:
  $0 -d 120 -i 5 -s solar-1 -e ess-1 -c 10000 -a 0.75
EOF
}

duration=60
interval=5
solar_mrid="solar-1"
ess_mrid="ess-1"
capacity_wh=10000
alpha=0.8

while getopts ":d:i:s:e:c:a:h" opt; do
  case $opt in
    d) duration=$OPTARG ;;
    i) interval=$OPTARG ;;
    s) solar_mrid=$OPTARG ;;
    e) ess_mrid=$OPTARG ;;
    c) capacity_wh=$OPTARG ;;
    a) alpha=$OPTARG ;;
    h) usage; exit 0 ;;
    \?) echo "Invalid option: -$OPTARG" >&2; usage; exit 1 ;;
  esac
done

publish(){
  local topic=$1 json=$2
  if command -v mosquitto_pub >/dev/null 2>&1; then
    printf '%s' "$json" | mosquitto_pub -h localhost -p 1883 -t "$topic" -s
  elif docker ps --format '{{.Names}}' | grep -q '^openfmb-mosquitto$'; then
    printf '%s' "$json" | docker exec -i openfmb-mosquitto sh -c "mosquitto_pub -t '$topic' -s"
  else
    echo "No mosquitto_pub found and openfmb-mosquitto container not running" >&2
    return 1
  fi
}

echo "Starting charge/discharge scenario: duration=${duration}s interval=${interval}s"
start_ts=$(date +%s)
end_ts=$((start_ts + duration))

# starting SOC in percent
soc=50

step=0
while [ $(date +%s) -lt $end_ts ]; do
  now=$(date +%s)

  # Simple pattern: solar power varies between 0 and 3000 W (sinusoid-like)
  # Use step to create a repeating pattern
  phase=$(( step % 20 ))
  # map phase 0..19 to power 0..3000..0
  if [ $phase -lt 10 ]; then
    solar_power=$(( phase * 300 ))
  else
    solar_power=$(( (20-phase) * 300 ))
  fi

  # ESS will absorb a fraction of solar when generation positive (charging)
  # and discharge (negative power) when solar low to supply load (simulate)
  # We'll simulate a simple logic: when solar_power > 1000, ESS charges with -alpha*solar_power
  # when solar_power < 500, ESS discharges with +500 W
  if [ $solar_power -gt 1000 ]; then
    ess_power=$(awk -v sp=$solar_power -v a=$alpha 'BEGIN{printf("%d", -int(sp*a))}')
  else
    ess_power=500
  fi

  # Update SOC based on ess_power (positive = export from ESS -> reduces SOC, negative = charging -> increases SOC)
  # delta_soc_pct = - (ess_power in W) * interval_seconds / (capacity_wh) * 100
  delta_soc=$(awk -v p=$ess_power -v intv=$interval -v cap=$capacity_wh 'BEGIN{printf("%.6f", -p * intv / (cap) * 100)}')
  # apply delta
  soc=$(awk -v s=$soc -v d=$delta_soc 'BEGIN{printf("%.6f", s + d)}')
  # clamp 0..100
  soc=$(awk -v s=$soc 'BEGIN{if(s<0) s=0; if(s>100) s=100; printf("%d", int(s))}')

  # build JSON payloads
  solar_json=$(python3 - <<PY
import json, time
print(json.dumps({
  "controlTimestamp": {"seconds": $now, "nanos": 0},
  "solarInverter": {"mRID": "$solar_mrid", "solarReading": {"mmxu": {"w": {"mag": $solar_power, "unit": "W"}}}}
}))
PY
)

  ess_json=$(python3 - <<PY
import json, time
print(json.dumps({
  "controlTimestamp": {"seconds": $now, "nanos": 0},
  "essStatus": {"mRID": "$ess_mrid", "essReading": {"mmxu": {"w": {"mag": $ess_power, "unit": "W"}}, "soc": {"mag": $soc, "unit": "percent"}}}
}))
PY
)

  echo "[$(date +%H:%M:%S)] step=$step solar=${solar_power}W ess=${ess_power}W soc=${soc}%"

  publish "openfmb/solarstatusprofile/$solar_mrid" "$solar_json" || true
  publish "openfmb/essstatusprofile/$ess_mrid" "$ess_json" || true

  step=$((step+1))
  sleep $interval
done

echo "Scenario finished"
