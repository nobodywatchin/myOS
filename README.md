<p align="center">
  <a href="https://github.com/nobodywatchin/myOS">
    <img src="/files/logos/usr/share/pixmaps/fedora-logo.png" href="https://github.com/nobodywatchin/myOS" width=360 />
  </a>
</p>

# myOS &nbsp; [![bluebuild build badge](https://github.com/nobodywatchin/myOS/actions/workflows/build.yml/badge.svg)](https://github.com/nobodywatchin/myOS/actions/workflows/build.yml)

myOS is an opinionated all-purpose operating system dedicated to progress, freedom, and ease-of-use.

# How it's made

This repo uses [BlueBuild](https://blue-build.org/) to generate operating system images, building on top of the following bootc images:
[Almalinux](https://quay.io/repository/almalinuxorg/almalinux-bootc?tab=tags), 
[CentOS](https://quay.io/repository/centos-bootc/centos-bootc?tab=tags), and 
[Fedora](https://quay.io/repository/fedora/fedora-bootc?tab=tags)

# Vision

myOS was created to offer a user-friendly yet powerful operating system that embraces open-source principles while providing a cohesive and polished experience. 

myOS works out of the box with minimal setup, allowing users to focus on their tasks without unnecessary distractions.

# Customization

If you want to add your own customizations on top of myOS, you are advised strongly against forking. Instead, create a repo for your own image by using the [BlueBuild template](https://github.com/blue-build/template), then change your `base-image` to a myOS image. This will allow you to apply your customizations to myOS in a concise and maintainable way, without the need to constantly sync with upstream. 

# Building as a VM

```bash
TMP=$(mktemp) && \
curl -fsSL https://raw.githubusercontent.com/nobodywatchin/myOS/stable/image.toml -o "$TMP" && \
sudo podman pull ghcr.io/nobodywatchin/alma10:latest && \
sudo podman pull quay.io/centos-bootc/bootc-image-builder:latest && \
sudo podman run --rm -it --privileged --pull=newer \
  --security-opt label=type:unconfined_t \
  --network=host \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  -v "$(pwd)/output:/output" \
  -v "$TMP:/config.toml:ro" \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type qcow2 \
  --progress verbose \
  --use-librepo=false \
  --config /config.toml \
  ghcr.io/nobodywatchin/alma10:latest
rm -f "$TMP"

```

# Building ISO File

```bash
TMP=$(mktemp) && \
curl -fsSL https://raw.githubusercontent.com/nobodywatchin/myOS/stable/iso.toml -o "$TMP" && \
sudo podman pull ghcr.io/nobodywatchin/alma10:latest && \
sudo podman pull quay.io/centos-bootc/bootc-image-builder:latest && \
sudo podman run --rm -it --privileged --pull=newer \
  --security-opt label=type:unconfined_t \
  --network=host \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  -v "$(pwd)/output:/output" \
  -v "$TMP:/config.toml:ro" \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type iso \
  --progress verbose \
  --use-librepo=false \
  --config /config.toml \
  ghcr.io/nobodywatchin/alma10:latest
rm -f "$TMP"
```


# Images
### AlmaLinux
- `alma10`
- `alma10-nvidia`
- `alma9`
- `alma9-nvidia`
### CentOS 
- 
### Fedora
- `fedora42`
- `fedora42-nvidia`
## Experimental [NOT YET RECOMMENDED]
- 
