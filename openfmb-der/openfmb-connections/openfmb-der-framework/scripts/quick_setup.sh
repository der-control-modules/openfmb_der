#!/bin/bash
# Clean Quick Setup with spec-accurate HMI configuration

set -e

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_SCRIPT="${SCRIPT_DIR}/setup_der_clean.sh"

print_status(){ echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning(){ echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error(){ echo -e "${RED}[ERROR]${NC} $1"; }
print_header(){ echo -e "${BLUE}[SETUP]${NC} $1"; }

print_banner() {
  echo -e "${BLUE}=============================================="
  echo "OpenFMB DER Quick Setup (Clean)"
  echo -e "==============================================${NC}\n"
}

print_menu() {
  cat <<EOF
Select DER configuration:
1) Solar PV Inverter
2) Battery Energy Storage System (ESS)
3) Smart Switch/Breaker
4) Load Controller
5) Smart Meter
6) Custom Configuration
7) View Example Commands
8) Setup Complete Stack (MQTT + NATS + HMI)
9) Energy Mgmt & Visualization (Grafana/Influx + scripts)
10) Exit

EOF
}

detect_platform() {
  # Detect OS first
  case "$(uname -s 2>/dev/null || echo 'Windows')" in
    Darwin)  # macOS
      case "$(uname -m)" in
        x86_64) echo "linux/amd64" ;;
        arm64) echo "linux/arm64" ;;
        *) echo "linux/amd64" ;;
      esac
      ;;
    Linux)
      case "$(uname -m)" in
        x86_64) echo "linux/amd64" ;;
        arm64|aarch64) echo "linux/arm64" ;;
        *) echo "linux/amd64" ;;
      esac
      ;;
    MINGW*|MSYS*|CYGWIN*|Windows*)  # Windows (Git Bash, WSL, etc.)
      echo "linux/amd64"  # Default to amd64 for Windows
      ;;
    *)
      echo "linux/amd64"  # Default fallback
      ;;
  esac
}

check_docker() {
  # Cross-platform Docker detection
  if command -v docker >/dev/null 2>&1; then
    if docker info >/dev/null 2>&1; then
      print_status "Docker OK"
    else
      print_error "Docker not running. Please start Docker Desktop."
      exit 1
    fi
  else
    case "$(uname -s 2>/dev/null || echo 'Windows')" in
      Darwin)
        print_error "Docker not installed. Install Docker Desktop for Mac from https://docker.com"
        ;;
      MINGW*|MSYS*|CYGWIN*|Windows*)
        print_error "Docker not installed. Install Docker Desktop for Windows from https://docker.com"
        ;;
      *)
        print_error "Docker not installed. Please install Docker."
        ;;
    esac
    exit 1
  fi
}

pull_docker_images() {
  print_header "Pulling images"
  local p=$(detect_platform)
  docker pull --platform $p eclipse-mosquitto:latest
  docker pull --platform $p oesinc/openfmb.adapters:latest
  docker pull --platform $p nats:latest
  docker pull --platform $p oesinc/openfmb.hmi || { print_warning "HMI image pull failed"; return 1; }
  docker pull --platform $p influxdb:1.8
  docker pull --platform $p grafana/grafana:latest
  return 0
}

cleanup_existing() {
  print_header "Cleanup"
  
  # Stop MQTT bridge if running
  if [ -f "${SCRIPT_DIR}/energy_management/mqtt_bridge.pid" ]; then
    local pid=$(cat "${SCRIPT_DIR}/energy_management/mqtt_bridge.pid")
    kill $pid 2>/dev/null || true
    rm -f "${SCRIPT_DIR}/energy_management/mqtt_bridge.pid"
  fi
  
  # Stop Modbus server if running
  if [ -f "${SCRIPT_DIR}/modbus_server.pid" ]; then
    local pid=$(cat "${SCRIPT_DIR}/modbus_server.pid")
    kill $pid 2>/dev/null || true
    rm -f "${SCRIPT_DIR}/modbus_server.pid"
  fi
  
  for c in openfmb-mosquitto nats-server openfmb-hmi grafana influxdb \
            openfmb-solar-adapter openfmb-ess-adapter openfmb-switch-adapter \
            openfmb-load-adapter openfmb-meter-adapter; do
    docker rm -f "$c" >/dev/null 2>&1 || true
  done
  docker network rm openfmb >/dev/null 2>&1 || true
}

