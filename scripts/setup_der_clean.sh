#!/bin/bash

# OpenFMB DER Setup Wrapper
# This script runs cleanup and then the main setup script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLEANUP_SCRIPT="${SCRIPT_DIR}/cleanup_containers.sh"
SETUP_SCRIPT="${SCRIPT_DIR}/setup_openfmb_der.sh"

echo "=============================================="
echo "OpenFMB DER Setup with Auto-Cleanup"
echo "=============================================="

# Check if cleanup is needed
if docker ps -a --format "table {{.Names}}" | grep -q "openfmb-mosquitto"; then
    echo "Found existing OpenFMB containers. Running cleanup first..."
    echo "y" | "${CLEANUP_SCRIPT}"
    echo ""
fi

# Run the main setup script with all passed arguments
echo "Running OpenFMB DER setup..."
"${SETUP_SCRIPT}" "$@"
