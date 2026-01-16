#!/usr/bin/env python3
"""
OpenFMB DER Framework - Windows Battery Control Script

Cross-platform Python script for controlling battery devices via MQTT.
This replaces the bash script for Windows compatibility.

Usage:
    python battery_control_windows.py <mqtt_host> <mqtt_port> <device_id> <action> <power>

Examples:
    python battery_control_windows.py localhost 1883 battery-device-1 charge 500
    python battery_control_windows.py localhost 1883 battery-device-1 discharge 300
    python battery_control_windows.py localhost 1883 battery-device-1 stop 0
"""

import sys
import json
import time
import paho.mqtt.client as mqtt
from datetime import datetime

def print_status(status, message):
    """Print colored status messages"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] [{status}] {message}")

def on_connect(client, userdata, flags, rc):
    """MQTT connection callback"""
    if rc == 0:
        print_status("OK", "Connected to MQTT broker")
    else:
        print_status("ERROR", f"Failed to connect to MQTT broker (code: {rc})")

def on_publish(client, userdata, mid):
    """MQTT publish callback"""
    print_status("OK", f"Message published (mid: {mid})")

def on_disconnect(client, userdata, rc):
    """MQTT disconnect callback"""
    if rc != 0:
        print_status("WARNING", "Unexpected disconnection from MQTT broker")

def send_battery_command(mqtt_host, mqtt_port, device_id, action, power):
    """Send battery control command via MQTT"""
    
    # Validate action
    valid_actions = ['charge', 'discharge', 'stop', 'idle']
    if action.lower() not in valid_actions:
        print_status("ERROR", f"Invalid action '{action}'. Valid actions: {', '.join(valid_actions)}")
        return False
    
    # Validate power
    try:
        power_value = float(power)
        if power_value < 0:
            print_status("ERROR", "Power value cannot be negative")
            return False
    except ValueError:
        print_status("ERROR", f"Invalid power value '{power}'. Must be a number")
        return False
    
    # Create MQTT client
    client = mqtt.Client()
    client.on_connect = on_connect
    client.on_publish = on_publish
    client.on_disconnect = on_disconnect
    
    try:
        print_status("INFO", f"Connecting to MQTT broker at {mqtt_host}:{mqtt_port}")
        client.connect(mqtt_host, int(mqtt_port), 60)
        
        # Prepare control message
        control_message = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "device_id": device_id,
            "action": action.lower(),
            "power_watts": power_value,
            "source": "battery_control_windows",
            "message_id": f"bat_ctrl_{int(time.time())}"
        }
        
        # OpenFMB-style message for different topics
        topics_and_messages = [
            ("openfmb/battery/control", control_message),
            (f"openfmb/batterymodule/{device_id}/BatteryControl", {
                "identifiedObject": {"mRID": device_id},
                "batteryControl": {
                    "controlTimestamp": datetime.utcnow().isoformat() + "Z",
                    "island": False,
                    "batteryControlScheduleFSCC": {
                        "ValA": power_value if action != 'stop' else 0,
                        "ctlVal": action.lower()
                    }
                }
            }),
            (f"device/{device_id}/battery/command", {
                "command": action.lower(),
                "power": power_value,
                "timestamp": control_message["timestamp"]
            })
        ]
        
        # Publish to multiple topics for compatibility
        success_count = 0
        for topic, message in topics_and_messages:
            try:
                json_message = json.dumps(message, indent=None)
                result = client.publish(topic, json_message, qos=1)
                
                if result.rc == mqtt.MQTT_ERR_SUCCESS:
                    print_status("OK", f"Published to topic: {topic}")
                    success_count += 1
                else:
                    print_status("ERROR", f"Failed to publish to topic: {topic}")
                    
            except Exception as e:
                print_status("ERROR", f"Error publishing to {topic}: {str(e)}")
        
        # Wait a bit for message delivery
        client.loop_start()
        time.sleep(1)
        client.loop_stop()
        
        # Disconnect
        client.disconnect()
        
        if success_count > 0:
            print_status("SUCCESS", f"Battery control command sent successfully!")
            print_status("INFO", f"Device: {device_id}")
            print_status("INFO", f"Action: {action.upper()}")
            print_status("INFO", f"Power: {power_value}W")
            print_status("INFO", f"Published to {success_count} topics")
            return True
        else:
            print_status("ERROR", "Failed to publish to any topics")
            return False
            
    except Exception as e:
        print_status("ERROR", f"Failed to send battery command: {str(e)}")
        return False

def show_help():
    """Show help information"""
    help_text = """