create_network() {
  docker network inspect openfmb >/dev/null 2>&1 || docker network create openfmb
}

start_mqtt_broker() {
  docker ps --format '{{.Names}}' | grep -q '^openfmb-mosquitto$' || \
  docker run -d --name openfmb-mosquitto --network openfmb -p 1883:1883 -p 9001:9001 eclipse-mosquitto:latest
  print_status "MQTT broker on 1883"
}

start_nats_server() {
  docker ps --format '{{.Names}}' | grep -q '^nats-server$' || \
  docker run -d --name nats-server --network openfmb -p 4222:4222 nats:latest
  print_status "NATS on 4222"
}

# Create app.toml exactly as in instructions, with dynamic URIs & environment
write_hmi_app_toml() {
  local dir="$1" env_choice="$2" prod_uri="$3" dev_uri="$4"
  mkdir -p "$dir"
  cat > "${dir}/app.toml" <<EOF
[hmi]
app_name = "OpenFMB HMI"
environment = "dev"

[nats]
dev_uri  = "nats-server:4222"
prod_uri = "nats-server:4222"
EOF
}

start_hmi() {
  print_header "Starting HMI"
  local host_port=${1:-80}
  local cfg_dir="scripts/der_configs/hmi_server"
  local default_prod="10.0.0.1:4222"
  local default_dev="192.168.86.1:4222"
  read -p "HMI environment (dev/prod) [dev]: " HMI_ENV; HMI_ENV=${HMI_ENV:-dev}
  read -p "NATS prod URI [${default_prod}]: " HMI_PROD; HMI_PROD=${HMI_PROD:-$default_prod}
  read -p "NATS dev  URI [${default_dev}]: " HMI_DEV;  HMI_DEV=${HMI_DEV:-$default_dev}
  write_hmi_app_toml "$cfg_dir" "$HMI_ENV" "$HMI_PROD" "$HMI_DEV"
  docker rm -f openfmb-hmi >/dev/null 2>&1 || true
  docker run -d --name openfmb-hmi --network openfmb \
    -p ${host_port}:80 \
    -e APP_CONF=/server/app.toml \
    -e APP_DIR_NAME=/server \
    -v "$(cd "$cfg_dir" && pwd):/server" \
    oesinc/openfmb.hmi
  local url="http://127.0.0.1"; [[ $host_port != 80 ]] && url="http://127.0.0.1:${host_port}"
  print_status "HMI running -> ${url} (admin/hm1admin)"
  echo "Config: ${cfg_dir}/app.toml (edit environment & restart container to switch)"
}

create_simple_monitor() {
  mkdir -p scripts/der_configs/web
  [ -f scripts/der_configs/web/mqtt_monitor.html ] && return 0
  cat > scripts/der_configs/web/mqtt_monitor.html <<'EOF'
<!DOCTYPE html><html><head><meta charset="utf-8"/><title>OpenFMB MQTT Monitor</title>
<style>body{font-family:Arial;margin:10px}#log{height:400px;overflow:auto;border:1px solid #ccc;padding:6px;font:12px monospace}</style></head>
<body><h3>OpenFMB MQTT Monitor</h3>
<input id="u" value="ws://localhost:9001" size="30"/>
<button onclick="c()">Connect</button>
<button onclick="d()">Disconnect</button>
<input id="t" value="openfmb/+/+/+" size="25"/>
<button onclick="s()">Subscribe</button>
<div id="st">Disconnected</div><div id="log"></div>
<script src="https://unpkg.com/mqtt@4.3.7/dist/mqtt.min.js"></script>
<script>
let client;function log(l){const e=document.getElementById('log');e.innerHTML+=l+'<br>';e.scrollTop=e.scrollHeight;}
function set(v){document.getElementById('st').innerText=v;}
function c(){client=mqtt.connect(document.getElementById('u').value);
client.on('connect',()=>{set('Connected');s();});
client.on('message',(t,m)=>log(new Date().toISOString()+' | '+t+' | '+m));
client.on('close',()=>set('Disconnected'));
client.on('error',e=>set('Error '+e.message));}
function d(){client&&client.end();}
function s(){client&&client.subscribe(document.getElementById('t').value);}
</script></body></html>
EOF
}

