# Custom Operations, Facts, Connectors & Programmatic API

Source: docs.pyinfra.com/en/3.x api/* pages. v3 API is "mostly stable". The internal `api/reference` carries no compat guarantees — expect breaking changes on non-major versions.

## Writing an operation

Operations are Python generator functions decorated with `@operation()`; they read facts, diff, and `yield` commands. Args starting `_` and `name` are reserved.

```py
from pyinfra import host
from pyinfra.api import OperationError, QuoteString, StringCommand, operation
from pyinfra.facts.files import File

@operation()
def file(path: str, present: bool = True):
    '''
    Manage the state of files.

    + path: name/path of the remote file
    + present: whether the file should exist
    '''
    info = host.get_fact(File, path=path)

    if info is False:                              # exists but not a file
        raise OperationError(f"{path} exists and is not a file")
    if info is None and present:
        yield StringCommand("touch", QuoteString(path))
    elif info and not present:
        yield StringCommand("rm", "-f", QuoteString(path))
```

- Command primitives: `StringCommand(*args)` (or plain str), `FileUploadCommand(local, remote)`, `FileDownloadCommand(remote, local)`, `FunctionCommand(fn, args, kwargs)`; per-command global overrides: `StringCommand("echo", "x", _sudo=True)`.
- **Security rule (from docs)**: never build shell commands with plain string formatting/f-strings containing user-supplied values — wrap every interpolated argument in `QuoteString` (paths, names, even integers) and compose with `StringCommand`, or you invite shell injection.
- Compose other operations: `yield from files.file._inner(path=..., ...)` — operation args only; global args like `_sudo` are NOT accepted there.
- In-tree contributions must be registered in `pyinfra-metadata.toml` (repo root) with `type = "operation"` + tags, or docs won't list them; external packages don't need this file.

## Writing a fact

Class with `command` (str attribute, or method when the fact takes args) + `process(output_lines)`; optional `default()` used when collection errors:

```py
from pyinfra.api import FactBase

class SwapEnabled(FactBase):
    command = 'swapon --show'
    def process(self, output):
        return len(output) > 0          # any lines → swap on

class FindFiles(FactBase):
    def command(self, path):
        return 'find {0} -type f'.format(path)
    def process(self, output):
        return output                    # list of lines
```

Use: `host.get_fact(SwapEnabled)`, `host.get_fact(FindFiles, path='/somewhere')`.

- **`FactBase`** vs **`ShortFactBase`**: the latter derives a view over another fact (`fact = LinuxDistribution`, `process_data(data) -> data["name"]`) — runs no command, shares the cached result, costs nothing at runtime.
- `requires_command()` → declare a needed binary; when absent pyinfra emits a sentinel and internally raises `MissingCommandError`. Phase-aware: prepare → silent `default()`; execute v3 → warning + `default()`; execute v4 → raises (flags deploy mis-ordering).
- `check_preconditions(state, host)` → return `None` (OK) or a `"reason"` string; framework raises `FactPreconditionError` with the same phase behavior.
- Hierarchy (all exported from `pyinfra.api`): `FactError → FactNotCollected → {MissingCommandError, FactPreconditionError}`.

## Writing a connector

Subclass `pyinfra.connectors.base.BaseConnector`; three shapes: inventory-only (`handles_execution = False`, just `make_names_data`), execution-only, or both.

```py
class InventoryConnector(BaseConnector):
    handles_execution = False

    @staticmethod
    def make_names_data(_=None):        # yields (name, data, groups) tuples
        yield ('foundhost', {'ip': '198.51.100.4'}, ['remote'])
```

Invoke via `pyinfra @custom[/name] deploy.py`; with a `/name` suffix `make_names_data(name)` receives the string (handle the `None` = whole-inventory case yourself). `make_names_data` is a staticmethod — configure through class attributes (`getattr(Cls, 'api_instance')`) or module-level functions, not `self`.

Execution methods: `run_shell_command(command, print_output, print_input, **arguments) -> (bool, CommandOutput)`, `put_file(...)`, `get_file(...)`, optional `connect()` (raise `ConnectError` on failure) / `disconnect()` (never fails).

- In `run_shell_command`, wrap commands with `make_unix_command_for_host(state, host, command, **arguments)` from `pyinfra.connectors.util` (shell wrapping, sudo elevation, env, chdir, retries, shell executable). First call `extract_control_arguments(arguments)` to strip connector-only params (`_success_exit_codes`, `_timeout`, `_get_pty`, `_stdin`) — they're for post-generation execution logic, not command construction. Without proper wrapping `&&`/`||`/pipes break (`timeout 60 bash -c 'cmd' || true` → `bash: ||: command not found`).
- Register via entry point in your package's `pyproject.toml`:

```toml
[project.entry-points.'pyinfra.connectors']
custom = 'pyinfra_custom_connector.connector:LoggingConnector'
```

- Upstream policy: new connectors are **not merged into pyinfra** — ship as separate installable packages; docs-link PRs welcome.

## Packaging a deploy (`@deploy`)

Wrap operation sequences in a function for reuse/PyPI distribution:

```py
from pyinfra.api import deploy
from pyinfra.operations import apt

@deploy("Install MariaDB")                      # 3.x: the decorator is CALLED
def install_mariadb():
    apt.packages(name="Install MariaDB apt package", packages=["mariadb-server"])
```

- Consumers: `from packaged_deploy import install_mariadb; install_mariadb()` — deploys accept the same global arguments as operations (`install_mariadb(sudo=True)` in docs), applying to every inner op.
- Overridable defaults: `@deploy("Install mariadb", data_defaults={"mariadb_version": "1.2.3"})`, read via `host.data.mariadb_version`; user host/group data with the same key wins.
- Reference packages: pyinfra-docker (no args), pyinfra-prometheus (multi-deploy with exporters).

## Programmatic API (using pyinfra as a library)

Same five stages, driven manually:

```python
from pyinfra.api import Config, Inventory, State
from pyinfra.api.connect import connect_all
from pyinfra.api.operation import add_op
from pyinfra.api.operations import run_ops
from pyinfra.api.facts import get_facts
from pyinfra.facts.server import Os
from pyinfra.operations import server

inventory = Inventory((["@local"], {}))          # (hosts, group_data)
config = Config(SUDO=True)
state = State(inventory=inventory, config=config)
connect_all(state)

op1 = add_op(state, server.user, user="pyinfra", home="/home/pyinfra", shell="/bin/bash")
op2 = add_op(state, server.shell, name="Run some shell commands",
             commands=["whoami", "echo $PATH", "bash --version"])
run_ops(state)

host = inventory.get_host('@local')
print(op1[host].did_change, op1[host].stdout, op1[host].stderr)   # add_op → {host: OperationMeta}
print(get_facts(state, Os))                                       # {host: value}
```

- `add_op` is **API-mode only** — raises inside a CLI deploy (there you call `apt.packages(...)` directly; the wrapper schedules internally).
- No manual `state.current_stage` juggling: stage-transition guards fire only when `pyinfra.is_cli` (CLI sets it); `add_op` handles `ctx_state`/`ctx_host` bookkeeping.
- Keep the `inventory` handle for lookups: `inventory.get_host(name)` → index into an `add_op` result.

### Observing a run (telemetry hooks)

```python
import time
from pyinfra.api import BaseStateCallback

class TimingCallback(BaseStateCallback):
    def __init__(self): self.timings = {}
    def operation_host_start(self, state, host, op_hash):
        self.timings.setdefault(op_hash, {})[host] = {"start": time.monotonic()}
    def operation_host_success(self, state, host, op_hash, retry_count=0):
        self.timings[op_hash][host]["end"] = time.monotonic()
    def operation_host_error(self, state, host, op_hash, retry_count=0, max_retries=0):
        self.timings[op_hash][host]["error"] = True

state.add_callback_handler(TimingCallback())
run_ops(state)
```

Hooks cover host connect/disconnect, operation start/end, per-host start/success/error/retry — telemetry/custom progress without writing your own scheduler.

## Testing third-party ops/facts

The declarative style behind pyinfra's own fact/op tests is externalized in the **pyinfra-testing harness** (github.com/pyinfra-dev/pyinfra-testing). In-tree: `scripts/dev-test.sh`, `uv run pytest tests/test_facts.py -k "efibootmgr.EFIBootMGR"`, `uv run pytest tests/test_operations.py -k "selinux."`; e2e markers `-m end_to_end_local|ssh|docker`. Combine `@fake` + function-based inventories for dependency-free unit tests (`connectors.md`, `inventory-data.md`).
