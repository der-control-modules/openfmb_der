#!/usr/bin/env python3
"""
OpenFMB DER Integration Bridge
Reads Modbus data and publishes to MQTT for OpenFMB HMI and stores in InfluxDB for Grafana

Integration Flow:
    Modbus Device/Simulator --> This Bridge --> MQTT (OpenFMB HMI)
                                           --> InfluxDB (Grafana)
"""

import json
import time
import sys
import signal
from datetime import datetime
import uuid

# Modbus client
from pymodbus.client.sync import ModbusTcpClient

# MQTT client
import paho.mqtt.client as mqtt

# InfluxDB client
try:
    from influxdb import InfluxDBClient
    INFLUX_AVAILABLE = True
except ImportError:
    INFLUX_AVAILABLE = False
    print("[WARN] InfluxDB client not available. Install with: pip install influxdb")

# Configuration
MODBUS_HOST = "localhost"
MODBUS_PORT = 5020
MQTT_HOST = "localhost"
MQTT_PORT = 1883
INFLUX_HOST = "localhost"
INFLUX_PORT = 8086
INFLUX_DB = "openfmb"
INFLUX_USER = "openfmb"
INFLUX_PASS = "openfmb123"

# Device MRIDs (unique identifiers)
SOLAR_MRID = str(uuid.uuid4())
ESS_MRID = str(uuid.uuid4())
LOAD_MRID = str(uuid.uuid4())
METER_MRID = str(uuid.uuid4())

running = True

def signal_handler(sig, frame):
    global running
    print("\n[EXIT] Shutting down bridge...")
    running = False

signal.signal(signal.SIGINT, signal_handler)

def create_openfmb_solar_reading(mrid, power, voltage, current):
    """Create OpenFMB SolarReadingProfile message"""
    return {
        "solarReadingProfile": {
            "identifiedObject": {
                "mRID": mrid,
                "name": "Solar PV Inverter"
            },
            "solarReading": {
                "readingMessageInfo": {
                    "messageTimeStamp": datetime.utcnow().isoformat() + "Z"
                },
                "solarReadingMMXU": {
                    "W": {"mag": power},
                    "PhV": {"mag": voltage},
                    "A": {"mag": current}
                }
            }
        }
    }

def create_openfmb_ess_reading(mrid, soc, power, voltage):
    """Create OpenFMB ESSReadingProfile message"""
    return {
        "essReadingProfile": {
            "identifiedObject": {
                "mRID": mrid,
                "name": "Battery ESS"
            },
            "essReading": {
                "readingMessageInfo": {
                    "messageTimeStamp": datetime.utcnow().isoformat() + "Z"
                },
                "essReadingMMXU": {
                    "W": {"mag": power},
                    "PhV": {"mag": voltage}
                },
                "stateOfCharge": {"mag": soc}
            }
        }
    }

def create_openfmb_meter_reading(mrid, power, voltage, frequency):
    """Create OpenFMB MeterReadingProfile message"""
    return {
        "meterReadingProfile": {
            "identifiedObject": {
                "mRID": mrid,
                "name": "Smart Meter"
            },
            "meterReading": {
                "readingMessageInfo": {
                    "messageTimeStamp": datetime.utcnow().isoformat() + "Z"
                },
                "meterReadingMMXU": {
                    "W": {"mag": power},
                    "PhV": {"mag": voltage},
                    "Hz": {"mag": frequency}
                }
            }
        }
    }

