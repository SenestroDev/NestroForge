#!/system/bin/sh
# post-fs-data.sh - runs in post-fs-data mode (BLOCKING)
# WARNING: Boot is paused until this finishes or 40 seconds pass
# WARNING: Use resetprop -n instead of setprop to avoid deadlock
# Only use this if absolutely necessary

MODDIR="${0%/*}"

# Debug log
LF=/data/adb/NestroForge.log
echo "[post-fs-data.sh] RUNNING AT BOOT..." >> $LF

# Call keybox.sh to place keybox.xml
KBLF=/data/adb/NestroForge-KeyBox.log
sh $MODDIR/keybox.sh >> $KBLF 2>&1