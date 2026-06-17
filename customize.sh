#!/system/bin/sh
# customize.sh - runs during module installation / reinstallation
# Sourced by the module installer script (NOT executed directly)
# Available variables: MAGISK_VER, MAGISK_VER_CODE, MODPATH, ARCH, API, IS64BIT
# DO NOT call exit at the end of this script

MODDIR="${0%/*}"

# ── Enforce install from Magisk app only ────────────────────────────────────
enforce_install_from_magisk_app() {
  if $BOOTMODE; then
    ui_print "- Installing from Magisk app"
  else
    ui_print "*********************************************************"
    ui_print "! Install from recovery is NOT supported"
    ui_print "! Please install from Magisk app"
    abort "*********************************************************"
  fi
}

enforce_install_from_magisk_app

# ── Module info ──────────────────────────────────────────────────────────────
ui_print "- Installing NestroForge"
ui_print "- Version: v1.0"
ui_print "- Author: John Yusuf Habila"
ui_print " "

# ── Example: architecture check ──────────────────────────────────────────────
# if [ "$ARCH" != "arm64" ]; then
#     abort "! Device not supported (arm64 required)"
# fi

# ── Detect reinstall: if module is already present, restore fonts first ──────
# Magisk sets MODPATH to the new staging path; the live installed module
# lives at /data/adb/modules/<module_id>. We derive that path from MODPATH.
MODULE_ID="${MODPATH##*/}"
INSTALLED_MODDIR="/data/adb/modules/$MODULE_ID"

if [ -d "$INSTALLED_MODDIR" ]; then
  ui_print "- Reinstall detected: restoring fonts from previous install"
  # Point font-restore.sh at the currently-installed module dir so it can
  # find the existing backup markers and files.
  MODDIR="$INSTALLED_MODDIR"
  . "$MODDIR/font-restore.sh"
  # Reset MODDIR back to the script context directory for any later use
  MODDIR="${0%/*}"
  ui_print " "
else
  ui_print "- Fresh install detected"
fi

# ── Extract module files ──────────────────────────────────────────────────────
ui_print "- Extracting module files"
unzip -o "$ZIPFILE" -x 'META-INF/*' -d "$MODPATH" >&2

# ── Set permissions ───────────────────────────────────────────────────────────
ui_print "- Setting permissions"
set_perm_recursive "$MODPATH" root root 0755 0644

# ── chmod 755 for executable scripts ─────────────────────────────────────────
ui_print "- Setting executables"
chmod 755 "$MODPATH/service.sh"        2>/dev/null || true
chmod 755 "$MODPATH/post-fs-data.sh"   2>/dev/null || true
chmod 755 "$MODPATH/uninstall.sh"      2>/dev/null || true
chmod 755 "$MODPATH/action.sh"         2>/dev/null || true
chmod 755 "$MODPATH/font-install.sh"   2>/dev/null || true
chmod 755 "$MODPATH/font-restore.sh"   2>/dev/null || true

# ── Font install: scan, back up originals, register injected fonts ────────────
ui_print "- Starting font installation"
# font-install.sh uses MODPATH, which is already set by Magisk
. "$MODPATH/font-install.sh"

ui_print " "
ui_print "- Done!"
