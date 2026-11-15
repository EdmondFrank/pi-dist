---
name: pyinfra
description: "Run pyinfra deploys: inventories, ops, facts, CLI."
---

# pyinfra Infrastructure Automation

Turns Python code into shell commands run against SSH, local, Docker, Podman, chroot, and Terraform/Vagrant targets: declarative operations diff gathered facts against desired state and emit only reconciling commands. Covers writing inventories/deploys, global arguments, the CLI, the built-in operation/fact/connector catalogs, and the programmatic API. Does NOT cover pyinfra 2.x syntax (see upgrade notes in `references/troubleshooting.md`) or Windows targets (`@winrm` was removed in 3.x).

## When to Use

- "Install/configure something on N remote servers from Python" / replace an ad-hoc Ansible playbook
- Trigger phrases: pyinfra, `pyinfra inventory.py deploy.py`, ad-hoc `pyinfra ... exec --`, `@docker/ubuntu` test deploys, `--dry` plan, operations/facts/connectors, `apt.packages`, `files.template`, `server.service`, `_sudo`
- Debugging: cycle errors, unexpected re-runs with changes, facts that look stale

## Core Model (always applies)

- **You need exactly two inputs**: an INVENTORY (hosts/groups/data) and OPERATIONS (deploy `.py` files or CLI ops). CLI order is always `pyinfra INVENTORY OPERATIONS...`.
- **Declarative vs imperative**: declarative ops (`apt.packages`, `files.file`, `server.user`) read a fact → diff → emit only converging commands, so re-runs are no-ops; imperative ops (`server.shell`, `server.script`, `python.call`) always execute.
- **Two-phase execution**: *prepare* runs your deploy code once per host (reads facts, decides order + `will_change`; **no mutating commands**), then *execute* re-evaluates each operation and runs its commands on all hosts, operation-by-operation in lock-step.
- **Consequence — golden rule**: deploy Python runs *before any host changes*. Branching on a *mutable* fact (`if host.get_fact(File, ...):`) or on `op.changed` sees **pre-deploy** state. Gate at execute time with `_if=op.did_change` instead. Branch only on immutable facts (OS, distro, arch, kernel).
- **Every operation call returns `OperationMeta`** with `did_change` / `did_not_change` / `did_succeed` / `did_error` callables (for `_if`) and post-execution `stdout`/`stderr` (read only inside a `python.call` callback).
- **Global arguments** (`_sudo`, `_env`, `_serial`, `_retries`, ...) are available on every operation, fact, and deploy; they can also come from inventory data (`_sudo = True` in `group_data`) or `config.SUDO = True`. Precedence: per-op kwarg > host data > group data > `all` data > config default.
- **Operations run once per host, parallel by default**, capped by the fd limit; use `_serial`, `_parallel=N`, `_run_once` (mutually exclusive) to change strategy.
- **Ordering in loops**: iterate with `host.loop(range(...))` when a loop contains operations, otherwise per-host orderings can conflict and pyinfra raises a cycle error.
- **Safety flow**: `--debug-operations` (plan order, no connect) → `--dry` (connect + facts + diff report, no changes) → real run; `-vv` shows the literal shell sent.

## Prerequisites

- Python 3.10+ on the control machine (pyinfra 3.5.1+ supports 3.10–3.13); targets need only shell access.
- Install: `uv tool install pyinfra` (or `pipx install pyinfra`, `uv add pyinfra`, `pip install pyinfra`). Verify: `pyinfra --version` (local docs learned against v3.2–3.5).
- SSH: pyinfra reuses your SSH config/keys/agent — if plain `ssh` works, it works.
- `@local` connector: macOS & Linux control hosts only. BSD installs need `GEVENTSETUP_EMBED_*=0` env (see `references/troubleshooting.md`).

## How to Run

Invoke through the `power---bash` tool:

```sh
pyinfra inventory.py deploy.py              # apply a committed deploy
pyinfra my-server.net exec -- uptime        # ad-hoc over SSH
pyinfra @docker/ubuntu:22.04 deploy.py      # fast local test loop
pyinfra inventory.py deploy.py --dry        # preview changes, mutate nothing
pyinfra inventory.py fact server.LinuxName  # read one fact
```

For verbatim signatures beyond the catalogs below, pull the machine-readable docs: `curl -s https://docs.pyinfra.com/en/3.x/llms.txt` (index) or `.../llms-full.txt` (~300 KB, every op/fact/connector docstring + signature).

## Quick Reference

