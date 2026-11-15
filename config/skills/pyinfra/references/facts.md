# Facts — reading target host state

Source: docs.pyinfra.com/en/3.x facts pages + using-operations/deploy-process guides.

## Using facts

```python
from pyinfra import host
from pyinfra.facts.files import File
from pyinfra.facts.server import LinuxName, Hostname

info = host.get_fact(File, path="/etc/nginx/nginx.conf")   # dict | False | None
name = host.get_fact(LinuxName)                            # "Ubuntu" etc.
```

```sh
pyinfra INV fact server.LinuxName
pyinfra INV fact files.File path=/etc/hosts
pyinfra INV fact server.LinuxName --json
```

- Facts are read-only shell commands + a `process()` parser; **cached per host for the whole deploy**, so repeat `get_fact` calls are free.
- **Timing rule**: facts are gathered during *prepare*, before any operation mutates the host → only branch Python on *immutable* facts (Os, Arch, Kernel*, LinuxDistribution/Name). Use `_if` for post-change conditions (`deploy-process.md`).
- A failing fact command fails the host → tolerate with `host.get_fact(Fact, _ignore_errors=True)`.
- Missing-binary behavior (`requires_command`, e.g. `mysql` not installed): v3 logs a warning at execute time and returns the fact's `default()`; **v4 will raise** — install-then-read ordering matters (see `custom-api.md`).

## Return conventions (filesystem facts)

- `None` → path does not exist
- `False` → path exists but wrong type (not a file/dir/etc.)
- `[]` → exists, searched thing not found (e.g. `Block` with no markers)
- dict → state (`File`: `{user, group, mode, size}`, `Directory`: `{user, group, mode}`)

## Notable fact shapes

| Fact | Call | Returns |
|---|---|---|
| `files.File` | `get_fact(File, path)` | info dict / `False` / `None` |
| `files.Directory` | `get_fact(Directory, path)` | `{user, group, mode}` / `False` / `None` |
| `files.FileContents` | `get_fact(FileContents, path)` | list of lines or `None` |
| `files.Block` | `get_fact(Block, path, marker, begin, end)` | lines between markers; `None` if no file, `[]` if no markers |
| `apt.AptPackages` | `get_fact(AptPackages)` | dict name → `[versions]` |
| `server.Users` | `get_fact(Users)` | dict username → details |
| `server.User` | `get_fact(User)` | current user name |
| `server.LinuxDistribution` | `get_fact(...)` | dict with distro `name`/version keys + release-file k/v |
| `server.LinuxName` | `get_fact(LinuxName)` | short name (ShortFact over LinuxDistribution) |
| `systemd.SystemdStatus` | `get_fact(SystemdStatus, user_mode, machine, user_name, services)` | dict unit → active bool |
| `server.Which` | `get_fact(Which, command='htop')` | binary path or `None` |
| `server.Command` | `get_fact(Command, command='...')` | raw output lines (general escape hatch) |
| `crontab.Crontab` | `get_fact(Crontab, user=...)` | dict of entries |
| `git.GitBranch` | `get_fact(GitBranch, repo=...)` | current branch |

## Full catalog by module (class names verbatim)

- **apk**: ApkPackages
- **apt**: AptKeys, AptPackages, AptSources, SimulateOperationWillChange
- **brew**: BrewCasks, BrewPackages, BrewTaps, BrewTrusted, BrewVersion
- **bsdinit**: RcdStatus — **cargo**: CargoPackages — **choco**: ChocoPackages, ChocoVersion
- **crontab**: Crontab — **deb**: DebArch, DebPackage, DebPackages
- **dnf**: DnfDisabledModules, DnfEnabledModules, DnfRepositories
- **docker**: DockerAuths, DockerContainer, DockerContainers, DockerContainerEnvs, DockerContainerFsChanges, DockerContainerLabels, DockerContainerMounts, DockerContainerNetworks, DockerContainerPorts, DockerContainerProcesses, DockerContainerStats, DockerImage, DockerImages, DockerImageHistory, DockerImageLabels, DockerImageLayers, DockerNetwork, DockerNetworks, DockerNetworkLabels, DockerPlugin, DockerPlugins, DockerSystemInfo, DockerVersion, DockerVolume, DockerVolumes, DockerVolumeLabels
- **efibootmgr**: EFIBootMgr — **flatpak**: FlatpakBaseFact, FlatpakPackage, FlatpakPackages — **freebsd**: PkgPackage, ServiceScript, ServiceStatus, Sysrc
- **files**: Block, Directory, File, FileContents, FindDirectories, FindFiles, FindInFile, FindLinks, Flags, Link, Md5File, Sha1File, Sha256File, Sha384File, Socket
- **gem**: GemPackages — **go**: GoPackages
- **git**: GitBranch, GitConfig, GitLocalCommit, GitRemoteBranchCommit, GitTag, GitTrackingBranch
- **gpg**: GpgKey, GpgKeyrings, GpgKeys, GpgSecretKeys
- **hardware**: BlockDevices, CpuInfo, Cpus, Ipv4Addresses, Ipv4Addrs, Ipv6Addresses, Ipv6Addrs, Memory, NetworkDevices
- **iptables**: IptablesChains, IptablesRules, Ip6tablesChains, Ip6tablesRules
- **launchd**: LaunchdStatus — **lxd**: LxdContainers
- **mysql**: MysqlDatabases, MysqlUserGrants, MysqlUsers — **npm**: NpmPackages
- **openrc**: OpenrcEnabled, OpenrcStatus — **opkg**: OpkgConf, OpkgFeeds, OpkgInstallableArchitectures, OpkgPackages, OpkgUpgradeablePackages
- **pacman**: PacmanPackages, PacmanUnpackGroup
- **pip**: PipPackages, Pip3Packages — **pipx**: PipxEnvironment, PipxPackages
- **pkg**: PkgPackages — **pkgin**: PkginPackages — **podman**: PodmanPs, PodmanSystemInfo
- **postgres**: PostgresDatabases, PostgresRoles — **postgresql**: PostgresqlDatabases, PostgresqlRoles
- **rpm**: RpmPackage, RpmPackages, RpmPackageProvides — **runit**: RunitManaged, RunitStatus
- **selinux**: FileContext, FileContextMapping, SEBoolean, SEPort, SEPorts
- **server**: Arch, AuthorizedKeys, Command, Date, EtcHosts, Groups, HasGui, Home, Hostname, Kernel, KernelModules, KernelVersion, Last, Lastb, LinuxDistribution, LinuxGui, LinuxName, LoadAverage, Locales, LsbRelease, MacosVersion, Mounts, Os, OsRelease, OsVersion, Path, Port, Ports, Processes, RebootRequired, SecurityLimits, Selinux, Sysctl, Timezone, TmpDir, Uptime, User, Users, Which
- **snap**: SnapBaseFact, SnapPackage, SnapPackages — **systemd**: SystemdStatus, SystemdEnabled — **sysvinit**: InitdStatus — **upstart**: UpstartStatus
- **uv**: UvAvailablePythonsByImplementation, UvAvailablePythonsByVersion, UvInstalledPythonsByImplementation, UvInstalledPythonsByVersion, UvPipPackages, UvPythonDir, UvToolDir, UvTools, UvVersion
- **vzctl**: OpenvzContainers — **xbps**: XbpsPackages — **yum**: YumRepositories — **zypper**: ZypperRepositories
- **zfs**: Pools, Datasets, Filesystems, Volumes, Snapshots

Writing your own fact classes (`FactBase`, `ShortFactBase`, `requires_command`, `check_preconditions`): see `custom-api.md`.
