#!/system/bin/sh
# common.sh - shared helpers for every NestroForge script.
# SOURCED by the other scripts (never executed, never calls exit).
# Callers set MODDIR first (MODDIR=${0%/*} at boot, MODDIR=$MODPATH while installing).

DATA_DIR=/data/adb/NestroForge          # survives module updates / reinstalls
CONFIG_FILE="$DATA_DIR/config.sh"
LOGFILE="$DATA_DIR/NestroForge.log"
LOG_MAX_BYTES=102400                    # rotate the log after ~100 KB
TS_MODULE_DIR=/data/adb/modules/tricky_store
TS_TARGET_DIR=/data/adb/tricky_store
BOOT_COUNT_FILE="$DATA_DIR/.boot_count"
TRIP_FILE="$DATA_DIR/.bootloop_tripped"

mkdir -p "$DATA_DIR" 2>/dev/null
chmod 700 "$DATA_DIR" 2>/dev/null

# ── Logging ──────────────────────────────────────────────────────────────────
# nf_log <tag> <message> - timestamped log line, with simple size-based rotation
nf_log() {
  if [ -f "$LOGFILE" ]; then
    _SZ=$(( $(wc -c < "$LOGFILE" 2>/dev/null) + 0 ))
    [ "$_SZ" -gt "$LOG_MAX_BYTES" ] && mv -f "$LOGFILE" "$LOGFILE.old"
  fi
  echo "$(date '+%Y-%m-%d %H:%M:%S') [$1] $2" >> "$LOGFILE"
}

# ── Config ───────────────────────────────────────────────────────────────────
# nf_cfg_add <KEY> <default> <comment, lines separated by \n and starting with "# ">
# Appends the key only if it is missing, so existing configs are upgraded in place.
nf_cfg_add() {
  grep -q "^$1=" "$CONFIG_FILE" 2>/dev/null && return 0
  printf '\n%b\n%s=%s\n' "$3" "$1" "$2" >> "$CONFIG_FILE"
}

# Create the config on first run and add any keys introduced by newer versions.
# Never changes a value the user already set.
nf_write_default_config() {
  if [ ! -f "$CONFIG_FILE" ]; then
    printf '%s\n%s\n' \
      "# NestroForge config - edit, then reboot (or run: su -c nf apply)." \
      "# Values are plain shell: KEY=value, no spaces around the equals sign." > "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
  fi
  nf_cfg_add ENABLE_KEYBOX 1 "# 1 = copy the keybox into Tricky Store at boot, 0 = never touch it."
  nf_cfg_add KEYBOX_OVERWRITE_EXISTING 0 "# Your keybox goes at /data/adb/NestroForge/keybox.xml and is always applied.\n# A bundled keybox will NOT replace a Tricky Store keybox this module did not\n# write, unless this is 1 (the old one is then backed up to .../backup/)."
  nf_cfg_add ENABLE_ADB_LOCAL 0 "# 1 = let adbd listen on localhost only (Termux: adb connect localhost:5555).\n# OFF by default. Needs the IPv4 AND IPv6 firewall rules, otherwise it stays closed."
  nf_cfg_add ADB_LOCAL_PORT 5555 "# Port for local ADB (1024-65535)."
  nf_cfg_add ENABLE_DESCRIPTION 1 "# 1 = show live status in the module description inside the Magisk app."
  nf_cfg_add SECURITY_PATCH '""' "# Spoofed security patch level for Tricky Store, as YYYY-MM-DD (empty = off).\n# Written to /data/adb/tricky_store/security_patch.txt as all=YYYY-MM-DD.\n# Example: SECURITY_PATCH=2026-11-05"
  nf_cfg_add ENABLE_NOTIFICATIONS 1 "# 1 = post a notification after boot when the status changed or something is wrong."
  nf_cfg_add BOOTLOOP_PROTECTION 1 "# 1 = disable this module automatically after too many unfinished boots in a row."
  nf_cfg_add BOOTLOOP_MAX 2 "# Allowed unfinished boots in a row. The next one disables the module.\n# A boot counts as finished 45 s after Android reports boot completed."
}

# Load config with safe defaults. A syntax error must not kill the calling script
# (a failed `.` aborts a non-interactive sh), so the file is checked first.
nf_load_config() {
  ENABLE_KEYBOX=1
  KEYBOX_OVERWRITE_EXISTING=0
  ENABLE_ADB_LOCAL=0
  ADB_LOCAL_PORT=5555
  ENABLE_DESCRIPTION=1
  SECURITY_PATCH=""
  ENABLE_NOTIFICATIONS=1
  BOOTLOOP_PROTECTION=1
  BOOTLOOP_MAX=2
  if [ -f "$CONFIG_FILE" ]; then
    if sh -n "$CONFIG_FILE" 2>/dev/null; then
      . "$CONFIG_FILE"
    else
      nf_log common "config.sh has a syntax error, using defaults"
    fi
  fi
  case "$BOOTLOOP_MAX" in ''|*[!0-9]*) BOOTLOOP_MAX=2 ;; esac
}

