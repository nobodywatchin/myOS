# Install

myOS is shipped as BootC images.

## Switch an installed system

The easiest path is:

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
curl -fsSL https://raw.githubusercontent.com/myos-dev/myOS/alma10/image.toml -o "$TMP"
sudo podman pull ghcr.io/myos-dev/alma10-gnome:latest
sudo podman pull quay.io/centos-bootc/bootc-image-builder:latest
sudo podman run --rm -it --privileged --pull=newer       --security-opt label=type:unconfined_t       --network=host       -v /var/lib/containers/storage:/var/lib/containers/storage       -v "$(pwd)/output:/output"       -v "$TMP:/config.toml:ro"       quay.io/centos-bootc/bootc-image-builder:latest       --type qcow2       --progress verbose       --use-librepo=false       --config /config.toml       ghcr.io/myos-dev/alma10-gnome:latest
rm -f "$TMP"
```

Swap in a different published tag if you want another role, environment, platform, or driver lane.
