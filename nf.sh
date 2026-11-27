#!/system/bin/sh
# nf - NestroForge command line tool.
# Installed to /data/adb/NestroForge/bin/nf (and as `nf` on the system PATH).
# Run it as root. From Termux just type:   nf status   (the module adds a launcher),
# or the long way:   su -c "nf status"

MODDIR=/data/adb/modules/NestroForge

if [ "$(id -u)" != "0" ]; then
  echo "nf needs root. Run:  su -c \"nf $*\""
  exit 1
fi
if [ ! -f "$MODDIR/common.sh" ]; then
  echo "NestroForge module folder not found ($MODDIR)"
  exit 1
fi
. "$MODDIR/common.sh"
. "$MODDIR/doctor.sh"

usage() {
  cat <<'USAGE'
nf - NestroForge control

  nf status                    show everything
  nf log [lines|export [file]] last log lines (default 20), or save a report to share
  nf apply                     re-apply everything now (keybox, patch, ADB, description)
  nf doctor                    check the whole setup and suggest fixes
  nf target [list|add PKG...|remove PKG...|path]   Tricky Store target apps
  nf backup [file] [--with-keybox]   save the config (and optionally the keybox) to a tar
  nf restore FILE              restore a backup made by nf backup

  nf keybox [apply|status|path]
  nf patch  [show|set YYYY-MM-DD|auto|off]  security patch spoofing
  nf adb    [on|off|status]                local ADB (localhost only)
  nf termux [link|unlink|status]           'nf' command inside Termux
  nf notify [on|off|sample]
  nf bootloop [status|reset]               reset re-enables a tripped module
  nf config [show|check|set KEY VALUE]
USAGE
}

EXPORT_DIR="$DATA_DIR/exports"

# ── nf log export ────────────────────────────────────────────────────────────
nf_log_export() {
  _O="${1:-$EXPORT_DIR/NestroForge-report-$(date +%Y%m%d-%H%M%S).txt}"
  mkdir -p "${_O%/*}"
  {
    echo "# NestroForge report - $(date)"
    echo "# Device: $(getprop ro.product.model), Android $(getprop ro.build.version.release), $(nf_root_manager)"
    echo ""
    nf_print_status
    nf_doctor
    echo ""
    echo "# ---- log ----"
    [ -f "$LOGFILE.old" ] && cat "$LOGFILE.old"
    cat "$LOGFILE" 2>/dev/null
  } > "$_O" 2>&1
  chmod 600 "$_O" 2>/dev/null
  echo "Report saved: $_O"
  echo "(it contains no keybox or key material)"
}

# ── nf target ────────────────────────────────────────────────────────────────
# Tricky Store's target.txt: one package per line, optional ! or ? suffix (as Tricky
# Store defines them), lines starting with # are comments.
nf_target_valid() {
  case "${1%[?!]}" in
    ''|*[!A-Za-z0-9._]*|.*|*.|*..*) return 1 ;;
    *.*) return 0 ;;
    *) return 1 ;;
  esac
}

nf_target_list() {
  _TF="$TS_TARGET_DIR/target.txt"
  if [ ! -f "$_TF" ]; then echo "(no target.txt yet - nf target add PACKAGE)"; return 0; fi
  _N="$(grep -cvE '^[[:space:]]*(#|$)' "$_TF")"
  grep -vE '^[[:space:]]*(#|$)' "$_TF"
  echo "($_N target(s) in $_TF)"
}

nf_target_add() {
  nf_target_valid "$1" || { echo "not a valid package name: $1"; return 1; }
  _B="${1%[?!]}"; _TF="$TS_TARGET_DIR/target.txt"; _T="$_TF.nf.tmp"
  mkdir -p "$TS_TARGET_DIR"
  [ -f "$_TF" ] || : > "$_TF"
  # same package with another suffix is replaced, not duplicated
  grep -vxF -e "$_B" -e "$_B!" -e "$_B?" "$_TF" > "$_T"
  echo "$1" >> "$_T"
  chmod 0644 "$_T"; chown 0:0 "$_T" 2>/dev/null
  mv -f "$_T" "$_TF" && echo "Added: $1" && nf_log target "added $1"
}

nf_target_remove() {
  _B="${1%[?!]}"; _TF="$TS_TARGET_DIR/target.txt"; _T="$_TF.nf.tmp"
  [ -f "$_TF" ] || { echo "target.txt does not exist"; return 1; }
  grep -qxF -e "$_B" -e "$_B!" -e "$_B?" "$_TF" || { echo "Not in target.txt: $_B"; return 1; }
  grep -vxF -e "$_B" -e "$_B!" -e "$_B?" "$_TF" > "$_T"
  chmod 0644 "$_T"; chown 0:0 "$_T" 2>/dev/null
  mv -f "$_T" "$_TF" && echo "Removed: $_B" && nf_log target "removed $_B"
}