| Task | Command / call |
|---|---|
| Install pkg (Ubuntu/Debian) | `pyinfra INV apt.packages vim update=true _sudo=true` |
| Install pkg (RHEL-family) | `pyinfra INV dnf.packages vim _sudo=true` |
| Manage service | `pyinfra INV server.service nginx running=true enabled=true _sudo=true` |
| Explicit init-system service op | `pyinfra INV systemd.service httpd running=False _sudo=True` (docs' `init.systemd` examples are stale — no `init` module in 3.x) |
| Reboot | `pyinfra INV server.reboot reboot_timeout=0 delay=0` |
| Show inventory debug | `pyinfra INV debug-inventory [--json]` |
| Limit hosts / exclude | `--limit "db*"` / `--exclude app-2.net` (repeatable) |
| Machine-readable output | `--json` (non-interactive; add `--yes` to actually apply) |
| Retries | `--retry 3 [--retry-delay 10]` |
| Show shell commands as run | `-vv` (facts `-v`, output `-vvv`) |
| Plan without connect | `--debug-operations`; with facts: `--debug-facts`, `--dry` |

## Procedure

1. Scaffold (optional layout, all names conventional only): `inventory.py`, `group_data/all.py`, `deploy.py`, `tasks/`, `templates/`. Write these with `power---file_write`.
2. Define groups in `inventory.py` — each top-level list/tuple is a group; `(host, {data})` tuples carry host data; host names like `"@docker/ubuntu:22.04"` are valid. Load `references/inventory-data.md` for formats, `group_data/`, data hierarchy.
3. Write `deploy.py` importing `from pyinfra.operations import apt, files, server` and calling declarative ops with `name=` labels. Load `references/writing-deploys.md` for `host`/`inventory`/`config` objects, `_if` gating, includes, callbacks.
4. Set privileges per op (`_sudo=True`) or deploy-wide (`config.SUDO = True`); full table in `references/global-arguments.md`.
5. Preview: run `--debug-operations`, then `--dry` via `power---bash`; inspect the change report; then apply without flags. Confirm with a second `--dry` (expect "Ready: 0 changes").
6. For anything the catalogs don't cover — exact args of `files.template`, a fact's return shape, connector data keys, custom op/fact/connector classes — load the matching file from the Reference Index below, then verify against upstream `llms-full.txt`.

## Pitfalls (top hits — more in `references/troubleshooting.md`)

- `if op.changed:` / branching on mutable facts in deploy code → always wrong; use `_if=op.did_change` (prepare-phase evaluation).
- `_if` must be callable(s): `_if=host.get_fact(...)` raises `ArgumentTypeError` (and `None` means "always run"). Wrap in `lambda:`.
- `result.stdout` raises before execution; read it inside a `python.call(...)` callback.
- `@docker/IMAGE` creates a *new* container every run — "always changes" is expected, not a bug. Reuse `@docker/CONTAINERID` to test idempotency.
- Default shell is POSIX `sh`, not bash — use `_shell_executable="bash -l"` for bashisms.
- A failing fact marks the host failed — pass `_ignore_errors=True` to `get_fact` when absence is OK.
- Escalation order matters: `doas → dzdo → sudo → su` (e.g. `_sudo=True, _su_user="x"` → `sudo su x`).

## Reference Index — load one on demand (each costs nothing until needed)

- `references/deploy-process.md` — the 5 stages, prepare/execute phases, operation ordering/lock-step, `host.loop` cycle errors, why callbacks exist.
- `references/writing-deploys.md` — operation calls, `host`/`inventory`/`config`/`local.include`, change detection, output callbacks, retries, requirements enforcement.
- `references/inventory-data.md` — inventory files, groups, host/group data, `group_data/`, data hierarchy, function-based inventories (alpha), project layout, `INHERIT_ENV`.
- `references/global-arguments.md` — every `_arg`: privilege escalation, shell control, meta/callbacks, execution strategy, retry behavior.
- `references/cli.md` — full CLI: verbs, options, verbosity, limit/exclude, JSON output, autocompletion.
- `references/operations-packages.md` — package-manager ops with signatures (apt, dnf, yum, apk, pacman, zypper, xbps, pkg, pkgin, opkg, snap, flatpak, choco, brew, pip, pipx, uv, npm, gem, cargo, go, `server.packages`).
- `references/operations-services.md` — service ops (systemd, upstart, openrc, sysvinit, runit, launchd, bsdinit, `server.service`, `systemd.daemon_reload`).
- `references/operations-files-server.md` — `files.*` (file/directory/link/template/put/get/download/block/line/replace/sync), `server.*` (user/group/shell/script/reboot/sysctl/hostname/cron via `crontab`), iptables, selinux, `ssh.*`, `python.call`.
- `references/operations-applications.md` — `docker.*` (incl. compose), `git.*`, `mysql.*`, `postgres*.*`, `zfs.*`, `lxd`, `vzctl`.
- `references/facts.md` — using facts in deploys/CLI + full catalog of fact classes by module, notable return shapes.
- `references/connectors.md` — `@ssh` (all `ssh_*` data keys), `@local`, `@docker`/`@podman`, `@dockerssh`/`@podmanssh` (beta), `@chroot`, `@fake` (scripted responses for tests), `@terraform`, `@vagrant`.
- `references/custom-api.md` — write custom operations (`@operation`, `StringCommand`/`QuoteString`), facts (`FactBase`/`ShortFactBase`, `requires_command`), connectors, packageable `@deploy` functions, and the programmatic Python API (`Inventory`/`State`/`add_op`/`run_ops`/`get_facts`, callbacks).
- `references/troubleshooting.md` — debugging loop, FAQ answers, performance notes, compatibility & 2.x→3.x upgrade renames, BSD/Windows install quirks.

## Verification

```sh
pyinfra @local exec -- echo "pyinfra ok"
pyinfra @local debug-inventory
```

Expected: the first prints a results table with `server.shell` succeeding on `@local` (1 Success); the second prints the resolved host without prompting. If `pyinfra --version` errors, install per Prerequisites first. (Avoid `--json` unless `pyinfra --help` confirms it exists — newer 3.x only.)
