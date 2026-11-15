# Using the CLI

Source: docs.pyinfra.com/en/3.x/cli.html. Shape: `pyinfra [OPTIONS] INVENTORY OPERATIONS...`

## INVENTORY argument forms

- File: `inventory.py` (or any Python inventory, incl. `inventories/prod.py`, or a function/module attribute — see `inventory-data.md`)
- Hostname(s): `my-server.net,my-other-server.net`
- Connector targets: `@local`, `@docker/fedora:43`, combos: `my-server.net,@local`

## OPERATIONS argument forms (verbs)

```sh
pyinfra INVENTORY deploy_web.py [deploy_db.py]...        # one or more deploy files
pyinfra INVENTORY server.user pyinfra home=/home/pyinfra # single builtin op, positional args + k=v
pyinfra INVENTORY exec -- my_command --some-arg           # raw shell (anything after -- passes through)
pyinfra INVENTORY fact server.LinuxName [server.Users]    # read facts (with args: fact files.File path=/x)
pyinfra INVENTORY debug-inventory                         # print hosts/groups/data
```

Ad-hoc builtin-op examples (state definitions):

```sh
pyinfra my-server.net dnf.packages vim
pyinfra my-server.net systemd.service httpd running=False _sudo=True   # (docs show init.systemd — stale, see note below)
pyinfra inventory.py apt.packages nginx update=true _sudo=true
pyinfra inventory.py yum.packages nginx _sudo=true
pyinfra inventory.py server.service nginx running=true enabled=true    # generic init-system dispatcher
pyinfra inventory.py server.reboot reboot_timeout=0 delay=0
pyinfra inventory.py exec -- reboot
```

Docs bug: getting-started/CLI pages still show `init.systemd` / `init.service`; 3.x has no `init` module (`No such module: init`) — use `server.service` or `systemd.service` (see `operations-services.md`).

Real-time streaming output for debugging distributed services:

```sh
pyinfra inventory.py exec --sudo -- tail -f /var/log/elasticsearch/elasticsearch.log
```

## Verbosity ladder

- (default) high level only: connect, op start
- `-v` — also facts collected + noop info ("package X already installed")
- `-vv` — also the shell input sent to hosts (the literal commands)
- `-vvv` — also shell output from hosts as it runs

## Debug / plan flags

| Flag | Effect |
|---|---|
| `--debug` | pyinfra internal debug messages |
| `--debug-facts` | print gathered facts after generating ops, then exit |
| `--debug-operations` | print operation order + metadata, then exit (no connect) |
| `--dry` | connect + gather facts + report proposed changes; mutate nothing |
| `--yes` | apply without the interactive confirm prompt (needed with `--json` to actually deploy) |

Note: `--debug-operations`/`--dry` show *which* ops change *which* hosts, not literal commands (those exist only at execute time; use `-vv`).

## Host targeting

```sh
pyinfra inventory.py deploy.py --limit @local            # by host name, group name, or glob "db*"
pyinfra inventory.py deploy.py --limit app_servers --limit db-1.net   # repeatable
pyinfra inventory.py deploy.py --exclude "db*"           # repeatable; applied AFTER --limit
pyinfra inventory.py deploy.py --limit app_servers --exclude app-2.net
```

## Connection options (CLI counterparts of ssh_* data)

```sh
pyinfra localhost --ssh-port 2222 --ssh-user vagrant exec -- echo "hello world"
pyinfra @podmanssh/production-server:alpine:3.18 --sudo --port 2222 operations/
```

Other flags: `--chdir TEXT` (working dir before executing — resolves `group_data/`, template paths), `--group-data PATH` (additional group data, overrides matching keys), `--config FILE` (config file, default `config.py`), `--data key=value` (override inventory data; highest data priority), `--fail-percent N` (% hosts failing before exiting early), `--no-wait` (don't wait between operations).

Global-arg shortcuts on the CLI: `--sudo`, `--sudo-user`, `--su-user`, `--use-sudo-password`, `--shell-executable`, `--parallel N`, `--serial`, plus `--debug-all`.

## Version note

`--retry/--retry-delay` and `--json` are documented on current 3.x (3.5+) but absent from e.g. v3.2 (`pyinfra --help` is the arbiter). On older installs use per-op `_retries=` and parse `-vvv` output instead.

## Retry options

```sh
pyinfra inventory.py deploy.py --retry 3                 # up to 3 retries, 5s delay default
pyinfra inventory.py deploy.py --retry 2 --retry-delay 10
```

## JSON output (`--json`)

Machine-readable stdout instead of the pretty printer; works with `debug-inventory`, `fact`, `--debug-operations`, `--dry`, and real deploys.

```sh
pyinfra inventory.py debug-inventory --json
pyinfra inventory.py fact server.LinuxName --json
pyinfra inventory.py deploy.py --json                    # PLAN only (no apply)
pyinfra inventory.py deploy.py --dry --json
pyinfra inventory.py deploy.py --json --yes              # apply + emit results
```

Non-interactive behavior: `--json` alone never mutates (plan + exit unless `--yes`); connection-failure prompts skipped (run fails instead); spinner disabled (`PYINFRA_PROGRESS=off`). Caveats: inventory `data` is serialized as-is → non-JSON types (sets, datetimes, custom objects) crash the command — keep data JSON-friendly; logs/errors still on stderr → `pyinfra ... --json 2>/dev/null > out.json`; `input()` in deploy code still blocks.

## Shell autocompletion

```sh
env _PYINFRA_COMPLETE=bash_source pyinfra > pyinfra-complete.sh   # then: source in ~/.bash_profile
env _PYINFRA_COMPLETE=zsh_source  pyinfra > pyinfra-complete.zsh
```

## Help / support

`pyinfra --support` prints environment info to attach to bug reports (see `troubleshooting.md`).
