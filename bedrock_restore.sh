#!/usr/bin/env bash

set -e

# Configuration
BACKUP_FILE=""
WORLD_DIR=""
SERVICE_NAME="mcbedrock" # Default service name

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

# Remove existing world directory and extract backup
rm -rf "$WORLD_DIR"
mkdir -p "$WORLD_PARENT"
cd "$WORLD_PARENT"
unzip -q "$BACKUP_FILE"

# Start the service
systemctl start "$SERVICE_NAME"

echo "Restore completed."
