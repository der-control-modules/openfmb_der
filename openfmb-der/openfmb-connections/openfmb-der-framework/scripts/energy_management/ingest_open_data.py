"""
Publish CSV time-series data to MQTT topics for testing.
Expected CSV format: timestamp,power_w,mrid
"""
import csv
import time
import json
import argparse
from paho.mqtt import client as mqtt_client

BROKER = 'localhost'
PORT = 1883
TOPIC_TEMPLATE = 'openfmb/telemetry/meter/{mrid}'


def publish_from_csv(path, mrid, rate_hz=1):
    client = mqtt_client.Client(f'ingest-{mrid}')
    client.connect(BROKER, PORT)
    with open(path, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            payload = {'timestamp': row.get('timestamp'), 'power_w': float(row.get('power_w', 0)), 'mrid': mrid}
            topic = TOPIC_TEMPLATE.format(mrid=mrid)
            client.publish(topic, json.dumps(payload))
            print('Published', payload)
            time.sleep(1 / rate_hz)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('csv', help='Path to CSV file')
    parser.add_argument('--mrid', default='TEST_METER', help='MRID to publish under')
    parser.add_argument('--rate', type=float, default=1.0, help='Publish rate Hz')
    args = parser.parse_args()
    publish_from_csv(args.csv, args.mrid, args.rate)
