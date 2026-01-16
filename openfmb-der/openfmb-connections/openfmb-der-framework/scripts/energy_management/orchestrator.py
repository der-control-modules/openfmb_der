"""
Minimal MQTT orchestrator to coordinate charge/discharge between two ESS devices.
- Subscribes to telemetry topics
- Implements a simple rule: if excess generation (meter) > threshold, charge target ESS; if shortage, discharge source ESS
- Publishes control commands to battery control topic

This is a minimal template — adapt decision logic to your needs.
"""

import json
import time
import threading
from typing import Dict
import paho.mqtt.client as mqtt

BROKER = "localhost"
PORT = 1883
TELEMETRY_TOPICS = [
    "openfmb/telemetry/meter/#",
    "openfmb/telemetry/ess/#",
]
CONTROL_TOPIC_TEMPLATE = "openfmb/control/ess/{mrid}"

# Simple in-memory state
state: Dict[str, Dict] = {
    "meter": {},
    "ess": {},
}

# Configurable thresholds
CHARGE_THRESHOLD = 1000.0  # Watts of excess to trigger charge
DISCHARGE_THRESHOLD = -1000.0  # Watts deficit to trigger discharge

# MRIDs for source and target ESS (replace with real MRIDs)
SOURCE_ESS_MRID = "ESS_SOURCE_MRID"
TARGET_ESS_MRID = "ESS_TARGET_MRID"

client = mqtt.Client(client_id="openfmb-orchestrator")


def on_connect(c, userdata, flags, rc):
    print("Connected to MQTT broker", rc)
    for t in TELEMETRY_TOPICS:
        c.subscribe(t)


def on_message(c, userdata, msg):
    topic = msg.topic
    try:
        payload = msg.payload.decode("utf-8")
        data = json.loads(payload)
    except Exception:
        # Not JSON or unexpected format — ignore
        return

    if topic.startswith("openfmb/telemetry/meter/"):
        mrid = topic.split("/")[-1]
        state["meter"][mrid] = data
    elif topic.startswith("openfmb/telemetry/ess/"):
        mrid = topic.split("/")[-1]
        state["ess"][mrid] = data


def decide_and_act():
    while True:
        # Very simple rule: use a single meter average to decide
        for mrid, m in state["meter"].items():
            # Assume payload contains 'power_w' positive means generation
            power = float(m.get("power_w", 0))
            if power > CHARGE_THRESHOLD:
                # Charge target ESS
                cmd = {"action": "charge", "power_w": min(2000, power)}
                publish_control(TARGET_ESS_MRID, cmd)
            elif power < DISCHARGE_THRESHOLD:
                # Discharge source ESS
                cmd = {"action": "discharge", "power_w": min(2000, abs(power))}
                publish_control(SOURCE_ESS_MRID, cmd)
        time.sleep(2)


def publish_control(mrid: str, cmd: Dict):
    topic = CONTROL_TOPIC_TEMPLATE.format(mrid=mrid)
    payload = json.dumps(cmd)
    client.publish(topic, payload)
    print(f"Published {payload} to {topic}")


client.on_connect = on_connect
client.on_message = on_message
client.connect(BROKER, PORT)

# Run decision loop in background
threading.Thread(target=decide_and_act, daemon=True).start()

try:
    client.loop_forever()
except KeyboardInterrupt:
    client.disconnect()