# nf_config_set <KEY> <value> - change one known key from the command line.
# Only a fixed list of keys and only safe characters are accepted.
nf_config_set() {
  case "$1" in
    ENABLE_KEYBOX|KEYBOX_OVERWRITE_EXISTING|ENABLE_ADB_LOCAL|ADB_LOCAL_PORT|ENABLE_DESCRIPTION|\
    SECURITY_PATCH|ENABLE_NOTIFICATIONS|BOOTLOOP_PROTECTION|BOOTLOOP_MAX) ;;
    *) echo "unknown key: $1" >&2; return 1 ;;
  esac
  case "$2" in *[!A-Za-z0-9._:-]*) echo "value has characters that are not allowed" >&2; return 1 ;; esac
  if grep -q "^$1=" "$CONFIG_FILE"; then
    sed -i "s|^$1=.*|$1=\"$2\"|" "$CONFIG_FILE"
  else
    echo "$1=\"$2\"" >> "$CONFIG_FILE"
  fi
}

nf_write_default_config
nf_load_config

# ── Small helpers ────────────────────────────────────────────────────────────
# nf_sum <file> - checksum used to tell "our" files from someone else's
nf_sum() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" 2>/dev/null | cut -d' ' -f1
  else
    cksum "$1" 2>/dev/null | cut -d' ' -f1,2 | tr ' ' '-'
  fi
}

# nf_ts_state - prints: ok | disabled | missing
nf_ts_state() {
  if [ ! -d "$TS_MODULE_DIR" ]; then
    echo missing
  elif [ -f "$TS_MODULE_DIR/disable" ] || [ -f "$TS_MODULE_DIR/remove" ]; then
    echo disabled
  else
    echo ok
  fi
}

# nf_status_of <name> <default> - read .status_<name>
nf_status_of() {
  _V="$(cat "$DATA_DIR/.status_$1" 2>/dev/null)"
  echo "${_V:-$2}"
}

# nf_install_cli - keep /data/adb/NestroForge/bin/nf in sync with the module's copy
nf_install_cli() {
  [ -f "$MODDIR/nf.sh" ] || return 0
  mkdir -p "$DATA_DIR/bin"
  cmp -s "$MODDIR/nf.sh" "$DATA_DIR/bin/nf" 2>/dev/null || cp -f "$MODDIR/nf.sh" "$DATA_DIR/bin/nf"
  chmod 755 "$DATA_DIR/bin/nf"
}

nf_quote() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

# ── Notifications ────────────────────────────────────────────────────────────
# nf_notify <title> <text> [tag] - posts through `cmd notification` (as the shell
# package). Runs in the background with a timeout so it can never stall a script.
nf_notify() {
  [ "$ENABLE_NOTIFICATIONS" = "1" ] || return 0
  command -v cmd >/dev/null 2>&1 || return 0
  
  _title=$(nf_quote "$1")
  _body=$(nf_quote "$2")
  _tag=$(nf_quote "${3:-nestroforge}")
  notif="cmd notification post -S bigtext -t $_title $_tag $_body"
  
  (
    if [ "$(id -u)" = "2000" ]; then
      set -- sh -c "$notif"
    else
      set -- su 2000 -c "$notif"
    fi
    if command -v timeout >/dev/null 2>&1; then
      timeout 15 "$@"
    else
      "$@"
    fi
  ) >/dev/null 2>&1 &
}

# nf_summary - one-line state used by the description and the notification
nf_summary() {
  _P="$(nf_status_of patch off)"
  _S="Keybox: $(nf_status_of keybox unknown) | Tricky Store: $(nf_ts_state) | ADB: $(nf_status_of adb off)"
  [ "$_P" = "off" ] || _S="$_S | Patch: $_P"
  echo "$_S"
}

# nf_has_problem - return 0 if something needs attention
nf_has_problem() {
  _KB="$(nf_status_of keybox unknown)"
  if [ "$ENABLE_KEYBOX" = "1" ]; then
    case "$_KB" in ok) ;; *) return 0 ;; esac
    [ "$(nf_ts_state)" = "ok" ] || return 0
  fi
  [ "$(nf_status_of adb off)" = "blocked" ] && return 0
  [ "$(nf_status_of patch off)" = "invalid" ] && return 0
  return 1
}

# nf_notify_changes - notify only when the overall state differs from the last
# notification, so a healthy device is not nagged on every boot.
nf_notify_changes() {
  _STATE="$(nf_summary)"
  [ "$_STATE" = "$(cat "$DATA_DIR/.last_notified" 2>/dev/null)" ] && return 0
  echo "$_STATE" > "$DATA_DIR/.last_notified"
  if nf_has_problem; then
    nf_notify "NestroForge: needs attention" "$_STATE" status
  else
    nf_notify "NestroForge: all good" "$_STATE" status
  fi
}

