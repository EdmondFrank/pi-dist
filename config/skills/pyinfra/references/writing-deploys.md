# Writing Deploys (Operations in Python)

Source: docs.pyinfra.com/en/3.x/using-operations.html. A deploy = any `.py` file listing operation calls; run with `pyinfra inventory.py deploy.py`. Filenames are convention; CLI args are positional.

## Operation call anatomy

```python
from pyinfra.operations import server, files

server.user(
    name="Create pyinfra user",          # label only — output + ordering, never behavior
    user="pyinfra",                        # op-specific args
    home="/home/pyinfra",
    _sudo=True,                            # global args (see global-arguments.md)
)
```

- `name` is a human-readable label (CLI output + identifies the op in the order). Omit → pyinfra generates one from the call signature.
- Declarative ops (`apt.packages`, `files.file`, `server.user`) converge state; imperative ops (`server.shell(commands=[...])`, `server.script`, `python.call`) always run.
- Example: `server.user(user="pyinfra", home="/home/pyinfra")` generates `useradd -d /home/pyinfra -m pyinfra` on a missing user, and *nothing* on re-run (the `server.Users` fact reports it exists).

## The context objects

```python
from pyinfra import host, inventory, config, local, logger
```

### `host` — current host context (deploy code runs once per host)
- `host.name` — name as defined in inventory (e.g. `"control-plane-1"`); actual OS hostname needs the `server.Hostname` fact.
- `host.groups` — list membership: `if "control-plane" in host.groups:`
- `host.data` — inventory data: `server.user(user=host.data.app_user, home=host.data.app_dir)`; use `host.data.get("key")` for optional keys. Can be mutated mid-deploy: `host.data._sudo_user = "apache"`.
- `host.get_fact(FactClass, **args)` — read facts; see `facts.md`. Add `_ignore_errors=True` when a failing fact command must not fail the host.

### `inventory` — cross-host access
```python
from pyinfra.facts.server import Hostname
db_host = inventory.get_host("postgres-main")
db_hostname = db_host.get_fact(Hostname)      # e.g. into files.template(..., db_hostname=db_hostname)
```

### `config` — deploy-wide defaults for global args
```python
config.SUDO = True        # all ops below use sudo unless _sudo=False
# also: SU_USER, REQUIRE_PYINFRA_VERSION, connection timeouts, ...
```
Three tiers: `config.X` = deploy-wide default → per-op kwarg (`_sudo=False`) overrides for one call → plain Python vars are just constants (use host/group data for per-host values).

### `local.include` — split deploys across files
```python
from pyinfra import local
local.include("tasks/install_something.py")
local.include("tasks/create_user.py", data={"group": "admin", "user": "Bob"})  # data lands in host.data
```
`tasks/` path is convention only. Inside the included file, read params via `host.data.get("group")`.

## Change detection & `_if` (execute-time gating)

Every call returns `OperationMeta`. Prepare-phase truth: `will_change`. Execute-phase: `did_change` / `did_not_change` / `did_succeed` / `did_error` (callables), plus `stdout`, `stderr`, `stdout_lines`, `stderr_lines` (only after execution — read in callbacks).

```python
create_user = server.user(...)
create_otheruser = server.user(...)

server.shell(commands=["..."], _if=create_user.did_change)                 # gate on one
server.shell(commands=["..."], _if=[create_user.did_change,
                                    create_otheruser.did_change])           # list = AND
server.shell(commands=["..."],
             _if=lambda: create_user.did_change() or create_otheruser.did_change())  # OR via lambda

from pyinfra.operations.util import any_changed, all_changed
server.shell(commands=["..."], _if=any_changed(create_user, create_otheruser))
server.shell(commands=["..."], _if=all_changed(create_user, create_otheruser))
```

Gotchas: `_if` must be callable or list of callables; `_if=<fact value>` raises `ArgumentTypeError` at prepare; `_if=None` = no condition (always run). To gate on a fact: `_if=lambda: bool(host.get_fact(MyFact))`.

## Output & callbacks

```python
from pyinfra import logger
from pyinfra.operations import python, server

result = server.shell(commands=["echo output"])
# result.stdout HERE would raise — op hasn't executed yet

def callback():
    logger.info(f"Got result: {result.stdout}")   # works: runs at execute time

python.call(name="Execute callback function", function=callback)
```

Callbacks may call other operations — those run immediately. Prefer `logger` for prepare-phase value inspection (see `troubleshooting.md` for the debugging loop).

## Retries (per operation)

```python
server.shell(commands=["curl -o ..."], _retries=3)                    # default 5s delay
server.shell(commands=["systemctl is-active svc"], _retries=2, _retry_delay=10)

def retry_on_network_error(output_data):        # receives {"stderr_lines": [...], ...}
    return any(k in " ".join(output_data["stderr_lines"]).lower()
               for k in ["network", "timeout", "connection"])
server.shell(commands=["wget ..."], _retries=5, _retry_until=retry_on_network_error)
```

CLI equivalents: `--retry N --retry-delay S` (see `cli.md`).

## Requirements enforcement

```python
config.REQUIRE_PYINFRA_VERSION = "~=3.0"
config.REQUIRE_PACKAGES = "requirements.txt"        # path relative to CWD, or:
config.REQUIRE_PACKAGES = ["pyinfra~=3.0"]
```
Ship as a `requirements.py` and `local.include("requirements.py")` at the top of deploys.

## Shell default warning

Commands run through the configured shell, default `sh` (POSIX). For bash syntax: `_shell_executable="bash -l"` per operation.

## Facts in deploy code

Import from `pyinfra.facts.*` (e.g. `from pyinfra.facts.server import LinuxName`). Distro-switch pattern:

```python
if host.get_fact(LinuxName) == "Fedora":
    yum.packages(name="Install nano via yum", packages=["nano"], _sudo=True)
if host.get_fact(LinuxName) == "Ubuntu":
    apt.packages(name="Install nano via apt", packages=["nano"], update=True, _sudo=True)
```

Immutable-vs-mutable rule + prepare-phase timing: see `deploy-process.md`.

## Where examples live

- Repo: github.com/pyinfra-dev/pyinfra-examples ("groups & roles" style via `local.include` + data).
- Reusable, shared deploys: wrap in `@deploy("Name")` and ship as a package — `custom-api.md`.