OpenFMB DER Framework - Battery Control (Windows)

USAGE:
    python battery_control_windows.py <mqtt_host> <mqtt_port> <device_id> <action> <power>

PARAMETERS:
    mqtt_host    : MQTT broker hostname or IP (e.g., localhost, 192.168.1.100)
    mqtt_port    : MQTT broker port (typically 1883)
    device_id    : Battery device identifier (e.g., battery-device-1)
    action       : Control action (charge, discharge, stop, idle)
    power        : Power in watts (positive number, 0 for stop)

EXAMPLES:
    # Charge battery at 500W
    python battery_control_windows.py localhost 1883 battery-device-1 charge 500
    
    # Discharge battery at 300W
    python battery_control_windows.py localhost 1883 battery-device-1 discharge 300
    
    # Stop battery operation
    python battery_control_windows.py localhost 1883 battery-device-1 stop 0
    
    # Set battery to idle mode
    python battery_control_windows.py localhost 1883 battery-device-1 idle 0

VALID ACTIONS:
    charge    : Charge the battery (requires positive power value)
    discharge : Discharge the battery (requires positive power value)  
    stop      : Stop all battery operation (power should be 0)
    idle      : Set battery to idle state (power should be 0)

NOTES:
    - Ensure MQTT broker is running before sending commands
    - Commands are published to multiple OpenFMB-compatible topics
    - Check Grafana dashboard to verify command execution
    - Power values are in watts (W)

TROUBLESHOOTING:
    - Verify MQTT broker is accessible: telnet <mqtt_host> <mqtt_port>
    - Check if device exists in your system configuration
    - Monitor MQTT traffic: Use MQTT client tools to verify message delivery
    - View logs in Grafana or InfluxDB for command processing status
"""
    print(help_text)

def main():
    """Main function"""
    
    # Check for help
    if len(sys.argv) == 1 or sys.argv[1].lower() in ['-h', '--help', 'help']:
        show_help()
        return 0
    
    # Check arguments
    if len(sys.argv) != 6:
        print_status("ERROR", "Incorrect number of arguments")
        print("\nUsage: python battery_control_windows.py <mqtt_host> <mqtt_port> <device_id> <action> <power>")
        print("Use 'python battery_control_windows.py --help' for detailed help")
        return 1
    
    mqtt_host = sys.argv[1]
    mqtt_port = sys.argv[2]
    device_id = sys.argv[3]
    action = sys.argv[4]
    power = sys.argv[5]
    
    print_status("START", "OpenFMB DER Battery Control")
    print_status("INFO", f"Target: {mqtt_host}:{mqtt_port}")
    print_status("INFO", f"Device: {device_id}")
    print_status("INFO", f"Command: {action.upper()} {power}W")
    
    # Send command
    success = send_battery_command(mqtt_host, mqtt_port, device_id, action, power)
    
    if success:
        print_status("COMPLETE", "Battery control operation completed successfully")
        return 0
    else:
        print_status("FAILED", "Battery control operation failed")
        return 1

if __name__ == "__main__":
    try:
        exit_code = main()
        sys.exit(exit_code)
    except KeyboardInterrupt:
        print_status("INFO", "Operation cancelled by user")
        sys.exit(130)
    except Exception as e:
        print_status("ERROR", f"Unexpected error: {str(e)}")
        sys.exit(1)