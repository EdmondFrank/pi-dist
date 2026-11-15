#!/usr/bin/env bash
# Build a self-contained pi binary (no Node runtime) from the npm release.
# Usage: ./build.sh [version] [bun-target]
#   ./build.sh 1.5.0 bun-darwin-arm64
#   ./build.sh 1.5.0 bun-linux-x64
set -euo pipefail

VERSION="${1:-1.5.0}"
TARGET="${2:-bun-darwin-arm64}"
PKG="@earendil-works/pi-coding-agent"
ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/src"
OUT="$ROOT/out"
SLUG="${TARGET#bun-}"

export https_proxy="${https_proxy:-http://127.0.0.1:7890}"
export http_proxy="${http_proxy:-$https_proxy}"

echo "== pi $VERSION -> $OUT/pi-$SLUG"

# 1. fetch release tarball (prebuilt dist, incl. dist/bun/cli.js)
rm -rf "$SRC" && mkdir -p "$SRC"
(cd "$ROOT" && npm pack "$PKG@$VERSION" >/dev/null)
TGZ="$(ls -t "$ROOT"/*pi-coding-agent-"$VERSION".tgz | head -1)"
tar xf "$TGZ" -C "$SRC" --strip-components=1

# 2. runtime deps (only needed to bundle: SDKs, jiti, photon wasm)
(cd "$SRC" && bun install --production)

# 3. codemode worker.
# In a bun binary the runtime resolves the worker as the *source* path
# "./src/extensions/codemode/worker.ts" (dist/config.js resolveCodemodeWorkerSpecifier),
# so that path must exist in the tree and be passed as an extra entrypoint.
# Without it every codemode/MCP tool call fails with ModuleNotFound.
mkdir -p "$SRC/src/extensions/codemode"
cp "$SRC/dist/bundle/chunks/codemode-worker.js" "$SRC/src/extensions/codemode/worker.ts"

# 4. compile: bun embeds its runtime + both entrypoints
mkdir -p "$OUT"
(cd "$SRC" && bun build --compile ./dist/bun/cli.js ./src/extensions/codemode/worker.ts \
  --outfile "$OUT/pi-$SLUG" --target "$TARGET")

# 5. assets that must sit next to the executable (resolved from dirname(argv[0]))
cp "$SRC/package.json" "$OUT/package.json"
rm -rf "$OUT/theme" "$OUT/assets" "$OUT/export-html"
cp -R "$SRC/dist/modes/interactive/theme" "$OUT/theme"
mkdir -p "$OUT/assets" && cp "$SRC"/dist/modes/interactive/assets/* "$OUT/assets/" 2>/dev/null || true
cp -R "$SRC/dist/core/export-html" "$OUT/export-html"
cp "$SRC/node_modules/@silvia-odwyer/photon-node/photon_rs_bg.wasm" "$OUT/" 2>/dev/null || true

# 6. smoke test (host target only; cross-built binaries cannot run here)
HOST_SLUG="$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m | sed 's/x86_64/x64/;s/aarch64/arm64/')"
if [ "$SLUG" = "$HOST_SLUG" ]; then
  ( cd "$OUT" && env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin "./pi-$SLUG" --version )
else
  echo "cross-built for $SLUG — skipped smoke test (verify on the target: docker/systemd-nspawn/ssh)"
fi

echo "done: $OUT/pi-$SLUG ($(du -h "$OUT/pi-$SLUG" | cut -f1))"