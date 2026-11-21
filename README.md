# pi-dist-build

Self-contained [pi coding agent](https://pi.dev) + portable config, so a fresh machine gets a working agent without installing Node.js.

Built artifact: **pi 1.5.0**, single executable, ~77 MB, bun-embedded runtime. Optional extras from the same sources: the **pi-web** dashboard (needs bun) and the **pi-acp** adapter (~61 MB) that lets ACP clients — Emacs `agent-shell`, Zed — drive it.

```bash
./build.sh 1.5.0 bun-darwin-arm64    # build     -> out/
./build.sh 1.5.0 bun-android-arm64    # Termux/Android (bionic PIE) -> out/pi-android-arm64
./build-acp.sh                       # optional  -> out/pi-acp-<platform>
./install.sh                         # install   -> ~/.local/{bin,lib/pi} + ~/.pi/agent
```

## Usage

The binary and its assets live in `$PREFIX/lib/pi` (`~/.local/lib/pi`) behind a `pi` shim; config lives in `$PI_CODING_AGENT_DIR` (default `~/.pi/agent`).

### ExHub provider

The dist is built around a local **ExHub** hub: one process on `http://localhost:9069` that serves an OpenAI-compatible API at `/openai/v1` (230 models) and MCP servers at `/<name>/mcp` (17 are used here). No per-provider keys or accounts are involved.

`install.sh` renders two files from the templates, so a real key never has to be committed:

| File | From | Contents |
|---|---|---|
| `$AGENT_DIR/models.json` (0600) | `config/models.json.tmpl` | provider `exhub` + `${EXHUB_BASE_URL}`, `${EXHUB_API_KEY}`, 16 model definitions |
| `$AGENT_DIR/mcp.json` (0600) | `config/mcp.json.tmpl` | 17 servers at `${EXHUB_ORIGIN}/<name>/mcp`; `desktop`/`lua` also send `x-project-dir: ${PI_PROJECT_DIR}` |

Install-time variables:

| Variable | Default | Meaning |
|---|---|---|
| `EXHUB_BASE_URL` | `http://localhost:9069/openai/v1` | OpenAI-compatible endpoint written into `models.json` |
| `EXHUB_API_KEY` | `exhub-local` | value written into `models.json`; the local hub ignores it |
| `EXHUB_ORIGIN` | `EXHUB_BASE_URL` without `/openai/v1` | origin for every MCP URL |
| `PI_PROJECT_DIR` | `$PWD` | `x-project-dir` header for the `desktop`/`lua` tools |
| `PI_CODING_AGENT_DIR` | `~/.pi/agent` | where the config is written |

```bash
./install.sh                                                     # local hub, defaults
EXHUB_BASE_URL=http://hub.example.com:9069/openai/v1 ./install.sh   # hub on another host
EXHUB_API_KEY='$EXHUB_API_KEY' ./install.sh --force              # keep the key in the environment
./install.sh --no-mcp                                            # models only, no hub tools
```

`models.json`'s `apiKey` and `headers` values resolve a literal string, `"$NAME"` environment interpolation, or `"!command"` output — so `"apiKey": "$EXHUB_API_KEY"` with `export EXHUB_API_KEY=…` keeps the secret out of the file. `baseUrl` is literal, so it is fixed at install time: re-run `install.sh --force` after changing the hub address, or edit `models.json` and `/reload`. The same `${VAR}` / `!command` expansion works in `mcp.json` `env` and `headers`.

Verify the wiring:

```bash
curl -s localhost:9069/openai/v1/models | head -c 120   # hub up: 230 models, no auth needed
pi auth check --model exhub/deepseek-v4.1-flash        # provider reachable, key accepted
pi mcp list                                            # 17 servers connected
```

Without a hub, point the provider at any OpenAI-compatible endpoint (edit `baseUrl`/`apiKey` in `models.json`, or add a second provider block) and pass `--no-mcp`. Each model entry (`id`, `name`, `reasoning`, `input`, `contextWindow`, `maxTokens`, `cost`) is what `pi --list-models` shows and what compaction budgeting uses. Change the default model in `settings.json` (`defaultProvider`/`defaultModel`) or with `pi config`.

### Sessions

```bash
pi                       # interactive TUI in the current directory
pi -c                    # continue this directory's most recent session
pi -r                    # pick a session from a list
pi --session <id|path>   # open a specific session
pi --fork <id>           # branch a session into this directory
pi --no-session          # ephemeral, writes nothing
```

Sessions are written to `$AGENT_DIR/sessions/<cwd-slug>/<ts>_<id>.jsonl` — JSONL v3, the same format Raft writes to `.pi-sessions`, so they can be copied between the two.

### Non-interactive / scripting

```bash
pi -p "explain src/main.ts"                 # print the answer and exit
pi --mode json -p "list the TODOs" > out.json
git diff | pi -p "review this diff"         # stdin is passed in
pi -p @src/app.ts "what does this do?"      # attach files with @
pi --no-session -p "what is 2+2"            # don't persist a session
```

`--mode` takes `text` (default), `json`, or `rpc`.

### Models

Default is `exhub/deepseek-v4.1-flash` at thinking `high` (`config/settings.json`).

```bash
pi --list-models                        # everything the catalog knows
pi --list-models kimi                   # fuzzy search
pi --model exhub/kimi-k2.7-code         # one-off model
pi --model exhub/glm-5.2:high           # model + thinking level
pi --thinking off -p "..."              # off|minimal|low|medium|high|xhigh|max
```

Inside a session `Ctrl+P` cycles the 9 `enabledModels`; add to that array in `settings.json` to extend the ring.

### Tools and permissions

```bash
pi --tools 'read,bash,edit'   # allowlist (patterns allowed)
pi -xt 'bash'                 # denylist, applies to MCP tools too
pi -nbt                       # keep extension/MCP tools, drop built-ins
pi -nt                        # no tools at all
pi -a                         # trust project-local .pi/ files for this run
```

### MCP

`install.sh` renders `config/mcp.json.tmpl` into `$AGENT_DIR/mcp.json` with 17 servers.

```bash
pi mcp list                                  # state, tool counts, errors (exits 1 on failure)
pi mcp add mem --url http://localhost:9069/memory/mcp
pi --no-mcp -p "..."                         # run with every server disabled
```

Every bundled server uses `codemode` exposure, so tools are reached through the `lua` codemode namespace instead of one tool per MCP tool. Per-server `exposure` (`codemode` | `direct` | `deferred` | `hidden`) is editable in `mcp.json`, or with `/mcp` inside a session.

### Skills, prompts, subagents

```
$AGENT_DIR/skills/<name>/SKILL.md    49 bundled — /skill:<name> or auto-selected
$AGENT_DIR/prompts/<name>.md         2 bundled (plan, handoff) — /<name>
$AGENT_DIR/agents/<name>.md          8 bundled subagents (worker, planner, scout, …)
$AGENT_DIR/AGENTS.md                 global instructions, prepended to every session
$AGENT_DIR/APPEND_SYSTEM.md          extra system-prompt text, no host-specific values
```

```bash
pi --skill ./SKILL.md -p "..."       # load an extra skill
pi --prompt-template ./tmpl.md       # load an extra prompt template
pi -ns -np                           # disable skills / prompt templates
```

The bundled subagents call `solo_tool`, so they only work after `pi install git:github.com/HazAT/pi-solo`.

### Recipes

| Task | Command |
|---|---|
| Explain a repo | `pi -p @README.md "summarize this project"` |
| Review staged changes | `git diff --staged \| pi -p "review for bugs"` |
| Machine-readable output | `pi --mode json -p "list files over 1MB"` |
| Ephemeral question | `pi --no-session -p "what does jiti do?"` |
| No startup network | `pi --offline -p "..."` |
| Export a session | `pi --export <session.jsonl> out.html` |
| Check provider auth | `pi auth check --model exhub/deepseek-v4.1-flash` |

## Why

Raft's agents (`raft-computer`) do **not** spawn the `pi` CLI — the daemon imports `@earendil-works/pi-coding-agent` in-process (`packages/daemon/src/drivers/pi.ts`) and the shipped SEA bundles `@earendil-works/pi-coding-agent@1.5.0`. This repo reproduces that runtime as a standalone binary: same SDK version, no daemon, no Node.

`pi --version` here reports `1.5.0`, i.e. what Raft actually runs — not `0.1.0` (the Zig rewrite at `~/.cargo/bin/pi`) and not `1.0.63` (`runtime-cli-versions.json`, which is the Raft runtime slot).

## Verified (2026-11-16, darwin-arm64)

| Check | Result |
|---|---|
| `--version` | `1.5.0` |
| `--help` | full CLI surface |
| no Node on PATH (`env -i PATH=/usr/bin:/bin`) | `1.5.0` |
| skills + extensions load (jiti, compiled) | ✅ |
| isolated `PI_CODING_AGENT_DIR` | ✅ |
| end-to-end `install.sh` into clean prefix, then `pi -p …` | ✅ |
| session writer | ✅ `$AGENT_DIR/sessions/<cwd-slug>/<ts>_<id>.jsonl` |
| Ubuntu 18.04 amd64 (Docker, glibc 2.27) | ✅ install + model + codemode tool call |
| ACP adapter (`pi-acp`) ↔ pi 1.5.0 | ✅ initialize / session/new / prompt ("OK") via `scripts/acp-smoke.py` |
| Emacs `agent-shell` end-to-end | ✅ `agent-shell-pi-start-agent` → prompt answered (headless, `emacs -Q --batch`) |
| MCP: 17 servers connect (`pi mcp list`) | ✅ all connected |
| codemode + MCP tool call (`todo get_items`) | ✅ |
| bundled skills / subagents | 49 skills, 8 agents |
| photon wasm / image tools | ⚠️ untested (needs a vision model) |
| TUI theme rendering | ⚠️ untested (headless only) |

## Layout

```
LICENSE                  MIT (this repository)
NOTICE                   provenance for bundled third-party skills
SECURITY.md              key handling + how to report
build.sh                 build from the npm release (tarball -> bun compile -> assets)
build-acp.sh             build the ACP adapter (pi-acp -> bun compile -> single binary)
build-web.sh             stage the pi-web dashboard from the npm release
package.sh               stage binary + assets + config into release/<name>.tar.gz + sha256
install.sh               install binary + config on a machine (no Node needed)
TERMUX.md                unpack + install on Android (Termux), incl. known limits
scripts/acp-smoke.py     ACP client used to smoke-test pi-acp (handshake, optional prompt)
release/                 shippable tarballs (gitignored)
out/                     build output: pi-<platform>, package.json, theme/, assets/, export-html/, photon_rs_bg.wasm
config/
  settings.json          portable settings — packages[] removed (agent starts bare)
  models.json.tmpl       provider template: ${EXHUB_BASE_URL} / ${EXHUB_API_KEY}
  mcp.json.tmpl          17 MCP servers, ${EXHUB_ORIGIN} + ${PI_PROJECT_DIR}
  mcp.json.example       single-server example (LAN URL, not installed)
  agent-shell-pi-dist.el optional Emacs snippet wiring agent-shell to this dist
  wezterm/               optional WezTerm config: keyboard protocol, Alt+Enter, Emacs copy mode
  AGENTS.md              global agent instructions
  skills/                49 skills: ~/.pi/agent (13) + ~/.aider-desk (36)
  prompts/ extensions/   2 prompts, 3 extensions from ~/.pi/agent
  agents/                8 subagent definitions from ~/.pi/agent/agents
locks/                   vendored package-locks (pi-web, pi-acp) for reproducible installs
src/                     extracted npm release + node_modules (gitignored, reproducible)
```

Binaries (`out/`) and `src/` are gitignored — ship `out/` as a release tarball, rebuild via `build.sh`.

### Imported from `~/.aider-desk`

| Source | What was taken | Notes |
|---|---|---|
| `mcp-servers.json` | 22 servers → 17 in `mcp.json.tmpl` | host rewritten to `${EXHUB_ORIGIN}`; `mcp-hub` dropped (duplicates every tool), `gitgud` dropped (404 on the hub) |
| `skills/` (44) | 36 new skills | deduped against `~/.pi/agent/skills`; internal-infrastructure skills dropped for the public release; `examples/ evals/ tests/ corpus/ fixtures/` and files >200 KB pruned |
| `agents/*/config.json` | **not** ported | AiderDesk agents are tool-approval profiles, not pi agent files |
| `prompts/system-prompt.hbs` | **not** ported | Handlebars; pi prompts are Markdown + frontmatter |
| `extensions/` (48 MB) | **not** ported | different extension API |

The 8 bundled agents (`worker`, `planner`, `scout`, …) use `solo_tool`, so they only fully work after `pi install git:github.com/HazAT/pi-solo`.

## Build

Requires `bun` + `npm` on the **build** machine only (target needs neither).

```bash
cd ~/Code/pi-dist-build
export https_proxy=http://127.0.0.1:7890 http_proxy=$https_proxy   # if needed
./build.sh 1.5.0 bun-darwin-arm64
./build.sh 1.5.0 bun-linux-x64       # emit for another target
./build-acp.sh 0.0.34 bun-darwin-arm64   # ACP adapter, same recipe
```

Two non-obvious requirements baked into `build.sh`:

1. **`package.json` must sit next to the binary.** `VERSION`/`APP_NAME` come from `getPackageJsonPath()` = the exe directory; without it `--version` prints `0.0.0`.
2. **Assets must sit next to the binary**: `theme/`, `assets/`, `export-html/`, `photon_rs_bg.wasm`.
3. **The codemode worker must be an extra entrypoint.** `dist/config.js` (`resolveCodemodeWorkerSpecifier`) returns the literal `"./src/extensions/codemode/worker.ts"` for a bun binary, so `build.sh` copies `dist/bundle/chunks/codemode-worker.js` to that path and compiles both entrypoints. Skip it and every codemode/MCP tool call fails with `ModuleNotFound resolving "./src/extensions/codemode/worker.ts"`.

Do not add `--minify` / `--bytecode` — pi loads extensions and skills at runtime through `jiti` and resolves asset paths from `dirname(argv[0])`.

## Web dashboard (pi-web)

[pi-web](https://github.com/agegr/pi-web) is the browser UI for pi: sessions, files, Git diffs, terminals, models, MCP, skills. It is packaged here as the npm release, not built from source, because `@agegr/pi-web` already ships a prebuilt, pruned `.next` (7 MB):

```bash
./build-web.sh 0.17.0     # -> out/pi-web (466 MB, ~56 MB compressed)
./install.sh              # also installs ~/.local/lib/pi-web + a pi-web shim
```

`install.sh --no-web` skips it; `package.sh` bundles `out/pi-web` into the release tarball automatically when present.

**The target machine needs `bun`** (pi itself does not): the dashboard runs Next 16 on Bun. `pi-web` is a shim at `$PREFIX/bin/pi-web`:

```bash
curl -fsSL https://bun.sh/install | bash   # once per machine
pi-web                                    # http://127.0.0.1:30141
pi-web --port 8080 --hostname 0.0.0.0     # Pi Web password login: PI_WEB_PASSWORD=...
pi-web status | stop | open
```

### Four adaptations `build-web.sh` makes

| Problem | Cause | Adaptation |
|---|---|---|
| `Failed to load next.config.ts` | Next transpiles a TS config through `require.extensions`; Bun has none | `scripts/gen-next-config-mjs.mjs` derives `next.config.mjs` |
| `findPackageJSON is not a function` → "MCP is off" | Bun lacks `module.findPackageJSON` (Node ≥ 22.14), and the chunk reaches it through a frozen ESM namespace | `scripts/patch-find-package-json.mjs` rewrites the call sites in `.next/server` chunks. A `--preload` shim cannot work: the CLI runs the server as a child process |
| `pty.node` fails to load → terminal panel dead | shipped `linux-x64` prebuild needs glibc ≥ 2.28 (Ubuntu 18.04 has 2.27) | rebuilt from source with `node-gyp@10`; result needs only glibc 2.4/2.8 |
| dependency resolution takes 10+ minutes | no lockfile in the npm tarball | `locks/pi-web-<version>/package-lock.json`, vendored from the release tag |

Pruned from `node_modules` (466 MB instead of 799 MB): `@next/swc-*`, `**/*.map`, `next/dist/docs`, `caniuse-lite`, `@img/sharp-libvips-*`. `next/dist/build` must stay — `bin/next` requires `../build/output/log`.

Use `PI_WEB_REGISTRY=https://registry.npmmirror.com ./build-web.sh` if the default registry is slow or blocked (the gitee npm mirror is unmaintained and returns 404s).

**Networking note:** `http_proxy` in the environment also catches loopback, so `http://127.0.0.1:30141` returns 502. Keep `127.0.0.1,localhost,::1` in `no_proxy` — `::1` matters because `localhost` resolves there first and the hub is reached as `localhost:9069`.

## ACP adapter (pi-acp) — Emacs agent-shell, Zed, …

[ACP](https://agentclientprotocol.com) is how editors drive an agent: the client spawns an adapter over stdio and the adapter drives the agent. For pi that adapter is [`pi-acp`](https://github.com/svkozak/pi-acp) (MIT, © Sergii Kozak). It is bundled here as a second self-contained binary built from the npm release, so the client needs neither Node nor npm:

```bash
./build-acp.sh 0.0.34     # -> out/pi-acp-<platform> (~61 MB, ~24 MB gzipped)
./install.sh              # also installs ~/.local/lib/pi-acp + a pi-acp shim
```

`install.sh --no-acp` skips it; `package.sh` adds `out/pi-acp-*` to the release tarball when present. `build-acp.sh` runs `scripts/acp-smoke.py` (handshake) after compiling — `PI_ACP_SMOKE_PROMPT=1 ./build-acp.sh` also sends one prompt, which costs tokens.

The shim at `$PREFIX/bin/pi-acp` is what clients spawn. It pins the adapter to *this* prefix's pi, so PATH order never decides which `pi` is driven:

| Variable | Shim default | Effect |
|---|---|---|
| `PI_ACP_PI_COMMAND` | `$PREFIX/lib/pi/pi` | the `pi` the adapter spawns (`pi --mode rpc --no-themes`) |
| `PI_ACP_ENABLE_EMBEDDED_CONTEXT` | `true` | advertise `promptCapabilities.embeddedContext`, so client-attached files/regions arrive as embedded resources instead of pasted text |

### Emacs agent-shell

`agent-shell` already ships `agent-shell-pi.el` (identifier `pi`), so one command is enough once the shim is on `PATH`:

```
M-x agent-shell-pi-start-agent          ; a Pi shell in the current project
M-x agent-shell                         ; or the picker, then "Pi"
```

What the adapter gives agent-shell:

| Feature | Behaviour |
|---|---|
| streaming | assistant text as `agent_message_chunk` |
| tool calls | `tool_call` / `tool_call_update` with file locations; `edit` also emits a structured diff |
| sessions | `session/load` reattaches through `~/.pi/pi-acp/session-map.json` to the same JSONL session pi writes |
| slash commands | `~/.pi/agent/prompts/**` + pi skills as `/skill:<name>`; plus `/compact`, `/autocompact`, `/export`, `/session`, `/name`, `/queue`, `/steering`, `/follow-up` |
| model & thinking | `session/new` `configOptions` (`model`, `thought_level`), switchable from the client |
| context usage | real `contextUsage` per turn as `usage_update` |

Pi skills, prompts, extensions and `AGENTS.md` are all loaded by pi itself, so agent-shell sessions behave like the TUI. Startup info (pi version, skills, prompts) is printed into the session unless `"quietStartup": true` is set in `settings.json`; the adapter still prints a "new version available" line when it can reach npm, which is harmless offline.

If GUI Emacs cannot see `~/.local/bin` (or the dist used a non-default `--agent-dir`), load the bundled snippet instead of fighting `exec-path`:

```elisp
(load "/path/to/pi-dist/config/agent-shell-pi-dist.el")
;; M-x customize-group RET agent-shell-pi-dist
;;   agent-shell-pi-dist-acp-shim     -> /Users/me/.local/bin/pi-acp
;;   agent-shell-pi-dist-agent-dir    -> /path/to/agent-dir (only if not ~/.pi/agent)
```

Limits (upstream): no ACP filesystem or terminal delegation — pi reads, writes and executes locally; MCP servers passed in `session/new` are stored but not forwarded to pi (pi uses its own `mcp.json`); thoughts are not streamed separately from assistant text.

## WezTerm (optional)

`config/wezterm/` is a two-file WezTerm setup for pi, installed with `./install.sh --wezterm`. It is **opt-in and additive** — WezTerm's config governs every program in that terminal, not just pi, so nothing is written unless you ask, and an existing `wezterm.lua` is never replaced (only `--force` does, after a `.bak`).

| File | Role |
|---|---|
| `pi.lua` | plain table: `enable_kitty_keyboard`, `Alt+Enter` → `CSI 13;3u`, Emacs `copy_mode` |
| `wezterm.lua` | minimal standalone config that merges `pi.lua`; written only when none exists |

If you already have a `wezterm.lua`, add two lines to it:

```lua
local pi = dofile(wezterm.config_dir .. '/pi.lua')
for k, v in pairs(pi) do config[k] = v end
```

Use `dofile`, not `require 'pi'` — WezTerm does not put the config directory on `package.path`.

The installer verifies the result the only way that works: `show-keys` exits 0 even on a config that failed to load, so it asserts on `C-w` in the `copy_mode` dump, a binding that only `pi.lua` defines.

### Emacs copy mode

`Ctrl+Shift+X` enters copy mode. Normal-mode keys are untouched, so the shell's own keymap still does line editing; the Emacs chords only replace WezTerm's scrollback keys.

| Key | Action |
|---|---|
| `C-a` / `C-e` | start / end of line |
| `C-f` / `C-b` | forward / back one character (WezTerm's defaults page up/down here) |
| `C-n` / `C-p` | next / previous line |
| `M-f` / `M-b` | forward / back one word |
| `C-v` / `M-v` | page down / up |

`C-v` is block-select by default; inside copy mode that moves to `Ctrl+Shift+V` (outside copy mode the key is still paste).
| `C-w` / `M-w` | kill-region: copy and leave copy mode |

The Vi table stays underneath (`h/j/k/l`, `v`, `V`, `y`, `H/L/M`, `g/G`), and `Space`/`v`/`V` still set cell/line selection. Declaring `key_tables.copy_mode` replaces the built-in table, so a custom Vi table of your own would be overridden by the merge — keep that in mind if you have one.

### Version limits

Checked against WezTerm `20220903` (the last release that runs on glibc 2.27, i.e. Ubuntu 18.04):

| Behaviour | 20220903 | Needs |
|---|---|---|
| `wezterm.config_builder()` | ✗ nil — pi's own `terminal-setup` snippet fails on it | WezTerm ≥ 2022-11 |
| `enable_kitty_keyboard` | ignored silently: `Shift+Enter` arrives as `\n`, indistinguishable from `Ctrl+J` | a build with the Kitty protocol |
| `Alt+Enter` → `CSI 13;3u` | ✅ works (verified byte-for-byte) | any build |
| OpenGL front end | ✗ panics `Could not resolve randr Event … response_type 103` on some X servers | add `front_end = 'Software'` to your config |

`config/wezterm/*.lua` therefore avoids `config_builder`, and the `front_end` workaround stays out of it — it is a host property, not a pi property.

## Config: what was stripped

`settings.json` keeps `defaultProvider`, `defaultModel`, `defaultThinkingLevel`, `theme`, `hideThinkingBlock`, `enabledModels`, `compaction`. The `packages` array was removed:

```diff
-  "packages": [
-    "git:github.com/pasky/chrome-cdp-skill",
-    "git:github.com/HazAT/pi-parallel",
-    "git:github.com/HazAT/pi-solo"
-  ],
```

Reason: on first run in a new agent dir pi installs those entries with a package manager, and `dist/package-manager-cli.js` prefers **npm/pnpm** (bun only as a last resort). On a Node-less box that fails or stalls for ~20 s. Re-add them later with `pi install <source>` once a package manager exists — or vendor them into `config/extensions/`.

## Updating

```bash
./build.sh <new-version> bun-darwin-arm64
./install.sh --force          # replaces binary + config, backs up settings.json -> .bak
```

Sessions live under `$AGENT_DIR/sessions` (default `~/.pi/agent/sessions`) and are untouched by `--force`; they are the same JSONL v3 format Raft writes to `.pi-sessions`.

## Limits

- Per-platform build; no cross-arch fallback (`Exec format error` if wrong).
- `android-arm64` is bun's `bun-linux-aarch64-android` runtime: the same `build.sh` works, the result links only `libc/libm/libdl` and runs on Termux (see [TERMUX.md](TERMUX.md)). `pi-web` is not shipped there — it is bun-packaged.
- The ACP adapter is ~61 MB (24 MB gzipped) per platform because it embeds a Bun runtime; ACP clients also get no filesystem/terminal delegation, since pi edits and executes locally.
- `mcp.json` is not part of the release tarball — render it with `install.sh`, or start from `config/mcp.json.example` and edit the URL.
- `AGENTS.md`, the prompts, and most skills encode one person's workflow; treat them as a starting point, not as defaults.
- pi itself is MIT and is not redistributed here — see [NOTICE](NOTICE) for bundled skill provenance.

## License

MIT — see [LICENSE](LICENSE). Vendored skills keep their upstream licenses (provenance table in [NOTICE](NOTICE)); key handling and reporting in [SECURITY.md](SECURITY.md).