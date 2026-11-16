# GUIDELINE — bring up a pi agent on a new machine

Runbook for the artifact produced by `build.sh`. Target: any macOS (arm64/x64) or Linux (x64/arm64) box with a shell. **No Node, npm, bun or Python required** on the target.

Time: ~3 minutes once the tarball is on the machine.

---

## 0. Prepare the artifact (on the build machine)

```bash
cd ~/Code/pi-dist-build
./build.sh 1.5.0 bun-linux-x64            # or bun-darwin-arm64
./build-acp.sh 0.0.34 bun-linux-x64       # optional: ACP adapter (agent-shell, Zed)
cd out && tar czf pi-1.5.0-linux-x64.tar.gz \
  pi-linux-x64 pi-acp-linux-x64 package.json theme assets export-html photon_rs_bg.wasm
shasum -a 256 pi-1.5.0-linux-x64.tar.gz
```

`./package.sh <ver> <slug>` does the same staging (binary + `pi-acp-*` + `pi-web/` if built) and writes the `.sha256` for you.

### Building for Ubuntu 18.04 / amd64

```bash
./build.sh 1.5.0 bun-linux-x64            # x86_64 with AVX2
./build.sh 1.5.0 bun-linux-x64-baseline   # pre-AVX2 CPUs (older Xeon E5/Atom)
./package.sh 1.5.0 linux-x64              # -> release/pi-1.5.0-linux-x64.tar.gz (~40 MB)
```

The binary needs **glibc >= 2.17** (highest symbol is `GLIBC_2.17`), so Ubuntu 18.04 (glibc 2.27) and anything newer works; nothing else is required (no Node, no npm, no bun). Verified by running the packaged tarball in `docker run --platform linux/amd64 ubuntu:18.04`: install, `pi --version` → `1.5.0`, 17 MCP servers connected, model reply, and a codemode tool call.

Cross-builds skip the local smoke test — `docker run --platform linux/amd64 ubuntu:18.04 /path/to/pi-linux-x64 --version` is the quick check, or just run it on the target.

### Building for Android / Termux

```bash
./build.sh 1.5.0 bun-android-arm64        # bionic PIE, interpreter /system/bin/linker64
./package.sh 1.5.0 android-arm64          # -> release/pi-1.5.0-android-arm64.tar.gz
```

Needs bun >= 1.4.4, which carries the `bun-linux-aarch64-android` runtime. The result links only `libc.so`, `libm.so`, `libdl.so` (all in Termux) and installs into `$PREFIX` instead of `~/.local`; `install.sh` detects Termux itself. `pi-web` is skipped — it is bun-packaged and Termux has no bun. Unpacking instructions and the Android-specific limits (noexec shared storage, phantom process killer, clipboard via `termux-api`) are in [TERMUX.md](TERMUX.md).

The binary alone is not enough — `package.json` (version/app name) and the four asset entries (`theme/`, `assets/`, `export-html/`, `photon_rs_bg.wasm`) must travel with it.

## 1. Transfer

```bash
scp pi-1.5.0-linux-x64.tar.gz user@host:/tmp/
# or: rsync -av --progress ... , or your gitea release, or a USB stick
```

## 2. Install

```bash
ssh user@host
mkdir -p ~/pi-bundle && tar xzf /tmp/pi-1.5.0-linux-x64.tar.gz -C ~/pi-bundle
cd ~/pi-bundle
# In a packaged tarball install.sh sits next to the binary and finds it by itself;
# from the repo, point at the bundle instead:
./install.sh --dry-run                       # inspect (repo: ./install.sh --from ~/pi-bundle)
./install.sh
```

What it does, in order:

| Step | Location |
|---|---|
| binary → `pi` (mode 0755) | `~/.local/lib/pi/pi` |
| assets next to it | `~/.local/lib/pi/{package.json,theme,assets,export-html,photon_rs_bg.wasm}` |
| shim `exec ~/.local/lib/pi/pi "$@"` | `~/.local/bin/pi` |
| ACP adapter (skipped with `--no-acp`) | `~/.local/lib/pi-acp/pi-acp` |
| shim exporting `PI_ACP_PI_COMMAND=~/.local/lib/pi/pi` | `~/.local/bin/pi-acp` |
| `settings.json`, `AGENTS.md`, `skills/`, `prompts/`, `extensions/`, `agents/` | `${PI_CODING_AGENT_DIR:-~/.pi/agent}` |
| `models.json` rendered from template | same dir, mode 0600 |
| `mcp.json` rendered from template (17 servers) | same dir, mode 0600 — skip with `--no-mcp` |

