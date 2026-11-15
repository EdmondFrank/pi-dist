# Operations: Docker, Git, Databases, Containers, Misc

Source: docs.pyinfra.com/en/3.x operations modules (signatures verbatim). These manage things *on* the inventory host (contrast with `@docker`/`@podman` **connectors** that make pyinfra execute *inside* containers — see `connectors.md`).

## docker.* — containers, images, volumes, networks, compose

```py
docker.image(image, present=True, force=False)                    # pull/remove image
docker.container(container, image='', ports=None, networks=None, volumes=None,
                 env_vars=None, env_files=None, labels=None, pull_always=False, present=True,
                 force=False, start=True, restart_policy=None, auto_remove=False, mounts=None,
                 privileged=False, hostname=None, entrypoint=None, user=None, cpus=None,
                 memory=None, extra_args=None, dns=None, command=None)
docker.container_exec(container, command, user=None, workdir=None, env=None, detach=False,
                      privileged=False, tty=False)                # command: str | list[str]
docker.compose(project_directory, files=None, project_name=None, present=True, pull=None,
               build=False, force_recreate=False, remove_orphans=True, remove_volumes=False,
               compose_command='docker compose')
docker.build(path, tags=None, dockerfile=None, build_args=None, labels=None, target=None,
             platform=None, network=None, cache_from=None, cache_to=None, secrets=None,
             pull=False, no_cache=False, force=False, builder=None, build_cmd='docker build')
docker.network(network, driver='', gateway='', ip_range='', ipam_driver='', subnet='', scope='',
               aux_addresses=None, opts=None, ipam_opts=None, labels=None, ingress=False,
               attachable=False, present=True)
docker.volume(volume, driver='', labels=None, options=None, present=True)
docker.login(username, password, server=None, force=False)
docker.logout(server=None)
docker.plugin(plugin, alias=None, present=True, enabled=True, plugin_options=None)
docker.prune(all=False, volumes=False, filter='')
```

- `docker.container(container="mydb", image="postgres:16", ports=["5432:5432"], present=True)` converges via `DockerContainer(s)` facts; `force=True` recreates; `start=False` creates stopped; `present=False` removes.
- Diff facts: `docker.DockerContainers`, `DockerImages`, `DockerNetworks`, `DockerVolumes` (see `facts.md`).

## git.* — repos & config

```py
git.repo(src, dest, branch=None, pull=True, rebase=False, user=None, group=None,
         ssh_keyscan=False, update_submodules=False, recursive_submodules=False, depth=None,
         *, fetch_tags=False)
git.worktree(worktree, repo=None, detached=False, new_branch=None, commitish=None, pull=True,
             rebase=False, from_remote_branch=None, present=True, assume_repo_exists=False,
             force=False, user=None, group=None)
git.bare_repo(path, user=None, group=None, present=True)
git.config(key, value, multi_value=False, repo=None, system=False)
```

- `git.repo` clones if missing, otherwise fetch/pull to converge `branch`; run as an unprivileged user via `user=`/`group=`.
- Private repos over SSH: `ssh_keyscan=True` accepts the host key on first contact.
- Facts: `git.GitBranch`, `git.GitConfig`, `git.GitRemoteBranchCommit`, `git.GitTrackingBranch`, `git.GitTag`, `git.GitLocalCommit`.

## mysql.* / postgres.* — DB state (connect kwargs at the end of every signature)

```py
mysql.database(database, present=True, collate=None, charset=None, user=None,
               user_hostname='localhost', user_privileges='ALL',
               mysql_user=None, mysql_password=None, mysql_host=None, mysql_port=None)
mysql.user(user, present=True, user_hostname='localhost', password=None, privileges=None,
           require=None, require_cipher=None, require_issuer=None, require_subject=None,
           max_connections=None, max_queries_per_hour=None, max_updates_per_hour=None,
           max_connections_per_hour=None,
           mysql_user=None, mysql_password=None, mysql_host=None, mysql_port=None)
mysql.privileges(user, privileges, user_hostname='localhost', database='*', table='*',
                 flush=True, with_grant_option=False, mysql_user=None, mysql_password=None,
                 mysql_host=None, mysql_port=None)
mysql.sql(sql, database=None, mysql_user=None, mysql_password=None, mysql_host=None, mysql_port=None)
mysql.dump(dest, database=None, ...); mysql.load(src, database=None, ...)
```

```py
postgres.database(database, present=True, owner=None, template=None, encoding=None,
                  lc_collate=None, lc_ctype=None, tablespace=None, connection_limit=None,
                  psql_user=None, psql_password=None, psql_host=None, psql_port=None,
                  psql_database=None)
postgres.role(role, present=True, password=None, login=True, superuser=False, inherit=False,
              createdb=False, createrole=False, replication=False, connection_limit=None,
              psql_user=None, psql_password=None, psql_host=None, psql_port=None,
              psql_database=None)
postgres.sql(sql, psql_user=None, ...); postgres.dump(dest, ...); postgres.load(src, ...)
postgresql.database/dump/load/role/sql(...)   # newer module, same API
```

- `mysql_user=`/`psql_user=` are the *connection* credentials; `user=`/`owner=` are the managed objects — easy to confuse.
- Facts: `mysql.MysqlDatabases/MysqlUsers/MysqlUserGrants`, `postgres.PostgresDatabases/PostgresRoles` (+ `postgresql.*` equivalents).

## Other hosts/containers

```py
lxd.container(id, present=True, image='ubuntu:16.04')            # LXD containers
vzctl.create(ctid, template=None); vzctl.delete(ctid); vzctl.start(ctid, force=False)
vzctl.stop(ctid); vzctl.restart(ctid, force=False); vzctl.mount(ctid); vzctl.unmount(ctid)
vzctl.set(ctid, save=True, **settings)                           # OpenVZ
zfs.dataset(dataset_name, present=True, recursive=False, sparse=None, volume_size=None,
            properties=None, **extra_props)
zfs.filesystem(fs_name, present=True, recursive=False, properties=None, **extra_props)
zfs.volume(volume_name, size, sparse=False, present=True, recursive=False, properties=None,
           **extra_props)
zfs.snapshot(snapshot_name, present=True, recursive=False, properties=None, **extra_props)
puppet.agent(server=None, port=None)                             # run a puppet agent
```

Facts: `zfs.Pools/Datasets/Filesystems/Volumes/Snapshots`, `lxd.LxdContainers`.

## CLI one-liners

```sh
pyinfra INV git.repo https://github.com/pyinfra-dev/pyinfra.git /srv/app user=deploy
pyinfra INV docker.compose /opt/stack
pyinfra INV docker.container mydb image=postgres:16 present=true
```
