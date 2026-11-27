#!/bin/sh
# build.sh - build the flashable module zip and refresh update.json.
# Run from the repository on a PC, WSL or Termux (needs: zip).
#   ./build.sh          -> dist/NestroForge-<version>.zip
set -e
cd "$(dirname "$0")"

REPO="SenestroDev/NestroForge"
BRANCH="main"

get() { grep -m1 "^$1=" module.prop | cut -d= -f2- | tr -d '\r'; }
ID="$(get id)"; VER="$(get version)"; CODE="$(get versionCode)"

fail() { echo "build: $*" >&2; exit 1; }
[ -n "$ID" ] && [ -n "$VER" ] || fail "module.prop needs id and version"
case "$CODE" in ''|*[!0-9]*) fail "versionCode must be a number (got '$CODE')" ;; esac
case "$VER" in v[0-9]*) ;; *) fail "version should look like v1.2.3 (got '$VER')" ;; esac
command -v zip >/dev/null 2>&1 || fail "zip is not installed"

for f in module.prop customize.sh common.sh service.sh post-fs-data.sh uninstall.sh action.sh \
         keybox.sh patch.sh nf.sh adb-local.sh doctor.sh update-description.sh system/bin/nf \
         META-INF/com/google/android/update-binary META-INF/com/google/android/updater-script; do
  [ -f "$f" ] || fail "missing file: $f"
done

for f in *.sh system/bin/nf; do
  sh -n "$f" || fail "syntax error in $f"
done

grep -q "^## \[${VER#v}\]" CHANGELOG.md 2>/dev/null || echo "build: warning - CHANGELOG.md has no [${VER#v}] section"

mkdir -p dist
OUT="dist/$ID-$VER.zip"
rm -f "$OUT"
zip -r9 -X "$OUT" . -x 'dist/*' 'build.sh' 'update.json' '.git/*' '.gitignore' '.github/*' '*.zip' 'module.prop.bak' >/dev/null

cat > update.json <<JSON
{
  "version": "$VER",
  "versionCode": $CODE,
  "zipUrl": "https://github.com/$REPO/releases/download/$VER/$ID-$VER.zip",
  "changelog": "https://raw.githubusercontent.com/$REPO/$BRANCH/CHANGELOG.md"
}
JSON

echo "built $OUT ($(wc -c < "$OUT") bytes), update.json refreshed"
