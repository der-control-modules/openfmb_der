# Manual Device Setup for OpenFMB HMI

## Devices to Create in HMI

### 1. Solar PV Device
- **Name**: Solar
- **Type**: solar  
- **MRID**: solar-device-1
- **Modbus Host**: localhost
- **Modbus Port**: 5020
- **Unit ID**: 1
- **Register Start**: 0
- **Description**: Solar PV Inverter (2.5kW)

### 2. Battery ESS Device  
- **Name**: Battery
- **Type**: ess
- **MRID**: battery-device-1  
- **Modbus Host**: localhost
- **Modbus Port**: 5020
- **Unit ID**: 1
- **Register Start**: 10
- **Description**: Battery Energy Storage System

### 3. Load Device
- **Name**: Load
- **Type**: load
- **MRID**: load-device-1
- **Modbus Host**: localhost  
- **Modbus Port**: 5020
- **Unit ID**: 1
- **Register Start**: 20
- **Description**: Building Load

### 4. Meter Device
- **Name**: Meter
- **Type**: meter
- **MRID**: meter-device-1
- **Modbus Host**: localhost
- **Modbus Port**: 5020  
- **Unit ID**: 1
- **Register Start**: 30
- **Description**: Grid Interconnection Meter

### 5. Switch Device  
- **Name**: Switch
- **Type**: switch
- **MRID**: switch-device-1
- **Modbus Host**: localhost
- **Modbus Port**: 5020
- **Unit ID**: 1  
- **Register Start**: 40
- **Description**: Main Disconnect Switch

## Data Mapping

### Solar (Registers 0-9)
- Register 0: Power Output (W)
- Register 1: Voltage (V) 
- Register 2: Current (A)

### Battery (Registers 10-19)  
- Register 10: State of Charge (%)
- Register 11: Power (W) - positive=discharge, negative=charge
- Register 12: Voltage (V)
- Register 13: Current (A)

### Load (Registers 20-29)
- Register 20: Power Consumption (W)
- Register 21: Voltage (V)
- Register 22: Current (A)

### Meter (Registers 30-39)
- Register 30: Grid Power (W) 
- Register 31: Voltage (V)
- Register 32: Frequency (Hz)

## Modbus Server Status
✅ Running on localhost:5020
✅ Simulating realistic DER data
✅ Data updates every 3 seconds