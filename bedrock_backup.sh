#!/usr/bin/env bash

# Configuration from command-line arguments
WORLD_DIR=""
SCREEN_NAME=""
BACKUP_DIR=""
HOURLY_RETENTION_HOURS=24
DAILY_RETENTION_DAYS=7
WEEKLY_RETENTION_WEEKS=4
WEEKLY_BACKUP_DAY="Sunday"


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
    -wd|-weekly_day) # New option for day of week
      WEEKLY_BACKUP_DAY="$2"
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
  echo "Usage: $0 -w <world_dir> -s <screen_name> -b <backup_dir> [-hr <hours>] [-dr <days>] [-wr <weeks>] [-wd <day>]"
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
cd "$(dirname "$WORLD_DIR")" && zip -rq "$BACKUP_FILE" "$WORLD_NAME"
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


# Function to calculate datetime from filename
calculate_datetime_from_filename() {
  local filename="$1"
  if [[ "$filename" =~ ^.*_([0-9]{8})_([0-9]{6}).*.zip$ ]]; then
    echo "${BASH_REMATCH[1]:0:4}-${BASH_REMATCH[1]:4:2}-${BASH_REMATCH[1]:6:2} ${BASH_REMATCH[2]:0:2}:${BASH_REMATCH[2]:2:2}:${BASH_REMATCH[2]:4:2}"
  else
    echo "" # Return empty string on failure
  fi
}

# Function to generate date patterns
generate_date_patterns() {
  local pattern_type="$1"
  local patterns=""
  local retention_period="" # Use a variable for the retention period

  if [[ "$pattern_type" == "days" ]]; then
    retention_period=$DAILY_RETENTION_DAYS
    for ((i=1; i<=$retention_period; i++)); do
      date_args=(-d "$i days ago" +'%Y%m%d')
      patterns="$patterns -o -name ${WORLD_NAME}_$(date "${date_args[@]}")_*.zip"
    done
  else
    retention_period=$WEEKLY_RETENTION_WEEKS
    for ((i=0; i<$retention_period; i++)); do
      date_args=(-d "$i weeks ago $WEEKLY_BACKUP_DAY" +'%Y%m%d')
      patterns="$patterns -o -name ${WORLD_NAME}_$(date "${date_args[@]}")_*.zip"
    done
  fi
  echo "${patterns:3}"
}

# Generate date patterns
daily_patterns=$(generate_date_patterns "days")
weekly_patterns=$(generate_date_patterns "$WEEKLY_BACKUP_DAY")

# Move files from hourly to daily
move_to_subfolder "$BACKUP_DIR/hourly/" "$BACKUP_DIR/daily/" "$daily_patterns"
move_to_subfolder "$BACKUP_DIR/daily/" "$BACKUP_DIR/weekly/" "$weekly_patterns"


# Delete old backups
delete_old_files() {
  local folder_path="$1"
  local threshold_hours="$2"

  # Iterate through the files in the folder
  find "$folder_path" -type f -name "*.zip" | while IFS= read -r file_path; do
    filename=$(basename "$file_path")
    local file_datetime=$(calculate_datetime_from_filename "$filename")

    if [[ -n "$file_datetime" ]]; then # Check if parsing was successful
      file_timestamp=$(date -d "$file_datetime" +%s)
      current_timestamp=$(date +%s)
      local diff_seconds=$((current_timestamp - file_timestamp))
      local diff_hours=$((diff_seconds / 3600))

      if [[ "$diff_hours" -gt "$threshold_hours" ]]; then
        echo "Deleting (older than $threshold_hours hours): $file_path"
        rm -v "$file_path"
      else
        echo "Keeping (within $threshold_hours hours): $file_path"
      fi
    else
      echo "Skipping: Invalid filename format: $file_path"
    fi
  done
}

delete_old_files "$BACKUP_DIR/hourly/" $HOURLY_RETENTION_HOURS
delete_old_files "$BACKUP_DIR/daily/" $(($DAILY_RETENTION_DAYS * 24))
delete_old_files "$BACKUP_DIR/weekly/" $(($WEEKLY_RETENTION_WEEKS * 7 * 24))

echo "Backup created: $BACKUP_FILE"
