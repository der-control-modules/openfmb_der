#!/bin/bash

# OpenFMB DER Quick Configuration Script
# This script provides quick setup options for common DER configurations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_SCRIPT="${SCRIPT_DIR}/setup_der_clean.sh"

function print_banner() {
    echo "=============================================="
    echo "OpenFMB DER Quick Setup"
    echo "=============================================="
    echo ""
}

function print_menu() {
    echo "Select DER configuration:"
    echo "1) Solar PV Inverter (SunSpec Modbus)"
    echo "2) Battery Energy Storage System (ESS)"
    echo "3) Smart Switch/Breaker"
    echo "4) Load Controller"
    echo "5) Smart Meter"
    echo "6) Custom Configuration"
    echo "7) View Example Commands"
    echo "8) Exit"
    echo ""
}

function setup_solar_pv() {
    echo "Setting up Solar PV Inverter..."
    echo ""
    read -p "Enter inverter IP address [192.168.1.100]: " ip
    ip=${ip:-192.168.1.100}
    
    read -p "Enter Modbus port [502]: " port
    port=${port:-502}
    
    read -p "Enter Modbus device ID [1]: " device_id
    device_id=${device_id:-1}
    
    read -p "Enter MQTT broker host [localhost]: " mqtt_host
    mqtt_host=${mqtt_host:-localhost}
    
    echo ""
    echo "Starting Solar PV setup..."
    "${SETUP_SCRIPT}" --type solar --ip "${ip}" --port "${port}" --device-id "${device_id}" --broker "${mqtt_host}"
}

function setup_ess() {
    echo "Setting up Battery Energy Storage System..."
    echo ""
    read -p "Enter ESS IP address [192.168.1.101]: " ip
    ip=${ip:-192.168.1.101}
    
    read -p "Enter Modbus port [502]: " port
    port=${port:-502}
    
    read -p "Enter Modbus device ID [1]: " device_id
    device_id=${device_id:-1}
    
    read -p "Enter MQTT broker host [localhost]: " mqtt_host
    mqtt_host=${mqtt_host:-localhost}
    
    echo ""
    echo "Starting ESS setup..."
    "${SETUP_SCRIPT}" --type ess --ip "${ip}" --port "${port}" --device-id "${device_id}" --broker "${mqtt_host}"
}

function setup_switch() {
    echo "Setting up Smart Switch/Breaker..."
    echo ""
    read -p "Enter switch IP address [192.168.1.102]: " ip
    ip=${ip:-192.168.1.102}
    
    read -p "Enter Modbus port [502]: " port
    port=${port:-502}
    
    read -p "Enter Modbus device ID [1]: " device_id
    device_id=${device_id:-1}
    
    read -p "Enter MQTT broker host [localhost]: " mqtt_host
    mqtt_host=${mqtt_host:-localhost}
    
    echo ""
    echo "Starting Switch setup..."
    "${SETUP_SCRIPT}" --type switch --ip "${ip}" --port "${port}" --device-id "${device_id}" --broker "${mqtt_host}"
}

function setup_load() {
    echo "Setting up Load Controller..."
    echo ""
    read -p "Enter load controller IP address [192.168.1.103]: " ip
    ip=${ip:-192.168.1.103}
    
    read -p "Enter Modbus port [502]: " port
    port=${port:-502}
    
    read -p "Enter Modbus device ID [1]: " device_id
    device_id=${device_id:-1}
    
    read -p "Enter MQTT broker host [localhost]: " mqtt_host
    mqtt_host=${mqtt_host:-localhost}
    
    echo ""
    echo "Starting Load Controller setup..."
    "${SETUP_SCRIPT}" --type load --ip "${ip}" --port "${port}" --device-id "${device_id}" --broker "${mqtt_host}"
}

function setup_meter() {
    echo "Setting up Smart Meter..."
    echo ""
    read -p "Enter meter IP address [192.168.1.104]: " ip
    ip=${ip:-192.168.1.104}
    
    read -p "Enter Modbus port [502]: " port
    port=${port:-502}
    
    read -p "Enter Modbus device ID [1]: " device_id
    device_id=${device_id:-1}
    
    read -p "Enter MQTT broker host [localhost]: " mqtt_host
    mqtt_host=${mqtt_host:-localhost}
    
    echo ""
    echo "Starting Smart Meter setup..."
    "${SETUP_SCRIPT}" --type meter --ip "${ip}" --port "${port}" --device-id "${device_id}" --broker "${mqtt_host}"
}

