# OpenFMB DER Setup Scripts

This repository contains shell scripts to automatically set up OpenFMB (Open Field Message Bus) adapters with MQTT communication to connect to real Distributed Energy Resources (DER).

## Overview

The scripts provide automated configuration for:
- **MQTT Broker Setup**: Automatically starts Mosquitto MQTT broker
- **OpenFMB Adapter Configuration**: Generates proper YAML configurations
- **Modbus Integration**: Templates for connecting to real DER devices via Modbus TCP
- **Docker Orchestration**: Complete Docker Compose setup
- **Monitoring & Control**: Scripts for real-time monitoring and device control

## Supported DER Types

- **Solar PV Inverters**: SunSpec compliant solar inverters
- **Battery Energy Storage Systems (ESS)**: Battery management systems
- **Smart Switches/Breakers**: Controllable switching devices  
- **Load Controllers**: Demand response enabled loads
- **Smart Meters**: Advanced metering infrastructure

## Prerequisites

- Docker and Docker Compose installed
- Network access to DER devices
- DER devices with Modbus TCP capability
- macOS, Linux, or WSL2 on Windows

## Quick Start

### Option 1: Interactive Setup (Recommended)
```bash
./quick_setup.sh
```
This launches an interactive menu where you can select your DER type and enter device details.

### Option 2: Command Line Setup
```bash
# Solar PV Inverter example
./setup_openfmb_der.sh --type solar --ip 192.168.1.100 --port 502 --device-id 1

# Battery ESS example  
./setup_openfmb_der.sh --type ess --ip 192.168.1.101 --port 502 --device-id 1

# Smart Meter example
./setup_openfmb_der.sh --type meter --ip 192.168.1.102 --port 502 --device-id 1
```

## Script Options

### setup_openfmb_der.sh Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-t, --type` | DER type (solar\|ess\|switch\|load\|meter) | solar |
| `-i, --ip` | DER device IP address | 192.168.1.100 |
| `-p, --port` | DER device Modbus port | 502 |
| `-d, --device-id` | Modbus device/unit ID | 1 |
| `-m, --mrid` | Device MRID identifier | auto-generated UUID |
| `-b, --broker` | MQTT broker hostname | localhost |
| `-P, --broker-port` | MQTT broker port | 1883 |
| `-c, --client-id` | MQTT client identifier | openfmb-der-client |
| `-l, --log-level` | Log level (debug\|info\|warn\|error) | info |

### Environment Variables

| Variable | Description |
|----------|-------------|
| `MQTT_BROKER_HOST` | MQTT broker hostname |
| `MQTT_BROKER_PORT` | MQTT broker port |
| `MQTT_CLIENT_ID` | MQTT client identifier |
| `ADAPTER_LOG_LEVEL` | Adapter logging level |

## Generated Configuration

After running the setup script, the following files are created:

### Directory Structure
```
der_configs/
├── adapter-{type}.yaml           # Main OpenFMB adapter configuration
├── templates/
│   └── modbus-{type}-template.yaml  # Modbus device mapping template
├── docker-compose.yml            # Docker services configuration
├── logs/                         # Adapter log files
├── monitor_der.sh               # Real-time monitoring script
└── control_der.sh              # Device control script
```

### Key Configuration Files

1. **adapter-{type}.yaml**: Main OpenFMB adapter configuration with MQTT and Modbus settings
2. **modbus-{type}-template.yaml**: Device-specific Modbus register mappings
3. **docker-compose.yml**: Orchestrates MQTT broker, adapter, and HMI services

## Usage Examples

### Multi-Device Setup
```bash
# Set up solar inverter
./setup_openfmb_der.sh --type solar --ip 192.168.1.100 --device-id 1

# Set up battery in same network  
./setup_openfmb_der.sh --type ess --ip 192.168.1.101 --device-id 2

# Set up smart meter
./setup_openfmb_der.sh --type meter --ip 192.168.1.102 --device-id 3
```

### External MQTT Broker
```bash
./setup_openfmb_der.sh --type solar --ip 192.168.1.100 --broker mqtt.example.com --broker-port 1883
```

### Custom MRID
```bash
./setup_openfmb_der.sh --type ess --ip 192.168.1.101 --mrid "battery-bank-001"
```

