# OpenFMB DER Next Steps Guide 🚀

This guide shows you exactly how to verify and troubleshoot your OpenFMB DER setup.

## 📊 Step 1: Check Service Status

```bash
# Navigate to the config directory
cd /Users/moha907/Downloads/openfmb.adapters.config-2.1.0/der_configs

# Check all service status
docker-compose ps

# Expected output:
# ✅ mosquitto: Up (MQTT broker)
# ❓ openfmb-adapter: May be restarting (normal during initial connection attempts)
# ❓ openfmb-hmi: May be restarting (platform compatibility issue on Mac)
```

## 🔍 Step 2: Check Service Logs

### MQTT Broker Logs
```bash
cd /Users/moha907/Downloads/openfmb.adapters.config-2.1.0/der_configs
docker-compose logs mosquitto
```
**Expected**: Should show "listening on port 1883"

### OpenFMB Adapter Logs
```bash
docker-compose logs openfmb-adapter | tail -20
```
**Look for**:
- Configuration file loading
- Modbus connection attempts to your DER device
- MQTT connection status

### HMI Logs (if needed)
```bash
docker-compose logs openfmb-hmi | tail -10
```

## 🔌 Step 3: Verify DER Device Connectivity

### Test Network Connectivity
```bash
# Test if your DER device is reachable
ping 192.168.1.100

# Test Modbus port connectivity (replace with your DER IP)
nc -zv 192.168.1.100 502
```

**Expected Results**:
- ✅ Ping should succeed
- ✅ Port 502 should be open
- ❌ If either fails, check your DER device network configuration

### Test MQTT Broker
```bash
# Install mosquitto clients if not available
brew install mosquitto  # macOS
# or sudo apt-get install mosquitto-clients  # Linux

# Test MQTT connection
mosquitto_pub -h localhost -p 1883 -t "test/topic" -m "hello"
```

## 📡 Step 4: Monitor Real-time Data

### Use the Generated Monitor Script
```bash
# Monitor all OpenFMB messages
/Users/moha907/Downloads/openfmb.adapters.config-2.1.0/der_configs/monitor_der.sh localhost 1883 "*"

# Monitor specific device (replace with your MRID)
/Users/moha907/Downloads/openfmb.adapters.config-2.1.0/der_configs/monitor_der.sh localhost 1883 "1e740843-fcf2-4dcb-a1f0-6bd48958ca14"
```

### Manual MQTT Monitoring
```bash
# Subscribe to all OpenFMB topics
mosquitto_sub -h localhost -p 1883 -t "openfmb/+/+/+" -v

# Subscribe to solar reading data specifically
mosquitto_sub -h localhost -p 1883 -t "openfmb/readingprofile/SolarReadingProfile/+" -v
```

## 🎛️ Step 5: Test Device Control

### Use the Control Script
```bash
# Start/enable device (replace MRID with yours)
/Users/moha907/Downloads/openfmb.adapters.config-2.1.0/der_configs/control_der.sh localhost 1883 "1e740843-fcf2-4dcb-a1f0-6bd48958ca14" start

# Set power level
/Users/moha907/Downloads/openfmb.adapters.config-2.1.0/der_configs/control_der.sh localhost 1883 "1e740843-fcf2-4dcb-a1f0-6bd48958ca14" setpower 1000
```

## 🌐 Step 6: Access Web Interface

### HMI Web Interface
```bash
# Open in browser
open http://localhost:32771
# or manually navigate to: http://localhost:32771
```

**Note**: The HMI may not work on Apple Silicon Macs due to platform compatibility. Use MQTT monitoring instead.

## 🔧 Step 7: Configuration Adjustments

### Modify Modbus Register Mappings
```bash
# Edit the template file to match your device
nano /Users/moha907/Downloads/openfmb.adapters.config-2.1.0/der_configs/templates/modbus-solar-template.yaml

# After changes, restart services
cd /Users/moha907/Downloads/openfmb.adapters.config-2.1.0/der_configs
docker-compose restart openfmb-adapter
```

### Common Register Adjustments:
- **Address**: Change `address: 40001` to match your device manual
- **Data Type**: Adjust `data-type: float32` (float32, int16, uint16, etc.)
- **Scale**: Modify `scale: 1.0` for unit conversions
- **Unit ID**: Update `unit-identifier: 1` if different

## 🚨 Troubleshooting Common Issues

### Issue 1: Adapter Keeps Restarting
**Cause**: Cannot connect to DER device or configuration error
**Solution**:
```bash
# Check logs for specific error
docker-compose logs openfmb-adapter | grep -i error

# Verify device connectivity
nc -zv YOUR_DER_IP 502

# Check configuration file syntax
cat /Users/moha907/Downloads/openfmb.adapters.config-2.1.0/der_configs/adapter-solar.yaml
```

### Issue 2: No Data on MQTT Topics
**Cause**: Incorrect Modbus register mappings
**Solution**:
1. Check your DER device manual for correct register addresses
2. Update the template file with correct mappings
3. Restart the adapter

### Issue 3: HMI Not Loading
**Cause**: Platform compatibility (common on Apple Silicon Macs)
**Solution**: Use MQTT monitoring instead:
```bash
mosquitto_sub -h localhost -p 1883 -t "openfmb/+/+/+" -v
```

## 📈 Step 8: Verify Data Flow

### Expected Data Flow:
1. **DER Device** → **Modbus TCP** → **OpenFMB Adapter**
2. **OpenFMB Adapter** → **MQTT** → **Mosquitto Broker**
3. **MQTT Topics** → **HMI/Monitoring Tools**

### Quick Verification Checklist:
- [ ] MQTT broker is running (port 1883)
- [ ] DER device is network accessible
- [ ] Modbus registers match device documentation
- [ ] MQTT topics show data
- [ ] Control commands work

## 🔄 Step 9: Restart/Reset if Needed

### Restart Services
```bash
cd /Users/moha907/Downloads/openfmb.adapters.config-2.1.0/der_configs
docker-compose restart
```

### Full Reset
```bash
# Stop all services
docker-compose down

# Clean up completely
cd /Users/moha907/Downloads/openfmb.adapters.config-2.1.0
./cleanup_containers.sh

# Start fresh
./setup_der_clean.sh --type solar --ip YOUR_DER_IP --port 502 --device-id 1
```

## 📞 Getting Help

### Check Logs Location:
- **Adapter Logs**: `/Users/moha907/Downloads/openfmb.adapters.config-2.1.0/der_configs/logs/`
- **Docker Logs**: `docker-compose logs [service-name]`

### Key Files to Check:
- **Main Config**: `der_configs/adapter-solar.yaml`
- **Modbus Template**: `der_configs/templates/modbus-solar-template.yaml`
- **Docker Compose**: `der_configs/docker-compose.yml`

Success indicators: 📊 Data flowing on MQTT topics, ✅ Stable containers, 🎯 Device responding to controls!
