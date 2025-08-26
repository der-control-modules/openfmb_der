#!/bin/bash

# OpenFMB DER Framework - One-Click Installer
# This script sets up the minimal OpenFMB DER framework

set -e

INSTALL_DIR="${1:-$(pwd)/openfmb-der-framework}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=============================================="
echo "OpenFMB DER Framework - One-Click Installer"
echo "=============================================="
echo ""
echo "Installing to: ${INSTALL_DIR}"
echo ""

# Create installation directory
mkdir -p "${INSTALL_DIR}"

# Copy all essential files
echo "Copying framework files..."
cp -r "${SCRIPT_DIR}/." "${INSTALL_DIR}/"

# Make all scripts executable
echo "Setting permissions..."
chmod +x "${INSTALL_DIR}/scripts/"*.sh

# Verify Docker is available
echo "Checking dependencies..."
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please install Docker first."
    echo "   macOS: https://docs.docker.com/docker-for-mac/install/"
    echo "   Linux: https://docs.docker.com/engine/install/"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "❌ Docker daemon not running. Please start Docker."
    exit 1
fi

echo "✅ Docker is available"

# Create quick start script
cat > "${INSTALL_DIR}/start.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")/scripts"
./quick_setup.sh
EOF

chmod +x "${INSTALL_DIR}/start.sh"

echo ""
echo "=============================================="
echo "✅ Installation Complete!"
echo "=============================================="
echo ""
echo "Framework installed to: ${INSTALL_DIR}"
echo ""
echo "Quick Start Options:"
echo "1. Interactive Setup:"
echo "   cd ${INSTALL_DIR}"
echo "   ./start.sh"
echo ""
echo "2. Command Line Setup:"
echo "   cd ${INSTALL_DIR}/scripts"
echo "   ./setup_der_clean.sh --type solar --ip 192.168.1.100"
echo ""
echo "3. Browse Documentation:"
echo "   open ${INSTALL_DIR}/README.md"
echo "   open ${INSTALL_DIR}/docs/DER_SETUP_README.md"
echo ""
echo "Happy DER integration! 🚀"
