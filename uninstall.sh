#!/system/bin/sh
# uninstall.sh - runs when Magisk removes this module (early in the next boot)
# The module folder is still there, so ${0%/*} points at it.

MODDIR=${0%/*}
. "$MODDIR/common.sh"
. "$MODDIR/adb-local.sh"

# Drop the local ADB only if this module enabled it
adb_local_disable

# Remove the Termux 'nf' launcher (only if this module put it there)
nf_termux_unlink

# Your own files in /data/adb/NestroForge (config.sh, keybox.xml, backups, log) are
# left in place on purpose. Delete that folder by hand for a full cleanup.
# The keybox already copied into Tricky Store is also left alone.
