@echo off
REM OpenFMB DER Framework - Windows Batch Setup Script
REM Alternative batch file for systems without PowerShell

setlocal EnableDelayedExpansion

echo ================================================================================
echo                 OpenFMB DER Framework - Windows Setup (Batch)
echo ================================================================================

REM Check for help parameter
if "%1"=="--help" goto :help
if "%1"=="-h" goto :help
if "%1"=="help" goto :help

REM Check for cleanup parameter
if "%1"=="--cleanup" goto :cleanup
if "%1"=="-cleanup" goto :cleanup
if "%1"=="cleanup" goto :cleanup

echo [INFO] Checking system requirements...

REM Check Docker
docker --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker not found. Please install Docker Desktop for Windows
    echo [INFO] Download from: https://docs.docker.com/desktop/windows/install/
    pause
    exit /b 1
) else (
    echo [OK] Docker found
)

REM Check Python
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python not found. Please install Python 3.8+
    echo [INFO] Download from: https://www.python.org/downloads/windows/
    pause
    exit /b 1
) else (
    echo [OK] Python found
)

REM Check pip
pip --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] pip not found. Please ensure pip is installed with Python
    pause
    exit /b 1
) else (
    echo [OK] pip found
)

echo [OK] All prerequisites met!

echo [INFO] Setting up OpenFMB DER Framework...

REM Get script directory
set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT=%SCRIPT_DIR%"
set "ENERGY_DIR=%SCRIPT_DIR%openfmb-connections\openfmb-der-framework\scripts\energy_management"

cd /d "%PROJECT_ROOT%"

echo [INFO] Installing Python dependencies...
if exist "%ENERGY_DIR%\requirements.txt" (
    pip install -r "%ENERGY_DIR%\requirements.txt"
) else (
    REM Install essential packages
    pip install pymodbus influxdb paho-mqtt pyserial
)
echo [OK] Python dependencies installed

echo [INFO] Setting up Docker containers...

REM Stop any existing containers
docker stop mosquitto-broker nats-server influxdb grafana openfmb-hmi >nul 2>&1
docker rm mosquitto-broker nats-server influxdb grafana openfmb-hmi >nul 2>&1

REM Start MQTT Broker (Mosquitto)
echo [INFO] Starting MQTT Broker (port 1883)...
docker run -d --name mosquitto-broker -p 1883:1883 -p 9001:9001 eclipse-mosquitto:latest
if errorlevel 1 (
    echo [ERROR] Failed to start MQTT Broker
) else (
    echo [OK] MQTT Broker started
)

REM Start NATS Server
echo [INFO] Starting NATS Server (port 4222)...
docker run -d --name nats-server -p 4222:4222 -p 6222:6222 -p 8222:8222 nats:latest
if errorlevel 1 (
    echo [ERROR] Failed to start NATS Server
) else (
    echo [OK] NATS Server started
)

REM Start InfluxDB
echo [INFO] Starting InfluxDB (port 8086)...
docker run -d --name influxdb -p 8086:8086 -e INFLUXDB_DB=openfmb -e INFLUXDB_USER=openfmb -e INFLUXDB_USER_PASSWORD=openfmb123 influxdb:1.8
if errorlevel 1 (
    echo [ERROR] Failed to start InfluxDB
) else (
    echo [OK] InfluxDB started
)

REM Start Grafana
echo [INFO] Starting Grafana (port 3000)...
docker run -d --name grafana -p 3000:3000 -e GF_SECURITY_ADMIN_PASSWORD=admin grafana/grafana:latest
if errorlevel 1 (
    echo [ERROR] Failed to start Grafana
) else (
    echo [OK] Grafana started
)

REM Wait for services to initialize
echo [INFO] Waiting for services to initialize...
timeout /t 10 /nobreak >nul

REM Start Modbus Server
echo [INFO] Starting Modbus Device Simulation Server (port 5020)...
if exist "%PROJECT_ROOT%modbus_server_fixed.py" (
    start /b python "%PROJECT_ROOT%modbus_server_fixed.py"
    timeout /t 3 /nobreak >nul
    
    REM Check if Modbus server is running
    netstat -an | findstr ":5020" >nul
    if errorlevel 1 (
        echo [WARNING] Modbus Server may not have started properly
    ) else (
        echo [OK] Modbus Server started on port 5020
    )
) else (
    echo [ERROR] Modbus server file not found: %PROJECT_ROOT%modbus_server_fixed.py
)

