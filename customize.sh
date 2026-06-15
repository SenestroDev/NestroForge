#!/system/bin/sh
# customize.sh - runs during module installation
# Sourced by the module installer script (NOT executed directly)
# Available variables: MAGISK_VER, MAGISK_VER_CODE, MODPATH, ARCH, API, IS64BIT
# DO NOT call exit at the end of this script

MODDIR="${0%/*}"

# ── Enforce install from Magisk app only ────────
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

# ── Module info ─────────────────────────────────
ui_print "- Installing NestroForge"
ui_print "- Version: v1.0"
ui_print "- Author: John Yusuf Habila"
ui_print " "

# ── Example: architecture check ─────────────────
# if [ "$ARCH" != "arm64" ]; then
#     abort "! Device not supported (arm64 required)"
# fi

# ── Fresh install: remove and recreate MODPATH ──
if [ -d "$MODPATH" ]; then
  ui_print "- Removing existing module directory"
  rm -rf "$MODPATH"
fi
mkdir -p "$MODPATH"

# ── Extract module files ─────────────────────────
ui_print "- Extracting modules"
unzip -o "$ZIPFILE" -x 'META-INF/*' -d "$MODPATH" >&2

# ── Set permissions ──────────────────────────────
ui_print "- Setting permissions"
set_perm_recursive "$MODPATH" root root 0755 0644

# ── chmod 755 for executable scripts ────────────
ui_print "- Setting executables"
chmod 755 "$MODPATH/service.sh" 2>/dev/null || true
chmod 755 "$MODPATH/post-fs-data.sh" 2>/dev/null || true
chmod 755 "$MODPATH/uninstall.sh" 2>/dev/null || true
chmod 755 "$MODPATH/action.sh" 2>/dev/null || true

ui_print "- Done!"
