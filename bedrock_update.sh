#!/usr/bin/env bash

set -e # Exit on error

# Define directories
SERVER_DIR="./"
BACKUP_DIR="${SERVER_DIR}bedrock_config_backup/" # Temporary backup directory
SERVICE_NAME="mcbedrock" # Default service name

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
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

# Stop service
systemctl stop "$SERVICE_NAME"

# Create temporary backup directory
mkdir -p "$BACKUP_DIR"

# Backup configuration
cp "${SERVER_DIR}server.properties" "${BACKUP_DIR}server.properties.bkup"
cp "${SERVER_DIR}allowlist.json" "${BACKUP_DIR}allowlist.json.bkup"
cp "${SERVER_DIR}permissions.json" "${BACKUP_DIR}permissions.json.bkup"

# Download latest server
DOWNLOAD_URL=$(curl -H "Accept-Encoding: identity" -H "Accept-Language: en" -s -L -A "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; BEDROCK-UPDATER)" https://minecraft.net/en-us/download/server/bedrock/ | grep -o 'https.*/bin-linux/.*.zip')

if [ -z "$DOWNLOAD_URL" ]; then
  echo "Error: Could not find download URL."
  exit 1
fi

wget -U "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; BEDROCK-UPDATER)" "$DOWNLOAD_URL" -O "${SERVER_DIR}bedrock-server.zip"

# Extract server
unzip -o "${SERVER_DIR}bedrock-server.zip" -d "${SERVER_DIR}"

# Clean up
rm "${SERVER_DIR}bedrock-server.zip"

# Restore configuration
mv "${BACKUP_DIR}server.properties.bkup" "${SERVER_DIR}server.properties"
mv "${BACKUP_DIR}allowlist.json.bkup" "${SERVER_DIR}allowlist.json"
mv "${BACKUP_DIR}permissions.json.bkup" "${SERVER_DIR}permissions.json"

# Remove temporary backup directory
rm -rf "$BACKUP_DIR"

# Start service
systemctl start "$SERVICE_NAME"

echo "Bedrock server updated successfully."
