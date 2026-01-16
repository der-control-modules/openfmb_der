#!/bin/bash
set -e
docker network inspect openfmb >/dev/null 2>&1 || docker network create openfmb
docker run -d --name influxdb --network openfmb -p 8086:8086 \
  -e INFLUXDB_DB=openfmb -e INFLUXDB_ADMIN_USER=admin -e INFLUXDB_ADMIN_PASSWORD=admin123 \
  -e INFLUXDB_USER=openfmb -e INFLUXDB_USER_PASSWORD=openfmb123 \
  -v influxdb-data:/var/lib/influxdb influxdb:1.8 >/dev/null 2>&1 || true
docker run -d --name grafana --network openfmb -p 3000:3000 \
  -e GF_SECURITY_ADMIN_PASSWORD=admin123 -v grafana-data:/var/lib/grafana grafana/grafana:latest >/dev/null 2>&1 || true
echo "Grafana: http://localhost:3000 (admin/admin123)"