verify_or_create_config() {
  local der=$1 ip=$2 port=$3 devid=$4 mqtt_host=$5 mqtt_port=$6
  mkdir -p scripts/der_configs/templates
  local base="scripts/der_configs"
  [ -f "$base/adapter-${der}.yaml" ] || {
    # Cross-platform UUID generation
    local mrid
    if command -v uuidgen >/dev/null 2>&1; then
      mrid=$(uuidgen | tr '[:upper:]' '[:lower:]')
    elif command -v python3 >/dev/null 2>&1; then
      mrid=$(python3 -c "import uuid; print(str(uuid.uuid4()))")
    elif command -v python >/dev/null 2>&1; then
      mrid=$(python -c "import uuid; print str(uuid.uuid4())")
    else
      # Fallback: generate a simple UUID-like string
      mrid=$(date +%s | sha256sum 2>/dev/null | cut -c1-32 | sed 's/\(.{8}\)\(.{4}\)\(.{4}\)\(.{4}\)\(.{12}\)/\1-\2-\3-\4-\5/' || echo "$(date +%s)-$(($RANDOM*$RANDOM))")
    fi
    echo "MRID=${mrid}" > "$base/.env"
    cat > "$base/adapter-${der}.yaml" <<EOF
plugins:
  - name: mqtt-publisher
    path: ./mqtt-publisher.so
    config:
      broker: { host: ${mqtt_host}, port: ${mqtt_port} }
      topic_prefix: openfmb
      client_id: openfmb-${der}-client
EOF
  }
  [ -f "$base/templates/modbus-${der}-template.yaml" ] || cat > "$base/templates/modbus-${der}-template.yaml" <<EOF
sessions:
  - session:
      channel: { name: channel, adapter: "${ip}", port: ${port} }
      timeout: 5000
      profile:
        - name: "${der}_profile"
          mRID: "$(grep ^MRID $base/.env | cut -d= -f2)"
          unitId: ${devid}
          integrity_period: 5000
EOF
}

fix_adapter_container() {
  local der=$1
  local cfg="$(cd scripts/der_configs && pwd)"
  docker rm -f openfmb-${der}-adapter >/dev/null 2>&1 || true
  docker run -d --name openfmb-${der}-adapter --network openfmb \
    -v "${cfg}:/cfg" oesinc/openfmb.adapters:latest -c /cfg/adapter-${der}.yaml
}

