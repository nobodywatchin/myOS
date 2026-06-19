# Alma 10 Installer ISO

myOS can build an Alma 10 Server based Anaconda installer ISO that installs the published myOS `alma10-server` BootC payload.

This installer exists to provide a predictable install path for bare-metal machines. In particular, it avoids relying on Fedora Workstation's desktop installer defaults when the goal is to install a system that can move cleanly across the Alma lanes.

## What it builds

The installer flow has two images:

```text
installer environment = Anaconda-capable image derived from ghcr.io/myos-dev/alma10-server:latest
installed payload     = ghcr.io/myos-dev/alma10-server:latest
root filesystem       = selected in Anaconda, with XFS recommended
```

The installer is intentionally interactive. The user should walk through Anaconda, choose disks, create users, and confirm storage. The included Kickstart only sets safe defaults and enables the relevant Anaconda modules.

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

## Override the payload

For testing a different tag or digest:

```bash
MYOS_INSTALLER_PAYLOAD_REF=ghcr.io/myos-dev/alma10-server:latest \
  bash ./scripts/build-alma10-installer-iso.sh
```

For release media, prefer a digest instead of a mutable tag.

## Build in GitHub Actions

The repository includes a manual workflow:

```text
Build Alma 10 Installer ISO
```

It uploads the ISO as a short-lived workflow artifact. Do not commit generated ISO files to the repository.

GitHub release assets have a per-file size limit, so large ISO files may need to remain workflow artifacts, be split into release parts, or be hosted elsewhere.

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
