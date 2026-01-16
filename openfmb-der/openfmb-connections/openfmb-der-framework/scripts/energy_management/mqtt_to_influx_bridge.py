#!/usr/bin/env python3
"""
MQTT to InfluxDB Bridge for OpenFMB DER Framework
Subscribes to OpenFMB MQTT topics and stores data in InfluxDB
"""

import json
import time
import sys
import signal
from datetime import datetime

try:
    import paho.mqtt.client as mqtt
    from influxdb import InfluxDBClient
except ImportError:
    print("Installing required packages...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "paho-mqtt", "influxdb"])
    import paho.mqtt.client as mqtt
    from influxdb import InfluxDBClient

# Configuration
MQTT_HOST = "localhost"
MQTT_PORT = 1883
INFLUX_HOST = "localhost"
INFLUX_PORT = 8086
INFLUX_DB = "openfmb"
INFLUX_USER = "openfmb"
INFLUX_PASS = "openfmb123"

# Global variables
influx_client = None
running = True

def signal_handler(sig, frame):
    global running
    print("\nShutting down bridge...")
    running = False
    sys.exit(0)

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print(f"[OK] Connected to MQTT broker at {MQTT_HOST}:{MQTT_PORT}")
        client.subscribe("openfmb/#")
        print("[INFO] Subscribed to openfmb/#")
    else:
        print(f"[ERROR] Failed to connect to MQTT broker, return code {rc}")

def parse_openfmb_message(topic, payload):
    """Parse OpenFMB message and extract relevant data"""
    try:
        data = json.loads(payload)
        parts = topic.split('/')
        
        if len(parts) < 3:
            return None
        
        # Handle simple flat JSON format (mrid, power, soc fields directly in data)
        if 'mrid' in data and 'power' in data:
            mrid = data['mrid']
            device_type = data.get('device_type', 'unknown')
            profile_type = data.get('profile_type', 'unknown')
            
            points = []
            timestamp = int(time.time() * 1000000000)
            
            points.append({
                "measurement": "power",
                "tags": {
                    "mrid": mrid,
                    "profile_type": profile_type,
                    "device_type": device_type
                },
                "time": timestamp,
                "fields": {
                    "value": float(data['power'])
                }
            })
            
            if 'soc' in data:
                points.append({
                    "measurement": "soc",
                    "tags": {
                        "mrid": mrid,
                        "profile_type": profile_type,
                        "device_type": device_type
                    },
                    "time": timestamp,
                    "fields": {
                        "value": float(data['soc'])
                    }
                })
            
            return points
            
        profile_type = parts[1]  # e.g., essstatusprofile, solarstatusprofile
        mrid = parts[2]
        
        points = []
        timestamp = int(time.time() * 1000000000)  # nanoseconds for InfluxDB
        
        # Extract power data
        power = None
        soc = None
        
        # For ESS (Battery) data
        if 'essStatus' in data or 'essReading' in data:
            ess_data = data.get('essStatus', data.get('essReading', {}))
            if 'essReading' in ess_data:
                mmxu = ess_data['essReading'].get('mmxu', {})
                if 'w' in mmxu:
                    power = mmxu['w'].get('mag')
                soc_data = ess_data['essReading'].get('soc', {})
                if 'mag' in soc_data:
                    soc = soc_data['mag']
        
        # For Solar data
        elif 'solarInverter' in data:
            solar_data = data['solarInverter']
            if 'solarReading' in solar_data:
                mmxu = solar_data['solarReading'].get('mmxu', {})
                if 'w' in mmxu:
                    power = mmxu['w'].get('mag')
        
        # For Meter data
        elif 'meterReading' in data:
            meter_data = data['meterReading']
            if 'readingMMXU' in meter_data:
                mmxu = meter_data['readingMMXU']
                if 'w' in mmxu:
                    power = mmxu['w'].get('mag')
        
        # Create InfluxDB points
        if power is not None:
            points.append({
                "measurement": "power",
                "tags": {
                    "mrid": mrid,
                    "profile_type": profile_type,
                    "device_type": profile_type.replace('statusprofile', '').replace('controlprofile', '')
                },
                "time": timestamp,
                "fields": {
                    "value": float(power)
                }
            })
        
        if soc is not None:
            points.append({
                "measurement": "soc",
                "tags": {
                    "mrid": mrid,
                    "profile_type": profile_type,
                    "device_type": "ess"
                },
                "time": timestamp,
                "fields": {
                    "value": float(soc)
                }
            })
        
        return points
        
    except Exception as e:
        print(f"[ERROR] Error parsing message: {e}")
        return None

def on_message(client, userdata, msg):
    """Handle incoming MQTT messages"""
    try:
        topic = msg.topic
        payload = msg.payload.decode('utf-8')
        
        print(f"[MSG] {datetime.now().strftime('%H:%M:%S')} - {topic}")
        
        # Parse the OpenFMB message
        points = parse_openfmb_message(topic, payload)
        
        if points and influx_client:
            # Write to InfluxDB
            influx_client.write_points(points)
            for point in points:
                measurement = point['measurement']
                value = point['fields']['value']
                device_type = point['tags']['device_type']
                print(f"[STORE] Stored: {device_type} {measurement}={value}")
        
    except Exception as e:
        print(f"[ERROR] Error processing message: {e}")

def main():
    global influx_client
    
    print("[START] Starting OpenFMB MQTT to InfluxDB Bridge")
    print(f"MQTT: {MQTT_HOST}:{MQTT_PORT}")
    print(f"InfluxDB: {INFLUX_HOST}:{INFLUX_PORT}/{INFLUX_DB}")
    print("-" * 50)
    
    # Setup signal handler
    signal.signal(signal.SIGINT, signal_handler)
    
    try:
        # Connect to InfluxDB
        influx_client = InfluxDBClient(
            host=INFLUX_HOST,
            port=INFLUX_PORT,
            username=INFLUX_USER,
            password=INFLUX_PASS,
            database=INFLUX_DB
        )
        
        # Test InfluxDB connection
        influx_client.ping()
        print("[OK] Connected to InfluxDB")
        
        # Setup MQTT client
        mqtt_client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION1)
        mqtt_client.on_connect = on_connect
        mqtt_client.on_message = on_message
        
        print(f"[INFO] Connecting to MQTT broker at {MQTT_HOST}:{MQTT_PORT}...")
        
        # Connect to MQTT
        mqtt_client.connect(MQTT_HOST, MQTT_PORT, 60)
        
        # Start the loop
        print("[INFO] Starting MQTT client loop...")
        mqtt_client.loop_forever()
        
    except KeyboardInterrupt:
        print("\n[STOP] Bridge stopped by user")
    except Exception as e:
        print(f"[ERROR] Error: {e}")
    finally:
        print("[EXIT] Bridge shutdown complete")

if __name__ == "__main__":
    main()
