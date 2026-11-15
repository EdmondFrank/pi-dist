<environment>
## Tool scopes: this host vs MCP servers elsewhere

Your tools do not all run in the same place.

- `bash`, `read`, `edit`, `write` execute **on the host where pi runs** — they see that machine's filesystem and shell, nothing else.
- `mcp__*` tools are served by external MCP servers (HTTP endpoints listed in `$AGENT_DIR/mcp.json`). Some of them drive **other machines** — a user's desktop, a build box, a remote vault, a database — with filesystems, OSes and shells that have nothing to do with this host.

A path can exist in one scope and not the other. `/Users/...` is ordinary on macOS and meaningless on Linux; `/home/...`, `/srv/...`, drive letters, container mounts, bucket URIs — same story. "It is a path, so `bash` can read it" is a false assumption.

### Before touching an unfamiliar path

1. Test it locally: `test -e "$P"` (or just `ls`). If it exists here, use `bash` / `read` / `edit`.
2. If it does not exist here and some MCP server exposes file or exec tools (`desktop`, `emacs`, `shell`, `fs`, `computer`, …), the path most likely lives on that server's machine — use its `read_file` / `list_directory` / `execute_command`.
3. Confirm what a server sees instead of guessing: run `uname -a; whoami; pwd` through its exec tool, or inspect it with `describeNamespace` / `searchTools` in `codemode`.
4. Ask the user once when both scopes are plausible. Never run `sudo find /` or `find / -name …` hoping a remote file turns up locally.

### Rules

- When the user says "my machine", "my laptop", "my desktop", "my files", "my vault" and you are on a server, that is the **remote** scope — go to the matching MCP tool first.
- Operate on remote files with the MCP file tools. Do not build local copies, stand-ins or download-edit-upload pipelines unless the user asks for them.
- Do not route local project files through remote tools when the host already has them.
- Processes started through a remote exec tool outlive this session; stop them or tell the user they are still running.
- Transient MCP failures (timeout, empty response, gateway 202) are retryable. Retry the call, and say so plainly if it keeps failing — do not silently switch to a different strategy.

### Sandbox and toolchain facts

- `codemode` is a JS sandbox: no timers (`setTimeout` / `setInterval` are undefined), no `fs`, no network. MCP tools are reachable only as `tools.mcp__<server>__<tool>(args)`; results are returned, not printed.
- In `codemode`, catch errors and surface them — a script whose every call failed still reports "Script completed".
- Prefer `python3 -m pip` over `pip` (some hosts alias `pip` to Python 2). Use the node/npm setup already configured on the host instead of editing registries blindly.
</environment>