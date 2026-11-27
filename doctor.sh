#!/system/bin/sh
# doctor.sh - `nf doctor` / Action menu: check the whole setup and suggest fixes.
# SOURCED after common.sh (never executed, never calls exit).
# Returns 1 if anything FAILED (warnings alone return 0).

DOC_FAIL=0
DOC_WARN=0
doc_hdr()  { echo ""; echo "$1"; }
doc_ok()   { echo "  [ ok ] $1"; }
doc_info() { echo "  [info] $1"; }
doc_warn() { echo "  [WARN] $1"; DOC_WARN=$((DOC_WARN + 1)); }
doc_fail() { echo "  [FAIL] $1"; DOC_FAIL=$((DOC_FAIL + 1)); }

nf_root_manager() {
  if command -v magisk >/dev/null 2>&1; then
    echo "Magisk $(magisk -v 2>/dev/null | head -n 1)"
  elif [ -d /data/adb/ksu ]; then
    echo "KernelSU"
  elif [ -d /data/adb/ap ]; then
    echo "APatch"
  else
    echo "unknown"
  fi
}

# doc_keybox_cert <file> - expiry of the first (leaf) certificate, if openssl exists
doc_keybox_cert() {
  command -v openssl >/dev/null 2>&1 || { doc_info "certificate expiry not checked (openssl is not available here)"; return; }
  _CF="$DATA_DIR/.doctor_cert.$$"
  sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/.*-----BEGIN CERTIFICATE-----/-----BEGIN CERTIFICATE-----/;s/-----END CERTIFICATE-----.*/-----END CERTIFICATE-----/' "$1" \
    | awk '/-----BEGIN CERTIFICATE-----/{f=1} f{print} /-----END CERTIFICATE-----/{if(f) exit}' > "$_CF"
  if [ ! -s "$_CF" ]; then
    doc_warn "no PEM certificate found inside the keybox"
  else
    _END="$(openssl x509 -in "$_CF" -noout -enddate 2>/dev/null | cut -d= -f2)"
    if [ -z "$_END" ]; then
      doc_warn "the first certificate in the keybox could not be read"
    elif ! openssl x509 -in "$_CF" -noout -checkend 0 >/dev/null 2>&1; then
      doc_fail "keybox certificate EXPIRED ($_END) - use a newer keybox"
    elif ! openssl x509 -in "$_CF" -noout -checkend 2592000 >/dev/null 2>&1; then
      doc_warn "keybox certificate expires within 30 days ($_END)"
    else
      doc_ok "keybox certificate valid until $_END"
    fi
  fi
  rm -f "$_CF"
}