### Debug Mode
```bash
ADAPTER_LOG_LEVEL=debug ./setup_openfmb_der.sh --type solar --ip 192.168.1.100
```

## Monitoring and Control

### Real-time Monitoring
```bash
# Monitor all devices
./der_configs/monitor_der.sh localhost 1883 "*"

# Monitor specific device
./der_configs/monitor_der.sh localhost 1883 "your-device-mrid"
```

### Device Control
```bash
# Start/enable device
./der_configs/control_der.sh localhost 1883 "device-mrid" start

# Stop/disable device  
./der_configs/control_der.sh localhost 1883 "device-mrid" stop

# Set power level (watts)
./der_configs/control_der.sh localhost 1883 "device-mrid" setpower 1500
```

### Web-based HMI
Access the Human-Machine Interface at: http://localhost:32771

## Docker Management

### View logs
```bash
cd der_configs
docker-compose logs -f
```

### Stop services
```bash
cd der_configs  
docker-compose down
```

### Restart services
```bash
cd der_configs
docker-compose restart
```

### View running containers
```bash
docker-compose ps
```

## MQTT Topic Structure

OpenFMB uses standardized MQTT topic patterns:

### Reading Profiles (Device → MQTT)
- `openfmb/readingprofile/SolarReadingProfile/{mRID}`
- `openfmb/readingprofile/ESSReadingProfile/{mRID}`  
- `openfmb/readingprofile/MeterReadingProfile/{mRID}`

### Status Profiles (Device → MQTT)
- `openfmb/statusprofile/SolarStatusProfile/{mRID}`
- `openfmb/statusprofile/ESSStatusProfile/{mRID}`

### Control Profiles (MQTT → Device)
- `openfmb/controlprofile/SolarControlProfile/{mRID}`
- `openfmb/discretecontrolprofile/SolarDiscreteControlProfile/{mRID}`

## Modbus Register Mapping

The scripts generate templates with common register mappings:

### Solar Inverter (SunSpec Model 1)
| Register | Parameter | Unit |
|----------|-----------|------|
| 40001-40002 | Active Power | W |
| 40003-40004 | Reactive Power | VAR |
| 40005-40006 | Voltage | V |
| 40007-40008 | Current | A |

### Battery ESS
| Register | Parameter | Unit |
|----------|-----------|------|
| 40001-40002 | Active Power | W |
| 40003-40004 | Reactive Power | VAR |
| 40005-40006 | Voltage | V |
| 40009-40010 | State of Charge | % |

**Note**: Adjust register addresses in the template files based on your specific device documentation.

## Customization

### Modifying Register Mappings
Edit the generated template files in `der_configs/templates/` to match your device's Modbus register map.

### Adding Custom Profiles
Extend the adapter configuration to include additional OpenFMB profiles as needed.

### Network Configuration  
Update IP addresses, ports, and device IDs in the configuration files for your network topology.

## Troubleshooting

### Common Issues

1. **Connection timeout to DER device**
   - Verify IP address and port
   - Check network connectivity: `ping <device_ip>`
   - Confirm device has Modbus TCP enabled

2. **MQTT connection failed**
   - Check broker status: `docker-compose ps`
   - Verify broker accessibility: `telnet localhost 1883`
   - Review adapter logs: `docker-compose logs openfmb-adapter`

3. **No data on MQTT topics**
   - Verify Modbus register mappings match device specs
   - Check device-specific Modbus settings (unit ID, byte order)
   - Enable debug logging: `ADAPTER_LOG_LEVEL=debug`

### Log Files
- Adapter logs: `der_configs/logs/adapter-{type}.log`
- Docker logs: `docker-compose logs`
- MQTT broker logs: Available in mosquitto container

## Security Considerations

For production deployments:

1. **Enable MQTT authentication**
2. **Use TLS encryption** 
3. **Configure firewall rules**
4. **Implement access control**
5. **Regular security updates**

## Support and Contribution

- OpenFMB Documentation: https://openfmb.org/
- Report issues via GitHub issues
- Contributions welcome via pull requests

## License

This project follows the same license as OpenFMB Adapters - see LICENSE file for details.
