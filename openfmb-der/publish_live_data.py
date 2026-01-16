#!/usr/bin/env python3
"""
Live DER Data Publisher - Publishes realistic DER data to MQTT
"""
import paho.mqtt.client as mqtt
import json
import time
import random
from datetime import datetime

MQTT_HOST = "localhost"
MQTT_PORT = 1883
INTERVAL = 3  # seconds

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("[OK] Connected to MQTT broker")
    else:
        print(f"[ERROR] Connection failed with code {rc}")

def publish_der_data(client):
    """Publish realistic DER device data"""
    i = 0
    print(f"\n[START] Publishing live DER data every {INTERVAL}s...")
    print("Press Ctrl+C to stop\n")
    
    while True:
        try:
            ts = int(time.time())
            
            # Generate realistic data
            solar_power = 2000 + random.randint(0, 1500)  # 2-3.5kW
            battery_soc = 70 + (i % 20)  # 70-90%
            battery_power = random.randint(-1000, 1000)  # -1kW to +1kW (charge/discharge)
            load_power = 1500 + random.randint(0, 1000)  # 1.5-2.5kW
            grid_power = solar_power - load_power + battery_power
            
            # Publish Solar PV data
            solar_msg = {
                "controlTimestamp": {"seconds": ts, "nanos": 0},
                "solarInverter": {
                    "mRID": "solar-pv-001",
                    "solarReading": {
                        "mmxu": {
                            "w": {"mag": solar_power, "unit": "W"}
                        }
                    }
                }
            }
            client.publish("openfmb/solarstatusprofile/solar-pv-001", json.dumps(solar_msg))
            
            # Publish Battery ESS data
            ess_msg = {
                "controlTimestamp": {"seconds": ts, "nanos": 0},
                "essStatus": {
                    "mRID": "a6a7f5f4-2601-45d2-9445-ca147f32c783",
                    "essReading": {
                        "mmxu": {
                            "w": {"mag": battery_power, "unit": "W"}
                        },
                        "soc": {"mag": battery_soc, "unit": "percent"}
                    }
                }
            }
            client.publish("openfmb/essstatusprofile/a6a7f5f4-2601-45d2-9445-ca147f32c783", json.dumps(ess_msg))
            
            # Publish Grid Meter data
            meter_msg = {
                "controlTimestamp": {"seconds": ts, "nanos": 0},
                "meterReading": {
                    "mRID": "grid-meter-001",
                    "readingMMXU": {
                        "w": {"mag": grid_power, "unit": "W"}
                    }
                }
            }
            client.publish("openfmb/meterstatusprofile/grid-meter-001", json.dumps(meter_msg))
            
            # Print status every 10 iterations
            if i % 10 == 0:
                timestamp = datetime.now().strftime('%H:%M:%S')
                print(f"[{timestamp}] Solar:{solar_power:4d}W | Battery:{battery_power:+5d}W ({battery_soc:2d}%) | Load:{load_power:4d}W | Grid:{grid_power:+5d}W")
            
            i += 1
            time.sleep(INTERVAL)
            
        except KeyboardInterrupt:
            print("\n[STOP] Publisher stopped by user")
            break
        except Exception as e:
            print(f"[ERROR] {e}")
            time.sleep(INTERVAL)

def main():
    client = mqtt.Client()
    client.on_connect = on_connect
    
    try:
        client.connect(MQTT_HOST, MQTT_PORT, 60)
        client.loop_start()
        time.sleep(1)  # Wait for connection
        
        publish_der_data(client)
        
    except KeyboardInterrupt:
        print("\n[STOP] Shutting down...")
    except Exception as e:
        print(f"[ERROR] {e}")
    finally:
        client.loop_stop()
        client.disconnect()
        print("[EXIT] Publisher stopped")

if __name__ == "__main__":
    main()
