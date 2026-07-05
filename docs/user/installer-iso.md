# Installer ISO

The Current Alma 10 installer ISO installs a published bootc payload through Anaconda.

## What this builds

```text
installer environment = Anaconda-capable image derived from ghcr.io/pelagians/alma10-server:latest
installed payload     = ghcr.io/pelagians/alma10-server:latest by default
root filesystem       = XFS by default
installer config      = installer/alma10-server/iso.toml
```

The installer environment includes Anaconda and related installer dependencies. The installed system payload is passed separately to `bootc-image-builder` with `--installer-payload-ref`.

## Build from the repository config

From the repository root:

```bash
bash ./scripts/build-alma10-installer-iso.sh
```

Default config:

```text
installer/alma10-server/iso.toml
```

Default output:

```text
output/installer/alma10-server/
```

The output should include an ISO and a matching `.sha256` file.

## Override the installer config

```bash
cp installer/alma10-server/iso.toml /tmp/current-iso.toml
$EDITOR /tmp/current-iso.toml

CURRENT_INSTALLER_CONFIG=/tmp/current-iso.toml   bash ./scripts/build-alma10-installer-iso.sh
```

## Override the payload image

```bash
CURRENT_INSTALLER_PAYLOAD_REF=ghcr.io/pelagians/alma10-server:latest   bash ./scripts/build-alma10-installer-iso.sh
```

For release media, prefer a digest instead of a mutable tag.

## Override the filesystem

```bash
CURRENT_INSTALLER_ROOTFS=xfs   bash ./scripts/build-alma10-installer-iso.sh
```

XFS is the recommended default for Alma lanes. Avoid Btrfs if the installed system is expected to move between Alma and Fedora image lanes.

## Direct builder equivalent

The build script wraps this shape:

```bash
sudo podman run   --rm   --privileged   --pull=newer   --security-opt label=type:unconfined_t   -v "$PWD/installer/alma10-server/iso.toml:/config.toml:ro"   -v "$PWD/output/installer/alma10-server:/output"   -v /var/lib/containers/storage:/var/lib/containers/storage   quay.io/centos-bootc/bootc-image-builder:latest   build   --type bootc-installer   --rootfs xfs   --installer-payload-ref ghcr.io/pelagians/alma10-server:latest   --output /output   localhost/current-alma10-server-installer:dev
```

Use the script unless you are debugging the builder invocation itself.