display_enhanced_summary() {
  local der=$1 ip=$2 port=$3 devid=$4 mh=$5 mp=$6 hmi_port=$7 hmi_used=$8
  [ -f scripts/der_configs/.env ] && source scripts/der_configs/.env
  local hurl="http://127.0.0.1"; [[ $hmi_port != 80 ]] && hurl="http://127.0.0.1:${hmi_port}"
  print_header "Summary"
  
  # Cross-platform path resolution
  local monitor_path
  if command -v cygpath >/dev/null 2>&1; then
    # Windows with Cygwin/MSYS
    monitor_path="file://$(cygpath -w "$(pwd)")/scripts/der_configs/web/mqtt_monitor.html"
  else
    monitor_path="file://$(pwd)/scripts/der_configs/web/mqtt_monitor.html"
  fi
  
  cat <<EOF
DER Type: ${der}
Device (Modbus): ${ip}:${port} (ID ${devid})
MRID: ${MRID:-(generated)}
MQTT: ${mh}:${mp}
HMI: $( [[ $hmi_used == true ]] && echo "${hurl} (admin/hm1admin)" || echo "Not started" )
Grafana: http://localhost:3000 (admin/admin123)
InfluxDB: http://localhost:8086 (openfmb/openfmb123)
Monitor (fallback): ${monitor_path}
EOF
  docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" --filter name=openfmb --filter name=grafana --filter name=influxdb
  
  echo ""
  # Check if MQTT bridge is running
  if [ -f "${SCRIPT_DIR}/energy_management/mqtt_bridge.pid" ]; then
    local pid=$(cat "${SCRIPT_DIR}/energy_management/mqtt_bridge.pid")
    if ps -p $pid > /dev/null 2>&1; then
      echo -e "${GREEN}[OK]${NC} MQTT-InfluxDB Bridge running (PID: $pid)"
    fi
  fi
  
  # Check if Modbus server is running
  if [ -f "${SCRIPT_DIR}/modbus_server.pid" ]; then
    local pid=$(cat "${SCRIPT_DIR}/modbus_server.pid")
    if ps -p $pid > /dev/null 2>&1; then
      echo -e "${GREEN}[OK]${NC} Modbus Device Simulator running on port 5020 (PID: $pid)"
    fi
  fi
}

enhanced_der_setup() {
  local der=$1 ip=$2 port=${3:-502} devid=${4:-1} mh=${5:-localhost} mp=${6:-1883} hmi_port=${7:-80}
  local use_hmi=true
  check_docker
  pull_docker_images || use_hmi=false
  cleanup_existing
  create_network
  
  # Start Modbus simulator if using localhost
  if [[ "$ip" == "localhost" || "$ip" == "127.0.0.1" ]]; then
    start_modbus_simulator
    sleep 2  # Give simulator time to start
  fi
  
  start_mqtt_broker
  start_nats_server
  if $use_hmi; then start_hmi "$hmi_port"; else create_simple_monitor; fi
  verify_or_create_config "$der" "$ip" "$port" "$devid" "$mh" "$mp"
  fix_adapter_container "$der"
  create_simple_monitor
  
  # Start energy management stack
  print_header "Starting Energy Management Stack"
  start_monitoring_stack
  sleep 3  # Wait for InfluxDB to initialize
  start_mqtt_bridge
  
  display_enhanced_summary "$der" "$ip" "$port" "$devid" "$mh" "$mp" "$hmi_port" "$use_hmi"
}

# Energy management & visualization (creates helper scripts)
create_energy_management_scripts() {
  mkdir -p scripts/energy_management
  # battery control
  cat > scripts/energy_management/battery_control.sh <<'EOF'
#!/bin/bash
MQTT_HOST=${1:-localhost}; MQTT_PORT=${2:-1883}; MRID=$3; ACTION=$4; P=${5:-1000}
[ -z "$MRID" ] && echo "Usage: $0 host port <mrid> <charge|discharge|stop>" && exit 1
TS=$(date +%s)
case $ACTION in
  charge) VAL=$P ;;
  discharge) VAL=$((-P)) ;;
  stop|"") VAL=0 ;;
  *) echo "Invalid action"; exit 1 ;;
