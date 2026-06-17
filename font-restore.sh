#!/system/bin/sh
# font-restore.sh - Shared helper: restore backed-up fonts and remove injected fonts
# Called by: customize.sh (on reinstall, before fresh install) and uninstall.sh
#
# Required env vars (set by caller before sourcing/calling):
#   MODDIR  — absolute path to the module directory containing the backup folder
#             In customize.sh this should be the EXISTING module dir (before re-extract),
#             in uninstall.sh this is the standard $MODDIR provided by Magisk.

BACKUP_DIR="$MODDIR/backup/fonts"
mkdir -p "$BACKUP_DIR"

ui_print "- Running font restore/cleanup"

if [ ! -d "$BACKUP_DIR" ]; then
  ui_print "  ! No backup directory found, nothing to restore"
  return 0
fi

# Check if any marker files exist before remounting
MARKERS_FOUND=0
for MARKER in "$BACKUP_DIR"/.restore_* "$BACKUP_DIR"/.injected_*; do
  [ -f "$MARKER" ] && MARKERS_FOUND=1 && break
done

if [ "$MARKERS_FOUND" -eq 0 ]; then
  ui_print "  ! No font markers found, nothing to restore"
  return 0
fi

mount -o remount,rw /system 2>/dev/null

for MARKER in "$BACKUP_DIR"/.restore_* "$BACKUP_DIR"/.injected_*; do
  # Skip glob expansion if no files matched
  [ -f "$MARKER" ] || continue

  MARKER_NAME="${MARKER##*/}"

  case "$MARKER_NAME" in
    .restore_*)
      # Font was backed up from system — restore the original
      FONT_NAME="${MARKER_NAME#.restore_}"
      BACKUP_FILE="$BACKUP_DIR/$FONT_NAME"
      SYSTEM_FONT="/system/fonts/$FONT_NAME"

      if [ -f "$BACKUP_FILE" ]; then
        cp "$BACKUP_FILE" "$SYSTEM_FONT"
        chmod 644 "$SYSTEM_FONT"
        chown root:root "$SYSTEM_FONT"
        ui_print "  ✓ Restored: $FONT_NAME"
      else
        ui_print "  ! Backup file missing for $FONT_NAME, skipping restore"
      fi
      ;;

    .injected_*)
      # Font was injected fresh (did not exist in system before) — remove it
      FONT_NAME="${MARKER_NAME#.injected_}"
      SYSTEM_FONT="/system/fonts/$FONT_NAME"

      if [ -f "$SYSTEM_FONT" ]; then
        rm -f "$SYSTEM_FONT"
        ui_print "  ✓ Removed injected font: $FONT_NAME"
      else
        ui_print "  ! Injected font $FONT_NAME already absent, skipping"
      fi
      ;;
  esac
done

mount -o remount,ro /system 2>/dev/null
ui_print "- Font restore/cleanup complete"
