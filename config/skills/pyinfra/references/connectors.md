# Connectors — execution backends

Source: docs.pyinfra.com/en/3.x connectors pages. Connector selection is part of the host string: `pyinfra @docker/ubuntu:22.04 ...`. Bare hostnames default to `@ssh` (`pyinfra my-host.net ...` ≡ `pyinfra @ssh/my-host.net ...`). Comma-separate to mix targets: `host-1.net,@local,@docker/alpine:3.8`.

## @ssh (default)

Uses your SSH config, keys, and agent — if plain `ssh` works, pyinfra works. Configure per host/group data (keys also exist as CLI flags `--ssh-user/--user`, `--ssh-port/--port`, `--ssh-key/--key`, `--ssh-key-password/--key-password`, `--ssh-password/--password`):

```python
# group_data/all.py
ssh_user = "ubuntu"
ssh_key = "~/.ssh/some_key"
ssh_key_password = "password for key"
ssh_port = 22
ssh_hostname = "localhost"        # actual address to dial, vs host name
```

Full key set (from `pyinfra.connectors.ssh`, v3.2): `ssh_hostname, ssh_port, ssh_user, ssh_password, ssh_key, ssh_key_password, ssh_config, ssh_config_file, ssh_known_hosts_file, ssh_flags, ssh_forward_agent, ssh_allow_agent, ssh_look_for_keys, ssh_strict_host_key_checking, ssh_connect_retries, ssh_connect_retry_min_delay, ssh_connect_retry_max_delay, ssh_paramiko_connect_kwargs, ssh_util`.

`ssh_user` is the *login* user; privilege escalation is separate (`_sudo` etc.).

## @local

Executes via subprocesses on the machine running pyinfra. **macOS & Linux only** (per docs). `pyinfra @local exec -- echo hi`.

## @docker / @podman — treat containers as inventory

Pass an **image** or an existing **container ID**:

```sh
pyinfra @docker/alpine:3.8 ...
pyinfra @docker/alpine:3.8,@docker/ubuntu:bionic ...    # parallel across images
pyinfra @docker/2beb8c15a1b1 ...                        # running container
pyinfra @podman/alpine:3.8 ...
```

- Image → creates a new container, runs ops, **saves result into a new image**, removes container.
- Container ID → executes against the running container, leaves it running.
- Great local dev loop for testing deploys/ops/facts. Note: with `@docker/IMAGE` every run starts fresh, so state ops always report changes; use the image/container ID from run 1 to exercise idempotency.
- Unrelated to `operations.docker`/`facts.docker` (which manage Docker *on* the target host).

## @dockerssh / @podmanssh (beta) — containers on remote hosts

Format `@<connector>/<remote-host>:<image>:<tag>`:

```sh
pyinfra @dockerssh/remotehost:alpine:3.8 ...
pyinfra @podmanssh/web1:nginx:latest,@podmanssh/web2:nginx:latest deploy.py
pyinfra @podmanssh/production-server:alpine:3.18 --sudo --port 2222 operations/
```

@podmanssh: SSH access to the remote host + Podman installed there; container create, `podman exec`, `podman cp` file ops, auto commit/cleanup. Choose: @podman = local Podman, @dockerssh = remote Docker, @podmanssh = remote Podman (rootless-friendly).

## @chroot

Execute operations within another root, for building/repairing filesystems.

## @fake — simulated execution (tests/demos/docs)

Every command "succeeds" (exit 0, empty output) unless scripted via host data:

```python
import re
fake_hosts = [("@fake", {
    "fake_responses": {
        "systemctl is-active": {"stdout": "active", "success": True},  # str → substring match
        re.compile(r"^ip addr"): ["1: lo", "2: eth0"],                 # re.Pattern → search()
    },
    "fake_delay": 0, "fake_delay_jitter": 0,  # or env PYINFRA_FAKE_DELAY / _JITTER
})]
```

Matchers tried in insertion order, first match wins; response is str / list of stdout lines / dict with optional `stdout`, `stderr`, `success`. Delay is short + randomized by default so progress bars behave realistically; set `0` for instant tests.

## @terraform — hosts from Terraform outputs

Reads `terraform output -json`; the path after `@terraform/` indexes the flattened output dict:

```sh
pyinfra @terraform/server_group.value.server_group_node_ips ...
```

Value must be a list of hostnames **or** dicts carrying host data:

```json
{"server_group_node_ips": [{"ssh_hostname": "1.2.3.4", "ssh_user": "ssh-user"}]}
```

## @vagrant — running Vagrant VMs as inventory

```sh
pyinfra @vagrant ...                        # all running VMs
pyinfra @vagrant/my-vm-name ...             # named VM
pyinfra @vagrant/my-vm-name,@vagrant/other ...
```

Reads current `vagrant` status to build the inventory (port/user wiring handled for you).

## Notes

- Windows targets: `@winrm` was **removed in 3.x**; planned as a separate `pyinfra-windows` package.
- Connector host names embed the connector string, so `--limit @local` matches by name.
- Connector config is just host/group data (`ssh_*`, `fake_responses`, ...) — inventories are Python, so generate them programmatically for dynamic fleets (`inventory-data.md`).
- Writing your own connector (`BaseConnector`, entry points): `custom-api.md`.
