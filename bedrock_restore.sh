#!/usr/bin/env bash

# Configuration
BACKUP_FILE=""
WORLD_DIR=""
SERVICE_NAME="mcbedrock" # Default service name
CONFIG_BACKUP_DIR="./restore_config_backup" # Temporary config backup directory

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -f|-file)
      BACKUP_FILE="$2"
      shift
      shift
      ;;
    -w|-world)
      WORLD_DIR="$2"
      shift
      shift
      ;;
    -s|-service)
      SERVICE_NAME="$2"
      shift
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Check if all required parameters are provided
if [ -z "$BACKUP_FILE" ] || [ -z "$WORLD_DIR" ]; then
  echo "Usage: $0 -f <backup_file> -w <world_dir> [-s <service_name>]"
  exit 1
fi

WORLD_NAME=$(basename "$WORLD_DIR")
WORLD_PARENT=$(dirname "$WORLD_DIR")

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
  echo "Error: Backup file '$BACKUP_FILE' not found."
  exit 1
fi

# Stop the service and perform restore
systemctl stop "$SERVICE_NAME"
echo "Server restore starting..."

# Backup current config files
mkdir -p "$CONFIG_BACKUP_DIR"
if [ -f "${WORLD_PARENT}/server.properties" ]; then
  cp "${WORLD_PARENT}/server.properties" "${CONFIG_BACKUP_DIR}/server.properties.bkup"
fi
if [ -f "${WORLD_PARENT}/allowlist.json" ]; then
  cp "${WORLD_PARENT}/allowlist.json" "${CONFIG_BACKUP_DIR}/allowlist.json.bkup"
fi
if [ -f "${WORLD_PARENT}/permissions.json" ]; then
    cp "${WORLD_PARENT}/permissions.json" "${CONFIG_BACKUP_DIR}/permissions.json.bkup"
fi

# Remove existing world directory and extract backup
rm -rf "$WORLD_DIR"
mkdir -p "$WORLD_PARENT"
cd "$WORLD_PARENT"
unzip -q "$BACKUP_FILE"

# Restore config files
if [ -f "${CONFIG_BACKUP_DIR}/server.properties.bkup" ]; then
  mv "${CONFIG_BACKUP_DIR}/server.properties.bkup" "${WORLD_PARENT}/server.properties"
fi
if [ -f "${CONFIG_BACKUP_DIR}/allowlist.json.bkup" ]; then
  mv "${CONFIG_BACKUP_DIR}/allowlist.json.bkup" "${WORLD_PARENT}/allowlist.json"
fi
if [ -f "${CONFIG_BACKUP_DIR}/permissions.json.bkup" ]; then
    mv "${CONFIG_BACKUP_DIR}/permissions.json.bkup" "${WORLD_PARENT}/permissions.json"
fi

# Remove temporary config backup directory
rm -rf "$CONFIG_BACKUP_DIR"

# Start the service
systemctl start "$SERVICE_NAME"

echo "Restore completed."
