#!/bin/bash

# ==============================================================================
# CONFIGURATION CONSTANTS
# ==============================================================================
TARGET_DIR="$HOME/Pictures/SD_Backups"
DESTINATION="$TARGET_DIR/LEICA_DSC_Backup"
LOG_FILE="$HOME/Library/Logs/sd_backup.log"

IMMICH_URL="https://synology.me"
IMMICH_KEY="YOUR_API_KEY"

# Ensure system awake monitoring lanes stay active for background tasks
/usr/bin/caffeinate -s -d &

echo "[$(date)] Headless Audio-Assisted Daemon Initialized." >> "$LOG_FILE"

# ==============================================================================
# 🔊 STARTUP READINESS ANNOUNCEMENT (Plays once right at boot-up)
# ==============================================================================
/usr/bin/afplay /System/Library/Sounds/Subtle.aiff || true
/usr/bin/say "S D backup system is active and ready." || true

# ==============================================================================
# MAIN BACKGROUND DECTION LOOP
# ==============================================================================
while true; do
    # Check if the Leica volume path exists in the system namespace
    if [ -d "/Volumes/LEICA DSC" ]; then
        echo "[$(date)] Leica SD Card Detected!" >> "$LOG_FILE"
        
        # 🔊 START INGEST SIGNALS: Alerts you that the Mac mini acknowledges the card
        /usr/bin/afplay /System/Library/Sounds/Ping.aiff || true
        /usr/bin/say "Leica card detected. Scanning for new items." || true
        
        /bin/mkdir -p "$DESTINATION"
        
        # 1. LOCAL SYNC ENGINE (Smart Mode)
        # Compares size and modification times to identify unique files, completely ignoring duplicate naming counters
        /usr/bin/rsync -avu --ignore-existing --size-only "/Volumes/LEICA DSC/" "$DESTINATION/" >> "$LOG_FILE" 2>&1
        
        # Check how many unique files were actually copied to the landing zone
        NEW_FILE_COUNT=$(/usr/bin/find "$DESTINATION" -type f 2>/dev/null | /usr/bin/wc -l | xargs)
        
        if [ "${NEW_FILE_COUNT:-0}" -gt 0 ]; then
            echo "[$(date)] Found $NEW_FILE_COUNT new assets. Ejecting card path..." >> "$LOG_FILE"
            
            # Unmount the card immediately so it's physically safe to pull out and take with you
            /usr/sbin/diskutil eject "/Volumes/LEICA DSC" >> "$LOG_FILE" 2>&1
            
            # 🔊 CARD SAFE SIGNALS: Tells you right away that you can take your card
            /usr/bin/afplay /System/Library/Sounds/Glass.aiff || true
            sleep 0.1
            /usr/bin/afplay /System/Library/Sounds/Glass.aiff || true
            /usr/bin/say "Backup initialized. You can remove your card now." || true
            
            echo "[$(date)] Launching background sync via immich-go..." >> "$LOG_FILE"
            
            # 2. HEADLESS IMMICH CLOUD SYNC ENGINE
            # Pushes the copied folder up to your Synology server, filtering out background jobs and terminal UI drawing loops
            $HOME/bin/immich-go upload from-folder --no-ui --pause-immich-jobs=false --server="$IMMICH_URL" --api-key="$IMMICH_KEY" "$DESTINATION/" >> "$LOG_FILE" 2>&1
            
            if [ $? -eq 0 ]; then
                echo "[$(date)] Immich verification complete. Wiping local staging buffer..." >> "$LOG_FILE"
                
                # 🗑️ STORAGE PURGE: Clears out the folder entirely to preserve your Mac mini's drive space
                /bin/rm -rf "${DESTINATION:?}"/* >/dev/null 2>&1
                
                # 🔊 SUCCESS SIGNALS: Lets you know from across the room that the photos are live on your timeline
                /usr/bin/afplay /System/Library/Sounds/Tink.aiff || true
                /usr/bin/say "Immich sync complete. Local buffer cleared." || true
            else
                echo "[$(date)] Immich upload routine failed! Keeping local data buffer for safety." >> "$LOG_FILE"
                
                # 🚨 CLOUD REJECTION ALERTS
                /usr/bin/afplay /System/Library/Sounds/Basso.aiff || true
                /usr/bin/say "Warning. Cloud upload failed. Data retained on local disk." || true
            fi
        else
            echo "[$(date)] No unique media signatures detected. Ejecting card safely..." >> "$LOG_FILE"
            
            # Eject the card anyway since there is nothing new to ingest
            /usr/sbin/diskutil eject "/Volumes/LEICA DSC" >> "$LOG_FILE" 2>&1
            
            # Wipe landing track clean just in case hidden files or empty folders were left behind
            /bin/rm -rf "${DESTINATION:?}"/* >/dev/null 2>&1
            
            # 🔊 NO NEW PHOTOS AUDIO MATCH
            /usr/bin/afplay /System/Library/Sounds/Glass.aiff || true
            /usr/bin/say "No new photos found." || true
        fi
        
        # Debounce loop protection: Waits patiently until you physically disconnect the card reader slot
        while [ -d "/Volumes/LEICA DSC" ]; do 
            /bin/sleep 2 
        done
        echo "[$(date)] Physical slot cleared. Re-arming triggers..." >> "$LOG_FILE"
    fi
    
    # Low-overhead interval cadence to watch for cards every 2 seconds
    /bin/sleep 2
done
