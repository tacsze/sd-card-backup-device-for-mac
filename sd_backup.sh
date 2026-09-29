#!/bin/bash

TARGET_DIR="$HOME/Pictures/SD_Backups"
DESTINATION="$TARGET_DIR/LEICA_DSC_Backup"
LOG_FILE="$HOME/Library/Logs/sd_backup.log"
EXCLUDE_DB="$TARGET_DIR/.backed_up_files.txt"

IMMICH_URL="https://photos.tacsze2.synology.me"
IMMICH_KEY="wznZ4J2lDHbuUVBy3lVMX3ms9Sy3iOULvW0pgEcrLQ"

# Prevent the core machine engine from slipping into deep sleep
caffeinate -s -d &

# Ensure the exclude database file exists so rsync doesn't error out
touch "$EXCLUDE_DB"
echo "[$(date)] Memory-Log Ingestion Daemon (Idea 1 Fixed) Active." >> "$LOG_FILE"

while true; do
 if [ -d "/Volumes/LEICA DSC" ]; then
 TIMESTAMP=$(date "+%Y-%m-%d_%H-%M-%S")
 echo "[$TIMESTAMP] Leica SD Card Detected!" >> "$LOG_FILE"
 
 # START SIGNALS
 afplay /System/Library/Sounds/Ping.aiff
 say "Leica card detected. Scanning for new photos."
 
 mkdir -p "$DESTINATION"
 
 # 1. Local Sync Engine (Smart Mode)
 rsync -avu --exclude-from="$EXCLUDE_DB" "/Volumes/LEICA DSC/" "$DESTINATION/" >> "$LOG_FILE" 2>&1
 
 # Count files inside destination to verify if there's actually anything new to process
 NEW_FILE_COUNT=$(find "$DESTINATION" -type f 2>/dev/null | wc -l | xargs)
 
 if [ "$NEW_FILE_COUNT" -gt 0 ]; then
 echo "[$(date)] Found $NEW_FILE_COUNT new assets. Ejecting card..." >> "$LOG_FILE"
 
 # Unmount the card immediately so it's physically safe to pull out
 diskutil eject "/Volumes/LEICA DSC" >> "$LOG_FILE" 2>&1
 
 # CARD SAFE SIGNALS
 afplay /System/Library/Sounds/Glass.aiff
 sleep 0.1
 afplay /System/Library/Sounds/Glass.aiff
 say "New photos found and copied. You can remove the card now."
 
 echo "[$(date)] Uploading new files to Immich in background..." >> "$LOG_FILE"
 
 # 2. Headless Immich Cloud Sync Engine
 $HOME/bin/immich-go upload from-folder --no-ui --server="$IMMICH_URL" --api-key="$IMMICH_KEY" "$DESTINATION/" >> "$LOG_FILE" 2>&1
 
 if [ $? -eq 0 ]; then
 echo "[$(date)] Immich upload success! Recording file names to memory database..." >> "$LOG_FILE"
 
 # CRASH-PROOF RECORD TO MEMORY:
 # We safely read straight from the directory path structure dynamically
 find "$DESTINATION" -type f -exec basename {} \; >> "$EXCLUDE_DB"
 sort -u "$EXCLUDE_DB" -o "$EXCLUDE_DB"
 
 # STORAGE PURGE
 rm -rf "${DESTINATION:?}"/*
 
 # COMPLETE SIGNALS
 afplay /System/Library/Sounds/Tink.aiff
 say "Immich sync finished. Your new photos are live, and local storage is cleared."
 else
 echo "[$(date)] Cloud sync failed! Keeping temporary files for safety." >> "$LOG_FILE"
 afplay /System/Library/Sounds/Basso.aiff
 say "Warning. Cloud upload failed. Local photos kept for backup safety."
 fi
 else
 echo "[$(date)] No new photos found on card. Ejecting safely." >> "$LOG_FILE"
 diskutil eject "/Volumes/LEICA DSC" >> "$LOG_FILE" 2>&1
 
 # Wipe folder just in case empty hidden directories were left behind
 rm -rf "${DESTINATION:?}"/* >/dev/null 2>&1
 
 afplay /System/Library/Sounds/Glass.aiff
 say "No new photos found. Card is already backed up."
 fi
 
 # Debounce safety check loop
 while [ -d "/Volumes/LEICA DSC" ]; do
 sleep 2
 done
 echo "[$(date)] Slot cleared physically. Standing by..." >> "$LOG_FILE"
 fi
 sleep 2
done
