#!/bin/bash 

# Grafana Alloy Stack Environment Variables
# This script sets all the environment variables used across the Grafana Alloy monitoring stack
# 
# USAGE:
#   1. Copy this file and customize the paths for your environment
#   2. Source it before running start.sh, stop.sh, or restart.sh
#   3. Or set these environment variables in your shell profile
#
# CUSTOMIZATION:
#   - Set GRAFANA_LOGS_SOURCE_DIR to point to your application's log directory
#   - Set GRAFANA_DB_BASE_DIR to where you want to store Grafana data
#   - Adjust ports if running multiple instances or avoiding conflicts
#   - Set GRAFANA_ENV_SUFFIX to identify this environment (e.g., "dev", "prod", "local")

# ==============================================================================
# REQUIRED: Core directory paths - CUSTOMIZE THESE FOR YOUR SETUP
# ==============================================================================

# Where to read application log files from (absolute path required)
# Example: /path/to/your/app/logs
export GRAFANA_LOGS_SOURCE_DIR="${GRAFANA_LOGS_SOURCE_DIR}"

# Where to store Grafana, Loki, and Alloy persistent data (absolute path required)
# Example: /var/lib/grafana-data or ~/grafana-data
export GRAFANA_DB_BASE_DIR="${GRAFANA_DB_BASE_DIR}"

# ==============================================================================
# Derived directory paths (automatically set based on GRAFANA_DB_BASE_DIR)
# ==============================================================================
export GRAFANA_DATA_DIR="$GRAFANA_DB_BASE_DIR/grafana"
export LOKI_DATA_DIR="$GRAFANA_DB_BASE_DIR/loki"
export ALLOY_DATA_DIR="$GRAFANA_DB_BASE_DIR/alloy"

# ==============================================================================
# Environment identification - useful when running multiple instances
# ==============================================================================
export GRAFANA_ENV_SUFFIX="${GRAFANA_ENV_SUFFIX:-dev}"  # Options: dev, prod, local, test, etc.

# ==============================================================================
# Port configurations for Grafana services
# ==============================================================================
export GRAFANA_PORT="${GRAFANA_PORT:-3000}"           # Grafana UI (web interface)
export LOKI_PORT="${LOKI_PORT:-3100}"                 # Loki API
export ALLOY_HTTP_PORT="${ALLOY_HTTP_PORT:-12345}"    # Alloy HTTP server
export ALLOY_OTLP_PORT="${ALLOY_OTLP_PORT:-4318}"     # Alloy OTLP receiver

# ==============================================================================
# Docker image versions (optional - docker-compose.yml has defaults)
# ==============================================================================
# Uncomment and set specific versions if needed, otherwise latest stable versions will be used
# export GRAFANA_VERSION="12.0.2"
# export GRAFANA_LOKI_VERSION="3.5.2"
# export GRAFANA_ALLOY_VERSION="v1.10.0"

# ==============================================================================
# Validation (required)
# ==============================================================================

# Check if GRAFANA_LOGS_SOURCE_DIR is set and exists
if [ -z "$GRAFANA_LOGS_SOURCE_DIR" ]; then
    echo "❌ Error: GRAFANA_LOGS_SOURCE_DIR environment variable is not set."
    echo "   Please set it to the absolute path of your application's log directory."
    echo "   Example: export GRAFANA_LOGS_SOURCE_DIR=/path/to/your/app/logs"
    echo
    echo "Press any key to exit..."
    read -n 1
    exit 1
fi

if [ ! -d "$GRAFANA_LOGS_SOURCE_DIR" ]; then
    echo "❌ Error: GRAFANA_LOGS_SOURCE_DIR directory does not exist: $GRAFANA_LOGS_SOURCE_DIR"
    echo "   Please create this directory or set GRAFANA_LOGS_SOURCE_DIR to an existing directory."
    echo
    echo "Press any key to exit..."
    read -n 1
    exit 1
fi

# Check if GRAFANA_DB_BASE_DIR is set and exists
if [ -z "$GRAFANA_DB_BASE_DIR" ]; then
    echo "❌ Error: GRAFANA_DB_BASE_DIR environment variable is not set."
    echo "   Please set it to the absolute path where you want to store Grafana data."
    echo "   Example: export GRAFANA_DB_BASE_DIR=/var/lib/grafana-data"
    echo
    echo "Press any key to exit..."
    read -n 1
    exit 1
fi

if [ ! -d "$GRAFANA_DB_BASE_DIR" ]; then
    echo "❌ Error: GRAFANA_DB_BASE_DIR directory does not exist: $GRAFANA_DB_BASE_DIR"
    echo "   Please create this directory or set GRAFANA_DB_BASE_DIR to an existing directory."
    echo
    echo "Press any key to exit..."
    read -n 1
    exit 1
fi

# If we reach here, both directories are valid
echo "✅ Environment validation passed:"
echo "   GRAFANA_LOGS_SOURCE_DIR: $GRAFANA_LOGS_SOURCE_DIR"
echo "   GRAFANA_DB_BASE_DIR: $GRAFANA_DB_BASE_DIR"
