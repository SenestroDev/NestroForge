#!/system/bin/sh
# action.sh - runs when the user taps the Action button in the Magisk app (Magisk 27+)
#
# Small menu driven with the volume keys:
#   Volume DOWN = move the arrow to the next entry
#   Volume UP   = select (run) the highlighted entry
# Entries: Status / Last log lines / Re-apply everything / Exit
# If the keys cannot be read (or nothing is pressed for 30 s at the start), the
# status is simply printed once.
#
# While this script runs the volume of the media/ring streams is pinned to the
# value it had at start, so the volume keys only act as menu keys.

MODDIR="${0%/*}"
. "$MODDIR/common.sh"

VOLPID=""
LOCK=""
STREAMS="3 2"        # 3 = media, 2 = ring. Add 5 (notification) / 0 (call) if needed
TTY=0
[ -t 1 ] && TTY=1

# ---------------------------------------------------------------------------
# Volume lock
# ---------------------------------------------------------------------------
VOLCMD=""
if command -v cmd >/dev/null 2>&1 && cmd media_session volume --stream 3 --get 2>&1 | grep -q 'volume is'; then
  VOLCMD="cmd media_session"
elif command -v media >/dev/null 2>&1 && media volume --stream 3 --get 2>&1 | grep -q 'volume is'; then
  VOLCMD="media"
fi

vol_get() {
  $VOLCMD volume --stream "$1" --get 2>/dev/null | sed -n 's/.*volume is \([0-9][0-9]*\).*/\1/p' | head -n 1
}

vol_set() {
  $VOLCMD volume --stream "$1" --set "$2" >/dev/null 2>&1
}

lock_volume() {
  [ -n "$VOLCMD" ] || return
  for _S in $STREAMS; do
    _V="$(vol_get "$_S")"
    [ -n "$_V" ] && LOCK="$LOCK $_S:$_V"
  done
  [ -n "$LOCK" ] || return
  (
    while :; do
      for _P in $LOCK; do
        _S="${_P%%:*}"; _T="${_P##*:}"
        _C="$(vol_get "$_S")"
        [ -n "$_C" ] && [ "$_C" != "$_T" ] && vol_set "$_S" "$_T"
      done
      sleep 0.1
    done
  ) >/dev/null 2>&1 &
  VOLPID=$!
}

cleanup() {
  [ -n "$VOLPID" ] && kill "$VOLPID" 2>/dev/null
  VOLPID=""
  for _P in $LOCK; do vol_set "${_P%%:*}" "${_P##*:}"; done
  LOCK=""
}
trap cleanup EXIT INT TERM

# ---------------------------------------------------------------------------
# Key reading (chooseport method, chainfire / ianmacd)
# getevent runs for 1 second per round, grep stops at the first volume key DOWN
# event. Touch events are ignored. Sets KEY to UP, DOWN, TIMEOUT or NOKEY.
# ---------------------------------------------------------------------------
GE=/system/bin/getevent
[ -x "$GE" ] || GE="$(command -v getevent 2>/dev/null)"

read_key() {
  KEY=NOKEY
  [ -n "$GE" ] || return
  command -v timeout >/dev/null 2>&1 || return

  _PATTERN="KEY_VOLUMEUP.*DOWN|KEY_VOLUMEDOWN.*DOWN"
  _END=$(( $(date +%s) + $1 ))
  while [ "$(date +%s)" -lt "$_END" ]; do
    _LINE=$(timeout -s 2 1 "$GE" -lq 2>/dev/null | grep -m 1 -E "$_PATTERN")
    case "$_LINE" in
      *KEY_VOLUMEUP*DOWN*)   sleep 0.2; KEY=UP;   return ;;
      *KEY_VOLUMEDOWN*DOWN*) sleep 0.2; KEY=DOWN; return ;;
    esac
  done
  KEY=TIMEOUT
}

# ---------------------------------------------------------------------------
# Menu
# ---------------------------------------------------------------------------
opt_name() {
  case "$1" in
    0) echo "Status" ;;
    1) echo "Last log lines" ;;
    2) echo "Re-apply everything" ;;
    3) echo "Exit" ;;
  esac
}

print_items() {
  [ "$TTY" = "1" ] && printf '\r\033[2K'
  echo "Vol DOWN = move   |   Vol UP = select"
  for _I in 0 1 2 3; do
    [ "$TTY" = "1" ] && printf '\r\033[2K'
    if [ "$_I" = "$SEL" ]; then echo "  > $(opt_name $_I)"; else echo "    $(opt_name $_I)"; fi
  done
}

draw_menu() {
  echo ""
  print_items
}

# Real terminal: the arrow moves in place. Magisk app output view cannot move the
# cursor, so there only the newly highlighted entry is printed (one line).
move_arrow() {
  if [ "$TTY" = "1" ]; then
    printf '\033[5A'
    print_items
  else
    echo "  > $(opt_name "$SEL")"
  fi
}

run_option() {
  echo ""
  case "$1" in
    0) nf_print_status ;;
    1) nf_show_log 15 ;;
    2) echo "Re-applying keybox, security patch, local ADB and description..."
       nf_apply_all
       nf_notify_changes
       echo "Done."
       nf_print_status ;;
  esac
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
SEL=0
USED=0
KEY=NOKEY

lock_volume
draw_menu
while true; do
  read_key 30
  case "$KEY" in
    DOWN) SEL=$(( (SEL + 1) % 4 ))
          move_arrow ;;
    UP)   [ "$SEL" = "3" ] && break
          run_option "$SEL"
          USED=1
          draw_menu ;;
    *)    if [ "$USED" = "0" ]; then
            echo ""
            echo "(no key press detected - showing status)"
            run_option 0
          fi
          break ;;
  esac
done

cleanup
echo ""
echo "Tip: from Termux just type  nf help"