Existing config is preserved unless `--force` (which backs up `settings.json` → `.bak`). Use `--prefix`, `--agent-dir`, `--from` for non-default layouts.

## 3. PATH

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc   # or ~/.bashrc
exec $SHELL -l
```

## 4. Provider

`models.json` ships one provider, `exhub`, rendered from `config/models.json.tmpl`:

| Variable | Default | Meaning |
|---|---|---|
| `EXHUB_BASE_URL` | `http://localhost:9069/openai/v1` | OpenAI-compatible endpoint |
| `EXHUB_API_KEY` | `exhub-local` | key sent as `Authorization: Bearer` |

Pick one:

**a. Local exhub proxy** (same as this Mac) — run the exchanger/LLM proxy on `:9069`, then re-run:
```bash
EXHUB_BASE_URL=http://localhost:9069/openai/v1 EXHUB_API_KEY=... ./install.sh --force
```

**b. Any OpenAI-compatible endpoint** (LiteLLM, vLLM, OpenRouter, DeepSeek…):
```bash
EXHUB_BASE_URL=https://api.deepseek.com/v1 EXHUB_API_KEY=$DEEPSEEK_KEY ./install.sh --force
```
Model ids in `models.json` are exhub names; edit `config/models.json.tmpl` (or `~/.pi/agent/models.json`) if the upstream uses different ids.

**c. Native Anthropic/OpenAI** — add a `providers` entry instead of pointing `exhub` elsewhere, then set `defaultProvider`/`defaultModel` in `settings.json`.

Verify credentials without spending tokens:
```bash
pi auth check --provider exhub --json
```

### MCP servers

`mcp.json` is rendered from `config/mcp.json.tmpl` (17 servers: `~/.aider-desk/mcp-servers.json` minus the `mcp-hub` aggregator and the dead `gitgud` route):

| Variable | Default | Meaning |
|---|---|---|
| `EXHUB_ORIGIN` | `EXHUB_BASE_URL` minus `/openai/v1` | base for `<origin>/<server>/mcp` |
| `PI_PROJECT_DIR` | `$PWD` at install time | sent as `x-project-dir` header (desktop/lua tools) |

```bash
./install.sh --force                      # re-render with the current env
./install.sh --force --no-mcp             # skip MCP entirely (offline)
pi mcp list                               # expect: connected, N tools
```

If the hub is not reachable, `pi mcp list` shows the failures and the session still starts — tools just are not exposed. Change `enabled` to `false` for a single server instead of dropping the file.

## 5. Verification checklist

```bash
env -i PATH=/usr/bin:/bin ~/.local/lib/pi/pi --version      # 1.5.0  (proves no Node needed)
pi --version                                                 # 1.5.0  (via shim)
pi list                                                      # "No packages installed."
pi auth check --provider exhub --json                        # {"status":"ready",…}
pi mcp list | head -6                                       # "…: connected, N tools"
cd /tmp && pi -p "Reply with exactly: OK" --no-session        # OK
cd /tmp && pi -p "Use codemode to call todo get_items; answer with the item count" --no-session   # 0  (proves codemode + MCP + worker)
ls ~/.pi/agent/sessions                                      # session dir appears after a non-ephemeral run
printf '' | pi-acp && echo acp-ok                            # ACP adapter starts and exits cleanly
python3 scripts/acp-smoke.py --command pi-acp --cwd /tmp     # ACP handshake (initialize + session/new)
python3 scripts/acp-smoke.py --command pi-acp --cwd /tmp --prompt   # + one real prompt (costs tokens)
```

Skills/extensions are picked up from `~/.pi/agent` automatically; `pi -p "list your skills"` should name the bundled ones. `pi list` is empty **by design** — `packages[]` was stripped, see README.

## 6. First real session

```bash
mkdir -p ~/work/demo && cd ~/work/demo
pi                      # TUI; /help for slash commands
pi -p "summarize this repo" --no-session --mode text
```

- Global behaviour comes from `~/.pi/agent/AGENTS.md`; per-project behaviour from `AGENTS.md`/`CLAUDE.md` in the cwd.
- Sessions are JSONL v3 under `~/.pi/agent/sessions/<cwd-slug>/` — same format Raft writes to `.pi-sessions`, so `@agegr/pi-web` can browse them.
- Tools run with your shell privileges; there is no sandbox.