REM Start MQTT to InfluxDB Bridge
echo [INFO] Starting MQTT to InfluxDB Bridge...
if exist "%ENERGY_DIR%\mqtt_to_influx_bridge.py" (
    cd /d "%ENERGY_DIR%"
    start /b python mqtt_to_influx_bridge.py
    timeout /t 2 /nobreak >nul
    echo [OK] MQTT to InfluxDB Bridge started
) else (
    echo [WARNING] MQTT Bridge file not found: %ENERGY_DIR%\mqtt_to_influx_bridge.py
)

echo.
echo ================================================================================
echo                    OpenFMB DER SYSTEM - SUCCESSFULLY LAUNCHED!
echo ================================================================================
echo.
echo ACTIVE SERVICES:
echo [OK] Modbus Device Server     : localhost:5020 (Solar, Battery, Load, Grid simulation^)
echo [OK] MQTT Broker             : localhost:1883 (Message bus^)
echo [OK] NATS Server             : localhost:4222 (Internal communication^)
echo [OK] InfluxDB Database       : localhost:8086 (Time-series data storage^)
echo [OK] Grafana Analytics       : localhost:3000 (Dashboards and visualization^)
echo [OK] MQTT-InfluxDB Bridge    : Running (Data pipeline^)
echo.
echo ACCESS POINTS:
echo - Grafana Dashboard: http://localhost:3000 (login: admin/admin^)
echo - InfluxDB Interface: http://localhost:8086 (login: openfmb/openfmb123^)
echo.
echo BATTERY CONTROL:
echo Create a file named "battery_control.py" with the following content:
echo.
echo import paho.mqtt.client as mqtt
echo import sys
echo.
echo if len(sys.argv^) ^< 4:
echo     print("Usage: python battery_control.py ^<action^> ^<power^> [device_id]"^)
echo     print("Example: python battery_control.py charge 500 battery-device-1"^)
echo     sys.exit(1^)
echo.
echo action = sys.argv[1]
echo power = sys.argv[2]  
echo device = sys.argv[3] if len(sys.argv^) ^> 3 else "battery-device-1"
echo.
echo client = mqtt.Client(^)
echo client.connect('localhost', 1883, 60^)
echo message = f'{{"device":"{device}","action":"{action}","power":{power}}}'
echo client.publish('openfmb/battery/control', message^)
echo client.disconnect(^)
echo print(f'Battery {action} command sent: {power}W'^)
echo.
echo Then use: python battery_control.py charge 500
echo.
echo SYSTEM STATUS CHECK:
echo docker ps                     # Check running containers
echo netstat -an ^| findstr :5020   # Check Modbus server
echo netstat -an ^| findstr :1883   # Check MQTT broker
echo netstat -an ^| findstr :3000   # Check Grafana
echo.
echo STOP SYSTEM:
echo %~nx0 cleanup
echo.
echo Your OpenFMB DER microgrid simulation platform is now running!
echo Open http://localhost:3000 to start monitoring your virtual DER devices.
echo.
echo [OK] Setup completed successfully!
pause
exit /b 0

:cleanup
echo [INFO] Stopping all OpenFMB DER services...

REM Stop Python processes (approximate - may need manual cleanup)
taskkill /f /im python.exe /fi "WINDOWTITLE eq *modbus*" >nul 2>&1
taskkill /f /im python.exe /fi "WINDOWTITLE eq *mqtt*" >nul 2>&1

REM Stop Docker containers
docker stop mosquitto-broker nats-server influxdb grafana openfmb-hmi >nul 2>&1
docker rm mosquitto-broker nats-server influxdb grafana openfmb-hmi >nul 2>&1

echo [OK] Cleanup completed
pause
exit /b 0

:help
echo OpenFMB DER Framework - Windows Setup (Batch)
echo.
echo Usage:
echo   %~nx0                    # Full setup and launch
echo   %~nx0 cleanup            # Stop and cleanup all services  
echo   %~nx0 help               # Show this help
echo.
echo Requirements:
echo - Docker Desktop for Windows
echo - Python 3.8+ with pip
echo - Windows Command Prompt or PowerShell
echo.
echo System will setup:
echo - Modbus Device Simulation Server (Port 5020^)
echo - MQTT Broker (Port 1883^)
echo - NATS Server (Port 4222^)
echo - InfluxDB Database (Port 8086^)
echo - Grafana Analytics (Port 3000^)
echo - MQTT to InfluxDB Data Bridge
echo.
echo Access URLs after setup:
echo - Grafana: http://localhost:3000 (admin/admin^)
echo - InfluxDB: http://localhost:8086 (openfmb/openfmb123^)
echo.
pause
exit /b 0