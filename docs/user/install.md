# Install

Current is shipped as bootc images.

## Install bare metal with the Alma 10 installer ISO

For a new bare-metal install, prefer the Current AlmaLinux 10 Server installer ISO.

That installer uses Anaconda and installs the published `ghcr.io/myos-dev/alma10-server:latest` bootc payload. It is intended to give Current a predictable install path without inheriting Fedora Workstation's Btrfs-oriented desktop defaults.

The image reference still uses the legacy `myos-dev` namespace until registry migration work lands.

See [installer-iso.md](installer-iso.md) for the ISO build and USB install flow.

Recommended storage layout:

```text
/boot/efi   EFI System Partition   1024 MiB
/boot       XFS or ext4             1024 MiB
/           XFS                     rest of disk
```

Avoid Btrfs if the system is expected to move between Alma and Fedora image lanes.

## Switch an installed system

The compatibility command is currently:

```bash
myos rebase
```

That picker presents images by role, environment, platform, and driver.

You can also switch directly:

```bash
sudo bootc switch ghcr.io/myos-dev/alma10-gnome:latest
```

## Build a VM image

A simple VM flow still looks like this:

```bash
TMP=$(mktemp)
curl -fsSL https://raw.githubusercontent.com/myos-dev/myOS/stable/image.toml -o "$TMP"
sudo podman pull ghcr.io/myos-dev/alma10-gnome:latest
sudo podman pull quay.io/centos-bootc/bootc-image-builder:latest
sudo podman run --rm -it --privileged --pull=newer   --security-opt label=type:unconfined_t   --network=host   -v /var/lib/containers/storage:/var/lib/containers/storage   -v "$(pwd)/output:/output"   -v "$TMP:/config.toml:ro"   quay.io/centos-bootc/bootc-image-builder:latest   build   --type qcow2   --progress verbose   --use-librepo=false   --output /output   ghcr.io/myos-dev/alma10-gnome:latest
rm -f "$TMP"
```

Swap in a different published tag if you want another role, environment, platform, or driver lane.