nf_doctor() {
  DOC_FAIL=0; DOC_WARN=0
  . "$MODDIR/adb-local.sh"
  echo "NestroForge doctor - $(grep -m1 '^version=' "$MODDIR/module.prop" 2>/dev/null | cut -d= -f2-)"

  doc_hdr "System"
  doc_info "root manager: $(nf_root_manager)"
  _SE="$(getenforce 2>/dev/null)"
  case "$_SE" in
    Enforcing) doc_ok "SELinux enforcing" ;;
    Permissive) doc_warn "SELinux is permissive" ;;
    *) doc_info "SELinux state unknown" ;;
  esac
  if [ -f "$MODDIR/disable" ] || [ -f "$MODDIR/remove" ]; then
    doc_fail "this module is disabled or pending removal ($MODDIR/disable|remove)"
  else
    doc_ok "module enabled"
  fi

  doc_hdr "Config"
  _P="$(nf_config_problems)"
  if [ $? -eq 0 ]; then
    doc_ok "config.sh is valid"
  else
    echo "$_P" | while IFS= read -r _LN; do doc_fail "$_LN"; done
    # the pipe runs in a subshell, so count again here
    DOC_FAIL=$((DOC_FAIL + $(echo "$_P" | wc -l)))
    echo "         fix with: nf config set KEY VALUE"
  fi

  doc_hdr "Tricky Store"
  case "$(nf_ts_state)" in
    ok) doc_ok "installed and enabled" ;;
    disabled) doc_fail "Tricky Store is disabled - enable it in your root manager and reboot" ;;
    *) doc_fail "Tricky Store is not installed" ;;
  esac
  _TF="$TS_TARGET_DIR/target.txt"
  if [ -f "$_TF" ] && [ "$(grep -cvE '^[[:space:]]*(#|$)' "$_TF")" -gt 0 ]; then
    doc_ok "target.txt has $(grep -cvE '^[[:space:]]*(#|$)' "$_TF") app(s)"
  else
    doc_warn "target.txt is empty or missing - add apps with: nf target add PACKAGE"
  fi

  doc_hdr "Keybox"
  if [ "$ENABLE_KEYBOX" != "1" ]; then
    doc_info "keybox management is off (ENABLE_KEYBOX=0)"
  else
    _KS="$(nf_status_of keybox unknown)"
    case "$_KS" in
      ok) doc_ok "status: ok" ;;
      nosource) doc_fail "no keybox found - put yours at $DATA_DIR/keybox.xml" ;;
      invalid) doc_fail "the keybox file is truncated or not a keybox" ;;
      foreign) doc_warn "an existing Tricky Store keybox was kept (not written by this module)" ;;
      *) doc_fail "status: $_KS (see: nf log)" ;;
    esac
    _DST="$TS_TARGET_DIR/keybox.xml"
    if [ -f "$_DST" ]; then
      if grep -q '<Keybox' "$_DST" && grep -q '</AndroidAttestation>' "$_DST"; then
        doc_ok "keybox in Tricky Store looks well-formed"
      else
        doc_fail "keybox in Tricky Store is not well-formed"
      fi
      _ST="$(stat -c '%a %u' "$_DST" 2>/dev/null)"
      [ "$_ST" = "600 0" ] && doc_ok "keybox permissions 600, owner root" || doc_warn "keybox permissions are '$_ST' (expected '600 0')"
      doc_keybox_cert "$_DST"
    else
      doc_fail "no keybox in $TS_TARGET_DIR yet (try: nf apply)"
    fi
  fi

  doc_hdr "Security patch"
  case "$(nf_status_of patch off)" in
    off) doc_info "spoofing is off" ;;
    invalid|error) doc_fail "patch status is bad (nf log)" ;;
    *) doc_ok "spoofing $(nf_status_of patch off)" ;;
  esac

  doc_hdr "Local ADB"
  _AS="$(nf_status_of adb off)"
  case "$_AS" in
    off) doc_info "off" ;;
    blocked) doc_fail "blocked: the firewall rule could not be applied (nf log)" ;;
    external*) doc_warn "ADB over TCP was enabled by something else ($_AS) - not firewalled by this module" ;;
    loopback:*)
      _PORT="${_AS#loopback:}"
      if adb_fw_present "$_PORT"; then doc_ok "firewall rule present for port $_PORT"; else doc_fail "firewall rule for port $_PORT is MISSING - run: nf apply"; fi
      [ "$(getprop init.svc.adbd)" = "running" ] && doc_ok "adbd running" || doc_info "adbd is not running (USB debugging off?)"
      adb_port_listening "$_PORT" && doc_ok "listening on port $_PORT" || doc_info "nothing listening on port $_PORT yet"
      _WP="$(cat "$ADB_WD_PID_FILE" 2>/dev/null)"
      if [ "$ADB_WATCHDOG" != "1" ]; then doc_info "watchdog off (ADB_WATCHDOG=0)"
      elif [ -n "$_WP" ] && kill -0 "$_WP" 2>/dev/null; then doc_ok "watchdog running"
      else doc_warn "watchdog not running - run: nf apply"; fi
      ;;
  esac

  doc_hdr "Termux"
  case "$(nf_termux_state)" in
    linked) doc_ok "nf command is in Termux" ;;
    absent) doc_info "Termux not installed" ;;
    not-initialised) doc_warn "Termux was never opened - open it once, then: nf termux link" ;;
    foreign) doc_warn "Termux has a different nf command (left alone)" ;;
    unlinked) [ "$ENABLE_TERMUX_LINK" = "1" ] && doc_warn "launcher missing - run: nf termux link" || doc_info "Termux command is off" ;;
  esac

  doc_hdr "Boot guard"
  if [ "$BOOTLOOP_PROTECTION" != "1" ]; then
    doc_info "off"
  elif [ -f "$TRIP_FILE" ]; then
    doc_fail "TRIPPED - run: nf bootloop reset"
  else
    _BC="$(cat "$BOOT_COUNT_FILE" 2>/dev/null || echo 0)"
    [ "$_BC" -gt 0 ] 2>/dev/null && doc_warn "$_BC unfinished boot(s) counted (limit $BOOTLOOP_MAX)" || doc_ok "no unfinished boots"
  fi

  echo ""
  if [ "$DOC_FAIL" -gt 0 ]; then
    echo "Result: $DOC_FAIL problem(s), $DOC_WARN warning(s)"
    return 1
  fi
  echo "Result: no problems, $DOC_WARN warning(s)"
  return 0
}
