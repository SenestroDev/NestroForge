#!/system/bin/sh
# keybox.sh - place a keybox.xml into Tricky Store's config folder.
# Run with `sh` (never sourced) by post-fs-data.sh, service.sh and action.sh.
#
# Source priority:
#   1. /data/adb/NestroForge/keybox.xml   (YOUR file - always applied)
#   2. <module>/keybox.xml                (bundled fallback)
#
# Safety rules:
#   - nothing is copied if the file is already identical (no needless reloads)
#   - a keybox in Tricky Store that this module did NOT write is never silently
#     destroyed: it is backed up first, and a bundled keybox will not replace it
#     unless KEYBOX_OVERWRITE_EXISTING=1
#   - the file is written atomically with mode 0600

MODDIR=${0%/*}
. "$MODDIR/common.sh"

STATUS_FILE="$DATA_DIR/.status_keybox"
SUM_FILE="$DATA_DIR/.keybox_last_sum"   # checksum of the last file WE wrote
USER_SRC="$DATA_DIR/keybox.xml"
BUNDLED_SRC="$MODDIR/keybox.xml"
DST="$TS_TARGET_DIR/keybox.xml"

# set_status <state> <log message>
set_status() {
  echo "$1" > "$STATUS_FILE"
  nf_log keybox "$2"
}

if [ "$ENABLE_KEYBOX" != "1" ]; then
  set_status disabled "disabled in config.sh"
  exit 0
fi

# Tricky Store not being there is a warning, not a stop: the file is harmless and
# is picked up as soon as Tricky Store is installed / enabled.
TS_STATE="$(nf_ts_state)"
[ "$TS_STATE" = "ok" ] || nf_log keybox "WARNING: Tricky Store is $TS_STATE ($TS_MODULE_DIR)"

if [ -f "$USER_SRC" ]; then
  SRC="$USER_SRC"; FROM=user
elif [ -f "$BUNDLED_SRC" ]; then
  SRC="$BUNDLED_SRC"; FROM=bundled
else
  set_status nosource "no keybox found - put yours at $USER_SRC"
  exit 0
fi

# Cheap sanity check so a truncated / wrong file is never pushed into Tricky Store
if ! grep -q '<Keybox' "$SRC" 2>/dev/null || ! grep -q '</AndroidAttestation>' "$SRC" 2>/dev/null; then
  set_status invalid "$SRC does not look like a valid keybox.xml, NOT applied"
  exit 1
fi

SRC_SUM="$(nf_sum "$SRC")"
mkdir -p "$TS_TARGET_DIR"

if [ -f "$DST" ]; then
  DST_SUM="$(nf_sum "$DST")"

  if [ "$DST_SUM" = "$SRC_SUM" ]; then
    echo "$SRC_SUM" > "$SUM_FILE"
    set_status ok "keybox already up to date ($FROM)"
    exit 0
  fi

  # The target differs. Is it a file we wrote earlier, or somebody else's?
  LAST_SUM="$(cat "$SUM_FILE" 2>/dev/null)"
  if [ "$DST_SUM" != "$LAST_SUM" ]; then
    if [ "$FROM" = "bundled" ] && [ "$KEYBOX_OVERWRITE_EXISTING" != "1" ]; then
      set_status foreign "existing Tricky Store keybox kept (not written by NestroForge)"
      exit 0
    fi
    mkdir -p "$DATA_DIR/backup"
    BK="$DATA_DIR/backup/keybox.xml.$(date +%Y%m%d-%H%M%S)"
    if cp -f "$DST" "$BK"; then
      chmod 0600 "$BK"
      nf_log keybox "backed up existing keybox to $BK"
    fi
  fi
fi

TMP="$DST.nf.tmp"
if cp -f "$SRC" "$TMP" && chmod 0600 "$TMP" && chown 0:0 "$TMP" && mv -f "$TMP" "$DST"; then
  echo "$SRC_SUM" > "$SUM_FILE"
  set_status ok "keybox placed from $FROM source"
else
  rm -f "$TMP"
  set_status error "failed to write $DST"
  exit 1
fi
