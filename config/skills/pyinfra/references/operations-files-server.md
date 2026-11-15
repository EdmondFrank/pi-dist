# Operations: Files, Server, Cron, Firewall, SELinux, SSH, Python

Source: docs.pyinfra.com/en/3.x operations/files, server, crontab, iptables, selinux, ssh, python (signatures verbatim). `from pyinfra.operations import files, server, crontab, iptables, selinux, ssh, python`.

## files.* — filesystem state, uploads, templates

```py
files.file(path, present=True, user=None, group=None, mode=None, touch=False,
           create_remote_dir=True, force=False, force_backup=True, force_backup_dir=None)
files.directory(path, present=True, user=None, group=None, mode=None, recursive=False,
                force=False, force_backup=True, force_backup_dir=None,
                _no_check_owner_mode=False, _no_fail_on_link=False)
files.link(path, target=None, present=True, user=None, group=None, symbolic=True,
           create_remote_dir=True, force=False, force_backup=True, force_backup_dir=None)
files.put(src, dest, user=None, group=None, mode=None, add_deploy_dir=True,
          create_remote_dir=True, force=False, assume_exists=False, atime=None, mtime=None)
files.get(src, dest, add_deploy_dir=True, create_local_dir=False, force=False)   # remote→local
files.sync(src, dest, user=None, group=None, mode=None, dir_mode=None, delete=False,
           exclude=None, exclude_dir=None, add_deploy_dir=True)
files.rsync(src, dest, flags=None)
files.template(src, dest, user=None, group=None, mode=None, create_remote_dir=True,
               jinja_env_kwargs=None, **data)          # Jinja2; extra kwargs = template vars
files.download(src, dest, user=None, group=None, mode=None, cache_time=None, force=False,
               sha384sum=None, sha256sum=None, sha1sum=None, md5sum=None, headers=None,
               insecure=False, proxy=None, limit_rate=None, temp_dir=None,
               extra_curl_args=None, extra_wget_args=None)
files.unarchive(src, dest, remote_src=False, creates=None, extra_opts=None, user=None, group=None)
files.line(path, line, present=True, replace=None, flags=None, backup=False,
           interpolate_variables=False, escape_regex_characters=False, ensure_newline=False,
           extended_regex=False)
files.block(path, content=None, present=True, line=None, backup=False,
            escape_regex_characters=False, try_prevent_shell_expansion=False, before=False,
            after=False, marker=None, begin=None, end=None)   # marker-managed block
files.replace(path, text=None, replace=None, flags=None, backup=False,
              interpolate_variables=False, extended_regex=False, match=None)
files.copy(src, dest, overwrite=False)      # remote→remote
files.move(src, dest, overwrite=False)      # remote→remote
files.flags(path, flags=None, present=True) # BSD file flags
```

Key behaviors:
- `mode` accepts int or str (`"644"`); ownership/mode converge via the `files.File` fact diff.
- `put`/`sync`/`template`/`get` local paths resolve relative to CWD unless absolute (`add_deploy_dir`).
- `force=True` re-copies/re-renders even when content matches — prefer `_if=op.did_change` on a follow-up restart op instead; `force_backup*` controls pre-overwrite backups.
- `files.template` diffs rendered content against the remote file → re-run is a no-op. Pass template variables as extra kwargs (e.g. `db_hostname=db_hostname`).
- `files.block` idempotently manages a delimited region (`begin`/`end`/`marker`); `try_prevent_shell_expansion` for `$`-heavy content.
- Checksums (`sha256sum`...) pin `download` content; `cache_time` skips refetch for N seconds.

## server.* — users, shell, OS state

