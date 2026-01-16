# OpenFMB DER Framework

A minimal, production-ready OpenFMB (Open Field Message Bus) setup for connecting Distributed Energy Resources (DER) via MQTT and Modbus TCP.

## Directory Structure

```
openfmb-der/
├── README.md
├── scripts/
│   ├── setup_openfmb_der.sh     # Main setup script
│   ├── setup_der_clean.sh       # Auto-cleanup wrapper
│   ├── quick_setup.sh           # Interactive menu setup
│   └── cleanup_containers.sh    # Manual container cleanup
├── templates/
│   ├── modbus-solar-template.yaml
│   └── modbus-ess-template.yaml
└── docs/
    ├── DER_SETUP_README.md
    ├── CONTAINER_FIX.md
    └── NEXT_STEPS_GUIDE.md
```

## Quick Start

### Interactive Setup
```bash
cd scripts
./quick_setup.sh
```

### Command Line Setup
```bash
cd scripts

# Solar PV Inverter
./setup_der_clean.sh --type solar --ip 192.168.1.100 --port 502

# Battery ESS
./setup_der_clean.sh --type ess --ip 192.168.1.101 --port 502
```

## Prerequisites

- Docker & Docker Compose
- Network access to DER devices
- Modbus TCP enabled on DER devices

## Supported DER Types

| Type | Description |
|------|-------------|
| solar | Solar PV Inverters |
| ess | Battery Energy Storage |
| switch | Smart Breakers |
| load | Load Controllers |
| meter | Smart Meters |

## Services

- **MQTT Broker**: `mqtt://localhost:1883`
- **OpenFMB Adapter**: Connects to DER devices
- **HMI Interface**: `http://localhost:32771`

## Usage

```bash
# Monitor real-time data
./der_configs/monitor_der.sh localhost 1883 "*"

# View logs
cd der_configs && docker-compose logs -f

# Stop services
cd der_configs && docker-compose down
```

## Troubleshooting

**Container Conflicts:**
```bash
./cleanup_containers.sh
./setup_der_clean.sh --type solar --ip 192.168.1.100
```

**Connection Issues:**
- Verify DER device: `telnet 192.168.1.100 502`
- Check Modbus mappings in template files

## Documentation

- [DER Setup Guide](docs/DER_SETUP_README.md)
- [Container Fixes](docs/CONTAINER_FIX.md)
- [Next Steps](docs/NEXT_STEPS_GUIDE.md)
