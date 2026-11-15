# Operations: Package Managers & Language Packages

Source: docs.pyinfra.com/en/3.x/operations index + per-module pages (signatures verbatim). Import as `from pyinfra.operations import apt, pip, ...`. Common patterns: `present=True/False` installs/removes; `latest=True` upgrades named packages; version pins inline (`"<pkg>=<version>"` per manager syntax). Distro map: apt→Debian/Ubuntu, dnf/yum→Fedora/RHEL, apk→Alpine, pacman→Arch, zypper→openSUSE/SLE, pkg→FreeBSD, pkgin→NetBSD/SmartOS, xbps→Void, opkg→OpenWrt, choco→Windows, snap/flatpak→cross-distro, brew→macOS. `dnf`, `pkg`, `xbps`, `yum` package names are **case-sensitive** (per module docs).

## System package managers

```py
apt.packages(packages=None, present=True, latest=False, update=False, cache_time=None,
             upgrade=False, force=False, no_recommends=False, allow_downgrades=False,
             purge=False, extra_install_args=None, extra_uninstall_args=None)
apt.update(cache_time=None)        # apt-get update; cache_time=N (secs) skips if cache fresh
apt.upgrade(auto_remove=False)
apt.dist_upgrade(auto_remove=False)
apt.key(src=None, keyserver=None, keyid=None, dest=None, present=True)  # GPG key for repos
apt.ppa(src, present=True)         # add-apt-repository style PPA
apt.repo(src, present=True, filename=None)                   # apt source snippet
apt.sources_file(filename, types='deb', uris=None, suites=None, components=None,
                 architectures=None, signed_by=None, present=True)  # /etc/apt/sources.list.d
apt.deb(src, present=True, force=False)                      # local .deb file

dnf.packages(packages=None, present=True, latest=False, update=False, clean=False,
             nobest=False, extra_install_args=None, extra_uninstall_args=None)
# update: run `dnf update` first; clean: run `dnf clean` first; nobest: pass --nobest
dnf.update()
dnf.repo(src, present=True, baseurl=None, description=None, enabled=True, gpgcheck=True, gpgkey=None)
dnf.key(src); dnf.rpm(src, present=True)        # install/remove an RPM (e.g. release RPMs)
dnf.module(module, stream=None, enabled=True)   # dnf modules

yum.packages(packages=None, present=True, latest=False, update=False, clean=False, nobest=False,
             extra_install_args=None, extra_uninstall_args=None)
yum.update(); yum.repo(src, present=True, baseurl=None, description=None, enabled=True,
                       gpgcheck=True, gpgkey=None); yum.key(src); yum.rpm(src, present=True)

apk.packages(packages=None, present=True, latest=False, update=False, upgrade=False)
apk.update(); apk.upgrade(available=False)       # versions pinned as <pkg>=<version>

pacman.packages(packages=None, present=True, update=False, upgrade=False)
pacman.update(); pacman.upgrade()

zypper.packages(packages=None, present=True, latest=False, update=False, clean=False,
                extra_global_install_args=None, extra_install_args=None,
                extra_global_uninstall_args=None, extra_uninstall_args=None)
zypper.update()
zypper.repo(src, baseurl=None, present=True, description=None, enabled=True,
            gpgcheck=True, gpgkey=None, type='rpm-md')
zypper.rpm(src, present=True)

xbps.packages(packages=None, present=True, update=False, upgrade=False)    # Void
xbps.update(); xbps.upgrade()

pkg.packages(packages=None, present=True, pkg_path=None)       # BSD pkg
pkgin.packages(packages=None, present=True, latest=False, update=False, upgrade=False)
pkgin.update(); pkgin.upgrade()

opkg.packages(packages='', present=True, latest=False, update=True)        # OpenWrt
opkg.update()

choco.packages(packages=None, present=True, latest=False)      # Windows Chocolatey
choco.install()                                                # bootstrap chocolatey itself
snap.package(packages=None, channel='latest/stable', classic=False, present=True)
flatpak.packages(packages=None, remote=None, present=True)

server.packages(packages, present=True)   # cross-distro: detects the manager & dispatches
```

## Language / application packages

```py
pip.packages(packages=None, present=True, latest=False, requirements=None, pip='pip',
             virtualenv=None, virtualenv_kwargs=None, extra_install_args=None)
pip.venv(path, python=None, site_packages=False, always_copy=False, present=True)
pip.virtualenv(path, python=None, venv=False, site_packages=False, always_copy=False, present=True)

pipx.packages(packages=None, present=True, latest=False, extra_args=None)   # CLI apps
pipx.upgrade_all(); pipx.ensure_path()

uv.packages(packages, *, requirements=None, present=True, latest=False, extra_args=None)
uv.venv(path, *, present=True, python=None, allow_existing=False, clear_existing=False,
        link_mode=None /* 'clone'|'copy'|'hardlink'|'symlink' */, seed=False,
        site_packages=False, extra_args=None)
uv.pythons(versions, *, present=True, managed=True, extra_args=None)  # managed Pythons
uv.tools(tools, *, present=True, latest=False, extra_args=None)       # uv tool install
uv.tools_upgrade_all(*, extra_args=None); uv.tools_update_shell()

npm.packages(packages=None, present=True, latest=False, directory=None)  # node; local via directory=
gem.packages(packages=None, present=True, latest=False)                  # ruby
cargo.packages(packages=None, present=True, latest=False)                # rust (cargo install)
go.packages(packages=None, present=True, latest=False)                   # go install binaries

brew.packages(packages=None, present=True, latest=False, update=False, upgrade=False)  # macOS
brew.casks(casks=None, present=True, latest=False, upgrade=False)
brew.tap(src=None, present=True, trusted=False, url=None)
brew.trust(items, kind, trusted)          # BrewItemKind
brew.update(); brew.upgrade(); brew.cask_upgrade()
```

## One-liner CLI usage

```sh
pyinfra INV apt.packages nginx update=true _sudo=true
pyinfra INV pip.packages requests virtualenv=/opt/app/venv
pyinfra INV fact apt.AptPackages          # read installed set (see facts.md)
```

## Idempotency notes

- Declarative: `X.packages` diffs against the matching fact (`apt.AptPackages`, `apk.ApkPackages`, `pip.PipPackages`, `npm.NpmPackages`, `brew.BrewPackages`, `deb.DebPackages`, `rpm.RpmPackages`, ...). Installed-but-outdated counts as converged unless `latest=True`.
- `apt.packages(cache_time=3600)` / `apt.update(cache_time=3600)` prevents repeated `apt-get update` across many operations in one deploy.
- apt `purge=True` uses purge instead of remove; `force=True` passes force flags; `no_recommends=True` skips Recommends.
- Repos: apt has both `apt.repo`/`apt.sources_file` (deb822-style kwargs) and `apt.ppa`; dnf/yum/zypper write `.repo` files via `repo(src, baseurl=..., gpgcheck=...)`.