def main():
    print("=" * 60)
    print("OpenFMB DER Integration Bridge")
    print("=" * 60)
    print(f"Modbus:   {MODBUS_HOST}:{MODBUS_PORT}")
    print(f"MQTT:     {MQTT_HOST}:{MQTT_PORT}")
    print(f"InfluxDB: {INFLUX_HOST}:{INFLUX_PORT}/{INFLUX_DB}")
    print("-" * 60)
    print(f"Solar MRID:  {SOLAR_MRID}")
    print(f"ESS MRID:    {ESS_MRID}")
    print(f"Meter MRID:  {METER_MRID}")
    print("-" * 60)
    
    # Connect to Modbus
    modbus_client = ModbusTcpClient(MODBUS_HOST, port=MODBUS_PORT)
    if not modbus_client.connect():
        print("[ERROR] Failed to connect to Modbus device")
        return
    print("[OK] Connected to Modbus device")
    
    # Connect to MQTT
    mqtt_client = mqtt.Client()
    try:
        mqtt_client.connect(MQTT_HOST, MQTT_PORT, 60)
        mqtt_client.loop_start()
        print("[OK] Connected to MQTT broker")
    except Exception as e:
        print(f"[ERROR] Failed to connect to MQTT: {e}")
        return
    
    # Connect to InfluxDB
    influx_client = None
    if INFLUX_AVAILABLE:
        try:
            influx_client = InfluxDBClient(
                host=INFLUX_HOST, 
                port=INFLUX_PORT,
                username=INFLUX_USER,
                password=INFLUX_PASS,
                database=INFLUX_DB
            )
            influx_client.ping()
            print("[OK] Connected to InfluxDB")
        except Exception as e:
            print(f"[WARN] InfluxDB not available: {e}")
            influx_client = None
    
    print("-" * 60)
    print("Publishing data to OpenFMB HMI and Grafana...")
    print("Press Ctrl+C to stop")
    print("-" * 60)
    
    cycle = 0
    while running:
        try:
            # Read Solar registers (0-4)
            solar_result = modbus_client.read_holding_registers(0, 5, unit=1)
            if not solar_result.isError():
                solar_power = solar_result.registers[0]
                solar_voltage = solar_result.registers[1]
                solar_current = solar_result.registers[2]
                
                # Publish to MQTT for OpenFMB HMI
                solar_msg = create_openfmb_solar_reading(
                    SOLAR_MRID, solar_power, solar_voltage, solar_current
                )
                mqtt_client.publish(
                    f"openfmb/solarreadingprofile/{SOLAR_MRID}",
                    json.dumps(solar_msg)
                )
                
                # Store in InfluxDB for Grafana
                if influx_client:
                    influx_client.write_points([{
                        "measurement": "solar",
                        "tags": {"mrid": SOLAR_MRID, "device": "solar-1"},
                        "fields": {
                            "power": float(solar_power),
                            "voltage": float(solar_voltage),
                            "current": float(solar_current)
                        }
                    }])
            
            # Read Battery registers (10-14)
            ess_result = modbus_client.read_holding_registers(10, 5, unit=1)
            if not ess_result.isError():
                ess_soc = ess_result.registers[0]
                ess_power = ess_result.registers[1]
                ess_voltage = ess_result.registers[2]
                
                # Publish to MQTT for OpenFMB HMI
                ess_msg = create_openfmb_ess_reading(
                    ESS_MRID, ess_soc, ess_power, ess_voltage
                )
                mqtt_client.publish(
                    f"openfmb/essreadingprofile/{ESS_MRID}",
                    json.dumps(ess_msg)
                )
                
                # Store in InfluxDB for Grafana
                if influx_client:
                    influx_client.write_points([{
                        "measurement": "ess",
                        "tags": {"mrid": ESS_MRID, "device": "ess-1"},
                        "fields": {
                            "soc": float(ess_soc),
                            "power": float(ess_power),
                            "voltage": float(ess_voltage)
                        }
                    }])
            
            # Read Meter registers (30-34)
            meter_result = modbus_client.read_holding_registers(30, 5, unit=1)
            if not meter_result.isError():
                meter_power = meter_result.registers[0]
                meter_voltage = meter_result.registers[1]
                meter_freq = meter_result.registers[2]
                
                # Publish to MQTT for OpenFMB HMI
                meter_msg = create_openfmb_meter_reading(
                    METER_MRID, meter_power, meter_voltage, meter_freq
                )
                mqtt_client.publish(
                    f"openfmb/meterreadingprofile/{METER_MRID}",
                    json.dumps(meter_msg)
                )
                
                # Store in InfluxDB for Grafana
                if influx_client:
                    influx_client.write_points([{
                        "measurement": "meter",
                        "tags": {"mrid": METER_MRID, "device": "meter-1"},
                        "fields": {
                            "power": float(meter_power),
                            "voltage": float(meter_voltage),
                            "frequency": float(meter_freq)
                        }
                    }])
            
            # Print status every 5 cycles
            if cycle % 5 == 0:
                print(f"[{cycle:4d}] Solar:{solar_power:5d}W | ESS:{ess_soc:3d}% {ess_power:5d}W | Grid:{meter_power:5d}W")
            
            cycle += 1
            time.sleep(2)
            
        except Exception as e:
            print(f"[ERROR] {e}")
            time.sleep(5)
    
    # Cleanup
    modbus_client.close()
    mqtt_client.loop_stop()
    mqtt_client.disconnect()
    print("[EXIT] Bridge stopped")

if __name__ == "__main__":
    main()
