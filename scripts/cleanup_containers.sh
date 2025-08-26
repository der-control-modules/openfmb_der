#!/bin/bash

# OpenFMB Container Cleanup Script
# This script cleans up existing OpenFMB containers to resolve conflicts

echo "=============================================="
echo "OpenFMB Container Cleanup"
echo "=============================================="

# Stop and remove existing containers
echo "Stopping existing OpenFMB containers..."

containers_to_cleanup=(
    "openfmb-mosquitto"
    "openfmb-solar-adapter"
    "openfmb-ess-adapter"
    "openfmb-switch-adapter"
    "openfmb-load-adapter"
    "openfmb-meter-adapter"
    "openfmb-hmi"
)

for container in "${containers_to_cleanup[@]}"; do
    if docker ps -a --format "table {{.Names}}" | grep -q "^${container}$"; then
        echo "Found container: ${container}"
        
        # Stop if running
        if docker ps --format "table {{.Names}}" | grep -q "^${container}$"; then
            echo "  Stopping ${container}..."
            docker stop "${container}"
        fi
        
        # Remove container
        echo "  Removing ${container}..."
        docker rm "${container}"
    fi
done

# Clean up any openfmb-related containers
echo "Cleaning up any other OpenFMB containers..."
docker ps -a --format "table {{.Names}}" | grep "openfmb" | while read container; do
    if [ ! -z "$container" ]; then
        echo "Found additional container: $container"
        docker stop "$container" 2>/dev/null || true
        docker rm "$container" 2>/dev/null || true
    fi
done

# Optionally remove Docker Compose networks/volumes
read -p "Remove OpenFMB Docker networks and volumes? [y/N]: " cleanup_volumes
if [[ $cleanup_volumes =~ ^[Yy]$ ]]; then
    echo "Cleaning up Docker networks..."
    docker network ls --format "table {{.Name}}" | grep "openfmb" | while read network; do
        if [ ! -z "$network" ]; then
            echo "Removing network: $network"
            docker network rm "$network" 2>/dev/null || true
        fi
    done
    
    echo "Cleaning up Docker volumes..."
    docker volume ls --format "table {{.Name}}" | grep -E "(mosquitto|openfmb)" | while read volume; do
        if [ ! -z "$volume" ]; then
            echo "Removing volume: $volume"
            docker volume rm "$volume" 2>/dev/null || true
        fi
    done
fi

echo ""
echo "Cleanup completed!"
echo "You can now run the setup script again."
