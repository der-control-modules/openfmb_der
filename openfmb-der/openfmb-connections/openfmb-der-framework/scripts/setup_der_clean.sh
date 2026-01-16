# filepath: /openfmb-der-framework/openfmb-der-framework/scripts/setup_der_clean.sh
#!/bin/bash
# Setup DER Clean Script

set -e

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

print_status(){ echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning(){ echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error(){ echo -e "${RED}[ERROR]${NC} $1"; }
print_header(){ echo -e "${BLUE}[CLEANUP]${NC} $1"; }

cleanup_existing() {
  print_header "Cleanup"
  for c in openfmb-mosquitto nats-server openfmb-hmi grafana influxdb \
            openfmb-solar-adapter openfmb-ess-adapter openfmb-switch-adapter \
            openfmb-load-adapter openfmb-meter-adapter; do
    docker rm -f "$c" >/dev/null 2>&1 || true
  done
  docker network rm openfmb >/dev/null 2>&1 || true
  print_status "Cleanup completed"
}

main() {
  cleanup_existing
}

main "$@"