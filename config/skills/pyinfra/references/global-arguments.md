# Global Arguments

Source: docs.pyinfra.com/en/3.x/arguments.html (include `deploy-globals.md`). Available on **all facts, operations and deploys**. All prefixed `_` (except `name`) to avoid clashes with operation args. Defaults may come from three places (highest first): per-call kwarg → inventory data (`_sudo = True` in `group_data/`) → `config.SUDO = True`.

## Privilege & user escalation

Order applied when combined: **`doas` → `dzdo` → `sudo` → `su`** — e.g. `_sudo=True, _su_user="pyinfra"` yields `sudo su pyinfra ...`.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `_sudo` | bool | `False` | Execute/apply changes with sudo |
| `_sudo_user` | str | | sudo to a non-root user |
| `_use_sudo_login` | bool | `False` | sudo via login shell |
| `_sudo_password` | str | | password for sudo (renamed from `_use_sudo_password` in 3.x); prompted for if needed & unset |
| `_preserve_sudo_env` | bool | `False` | keep connecting user's env under sudo |
| `_su_user` | str | | run via `su` as this user |
| `_use_su_login` | bool | `False` | su with login shell |
| `_preserve_su_env` | bool | `False` | keep env under su |
| `_su_shell` | str | | shell used for `su` (Linux only; for users with nologin shells) |
| `_su_password` | str | | password for su |
| `_doas` | bool | `False` | use doas (BSD) |
| `_doas_user` | str | | doas to non-root user |
| `_dzdo` | bool | `False` | use dzdo (CentOS/PowerBroker) |
| `_dzdo_user` | str | | dzdo to non-root user |

```python
server.user(name="Create pyinfra user using sudo", user="pyinfra",
            _sudo=True, _sudo_password="my-secret-password")
```

## Shell control & features

| Key | Type | Default | Meaning |
|---|---|---|---|
| `_shell_executable` | str | `sh` | shell used to execute commands (POSIX by default; `"bash -l"` for bashisms/login) |
| `_chdir` | str | | cd before executing |
| `_env` | Mapping[str, Union] | `{}` | env vars to set for the command |
| `_success_exit_codes` | Iterable[int] | `[0]` | exit codes treated as success |
| `_timeout` | int | | timeout **per command** within the operation |
| `_get_pty` | bool | `False` | request a pseudo-TTY |
| `_stdin` | str/list/Iterable | | piped to command stdin |
| `_temp_dir` | str | | remote temp dir for file ops (else `TMPDIR`, else `/tmp`) |

```python
server.shell(name="Bootstrap nginx params",
             commands=["openssl dhparam -out dhparam.pem 4096"],
             _chdir="/etc/ssl/certs")
```

## Operation meta & callbacks

| Key | Type | Default | Meaning |
|---|---|---|---|
| `name` | str | | human label for output + ordering (no behavior effect; auto-generated if omitted) |
| `_ignore_errors` | bool | `False` | failure doesn't mark host failed (also usable on `get_fact`) |
| `_continue_on_error` | bool | `False` | keep running remaining commands after an error; only when `_ignore_errors=True` |
| `_if` | list/Callable/None | `[]` | run only if callables return True **at execute time** |

`_if` accepts a callable, list of callables (AND), or lambdas combining `OperationMeta` helpers (`did_change`, `did_not_change`, `did_succeed`, `did_error`) / `any_changed` / `all_changed`. Non-callable → `ArgumentTypeError`; `None` → always run. Full examples: `writing-deploys.md`.

## Execution strategy

Default: every operation on **all hosts in parallel**, capped by the open-file-descriptor limit. The three keys below are **mutually exclusive per operation** and must evaluate to the same value on every host.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `_parallel` | int | `0` | max hosts at once for this op; `0` = global `config.PARALLEL` (all hosts) |
| `_run_once` | bool | `False` | execute only on the first host that reaches the op |
| `_serial` | bool | `False` | host-by-host, no parallelism |

## Retry behavior

| Key | Type | Default | Meaning |
|---|---|---|---|
| `_retries` | int | `0` | retry failed operation up to N times |
| `_retry_delay` | int/float | `5` | seconds between attempts |
| `_retry_until` | Callable[[dict], bool] | | given output data (`stderr_lines`, ...), return True to keep retrying |

CLI-wide equivalents: `--retry N`, `--retry-delay S` (see `cli.md`). Code examples: `writing-deploys.md`.

## Related config keys (ConfigDefaults, pyinfra 3.2)

Deploy-wide defaults on `config.*` (uppercase mirror of `_args`): `FAIL_PERCENT` (% host failures that stop all ops; default None), `CONNECT_TIMEOUT=10` s, `TEMP_DIR=None`/`DEFAULT_TEMP_DIR="/tmp"`, `PARALLEL=0` (gevent pool, default = #hosts), `REQUIRE_PYINFRA_VERSION`, `REQUIRE_PACKAGES`, `SUDO/SUDO_USER/USE_SUDO_LOGIN/PRESERVE_SUDO_ENV/SUDO_PASSWORD`, `SU_USER/USE_SU_LOGIN/SU_SHELL/PRESERVE_SU_ENV`, `DOAS/DOAS_USER`, `IGNORE_ERRORS`, `SHELL="sh"`, plus `ENV` / `INHERIT_ENV` (see `inventory-data.md`).

## Ad-hoc CLI mapping

Global args pass as `_key=value` tokens on the CLI:

```sh
pyinfra inventory.py apt.packages nginx update=true _sudo=true
pyinfra inventory.py systemd.service httpd running=False _sudo=True
pyinfra inventory.py exec --sudo -- tail -f /var/log/app.log   # exec has its own --sudo flag
```
