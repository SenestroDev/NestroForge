#!/system/bin/sh
# patch.sh - security patch spoofing for Tricky Store.
# Run with `sh` by post-fs-data.sh, nf and nf_apply_all.
#
# config.sh: SECURITY_PATCH=2026-11-05 (or auto = device patch level)  ->  /data/adb/tricky_store/security_patch.txt
#            containing the line  all=2026-11-05
# Empty / off removes the file again, but only if THIS module wrote it.
# A security_patch.txt written by someone else is backed up before it is replaced.

MODDIR=${0%/*}
. "$MODDIR/common.sh"

STATUS_FILE="$DATA_DIR/.status_patch"
SUM_FILE="$DATA_DIR/.patch_last_sum"
DST="$TS_TARGET_DIR/security_patch.txt"

set_status() {
  echo "$1" > "$STATUS_FILE"
  nf_log patch "$2"
}

V="$SECURITY_PATCH"

# ── Off: clean up what we wrote ──────────────────────────────────────────────
case "$V" in
  ''|off|0)
    if [ -f "$DST" ] && [ "$(nf_sum "$DST")" = "$(cat "$SUM_FILE" 2>/dev/null)" ]; then
      rm -f "$DST"
      nf_log patch "spoofing turned off, removed $DST"
    fi
    rm -f "$SUM_FILE"
    echo off > "$STATUS_FILE"
    exit 0
    ;;
esac

# ── auto: follow the device's own patch level ────────────────────────────────
if [ "$V" = "auto" ]; then
  V="$(getprop ro.build.version.security_patch)"
  [ -n "$V" ] || { set_status invalid "SECURITY_PATCH=auto but ro.build.version.security_patch is empty"; exit 1; }
fi

# ── Validate YYYY-MM-DD ──────────────────────────────────────────────────────
case "$V" in
  [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
  *) set_status invalid "SECURITY_PATCH='$V' is not YYYY-MM-DD, nothing written"; exit 1 ;;
esac
MM="${V#*-}"; MM="${MM%-*}"
DD="${V##*-}"
case "$MM" in 0[1-9]|1[0-2]) ;; *) set_status invalid "bad month in '$V'"; exit 1 ;; esac
case "$DD" in 0[1-9]|[12][0-9]|3[01]) ;; *) set_status invalid "bad day in '$V'"; exit 1 ;; esac
case "$MM" in 02) _MAXD=29 ;; 04|06|09|11) _MAXD=30 ;; *) _MAXD=31 ;; esac
_D="${DD#0}"
[ "$_D" -le "$_MAXD" ] || { set_status invalid "day $DD does not exist in month $MM ('$V')"; exit 1; }

# ── Write ────────────────────────────────────────────────────────────────────
mkdir -p "$TS_TARGET_DIR"
TMP="$DST.nf.tmp"
echo "all=$V" > "$TMP" || { rm -f "$TMP"; set_status error "cannot write $TMP"; exit 1; }

if [ -f "$DST" ]; then
  if cmp -s "$TMP" "$DST"; then
    rm -f "$TMP"
    nf_sum "$DST" > "$SUM_FILE"
    set_status "$V" "already up to date ($V)"
    exit 0
  fi
  # Different content: ours from an earlier setting, or somebody else's?
  if [ "$(nf_sum "$DST")" != "$(cat "$SUM_FILE" 2>/dev/null)" ]; then
    mkdir -p "$DATA_DIR/backup"
    BK="$DATA_DIR/backup/security_patch.txt.$(date +%Y%m%d-%H%M%S)"
    cp -f "$DST" "$BK" && nf_log patch "backed up existing security_patch.txt to $BK"
  fi
fi

if chmod 0644 "$TMP" && chown 0:0 "$TMP" && mv -f "$TMP" "$DST"; then
  nf_sum "$DST" > "$SUM_FILE"
  set_status "$V" "security patch set to $V"
else
  rm -f "$TMP"
  set_status error "failed to write $DST"
  exit 1
fi
