#!/bin/bash

# OpenFMB DER Setup Script with MQTT
# This script sets up OpenFMB adapters to connect with real DER devices via MQTT

set -e

echo "=============================================="
echo "OpenFMB DER Setup Script with MQTT"
echo "=============================================="

# Configuration variables
OPENFMB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${OPENFMB_DIR}/der_configs"
MQTT_BROKER_HOST="${MQTT_BROKER_HOST:-localhost}"
MQTT_BROKER_PORT="${MQTT_BROKER_PORT:-1883}"
MQTT_CLIENT_ID="${MQTT_CLIENT_ID:-openfmb-der-client}"
ADAPTER_LOG_LEVEL="${ADAPTER_LOG_LEVEL:-info}"

# DER device configuration
DER_TYPE="${DER_TYPE:-solar}"  # Options: solar, ess, switch, load, meter
DER_IP="${DER_IP:-192.168.1.100}"
DER_PORT="${DER_PORT:-502}"
DER_DEVICE_ID="${DER_DEVICE_ID:-1}"
DER_MRID="${DER_MRID:-$(uuidgen | tr '[:upper:]' '[:lower:]')}"

function print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -t, --type TYPE        DER type (solar|ess|switch|load|meter) [default: solar]"
    echo "  -i, --ip IP           DER device IP address [default: 192.168.1.100]"
    echo "  -p, --port PORT       DER device port [default: 502]"
    echo "  -d, --device-id ID    DER device Modbus ID [default: 1]"
    echo "  -m, --mrid MRID       Device MRID [default: auto-generated UUID]"
    echo "  -b, --broker HOST     MQTT broker host [default: localhost]"
    echo "  -P, --broker-port PORT MQTT broker port [default: 1883]"
    echo "  -c, --client-id ID    MQTT client ID [default: openfmb-der-client]"
    echo "  -l, --log-level LEVEL Log level (debug|info|warn|error) [default: info]"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  MQTT_BROKER_HOST      MQTT broker hostname"
    echo "  MQTT_BROKER_PORT      MQTT broker port"
    echo "  MQTT_CLIENT_ID        MQTT client identifier"
    echo "  ADAPTER_LOG_LEVEL     Adapter logging level"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type)
            DER_TYPE="$2"
            shift 2
            ;;
        -i|--ip)
            DER_IP="$2"
            shift 2
            ;;
        -p|--port)
            DER_PORT="$2"
            shift 2
            ;;
        -d|--device-id)
            DER_DEVICE_ID="$2"
            shift 2
            ;;
        -m|--mrid)
            DER_MRID="$2"
            shift 2
            ;;
        -b|--broker)
            MQTT_BROKER_HOST="$2"
            shift 2
            ;;
        -P|--broker-port)
            MQTT_BROKER_PORT="$2"
            shift 2
            ;;
        -c|--client-id)
            MQTT_CLIENT_ID="$2"
            shift 2
            ;;
        -l|--log-level)
            ADAPTER_LOG_LEVEL="$2"
            shift 2
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

function check_dependencies() {
    echo "Checking dependencies..."
    
    # Check if Docker is installed and running
    if ! command -v docker &> /dev/null; then
        echo "Error: Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        echo "Error: Docker daemon is not running. Please start Docker."
        exit 1
    fi
    
    # Check if mosquitto (MQTT broker) is available
    if ! command -v mosquitto &> /dev/null; then
        echo "Warning: Mosquitto MQTT broker not found locally. Will use Docker container."
    fi
    
    echo "Dependencies check completed."
}

function setup_directories() {
    echo "Setting up directory structure..."
    
    mkdir -p "${CONFIG_DIR}"
    mkdir -p "${CONFIG_DIR}/logs"
    mkdir -p "${CONFIG_DIR}/templates"
    
    echo "Directory structure created."
}

function start_mqtt_broker() {
    echo "MQTT broker will be started by Docker Compose..."
    return 0
}
function generate_main_config() {
    echo "Generating main adapter configuration..."
    
    local config_file="${CONFIG_DIR}/adapter-${DER_TYPE}.yaml"
    
    cat > "${config_file}" << EOF
---
file:
  id: openfmb-adapter-${DER_TYPE}
  edition: "2.1"
  version: "1.0.0"
  plugin: ""

logging:
  logger-name: "openfmb-${DER_TYPE}-adapter"
  console:
    enabled: true
  rotating-file:
    enabled: true
    path: "${CONFIG_DIR}/logs/adapter-${DER_TYPE}.log"
    max-size: 10485760  # 10MB
    max-files: 5

plugins:
  modbus-master:
    enabled: true
    thread-pool-size: 2
    sessions:
      - path: "${CONFIG_DIR}/templates/modbus-${DER_TYPE}-template.yaml"
        overrides: []

  mqtt:
    enabled: true
    max-queued-messages: 1000
    server-address: "tcp://${MQTT_BROKER_HOST}:${MQTT_BROKER_PORT}"
    client-id: "${MQTT_CLIENT_ID}-${DER_TYPE}"
    connect-retry-delay-ms: 5000
    security:
      security-type: none
    publish:
EOF

    # Add profile-specific publish configurations
    case "${DER_TYPE}" in
        "solar")
            cat >> "${config_file}" << EOF
      - profile: SolarReadingProfile
        topic-suffix: "${DER_MRID}"
      - profile: SolarStatusProfile
        topic-suffix: "${DER_MRID}"