esac
mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" -t "openfmb/esscontrolprofile/$MRID" -m "{
 \"controlTimestamp\":{\"seconds\":$TS,\"nanos\":0},
 \"essControl\":{\"mRID\":\"$MRID\",\"essControlFSCC\":{\"controlFSCC\":{\"islandControlScheduleFSCH\":{\"ValDCSG\":[{\"crvPts\":[{\"startTime\":{\"seconds\":$TS,\"nanos\":0},\"yVal\":$VAL}]}]}}}}}"
echo "Sent $ACTION ($VAL W) to $MRID"
EOF
  chmod +x scripts/energy_management/battery_control.sh

  # simple simulator
  cat > scripts/energy_management/simulate_data.sh <<'EOF'
#!/bin/bash
HOST=${1:-localhost}; PORT=${2:-1883}; MRID=${3:-demo-solar-1}; TYPE=${4:-solar}; INTERVAL=${5:-5}
echo "Simulating $TYPE -> $MRID every ${INTERVAL}s (Ctrl+C to stop)"
while true; do
  TS=$(date +%s)
  case $TYPE in
    solar)  W=$((RANDOM%5000)); TOPIC="openfmb/solarstatusprofile/$MRID"; PAY="{\"solarInverter\":{\"mRID\":\"$MRID\",\"solarReading\":{\"mmxu\":{\"w\":{\"mag\":$W,\"unit\":\"W\"}}}}}" ;;
    ess|battery) W=$((-2000 + RANDOM%4000)); TOPIC="openfmb/essstatusprofile/$MRID"; PAY="{\"essStatus\":{\"mRID\":\"$MRID\",\"essReading\":{\"mmxu\":{\"w\":{\"mag\":$W,\"unit\":\"W\"}},\"soc\":{\"mag\":50,\"unit\":\"percent\"}}}}" ;;
    meter)  W=$((1000+RANDOM%3000)); TOPIC="openfmb/meterstatusprofile/$MRID"; PAY="{\"meterReading\":{\"mRID\":\"$MRID\",\"readingMMXU\":{\"w\":{\"mag\":$W,\"unit\":\"W\"}}}}" ;;
    *) echo "Unknown type"; exit 1 ;;
  esac
  mosquitto_pub -h "$HOST" -p "$PORT" -t "$TOPIC" -m "{\"controlTimestamp\":{\"seconds\":$TS,\"nanos\":0},$PAY}"
  echo "$(date +%H:%M:%S) $TYPE W=$W"
  sleep "$INTERVAL"
done
EOF
  chmod +x scripts/energy_management/simulate_data.sh

  # Grafana stack runner
  cat > scripts/energy_management/run_grafana_stack.sh <<'EOF'
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
EOF
  chmod +x scripts/energy_management/run_grafana_stack.sh
  print_status "Energy management scripts created (scripts/energy_management)"
}

start_monitoring_stack() {
  print_status "Starting InfluxDB..."
  docker run -d --name influxdb --network openfmb -p 8086:8086 \
    -e INFLUXDB_DB=openfmb -e INFLUXDB_ADMIN_USER=admin -e INFLUXDB_ADMIN_PASSWORD=admin123 \
    -e INFLUXDB_USER=openfmb -e INFLUXDB_USER_PASSWORD=openfmb123 \
    -v influxdb-data:/var/lib/influxdb influxdb:1.8 2>/dev/null || true
  
  print_status "Starting Grafana..."
  docker run -d --name grafana --network openfmb -p 3000:3000 \
    -e GF_SECURITY_ADMIN_PASSWORD=admin123 \
    -v grafana-data:/var/lib/grafana grafana/grafana:latest 2>/dev/null || true
  
  print_status "Grafana -> http://localhost:3000 (admin/admin123)"
  print_status "InfluxDB -> http://localhost:8086 (openfmb/openfmb123)"
}

start_mqtt_bridge() {
  print_status "Starting MQTT-InfluxDB Bridge..."
  local bridge_script="${SCRIPT_DIR}/energy_management/mqtt_to_influx_bridge.py"
  
  if [ -f "$bridge_script" ]; then
    # Check if Python 3 is available
    if command -v python3 >/dev/null 2>&1; then
      # Run bridge in background using nohup
      cd "${SCRIPT_DIR}/energy_management"
      nohup python3 mqtt_to_influx_bridge.py > mqtt_bridge.log 2>&1 &
      local pid=$!
      echo $pid > mqtt_bridge.pid
      print_status "MQTT Bridge running (PID: $pid, log: energy_management/mqtt_bridge.log)"
    else
      print_warning "Python 3 not found, skipping MQTT bridge"
    fi
  else
    print_warning "MQTT bridge script not found at $bridge_script"
  fi
}

