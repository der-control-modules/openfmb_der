# OpenFMB DER Framework

## Overview
The OpenFMB DER Framework provides a modular environment for distributed energy resource (DER) management, simulation, monitoring, and control. It supports various DER configurations, including Solar PV Inverters, Battery Energy Storage Systems (ESS), Smart Switches/Breakers, Load Controllers, and Smart Meters. The framework leverages containerized adapters, MQTT messaging, and time-series data storage for scalable and flexible energy management.

## Features
- **Quick Setup Script**: The `quick_setup.sh` script offers a menu-driven interface for easy configuration of different DER types and complete stacks with MQTT, NATS, and HMI.
- **Energy Management**: Includes scripts for managing battery actions and simulating data for various DER types, facilitating effective energy management and visualization.
- **Monitoring Tools**: Integration with Grafana and InfluxDB for real-time monitoring and visualization of energy data.
- **Cross-Platform Compatibility**: Supports macOS, Windows (via Git Bash, PowerShell, or WSL), and Linux.

## Architecture

- **Adapters**: Each DER type (ESS, Solar, Load, Meter, Switch) is managed by a dedicated adapter container, configured via YAML files.
- **MQTT Broker**: Serves as the central message bus for all DER communications.
- **Energy Management Scripts**: Shell and Python scripts for device control, data simulation, and bridging MQTT data to InfluxDB.
- **HMI Server**: Provides a web-based interface for real-time monitoring and control.
- **Grafana & InfluxDB**: Collects and visualizes time-series data for analytics and historical review.
- **Web Monitor**: HTML-based MQTT topic monitor for quick diagnostics.

## Directory Structure
```
openfmb-der-framework
├── scripts
│   ├── quick_setup.sh            # Main setup script (macOS/Linux/Git Bash)
│   ├── quick_setup.ps1           # PowerShell version for Windows
│   ├── quick_setup.bat           # Windows batch wrapper
│   ├── setup_der_clean.sh        # Cleanup script for existing setups
│   ├── energy_management         # Scripts for energy management
│   │   ├── battery_control.sh    # Control battery actions via MQTT
│   │   ├── simulate_data.sh      # Simulate data for different DER types
│   │   ├── run_grafana_stack.sh  # Setup Grafana and InfluxDB stack
│   │   └── mqtt_to_influx_bridge.py # Bridge MQTT data to InfluxDB
│   └── der_configs               # Configuration files for DERs
│       ├── .env                  # Environment variables for DER configurations
│       ├── adapter-*.yaml        # Configuration files for different DER types
│       ├── hmi_server            # HMI server configuration
│       │   └── app.toml          # HMI application configuration
│       ├── templates             # Modbus configuration templates
│       └── web                   # Web-based MQTT monitor
│           └── mqtt_monitor.html
└── README.md                     # Documentation for the project
```

## Getting Started

### Prerequisites
- **Docker Desktop**: Install Docker Desktop for your platform:
  - macOS: [Docker Desktop for Mac](https://docs.docker.com/desktop/install/mac-install/)
  - Windows: [Docker Desktop for Windows](https://docs.docker.com/desktop/install/windows-install/)
  - Linux: [Docker Engine](https://docs.docker.com/engine/install/)

### Quick Setup (Cross-Platform)

#### For macOS and Linux:
```bash
git clone <repository-url>
cd openfmb-der-framework
chmod +x scripts/quick_setup.sh
./scripts/quick_setup.sh
```

#### For Windows:
**Option 1: Using Git Bash (Recommended)**
```bash
./scripts/quick_setup.sh
```
**Option 2: Using PowerShell**
```powershell
.\scripts\quick_setup.ps1
```
**Option 3: Using WSL (Windows Subsystem for Linux)**
```bash
./scripts/quick_setup.sh
```

### Platform-Specific Notes
- Windows: Git Bash is recommended for full compatibility with the bash script.
- macOS/Linux: Native bash support, works out of the box.
- All platforms: Ensure Docker Desktop is running before executing scripts.

## Usage

### Running the Setup
Choose the appropriate method for your platform:
```bash
# For macOS/Linux or Windows Git Bash
./scripts/quick_setup.sh

# For Windows PowerShell (limited features)
.\scripts\quick_setup.ps1
```

### Workflow

1. **Adapters** publish and subscribe to MQTT topics for DER status and control.
2. **Energy management scripts** interact with adapters via MQTT for simulation and control.
3. **MQTT to InfluxDB bridge** subscribes to relevant topics and stores parsed data in InfluxDB.
4. **Grafana** visualizes historical and real-time data from InfluxDB.
5. **HMI** provides operational control and monitoring for all connected DERs.

### Script Features
The quick setup script provides an interactive menu to guide you through:
- Individual DER type configurations (Solar, ESS, Switch, Load, Meter)
- Complete stack deployment (MQTT + NATS + HMI)
- Energy management and visualization tools
- Cross-platform Docker container management

Refer to the individual script files for specific usage instructions and configurations.

### Energy Management
- Control and simulate DERs using provided scripts:
  - Battery control:
    ```bash
    ./scripts/energy_management/battery_control.sh localhost 1883 <mrid> <charge|discharge|stop>
    ```
  - Data simulation:
    ```bash
    ./scripts/energy_management/simulate_data.sh
    ```

### Data Bridge
- Start the MQTT to InfluxDB bridge to enable time-series data storage:
  ```bash
  python3 ./scripts/energy_management/mqtt_to_influx_bridge.py
  ```

### Grafana & InfluxDB
- Start the stack:
  ```bash
  ./scripts/energy_management/run_grafana_stack.sh
  ```
- Access Grafana at [http://localhost:3000](http://localhost:3000) (default login: admin/admin123).
- Configure InfluxDB as the data source:
  - URL: `http://influxdb:8086`
  - Database: `openfmb`
  - User: `openfmb`
  - Password: `openfmb123`
- Create panels to visualize battery power, state of charge, and other metrics.

### HMI
- Access the HMI dashboard at [http://127.0.0.1:8080](http://127.0.0.1:8080) (default login: admin/hm1admin).
- Use the HMI to monitor device status, send control commands, and review system topology.

## Troubleshooting

- Ensure Docker is running and accessible.
- Verify MQTT broker is active on port 1883.
- Confirm InfluxDB and Grafana containers are running.
- Check that the MQTT to InfluxDB bridge is subscribed and writing data.
- Review logs for each container and script for error messages.


