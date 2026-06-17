#!/system/bin/sh
# uninstall.sh - runs when Magisk removes this module

MODDIR="${0%/*}"

# ── Font restore logic ────────────────────────────
BACKUP_DIR="$MODDIR/backup"

ui_print "- Running font cleanup"

if [ ! -d "$BACKUP_DIR" ]; then
  ui_print "  ! No backup directory found, skipping"
else
  mount -o remount,rw /system 2>/dev/null

  for MARKER in "$BACKUP_DIR"/.restore_* "$BACKUP_DIR"/.injected_*; do
    # Skip glob if no files matched
    [ -f "$MARKER" ] || continue

    MARKER_NAME="${MARKER##*/}"

    case "$MARKER_NAME" in
      .restore_*)
        # Font was backed up — restore original
        FONT_NAME="${MARKER_NAME#.restore_}"
        BACKUP_FILE="$BACKUP_DIR/$FONT_NAME"
        SYSTEM_FONT="/system/fonts/$FONT_NAME"

        if [ -f "$BACKUP_FILE" ]; then
          cp "$BACKUP_FILE" "$SYSTEM_FONT"
          chmod 644 "$SYSTEM_FONT"
          chown root:root "$SYSTEM_FONT"
          ui_print "  ✓ Restored $FONT_NAME"
        else
          ui_print "  ! Backup missing for $FONT_NAME, skipping restore"
        fi
        ;;

      .injected_*)
        # Font was injected fresh — remove it
        FONT_NAME="${MARKER_NAME#.injected_}"
        SYSTEM_FONT="/system/fonts/$FONT_NAME"

        rm -f "$SYSTEM_FONT"
        ui_print "  ✓ Removed injected $FONT_NAME"
        ;;
    esac
  done

  mount -o remount,ro /system 2>/dev/null
  ui_print "- Font cleanup complete"
fi
