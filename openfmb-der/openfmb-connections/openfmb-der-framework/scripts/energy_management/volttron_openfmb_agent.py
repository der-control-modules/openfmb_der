#!/usr/bin/env python3
"""
VOLTTRON OpenFMB Agent Example

This agent bridges VOLTTRON's internal message bus to OpenFMB MQTT.
It can:
1. Subscribe to VOLTTRON device topics and publish to OpenFMB MQTT
2. Subscribe to OpenFMB MQTT commands and forward to VOLTTRON

Requirements:
- VOLTTRON platform running
- pip install volttron paho-mqtt

To install in VOLTTRON:
  vctl install . --agent-config config.json --start
"""

import json
import logging
from datetime import datetime
from typing import Dict, Any

# VOLTTRON imports (uncomment when running in VOLTTRON)
# from volttron.platform.agent import utils
# from volttron.platform.vip.agent import Agent, Core, RPC
# from volttron.platform.messaging import headers as headers_mod

import paho.mqtt.client as mqtt

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class OpenFMBBridge:
    """
    Bridge between VOLTTRON and OpenFMB MQTT.
    
    This can run standalone or be integrated into a VOLTTRON agent.
    """
    
    def __init__(self, mqtt_host='localhost', mqtt_port=1883):
        self.mqtt_host = mqtt_host
        self.mqtt_port = mqtt_port
        self.mqtt_client = mqtt.Client()
        
        # Device MRIDs (would come from config in production)
        self.devices = {
            'solar': {
                'mrid': 'e294650b-dcf3-4bef-bd87-2c1fa2f5209e',
                'name': 'Solar PV Inverter'
            },
            'battery': {
                'mrid': 'e3853a47-9665-45d0-9429-33585c759f5d',
                'name': 'Battery ESS'
            },
            'meter': {
                'mrid': '59db1ade-953e-4ff9-930b-940d645cdcbb',
                'name': 'Smart Meter'
            }
        }
        
    def connect(self):
        """Connect to MQTT broker"""
        self.mqtt_client.connect(self.mqtt_host, self.mqtt_port, 60)
        self.mqtt_client.loop_start()
        logger.info(f"Connected to MQTT broker at {self.mqtt_host}:{self.mqtt_port}")
        
    def disconnect(self):
        """Disconnect from MQTT broker"""
        self.mqtt_client.loop_stop()
        self.mqtt_client.disconnect()
        
    # =========================================================================
    # VOLTTRON → OpenFMB (Publishing)
    # =========================================================================
    
    def publish_solar_reading(self, power: float, voltage: float = 240, current: float = 10):
        """
        Publish solar reading from VOLTTRON to OpenFMB.
        
        In VOLTTRON, this would be called when receiving data from:
        - devices/campus/building/solar/all
        """
        device = self.devices['solar']
        message = {
            "solarReadingProfile": {
                "identifiedObject": {
                    "mRID": device['mrid'],
                    "name": device['name']
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
        
        topic = f"openfmb/solarreadingprofile/{device['mrid']}"
        self.mqtt_client.publish(topic, json.dumps(message))
        logger.debug(f"Published solar reading: {power}W")
        
    def publish_battery_reading(self, soc: float, power: float, voltage: float = 48):
        """
        Publish battery reading from VOLTTRON to OpenFMB.
        
        In VOLTTRON, this would be called when receiving data from:
        - devices/campus/building/battery/all
        """
        device = self.devices['battery']
        message = {
            "essReadingProfile": {
                "identifiedObject": {
                    "mRID": device['mrid'],
                    "name": device['name']
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
        
        topic = f"openfmb/essreadingprofile/{device['mrid']}"
        self.mqtt_client.publish(topic, json.dumps(message))
        logger.debug(f"Published battery reading: {soc}% SOC, {power}W")
        
    def publish_meter_reading(self, power: float, voltage: float = 240, frequency: float = 60):
        """
        Publish meter reading from VOLTTRON to OpenFMB.
        
        In VOLTTRON, this would be called when receiving data from:
        - devices/campus/building/meter/all
        """
        device = self.devices['meter']
        message = {
            "meterReadingProfile": {
                "identifiedObject": {
                    "mRID": device['mrid'],
                    "name": device['name']
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
        
        topic = f"openfmb/meterreadingprofile/{device['mrid']}"
        self.mqtt_client.publish(topic, json.dumps(message))
        logger.debug(f"Published meter reading: {power}W")
        
    # =========================================================================
    # OpenFMB → VOLTTRON (Commands/Control)
    # =========================================================================
    
    def subscribe_to_controls(self, callback):
        """
        Subscribe to OpenFMB control profiles.
        
        When a control command comes from OpenFMB, forward to VOLTTRON actuator.
        """
        def on_message(client, userdata, msg):
            try:
                payload = json.loads(msg.payload.decode())
                topic_parts = msg.topic.split('/')
                profile_type = topic_parts[1] if len(topic_parts) > 1 else ''
                
                if 'esscontrolprofile' in profile_type.lower():
                    # Battery control command
                    callback('battery', payload)
                elif 'solarcontrolprofile' in profile_type.lower():
                    # Solar control command (curtailment)
                    callback('solar', payload)
                    
            except Exception as e:
                logger.error(f"Error processing control message: {e}")
                
        self.mqtt_client.on_message = on_message
        self.mqtt_client.subscribe("openfmb/+controlprofile/#")
        logger.info("Subscribed to OpenFMB control profiles")


# =============================================================================
# Example VOLTTRON Agent (Template)
# =============================================================================

"""
# Uncomment this section to create a full VOLTTRON agent

class OpenFMBAgent(Agent):
    '''
    VOLTTRON Agent that bridges to OpenFMB MQTT.
    '''
    
    def __init__(self, config_path, **kwargs):
        super().__init__(**kwargs)
        self.config = utils.load_config(config_path)
        self.bridge = OpenFMBBridge(
            mqtt_host=self.config.get('mqtt_host', 'localhost'),
            mqtt_port=self.config.get('mqtt_port', 1883)
        )
        
    @Core.receiver('onstart')
    def onstart(self, sender, **kwargs):
        '''Agent startup - connect to MQTT and subscribe to VOLTTRON topics'''
        self.bridge.connect()
        
        # Subscribe to VOLTTRON device topics
        self.vip.pubsub.subscribe(
            peer='pubsub',
            prefix='devices/campus/building/solar',
            callback=self.on_solar_data
        )
        self.vip.pubsub.subscribe(
            peer='pubsub',
            prefix='devices/campus/building/battery',
            callback=self.on_battery_data
        )
        self.vip.pubsub.subscribe(
            peer='pubsub',
            prefix='devices/campus/building/meter',
            callback=self.on_meter_data
        )
        
        # Subscribe to OpenFMB controls
        self.bridge.subscribe_to_controls(self.on_openfmb_control)
        
    def on_solar_data(self, peer, sender, bus, topic, headers, message):
        '''Handle solar data from VOLTTRON and publish to OpenFMB'''
        power = message[0].get('power', 0)
        voltage = message[0].get('voltage', 240)
        current = message[0].get('current', 10)
        self.bridge.publish_solar_reading(power, voltage, current)
        
    def on_battery_data(self, peer, sender, bus, topic, headers, message):
        '''Handle battery data from VOLTTRON and publish to OpenFMB'''
        soc = message[0].get('soc', 0)
        power = message[0].get('power', 0)
        voltage = message[0].get('voltage', 48)
        self.bridge.publish_battery_reading(soc, power, voltage)
        
    def on_meter_data(self, peer, sender, bus, topic, headers, message):
        '''Handle meter data from VOLTTRON and publish to OpenFMB'''
        power = message[0].get('power', 0)
        voltage = message[0].get('voltage', 240)
        frequency = message[0].get('frequency', 60)
        self.bridge.publish_meter_reading(power, voltage, frequency)
        
    def on_openfmb_control(self, device_type, payload):
        '''Handle OpenFMB control and forward to VOLTTRON actuator'''
        if device_type == 'battery':
            # Forward battery command to VOLTTRON actuator
            self.vip.rpc.call(
                'platform.actuator',
                'set_point',
                'openfmb_agent',
                'campus/building/battery/power_setpoint',
                payload.get('setpoint', 0)
            )

def main():
    utils.vip_main(OpenFMBAgent)

if __name__ == '__main__':
    main()
"""


# =============================================================================
# Standalone Test (without VOLTTRON)
# =============================================================================

if __name__ == '__main__':
    import time
    import random
    
    print("=" * 60)
    print("VOLTTRON-OpenFMB Bridge Standalone Test")
    print("=" * 60)
    print()
    print("This simulates VOLTTRON publishing device data to OpenFMB.")
    print("In production, this would receive data from VOLTTRON's pubsub.")
    print()
    
    bridge = OpenFMBBridge(mqtt_host='localhost', mqtt_port=1883)
    
    try:
        bridge.connect()
        print("Connected! Publishing simulated VOLTTRON data...")
        print()
        
        while True:
            # Simulate VOLTTRON device data
            solar_power = random.randint(1500, 3000)
            battery_soc = random.randint(50, 90)
            battery_power = random.randint(0, 1500)
            meter_power = random.randint(0, 1000)
            
            # Publish to OpenFMB (as if VOLTTRON sent the data)
            bridge.publish_solar_reading(solar_power)
            bridge.publish_battery_reading(battery_soc, battery_power)
            bridge.publish_meter_reading(meter_power)
            
            print(f"[VOLTTRON→OpenFMB] Solar: {solar_power}W | "
                  f"Battery: {battery_soc}% {battery_power}W | "
                  f"Meter: {meter_power}W")
            
            time.sleep(5)
            
    except KeyboardInterrupt:
        print("\nStopping...")
    finally:
        bridge.disconnect()
