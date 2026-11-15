#!/usr/bin/env bash
# Install a self-contained pi binary + portable config on a new machine.
# No Node.js required: the binary embeds its own runtime.
#
#   ./install.sh                 # install into ~/.local/{bin,lib/pi} + ~/.pi/agent
#   ./install.sh --dry-run       # show what would happen
#   ./install.sh --from dist --prefix /opt/pi --agent-dir /etc/pi
#   ./install.sh --force         # overwrite existing config (backs up to *.bak)
#   ./install.sh --no-mcp        # skip mcp.json (offline / no exhub hub)
#   ./install.sh --no-web        # skip the browser dashboard (pi-web)
#   ./install.sh --platform slug # force a build (android-arm64, linux-x64, …)
#
# Termux/Android is detected automatically: it installs the bionic build
# (pi-android-arm64) into $PREFIX/bin + $PREFIX/lib/pi, and skips pi-web (bun).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FROM="$HERE/out"

# Termux exports PREFIX=/data/data/com.termux/files/usr and TERMUX_VERSION, but its shell
# still reports uname -s Linux / -m aarch64 — with a bionic loader, so the glibc builds
# (linux-arm64) cannot run there. The matching build is android-arm64 (bionic PIE).
TERMUX=0
TERMUX_USR=""
if [ -n "${TERMUX_VERSION:-}" ]; then TERMUX=1; fi
case "${PREFIX:-}" in /data/data/com.termux/*) TERMUX=1; TERMUX_USR="$PREFIX" ;; esac

PREFIX="$HOME/.local"
if [ "$TERMUX" = 1 ]; then
  if [ -z "$TERMUX_USR" ]; then TERMUX_USR="$(cd "$HOME/.." && pwd)/usr"; fi
  PREFIX="$TERMUX_USR"   # == Termux $PREFIX, already on PATH
fi
AGENT_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
FORCE=0
DRY=0
WITH_MCP=1
WITH_WEB=1
if [ "$TERMUX" = 1 ]; then WITH_WEB=0; fi   # pi-web is bun-packaged; no bun on Termux
PLATFORM_OVERRIDE="${PI_PLATFORM:-}"

die() { echo "error: $*" >&2; exit 1; }
say() { echo "== $*"; }
run() { if [ "$DRY" = 1 ]; then echo "   [dry] $*"; else "$@"; fi; }

# Render ${VAR} placeholders in config/*.tmpl. perl is not part of a default Termux
# install, so fall back to sed (| delimiter, since the values are URLs).
render_tmpl() {   # $1 template, $2 output, then the variable names to substitute
  local tpl="$1" out="$2" v val list="" args=()
  shift 2
  if [ -z "${PI_NO_PERL:-}" ] && command -v perl >/dev/null 2>&1; then
    for v in "$@"; do list="${list}s/\\\$\{$v\}/\$ENV{$v}/g; "; done
    perl -pe "$list" "$tpl" > "$out"
  else
    for v in "$@"; do
      val="${!v}"
      val="${val//\\/\\\\}"; val="${val//|/\\|}"; val="${val//&/\\&}"
      args+=(-e "s|\${$v}|$val|g")
    done
    sed "${args[@]}" "$tpl" > "$out"
  fi
}

while [ $# -gt 0 ]; do
  case "$1" in
    --from)      FROM="$2"; shift 2 ;;
    --prefix)    PREFIX="$2"; shift 2 ;;
    --agent-dir) AGENT_DIR="$2"; shift 2 ;;
    --force)     FORCE=1; shift ;;
    --no-mcp)    WITH_MCP=0; shift ;;
    --no-web)    WITH_WEB=0; shift ;;
    --web)       WITH_WEB=1; shift ;;
    --platform)  PLATFORM_OVERRIDE="$2"; shift 2 ;;
    --dry-run)   DRY=1; shift ;;
    -h|--help)   sed -n '2,16p' "$0"; exit 0 ;;
    *)           die "unknown option: $1" ;;
  esac
done

# ---------------------------------------------------------------- platform
if [ -n "$PLATFORM_OVERRIDE" ]; then
  PLATFORM="$PLATFORM_OVERRIDE"
elif [ "$TERMUX" = 1 ]; then
  case "$(uname -m)" in
    aarch64|arm64)            PLATFORM=android-arm64 ;;
    x86_64|amd64)             PLATFORM=android-x64 ;;
    *) die "unsupported Termux architecture: $(uname -m)" ;;
  esac
else
  case "$(uname -s)/$(uname -m)" in
    Darwin/arm64)        PLATFORM=darwin-arm64 ;;
    Darwin/x86_64)       PLATFORM=darwin-x64 ;;
    Linux/x86_64)        PLATFORM=linux-x64 ;;
    Linux/aarch64|Linux/arm64) PLATFORM=linux-arm64 ;;
    *) die "unsupported platform: $(uname -s) $(uname -m) (Termux on Android? use --platform android-arm64)" ;;
  esac
fi

BIN="$FROM/pi-$PLATFORM"
# Release tarballs ship the binary next to install.sh; build trees keep it under out/.
if [ ! -f "$BIN" ] && [ ! -f "$FROM/pi-$PLATFORM-baseline" ] && [ -f "$HERE/pi-$PLATFORM" ]; then
  FROM="$HERE"
  BIN="$FROM/pi-$PLATFORM"
fi
if [ ! -f "$BIN" ] && [ -f "$FROM/pi-$PLATFORM-baseline" ]; then
  BIN="$FROM/pi-$PLATFORM-baseline"   # pre-AVX2 CPU build (older Xeons/Atoms)
  echo "note: using baseline binary $(basename "$BIN")"
fi
[ -f "$BIN" ] || die "missing $BIN (build it: ./build.sh 1.5.0 bun-$PLATFORM)"
[ -f "$FROM/package.json" ] || die "missing $FROM/package.json (needed for --version / app name)"

LIB="${PI_LIB:-$PREFIX/lib/pi}"
BIN_DIR="$PREFIX/bin"

# ---------------------------------------------------------------- binary
say "platform $PLATFORM -> $LIB"
run mkdir -p "$LIB" "$BIN_DIR"
run cp "$BIN" "$LIB/pi"   # cp+chmod, not install(1): Termux has no coreutils by default
run chmod 0755 "$LIB/pi"
for asset in package.json theme assets export-html photon_rs_bg.wasm; do
  [ -e "$FROM/$asset" ] || die "missing asset: $FROM/$asset"
  run rm -rf "$LIB/$asset"
  if [ -d "$FROM/$asset" ]; then run cp -R "$FROM/$asset" "$LIB/$asset";
  else run cp "$FROM/$asset" "$LIB/$asset"; fi
done

SHIM="$BIN_DIR/pi"
say "shim $SHIM"
if [ "$DRY" = 1 ]; then
  echo "   [dry] write shim"
else
  cat > "$SHIM" <<EOF
#!/bin/sh
exec "$LIB/pi" "\$@"
EOF
  chmod 0755 "$SHIM"
fi

# ---------------------------------------------------------------- web dashboard
WEB_SRC="$HERE/pi-web"
[ -d "$WEB_SRC" ] || WEB_SRC="$FROM/pi-web"
LIB_WEB="${PI_WEB_LIB:-$PREFIX/lib/pi-web}"
WEB_SHIM="$BIN_DIR/pi-web"
if [ "$WITH_WEB" = 0 ]; then
  echo "   web: skipped (--no-web)"
elif [ ! -d "$WEB_SRC" ]; then
  echo "   web: no pi-web build found (run ./build-web.sh) — skipping dashboard"
else
  say "web $LIB_WEB"
  run rm -rf "$LIB_WEB"
  run mkdir -p "$LIB_WEB"
  run cp -R "$WEB_SRC/." "$LIB_WEB/"

  # pi-web runs on Node >= 22.19 or Bun; this repo assumes Bun.
  WEB_RUNNER=""
  if command -v bun >/dev/null 2>&1; then
    WEB_RUNNER="$(command -v bun)"
  elif [ -x "$HOME/.bun/bin/bun" ]; then
    WEB_RUNNER="$HOME/.bun/bin/bun"
  else
    echo "   warning: bun not found — the pi-web dashboard needs it:"
    echo "            curl -fsSL https://bun.sh/install | bash"
  fi

  say "web shim $WEB_SHIM"
  if [ "$DRY" = 1 ]; then
    echo "   [dry] write web shim (runner: ${WEB_RUNNER:-bun})"
  elif [ -n "$WEB_RUNNER" ]; then
    cat > "$WEB_SHIM" <<EOF
#!/bin/sh
# pi-web shim (bun). --preload supplies module.findPackageJSON, which Bun lacks.
PI_WEB_SKIP_VERSION_CHECK=\${PI_WEB_SKIP_VERSION_CHECK:-1}
export PI_WEB_SKIP_VERSION_CHECK
exec "$WEB_RUNNER" --preload "$LIB_WEB/scripts/bun-preload.cjs" "$LIB_WEB/bin/pi-web.js" "\$@"
EOF
    chmod 0755 "$WEB_SHIM"
  else
    echo "   (no runner found; shim not written — install bun, then re-run)"
    WEB_SHIM="$WEB_SHIM (missing bun)"
  fi
fi

# ---------------------------------------------------------------- config
say "config $AGENT_DIR"
if [ -e "$AGENT_DIR/settings.json" ] && [ "$FORCE" = 0 ]; then
  echo "   settings.json exists — keeping it (use --force to replace, backs up to .bak)"
else
  run mkdir -p "$AGENT_DIR"
  [ -e "$AGENT_DIR/settings.json" ] && run cp "$AGENT_DIR/settings.json" "$AGENT_DIR/settings.json.bak"
  run cp "$HERE/config/settings.json" "$AGENT_DIR/settings.json"
  run cp "$HERE/config/AGENTS.md" "$AGENT_DIR/AGENTS.md"
  # merge-copy (".") so a re-run with --force does not nest skills/skills/ inside AGENT_DIR
  for d in skills prompts extensions agents; do
    run mkdir -p "$AGENT_DIR/$d"
    run cp -R "$HERE/config/$d/." "$AGENT_DIR/$d/"
  done
fi

# Environment facts appended to the system prompt: remote MCP servers vs this host.
# Installed even when settings.json is kept, but never clobbers local edits without --force.
if [ ! -e "$AGENT_DIR/APPEND_SYSTEM.md" ] || [ "$FORCE" = 1 ]; then
  [ -e "$AGENT_DIR/APPEND_SYSTEM.md" ] && run cp "$AGENT_DIR/APPEND_SYSTEM.md" "$AGENT_DIR/APPEND_SYSTEM.md.bak"
  run cp "$HERE/config/APPEND_SYSTEM.md" "$AGENT_DIR/APPEND_SYSTEM.md"
else
  echo "   APPEND_SYSTEM.md exists — keeping it (use --force to replace)"
fi

# ---------------------------------------------------------------- provider
EXHUB_BASE_URL="${EXHUB_BASE_URL:-http://localhost:9069/openai/v1}"
EXHUB_API_KEY="${EXHUB_API_KEY:-exhub-local}"
if [ -e "$AGENT_DIR/models.json" ] && [ "$FORCE" = 0 ]; then
  echo "   models.json exists — keeping it"
else
  say "models.json (provider exhub -> $EXHUB_BASE_URL)"
  if [ "$DRY" = 1 ]; then
    echo "   [dry] render from config/models.json.tmpl"
  else
    if [ -e "$AGENT_DIR/models.json" ]; then run cp "$AGENT_DIR/models.json" "$AGENT_DIR/models.json.bak"; fi
    EXHUB_BASE_URL="$EXHUB_BASE_URL" EXHUB_API_KEY="$EXHUB_API_KEY" \
      render_tmpl "$HERE/config/models.json.tmpl" "$AGENT_DIR/models.json" EXHUB_BASE_URL EXHUB_API_KEY
    chmod 600 "$AGENT_DIR/models.json"
  fi
fi

# ---------------------------------------------------------------- MCP
EXHUB_ORIGIN="${EXHUB_ORIGIN:-${EXHUB_BASE_URL%/openai/v1}}"
PI_PROJECT_DIR="${PI_PROJECT_DIR:-$PWD}"
if [ "$WITH_MCP" = 0 ]; then
  echo "   MCP: skipped (--no-mcp)"
elif [ -e "$AGENT_DIR/mcp.json" ] && [ "$FORCE" = 0 ]; then
  echo "   mcp.json exists — keeping it"
else
  say "mcp.json ($(grep -c '"url"' "$HERE/config/mcp.json.tmpl") servers via $EXHUB_ORIGIN)"
  if [ "$DRY" = 1 ]; then
    echo "   [dry] render from config/mcp.json.tmpl"
  else
    if [ -e "$AGENT_DIR/mcp.json" ]; then run cp "$AGENT_DIR/mcp.json" "$AGENT_DIR/mcp.json.bak"; fi
    EXHUB_ORIGIN="$EXHUB_ORIGIN" PI_PROJECT_DIR="$PI_PROJECT_DIR" \
      render_tmpl "$HERE/config/mcp.json.tmpl" "$AGENT_DIR/mcp.json" EXHUB_ORIGIN PI_PROJECT_DIR
    chmod 600 "$AGENT_DIR/mcp.json"
  fi
fi

# ---------------------------------------------------------------- verify
say "verify"
if [ "$TERMUX" = 1 ]; then VERIFY_PATH="$PREFIX/bin:/system/bin"; else VERIFY_PATH="/usr/bin:/bin:/usr/sbin:/sbin"; fi
if [ "$DRY" = 1 ]; then
  echo "   [dry] $LIB/pi --version"
else
  env -i PATH="$VERIFY_PATH" "$LIB/pi" --version
fi

cat <<EOF

Installed.
  binary : $LIB/pi (+ assets in $LIB)
  shim   : $SHIM
  config : $AGENT_DIR
EOF

if [ "$WITH_WEB" = 1 ] && [ -d "$WEB_SRC" ]; then
  cat <<EOF
  web    : $LIB_WEB
  web shim: $WEB_SHIM
EOF
fi

cat <<EOF

Add to PATH if needed:  export PATH="$BIN_DIR:\$PATH"
Smoke test:             pi -p "Reply with exactly: OK" --no-session
EOF

if [ "$WITH_WEB" = 1 ] && [ -d "$WEB_SRC" ]; then
  cat <<EOF
Dashboard:              pi-web            (http://127.0.0.1:30141)
                        pi-web --help     port, hostname, --no-open
                        pi-web status | stop | open
EOF
fi
