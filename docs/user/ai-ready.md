# AI-Ready

In myOS, AI-ready means local capability without forced platform identity.

## What core images include

- ROCm userspace
- host Vulkan tooling (`mesa-vulkan-drivers`, `vulkan-loader`, and `vulkaninfo`)
- AMD/ROCm host-side access prerequisites such as the shared DRM/KFD `uaccess` rule
- generic Podman and Quadlet capability

Current images do not ship a built-in per-user OpenClaw runtime, command wrapper, or user Quadlet template.

## What full images add

- tenant tooling
- persistent-user admin tooling
- `openclaw-host`
- related platform-host scaffolding

`myos persistent-user-enroll --user <name>` now also adds the enrolled login user
to `render` and `video`, which is the repo-managed path for headless or
long-lived rootless GPU workloads on full images.

Those are real advanced capabilities, but they are not the default identity of every workstation image anymore.

For the concrete admin steps to grant a user local GPU access for host
Vulkan or rootless GPU containers, see [docs/user/hardware.md](hardware.md).

## What myOS does not do

- it does not force hosted OpenClaw flows on ordinary workstation users
- it does not preload models as branding theater
- it does not pretend every image is an operator appliance
- it does not automatically pass `/dev/dri` or `/dev/kfd` through every rootless
  workload; explicit device-aware container config is still required for local
  GPU backends
