#!/system/bin/sh
# service.sh - runs in late_start service mode (NON-BLOCKING)

MODDIR=${0%/*}
. "$MODDIR/common.sh"

nf_log service "started"

# Wait until Android has really finished booting (max ~3 min) instead of a fixed sleep
i=0
until [ "$(getprop sys.boot_completed)" = "1" ] || [ "$i" -ge 90 ]; do
  sleep 2
  i=$((i + 1))
done
BOOT_OK=1
if [ "$i" -ge 90 ]; then
  BOOT_OK=0
  nf_log service "boot_completed not seen after 3 min, continuing anyway"
fi

# Boot-loop protection tripped during this boot: stay out of the way and say so
if [ -f "$TRIP_FILE" ] && [ -f "$MODDIR/disable" ]; then
  nf_log service "module disabled by boot-loop protection, skipping everything"
  nf_notify "NestroForge disabled" "Too many unfinished boots in a row, so the module turned itself off. Re-enable it in Magisk, or run: su -c nf bootloop reset" bootloop
  exit 0
fi

# Keep the CLI current, then apply keybox + security patch + local ADB + description.
# (keybox/patch are idempotent, so this is also a safety net for post-fs-data.)
# A watchdog from the previous boot cannot be alive any more
rm -f "$DATA_DIR/.adb_watchdog.pid"

nf_install_cli
nf_apply_all

# Notify only when the state changed or something needs attention
nf_notify_changes

nf_log service "done"

# The boot only counts as finished once the system stayed up for a while
if [ "$BOOT_OK" = "1" ]; then
  sleep 45
  nf_bootloop_ok
fi
