#!/bin/bash

# OpenFMB DER Monitoring Script

MQTT_HOST="${1:-localhost}"
MQTT_PORT="${2:-1883}"
DER_MRID="${3:-*}"

echo "Starting OpenFMB DER monitoring..."
echo "MQTT Broker: ${MQTT_HOST}:${MQTT_PORT}"
echo "DER MRID: ${DER_MRID}"
echo "Press Ctrl+C to stop"

# Subscribe to all OpenFMB topics for the DER
mosquitto_sub -h "${MQTT_HOST}" -p "${MQTT_PORT}" -t "openfmb/+profile/+/${DER_MRID}" -v
