# OpenFMB DER Framework - Windows Setup and Usage Guide

## Quick Start for Windows

### 1. Prerequisites Installation

**Required Software:**
- **Docker Desktop for Windows**: [Download Here](https://docs.docker.com/desktop/windows/install/)
- **Python 3.8+**: [Download Here](https://www.python.org/downloads/windows/)
- **Git for Windows**: [Download Here](https://git-scm.com/download/win)

**Verification Commands (in Command Prompt or PowerShell):**
```cmd
docker --version
python --version
git --version
```

### 2. Download and Setup

```cmd
# Clone or download the project
git clone <your-repository-url>
cd openfmb-der

# Option A: Use PowerShell Script (Recommended)
PowerShell -ExecutionPolicy Bypass -File setup_windows.ps1

# Option B: Use Batch File (Alternative)
setup_windows.bat

# Option C: Use PowerShell with parameters
PowerShell -ExecutionPolicy Bypass -File setup_windows.ps1 -Help
```

### 3. System Launch Options

**Full Setup (Recommended):**
```powershell
# PowerShell (run as Administrator if needed)
.\setup_windows.ps1

# OR Command Prompt
setup_windows.bat
```

**Custom Setup:**
```powershell
# Skip Docker setup (if containers already running)
.\setup_windows.ps1 -SkipDocker

# Show help and options
.\setup_windows.ps1 -Help
```

## What Gets Installed and Started

### Automatic Service Setup

| Service | Port | Purpose | Status Check |
|---------|------|---------|--------------|
| **Modbus Server** | 5020 | DER Device Simulation | `netstat -an \| findstr :5020` |
| **MQTT Broker** | 1883 | Message Bus | `netstat -an \| findstr :1883` |
| **NATS Server** | 4222 | Internal Communication | `docker ps \| findstr nats` |
| **InfluxDB** | 8086 | Time Series Database | `docker ps \| findstr influx` |
| **Grafana** | 3000 | Analytics Dashboard | `docker ps \| findstr grafana` |
| **Data Bridge** | - | MQTT to InfluxDB | Background Process |

### Access URLs After Setup

- **Grafana Dashboard**: http://localhost:3000
  - Username: `admin`
  - Password: `admin` (will prompt to change)
  
- **InfluxDB Interface**: http://localhost:8086
  - Username: `openfmb`
  - Password: `openfmb123`

## Battery Control Commands

### Method 1: Python Script (Recommended)

```cmd
# Navigate to energy management directory
cd openfmb-connections\openfmb-der-framework\scripts\energy_management

# Charge battery at 500W
python battery_control_windows.py localhost 1883 battery-device-1 charge 500

# Discharge battery at 300W
python battery_control_windows.py localhost 1883 battery-device-1 discharge 300

# Stop battery operation
python battery_control_windows.py localhost 1883 battery-device-1 stop 0

# Get help
python battery_control_windows.py --help
```

### Method 2: Direct Python MQTT (Quick Commands)

```python
# Create quick_battery.py file
import paho.mqtt.client as mqtt
import json
from datetime import datetime

def battery_command(action, power, device="battery-device-1"):
    client = mqtt.Client()
    client.connect('localhost', 1883, 60)
    
    message = {
        "device": device,
        "action": action,
        "power": power,
        "timestamp": datetime.utcnow().isoformat()
    }
    
    client.publish('openfmb/battery/control', json.dumps(message))
    client.disconnect()
    print(f"Battery {action} command sent: {power}W")

# Usage:
# battery_command("charge", 500)
# battery_command("discharge", 300)
# battery_command("stop", 0)
```

## System Management Commands

### Check System Status

```cmd
# Check all Docker containers
docker ps

# Check specific services
docker ps | findstr mosquitto
docker ps | findstr nats
docker ps | findstr influx
docker ps | findstr grafana

# Check ports in use
netstat -an | findstr :5020   # Modbus
netstat -an | findstr :1883   # MQTT
netstat -an | findstr :3000   # Grafana
netstat -an | findstr :8086   # InfluxDB
```

### Stop/Restart Services

```cmd
# Stop all services (PowerShell)
.\setup_windows.ps1 -Cleanup

# Stop all services (Batch)
setup_windows.bat cleanup

# Restart individual containers
docker restart mosquitto-broker
docker restart nats-server
docker restart influxdb
docker restart grafana

# Restart Modbus server
taskkill /f /im python.exe
# Then run setup script again
```

## Grafana Dashboard Setup

### 1. Access Grafana
1. Open browser to http://localhost:3000
2. Login with `admin` / `admin`
3. Set new password when prompted

### 2. Configure Data Source
1. Go to Configuration → Data Sources
2. Add InfluxDB data source:
   - URL: `http://localhost:8086`
   - Database: `openfmb`
   - User: `openfmb`
   - Password: `openfmb123`

### 3. Import Dashboard
```cmd
# Navigate to energy management directory
cd openfmb-connections\openfmb-der-framework\scripts\energy_management

# Import the pre-built dashboard
# In Grafana: + → Import → Upload JSON file
# Select: grafana_dashboard_fixed.json
```

## Troubleshooting

### Common Issues and Solutions

**1. Docker Containers Won't Start**
```cmd
# Check if Docker Desktop is running
docker info

# Stop conflicting containers
docker stop $(docker ps -aq)
docker system prune -f

# Restart Docker Desktop and try again
```

**2. Python Modules Missing**
```cmd
# Install missing dependencies
pip install pymodbus paho-mqtt influxdb

# If pip fails, try:
python -m pip install --upgrade pip
pip install -r openfmb-connections\openfmb-der-framework\scripts\energy_management\requirements.txt
```

**3. Port Conflicts**
```cmd
# Find what's using a port (example for 3000)
netstat -ano | findstr :3000

# Kill process by PID
taskkill /f /pid <PID_NUMBER>
```

**4. PowerShell Execution Policy**
```powershell
# If PowerShell scripts are blocked
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Or run with bypass
PowerShell -ExecutionPolicy Bypass -File setup_windows.ps1
```

**5. Firewall/Antivirus Issues**
- Add Python and Docker to firewall exceptions
- Temporarily disable antivirus for setup
- Ensure ports 1883, 3000, 5020, 8086 are allowed

### Log Locations

**Docker Container Logs:**
```cmd
docker logs mosquitto-broker
docker logs nats-server  
docker logs influxdb
docker logs grafana
```

**Python Process Logs:**
- Check Command Prompt windows where Python processes are running
- Look for error messages in console output

## Windows-Specific Notes

### File Paths
- Use backslashes `\` for Windows paths in Command Prompt
- Use forward slashes `/` for URLs and Docker paths
- PowerShell accepts both `\` and `/`

### Process Management
- Python processes run in separate Command Prompt windows
- Use Task Manager to monitor Python processes
- Stop processes with `Ctrl+C` in their respective windows

### Networking
- Windows Defender Firewall may block connections
- Docker Desktop creates virtual network interfaces
- Use `localhost` or `127.0.0.1` for local connections

### Performance Tips
- Ensure Docker Desktop has adequate memory (4GB+)
- Close unused applications to free system resources
- Monitor CPU usage during data simulation

## Success Verification

After setup, verify these indicators:

**[OK] Green Status Messages** during setup
**[OK] All containers show "Up" status** in `docker ps`
**[OK] All ports responding** in netstat commands  
**[OK] Grafana accessible** at http://localhost:3000
**[OK] Battery commands** execute without errors
**[OK] Live data visible** in Grafana dashboards

Your OpenFMB DER microgrid simulation platform is ready for development and testing!

## Additional Windows Tools

### Optional Utilities
- **MQTT Explorer**: GUI MQTT client for message monitoring
- **Postman**: API testing for REST endpoints  
- **Docker Desktop Dashboard**: Visual container management
- **Windows Terminal**: Enhanced command line experience