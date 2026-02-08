#!/bin/bash

BASE_DIR="/home/ec2-user/class-recordings"
LOG_FILE="$BASE_DIR/recording.log"
LOCK_FILE="/tmp/class_recording.lock"

MIN_FILE_SIZE_MB=5 

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

if [ $# -lt 2 ]; then
    echo "Usage: $0 <Class_Name> <Recording_File_Path>"
    exit 1
fi

CLASS_NAME="$1"
RECORDING_FILE="$2"

if [ -z "${SLACK_WEBHOOK:-}" ]; then
    echo "ERROR: SLACK_WEBHOOK environment variable not set."
    exit 1
fi

if [ ! -f "$RECORDING_FILE" ]; then
    echo "ERROR: Recording file does not exist."
    exit 1
fi

if [ -f "$LOCK_FILE" ]; then
    echo "Another instance is running. Exiting."
    exit 1
fi

trap "rm -f $LOCK_FILE" EXIT
touch "$LOCK_FILE"

log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" >> "$LOG_FILE"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" >> "$LOG_FILE"
}

send_slack() {
    local STATUS="$1"
    local MESSAGE="$2"

    curl -s -X POST -H "Content-type: application/json" \
        --data "{\"text\":\"$MESSAGE\"}" \
        "$SLACK_WEBHOOK" > /dev/null
}

CLASS_DIR="$BASE_DIR/$CLASS_NAME"
FILE_NAME=$(basename "$RECORDING_FILE")
DATE_TIME=$(date "+%Y-%m-%d %H:%M:%S")

mkdir -p "$CLASS_DIR"

# File size validation
FILE_SIZE_MB=$(du -m "$RECORDING_FILE" | cut -f1)

if [ "$FILE_SIZE_MB" -lt "$MIN_FILE_SIZE_MB" ]; then
    ERROR_MSG="File size too small ($FILE_SIZE_MB MB). Upload may have failed."
    log_error "$ERROR_MSG"

    send_slack "FAILED" "❌ *Recording Upload Failed*
Class: $CLASS_NAME
File: $FILE_NAME
Reason: $ERROR_MSG
Time: $DATE_TIME"

    exit 1
fi

# Move file
mv "$RECORDING_FILE" "$CLASS_DIR/"

log_info "Recording updated: $CLASS_NAME - $FILE_NAME ($FILE_SIZE_MB MB)"

#############################
# SUCCESS SLACK NOTIFICATION
#############################

SUCCESS_MESSAGE="✅ *Class Recording Updated Successfully*
Class: $CLASS_NAME
File: $FILE_NAME
Size: ${FILE_SIZE_MB}MB
Time: $DATE_TIME
Server: $(hostname)"

send_slack "SUCCESS" "$SUCCESS_MESSAGE"

echo "Recording updated successfully."
exit 0