# Operations: Services & Init Systems

Source: docs.pyinfra.com/en/3.x operation modules (signatures verbatim). Import `from pyinfra.operations import systemd, server, ...`.

## Dispatcher: `server.service`

```py
server.service(service, running=True, restarted=False, reloaded=False,
               command=None, enabled=None)
```

Auto-detects the init system at runtime by looking for `systemctl`, `initctl`, `/etc/init.d`, `/etc/rc.d` — if none found the operation fails with `No init system found (...)` (e.g. on a macOS local target). Use the explicit module when the init system is known.

`running` (start/stop), `enabled` (boot autostart, `None` = don't touch), `restarted`/`reloaded` (trigger now), `command` = arbitrary init action to run (e.g. `"force-reload"`).

## systemd

```py
systemd.service(service, running=True, restarted=False, reloaded=False, command=None,
                enabled=None, daemon_reload=False, user_mode=False, machine=None, user_name=None)
systemd.daemon_reload(user_mode=False, machine=None, user_name=None)
```

- `user_mode=True` → `systemctl --user`; `user_name` → `systemctl --machine <user>@.host`.
- `machine` targets systemd-nspawn/machined containers.
- Pass `daemon_reload=True` on the service op when unit files were just written.

## Other init systems

```py
upstart.service(service, running=True, restarted=False, reloaded=False, command=None, enabled=None)
openrc.service(service, running=True, restarted=False, reloaded=False, command=None,
               enabled=None, runlevel='default')                       # OpenRC systems
sysvinit.service(service, running=True, restarted=False, reloaded=False,
                 enabled=None, command=None)                           # /etc/init.d
sysvinit.enable(service, start_priority=20, stop_priority=80,
                start_levels=(2, 3, 4, 5), stop_levels=(0, 1, 6))      # create rc links first
runit.service(service, running=True, restarted=False, reloaded=False, command=None,
              enabled=None, managed=True, svdir='/var/service', sourcedir='/etc/sv')
runit.auto(service, auto=True, sourcedir='/etc/sv')                    # /etc/service autostart link
runit.manage(service, managed=True, svdir='/var/service', sourcedir='/etc/sv')
runit.wait_runsv(service, svdir='/var/service', timeout=10)            # block until runsv picks it up
launchd.service(service, running=True, restarted=False, command=None)  # macOS
bsdinit.service(service, running=True, restarted=False, reloaded=False, command=None,
                enabled=None)                                          # /etc/rc.d, /usr/local/etc/rc.d
```

`launchd` has no `enabled`/`reloaded` — start/stop/restart only. `runit` "enabled" = symlink presence (`auto`), plus a separate `managed` concept (`svdir`).

## CLI

```sh
pyinfra INV server.service nginx running=true enabled=true _sudo=true
pyinfra INV systemd.service nginx running=true daemon_reload=true _sudo=true
```

## Pitfalls

- **Docs bug**: the getting-started/CLI pages show `pyinfra ... init.systemd httpd running=False _sudo=True` and `init.service nginx ...`. On 3.x (verified on 3.2; still absent from the latest operations index) there is **no `init` module** — CLI fails with `No such module: init`. Use `server.service` (dispatcher) or `systemd.service` (explicit) instead. In Python code, `from pyinfra.operations import init` also raises ImportError.
- Restart/reload flags trigger **on every run** where the op executes — combine with `_if=config_file.did_change` (see `writing-deploys.md`) to restart only after the config actually changed.
- Facts: `systemd.SystemdStatus` / `systemd.SystemdEnabled` back the diff (see `facts.md`).
