#!/bin/bash

# OpenFMB DER Control Script

MQTT_HOST="${1:-localhost}"
MQTT_PORT="${2:-1883}"
DER_MRID="${3}"
COMMAND="${4}"
VALUE="${5}"

if [ -z "${DER_MRID}" ] || [ -z "${COMMAND}" ]; then
    echo "Usage: $0 <mqtt_host> <mqtt_port> <der_mrid> <command> [value]"
    echo "Commands: start, stop, setpower, reset"
    exit 1
fi

case "${COMMAND}" in
    "start")
        TOPIC="openfmb/discretecontrolprofile/SolarDiscreteControlProfile/${DER_MRID}"
        MESSAGE='{"conductingEquipment":{"mRID":"'${DER_MRID}'"},"solarDiscreteControl":{"solarDiscreteControlZGEN":{"discreteControlYPSH":{"controlValue":true}}}}'
        ;;
    "stop")
        TOPIC="openfmb/discretecontrolprofile/SolarDiscreteControlProfile/${DER_MRID}"
        MESSAGE='{"conductingEquipment":{"mRID":"'${DER_MRID}'"},"solarDiscreteControl":{"solarDiscreteControlZGEN":{"discreteControlYPSH":{"controlValue":false}}}}'
        ;;
    "setpower")
        if [ -z "${VALUE}" ]; then
            echo "Power value required for setpower command"
            exit 1
        fi
        TOPIC="openfmb/controlprofile/SolarControlProfile/${DER_MRID}"
        MESSAGE='{"conductingEquipment":{"mRID":"'${DER_MRID}'"},"solarControl":{"solarControlFSCC":{"controlFSCC":{"controlValue":'${VALUE}'}}}}'
        ;;
    *)
        echo "Unknown command: ${COMMAND}"
        exit 1
        ;;
esac

echo "Sending control command to ${DER_MRID}: ${COMMAND}"
mosquitto_pub -h "${MQTT_HOST}" -p "${MQTT_PORT}" -t "${TOPIC}" -m "${MESSAGE}"
