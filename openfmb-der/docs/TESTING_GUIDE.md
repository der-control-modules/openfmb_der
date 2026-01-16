# Testing Guide: Grafana and OpenFMB HMI

## Part 1: Testing with Grafana

### Step 1: Access Grafana Dashboard

1. **Open Grafana in your browser:**
   ```
   http://localhost:3000
   ```

2. **Login with default credentials:**
   - Username: `admin`
   - Password: `admin`
   - You'll be prompted to change the password (you can skip this for testing)

### Step 2: Configure InfluxDB Data Source

1. **Navigate to Data Sources:**
   - Click the gear icon (⚙️) in the left sidebar
   - Select "Data Sources"
   - Click "Add data source"

2. **Select InfluxDB:**
   - Search for "InfluxDB" in the list
   - Click on it

3. **Configure the connection:**
   ```
   Name: InfluxDB-OpenFMB
   
   HTTP:
   - URL: http://influxdb:8086
     (or http://localhost:8086 if the first doesn't work)
   
   InfluxDB Details:
   - Database: openfmb
   - User: openfmb
   - Password: openfmb123
   
   HTTP Method: GET
   ```

4. **Save & Test:**
   - Scroll down and click "Save & Test"
   - You should see a green message: "Data source is working"

### Step 3: Import Pre-Built Dashboard

1. **Import the dashboard:**
   - Click the "+" icon in the left sidebar
   - Select "Import"
   - Click "Upload JSON file"
   - Navigate to: `openfmb-connections/openfmb-der-framework/scripts/energy_management/grafana_dashboard_fixed.json`
   - Click "Load"

2. **Select data source:**
   - In the "InfluxDB" dropdown, select "InfluxDB-OpenFMB"
   - Click "Import"

3. **View the dashboard:**
   - You should now see panels showing:
     * Battery Power (W)
     * State of Charge (%)
     * Current Power Status
     * Battery voltage and other metrics

### Step 4: Create a Custom Panel (Manual Testing)

If you want to create your own visualization:

1. **Create a new dashboard:**
   - Click "+" → "Dashboard" → "Add new panel"

2. **Configure the query:**
   ```sql
   Query Language: InfluxQL
   
   FROM: default power
   WHERE: mrid = 'battery-device-1'
   SELECT: field(value) mean()
   GROUP BY: time($__interval) fill(null)
   FORMAT AS: Time series
   ```

3. **Customize visualization:**
   - Choose visualization type (Time series, Gauge, Stat, etc.)
   - Set units (watts, percent, etc.)
   - Configure colors and thresholds
   - Click "Apply"

### Step 5: Test Live Data

1. **Verify data is flowing:**
   - Open the dashboard you imported
   - Set time range to "Last 5 minutes" (top right)
   - Enable auto-refresh: Set to "5s" or "10s" (top right dropdown)

2. **Check for live updates:**
   - You should see graphs updating in real-time
   - Battery SOC should be cycling between 70-85%
   - Power values should be changing

3. **If no data appears:**
   ```bash
   # Check if MQTT bridge is running
   ps aux | grep mqtt_to_influx_bridge
   
   # Check InfluxDB for data
   docker exec -it influxdb influx
   > USE openfmb
   > SHOW MEASUREMENTS
   > SELECT * FROM power LIMIT 10
   > exit
   ```

### Step 6: Test Battery Control Impact

1. **Open terminal and send battery command:**
   ```bash
   cd openfmb-connections/openfmb-der-framework/scripts/energy_management
   ./battery_control.sh localhost 1883 battery-device-1 charge 750
   ```

2. **Watch Grafana dashboard:**
   - The battery power graph should show the change
   - SOC should start increasing if charging
   - Look for the control command's impact on the visualization

### Step 7: Create Alerts (Advanced)

1. **Add alert to a panel:**
   - Edit any panel
   - Go to "Alert" tab
   - Create alert rule
   - Example: Alert if battery SOC < 20%

2. **Configure notification channel:**
   - Go to Alerting → Notification channels
   - Add email, Slack, or webhook notifications

---

## Part 2: Testing with OpenFMB HMI

### Step 1: Check HMI Status

1. **Check if HMI container is available:**
   ```bash
   docker ps | grep hmi
   ```

2. **If not running, try to start it:**
   ```bash
   docker run -d --name openfmb-hmi \
     -p 8080:8080 \
     -v "$PWD/openfmb-connections/openfmb-der-framework/scripts/der_configs/hmi_server:/config" \
     --network host \
     oesinc/openfmb.hmi:latest
   ```

   **Note:** The HMI container may have ARM64 compatibility issues on Apple Silicon Macs.

### Step 2: Access HMI Interface (if running)

1. **Open HMI in browser:**
   ```
   http://localhost:8080
   ```

2. **Default login (if required):**
   - Check `openfmb-connections/openfmb-der-framework/scripts/der_configs/hmi_server/users.json`
   - Typical defaults: `admin` / `admin`

### Step 3: HMI Configuration

1. **Load equipment configuration:**
   - The HMI reads from: `der_configs/hmi_server/equipment.json`
   - This defines your DER devices (solar, battery, load, meter)

2. **Load diagram configuration:**
   - Diagrams are stored in: `der_configs/hmi_server/diagrams/`
   - These show visual representations of your microgrid

### Step 4: Test HMI Functionality

1. **View live device status:**
   - Navigate through the HMI interface
   - Look for device status indicators
   - Check real-time measurements

2. **Send control commands:**
   - Use HMI control buttons (if available)
   - Commands are sent via NATS/MQTT to devices
   - Verify commands execute properly

3. **Monitor system topology:**
   - View single-line diagrams
   - See power flow visualizations
   - Check connection status of devices

