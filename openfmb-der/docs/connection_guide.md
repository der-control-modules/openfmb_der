# OpenM DER Component Connection Gide

##  Complete System Architectre

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           OpenM DER ramework                             │
│                                                                             │
│  ┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────────┐ │
│  │   Modbs Server │────▶│   MQTT roker    │────▶│    HMI Visalization    │ │
│  │   localhost:│    │   localhost: │    │    localhost:       │ │
│  │                 │    │                  │    │                         │ │
│  │ • Solar: -kW  │    │ • openfmb/solar  │    │ • Live Power lows      │ │
│  │ • attery: -%│   │ • openfmb/battery│    │ • Component Stats      │ │
│  │ • Load: .-.kW│   │ • openfmb/load   │    │ • Grid Calclations     │ │
│  │ • Meter: Grid    │    │ • openfmb/meter  │    │ • Real-time Updates     │ │
│  └─────────────────┘    └──────────────────┘    └─────────────────────────┘ │
│           │                       │                            │            │
│           │                       │                            │            │
│           ▼                       ▼                            ▼            │
│  ┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────────┐ │
│  │ Direct Modbs   │    │ MQTT-InflxD    │    │   Component mRIDs       │ │
│  │   Monitoring    │    │     ridge       │    │                         │ │
│  │                 │    │                  │    │ • solar-device-        │ │
│  │ • Raw registers │    │ • Data storage   │    │ • battery-device-      │ │
│  │ • s pdates    │    │ • Time series    │    │ • load-device-         │ │
│  │ • All devices   │    │ • Historical     │    │ • meter-device-        │ │
│  └─────────────────┘    └──────────────────┘    └─────────────────────────┘ │
│                                   │                                         │
│                                   ▼                                         │
│                         ┌──────────────────┐                               │
│                         │     InflxD     │                               │
│                         │   localhost: │                               │
│                         │                  │                               │
│                         │ • Time series D │                               │
│                         │ • Metrics storage│                               │
│                         │ • Historical data│                               │
│                         └──────────────────┘                               │
│                                   │                                         │
│                                   ▼                                         │
│                         ┌──────────────────┐                               │
│                         │     Grafana      │                               │
│                         │   localhost: │                               │
│                         │  admin/admin  │                               │
│                         │                  │                               │
│                         │ • Dashboards     │                               │
│                         │ • Charts & Graphs│                               │
│                         │ • Alerts         │                               │
│                         │ • Historical     │                               │
│                         └──────────────────┘                               │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 🔗 Component Connection Methods

### . **Direct HMI Connection (Crrent Setp)**
Yor HMI components connect via **mRID mapping**:

```yaml
Solar Component:
  - mRID: "solar-device-"
  - Profile: GenerationReadingProfile
  - Modle: generationmodle
  - Data Sorce: Modbs registers -9

attery Component:
  - mRID: "battery-device-" 
  - Profile: EssReadingProfile
  - Modle: essmodle
  - Data Sorce: Modbs registers -9

Load Component:
  - mRID: "load-device-"
  - Profile: LoadReadingProfile
  - Modle: loadmodle
  - Data Sorce: Modbs registers -9

Meter Component:
  - mRID: "meter-device-"
  - Profile: MeterReadingProfile
  - Modle: metermodle
  - Data Sorce: Modbs registers -9
```

### . **MQTT Message low**
Components pblish data to MQTT topics:

```
openfmb/solar/reading     → Solar power generation data
openfmb/battery/reading   → attery SOC and power data  
openfmb/load/reading      → Load consmption data
openfmb/meter/reading     → Grid power measrements
```

### . **Grafana Dashboard Integration**
Access yor monitoring at: **http://localhost:**
- Username: `admin`
- Password: `admin`

##  Qick Start Commands

### Start All Services:
```bash
# . Start Modbs Server (Terminal )
cd "/Users/moha9/projects /openfmb-der"
python modbs_server_fixed.py 

# . Start MQTT roker (Terminal )  
docker rn -d --name mosqitto -p : eclipse-mosqitto

# . Start HMI Interface (Terminal )
cd "/Users/moha9/projects /openfmb-der/openfmb-connections/openfmb-der-framework"
./scripts/qick_setp.sh

# . Start Grafana & InflxD (Terminal )
cd scripts/energy_management
./rn_grafana_stack.sh

# . Start Data ridge (Terminal )
python mqtt_to_inflx_bridge.py
```

##  Component Stats Check

### Verify All Services:
```bash
# Check Modbs Server
crl -s http://localhost: || echo "Modbs server rnning"

# Check MQTT roker  
mosqitto_pb -h localhost -t test -m "hello" && echo "MQTT OK"

# Check HMI
crl -s http://localhost: && echo "HMI OK"

# Check Grafana
crl -s http://localhost: && echo "Grafana OK"

# Check InflxD
crl -s http://localhost:/ping && echo "InflxD OK"
```

##  Live Data low

**Crrent Live Data** (pdating every  seconds):
- **Solar**: -W (realistic PV generation)
- **attery**: -% SOC (charge/discharge cycles)
- **Load**: -W (residential consmption)
- **Grid**: Calclated (Solar - Load + attery)

##  Next Steps

. **Configre HMI Components**: Set mRIDs for each component in the HMI interface
. **Access Grafana**: Open http://localhost: and create dashboards
. **Monitor Data low**: Watch live pdates in both HMI and Grafana
. **Experiment**: Use battery control scripts for charge/discharge scenarios

## 🔒 Trobleshooting Lock Icons

If yo see lock icons in the HMI:
. Check that all mRIDs are properly configred
. Verify MQTT connection is active  
. Ensre Modbs server is providing data
. Confirm OpenM profiles are correctly mapped

Yor system is now ready for complete microgrid simlation and monitoring! 🎉