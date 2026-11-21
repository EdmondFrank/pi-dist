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
#   ./install.sh --no-acp        # skip the ACP adapter (pi-acp, for Emacs agent-shell / Zed)
#   ./install.sh --wezterm       # also install ~/.config/wezterm/pi.lua (keyboard protocol + Emacs copy mode)
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
WEZTERM_DIR="${PI_WEZTERM_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/wezterm}"
FORCE=0
DRY=0
WITH_MCP=1
WITH_WEB=1
WITH_ACP=1
WITH_WEZTERM=0   # opt-in: the config governs every program in that terminal, not just pi
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
    --no-acp)    WITH_ACP=0; shift ;;
    --wezterm)   WITH_WEZTERM=1; shift ;;
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

# ---------------------------------------------------------------- ACP adapter
# pi-acp is the ACP (Agent Client Protocol) adapter: ACP clients such as Emacs
# agent-shell or Zed spawn it and it drives `pi --mode rpc` for them. Self
# contained binary, so the client needs no Node.js either.
ACP_SRC="$HERE/pi-acp-$PLATFORM"
[ -f "$ACP_SRC" ] || ACP_SRC="$FROM/pi-acp-$PLATFORM"
[ -f "$ACP_SRC" ] || ACP_SRC="$FROM/pi-acp-$PLATFORM-baseline"
LIB_ACP="${PI_ACP_LIB:-$PREFIX/lib/pi-acp}"
ACP_SHIM="$BIN_DIR/pi-acp"
if [ "$WITH_ACP" = 0 ]; then
  echo "   acp: skipped (--no-acp)"
elif [ ! -f "$ACP_SRC" ]; then
  echo "   acp: no pi-acp build found (run ./build-acp.sh) — skipping ACP adapter"
else
  say "acp $LIB_ACP"
  run mkdir -p "$LIB_ACP"
  run install -m 0755 "$ACP_SRC" "$LIB_ACP/pi-acp"

  # The shim pins PI_ACP_PI_COMMAND to this prefix's pi, so the adapter never
  # resolves `pi` from PATH (GUI Emacs often has a different PATH than a login
  # shell) and a `pi` on PATH belonging to another tool cannot be picked up.
  say "acp shim $ACP_SHIM"
  if [ "$DRY" = 1 ]; then
    echo "   [dry] write acp shim"
  else
    cat > "$ACP_SHIM" <<EOF
#!/bin/sh
# pi-acp shim written by pi-dist install.sh — the ACP adapter for this pi.
PI_ACP_PI_COMMAND="\${PI_ACP_PI_COMMAND:-$LIB/pi}"
# pi-acp compares against the literal string "true" (not "1").
PI_ACP_ENABLE_EMBEDDED_CONTEXT="\${PI_ACP_ENABLE_EMBEDDED_CONTEXT:-true}"
export PI_ACP_PI_COMMAND PI_ACP_ENABLE_EMBEDDED_CONTEXT
exec "$LIB_ACP/pi-acp" "\$@"
EOF
    chmod 0755 "$ACP_SHIM"
  fi
fi

# ---------------------------------------------------------------- wezterm
# Opt-in, and only ever additive: pi.lua holds the portable settings, while an
# existing wezterm.lua is left alone (--force backs it up before replacing).
WEZTERM_CFG="$HERE/config/wezterm"
if [ "$TERMUX" = 1 ] && [ "$WITH_WEZTERM" = 1 ]; then
  echo "   wezterm: skipped (Termux has no WezTerm)"
  WITH_WEZTERM=0
fi
if [ "$WITH_WEZTERM" = 0 ]; then
  echo "   wezterm: skipped (--wezterm installs config/wezterm/pi.lua)"
else
  say "wezterm $WEZTERM_DIR"
  run mkdir -p "$WEZTERM_DIR"
  [ -e "$WEZTERM_DIR/pi.lua" ] && run cp "$WEZTERM_DIR/pi.lua" "$WEZTERM_DIR/pi.lua.bak"
  run cp "$WEZTERM_CFG/pi.lua" "$WEZTERM_DIR/pi.lua"

  if [ ! -e "$WEZTERM_DIR/wezterm.lua" ]; then
    run cp "$WEZTERM_CFG/wezterm.lua" "$WEZTERM_DIR/wezterm.lua"
  elif [ "$FORCE" = 1 ]; then
    run cp "$WEZTERM_DIR/wezterm.lua" "$WEZTERM_DIR/wezterm.lua.bak"
    run cp "$WEZTERM_CFG/wezterm.lua" "$WEZTERM_DIR/wezterm.lua"
  elif grep -q 'pi\.lua' "$WEZTERM_DIR/wezterm.lua"; then
    echo "   wezterm.lua already loads pi.lua — keeping it"
  else
    echo "   wezterm.lua exists — keeping it; add these two lines to it:"
    echo "     local pi = dofile(wezterm.config_dir .. '/pi.lua')"
    echo "     for k, v in pairs(pi) do config[k] = v end"
  fi

  # show-keys exits 0 even when the config failed to load, so assert on a
  # binding that only pi.lua defines (C-w has no default in copy_mode).
  if ! command -v wezterm >/dev/null 2>&1; then
    echo "   wezterm: not on PATH — config written, nothing to check"
  elif [ "$DRY" = 1 ]; then
    echo "   [dry] wezterm --config-file $WEZTERM_DIR/wezterm.lua show-keys --lua --key-table copy_mode"
  elif wezterm --config-file "$WEZTERM_DIR/wezterm.lua" show-keys --lua --key-table copy_mode 2>/dev/null \
       | grep -qF "{ key = 'w', mods = 'CTRL'"; then
    echo "   wezterm: config ok"
  else
    echo "   warning: wezterm loaded $WEZTERM_DIR/wezterm.lua without pi.lua" >&2
    echo "            add the dofile lines above, or check for a Lua error" >&2
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

if [ "$WITH_ACP" = 1 ] && [ -x "${ACP_SHIM:-}" ]; then
  # Closing stdin makes the ACP server shut down; a clean exit proves the
  # adapter runs here and that the shim resolves its pinned pi.
  if printf '' | "$ACP_SHIM" >/dev/null 2>&1; then
    echo "   pi-acp: ok"
  else
    echo "   warning: $ACP_SHIM did not exit cleanly" >&2
  fi
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

if [ "$WITH_ACP" = 1 ] && [ -x "${ACP_SHIM:-}" ]; then
  cat <<EOF
  acp    : $LIB_ACP/pi-acp
  acp shim: $ACP_SHIM  (spawned by ACP clients: Emacs agent-shell, Zed, ...)
EOF
fi

if [ "$WITH_WEZTERM" = 1 ]; then
  cat <<EOF
  wezterm: $WEZTERM_DIR/pi.lua
           copy mode (Ctrl+Shift+X): C-a/C-e, C-f/C-b, C-n/C-p, M-f/M-b, C-v/M-v, C-w
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

if [ "$WITH_ACP" = 1 ] && [ -x "${ACP_SHIM:-}" ]; then
  cat <<EOF
Emacs:                  M-x agent-shell-pi-start-agent   (agent-shell finds pi-acp on PATH)
                        M-x agent-shell, pick "Pi"       (same, from the agent picker)
                        adapter check: printf '' | pi-acp && echo acp-ok
EOF
fi