EOF
            ;;
        "ess")
            cat >> "${config_file}" << EOF
      - profile: ESSReadingProfile
        topic-suffix: "${DER_MRID}"
      - profile: ESSStatusProfile
        topic-suffix: "${DER_MRID}"
EOF
            ;;
        "switch")
            cat >> "${config_file}" << EOF
      - profile: SwitchReadingProfile
        topic-suffix: "${DER_MRID}"
      - profile: SwitchStatusProfile
        topic-suffix: "${DER_MRID}"
EOF
            ;;
        "load")
            cat >> "${config_file}" << EOF
      - profile: LoadReadingProfile
        topic-suffix: "${DER_MRID}"
      - profile: LoadStatusProfile
        topic-suffix: "${DER_MRID}"
EOF
            ;;
        "meter")
            cat >> "${config_file}" << EOF
      - profile: MeterReadingProfile
        topic-suffix: "${DER_MRID}"
EOF
            ;;
    esac

    cat >> "${config_file}" << EOF
    subscribe:
EOF

    # Add profile-specific subscribe configurations for control
    case "${DER_TYPE}" in
        "solar")
            cat >> "${config_file}" << EOF
      - profile: SolarDiscreteControlProfile
        topic-suffix: "${DER_MRID}"
      - profile: SolarControlProfile
        topic-suffix: "${DER_MRID}"
EOF
            ;;
        "ess")
            cat >> "${config_file}" << EOF
      - profile: ESSDiscreteControlProfile
        topic-suffix: "${DER_MRID}"
      - profile: ESSControlProfile
        topic-suffix: "${DER_MRID}"
EOF
            ;;
        "switch")
            cat >> "${config_file}" << EOF
      - profile: SwitchDiscreteControlProfile
        topic-suffix: "${DER_MRID}"
EOF
            ;;
        "load")
            cat >> "${config_file}" << EOF
      - profile: LoadControlProfile
        topic-suffix: "${DER_MRID}"
EOF
            ;;
    esac

    # Disable other plugins
    cat >> "${config_file}" << EOF

  # Disabled plugins
  capture:
    enabled: false
  replay:
    enabled: false
  dnp3-master:
    enabled: false
  dnp3-outstation:
    enabled: false
  modbus-outstation:
    enabled: false
  nats:
    enabled: false
  timescaledb:
    enabled: false
  log:
    enabled: false
EOF

    echo "Main configuration generated: ${config_file}"
}

function generate_modbus_template() {
    echo "Generating Modbus template for ${DER_TYPE}..."
    
    local template_file="${CONFIG_DIR}/templates/modbus-${DER_TYPE}-template.yaml"
    
    cat > "${template_file}" << EOF
---
file:
  id: modbus-${DER_TYPE}-template
  edition: "2.1"
  version: "1.0.0"
  plugin: "modbus-master"

master:
  channel:
    type: tcp-client
    tcp-client:
      adapter: "${DER_IP}"
      port: ${DER_PORT}
      connect-timeout-ms: 5000
  
  session:
    response-timeout-ms: 5000
    max-read-request-size: 100
    device-map:
      - unit-identifier: ${DER_DEVICE_ID}
        profiles:
EOF

    case "${DER_TYPE}" in
        "solar")
            cat >> "${template_file}" << EOF
          - name: SolarReadingProfile
            mRID: "${DER_MRID}"
            mapping:
              - name: "SolarInverter"
                type: "SolarInverter"
                conducting-equipment:
                  mRID: "${DER_MRID}"
                  name: "Solar Inverter ${DER_DEVICE_ID}"
                  description: "Solar inverter connected via Modbus"
                reading-data:
                  - name: "ActivePower"
                    register-type: holding
                    address: 40001
                    register-count: 2
                    data-type: float32
                    scale: 1.0
                    unit: "W"
                    profile-mapping: "solarReading.readingMMXU.W.net.cVal.mag.f.value"
                  - name: "ReactivePower"
                    register-type: holding
                    address: 40003
                    register-count: 2
                    data-type: float32
                    scale: 1.0
                    unit: "VAR"
                    profile-mapping: "solarReading.readingMMXU.VAr.net.cVal.mag.f.value"
                  - name: "Voltage"
                    register-type: holding
                    address: 40005
                    register-count: 2
                    data-type: float32
                    scale: 1.0
                    unit: "V"
                    profile-mapping: "solarReading.readingMMXU.PhV.phsA.cVal.mag.f.value"
                  - name: "Current"
                    register-type: holding
                    address: 40007
                    register-count: 2
                    data-type: float32
                    scale: 1.0
                    unit: "A"
                    profile-mapping: "solarReading.readingMMXU.A.phsA.cVal.mag.f.value"
          - name: SolarStatusProfile
            mRID: "${DER_MRID}"
            mapping:
              - name: "SolarInverter"
                type: "SolarInverter"
                conducting-equipment:
                  mRID: "${DER_MRID}"
                  name: "Solar Inverter ${DER_DEVICE_ID}"
                status-data:
                  - name: "InverterStatus"
                    register-type: discrete-input
                    address: 10001
                    register-count: 1
                    data-type: bool
                    profile-mapping: "solarStatus.solarStatusZGEN.SolarStatusZGEN.DynamicTest.stVal"
