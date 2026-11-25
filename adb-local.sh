#!/system/bin/sh
# adb-local.sh - let adbd listen on TCP so a terminal on the phone (e.g. Termux)
# can reach it with: adb connect localhost:5555
#
# adbd listens on ALL interfaces, so a firewall rule drops everything to the ADB
# port that does not arrive on loopback (lo). ADB over TCP is opened ONLY if that
# rule is in place for BOTH IPv4 and IPv6 (many mobile networks hand out globally
# routable IPv6, and adbd listens on :: too).
#
# Sourced by service.sh / action.sh / uninstall.sh after common.sh, so it uses
# `return` (never `exit`).
#
# Note: any app on the phone can still reach 127.0.0.1:<port> and trigger the
# "Allow USB debugging?" prompt. Never tick "Always allow" for something you don't trust.

[ -n "$DATA_DIR" ] || . "$MODDIR/common.sh"

ADB_LOCAL_PORT="${ADB_LOCAL_PORT:-5555}"
# Reject anything that is not a sane unprivileged port
case "$ADB_LOCAL_PORT" in
  ''|*[!0-9]*) ADB_LOCAL_PORT=5555 ;;
esac
{ [ "$ADB_LOCAL_PORT" -ge 1024 ] && [ "$ADB_LOCAL_PORT" -le 65535 ]; } || ADB_LOCAL_PORT=5555

# Marker: exists only while THIS module turned ADB over TCP on. Stores the port.
# Lives in DATA_DIR (not the module folder) so it survives module updates.
ADB_LOCAL_MARKER="$DATA_DIR/.adb_local_enabled"
ADB_STATUS_FILE="$DATA_DIR/.status_adb"

adb_log() { nf_log adb-local "$1"; }
adb_set_status() { echo "$1" > "$ADB_STATUS_FILE"; }

# Print the TCP port adbd is already configured to use and return 0, or return 1.
# Empty, 0 and -1 all mean "TCP off".
adb_configured_port() {
  for P in "$(getprop service.adb.tcp.port)" "$(getprop persist.adb.tcp.port)"; do
    case "$P" in
      ''|*[!0-9]*) continue ;;
    esac
    if [ "$P" -gt 0 ]; then
      echo "$P"
      return 0
    fi
  done
  return 1
}

# Return 0 if something is already listening on TCP port $1 (state 0A = LISTEN).
adb_port_listening() {
  HEX="$(printf '%04X' "$1")"
  grep -qiE ":$HEX [0-9A-F:]+ 0A " /proc/net/tcp /proc/net/tcp6 2>/dev/null
}

# Restart adbd so it re-reads the port. Only if it already runs: starting it by
# hand while USB debugging is off would turn ADB on behind the user's back.
adb_restart_adbd() {
  if [ "$(getprop init.svc.adbd)" != "running" ]; then
    adb_log "adbd is not running (USB debugging off?), it will read the setting when it starts"
    return 0
  fi
  # Note: this drops any ADB session that is open right now (for example over USB)
  stop adbd
  sleep 1
  start adbd
}

# ── Firewall ─────────────────────────────────────────────────────────────────
# Rules live in kernel memory and vanish on reboot; service.sh re-adds them.

# adb_fw_add <iptables|ip6tables> <port> - idempotent, inserted at the top of INPUT
adb_fw_add() {
  command -v "$1" >/dev/null 2>&1 || return 1
  "$1" -w -C INPUT -p tcp --dport "$2" ! -i lo -j DROP 2>/dev/null && return 0
  "$1" -w -I INPUT 1 -p tcp --dport "$2" ! -i lo -j DROP 2>/dev/null
}

# Remove the rules for port $1 (loops in case a rule was added more than once)
adb_local_firewall_off() {
  for IPT in iptables ip6tables; do
    command -v "$IPT" >/dev/null 2>&1 || continue
    while "$IPT" -w -C INPUT -p tcp --dport "$1" ! -i lo -j DROP 2>/dev/null; do
      "$IPT" -w -D INPUT -p tcp --dport "$1" ! -i lo -j DROP 2>/dev/null || break
    done
  done
}