start_modbus_simulator() {
  print_status "Starting Modbus Device Simulator..."
  local modbus_script
  
  # Look for modbus server in parent directory
  if [ -f "${SCRIPT_DIR}/../../modbus_server_fixed.py" ]; then
    modbus_script="${SCRIPT_DIR}/../../modbus_server_fixed.py"
  elif [ -f "${SCRIPT_DIR}/../modbus_server_fixed.py" ]; then
    modbus_script="${SCRIPT_DIR}/../modbus_server_fixed.py"
  fi
  
  if [ -n "$modbus_script" ] && [ -f "$modbus_script" ]; then
    if command -v python3 >/dev/null 2>&1; then
      cd "$(dirname "$modbus_script")"
      nohup python3 "$(basename "$modbus_script")" 5020 > modbus_server.log 2>&1 &
      local pid=$!
      echo $pid > "${SCRIPT_DIR}/modbus_server.pid"
      print_status "Modbus Simulator running on port 5020 (PID: $pid)"
    else
      print_warning "Python 3 not found, skipping Modbus simulator"
    fi
  else
    print_warning "Modbus server script not found"
  fi
}

setup_energy_management_and_visualization() {
  check_docker
  pull_docker_images || true
  create_energy_management_scripts
  start_monitoring_stack
  echo "Start simulator: ./scripts/energy_management/simulate_data.sh"
}

# DER setup wrappers
setup_solar_pv(){ read -p "Solar IP [localhost]: " ip; ip=${ip:-localhost}; enhanced_der_setup solar "$ip" 502 1 localhost 1883 80; }
setup_ess(){ read -p "ESS IP [localhost]: " ip; ip=${ip:-localhost}; enhanced_der_setup ess "$ip" 502 1 localhost 1883 8080; }
setup_switch(){ read -p "Switch IP [localhost]: " ip; ip=${ip:-localhost}; enhanced_der_setup switch "$ip" 502 1 localhost 1883 8081; }
setup_load(){ read -p "Load IP [localhost]: " ip; ip=${ip:-localhost}; enhanced_der_setup load "$ip" 502 1 localhost 1883 8082; }
setup_meter(){ read -p "Meter IP [localhost]: " ip; ip=${ip:-localhost}; enhanced_der_setup meter "$ip" 502 1 localhost 1883 8083; }

custom_setup() {
  read -p "DER type (solar|ess|switch|load|meter): " der
  read -p "Device IP [localhost]: " ip; ip=${ip:-localhost}
  read -p "Modbus port [502]: " mport; mport=${mport:-502}
  read -p "Unit ID [1]: " uid; uid=${uid:-1}
  read -p "MQTT host [localhost]: " mh; mh=${mh:-localhost}
  read -p "MQTT port [1883]: " mp; mp=${mp:-1883}
  read -p "HMI host port [80]: " hp; hp=${hp:-80}
  enhanced_der_setup "$der" "$ip" "$mport" "$uid" "$mh" "$mp" "$hp"
}

setup_complete_stack() {
  check_docker
  pull_docker_images || true
  cleanup_existing
  create_network
  start_mqtt_broker
  start_nats_server
  start_hmi 80
  print_status "Base stack running (HMI + MQTT + NATS)"
}

show_examples() {
  cat <<EOF
Examples:
Monitor all: mosquitto_sub -h localhost -p 1883 -t 'openfmb/+/+'
Sim solar:   ./scripts/energy_management/simulate_data.sh localhost 1883 solar-1 solar
Charge ESS:  ./scripts/energy_management/battery_control.sh localhost 1883 ess-1 charge 1500
HMI:         http://127.0.0.1  (admin / hm1admin)
EOF
  read -p "Enter to continue..."
}

main() {
  print_banner
  while true; do
    print_menu
    read -p "Choice [1-10]: " c
    case $c in
      1) setup_solar_pv; break ;;
      2) setup_ess; break ;;
      3) setup_switch; break ;;
      4) setup_load; break ;;
      5) setup_meter; break ;;
      6) custom_setup; break ;;
      7) show_examples ;;
      8) setup_complete_stack ;;
      9) setup_energy_management_and_visualization ;;
      10) exit 0 ;;
      *) echo "Invalid" ;;
    esac
  done
}

main "$@"