EOF
            ;;
        "ess")
            cat >> "${template_file}" << EOF
          - name: ESSReadingProfile
            mRID: "${DER_MRID}"
            mapping:
              - name: "BatterySystem"
                type: "BatterySystem"
                conducting-equipment:
                  mRID: "${DER_MRID}"
                  name: "Battery System ${DER_DEVICE_ID}"
                  description: "Battery Energy Storage System"
                reading-data:
                  - name: "ActivePower"
                    register-type: holding
                    address: 40001
                    register-count: 2
                    data-type: float32
                    scale: 1.0
                    unit: "W"
                    profile-mapping: "essReading.readingMMXU.W.net.cVal.mag.f.value"
                  - name: "StateOfCharge"
                    register-type: holding
                    address: 40009
                    register-count: 2
                    data-type: float32
                    scale: 1.0
                    unit: "%"
                    profile-mapping: "essReading.readingMMTR.SOC.mag.f.value"
                  - name: "Voltage"
                    register-type: holding
                    address: 40005
                    register-count: 2
                    data-type: float32
                    scale: 1.0
                    unit: "V"
                    profile-mapping: "essReading.readingMMXU.PhV.phsA.cVal.mag.f.value"
EOF
            ;;
        "meter")
            cat >> "${template_file}" << EOF
          - name: MeterReadingProfile
            mRID: "${DER_MRID}"
            mapping:
              - name: "ElectricMeter"
                type: "Meter"
                conducting-equipment:
                  mRID: "${DER_MRID}"
                  name: "Electric Meter ${DER_DEVICE_ID}"
                reading-data:
                  - name: "ActivePower"
                    register-type: holding
                    address: 40001
                    register-count: 2
                    data-type: float32
                    scale: 1.0
                    unit: "W"
                    profile-mapping: "meterReading.readingMMXU.W.net.cVal.mag.f.value"
                  - name: "EnergyDelivered"
                    register-type: holding
                    address: 40011
                    register-count: 2
                    data-type: float32
                    scale: 1.0
                    unit: "Wh"
                    profile-mapping: "meterReading.readingMMTR.TotWh.actVal"
                  - name: "Voltage"
                    register-type: holding
                    address: 40005
                    register-count: 2
                    data-type: float32
                    scale: 1.0
                    unit: "V"
                    profile-mapping: "meterReading.readingMMXU.PhV.phsA.cVal.mag.f.value"
EOF
            ;;
    esac

    echo "Modbus template generated: ${template_file}"
}

function generate_docker_compose() {
    echo "Generating Docker Compose configuration..."
    
    local compose_file="${CONFIG_DIR}/docker-compose.yml"
    
    cat > "${compose_file}" << EOF
version: "3.9"

services:
  mosquitto:
    image: eclipse-mosquitto:latest
    container_name: openfmb-mosquitto
    restart: unless-stopped
    ports:
      - "${MQTT_BROKER_PORT}:1883"
      - "9001:9001"
    volumes:
      - mosquitto_data:/mosquitto/data
      - mosquitto_logs:/mosquitto/log

  openfmb-adapter:
    image: oesinc/openfmb.adapters:latest
    container_name: openfmb-${DER_TYPE}-adapter
    restart: unless-stopped
    depends_on:
      - mosquitto
    volumes:
      - ${CONFIG_DIR}:/cfg
    command: -c /cfg/adapter-${DER_TYPE}.yaml
    environment:
      - OPENFMB_LOG_LEVEL=${ADAPTER_LOG_LEVEL}
    networks:
      - openfmb

  # Optional: HMI for monitoring
  openfmb-hmi:
    image: oesinc/openfmb.hmi:latest
    container_name: openfmb-hmi
    restart: unless-stopped
    depends_on:
      - mosquitto
    ports:
      - "32771:32771"
    environment:
      - MQTT_BROKER_HOST=mosquitto
      - MQTT_BROKER_PORT=1883
    networks:
      - openfmb

volumes:
  mosquitto_data:
  mosquitto_logs:

networks:
  openfmb:
    driver: bridge
EOF

    echo "Docker Compose configuration generated: ${compose_file}"
}

