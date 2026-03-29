<p align="center">
  <a href="https://github.com/myos-dev/myOS">
    <img src="files/base/branding/usr/share/pixmaps/system-logo-white.png" href="https://github.com/myos-dev/myOS" width=360 />
  </a>
</p>

# myOS &nbsp; [![bluebuild build badge](https://github.com/myos-dev/myOS/actions/workflows/build.yml/badge.svg)](https://github.com/myos-dev/myOS/actions/workflows/build.yml)

myOS is an opinionated BootC image ecosystem organized around a small shared core, clear per-distro layers, and workstation products that stay easy to extend.

# Image Progression

Both Alma 9 and 10 follow the same product path:

- `core-minimal-alma9` / `core-minimal-alma10`
- `core-minimal-alma9-nvidia` / `core-minimal-alma10-nvidia`
- `core-full-alma9` / `core-full-alma10`
- `core-full-alma9-nvidia` / `core-full-alma10-nvidia`
- `workstation-alma9` / `workstation-alma10`
- `workstation-alma9-nvidia` / `workstation-alma10-nvidia`

`core-full-*` is the single full base tier. It includes tenant commands, Cockpit admin tooling, and OpenClaw host scaffolding for both distros. 
RamaLama is added in the Alma 10 full images, while Alma 9 keeps the same platform layout without the packaged RamaLama runtime.

# Repo Layout

```text
recipes/
  images/
    core/
    workstation/
  layers/
    shared/
    alma9/
    alma10/
    features/

files/
  base/
  workstation/
  agent/
  dnf/
  justfiles/
```

- `recipes/images` contains only buildable images.
- `recipes/layers/shared` contains the small shared building blocks: `core-base`, `core-full`, `workstation-base`, `nvidia`, and `nvidia-workstation`.
- `recipes/layers/alma9` and `recipes/layers/alma10` keep version differences explicit without spreading them across lots of tiny files.
- `files/base`, `files/workstation`, and `files/agent` mirror those concerns in the payloads.

Kubernetes is still available as the opt-in feature layer at [`recipes/layers/features/kubernetes-cli.yml`](recipes/layers/features/kubernetes-cli.yml).

The full architecture and migration notes live in [`docs/image-architecture.md`](docs/image-architecture.md).

# Build Flow

The workflow now publishes full core images before workstation builds run. Workstation recipes use `ghcr.io/myos-dev/core-full-*` as their base image, so the published workstation tags reflect the latest published full core tags.

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

Generic `myos` commands live in the shared core. Tenant commands are layered into the `core-full-*` and workstation images for both distros.

# Adding Images

1. Start from the smallest core image that matches the image's job.
2. Use `core-full-*` when the image needs tenant or OpenClaw host features.
3. Treat RamaLama as an Alma 10 full-core add-on until Alma 9 has a supported package source.
4. Use `nvidia.yml` for core/server NVIDIA support and add `nvidia-workstation.yml` only for workstation-specific NVIDIA extras.
5. Add workstation layers only for actual workstation products.
6. Keep optional capabilities in `recipes/layers/features/` instead of silently growing every image.

# Building as a VM

```bash
TMP=$(mktemp) && \
curl -fsSL https://raw.githubusercontent.com/myos-dev/myOS/stable/image.toml -o "$TMP" && \
sudo podman pull ghcr.io/myos-dev/workstation-alma10:latest && \
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
  ghcr.io/myos-dev/workstation-alma10:latest
rm -f "$TMP"
```

# Building ISO File

```bash
TMP=$(mktemp) && \
curl -fsSL https://raw.githubusercontent.com/myos-dev/myOS/stable/iso.toml -o "$TMP" && \
sudo podman pull ghcr.io/myos-dev/workstation-alma10:latest && \
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
  ghcr.io/myos-dev/workstation-alma10:latest
rm -f "$TMP"
```
