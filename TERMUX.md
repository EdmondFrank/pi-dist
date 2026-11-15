# pi on Android (Termux)

`pi-android-arm64` is a bionic PIE (`interpreter /system/bin/linker64`) built from the same
npm release as the macOS/Linux binaries, with a bun runtime compiled for
`bun-linux-aarch64-android`. It links only `libc.so`, `libm.so`, `libdl.so` — all provided by
Termux. No proot, no glibc-runner, no Node.

## 1. Unpack inside Termux's home

Android shared storage (`/sdcard`, `~/storage/downloads`) is mounted **noexec**, so the binary
cannot start from there. Move the tarball into Termux's own filesystem first:

```bash
pkg install tar termux-api            # tar to unpack, termux-api for clipboard
pkg install fd ripgrep                # pi warns about these on first start; both speed up search
termux-setup-storage                  # once, to reach ~/storage/downloads
cd ~
tar xzf ~/storage/downloads/pi-1.5.0-android-arm64.tar.gz
cd pi-1.5.0-android-arm64
ls -l                                  # the binary must be executable (mode 0755)
```

If you copied it in with a file manager instead, `chmod +x install.sh out/pi-android-arm64`
before continuing.

## 2. Install

```bash
pkg install termux-api               # optional: clipboard get/set (termux-clipboard-*)
./install.sh
```

`install.sh` detects Termux on its own (`TERMUX_VERSION`, `PREFIX=/data/data/com.termux/*`) and
installs into the Termux prefix instead of `~/.local`:

| Path | Contents |
|---|---|
| `$PREFIX/lib/pi/pi` | the binary |
| `$PREFIX/lib/pi/{theme,assets,export-html,package.json,photon_rs_bg.wasm}` | runtime assets |
| `$PREFIX/bin/pi` | shim (already on `PATH` — no export needed) |
| `~/.pi/agent/` | `settings.json`, `models.json`, `mcp.json`, `AGENTS.md`, `APPEND_SYSTEM.md`, `skills/` |

`pi-web` (the browser dashboard) is skipped on Android: it is bun-packaged and there is no bun in
Termux. Pass `--web` if you ever get bun running there.

## 3. Check it

```bash
pi --version                                    # 1.5.0
pi -p "Reply with exactly: OK" --no-session     # end-to-end with the provider
pi mcp list                                     # MCP servers, if models.json/mcp.json point at a hub
```

## Pointing at your hub

`install.sh` renders `models.json` / `mcp.json` from templates. On a phone the hub is not on
`localhost`, so pass the origin of your ExHub gateway:

```bash
EXHUB_ORIGIN=http://10.7.0.21:9069 \
EXHUB_BASE_URL=http://10.7.0.21:9069/openai/v1 \
./install.sh
```

Otherwise edit `~/.pi/agent/models.json` (`baseUrl`) and `~/.pi/agent/mcp.json` (`url` per server)
afterwards. Needs the phone on the same LAN or VPN as the hub.

## Known Android limits

- **Phantom process killer**: Android kills backgrounded children of Termux. Run
  `pkg install termux-api && termux-wake-lock` (and keep the notification) for long `bash` or
  codemode jobs, or an interactive `pi` turn can die mid-tool-call.
- **Clipboard / image paste**: works through `termux-clipboard-get`/`set` when `termux-api` is
  installed; otherwise pi falls back gracefully with no clipboard support.
- **No `pi-web` dashboard** (see above).
- **Software keyboard**: the extra-keys row (`~/.termux/termux.properties`) helps for `Esc`, `Ctrl`,
  and arrows that the TUI expects.
- **Storage**: keep the checkout in `~`, not in `~/storage/*`.

## Uninstall

```bash
rm -f "$PREFIX/bin/pi"
rm -rf "$PREFIX/lib/pi"
rm -rf ~/.pi/agent            # optional: sessions and credentials live here too
```