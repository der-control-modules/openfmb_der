#!/usr/bin/env python3
"""
Simple Modbus TCP server simulator for OpenFMB DER devices
Simulates Solar, Battery, Load, and Meter data
"""

from pymodbus.server import StartAsyncTcpServer
from pymodbus.datastore import (
    ModbusSequentialDataBlock,
    ModbusSlaveContext,
    ModbusServerContext,
)
import asyncio
import threading
import time
import sys
import random

def parse_port():
    """Parse port from command line, default 5020"""
    try:
        if len(sys.argv) > 1:
            return int(sys.argv[1])
    except ValueError:
        print(f"Invalid port '{sys.argv[1]}', falling back to 5020")
    return 5020

PORT = parse_port()

# Create device context with realistic DER data
device_context = ModbusSlaveContext(
    di=ModbusSequentialDataBlock(0, [0] * 100),  # Discrete inputs
    co=ModbusSequentialDataBlock(0, [0] * 100),  # Coils
    hr=ModbusSequentialDataBlock(0, [0] * 100),  # Holding registers
    ir=ModbusSequentialDataBlock(0, [0] * 100)   # Input registers
)

# Initialize with DER data
# Solar: registers 0-9 (power, voltage, current)
device_context.setValues(3, 0, [2500, 240, 10, 0, 0, 0, 0, 0, 0, 0])

# Battery: registers 10-19 (SOC%, power, voltage, current) 
device_context.setValues(3, 10, [75, 1000, 48, 20, 0, 0, 0, 0, 0, 0])

# Load: registers 20-29 (power consumption)
device_context.setValues(3, 20, [1800, 240, 7, 0, 0, 0, 0, 0, 0, 0])

# Meter: registers 30-39 (grid power, voltage, frequency)
device_context.setValues(3, 30, [700, 240, 60, 0, 0, 0, 0, 0, 0, 0])

# Create server context
context = ModbusServerContext(slaves=device_context, single=True)

def updater():
    """Simulate changing DER values"""
    i = 0
    while True:
        try:
            # Simulate solar power (1-3kW based on time of day simulation)
            solar_power = 2000 + random.randint(-500, 1000)
            device_context.setValues(3, 0, [solar_power])
            
            # Simulate battery SOC (70-85%)
            battery_soc = 70 + (i % 15)
            battery_power = random.randint(-2000, 2000)  # Charge/discharge
            device_context.setValues(3, 10, [battery_soc, abs(battery_power)])
            
            # Simulate load variations (1.5-2.5kW)
            load_power = 1500 + random.randint(0, 1000)
            device_context.setValues(3, 20, [load_power])
            
            # Calculate grid power (simplified)
            grid_power = max(0, solar_power - load_power)
            device_context.setValues(3, 30, [grid_power])
            
            if i % 5 == 0:
                print(f"[{i:3d}] Solar:{solar_power:4d}W | Battery:{battery_soc:2d}% | Load:{load_power:4d}W | Grid:{grid_power:4d}W")
            
            i += 1
            time.sleep(3)
        except Exception as e:
            print(f"[updater] Error: {e}")
            break

if __name__ == "__main__":
    print(f"Starting Modbus TCP server on localhost:{PORT}")
    print("Device simulation:")
    print("  Solar PV    - Registers 0-9   (Unit ID 1)")
    print("  Battery ESS - Registers 10-19 (Unit ID 1)")  
    print("  Load        - Registers 20-29 (Unit ID 1)")
    print("  Meter       - Registers 30-39 (Unit ID 1)")
    print("Press Ctrl+C to stop\n")
    
    # Start the data updater in background
    updater_thread = threading.Thread(target=updater, daemon=True)
    updater_thread.start()
    
    # Start the Modbus server
    try:
        asyncio.run(StartAsyncTcpServer(context=context, address=("localhost", PORT)))
    except KeyboardInterrupt:
        print("\nServer stopped by user")
    except Exception as e:
        print(f"Server error: {e}")