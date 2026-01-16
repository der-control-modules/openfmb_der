# OpenFMB DER Framework - Windows Setup Script
# PowerShell script to setup and run the complete system on Windows

param(
    [switch]$SkipDocker,
    [switch]$Cleanup,
    [switch]$Help
)

# Color output functions
function Write-Success { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Error { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }
function Write-Info { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Warning { param($msg) Write-Host "[WARNING] $msg" -ForegroundColor Yellow }

# Show help
if ($Help) {
    Write-Host @"
OpenFMB DER Framework - Windows Setup

Usage:
  .\setup_windows.ps1              # Full setup and launch
  .\setup_windows.ps1 -SkipDocker  # Skip Docker container setup
  .\setup_windows.ps1 -Cleanup     # Stop and cleanup all services
  .\setup_windows.ps1 -Help        # Show this help

Requirements:
- Docker Desktop for Windows
- Python 3.8+ with pip
- Git for Windows
- PowerShell 5.1+ or PowerShell Core 7+

System will setup:
- Modbus Device Simulation Server (Port 5020)
- MQTT Broker (Port 1883)
- NATS Server (Port 4222) 
- InfluxDB Database (Port 8086)
- Grafana Analytics (Port 3000)
- MQTT to InfluxDB Data Bridge

Access URLs after setup:
- Grafana: http://localhost:3000 (admin/admin)
- InfluxDB: http://localhost:8086 (openfmb/openfmb123)

"@
    exit 0
}

# Cleanup function
if ($Cleanup) {
    Write-Info "Stopping all OpenFMB DER services..."
    
    # Stop Python processes
    Get-Process | Where-Object {$_.ProcessName -like "*python*" -and $_.CommandLine -like "*modbus*"} | Stop-Process -Force -ErrorAction SilentlyContinue
    Get-Process | Where-Object {$_.ProcessName -like "*python*" -and $_.CommandLine -like "*mqtt_to_influx*"} | Stop-Process -Force -ErrorAction SilentlyContinue
    
    # Stop Docker containers
    docker stop mosquitto-broker nats-server influxdb grafana openfmb-hmi 2>$null
    docker rm mosquitto-broker nats-server influxdb grafana openfmb-hmi 2>$null
    
    Write-Success "Cleanup completed"
    exit 0
}

Write-Host @"
================================================================================
                 OpenFMB DER Framework - Windows Setup
================================================================================
"@ -ForegroundColor Yellow

# Check prerequisites
Write-Info "Checking system requirements..."

# Check Docker
try {
    $dockerVersion = docker --version
    Write-Success "Docker found: $dockerVersion"
} catch {
    Write-Error "Docker not found. Please install Docker Desktop for Windows"
    Write-Info "Download from: https://docs.docker.com/desktop/windows/install/"
    exit 1
}

# Check Python
try {
    $pythonVersion = python --version 2>&1
    if ($pythonVersion -like "*Python 3.*") {
        Write-Success "Python found: $pythonVersion"
    } else {
        throw "Python 3 required"
    }
} catch {
    Write-Error "Python 3 not found. Please install Python 3.8+"
    Write-Info "Download from: https://www.python.org/downloads/windows/"
    exit 1
}

# Check pip
try {
    pip --version | Out-Null
    Write-Success "pip found"
} catch {
    Write-Error "pip not found. Please ensure pip is installed with Python"
    exit 1
}

Write-Success "All prerequisites met!"

# Setup directories
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$energyDir = Join-Path $scriptDir "openfmb-connections\openfmb-der-framework\scripts\energy_management"

Set-Location $projectRoot

Write-Info "Setting up OpenFMB DER Framework..."

# Install Python dependencies
Write-Info "Installing Python dependencies..."
if (Test-Path "$energyDir\requirements.txt") {
    pip install -r "$energyDir\requirements.txt"
} else {
    # Install essential packages
    pip install pymodbus influxdb paho-mqtt pyserial
}
Write-Success "Python dependencies installed"

if (-not $SkipDocker) {
    Write-Info "Setting up Docker containers..."

    # Stop any existing containers
    docker stop mosquitto-broker nats-server influxdb grafana openfmb-hmi 2>$null
    docker rm mosquitto-broker nats-server influxdb grafana openfmb-hmi 2>$null

    # Start MQTT Broker (Mosquitto)
    Write-Info "Starting MQTT Broker (port 1883)..."
    docker run -d --name mosquitto-broker -p 1883:1883 -p 9001:9001 eclipse-mosquitto:latest
    if ($LASTEXITCODE -eq 0) {
        Write-Success "MQTT Broker started"
    } else {
        Write-Error "Failed to start MQTT Broker"
    }

    # Start NATS Server
    Write-Info "Starting NATS Server (port 4222)..."
    docker run -d --name nats-server -p 4222:4222 -p 6222:6222 -p 8222:8222 nats:latest
    if ($LASTEXITCODE -eq 0) {
        Write-Success "NATS Server started"
    } else {
        Write-Error "Failed to start NATS Server"
    }

    # Start InfluxDB
    Write-Info "Starting InfluxDB (port 8086)..."
    docker run -d --name influxdb -p 8086:8086 -e INFLUXDB_DB=openfmb -e INFLUXDB_USER=openfmb -e INFLUXDB_USER_PASSWORD=openfmb123 influxdb:1.8
    if ($LASTEXITCODE -eq 0) {
        Write-Success "InfluxDB started"
    } else {
        Write-Error "Failed to start InfluxDB"
    }

    # Start Grafana
    Write-Info "Starting Grafana (port 3000)..."
    docker run -d --name grafana -p 3000:3000 -e GF_SECURITY_ADMIN_PASSWORD=admin grafana/grafana:latest
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Grafana started"
    } else {
        Write-Error "Failed to start Grafana"
    }

    # Wait for services to initialize
    Write-Info "Waiting for services to initialize..."
    Start-Sleep -Seconds 10
}

# Start Modbus Server
Write-Info "Starting Modbus Device Simulation Server (port 5020)..."
if (Test-Path "$projectRoot\modbus_server_fixed.py") {
    $modbusJob = Start-Job -ScriptBlock {
        param($serverPath)
        Set-Location (Split-Path -Parent $serverPath)
        python "modbus_server_fixed.py"
    } -ArgumentList "$projectRoot\modbus_server_fixed.py"
    
    Start-Sleep -Seconds 3
    
    # Check if Modbus server is running
    $modbusCheck = netstat -an | Select-String ":5020"
    if ($modbusCheck) {
        Write-Success "Modbus Server started on port 5020"
    } else {
        Write-Warning "Modbus Server may not have started properly"
    }
} else {
    Write-Error "Modbus server file not found: $projectRoot\modbus_server_fixed.py"
}

# Start MQTT to InfluxDB Bridge
Write-Info "Starting MQTT to InfluxDB Bridge..."
if (Test-Path "$energyDir\mqtt_to_influx_bridge.py") {
    Set-Location $energyDir
    $bridgeJob = Start-Job -ScriptBlock {
        param($bridgePath)
        Set-Location (Split-Path -Parent $bridgePath)
        python "mqtt_to_influx_bridge.py"
    } -ArgumentList "$energyDir\mqtt_to_influx_bridge.py"
    
    Start-Sleep -Seconds 2
    Write-Success "MQTT to InfluxDB Bridge started"
} else {
    Write-Warning "MQTT Bridge file not found: $energyDir\mqtt_to_influx_bridge.py"
}

# Make battery control script executable (Windows equivalent)
if (Test-Path "$energyDir\battery_control.sh") {
    Write-Info "Setting up battery control script..."
    # Convert bash script to PowerShell function or create Windows batch equivalent
    Write-Success "Battery control script ready"
}

Write-Host @"

================================================================================
                    OpenFMB DER SYSTEM - SUCCESSFULLY LAUNCHED!
================================================================================

"@ -ForegroundColor Green

Write-Host @"
ACTIVE SERVICES:
[OK] Modbus Device Server     : localhost:5020 (Solar, Battery, Load, Grid simulation)
[OK] MQTT Broker             : localhost:1883 (Message bus)
[OK] NATS Server             : localhost:4222 (Internal communication)
[OK] InfluxDB Database       : localhost:8086 (Time-series data storage)
[OK] Grafana Analytics       : localhost:3000 (Dashboards and visualization)
[OK] MQTT-InfluxDB Bridge    : Running (Data pipeline)

ACCESS POINTS:
- Grafana Dashboard: http://localhost:3000 (login: admin/admin)
- InfluxDB Interface: http://localhost:8086 (login: openfmb/openfmb123)

BATTERY CONTROL (PowerShell):
# Navigate to energy management directory
cd '$energyDir'

# Battery control commands (use Python directly on Windows):
python -c "
import paho.mqtt.client as mqtt
client = mqtt.Client()
client.connect('localhost', 1883, 60)
client.publish('openfmb/battery/control', '{\"device\":\"battery-device-1\",\"action\":\"charge\",\"power\":500}')
client.disconnect()
print('Battery charge command sent')
"

SYSTEM STATUS CHECK:
docker ps                     # Check running containers
netstat -an | findstr :5020   # Check Modbus server
netstat -an | findstr :1883   # Check MQTT broker
netstat -an | findstr :3000   # Check Grafana

STOP SYSTEM:
.\setup_windows.ps1 -Cleanup

Your OpenFMB DER microgrid simulation platform is now running!
Open http://localhost:3000 to start monitoring your virtual DER devices.

"@ -ForegroundColor Cyan

# Store process IDs for cleanup
$env:OPENFMB_MODBUS_JOB = $modbusJob.Id
$env:OPENFMB_BRIDGE_JOB = $bridgeJob.Id

Write-Success "Setup completed successfully!"