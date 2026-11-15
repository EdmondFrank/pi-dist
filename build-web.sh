#!/usr/bin/env bash
# Fetch the published pi-web package and stage it for pi-dist (out/pi-web).
#
# pi-web is the browser UI for pi (https://github.com/agegr/pi-web). The npm
# tarball already ships a pruned, prebuilt .next, so nothing is compiled here —
# we only add the two Bun adaptations and a production node_modules:
#
#   1. next.config.mjs  — Next loads next.config.ts through require.extensions,
#                         which Bun does not implement. Generated from the .ts.
#   2. bun-preload.cjs  — polyfills module.findPackageJSON (absent in Bun), which
#                         pi's server chunks need to locate its own packages.
#                         Without it MCP is disabled and llama.cpp fails to load.
#
# Usage: ./build-web.sh [version]
#   ./build-web.sh            # pinned default
#   ./build-web.sh 0.17.0
#   PI_WEB_REGISTRY=https://registry.npmmirror.com ./build-web.sh
set -euo pipefail

WEB_VERSION="${1:-${PI_WEB_VERSION:-0.17.0}}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
WORK="$ROOT/src-web"
STAGE="$ROOT/out/pi-web"
PKG="@agegr/pi-web"
REGISTRY="${PI_WEB_REGISTRY:-https://registry.npmjs.org}"

die() { echo "error: $*" >&2; exit 1; }
say() { echo "== $*"; }

command -v bun >/dev/null || die "bun not found (needed to run and install pi-web; https://bun.sh)"

export https_proxy="${https_proxy:-http://127.0.0.1:7890}"
export http_proxy="${http_proxy:-$https_proxy}"
export PATH="$HOME/.bun/bin:$PATH"
export BUN_CONFIG_REGISTRY="$REGISTRY"

say "pi-web $WEB_VERSION -> $STAGE"
rm -rf "$WORK" && mkdir -p "$WORK"
cd "$WORK"

# 1. published tarball (prebuilt .next, pruned — no cache, no sourcemaps)
npm pack "$PKG@$WEB_VERSION" --registry "$REGISTRY" >/dev/null \
  || die "npm pack failed (network/proxy?)"
TGZ="$(ls -t ./*pi-web-"$WEB_VERSION".tgz | head -1)"
mkdir pkg && tar xzf "$TGZ" -C pkg --strip-components=1

# 2. runtime dependencies only (next, react, pi SDKs, node-pty, ...)
#
# Resolution without a lockfile is extremely slow, so a lockfile for the pinned
# version is vendored in locks/. Regenerate it from the release tag with:
#   curl -sL -o locks/pi-web-$V/package-lock.json \
#     https://raw.githubusercontent.com/agegr/pi-web/v$V/package-lock.json
LOCK="$ROOT/locks/pi-web-$WEB_VERSION/package-lock.json"
if [ -f "$LOCK" ]; then
  cp "$LOCK" pkg/package-lock.json
  echo "== using vendored lockfile"
else
  echo "warning: no locks/pi-web-$WEB_VERSION/package-lock.json — dependency resolution will be slow" >&2
fi
# Bun blocks lifecycle scripts by default; node-pty's install step is needed.
cat > pkg/bunfig.toml <<'EOF'
[install]
trustedDependencies = ["node-pty"]
EOF
say "installing production dependencies (this takes a while)"
(cd pkg && bun install --production --no-frozen-lockfile)

# 3. Bun adaptations
bun "$ROOT/scripts/gen-next-config-mjs.mjs" pkg >/dev/null
rm -f pkg/next.config.ts          # .mjs wins the lookup anyway; keep it unambiguous
mkdir -p pkg/scripts
cp "$ROOT/scripts/bun-preload.cjs" pkg/scripts/

# 3b. prune what `next start` never reads. Each entry is justified:
#   @next/swc-*            compile-time only, and the linux-x64 native build
#                          needs glibc >= 2.29 (this package targets 2.27 too)
#   **/*.map               server sourcemaps
#   next/dist/docs         bundled documentation
#   caniuse-lite           browserslist data, build-time only
#   @img/sharp-libvips-*   next/image optimizer, disabled in next.config.ts
# (next/dist/build stays: bin/next requires ../build/output/log.)
say "pruning"
rm -rf pkg/node_modules/@next/swc-* \
       pkg/node_modules/next/dist/docs \
       pkg/node_modules/caniuse-lite
