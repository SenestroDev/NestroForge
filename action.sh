#!/system/bin/sh
# action.sh - runs when the user taps the Action button in the Magisk app (Magisk 27+)
#
# Small menu driven with the volume keys:
#   Volume UP   = move to the next entry
#   Volume DOWN = run the highlighted entry
# Entries: Status / Last log lines / Re-apply everything / Exit
# If the keys cannot be read (or nothing is pressed for 30 s at the start), the
# status is simply printed once.

MODDIR="${0%/*}"
. "$MODDIR/common.sh"

# read_key <seconds> - prints UP, DOWN, TIMEOUT or NOKEY
# Uses the chooseport method (chainfire / ianmacd): getevent runs for 1 second per
# round, grep stops at the first volume key DOWN event. Touch events are ignored.
read_key() {
  _GE=/system/bin/getevent
  [ -x "$_GE" ] || _GE="$(command -v getevent 2>/dev/null)"
  [ -n "$_GE" ] || { echo NOKEY; return; }
  command -v timeout >/dev/null 2>&1 || { echo NOKEY; return; }

  _PATTERN="KEY_VOLUMEUP.*DOWN|KEY_VOLUMEDOWN.*DOWN"
  _NOW=$(date +%s)
  _END=$((_NOW + $1))
  while [ "$_NOW" -lt "$_END" ]; do
    _LINE=$(timeout -s 2 1 "$_GE" -lq 2>/dev/null | grep -m 1 -E "$_PATTERN")
    case "$_LINE" in
      *KEY_VOLUMEUP*DOWN*)   sleep 0.2; echo UP;   return ;;
      *KEY_VOLUMEDOWN*DOWN*) sleep 0.2; echo DOWN; return ;;
    esac
    _NOW=$(date +%s)
  done
  echo TIMEOUT
}

opt_name() {
  case "$1" in
    0) echo "Status" ;;
    1) echo "Last log lines" ;;
    2) echo "Re-apply everything" ;;
    3) echo "Exit" ;;
  esac
}

draw_menu() {
  echo ""
  echo "Vol UP = next   |   Vol DOWN = select"
  for _I in 0 1 2 3; do
    if [ "$_I" = "$SEL" ]; then echo "  > $(opt_name $_I)"; else echo "    $(opt_name $_I)"; fi
  done
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

SEL=0
USED=0
while true; do
  draw_menu
  KEY="$(read_key 30)"
  case "$KEY" in
    UP)   SEL=$(( (SEL + 1) % 4 )) ;;
    DOWN) [ "$SEL" = "3" ] && break
          run_option "$SEL"
          USED=1 ;;
    NOKEY|TIMEOUT)
          if [ "$USED" = "0" ]; then
            echo ""
            echo "(no key press detected - showing status)"
            run_option 0
          fi
          break ;;
  esac
done
echo ""
echo "Tip: from Termux use  su -c \"nf help\""
