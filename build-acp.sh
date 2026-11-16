#!/usr/bin/env bash
# Build a self-contained pi-acp binary (the ACP adapter for pi) from the npm
# release, so ACP clients (Emacs agent-shell, Zed, ...) can drive this dist's pi
# without Node.js on the target.
#
# pi-acp speaks ACP JSON-RPC 2.0 over stdio and spawns `pi --mode rpc`, bridging
# requests and session updates. It is a plain ESM package with three pure-JS
# dependencies (@agentclientprotocol/sdk, cross-spawn, zod), so bun bundles it
# into one executable exactly like build.sh does for pi.
#
# Usage: ./build-acp.sh [version] [bun-target]
#   ./build-acp.sh                     # pinned default, host target
#   ./build-acp.sh 0.0.34 bun-linux-x64
set -euo pipefail

VERSION="${1:-${PI_ACP_VERSION:-0.0.34}}"
TARGET="${2:-bun-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m | sed 's/x86_64/x64/;s/aarch64/arm64/')}"
PKG="pi-acp"
ROOT="$(cd "$(dirname "$0")" && pwd)"
WORK="$ROOT/src-acp"
OUT="$ROOT/out"
SLUG="${TARGET#bun-}"
REGISTRY="${PI_ACP_REGISTRY:-https://registry.npmjs.org}"

die() { echo "error: $*" >&2; exit 1; }
say() { echo "== $*"; }

command -v bun >/dev/null || die "bun not found (needed to bundle pi-acp; https://bun.sh)"
export https_proxy="${https_proxy:-http://127.0.0.1:7890}"
export http_proxy="${http_proxy:-$https_proxy}"
export PATH="$HOME/.bun/bin:$PATH"
export BUN_CONFIG_REGISTRY="$REGISTRY"

say "pi-acp $VERSION -> $OUT/pi-acp-$SLUG"
rm -rf "$WORK" && mkdir -p "$WORK"
cd "$WORK"

# 1. published tarball (dist/index.js is already built by the upstream prepack)
npm pack "$PKG@$VERSION" --registry "$REGISTRY" >/dev/null \
  || die "npm pack failed (network/proxy?)"
TGZ="$(ls -t ./pi-acp-"$VERSION".tgz | head -1)"
mkdir pkg && tar xzf "$TGZ" -C pkg --strip-components=1

# 2. runtime dependencies. The npm tarball ships no lockfile and resolving three
# semver ranges is slow and not reproducible, so a lockfile for the pinned
# version is vendored in locks/. Regenerate it from the release tag with:
#   curl -sL -o locks/pi-acp-$V/package-lock.json \
#     https://raw.githubusercontent.com/svkozak/pi-acp/v$V/package-lock.json
LOCK="$ROOT/locks/pi-acp-$VERSION/package-lock.json"
if [ -f "$LOCK" ]; then
  cp "$LOCK" pkg/package-lock.json
  echo "== using vendored lockfile"
else
  echo "warning: no locks/pi-acp-$VERSION/package-lock.json — dependency resolution will be slow" >&2
fi
say "installing production dependencies"
(cd pkg && bun install --production --no-frozen-lockfile)

# 3. compile. Unlike pi there are no assets next to the executable and no
# runtime-discovered entrypoints, so nothing else has to travel with it.
say "compiling"
mkdir -p "$OUT"
(cd pkg && bun build --compile ./dist/index.js \
  --outfile "$OUT/pi-acp-$SLUG" --target "$TARGET")

# 4. smoke test (host target only; cross-built binaries cannot run here).
# ACP handshake only by default. PI_ACP_SMOKE_PROMPT=1 also sends one prompt,
# which costs tokens and needs a reachable model provider.
HOST_SLUG="$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m | sed 's/x86_64/x64/;s/aarch64/arm64/')"
if [ "$SLUG" = "$HOST_SLUG" ]; then
  if command -v python3 >/dev/null; then
    PROMPT_FLAG=""
    [ "${PI_ACP_SMOKE_PROMPT:-0}" = 1 ] && PROMPT_FLAG="--prompt"
    python3 "$ROOT/scripts/acp-smoke.py" --command "$OUT/pi-acp-$SLUG" \
      --pi "$ROOT/out/pi-$SLUG" --cwd "${TMPDIR:-/tmp}" $PROMPT_FLAG \
      || die "ACP smoke test failed"
  else
    echo "note: python3 not found — skipping ACP smoke test"
  fi
else
  echo "cross-built for $SLUG — skipped smoke test (verify on the target)"
fi

echo "done: $OUT/pi-acp-$SLUG ($(du -h "$OUT/pi-acp-$SLUG" | cut -f1))"