# Hardware

myOS makes GPU policy explicit instead of hiding it behind one generic image.

## Standard lane

Images without a driver suffix are the standard lane.

Choose them when you do not need NVIDIA-specific packaging.

## NVIDIA open lane

Choose `nvidia-open` for newer supported NVIDIA GPUs on supported Alma 10 and Fedora 43 images.

## NVIDIA 580 lane

Choose `nvidia-580` only on Alma 9.

That lane is intentionally pinned to the proprietary `nvidia-driver:580` stream for supported older GPUs. It is not available on Alma 10 or Fedora 43.

## PCP monitoring

All images include Performance Co-Pilot with `pmcd` for live metrics and `pmlogger` for local history.

NVIDIA images also include the NVIDIA GPU PMDA and register it automatically on boot so NVIDIA metrics are available through PCP without a manual PMDA install step.

## AMD and ROCm

ROCm userspace stays in the shared core contract across all roles.

Host Vulkan tooling ships from the same shared core contract, so every image gets the same AMD/Intel host-side baseline.

For actual device-node access:

- local graphical sessions can use the DRM/KFD `uaccess` ACL path
- headless or long-lived rootless service users on server images should use `myos persistent-user-enroll --user <name>`, which adds `render` and `video`

The shipped OpenClaw and persistent-user helpers still do not auto-inject `/dev/dri` or `/dev/kfd` into every rootless container; local GPU containers must still opt into explicit device pass-through.

## Admin steps for GPU access

If an admin wants a login user to run host Vulkan tools or rootless GPU-aware containers, use one of these paths.

### Server images: supported myOS enrollment path

Use this when the user is meant to host long-lived rootless workloads:

```bash
sudo myos persistent-user-enroll --user alice
```

That path:

- enables lingering
- provisions subuid/subgid
- installs the managed persistent-user baseline
- adds the user to `render` and `video`

### Any image: manual group-based path

Use this when the user only needs local GPU device access and does not need the full persistent-user flow:

```bash
sudo usermod -aG render,video alice
```

After either path, have the user fully log out and log back in before testing.
A new login session is required before the updated supplementary groups apply.

### Quick verification

As the target user, verify the basics:

```bash
id
ls -l /dev/dri/renderD128
vulkaninfo --summary
podman info --format '{{.Host.OCIRuntime.Name}}'
```

Useful expectations:

- `id` should list `render` and `video` for group-based access
- `/dev/dri/renderD128` should be readable and writable by the user or by a session ACL
- `vulkaninfo --summary` should show the real GPU instead of only `llvmpipe`
- rootless GPU container flows are safest when Podman is using `crun`

### Important container note

User/group permissions are only the host-side prerequisite. A rootless Vulkan backend still needs explicit device pass-through in the container invocation or Quadlet. Membership in `render`/`video` alone does not make `/dev/dri` or `/dev/kfd` appear inside the container.
