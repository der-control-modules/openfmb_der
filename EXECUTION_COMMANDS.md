# OpenFMB DER Framework - File Execution Commands

## 🚀 Complete Setup and Execution Guide

### 📁 Navigate to the Minimal Setup Folder
```bash
cd /Users/moha907/Downloads/openfmb.adapters.config-2.1.0/openfmb-der-minimal/
```

## 📋 Pre-Execution Checklist
```bash
# 1. Verify Docker is running
docker --version
docker info

# 2. Check file permissions
ls -la scripts/
```

## 🔧 Installation and Setup Commands

### Option 1: Automated Installation (Recommended)
```bash
# Run the complete installation script
./install.sh
```

### Option 2: Manual Step-by-Step Execution
```bash
# Step 1: Make all scripts executable
chmod +x scripts/*.sh
chmod +x install.sh

# Step 2: Run interactive setup
./scripts/quick_setup.sh
```

### Option 3: Direct Command Line Setup
```bash
# Solar Inverter Setup
./scripts/setup_der_clean.sh --type solar --ip 192.168.1.100 --port 502 --device-id 1

# Battery ESS Setup
./scripts/setup_der_clean.sh --type ess --ip 192.168.1.101 --port 502 --device-id 2

# Smart Meter Setup
./scripts/setup_der_clean.sh --type meter --ip 192.168.1.102 --port 502 --device-id 3
```

## 🎯 Common Execution Scenarios

### Scenario 1: First Time Setup (Solar Inverter)
```bash
# Navigate to folder
cd openfmb-der-minimal/

# Interactive setup
./scripts/quick_setup.sh
# Select option 1 (Solar PV Inverter)
# Enter IP: 192.168.1.100
# Enter Port: 502
# Enter Device ID: 1
# Enter MQTT Broker: localhost
```

### Scenario 2: Multiple DER Devices
```bash
# Setup multiple devices in sequence
./scripts/setup_der_clean.sh --type solar --ip 192.168.1.100 --device-id 1
./scripts/setup_der_clean.sh --type ess --ip 192.168.1.101 --device-id 2
./scripts/setup_der_clean.sh --type meter --ip 192.168.1.102 --device-id 3
```

### Scenario 3: Custom Configuration
```bash
# Custom MQTT broker and specific device MRID
./scripts/setup_der_clean.sh \
    --type solar \
    --ip 192.168.1.100 \
    --port 502 \
    --device-id 1 \
    --broker mqtt.company.com \
    --broker-port 1883 \
    --mrid "solar-inverter-001" \
    --client-id "openfmb-site1"
```

## 🔍 Monitoring and Control Commands

### Real-Time Monitoring
```bash
# Monitor all DER devices
./generated/configs/monitor_der.sh localhost 1883 "*"

# Monitor specific device (replace MRID with actual value)
./generated/configs/monitor_der.sh localhost 1883 "your-device-mrid-here"

# Monitor with external MQTT broker
./generated/configs/monitor_der.sh mqtt.company.com 1883 "*"
```

### Device Control Commands
```bash
# Start/Enable Device
./generated/configs/control_der.sh localhost 1883 "device-mrid" start

# Stop/Disable Device
./generated/configs/control_der.sh localhost 1883 "device-mrid" stop

# Set Power Level (in watts)
./generated/configs/control_der.sh localhost 1883 "device-mrid" setpower 1500

# Reset Device
./generated/configs/control_der.sh localhost 1883 "device-mrid" reset
```

## 📊 Service Management Commands

### Docker Container Management
```bash
# Check service status
cd generated/configs/
docker-compose ps

# View logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f openfmb-adapter
docker-compose logs -f mosquitto
docker-compose logs -f openfmb-hmi

# Restart services
docker-compose restart

# Stop all services
docker-compose down

# Stop and remove volumes
docker-compose down -v
```

### Manual MQTT Testing
```bash
# Test MQTT connection
mosquitto_pub -h localhost -p 1883 -t "test/connection" -m "OpenFMB Test"

# Subscribe to all OpenFMB topics
mosquitto_sub -h localhost -p 1883 -t "openfmb/+/+/+" -v

# Subscribe to specific profile
mosquitto_sub -h localhost -p 1883 -t "openfmb/readingprofile/SolarReadingProfile/+" -v
```

## 🛠️ Maintenance Commands

### Container Cleanup
```bash
# Clean up conflicting containers
./scripts/cleanup_containers.sh

# Remove all OpenFMB containers and data
./scripts/cleanup_containers.sh
# Answer 'y' when prompted to remove volumes
```

### Configuration Updates
```bash
# Regenerate configurations for different device
./scripts/setup_der_clean.sh --type ess --ip 192.168.1.200 --device-id 5

# Update Modbus register mappings
nano generated/configs/templates/modbus-solar-template.yaml

# Restart services after config changes
cd generated/configs/
docker-compose restart
```

## 📱 Web Interface Access

### HMI (Human-Machine Interface)
```bash
# Open HMI in browser
open http://localhost:32771

# Or manually navigate to:
# http://localhost:32771
```

### MQTT Web Interface
```bash
# If mosquitto WebSocket is enabled:
# ws://localhost:9001
```

## 🔧 Troubleshooting Commands

### Check Service Health
```bash
# Check all containers
docker ps -a

# Check specific container logs
docker logs openfmb-mosquitto
docker logs openfmb-solar-adapter
docker logs openfmb-hmi

# Check network connectivity to DER device
ping 192.168.1.100
telnet 192.168.1.100 502
```

### Debug Mode
```bash
# Run with debug logging
ADAPTER_LOG_LEVEL=debug ./scripts/setup_der_clean.sh --type solar --ip 192.168.1.100

# Check debug logs
cd generated/configs/
docker-compose logs -f | grep -i error
```

## 📋 Complete Execution Sequence (Start to Finish)

```bash
# 1. Navigate to setup folder
cd /path/to/openfmb-der-minimal/

# 2. Run installation
./install.sh

# 3. Setup your DER device
./scripts/quick_setup.sh

# 4. Monitor data flow
./generated/configs/monitor_der.sh localhost 1883 "*"

# 5. Open web interface
open http://localhost:32771

# 6. Control devices
./generated/configs/control_der.sh localhost 1883 "device-mrid" start

# 7. View logs (in another terminal)
cd generated/configs/ && docker-compose logs -f
```

## 🎯 Quick Command Reference

| Action | Command |
|--------|---------|
| **Setup** | `./scripts/quick_setup.sh` |
| **Monitor** | `./generated/configs/monitor_der.sh localhost 1883 "*"` |
| **Control** | `./generated/configs/control_der.sh localhost 1883 "mrid" start` |
| **Logs** | `cd generated/configs && docker-compose logs -f` |
| **Web UI** | `open http://localhost:32771` |
| **Cleanup** | `./scripts/cleanup_containers.sh` |
| **Status** | `cd generated/configs && docker-compose ps` |

All commands assume you're in the `openfmb-der-minimal/` directory!
