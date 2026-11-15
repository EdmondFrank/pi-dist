#!/usr/bin/env bash
# Package a built binary + assets + config into a shippable release tarball.
#   ./package.sh 1.5.0 linux-x64
#   ./package.sh 1.5.0 linux-x64-baseline
set -euo pipefail

VERSION="${1:-1.5.0}"
SLUG="${2:-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m | sed 's/x86_64/x64/;s/aarch64/arm64/')}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAGE="$HERE/release/pi-$VERSION-$SLUG"
BIN="$HERE/out/pi-$SLUG"
[ -f "$BIN" ] || { echo "error: missing $BIN (run ./build.sh)" >&2; exit 1; }

rm -rf "$STAGE" && mkdir -p "$STAGE"
cp "$BIN" "$STAGE/"
cp "$HERE/out/package.json" "$HERE/out/photon_rs_bg.wasm" "$STAGE/"
cp -R "$HERE/out/theme" "$HERE/out/assets" "$HERE/out/export-html" "$STAGE/"
cp "$HERE/install.sh" "$HERE/README.md" "$HERE/GUIDELINE.md" "$STAGE/"
[ -f "$HERE/TERMUX.md" ] && cp "$HERE/TERMUX.md" "$STAGE/" || true
cp -R "$HERE/config" "$STAGE/"

# Browser dashboard (optional; build it with ./build-web.sh).
# Skipped on android-*: pi-web is bun-packaged and Termux has no bun.
WITH_WEB=1
case "$SLUG" in android-*) WITH_WEB=0 ;; esac
if [ "$WITH_WEB" = 0 ]; then
  echo "note: pi-web skipped (Termux has no bun)"
elif [ -d "$HERE/out/pi-web" ]; then
  cp -R "$HERE/out/pi-web" "$STAGE/pi-web"
else
  echo "note: out/pi-web missing — run ./build-web.sh to include the dashboard"
fi

TGZ="$HERE/release/pi-$VERSION-$SLUG.tar.gz"
COPYFILE_DISABLE=1 tar --no-xattrs -czf "$TGZ" -C "$HERE/release" "pi-$VERSION-$SLUG" 2>/dev/null \
  || COPYFILE_DISABLE=1 tar czf "$TGZ" -C "$HERE/release" "pi-$VERSION-$SLUG"
( cd "$HERE/release" && shasum -a 256 "$(basename "$TGZ")" > "$(basename "$TGZ").sha256" )

echo "release: $TGZ ($(du -h "$TGZ" | cut -f1))"
cat "$TGZ.sha256"