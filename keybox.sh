#!/system/bin/sh

MODULE_DIR=/data/adb/modules/tricky_store
TARGET_DIR=/data/adb/tricky_store
SOURCE_FILE=${0%/*}/xml/keybox.xml
TARGET_FILE=$TARGET_DIR/keybox.xml
LOGFILE=/data/adb/NestroForge-KeyBox.log

if [ ! -d "$MODULE_DIR" ]; then
    MSG="[keybox.sh] Tricky Store module is not installed ($MODULE_DIR not found). Install it first."
    echo "$MSG"
    echo "$MSG" >> $LOGFILE
    exit 1
fi

mkdir -p "$TARGET_DIR"

if [ -f "$SOURCE_FILE" ]; then
    cp -f "$SOURCE_FILE" "$TARGET_FILE"
    chmod 0644 "$TARGET_FILE"
    chown 0:0 "$TARGET_FILE"
    echo "[keybox.sh] keybox.xml successfully placed in $TARGET_DIR" >> $LOGFILE
else
    echo "[keybox.sh] ERROR: keybox.xml not found at $SOURCE_FILE" >> $LOGFILE
fi
