#!/bin/bash
MQTT_HOST=${1:-localhost}; MQTT_PORT=${2:-1883}; MRID=$3; ACTION=$4; P=${5:-1000}
[ -z "$MRID" ] && echo "Usage: $0 host port <mrid> <charge|discharge|stop>" && exit 1
TS=$(date +%s)
case $ACTION in
  charge) VAL=$P ;;
  discharge) VAL=$((-P)) ;;
  stop|"") VAL=0 ;;
  *) echo "Invalid action"; exit 1 ;;
esac
mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" -t "openfmb/esscontrolprofile/$MRID" -m "{
 \"controlTimestamp\":{\"seconds\":$TS,\"nanos\":0},
 \"essControl\":{\"mRID\":\"$MRID\",\"essControlFSCC\":{\"controlFSCC\":{\"islandControlScheduleFSCH\":{\"ValDCSG\":[{\"crvPts\":[{\"startTime\":{\"seconds\":$TS,\"nanos\":0},\"yVal\":$VAL}]}]}}}}}"
echo "Sent $ACTION ($VAL W) to $MRID"