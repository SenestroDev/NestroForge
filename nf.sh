#!/system/bin/sh
# nf - NestroForge command line tool.
# Installed to /data/adb/NestroForge/bin/nf (and as `nf` on the system PATH).
# Run it as root, for example from Termux:   su -c "nf status"

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

usage() {
  cat <<'USAGE'
nf - NestroForge control

  nf status                    show everything
  nf log [lines]               last log lines (default 20)
  nf apply                     re-apply everything now (keybox, patch, ADB, description)

  nf keybox [apply|status|path]
  nf patch  [show|set YYYY-MM-DD|off]      security patch spoofing
  nf adb    [on|off|status]                local ADB (localhost only)
  nf notify [on|off|test]
  nf bootloop [status|reset]               reset re-enables a tripped module
  nf config [show|set KEY VALUE]
USAGE
}

CMD="${1:-status}"
[ $# -gt 0 ] && shift

case "$CMD" in
  status|s)
    nf_print_status
    ;;

  log|logs)
    nf_show_log "${1:-20}"
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

  notify)
    case "${1:-test}" in
      on)  nf_config_set ENABLE_NOTIFICATIONS 1; echo "Notifications: on" ;;
      off) nf_config_set ENABLE_NOTIFICATIONS 0; echo "Notifications: off" ;;
      test)
        if [ "$ENABLE_NOTIFICATIONS" = "1" ]; then
          nf_notify "NestroForge" "Test notification - it works." test
          echo "Test notification sent"
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
      set)  nf_config_set "$2" "$3" && echo "$2 set (run: nf apply)" ;;
      *) usage; exit 1 ;;
    esac
    ;;

  help|-h|--help) usage ;;
  *) echo "unknown command: $CMD"; usage; exit 1 ;;
esac
