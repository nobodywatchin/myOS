<p align="center">
  <a href="https://github.com/myos-dev/myOS">
    <img src="files/base/branding/usr/share/pixmaps/system-logo-white.png" href="https://github.com/myos-dev/myOS" width=360 />
  </a>
</p>

# myOS &nbsp; [![bluebuild build badge](https://github.com/myos-dev/myOS/actions/workflows/build.yml/badge.svg)](https://github.com/myos-dev/myOS/actions/workflows/build.yml)

myOS is an opinionated BootC image ecosystem organized around the shared `core-base` substrate, clear per-distro layers, and workstation products that stay easy to extend.

# Image Progression

Both Alma 9 and 10 now follow one core tier plus workstation products:

- `core-full-alma9` / `core-full-alma10`
- `core-full-alma9-nvidia-open` / `core-full-alma10-nvidia-open`
- `core-full-alma9-nvidia-legacy`
- `workstation-alma9` / `workstation-alma10`
- `workstation-alma9-nvidia-open` / `workstation-alma10-nvidia-open`
- `workstation-alma9-nvidia-legacy`

NVIDIA streams are explicit:

- `-nvidia-open` uses the open kernel module path and is the default fit for newer supported GPUs.
- Alma 9 `-nvidia-legacy` is the older-GPU AI host lane. It pins the proprietary `nvidia-driver:580` stream and expects kernel-version-specific prebuilt `kmod-nvidia-*` packages on EL9 for Maxwell-, Pascal-, and similar legacy-supported GPUs.
- Alma 10 support in myOS is `-nvidia-open`.

For the legacy AI lane, keep the host driver and the AI userspace stack as separate decisions. The host stays on the pinned R580 proprietary branch, while older-GPU AI workloads should start from CUDA 12.6-class userspace stacks, such as PyTorch `cu126`, instead of assuming newer CUDA 13-era examples are the safest default for Maxwell/Pascal-class hardware.

`core-full-*` is the single full base tier. It includes tenant commands, persistent-user enrollment tooling, Cockpit admin services, and OpenClaw platform-host scaffolding for both distros.
Alma 10 carries the packaged RamaLama runtime in its distro-specific core layer, while Alma 9 keeps the same platform layout without the packaged RamaLama runtime.

For per-user OpenClaw on `core-full-*` and workstation images, the split is explicit:

- `openclaw` is the workload CLI that forwards into the already-running per-user runtime.
- `openquad` manages the rootless per-user `openclaw.service` Quadlet runtime.

Typical flow:

```bash
openquad start
openclaw onboard
openclaw chat
openquad status
openquad doctor
```

On accounts that predate the per-user Quadlet rollout, the first `openquad start`
will render the shipped `openclaw.container` into
`~/.config/containers/systemd/` and start the generated user service. Lingering across logout still requires
`myos persistent-user-enroll --user <name>`. The runtime config file itself lives at
`~/.local/share/openclaw/openclaw.json`.
On first-time setups, `openquad start` now leaves the runtime up in a safe
unconfigured mode so `openclaw onboard` can finish the initial setup without a
restart loop.

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
- `recipes/layers/shared` contains the small shared building blocks: `core-base`, `workstation-base`, `nvidia-common`, `nvidia-open`, and `nvidia-workstation`.
- `recipes/layers/alma9` and `recipes/layers/alma10` keep version differences explicit without spreading them across lots of tiny files.
- `modules/os-release-meta` runs first from `core-base`, before branding, and is the shared EL metadata source of truth. `core-base` now carries the shared EL Tailscale setup, common runtime payloads, and shared admin/platform-host scaffolding, while `workstation-base` carries the shared GNOME desktop baseline in addition to the broader workstation tooling and Flatpak defaults.
- `files/base`, `files/workstation`, and `files/agent` mirror those concerns in the payloads.

Kubernetes is still available as the opt-in feature layer at [`recipes/layers/features/kubernetes-cli.yml`](recipes/layers/features/kubernetes-cli.yml).

The full architecture and migration notes live in [`docs/image-architecture.md`](docs/image-architecture.md). The rootless persistence model lives in [`docs/rootless-persistence.md`](docs/rootless-persistence.md). Runtime ownership and path contracts live in [`docs/runtime-contracts.md`](docs/runtime-contracts.md). Validation guidance lives in [`docs/validation.md`](docs/validation.md). Current Alma 9 versus Alma 10 intentional drift is tracked in [`docs/alma-drift.md`](docs/alma-drift.md).

# Build Flow

The workflow now publishes full core images before workstation builds run. Workstation recipes use `ghcr.io/myos-dev/core-full-*` as their base image, so the published workstation tags reflect the latest published full core tags.

# Rootless Service Model

myOS keeps two rootless planes:

- persistent or background rootless services for dedicated tenant accounts and explicitly enrolled login users with lingering
- desktop or session rootless services for workstation-only helpers that are separate from the per-user OpenClaw runtime

See [`docs/rootless-persistence.md`](docs/rootless-persistence.md) for the full model, including owner-only versus per-user baseline units and the supported self-service Quadlet path.

# Update Flow

myOS disables the stock `bootc-fetch-apply-updates.service` and `bootc-fetch-apply-updates.timer` so hosts do not surprise-reboot on their own. Use `myos update-system` or `myos rebase`, then reboot on your own schedule or during a maintenance window.

# Tenant Operations

The supported OpenClaw operator workflow is exposed through the `myos` just wrapper instead of hand-editing tenant files under `/srv/tenants`. That flow remains the dedicated service-account path for persistent background OpenClaw hosting.

Common tenant flows:

```bash
myos tenant-create --tenant demo
myos tenant-secret-set --tenant demo --key OPENROUTER_API_KEY
myos tenant-configure --tenant demo --model openrouter/anthropic/claude-sonnet-4-5
myos tenant-start --tenant demo
myos tenant-status --tenant demo
```

For persistent login users, use the separate enrollment flow:

```bash
myos persistent-user-enroll --user alice
myos persistent-user-set-owner --user alice
myos persistent-user-install-quadlet --file ./my-api.container --enable
```

Generic `myos` commands live in the shared core. Tenant commands and persistent-user commands are layered into the `core-full-*` and workstation images for both distros.

# Adding Images

1. Start from `core-full-*`, which is now the single published core tier.
2. Use `core-full-*` when the image needs tenant or OpenClaw host features.
3. Treat RamaLama as an Alma 10 full-core add-on until Alma 9 has a supported package source.
4. Use `nvidia-open.yml` for shared core/server NVIDIA support, `alma9/nvidia-legacy.yml` only for the EL9 proprietary R580 older-GPU AI path, and `nvidia-workstation.yml` only for workstation-specific NVIDIA extras.
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

The old single-stream `*-nvidia` image names were replaced by explicit `*-nvidia-open` images, with Alma 9 also retaining `*-nvidia-legacy` for the supported proprietary older-GPU AI path.

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
