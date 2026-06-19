# Alma 10 Installer ISO

myOS can build an Alma 10 Server based Anaconda installer ISO that installs the published myOS `alma10-server` BootC payload.

This installer exists to provide a predictable install path for bare-metal machines. In particular, it avoids relying on Fedora Workstation's desktop installer defaults when the goal is to install a system that can move cleanly across the Alma lanes.

The generated ISO is not committed to the repository. The repository contains the source files needed to generate it.

## Canonical files

The Alma 10 Server installer source lives here:

```text
installer/alma10-server/
├── Containerfile
├── README.md
└── iso.toml
```

The important file for installer behavior is:

```text
installer/alma10-server/iso.toml
```

That TOML file defines the ISO metadata, embedded Kickstart, and Anaconda modules used by the installer. The default profile is intentionally interactive: users should walk through Anaconda, choose storage, create users, and confirm install settings.

## What it builds

The installer flow has two images:

```text
installer environment = Anaconda-capable image derived from ghcr.io/myos-dev/alma10-server:latest
installed payload     = ghcr.io/myos-dev/alma10-server:latest by default
root filesystem       = XFS by default
installer config      = installer/alma10-server/iso.toml
```

The installer environment includes Anaconda and related installer dependencies. The installed system payload is passed separately to `bootc-image-builder` with `--installer-payload-ref`.

## Build locally

From the repository root:

```bash
bash ./scripts/build-alma10-installer-iso.sh
```

The default output path is:

```text
output/installer/alma10-server/
```

The script writes both the ISO and a `.sha256` file.

## Use a modified TOML without changing the repo

To experiment with installer behavior locally:

```bash
cp installer/alma10-server/iso.toml /tmp/myos-iso.toml
$EDITOR /tmp/myos-iso.toml

MYOS_INSTALLER_CONFIG=/tmp/myos-iso.toml \
  bash ./scripts/build-alma10-installer-iso.sh
```

Use this when testing storage automation, different Anaconda module settings, or temporary Kickstart changes.

## Override the payload

For testing a different tag or digest:

```bash
MYOS_INSTALLER_PAYLOAD_REF=ghcr.io/myos-dev/alma10-server:latest \
  bash ./scripts/build-alma10-installer-iso.sh
```

For release media, prefer a digest instead of a mutable tag.

## Override the root filesystem

The default root filesystem is XFS:

```bash
MYOS_INSTALLER_ROOTFS=xfs \
  bash ./scripts/build-alma10-installer-iso.sh
```

XFS is the recommended default for Alma-lane installs. Avoid Btrfs if the system is expected to move between Alma and Fedora image lanes.

## Direct builder equivalent

The build script wraps this shape:

```bash
sudo podman run \
  --rm \
  --privileged \
  --pull=newer \
  --security-opt label=type:unconfined_t \
  -v "$PWD/installer/alma10-server/iso.toml:/config.toml:ro" \
  -v "$PWD/output/installer/alma10-server:/output" \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  quay.io/centos-bootc/bootc-image-builder:latest \
  build \
  --type bootc-installer \
  --rootfs xfs \
  --installer-payload-ref ghcr.io/myos-dev/alma10-server:latest \
  --output /output \
  localhost/myos-alma10-server-installer:dev
```

Use the script unless you are debugging the builder invocation itself.

## Build in GitHub Actions

The repository includes a manual workflow:

```text
Build Alma 10 Installer ISO
```

It uploads the ISO as a workflow artifact. Do not commit generated ISO files to the repository.

Large ISO files should be treated as build outputs, not source files. Keep the repo focused on installer definitions, scripts, and documentation.

## Install on bare metal

Write the ISO to a USB drive:

```bash
lsblk -o NAME,SIZE,MODEL,TRAN,TYPE,MOUNTPOINTS

export USB=/dev/sdX   # replace carefully
export ISO=/path/to/myos-installer.iso

sudo umount "${USB}"* 2>/dev/null || true
sudo dd if="$ISO" of="$USB" bs=4M status=progress oflag=sync
sync
sudo eject "$USB" || true
```

Boot the target machine from the USB and walk through Anaconda.

Recommended storage layout:

```text
/boot/efi   EFI System Partition   1024 MiB
/boot       XFS or ext4             1024 MiB
/           XFS                     rest of disk
```

Avoid Btrfs if the system is expected to move between Alma and Fedora image lanes.

## Validate after install

On the installed system:

```bash
cat /etc/os-release
findmnt /
findmnt /boot || true
lsblk -f
bootc status || true
mount | grep -i btrfs || true
```

Expected result:

```text
/ is XFS
no Btrfs mounts
bootc status points at the installed myOS Alma 10 Server payload
```

## Maintenance notes

- Keep `installer/alma10-server/iso.toml` interactive by default.
- Do not add `firewall --enabled` to the Kickstart unless `firewalld` is present in the installed payload image.
- Do not commit generated ISO files.
- Add a separate automated profile later if unattended installs become a supported goal.
