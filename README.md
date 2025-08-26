# OpenFMB DER Framework - Minimal Setup

This is a minimal, production-ready OpenFMB (Open Field Message Bus) setup for connecting Distributed Energy Resources (DER) via MQTT and Modbus TCP.

## 📁 Directory Structure

```
openfmb-der-minimal/
├── README.md                    # This file
├── scripts/                     # All executable scripts
│   ├── setup_openfmb_der.sh    # Main setup script
│   ├── setup_der_clean.sh      # Auto-cleanup wrapper (RECOMMENDED)
│   ├── quick_setup.sh          # Interactive menu setup
│   └── cleanup_containers.sh   # Manual container cleanup
├── templates/                   # Modbus device templates
│   ├── modbus-solar-template.yaml
│   ├── modbus-ess-template.yaml
│   └── modbus-*.yaml           # Generated during setup
└── docs/                       # Documentation
    ├── DER_SETUP_README.md     # Detailed setup guide
    ├── CONTAINER_FIX.md        # Container conflict resolution
    └── NEXT_STEPS_GUIDE.md     # Post-setup verification
```

## 🚀 Quick Start (30 seconds)

### Option 1: Interactive Setup (Recommended)
```bash
cd openfmb-der-minimal/scripts
./quick_setup.sh
```

### Option 2: Command Line Setup
```bash
cd openfmb-der-minimal/scripts

# Solar PV Inverter
./setup_der_clean.sh --type solar --ip 192.168.1.100 --port 502

# Battery ESS
./setup_der_clean.sh --type ess --ip 192.168.1.101 --port 502

# Smart Meter
./setup_der_clean.sh --type meter --ip 192.168.1.102 --port 502
```

## 📋 Prerequisites

- **Docker & Docker Compose** installed
- **Network access** to DER devices
- **Modbus TCP** enabled on DER devices
- **macOS, Linux, or WSL2**

## 🔌 Supported DER Types

| Type | Description | OpenFMB Profiles |
|------|-------------|------------------|
| `solar` | Solar PV Inverters | SolarReadingProfile, SolarStatusProfile |
| `ess` | Battery Energy Storage | ESSReadingProfile, ESSStatusProfile |
| `switch` | Smart Breakers | SwitchReadingProfile, SwitchStatusProfile |
| `load` | Load Controllers | LoadReadingProfile, LoadStatusProfile |
| `meter` | Smart Meters | MeterReadingProfile |

## 🔧 What Gets Created

After running setup:
```
der_configs/                    # Generated during setup
├── adapter-{type}.yaml        # Main OpenFMB configuration
├── templates/
│   └── modbus-{type}-template.yaml  # Device-specific mappings
├── docker-compose.yml         # Container orchestration
├── logs/                      # Adapter log files
├── monitor_der.sh            # Real-time monitoring
└── control_der.sh           # Device control commands
```

## 📊 Services Started

- **MQTT Broker (Mosquitto)**: `mqtt://localhost:1883`
- **OpenFMB Adapter**: Connects to your DER device
- **HMI Interface**: `http://localhost:32771` (optional)

## ⚡ Usage Examples

```bash
# Monitor real-time data
./der_configs/monitor_der.sh localhost 1883 "*"

# Control device
./der_configs/control_der.sh localhost 1883 "device-mrid" start

# View logs
cd der_configs && docker-compose logs -f

# Stop services
cd der_configs && docker-compose down
```

## 🛠️ Script Functions

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `quick_setup.sh` | Interactive menu | First time setup |
| `setup_der_clean.sh` | Auto-cleanup setup | Production use |
| `setup_openfmb_der.sh` | Core setup logic | Advanced users |
| `cleanup_containers.sh` | Manual cleanup | Troubleshooting |

## 🔍 Verification Steps

1. **Check Services**: `docker ps` (should show 3+ containers)
2. **Test MQTT**: `mosquitto_pub -h localhost -p 1883 -t "test" -m "hello"`
3. **Monitor Data**: Use the generated monitor script
4. **View HMI**: Open `http://localhost:32771`

## 🐛 Troubleshooting

### Container Conflicts
```bash
./cleanup_containers.sh
./setup_der_clean.sh --type solar --ip 192.168.1.100
```

### Connection Issues
- Verify DER device IP/port: `telnet 192.168.1.100 502`
- Check Modbus mappings in template files
- Enable debug logging: `ADAPTER_LOG_LEVEL=debug`

### Platform Issues (Apple Silicon)
The Docker images may show platform warnings on M1/M2 Macs but will work correctly.

## 📖 Documentation

- **Full Setup Guide**: `docs/DER_SETUP_README.md`
- **Container Fixes**: `docs/CONTAINER_FIX.md`  
- **Next Steps**: `docs/NEXT_STEPS_GUIDE.md`

## 🔒 Security Note

This setup is for development/testing. For production:
- Enable MQTT authentication
- Use TLS encryption
- Configure firewall rules
- Implement access control

## ✅ Production Ready

This minimal setup includes everything needed for a production OpenFMB deployment:
- Automatic container management
- Comprehensive error handling
- Modular configuration
- Monitoring and control utilities
- Complete documentation

**Start your OpenFMB DER integration in under 1 minute!** 🚀