# ── Description ──────────────────────────────────────────────────────────────
# nf_refresh_description - write the live status into module.prop.
# update-description.sh keeps the ORIGINAL description in module.prop.bak, so
# running this on every boot never stacks text.
nf_refresh_description() {
  [ "$ENABLE_DESCRIPTION" = "1" ] || return 0
  [ -f "$MODDIR/update-description.sh" ] || return 0
  _ICON="✅"
  nf_has_problem && _ICON="⚠️"
  sh "$MODDIR/update-description.sh" -backup -prepend -desc "$_ICON $(nf_summary) |"
}

# ── Boot-loop protection ─────────────────────────────────────────────────────
# post-fs-data.sh calls nf_bootloop_check at every boot; service.sh calls
# nf_bootloop_ok 45 s after Android finished booting. If the counter is not
# cleared BOOTLOOP_MAX times in a row, the module disables itself (creates
# <module>/disable) and stays out of the next boot.
# Returns 0 = carry on, 1 = tripped (caller must stop).
nf_bootloop_check() {
  if [ "$BOOTLOOP_PROTECTION" != "1" ]; then
    rm -f "$BOOT_COUNT_FILE"
    return 0
  fi
  if [ -f "$TRIP_FILE" ]; then
    # Same boot that tripped: the disable file is still there
    [ -f "$MODDIR/disable" ] && return 1
    # The user re-enabled the module: start counting from zero again
    rm -f "$TRIP_FILE"
    echo 0 > "$BOOT_COUNT_FILE"
    nf_log bootloop "module re-enabled, boot-loop counter reset"
  fi
  _N=$(( $(cat "$BOOT_COUNT_FILE" 2>/dev/null) + 0 ))
  _N=$((_N + 1))
  echo "$_N" > "$BOOT_COUNT_FILE"
  if [ "$_N" -gt "$BOOTLOOP_MAX" ]; then
    touch "$MODDIR/disable"
    echo "$(date '+%Y-%m-%d %H:%M:%S') unfinished boots: $_N" > "$TRIP_FILE"
    echo 0 > "$BOOT_COUNT_FILE"
    nf_log bootloop "TRIPPED after $_N unfinished boots - module disabled"
    return 1
  fi
  nf_log bootloop "boot attempt $_N of $BOOTLOOP_MAX allowed"
  return 0
}

# nf_bootloop_ok - the boot finished and stayed up: clear the counter
nf_bootloop_ok() {
  [ "$BOOTLOOP_PROTECTION" = "1" ] || return 0
  echo 0 > "$BOOT_COUNT_FILE"
  nf_log bootloop "boot finished, counter cleared"
}

# nf_bootloop_reset - used by `nf bootloop reset`: re-enable and clear everything
nf_bootloop_reset() {
  rm -f "$TRIP_FILE" "$MODDIR/disable"
  echo 0 > "$BOOT_COUNT_FILE"
  nf_log bootloop "reset by user (module re-enabled for the next boot)"
}

# ── Apply everything / status / log (shared by service.sh, action.sh, nf) ────
nf_apply_all() {
  [ "$ENABLE_KEYBOX" = "1" ] && sh "$MODDIR/keybox.sh"
  sh "$MODDIR/patch.sh"
  . "$MODDIR/adb-local.sh"
  if [ "$ENABLE_ADB_LOCAL" = "1" ]; then
    adb_local_enable
  elif [ -f "$ADB_LOCAL_MARKER" ]; then
    adb_local_disable
  else
    adb_set_status off
  fi
  nf_refresh_description
}

nf_print_status() {
  echo "NestroForge $(grep -m1 '^version=' "$MODDIR/module.prop" 2>/dev/null | cut -d= -f2-)"
  echo "------------------------------"
  echo "Tricky Store  : $(nf_ts_state)"
  echo "Keybox        : $(nf_status_of keybox unknown)"
  echo "Security patch: $(nf_status_of patch off)"
  echo "Local ADB     : $(nf_status_of adb off)"
  [ "$ENABLE_NOTIFICATIONS" = "1" ] && _NT=on || _NT=off
  echo "Notifications : $_NT"
  if [ "$BOOTLOOP_PROTECTION" = "1" ]; then
    _BG="on, unfinished boots $(cat "$BOOT_COUNT_FILE" 2>/dev/null || echo 0)/$BOOTLOOP_MAX"
    [ -f "$TRIP_FILE" ] && _BG="$_BG, TRIPPED ($(cat "$TRIP_FILE"))"
  else
    _BG=off
  fi
  echo "Boot guard    : $_BG"
  echo "Data folder   : $DATA_DIR"
}

# nf_show_log [lines]
nf_show_log() {
  tail -n "${1:-15}" "$LOGFILE" 2>/dev/null || echo "(no log yet)"
}