# ── nf backup / restore ──────────────────────────────────────────────────────
nf_backup() {
  _WITHKB=0; _OUT=""
  for _A in "$@"; do
    case "$_A" in --with-keybox) _WITHKB=1 ;; *) _OUT="$_A" ;; esac
  done
  [ -f "$DATA_DIR/config.sh" ] || { echo "no config.sh to back up"; return 1; }
  _OUT="${_OUT:-$EXPORT_DIR/NestroForge-backup-$(date +%Y%m%d-%H%M%S).tar}"
  mkdir -p "${_OUT%/*}"
  _FILES="config.sh"
  [ "$_WITHKB" = "1" ] && [ -f "$DATA_DIR/keybox.xml" ] && _FILES="$_FILES keybox.xml"
  ( umask 077; tar -cf "$_OUT" -C "$DATA_DIR" $_FILES ) || { echo "tar failed"; rm -f "$_OUT"; return 1; }
  chmod 600 "$_OUT" 2>/dev/null
  echo "Backup saved: $_OUT  ($_FILES)"
  if [ "$_WITHKB" = "1" ]; then
    echo "WARNING: this file contains your keybox (private keys). Keep it private."
    case "$_OUT" in /sdcard/*|/storage/*|/data/media/*)
      echo "WARNING: shared storage can be read by other apps. Consider a root-only path." ;; esac
  else
    echo "(keybox not included - add --with-keybox to include it)"
  fi
}

nf_restore() {
  _IN="$1"
  [ -n "$_IN" ] && [ -f "$_IN" ] || { echo "usage: nf restore FILE"; return 1; }
  _LIST="$(tar -tf "$_IN" 2>/dev/null)" || { echo "not a readable tar archive"; return 1; }
  [ -n "$_LIST" ] || { echo "the archive is empty"; return 1; }
  for _E in $_LIST; do
    case "${_E#./}" in config.sh|keybox.xml) ;; *) echo "refusing: unexpected entry '$_E' in the archive"; return 1 ;; esac
  done
  _TMPD="$DATA_DIR/.restore.$$"
  rm -rf "$_TMPD"; mkdir -p "$_TMPD"
  tar -xf "$_IN" -C "$_TMPD" || { echo "could not extract the archive"; rm -rf "$_TMPD"; return 1; }
  for _F in config.sh keybox.xml; do
    [ -L "$_TMPD/$_F" ] && { echo "refusing: $_F is a symlink"; rm -rf "$_TMPD"; return 1; }
  done
  if [ -f "$_TMPD/config.sh" ]; then
    # config.sh is run as shell by this module, so only plain KEY=value lines are accepted
    _BAD="$(grep -vE '^[[:space:]]*(#.*)?$|^[A-Z_]+=("[A-Za-z0-9._:-]*"|[A-Za-z0-9._:-]*)$' "$_TMPD/config.sh")"
    if [ -n "$_BAD" ]; then
      echo "refusing: config.sh in the backup has lines that are not plain KEY=value:"
      echo "$_BAD" | head -n 5
      rm -rf "$_TMPD"; return 1
    fi
  fi
  mkdir -p "$DATA_DIR/backup"
  _TS="$(date +%Y%m%d-%H%M%S)"
  for _F in config.sh keybox.xml; do
    [ -f "$_TMPD/$_F" ] || continue
    if [ -f "$DATA_DIR/$_F" ]; then
      cp -f "$DATA_DIR/$_F" "$DATA_DIR/backup/$_F.$_TS" && chmod 600 "$DATA_DIR/backup/$_F.$_TS"
    fi
    cp -f "$_TMPD/$_F" "$DATA_DIR/$_F.nf.tmp" && chmod 600 "$DATA_DIR/$_F.nf.tmp" && mv -f "$DATA_DIR/$_F.nf.tmp" "$DATA_DIR/$_F" \
      && echo "Restored $_F (old copy in $DATA_DIR/backup/)"
  done
  rm -rf "$_TMPD"
  nf_write_default_config
  nf_load_config
  nf_log restore "restored from $_IN"
  nf_apply_all
  nf_print_status
}

CMD="${1:-status}"
[ $# -gt 0 ] && shift

case "$CMD" in
  status|s)
    nf_print_status
    ;;

  log|logs)
    case "$1" in
      export) nf_log_export "$2" ;;
      *) nf_show_log "${1:-20}" ;;
    esac
    ;;

  doctor|check)
    nf_doctor
    ;;

  target|targets)
    case "${1:-list}" in
      list) nf_target_list ;;
      path) echo "$TS_TARGET_DIR/target.txt" ;;
      add|remove|rm)
        _ACT="$1"; shift
        [ $# -gt 0 ] || { echo "usage: nf target $_ACT PACKAGE [PACKAGE...]"; exit 1; }
        _RC=0
        for _P in "$@"; do
          if [ "$_ACT" = "add" ]; then nf_target_add "$_P" || _RC=1; else nf_target_remove "$_P" || _RC=1; fi
        done
        exit $_RC
        ;;
      *) usage; exit 1 ;;
    esac
    ;;

  backup)
    nf_backup "$@" || exit 1
    ;;

  restore)
    nf_restore "$1" || exit 1
    ;;

  apply|reapply)
    nf_apply_all
    nf_print_status
    ;;

  keybox)
    case "${1:-apply}" in
      apply)  sh "$MODDIR/keybox.sh"; nf_refresh_description; echo "Keybox: $(nf_status_of keybox unknown)" ;;
      status) echo "Keybox: $(nf_status_of keybox unknown)" ;;
      path)   echo "$DATA_DIR/keybox.xml" ;;
      *) usage; exit 1 ;;
    esac
    ;;

  patch)
    case "${1:-show}" in
      show) echo "Security patch: $(nf_status_of patch off)  (config: ${SECURITY_PATCH:-off})" ;;
      set)
        V="$2"
        [ -n "$V" ] || { echo "usage: nf patch set YYYY-MM-DD   (or: nf patch off)"; exit 1; }
        case "$V" in   # accept 20261105 as well
          [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9])
            V="$(echo "$V" | cut -c1-4)-$(echo "$V" | cut -c5-6)-$(echo "$V" | cut -c7-8)" ;;
        esac
        nf_config_set SECURITY_PATCH "$V" || exit 1
        nf_load_config; sh "$MODDIR/patch.sh"; nf_refresh_description
        echo "Security patch: $(nf_status_of patch off)"
        [ "$(nf_status_of patch off)" = "invalid" ] && exit 1
        ;;
      off)
        nf_config_set SECURITY_PATCH "" || exit 1
        nf_load_config; sh "$MODDIR/patch.sh"; nf_refresh_description
        echo "Security patch: off"
        ;;
      *) usage; exit 1 ;;
    esac
    ;;

  adb)
    case "${1:-status}" in
      status) echo "Local ADB: $(nf_status_of adb off)" ;;
      on)  nf_config_set ENABLE_ADB_LOCAL 1; nf_load_config; nf_apply_all; echo "Local ADB: $(nf_status_of adb off)" ;;
      off) nf_config_set ENABLE_ADB_LOCAL 0; nf_load_config; nf_apply_all; echo "Local ADB: $(nf_status_of adb off)" ;;
      *) usage; exit 1 ;;
    esac
    ;;

  termux)
    case "${1:-status}" in
      status) echo "Termux nf: $(nf_termux_state)" ;;
      link)
        nf_config_set ENABLE_TERMUX_LINK 1; nf_load_config   # otherwise the next apply/boot would undo it
        nf_termux_link
        case $? in
          0) echo "Termux: 'nf' command is in place" ;;
          2) echo "Termux is not installed"; exit 1 ;;
          3) echo "Termux was never opened. Open it once, then run this again"; exit 1 ;;
          4) echo "Termux already has a different 'nf', left untouched"; exit 1 ;;
          *) echo "Failed (see: nf log)"; exit 1 ;;
        esac
        ;;
      unlink) nf_config_set ENABLE_TERMUX_LINK 0; nf_load_config; nf_termux_unlink; echo "Termux nf: $(nf_termux_state)" ;;
      *) usage; exit 1 ;;
    esac
    ;;

  notify)
    case "${1:-sample}" in
      on)  nf_config_set ENABLE_NOTIFICATIONS 1; echo "Notifications: on" ;;
      off) nf_config_set ENABLE_NOTIFICATIONS 0; echo "Notifications: off" ;;
      sample)
        if [ "$ENABLE_NOTIFICATIONS" = "1" ]; then
          nf_notify "NestroForge" "Sample notification - it works." sample
          echo "Sample notification sent"
        else
          echo "Notifications are off (nf notify on)"
        fi
        ;;
      *) usage; exit 1 ;;
    esac
    ;;

  bootloop)
    case "${1:-status}" in
      status) nf_print_status | grep -i 'boot guard' ;;
      reset)  nf_bootloop_reset; echo "Boot guard reset. The module runs again on the next boot." ;;
      *) usage; exit 1 ;;
    esac
    ;;

  config)
    case "${1:-show}" in
      show) cat "$CONFIG_FILE" ;;
      check)
        if nf_config_problems; then echo "config.sh: all values are fine"; else exit 1; fi
        ;;
      set)
        [ $# -ge 3 ] || { echo "usage: nf config set KEY VALUE"; exit 1; }
        nf_config_set "$2" "$3" && echo "$2 set (run: nf apply)" ;;
      *) usage; exit 1 ;;
    esac
    ;;

  help|-h|--help) usage ;;
  *) echo "unknown command: $CMD"; usage; exit 1 ;;
esac
