# Troubleshooting, Debugging, FAQ & Compatibility

Sources: docs.pyinfra.com/en/3.x debugging, faq, compatibility, performance, install pages.

## The debugging loop (docs-recommended)

1. **Inspect inputs**: `pyinfra inventory.py debug-inventory` (resolved hosts/groups/data; add `--json`) and `pyinfra inventory.py fact server.LinuxName` (any fact directly).
2. **Preview the plan**: `--debug-operations` (order, no connect) → `--dry` (connect, facts, change report, no mutations).
3. **Raise verbosity**: `-v` facts+noops, `-vv` commands sent, `-vvv` output; `--debug` for pyinfra internals, `--debug-all` includes dependency logs.
4. **Log values from deploy code** with pyinfra's logger during prepare:

```python
from pyinfra import host, logger
from pyinfra.facts.server import LinuxDistribution
logger.info("Distribution data: %r", host.get_fact(LinuxDistribution))
```

- Do NOT add a `server.shell` op just to print a Python value — ops run on the target and are deferred to execute; use `logger` (or a `python.call` callback if it needs op output).
- Don't step through a deploy in an interactive debugger expecting the remote order — prepare runs per host, execute is concurrent.
- Avoid logging secrets/host-sensitive data. Keep diagnostic changes small; remove them once understood.
- `pyinfra --support` dumps version/env info for bug reports.

## Symptom table

| Symptom | Cause / fix |
|---|---|
| Changes reported on every run | Branching on a mutable fact in Python (prepare-time) → use `_if`; or `@docker/IMAGE` targets are fresh containers each run (expected) |
| `No such module: init` | Docs examples use removed `init.*` ops → use `server.service`/`systemd.service` |
| `ArgumentTypeError` at prepare | Non-callable passed to `_if` → wrap: `_if=lambda: bool(value)` |
| `result.stdout` raises inside deploy | Output only exists post-execute → read in `python.call(callback)` |
| Cycle error at prepare | Ops inside a plain loop with per-host branches → wrap the iterable in `host.loop(...)` (see `deploy-process.md`) |
| Host fails though "nothing ran" | A fact command exited non-zero → `host.get_fact(F, _ignore_errors=True)` |
| Bash syntax fails silently | Default shell is `sh` → `_shell_executable="bash -l"` |
| `No init system found (no systemctl, initctl, /etc/init.d or /etc/rc.d found)` | `server.service` on a host without a supported init (e.g. macOS local) → use `launchd.service` there |
| `--json` crashes on inventory data | Non-JSON-serializable data values → keep inventory data to primitives |
| `--json` doesn't apply changes | By design: add `--yes` (or use a plain run) |
| Parallel run hits fd limits | Concurrency capped by the open-file-descriptor limit → lower `--parallel N`/`config.PARALLEL`, use `_serial`, or raise ulimit |
| PyCharm debugger hangs | pyinfra uses gevent → enable PyCharm's gevent debug support |

## FAQ highlights (docs)

- **Current host name**: `host.name` (inventory label) vs `host.get_fact(server.Hostname)` (actual).
- **sudo/su/doas combos**: applied in order `doas → dzdo → sudo → su`; `_sudo=True,_su_user="pyinfra"` → `sudo su pyinfra ...`. Table: `global-arguments.md`.
- **chmod/chown anything**: `files.file`/`files.directory`/`files.link` with `user/group/mode` — no raw shell.
- **Unreliable network ops**: `_retries/_retry_delay/_retry_until` (see `writing-deploys.md`).
- **Live docs for agents**: `https://docs.pyinfra.com/en/latest/llms.txt` (index ~15 KB) and `llms-full.txt` (~290 KB; hand-written guides + every op/fact/connector docstring & signature). Swap `latest` for `3.x` or a tag (e.g. `v3.3.2`) to pin. Fetch via `power---bash` when these catalogs lack signature-level detail.

## Compatibility & upgrades

Control machine: any Python (macOS/Linux/Windows). Targets: Unix-like with shell access; facts/ops prefer POSIX, so `server`+`files` ops work broadly (developed against Ubuntu 20/22/24, Debian 9/10, Fedora 43, Alpine 3.8, OpenBSD/FreeBSD/NetBSD/HardenedBSD/DragonflyBSD, openSUSE, macOS via `@local`, Docker).

Semver rules: major = breaking (CLI warns on the prior major first); minor = new ops/APIs/global args; patch = new op args, bug fixes.

**2.x → 3.x upgrades** (from the compatibility page):
- Rename `_use_sudo_password` argument to `_sudo_password`
- Deploy decorator must be called: bare `@deploy` → `@deploy()` / `@deploy("Name")`
- `@winrm` connector removed (returns as separate `pyinfra-windows` package)

Older: 1.x→2.x dropped Python 2.7/3.5 ("deploy directory" concept removed → everything runs from CWD, new `--chdir` flag); 0.x→1.x moved `pyinfra.modules` → `pyinfra.operations` and replaced the leading label-set first argument with the `name=` kwarg.

## Install platform notes

- Python **3.10+** required; pyinfra 3.5.1+ supports 3.10–3.13.
- Recommended `uv tool install pyinfra`; also `pipx install pyinfra`, `uv add pyinfra` (project dep), or venv + `pip install pyinfra`; upgrade via `pip install --upgrade pyinfra`.
- **BSD**: gevent must not embed libraries — prefix install with `C_INCLUDE_PATH='/usr/local/include/' GEVENTSETUP_EMBED_CARES=0 GEVENTSETUP_EMBED_LIBEV=0 GEVENTSETUP_EMBED_LIBUV=0` (env vars); system `c-ares`, `libev`, `libuv` still required.
- **Windows (control)**: Python + venv + pip; MSVC/C++ workload only if a dependency needs compiling. `@local` connector itself is macOS/Linux only.
- Docs best practices: isolate in a venv/`uv tool`, install as a regular user, don't mix other projects in the same env.

## Performance notes

Pitch: agent-less, state-managing like Ansible but performing closer to Fabric (ad-hoc execution). Published 2024 benchmark: pyinfra vs Fabric vs Ansible (source: github.com/Fizzadar/pyinfra-performance). Levers: `cache_time` to skip repeated `apt update`, keep default parallelism (bounded by the fd limit), `_serial`/`--parallel` only when ordering or resource limits demand, one SSH connection reused for all ops/facts per host.

## Known upstream docs bugs (found authoring this skill, v3.2–3.5)

- `init.systemd` / `init.service` CLI examples on getting-started & CLI pages — no `init` module exists (`No such module: init`); use `systemd.service` / `server.service`.
- `using-operations` "Output & Callbacks" contains a pseudocode fragment (`def ufw_usable(function code here)`) that is not valid Python.
- `--retry`/`--retry-delay`/`--json` exist only on newer 3.x (not v3.2) — check `pyinfra --help` on the actual control host.
- In `llms-full.txt` the arguments page's `deploy-globals.md` include is left unexpanded; read the rendered `arguments.html` for the tables (mirrored in `global-arguments.md`).
