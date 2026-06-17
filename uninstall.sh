#!/system/bin/sh
# uninstall.sh - runs when Magisk removes this module
# MODDIR is provided by Magisk and points to the installed module directory.

# ── Font restore via shared helper ───────────────────────────────────────────
# font-restore.sh expects MODDIR to be set, which Magisk already provides.
. "$MODDIR/font-restore.sh"
