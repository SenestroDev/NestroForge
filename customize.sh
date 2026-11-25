#!/system/bin/sh
# customize.sh - runs during module installation / reinstallation
# Sourced by the module installer script (NOT executed directly)
# Available variables: MAGISK_VER, MAGISK_VER_CODE, MODPATH, ARCH, API, IS64BIT
# DO NOT call exit at the end of this script

# We extract files ourselves below, so tell Magisk not to extract them again.
# Keep this on its own line: the installer detects it with grep '^SKIPUNZIP=1$'.
SKIPUNZIP=1

# customize.sh is SOURCED, so ${0%/*} would give the installer's directory, not the module's.
# Use MODPATH here. Scripts that run from the installed module use MODDIR=${0%/*}.
MODDIR="$MODPATH"

# ── Enforce install from Magisk app only ────────────────────────────────────
if $BOOTMODE; then
  ui_print "- Installing from Magisk app"
else
  ui_print "*********************************************************"
  ui_print "! Install from recovery is NOT supported"
  ui_print "! Please install from Magisk app"
  abort "*********************************************************"
fi

# ── Read module info from module.prop ────────────────────────────────────────
# SKIPUNZIP=1 means Magisk extracts nothing for us, so pull module.prop out ourselves.
unzip -o "$ZIPFILE" module.prop -d "$TMPDIR" >&2

# Read one key from module.prop (first match; tr strips CR from CRLF files)
get_prop() {
  grep -m1 "^$1=" "$TMPDIR/module.prop" | cut -d= -f2- | tr -d '\r'
}

MOD_NAME="$(get_prop name)"
MOD_VERSION="$(get_prop version)"
MOD_AUTHOR="$(get_prop author)"

ui_print "- Installing $MOD_NAME"
ui_print "- Version: $MOD_VERSION"
ui_print "- Author: $MOD_AUTHOR"
ui_print " "

# ── Compatibility checks ─────────────────────────────────────────────────────
# MAGISK_VER_CODE may be empty on other root managers, so every test is guarded.
if [ -n "$MAGISK_VER_CODE" ] && [ "$MAGISK_VER_CODE" -lt 24000 ]; then
  abort "! Magisk 24.0 or newer is required (found $MAGISK_VER)"
fi
if [ -n "$MAGISK_VER_CODE" ] && [ "$MAGISK_VER_CODE" -lt 27000 ]; then
  ui_print "! Magisk older than 27: the Action button will not be available"
fi

ui_print "- Device: $(getprop ro.product.model) ($(getprop ro.board.platform)), Android $(getprop ro.build.version.release)"
if [ "$(getprop ro.board.platform)" != "mt6768" ]; then
  ui_print "! system.prop is written for MT6768 (Helio G85). Its tweaks are all"
  ui_print "! disabled by default - review them before enabling on this device."
fi

if [ ! -d /data/adb/modules/tricky_store ] && [ ! -d /data/adb/modules_update/tricky_store ]; then
  ui_print "! Tricky Store is not installed - the keybox cannot be used until it is."
  ui_print "! Install Tricky Store, then reboot."
fi

# ── Reinstall detection ──────────────────────────────────────────────────────
MODULE_ID="$(get_prop id)"
[ -z "$MODULE_ID" ] && MODULE_ID="${MODPATH##*/}"
if [ -d "/data/adb/modules/$MODULE_ID" ]; then
  ui_print "- Reinstall detected: updating existing install"
else
  ui_print "- Fresh install detected"
fi

# ── Extract module files ─────────────────────────────────────────────────────
ui_print "- Extracting module files"
unzip -o "$ZIPFILE" -x 'META-INF/*' '*.md' '.git*' -d "$MODPATH" >&2

[ -f "$MODPATH/common.sh" ] || abort "! common.sh is missing from the zip, aborting"

# ── Persistent data folder + default config (existing config is never overwritten) ──
. "$MODPATH/common.sh"
nf_write_default_config
ui_print "- Config: $CONFIG_FILE"

# Command line tool: /data/adb/NestroForge/bin/nf (also on PATH as `nf`)
nf_install_cli
ui_print "- CLI installed: /data/adb/NestroForge/bin/nf"

# Make `nf` work directly inside Termux (only if Termux is installed)
if [ "$ENABLE_TERMUX_LINK" = "1" ]; then
  nf_termux_link
  case $? in
    0) ui_print "- Termux: 'nf' command added (just type: nf status)" ;;
    2) ui_print "- Termux not installed, skipping the Termux command" ;;
    3) ui_print "! Termux is installed but was never opened. Open it once, then run:"
       ui_print "!   su -c \"nf termux link\"   (or reboot)" ;;
    4) ui_print "! Termux already has a different 'nf' command, left untouched" ;;
    *) ui_print "! Could not add the Termux command (see $LOGFILE)" ;;
  esac
else
  ui_print "- Termux command is off (ENABLE_TERMUX_LINK=0 in config.sh)"
fi

# A fresh install starts with a clean boot-loop counter
rm -f "$TRIP_FILE" "$DATA_DIR/.last_notified"
echo 0 > "$BOOT_COUNT_FILE"

if [ -f "$DATA_DIR/keybox.xml" ]; then
  ui_print "- Using your keybox: $DATA_DIR/keybox.xml"
elif [ -f "$MODPATH/keybox.xml" ]; then
  ui_print "- Using the keybox bundled in the module"
  ui_print "  (put your own at $DATA_DIR/keybox.xml to override it)"
else
  ui_print "! No keybox found. Put yours at $DATA_DIR/keybox.xml"
fi

# ── Set permissions ──────────────────────────────────────────────────────────
ui_print "- Setting permissions"
set_perm_recursive "$MODPATH" root root 0755 0644
for f in service.sh post-fs-data.sh uninstall.sh action.sh keybox.sh patch.sh nf.sh \
         update-description.sh adb-local.sh common.sh system/bin/nf; do
  [ -f "$MODPATH/$f" ] && chmod 755 "$MODPATH/$f"
done
# The keybox holds private keys: root-only
[ -f "$MODPATH/keybox.xml" ] && chmod 600 "$MODPATH/keybox.xml"

ui_print "- Local ADB is OFF by default (enable it in config.sh)"
ui_print "- Changes apply on next reboot"
ui_print " "
ui_print "- Done!"
