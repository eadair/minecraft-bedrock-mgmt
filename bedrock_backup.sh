#!/usr/bin/env bash

# Configuration (from command-line arguments)
WORLD_DIR=""
SCREEN_NAME=""
BACKUP_DIR=""
HOURLY_RETENTION_HOURS=24
DAILY_RETENTION_DAYS=7
WEEKLY_RETENTION_WEEKS=8

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -w|-world)
      WORLD_DIR="$2"
      shift
      shift
      ;;
    -s|-screen)
      SCREEN_NAME="$2"
      shift
      shift
      ;;
    -b|-backup)
      BACKUP_DIR="$2"
      shift
      shift
      ;;
    -hr|-hourly_retention)
      HOURLY_RETENTION_HOURS="$2"
      shift
      shift
      ;;
    -dr|-daily_retention)
      DAILY_RETENTION_DAYS="$2"
      shift
      shift
      ;;
    -wr|-weekly_retention)
      WEEKLY_RETENTION_WEEKS="$2"
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
if [ -z "$WORLD_DIR" ] || [ -z "$SCREEN_NAME" ] || [ -z "$BACKUP_DIR" ]; then
  echo "Usage: $0 -w <world_dir> -s <screen_name> -b <backup_dir> [-hr <hours>] [-dr <days>] [-wr <weeks>]"
  exit 1
fi

WORLD_NAME=$(basename "$WORLD_DIR")
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Ensure backup directories exist
mkdir -p "$BACKUP_DIR/hourly"
mkdir -p "$BACKUP_DIR/daily"
mkdir -p "$BACKUP_DIR/weekly"

# Create backup filename
BACKUP_FILE="$BACKUP_DIR/hourly/${WORLD_NAME}_$TIMESTAMP.zip"

# Bedrock commands for backup
screen -S "$SCREEN_NAME" -X stuff "say Server backup starting...^M"
screen -S "$SCREEN_NAME" -X stuff "save-all^M"
sleep 5
screen -S "$SCREEN_NAME" -X stuff "save-off^M"
sleep 5
screen -S "$SCREEN_NAME" -X stuff "say Server backup in progress...^M"
cd "$(dirname "$WORLD_DIR")" && zip -r "$BACKUP_FILE" "$WORLD_NAME"
screen -S "$SCREEN_NAME" -X stuff "save-on^M"
screen -S "$SCREEN_NAME" -X stuff "say Server backup completed! File: ${WORLD_NAME}_$TIMESTAMP.zip^M"

# Cleanup functions
move_to_subfolder() {
  local source_dir="$1"
  local target_dir="$2"
  local date_patterns="$3"

  find "$source_dir" -type f $date_patterns | while IFS= read -r file; do
    local filename=$(basename "$file")
    local date="${filename#${WORLD_NAME}_}"
    date="${date%%_*}"

    if [[ $(find "$target_dir" -type f -name "${WORLD_NAME}_${date}_*.zip" | wc -l) -eq 0 ]]; then
      local latest=$(find "$source_dir" -type f -name "${WORLD_NAME}_${date}_*.zip" | sort -r | head -n 1)
      if [[ "$file" == "$latest" ]]; then
        /usr/bin/mv -v "$file" "$target_dir"
      fi
    fi
  done
}

prune_old_backups() {
  local target_dir="$1"
  local date_patterns="$2"
  find "$target_dir" -type f $date_patterns -execdir sh -c 'ls -t "{}" | tail -n +2 | xargs rm' \;
}

# Generate date patterns
daily_patterns=""
for ((i=1; i<=$DAILY_RETENTION_DAYS; i++)); do
  date_args=(-d "$i days ago" +'%Y%m%d')
  daily_patterns="$daily_patterns -o -name ${WORLD_NAME}_$(date "${date_args[@]}")_*.zip"
done
daily_patterns="${daily_patterns:3}"

# Generate weekly patterns
weekly_patterns=""
for ((i=1; i<=$WEEKLY_RETENTION_WEEKS; i++)); do
  date_args=(-d "$i weeks ago" +'%Y%m%d')
  weekly_patterns="$weekly_patterns -o -name ${WORLD_NAME}_$(date "${date_args[@]}")_*.zip"
done
weekly_patterns="${weekly_patterns:3}"

# Cleanup old backups (modified hourly)
move_to_subfolder "$BACKUP_DIR/hourly/" "$BACKUP_DIR/daily/" "$daily_patterns"
prune_old_backups "$BACKUP_DIR/daily/" "$daily_patterns"

FILES_TO_DELETE=$(find "$BACKUP_DIR/hourly/" -type f -mmin "+$(($HOURLY_RETENTION_HOURS * 60))" -print)
if [ -n "$FILES_TO_DELETE" ]; then
  while IFS= read -r FILE; do
    echo "Deleting: $FILE"
    rm "$FILE"
  done <<< "$FILES_TO_DELETE"
fi

move_to_subfolder "$BACKUP_DIR/daily/" "$BACKUP_DIR/weekly/" "$weekly_patterns"
prune_old_backups "$BACKUP_DIR/weekly/" "$weekly_patterns"

echo "Backup created: $BACKUP_FILE"