# Return 0 ONLY if the rule is in place for IPv4 AND IPv6. On any failure the rules
# already added are rolled back, so nothing half-configured is left behind.
adb_local_firewall_on() {
  if ! adb_fw_add iptables "$1"; then
    adb_log "could not add the iptables (IPv4) rule for port $1"
    return 1
  fi
  if command -v ip6tables >/dev/null 2>&1; then
    if ! adb_fw_add ip6tables "$1"; then
      adb_log "could not add the ip6tables (IPv6) rule for port $1"
      adb_local_firewall_off "$1"
      return 1
    fi
  elif [ -s /proc/net/if_inet6 ]; then
    # IPv6 is active on this device but there is no tool to firewall it
    adb_log "IPv6 is active but ip6tables is missing"
    adb_local_firewall_off "$1"
    return 1
  fi
  return 0
}

# ── Enable / disable ─────────────────────────────────────────────────────────
adb_local_enable() {
  EXISTING="$(adb_configured_port)"

  # Already enabled by us during this boot (e.g. Action button pressed again)
  if [ -f "$ADB_LOCAL_MARKER" ] && [ -n "$EXISTING" ] && [ "$EXISTING" = "$(cat "$ADB_LOCAL_MARKER" 2>/dev/null)" ]; then
    if adb_local_firewall_on "$EXISTING"; then
      adb_set_status "loopback:$EXISTING"
      return 0
    fi
    adb_set_status "blocked"
    return 1
  fi

  if [ -n "$EXISTING" ] || adb_port_listening "$ADB_LOCAL_PORT"; then
    adb_log "ADB over TCP already available (port ${EXISTING:-$ADB_LOCAL_PORT}), leaving it alone"
    # Not ours: uninstall must never drop it, and we don't firewall it
    rm -f "$ADB_LOCAL_MARKER"
    adb_set_status "external:${EXISTING:-$ADB_LOCAL_PORT}"
    return 0
  fi

  # Close the port to the network BEFORE opening it
  if ! adb_local_firewall_on "$ADB_LOCAL_PORT"; then
    adb_log "NOT enabling ADB over TCP: firewall rules could not be fully applied"
    adb_set_status "blocked"
    return 1
  fi

  adb_log "Enabling ADB over TCP on port $ADB_LOCAL_PORT (loopback only, IPv4+IPv6 firewalled)"
  # service.* is not persistent; service.sh sets it again on every boot
  resetprop service.adb.tcp.port "$ADB_LOCAL_PORT"
  echo "$ADB_LOCAL_PORT" > "$ADB_LOCAL_MARKER"
  adb_restart_adbd
  adb_set_status "loopback:$ADB_LOCAL_PORT"
}

# Drop the setting and firewall rules, but only if this module enabled them.
adb_local_disable() {
  adb_set_status "off"
  if [ ! -f "$ADB_LOCAL_MARKER" ]; then
    adb_log "ADB over TCP was not enabled by this module, nothing to drop"
    return 0
  fi

  OPENED_PORT="$(cat "$ADB_LOCAL_MARKER" 2>/dev/null)"
  [ -n "$OPENED_PORT" ] || OPENED_PORT="$ADB_LOCAL_PORT"

  adb_log "Dropping ADB over TCP (port $OPENED_PORT)"
  # After a reboot the property is already gone (the marker is stale): then there is
  # nothing to restart, so the USB session is not dropped for no reason.
  if [ -n "$(getprop service.adb.tcp.port)" ]; then
    resetprop --delete service.adb.tcp.port 2>/dev/null || resetprop service.adb.tcp.port 0
    rm -f "$ADB_LOCAL_MARKER"
    adb_restart_adbd
  else
    rm -f "$ADB_LOCAL_MARKER"
  fi
  # Close the firewall hole last, after adbd has stopped listening
  adb_local_firewall_off "$OPENED_PORT"
}