```py
server.shell(commands)                                   # str or list, imperative, via sh
server.script(src, args=())                              # upload + run a local script
server.script_template(src, args=(), **data)             # Jinja-rendered script
server.user(user, present=True, home=None, shell=None, group=None, groups=None, append=False,
            public_keys=None, delete_keys=False, ensure_home=True, create_home=False,
            system=False, uid=None, comment=None, unique=True, password=None)
server.user_authorized_keys(user, public_keys, group=None, delete_keys=False,
                            authorized_key_directory=None, authorized_key_filename=None)
server.group(group, present=True, system=False, gid=None)
server.hostname(hostname, hostname_file=None)
server.etc_hosts(ip, hostnames=None, present=True, path='/etc/hosts')
server.sysctl(key, value, persist=False, persist_file='/etc/sysctl.conf')
server.security_limit(domain, limit_type, item, value)   # /etc/security/limits.d
server.locale(locale, present=True)
server.timezone(timezone)
server.modprobe(module, present=True, force=False)
server.mount(path, mounted=True, options=None, device=None, fs_type=None)
server.wait(port)                                        # block until TCP port answers
server.kill(pid, signal='TERM')
server.reboot(delay=10, interval=1, reboot_timeout=300)  # waits for host to come back
server.packages(packages, present=True)                  # cross-distro pkg dispatcher
```

- `server.shell(commands=["whoami", "echo $PATH"])` — each string is one command; tune with `_chdir`/`_env`/`_shell_executable` (see `global-arguments.md`).
- `server.script` args pass as positional CLI args to the script; use `script_template` for config-driven values.
- `server.user(public_keys=...)` manages `~/.ssh/authorized_keys` (keys appended; `delete_keys` prunes unknown ones — careful).
- Docs CLI example for fire-and-forget reboot: `server.reboot reboot_timeout=0 delay=0`.

## crontab.crontab — cron entries

```py
crontab.crontab(command, present=True, user=None, cron_name=None,
                minute=None, hour=None, month=None, day_of_week=None, day_of_month=None,
                special_time=None, interpolate_variables=False)
```

Schedule values accept lists/str/int (`minute=[5, 10]`, `"*/30"`); `special_time` for `@daily`/`@reboot`-style entries; `cron_name` labels the entry; `interpolate_variables=True` keeps `$VARS` in the command. Diff fact: `crontab.Crontab(user=...)`.

## iptables / selinux

```py
iptables.chain(chain, present=True, table='filter', policy=None, version=4)  # policy DROP/ACCEPT
iptables.rule(chain, jump, present=True, table='filter', append=True, version=4,
              protocol=None, not_protocol=None, source=None, not_source=None,
              destination=None, not_destination=None, in_interface=None, not_in_interface=None,
              out_interface=None, not_out_interface=None, to_destination=None, to_source=None,
              to_ports=None, log_prefix=None, destination_port=None, source_port=None, extras='')
selinux.boolean(bool_name, value, persistent=False)
selinux.file_context(path, se_type)
selinux.file_context_mapping(target, se_type=None, present=True)
selinux.port(protocol, port_num, se_type=None, present=True)
```

IPv6: `version=6` uses ip6tables (facts `Ip6tablesRules`/`Ip6tablesChains`).

## ssh.* — pull-mode SSH (run from the target *against another host*)

```py
ssh.command(hostname, command, user=None, port=22)
ssh.upload(hostname, filename, remote_filename=None, port=22, user=None,
           use_remote_sudo=False, ssh_keyscan=False)
ssh.download(hostname, filename, local_filename=None, force=False, port=22, user=None,
             ssh_keyscan=False)
ssh.keyscan(hostname, force=False, port=22)
```

These open a fresh ssh client session *from* the inventory host to `hostname` — distinct from pyinfra's own `@ssh` connector (which targets the inventory host itself). Rarely needed; prefer connector + `server.shell`.

## python.call — execute Python at run time

```py
python.call(function, *args, **kwargs)      # runs during execute phase (see callbacks)
python.raise_exception(exception, *args, **kwargs)
```

`function` may read `OperationMeta.stdout` and schedule further operations (those execute immediately) — the standard place for output-driven logic (see `writing-deploys.md` → Output & Callbacks).