function custom_setup() {
    echo "Custom Configuration Setup..."
    echo ""
    echo "Available DER types: solar, ess, switch, load, meter"
    read -p "Enter DER type: " der_type
    
    read -p "Enter device IP address: " ip
    read -p "Enter Modbus port [502]: " port
    port=${port:-502}
    
    read -p "Enter Modbus device ID [1]: " device_id
    device_id=${device_id:-1}
    
    read -p "Enter device MRID (leave empty for auto-generation): " mrid
    
    read -p "Enter MQTT broker host [localhost]: " mqtt_host
    mqtt_host=${mqtt_host:-localhost}
    
    read -p "Enter MQTT broker port [1883]: " mqtt_port
    mqtt_port=${mqtt_port:-1883}
    
    read -p "Enter MQTT client ID [openfmb-der-client]: " client_id
    client_id=${client_id:-openfmb-der-client}
    
    echo ""
    echo "Starting custom setup..."
    
    cmd="${SETUP_SCRIPT} --type ${der_type} --ip ${ip} --port ${port} --device-id ${device_id} --broker ${mqtt_host} --broker-port ${mqtt_port} --client-id ${client_id}"
    
    if [ ! -z "${mrid}" ]; then
        cmd="${cmd} --mrid ${mrid}"
    fi
    
    eval "${cmd}"
}

function show_examples() {
    echo "Example Usage Commands:"
    echo ""
    echo "1. Solar PV with custom MQTT broker:"
    echo "   ./setup_openfmb_der.sh --type solar --ip 192.168.1.100 --broker mqtt.example.com --broker-port 1883"
    echo ""
    echo "2. Battery ESS with specific MRID:"
    echo "   ./setup_openfmb_der.sh --type ess --ip 192.168.1.101 --mrid 'battery-001'"
    echo ""
    echo "3. Multiple DER setup (run separately):"
    echo "   ./setup_openfmb_der.sh --type solar --ip 192.168.1.100 --device-id 1"
    echo "   ./setup_openfmb_der.sh --type ess --ip 192.168.1.101 --device-id 2"
    echo "   ./setup_openfmb_der.sh --type meter --ip 192.168.1.102 --device-id 3"
    echo ""
    echo "4. With external MQTT broker:"
    echo "   ./setup_openfmb_der.sh --type solar --ip 192.168.1.100 --broker 10.0.1.50 --broker-port 1883"
    echo ""
    echo "5. Debug mode with verbose logging:"
    echo "   ADAPTER_LOG_LEVEL=debug ./setup_openfmb_der.sh --type solar --ip 192.168.1.100"
    echo ""
    echo "Monitoring Commands:"
    echo "   # Monitor all messages"
    echo "   ./der_configs/monitor_der.sh localhost 1883 '*'"
    echo ""
    echo "   # Monitor specific device"
    echo "   ./der_configs/monitor_der.sh localhost 1883 'your-device-mrid'"
    echo ""
    echo "Control Commands:"
    echo "   # Start device"
    echo "   ./der_configs/control_der.sh localhost 1883 'your-device-mrid' start"
    echo ""
    echo "   # Set power level"
    echo "   ./der_configs/control_der.sh localhost 1883 'your-device-mrid' setpower 1000"
    echo ""
    echo "Docker Management:"
    echo "   # View logs"
    echo "   cd der_configs && docker-compose logs -f"
    echo ""
    echo "   # Stop services"
    echo "   cd der_configs && docker-compose down"
    echo ""
    echo "   # Restart services"
    echo "   cd der_configs && docker-compose restart"
    echo ""
}

function main() {
    print_banner
    
    if [ ! -f "${SETUP_SCRIPT}" ]; then
        echo "Error: Setup script not found at ${SETUP_SCRIPT}"
        exit 1
    fi
    
    while true; do
        print_menu
        read -p "Enter your choice [1-8]: " choice
        
        case $choice in
            1)
                setup_solar_pv
                break
                ;;
            2)
                setup_ess
                break
                ;;
            3)
                setup_switch
                break
                ;;
            4)
                setup_load
                break
                ;;
            5)
                setup_meter
                break
                ;;
            6)
                custom_setup
                break
                ;;
            7)
                show_examples
                echo ""
                read -p "Press Enter to continue..."
                continue
                ;;
            8)
                echo "Exiting..."
                exit 0
                ;;
            *)
                echo "Invalid choice. Please select 1-8."
                echo ""
                ;;
        esac
    done
}

main "$@"
