#!/system/bin/sh
# update-description.sh - change the description= line in this module's module.prop
#
# Usage: update-description.sh [-backup] [-append | -prepend] -desc "new description"
#
#   -backup   Copy module.prop to module.prop.bak first, but only if no backup exists
#             yet, so the backup always keeps the ORIGINAL module.prop
#   -append   Put the new description AFTER the old one (instead of replacing it)
#   -prepend  Put the new description BEFORE the old one (instead of replacing it)
#   -desc     The new description (required, takes a value)
#
# Without -append or -prepend the new description replaces the old one.
# If both -append and -prepend are given, the one given last wins.
# If -desc is missing (or empty), nothing is changed, not even the backup.
#
# If module.prop.bak exists, its description is used as the "old" description, so running
# this script again does not stack new text on top of text it added earlier.

# Folder this script lives in. Works with a full path, ./update-description.sh, or
# 'sh update-description.sh' after cd (where $0 has no slash).
case "$0" in
  */*) MODDIR="${0%/*}" ;;
  *)   MODDIR="." ;;
esac

PROP="$MODDIR/module.prop"
BAK="$MODDIR/module.prop.bak"

# ── Parse arguments ──────────────────────────────────────────────────────────
BACKUP=0
MODE=replace
DESC=

while [ $# -gt 0 ]; do
  case "$1" in
    -backup)  BACKUP=1 ;;
    -append)  MODE=append ;;
    -prepend) MODE=prepend ;;
    -desc)
      shift
      # -desc was the last argument with no value after it
      [ $# -gt 0 ] || break
      DESC="$1"
      ;;
    *) ;; # ignore anything we don't know
  esac
  shift
done

# No -desc (or an empty one): do nothing
[ -n "$DESC" ] || exit 0

if [ ! -f "$PROP" ]; then
  echo "update-description.sh: $PROP not found" >&2
  exit 1
fi

# module.prop values must be a single line, so turn any CR/LF in the new text into spaces
DESC="$(printf '%s' "$DESC" | tr '\r\n' '  ')"

# ── Backup the original module.prop (only once, never overwrite) ─────────────
if [ "$BACKUP" -eq 1 ] && [ ! -f "$BAK" ]; then
  cp -f "$PROP" "$BAK"
fi

# ── Work out the old description ─────────────────────────────────────────────
# Prefer the backup (the original), otherwise use the current module.prop
SRC="$PROP"
[ -f "$BAK" ] && SRC="$BAK"
OLD_DESC="$(grep -m1 "^description=" "$SRC" | cut -d= -f2- | tr -d '\r')"

# ── Build the new description ────────────────────────────────────────────────
if [ -z "$OLD_DESC" ]; then
  # Nothing to append to or prepend to
  NEW_DESC="$DESC"
else
  case "$MODE" in
    append)  NEW_DESC="$OLD_DESC $DESC" ;;
    prepend) NEW_DESC="$DESC $OLD_DESC" ;;
    *)       NEW_DESC="$DESC" ;;
  esac
fi

# Escape characters that mean something in the sed replacement text (& / \)
NEW_DESC_FIX="$(printf '%s' "$NEW_DESC" | sed 's/[&/\]/\\&/g')"

# ── Write it into module.prop ────────────────────────────────────────────────
if grep -q "^description=" "$PROP"; then
  sed -i "s/^description=.*/description=$NEW_DESC_FIX/" "$PROP"
else
  # No description= line yet: add one (first make sure the file ends with a newline)
  [ -n "$(tail -c1 "$PROP")" ] && echo >> "$PROP"
  echo "description=$NEW_DESC" >> "$PROP"
fi