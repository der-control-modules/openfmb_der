#!/usr/bin/env python3
import json
import time
import random
import subprocess
from datetime import datetime

MQTT_HOST = "localhost"
MQTT_PORT = 1883
INTERVAL = 3

print("[START] Publishing live DER data...")
print(f"MQTT: {MQTT_HOST}:{MQTT_PORT}")
print(f"Interval: {INTERVAL}s\n")

i = 0
while True:
    try:
        ts = int(time.time())
        
        # Generate realistic data
        solar_power = 2000 + random.randint(0, 1500)
        battery_soc = 70 + (i % 20)
        battery_power = random.randint(-1000, 1000)
        load_power = 1500 + random.randint(0, 1000)
        grid_power = solar_power - load_power + battery_power
        
        # Publish using subprocess (more reliable than paho mqtt)
        messages = [
            ("openfmb/solarstatusprofile/solar-pv-001", {
                "solarInverter": {"mRID": "solar-pv-001", "solarReading": {"mmxu": {"w": {"mag": solar_power}}}}
            }),
            ("openfmb/essstatusprofile/a6a7f5f4-2601-45d2-9445-ca147f32c783", {
                "essStatus": {"mRID": "a6a7f5f4-2601-45d2-9445-ca147f32c783", 
                             "essReading": {"mmxu": {"w": {"mag": battery_power}}, "soc": {"mag": battery_soc}}}
            }),
            ("openfmb/meterstatusprofile/grid-meter-001", {
                "meterReading": {"mRID": "grid-meter-001", "readingMMXU": {"w": {"mag": grid_power}}}
            })
        ]
        
        for topic, payload in messages:
            cmd = ["docker", "exec", "openfmb-mosquitto", "mosquitto_pub", 
                   "-h", "localhost", "-t", topic, "-m", json.dumps(payload)]
            subprocess.run(cmd, capture_output=True, timeout=2)
        
        if i % 10 == 0:
            ts_str = datetime.now().strftime('%H:%M:%S')
            print(f"[{ts_str}] Solar:{solar_power:4d}W | Battery:{battery_power:+5d}W ({battery_soc}%) | Grid:{grid_power:+5d}W")
        
        i += 1
        time.sleep(INTERVAL)
        
    except KeyboardInterrupt:
        print("\n[STOP] Publisher stopped")
        break
    except Exception as e:
        print(f"[ERROR] {e}")
        time.sleep(INTERVAL)
