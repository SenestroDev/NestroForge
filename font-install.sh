#!/system/bin/sh
# font-install.sh - Shared helper: scan module fonts, back up originals, prepare for install
# Called by: customize.sh
#
# Required env vars (set by caller before sourcing/calling):
#   MODPATH  — absolute path to the installed module directory
#   ZIPFILE  — path to the module zip (used by caller for extraction, not here)

BACKUP_DIR="$MODPATH/backup/fonts"
MODULE_FONTS_DIR="$MODPATH/system/fonts"

ui_print "- Preparing fonts backup directory"
mkdir -p "$BACKUP_DIR"

ui_print "- Scanning module fonts directory"

if [ ! -d "$MODULE_FONTS_DIR" ]; then
  ui_print "  ! No fonts directory found in module, skipping font install"
  return 0
fi

FOUND=0

for MODULE_FONT in "$MODULE_FONTS_DIR"/*.ttf "$MODULE_FONTS_DIR"/*.otf; do
  # Skip glob expansion if no files matched
  [ -f "$MODULE_FONT" ] || continue

  FOUND=1
  FONT_NAME="${MODULE_FONT##*/}"
  SYSTEM_FONT="/system/fonts/$FONT_NAME"

  ui_print "  - Processing: $FONT_NAME"

  if [ -f "$SYSTEM_FONT" ]; then
    # Font exists in system — back it up and mark for restore on uninstall
    cp "$SYSTEM_FONT" "$BACKUP_DIR/$FONT_NAME"
    touch "$BACKUP_DIR/.restore_$FONT_NAME"
    ui_print "    ✓ Backed up existing system font: $FONT_NAME"
  else
    # Font does not exist in system — mark as fresh injection (remove on uninstall)
    touch "$BACKUP_DIR/.injected_$FONT_NAME"
    ui_print "    ! $FONT_NAME not in system, will be injected fresh"
  fi
done

if [ "$FOUND" -eq 0 ]; then
  ui_print "  ! No .ttf or .otf files found in module fonts directory, skipping"
else
  ui_print "- Font scan complete"
fi