rm -rf pkg/node_modules/@img/sharp-libvips-* 2>/dev/null || true
find pkg/node_modules -name '*.map' -type f -delete 2>/dev/null || true

# 3c. node-pty: the shipped linux-x64 prebuild needs glibc >= 2.28, so it does
# not load on glibc 2.27 (Ubuntu 18.04) and the terminal panel breaks. Build it
# from source when that happens; the result only needs glibc 2.4/2.8.
say "node-pty"
if (cd pkg && bun -e 'require("node-pty")' >/dev/null 2>&1); then
  echo "   prebuilt module loads"
else
  echo "   prebuilt module does not load here — building from source"
  ( cd pkg/node_modules/node-pty \
    && BUN_CONFIG_REGISTRY="$REGISTRY" bun x node-gyp@10 rebuild ) \
    || echo "   warning: node-pty build failed; the terminal panel will be unavailable"
fi
cat > pkg/PI-DIST-WEB.md <<'EOF'
Vendored @agegr/pi-web, repacked by pi-dist's build-web.sh.

Differences from the npm tarball:
  next.config.mjs     generated from next.config.ts (Bun cannot load a TS config)
  scripts/bun-preload.cjs  polyfills module.findPackageJSON (bin/pi-web.js path)
  .next/server chunks findPackageJSON call sites rewritten for Bun
  node_modules/       production dependencies only (pruned; node-pty built if needed)

Run with:  pi-web   (shim in ~/.local/bin)
EOF

# 4. stage
rm -rf "$STAGE" && mkdir -p "$STAGE"
cp -R pkg/. "$STAGE"/

# 4b. Make pi's module.findPackageJSON() calls work under Bun. This rewrites the
# server chunks instead of relying on --preload: pi-web's CLI runs the Next
# server as a child process, which would not inherit the preload flag.
bun "$ROOT/scripts/patch-find-package-json.mjs" "$STAGE"
say "staged $(du -sh "$STAGE" | cut -f1) in $STAGE"

# 5. smoke test: serve on a free port, then check the session list and the patch
FAILED=0
PORT="$(bun -e 'const s=require("node:net").createServer();s.listen(0,"127.0.0.1",()=>{console.log(s.address().port);s.close()})')"
export no_proxy="127.0.0.1,localhost,::1" NO_PROXY="127.0.0.1,localhost,::1"
( cd "$STAGE" && bun --preload ./scripts/bun-preload.cjs bin/pi-web.js --port "$PORT" --no-open \
    > "$WORK/smoke.log" 2>&1 & echo $! > "$WORK/smoke.pid" )
for _ in $(seq 1 60); do
  if curl -fsS --max-time 1 "http://127.0.0.1:$PORT/api/sessions" >/dev/null 2>&1; then break; fi
  sleep 0.5
done
if curl -fsS --max-time 5 "http://127.0.0.1:$PORT/api/sessions" >/dev/null 2>&1; then
  echo "== smoke test ok (http://127.0.0.1:$PORT/api/sessions)"
else
  echo "== smoke test FAILED" >&2
  tail -20 "$WORK/smoke.log" >&2
  FAILED=1
fi
# Without the patch pi-web logs "MCP is off" and the llama.cpp provider fails;
# check the rewrite itself rather than waiting for a session to trigger it.
if grep -rqs "__piDistFindPackageJSON" "$STAGE/.next/server"; then
  echo "== findPackageJSON patch ok"
else
  echo "== warning: findPackageJSON patch did not take effect (MCP disabled)" >&2
  FAILED=1
fi
kill "$(cat "$WORK/smoke.pid")" 2>/dev/null || true
pkill -f "next start -p $PORT" 2>/dev/null || true

echo "done: $STAGE ($(du -sh "$STAGE" | cut -f1))"
[ "$FAILED" = 0 ] || { echo "error: smoke test failed" >&2; exit 1; }