function generate_monitoring_script() {
    echo "Generating monitoring script..."
    
    local monitor_script="${CONFIG_DIR}/monitor_der.sh"
    
    cat > "${monitor_script}" << 'EOF'
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
EOF

    chmod +x "${monitor_script}"
    echo "Monitoring script generated: ${monitor_script}"
}

function generate_control_script() {
    echo "Generating control script..."
    
    local control_script="${CONFIG_DIR}/control_der.sh"
    
    cat > "${control_script}" << 'EOF'
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
EOF

    chmod +x "${control_script}"
    echo "Control script generated: ${control_script}"
}

function start_services() {
    echo "Starting OpenFMB services..."
    
    cd "${CONFIG_DIR}"
    
    # Start services using Docker Compose
    docker-compose up -d
    
    echo "Services started. Checking status..."
    sleep 5
    docker-compose ps
    
    echo ""
    echo "Service URLs:"
    echo "  MQTT Broker: mqtt://${MQTT_BROKER_HOST}:${MQTT_BROKER_PORT}"
    echo "  HMI Interface: http://localhost:32771"
    echo ""
}

function print_summary() {
    echo ""
    echo "=============================================="
    echo "OpenFMB DER Setup Complete!"
    echo "=============================================="
    echo ""
    echo "Configuration Summary:"
    echo "  DER Type: ${DER_TYPE}"
    echo "  DER IP: ${DER_IP}:${DER_PORT}"
    echo "  Device ID: ${DER_DEVICE_ID}"
    echo "  MRID: ${DER_MRID}"
    echo "  MQTT Broker: ${MQTT_BROKER_HOST}:${MQTT_BROKER_PORT}"
    echo "  Client ID: ${MQTT_CLIENT_ID}-${DER_TYPE}"
    echo ""
    echo "Generated Files:"
    echo "  Main Config: ${CONFIG_DIR}/adapter-${DER_TYPE}.yaml"
    echo "  Modbus Template: ${CONFIG_DIR}/templates/modbus-${DER_TYPE}-template.yaml"
    echo "  Docker Compose: ${CONFIG_DIR}/docker-compose.yml"
    echo "  Monitor Script: ${CONFIG_DIR}/monitor_der.sh"
    echo "  Control Script: ${CONFIG_DIR}/control_der.sh"
    echo ""
    echo "Usage Examples:"
    echo "  Monitor DER: ${CONFIG_DIR}/monitor_der.sh ${MQTT_BROKER_HOST} ${MQTT_BROKER_PORT} ${DER_MRID}"
    echo "  Control DER: ${CONFIG_DIR}/control_der.sh ${MQTT_BROKER_HOST} ${MQTT_BROKER_PORT} ${DER_MRID} start"
    echo "  Stop Services: cd ${CONFIG_DIR} && docker-compose down"
    echo "  View Logs: cd ${CONFIG_DIR} && docker-compose logs -f"
    echo ""
    echo "Next Steps:"
    echo "1. Verify your DER device is accessible at ${DER_IP}:${DER_PORT}"
    echo "2. Adjust Modbus register mappings in the template file if needed"
    echo "3. Monitor the logs for connection status"
    echo "4. Use the HMI at http://localhost:32771 to visualize data"
    echo ""
}

# Main execution
main() {
    echo "Starting OpenFMB DER setup with the following configuration:"
    echo "  DER Type: ${DER_TYPE}"
    echo "  DER IP: ${DER_IP}:${DER_PORT}"
    echo "  Device ID: ${DER_DEVICE_ID}"
    echo "  MRID: ${DER_MRID}"
    echo "  MQTT Broker: ${MQTT_BROKER_HOST}:${MQTT_BROKER_PORT}"
    echo ""
    
    check_dependencies
    setup_directories
    start_mqtt_broker
    generate_main_config
    generate_modbus_template
    generate_docker_compose
    generate_monitoring_script
    generate_control_script
    start_services
    print_summary
}

# Run main function
main "$@"