### From Emacs (agent-shell)

```elisp
;; needs agent-shell + pi-acp on exec-path (both come from this bundle)
M-x agent-shell-pi-start-agent     ; or: M-x agent-shell, pick "Pi"
```

The shell behaves like the TUI: skills, prompts and `AGENTS.md` come from
`~/.pi/agent`, `/plan` and `/skill:<name>` are slash commands, the model
selector maps to the `model` config option, and context usage is reported per
turn. Sessions written from Emacs are the same JSONL files the TUI resumes.
If Emacs cannot find `pi-acp`, load `config/agent-shell-pi-dist.el` and set
`agent-shell-pi-dist-acp-shim` (see README).

## 7. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `pi --version` → `0.0.0` | `package.json` not next to binary | copy it into `~/.local/lib/pi/` |
| `ENOENT … theme/…` or blank TUI | assets missing next to binary | re-run `install.sh` (or copy `theme assets export-html photon_rs_bg.wasm`) |
| `Exec format error` | wrong target arch | build `bun-<os>-<arch>` matching `uname -s/-m` |
| `401 invalid x-api-key` / `authentication_error` | `models.json` missing → fell back to a built-in provider | ensure `$PI_CODING_AGENT_DIR/models.json` exists and names `exhub` |
| First run stalls ~20 s, `npm warn EBADENGINE` | `packages[]` in settings (not in this bundle) | drop it, or install a package manager and run `pi install <source>` |
| `command not found: pi` | `~/.local/bin` not on PATH | add it (step 3) |
| shim points at a moved binary | prefix relocated | re-run `install.sh` with the new `--prefix` |
| MCP tools missing | installed with `--no-mcp`, or `mcp.json` absent | `./install.sh --force` (renders 18 servers) |
| `pi mcp list` shows `error` / refused | hub not reachable at `EXHUB_ORIGIN` | `nc -z <host> 9069`; re-render with the right origin |
| `ModuleNotFound resolving "./src/extensions/codemode/worker.ts"` | binary built without the codemode worker entrypoint | rebuild with `./build.sh` (it adds the entrypoint); temporary workaround: set `"exposure": "direct"` per server |
| bundled agents fail on `solo_tool` | agents need the Solo package | `pi install git:github.com/HazAT/pi-solo` |
| agent-shell: `pi-acp … not found` | adapter not installed, or `~/.local/bin` is not in Emacs' `exec-path` | `./install.sh` (installs it); in GUI Emacs load `config/agent-shell-pi-dist.el` and set `agent-shell-pi-dist-acp-shim` |
| agent-shell: `Session not ready... please wait` | prompt sent before `session/new` finished | wait for the `Pi>` prompt; the adapter needs a second to start pi |
| agent-shell shows no reply, pi fails to spawn | shim's pinned pi moved/was removed | re-run `./install.sh --force` (rewrites `~/.local/bin/pi-acp`) |
| ACP session has no MCP tools | pi-acp does not forward ACP `mcpServers` | expected: pi uses its own `mcp.json` (17 servers) |

## 8. Maintenance

| Task | Command |
|---|---|
| Upgrade pi | `./build.sh <ver> bun-<plat>` then `./install.sh --force` |
| Keep config, reset models | `./install.sh --force` + re-render `models.json` only (edit env, delete file, re-run) |
| Rollback | `mv ~/.pi/agent/settings.json.bak ~/.pi/agent/settings.json`; re-install the previous binary |
| Sessions/backups | `~/.pi/agent/sessions` (JSONL) — never touched by the installer |
| Add a package again | `pi install git:github.com/HazAT/pi-solo` (needs npm/pnpm/bun on the box) |
| Refresh skills/agents | edit `config/skills`, `config/agents`, then `./install.sh --force` |
| Change MCP set | edit `config/mcp.json.tmpl`, re-run `./install.sh --force` |
| Upgrade ACP adapter | `./build-acp.sh <ver> bun-<plat>` then `./install.sh --force` (pin a new `locks/pi-acp-<ver>/package-lock.json`) |

## 9. Security

- `models.json` holds a credential → mode `0600`; never commit rendered output.
- `config/models.json.tmpl` and `config/settings.json` contain **no** secrets and are safe to push.
- The binary executes tools as your user; treat a copied `~/.pi/agent` as trusted code (skills/extensions run in-process).