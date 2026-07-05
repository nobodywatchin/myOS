# Installer ISO

Current provides an AlmaLinux 10 based Anaconda installer ISO path for bare-metal installs.

The ISO is built from the repository and installs a bootc payload. The current default payload reference still uses the legacy `myos-dev` registry namespace until the technical namespace migration lands.

## What this builds

```text
installer environment = Anaconda-capable image derived from ghcr.io/myos-dev/alma10-server:latest
installed payload     = ghcr.io/myos-dev/alma10-server:latest by default
root filesystem       = XFS by default
installer config      = installer/alma10-server/iso.toml
```

The installer environment includes Anaconda and related installer dependencies. The installed system payload is passed separately to `bootc-image-builder` with `--installer-payload-ref`.

## Build from the repository config

From the repository root:

```bash
bash ./scripts/build-alma10-installer-iso.sh
```

The script uses this file by default:

```text
installer/alma10-server/iso.toml
```

The default output directory is:

```text
output/installer/alma10-server/
```

The output should include an ISO and a matching `.sha256` file.

## Override the installer config

To test a modified TOML file without changing the repo copy:

```bash
cp installer/alma10-server/iso.toml /tmp/current-iso.toml
$EDITOR /tmp/current-iso.toml

MYOS_INSTALLER_CONFIG=/tmp/current-iso.toml   bash ./scripts/build-alma10-installer-iso.sh
```

The environment variable is still `MYOS_INSTALLER_CONFIG` during the compatibility transition.

## Override the payload image

To install a different tag or digest:

```bash
MYOS_INSTALLER_PAYLOAD_REF=ghcr.io/myos-dev/alma10-server:latest   bash ./scripts/build-alma10-installer-iso.sh
```

For release media, prefer a digest instead of a mutable tag.

## Override the filesystem

The default root filesystem is XFS:

```bash
MYOS_INSTALLER_ROOTFS=xfs   bash ./scripts/build-alma10-installer-iso.sh
```

XFS is the recommended default for the Alma lanes. Avoid Btrfs if the installed system is expected to move between Alma and Fedora image lanes.

## Direct builder equivalent

The build script wraps this shape:

```bash
sudo podman run   --rm   --privileged   --pull=newer   --security-opt label=type:unconfined_t   -v "$PWD/installer/alma10-server/iso.toml:/config.toml:ro"   -v "$PWD/output/installer/alma10-server:/output"   -v /var/lib/containers/storage:/var/lib/containers/storage   quay.io/centos-bootc/bootc-image-builder:latest   build   --type bootc-installer   --rootfs xfs   --installer-payload-ref ghcr.io/myos-dev/alma10-server:latest   --output /output   localhost/myos-alma10-server-installer:dev
```

Use the script unless you are debugging the builder invocation itself.

## Notes

- Do not add generated ISO files to git.
- Keep `iso.toml` interactive by default. It should let the user walk through Anaconda.
- Do not add `firewall --enabled` to the Kickstart unless `firewalld` is present in the installed payload image.
- Keep storage decisions visible in Anaconda unless a separate automated installer profile is introduced.