### Step 5: Alternative - Use Web MQTT Monitor

If HMI is not available, use the lightweight web monitor:

1. **Open the MQTT monitor:**
   ```bash
   cd openfmb-connections/openfmb-der-framework/scripts/der_configs/web
   open mqtt_monitor.html
   ```

2. **Configure connection:**
   - Host: `localhost`
   - Port: `9001` (WebSocket port)
   - Click "Connect"

3. **Subscribe to topics:**
   - Topic: `openfmb/#`
   - You'll see all OpenFMB messages in real-time

### Step 6: HMI Troubleshooting

**If HMI won't start:**

1. **Check logs:**
   ```bash
   docker logs openfmb-hmi
   ```

2. **Verify NATS connection:**
   ```bash
   # Test NATS connectivity
   curl http://localhost:8222/varz
   ```

3. **Check configuration files:**
   ```bash
   # Verify HMI config exists
   cat openfmb-connections/openfmb-der-framework/scripts/der_configs/hmi_server/app.toml
   ```

4. **Alternative: Use Grafana instead:**
   - Grafana provides similar functionality
   - More stable and widely supported
   - Better for data visualization

---

## Part 3: End-to-End Testing Workflow

### Complete Test Scenario

1. **Start with Grafana open** (http://localhost:3000)

2. **Monitor baseline data:**
   - Watch battery SOC (should be cycling)
   - Note current power levels

3. **Send charge command:**
   ```bash
   ./battery_control.sh localhost 1883 battery-device-1 charge 1000
   ```

4. **Observe in Grafana:**
   - Battery power should increase
   - SOC should trend upward
   - Grid power should adjust accordingly

5. **Send discharge command:**
   ```bash
   ./battery_control.sh localhost 1883 battery-device-1 discharge 500
   ```

6. **Verify response:**
   - Battery power goes negative (discharging)
   - SOC decreases
   - Load is being met by battery

7. **Check data persistence:**
   ```bash
   # Query InfluxDB directly
   docker exec -it influxdb influx -database openfmb -execute "SELECT * FROM power WHERE time > now() - 5m"
   ```

### Testing Checklist

- [ ] Grafana accessible at localhost:3000
- [ ] InfluxDB data source configured and working
- [ ] Dashboard showing live data
- [ ] Data updates every 3-5 seconds
- [ ] Battery control commands execute successfully
- [ ] Control commands visible in Grafana graphs
- [ ] Historical data queryable in InfluxDB
- [ ] Alerts configured (optional)
- [ ] HMI accessible (if compatible)
- [ ] MQTT messages visible via monitor

---

## Part 4: Advanced Testing

### Performance Testing

1. **Test data throughput:**
   ```bash
   # Monitor MQTT message rate
   mosquitto_sub -h localhost -p 1883 -t 'openfmb/#' -v | pv -l > /dev/null
   ```

2. **Check InfluxDB write performance:**
   ```bash
   docker exec -it influxdb influx -execute "SHOW STATS"
   ```

### Integration Testing

1. **Test multiple device controls:**
   ```bash
   # Charge battery
   ./battery_control.sh localhost 1883 battery-device-1 charge 800
   
   # Wait 10 seconds
   sleep 10
   
   # Discharge battery
   ./battery_control.sh localhost 1883 battery-device-1 discharge 400
   ```

2. **Verify in Grafana:**
   - Should see distinct charge/discharge patterns
   - Power transitions should be smooth

### Stress Testing

1. **Send rapid commands:**
   ```bash
   for i in {1..10}; do
     ./battery_control.sh localhost 1883 battery-device-1 charge $((500 + i*50))
     sleep 2
   done
   ```

2. **Monitor system resources:**
   ```bash
   docker stats
   ```

---

## Quick Reference Commands

```bash
# Check all services
docker ps

# View Modbus server output
tail -f /Users/moha907/projects\ /openfmb-der/modbus_server.log

# Monitor MQTT messages
mosquitto_sub -h localhost -p 1883 -t 'openfmb/#' -v

# Query InfluxDB
docker exec -it influxdb influx -database openfmb -execute "SELECT * FROM power LIMIT 5"

# Send battery command
cd openfmb-connections/openfmb-der-framework/scripts/energy_management
./battery_control.sh localhost 1883 battery-device-1 charge 750

# Restart bridge if needed
pkill -f mqtt_to_influx_bridge
python mqtt_to_influx_bridge.py &
```

---

## Expected Results

**Successful Grafana Test:**
- Dashboard loads with multiple panels
- Live data visible and updating every 3-5 seconds
- Battery SOC cycles between 70-85%
- Solar power varies between 1-3 kW
- Control commands cause visible changes in graphs
- No error messages in Grafana logs

**Successful HMI Test (if available):**
- HMI interface loads at localhost:8080
- Device status indicators show green/connected
- Single-line diagram displays correctly
- Control buttons responsive
- Real-time data matches Modbus server output
- Commands execute and devices respond

---

## Troubleshooting Tips

**Grafana shows "No Data":**
- Check InfluxDB data source connection
- Verify MQTT bridge is running
- Ensure database name is correct: `openfmb`
- Check time range (use "Last 5 minutes")

**HMI won't start:**
- Check Docker logs: `docker logs openfmb-hmi`
- Verify ARM64 compatibility (may not work on Apple Silicon)
- Use Grafana as alternative visualization
- Check NATS server is running: `docker ps | grep nats`

**Data not updating:**
- Verify Modbus server is running: `lsof -i :5020`
- Check MQTT broker: `docker ps | grep mosquitto`
- Restart MQTT bridge if needed
- Check InfluxDB is accepting writes

Your OpenFMB DER framework is now ready for comprehensive testing!