<p align="center">
  <a href="https://github.com/myos-dev/myOS">
    <img src="/files/logos/usr/share/pixmaps/fedora-logo.png" href="https://github.com/myos-dev/myOS" width=360 />
  </a>
</p>

# myOS &nbsp; [![bluebuild build badge](https://github.com/myos-dev/myOS/actions/workflows/build.yml/badge.svg)](https://github.com/myos-dev/myOS/actions/workflows/build.yml)

myOS is an opinionated all-purpose operating system dedicated to progress, freedom, and ease-of-use.

# How it's made

This repo uses [BlueBuild](https://blue-build.org/) to generate operating system images, building on top of the following bootc images:
[Almalinux](https://quay.io/repository/almalinuxorg/almalinux-bootc?tab=tags), 
[CentOS](https://quay.io/repository/centos-bootc/centos-bootc?tab=tags), and 
[Fedora](https://quay.io/repository/fedora/fedora-bootc?tab=tags)

# Vision

myOS was created to offer a user-friendly yet powerful operating system that embraces open-source principles while providing a cohesive and polished experience. 

myOS works out of the box with minimal setup, allowing users to focus on their tasks without unnecessary distractions.

# Tenant Operations

The supported OpenClaw operator workflow is exposed through the `myos` just wrapper instead of hand-editing tenant files under `/srv/tenants`.

Common flows:

```bash
myos tenant-create --tenant demo
myos tenant-secret-set --tenant demo --key OPENROUTER_API_KEY
myos tenant-configure --tenant demo --model openrouter/anthropic/claude-sonnet-4-5
myos tenant-start --tenant demo
myos tenant-status --tenant demo
```

For interactive use, `myos tenant` opens an `fzf` chooser for the same command surface.

# Customization

If you want to add your own customizations on top of myOS, you are advised strongly against forking. Instead, create a repo for your own image by using the [BlueBuild template](https://github.com/blue-build/template), then change your `base-image` to a myOS image. This will allow you to apply your customizations to myOS in a concise and maintainable way, without the need to constantly sync with upstream. 

The [Red Hat](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/using_image_mode_for_rhel_to_build_deploy_and_manage_operating_systems/deploying-the-rhel-bootc-images_using-image-mode-for-rhel-to-build-deploy-and-manage-operating-systems#building-and-launching-configured-images_deploying-the-rhel-bootc-images) and [OSBuild](https://osbuild.org/docs/bootc/) documentation on building bootc images is quite in-depth if you want to tinker. 

# Building as a VM

```bash
TMP=$(mktemp) && \
curl -fsSL https://raw.githubusercontent.com/myos-dev/myOS/stable/image.toml -o "$TMP" && \
sudo podman pull ghcr.io/myos-dev/alma10:latest && \
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
  ghcr.io/myos-dev/alma10:latest
rm -f "$TMP"

```

# Building ISO File

```bash
TMP=$(mktemp) && \
curl -fsSL https://raw.githubusercontent.com/myos-dev/myOS/stable/iso.toml -o "$TMP" && \
sudo podman pull ghcr.io/myos-dev/alma10:latest && \
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
  ghcr.io/myos-dev/alma10:latest
rm -f "$TMP"
```
