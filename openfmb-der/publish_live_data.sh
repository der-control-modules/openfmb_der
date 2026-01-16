#!/bin/bash
# Publish live DER data to MQTT for Grafana visualization

MQTT_HOST="localhost"
MQTT_PORT=1883
INTERVAL=3

echo "Publishing live DER data to MQTT every ${INTERVAL}s..."
echo "Press Ctrl+C to stop"
echo ""

i=0
while true; do
  TS=$(date +%s)
  
  # Generate realistic data
  solar_power=$((2000 + RANDOM % 1500))  # 2-3.5kW
  battery_soc=$((70 + (i % 20)))         # 70-90%
  battery_power=$((-1000 + RANDOM % 2000))  # -1kW to +1kW
  load_power=$((1500 + RANDOM % 1000))   # 1.5-2.5kW
  grid_power=$((solar_power - load_power + battery_power))
  
  # Publish Solar PV data
  mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" -t "openfmb/solarstatusprofile/solar-pv-001" -m "{
    \"controlTimestamp\":{\"seconds\":$TS,\"nanos\":0},
    \"solarInverter\":{
      \"mRID\":\"solar-pv-001\",
      \"solarReading\":{
        \"mmxu\":{
          \"w\":{\"mag\":$solar_power,\"unit\":\"W\"}
        }
      }
    }
  }"
  
  # Publish Battery ESS data
  mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" -t "openfmb/essstatusprofile/a6a7f5f4-2601-45d2-9445-ca147f32c783" -m "{
    \"controlTimestamp\":{\"seconds\":$TS,\"nanos\":0},
    \"essStatus\":{
      \"mRID\":\"a6a7f5f4-2601-45d2-9445-ca147f32c783\",
      \"essReading\":{
        \"mmxu\":{
          \"w\":{\"mag\":$battery_power,\"unit\":\"W\"}
        },
        \"soc\":{\"mag\":$battery_soc,\"unit\":\"percent\"}
      }
    }
  }"
  
  # Publish Grid Meter data
  mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" -t "openfmb/meterstatusprofile/grid-meter-001" -m "{
    \"controlTimestamp\":{\"seconds\":$TS,\"nanos\":0},
    \"meterReading\":{
      \"mRID\":\"grid-meter-001\",
      \"readingMMXU\":{
        \"w\":{\"mag\":$grid_power,\"unit\":\"W\"}
      }
    }
  }"
  
  # Publish Load data
  mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" -t "openfmb/loadstatusprofile/load-001" -m "{
    \"controlTimestamp\":{\"seconds\":$TS,\"nanos\":0},
    \"load\":{
      \"mRID\":\"load-001\",
      \"loadReading\":{
        \"mmxu\":{
          \"w\":{\"mag\":$load_power,\"unit\":\"W\"}
        }
      }
    }
  }"
  
  if (( i % 10 == 0 )); then
    echo "[$(date '+%H:%M:%S')] Solar:${solar_power}W | Battery:${battery_power}W (${battery_soc}%) | Load:${load_power}W | Grid:${grid_power}W"
  fi
  
  ((i++))
  sleep "$INTERVAL"
done
