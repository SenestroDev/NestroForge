#!/system/bin/sh
# post-fs-data.sh - runs in post-fs-data mode (BLOCKING: boot waits for it, max 40 s)
# Keep it tiny: boot-loop check, then the two quick file copies (keybox, security
# patch) so they exist before the Tricky Store daemon starts.
# Everything else lives in service.sh.

# MODPATH only exists while installing, so at boot it is empty.
MODDIR=${0%/*}
. "$MODDIR/common.sh"

nf_log post-fs-data "running"

# Boot-loop protection: after too many unfinished boots the module disables itself
if ! nf_bootloop_check; then
  nf_log post-fs-data "boot-loop protection is active, doing nothing this boot"
  exit 0
fi

nf_install_cli

# Run with sh instead of sourcing: these scripts use exit.
[ "$ENABLE_KEYBOX" = "1" ] && sh "$MODDIR/keybox.sh"
sh "$MODDIR/patch.sh"
