#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=============================================="
echo "OpenFMB DER Framework - Full Stack Test"
echo "=============================================="
echo ""

# 1. Start visualization stack
echo "[STEP 1] Starting visualization stack (Grafana + InfluxDB)..."
./run_grafana_stack.sh
echo "[STEP 1] Waiting for services to be ready..."
sleep 5
# Wait for InfluxDB to be ready
for i in {1..10}; do
    if curl -s http://localhost:8086/ping > /dev/null 2>&1; then
        echo "[STEP 1] InfluxDB is ready."
        break
    fi
    echo "[STEP 1] Waiting for InfluxDB... ($i/10)"
    sleep 2
done
echo "[STEP 1] Visualization stack started."
echo ""

# 2. Start MQTT to InfluxDB bridge (background)
echo "[STEP 2] Starting MQTT to InfluxDB bridge..."
python mqtt_to_influx_bridge.py &
BRIDGE_PID=$!
sleep 3
echo "[STEP 2] MQTT to InfluxDB bridge started (PID: $BRIDGE_PID)."
echo ""

# 3. Run charge/discharge simulation
echo "[STEP 3] Running charge/discharge simulation (120s, 5s interval)..."
./charge_discharge_scenario.sh -d 120 -i 5
echo "[STEP 3] Charge/discharge simulation completed."
echo ""

# 4. CLI battery control - Charge
echo "[STEP 4a] Sending battery CHARGE command (1000W)..."
python battery_control_windows.py localhost 1883 ess-1 charge 1000
echo "[STEP 4a] Battery charge command sent."
echo ""

# 4. CLI battery control - Discharge
echo "[STEP 4b] Sending battery DISCHARGE command (500W)..."
python battery_control_windows.py localhost 1883 ess-1 discharge 500
echo "[STEP 4b] Battery discharge command sent."
echo ""

# 5. Ingest CSV test data
echo "[STEP 5] Ingesting CSV test data..."
if [ -f "test_data.csv" ]; then
    python ingest_open_data.py test_data.csv --mrid meter-1 --rate 1
    echo "[STEP 5] CSV data ingestion completed."
else
    echo "[STEP 5] Skipped - test_data.csv not found."
fi
echo ""

# 6. Open Grafana
echo "[STEP 6] Opening Grafana dashboard..."
echo "URL: http://localhost:3000"
echo "Login: admin / admin123"
open http://localhost:3000
echo "[STEP 6] Grafana opened in browser."
echo ""

echo "=============================================="
echo "Test Complete"
echo "=============================================="
echo ""
echo "To stop the MQTT bridge: kill $BRIDGE_PID"
echo "To stop all services: docker-compose down"
