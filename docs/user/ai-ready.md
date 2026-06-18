# AI-Ready

In myOS, AI-ready means local host/runtime capability without forced platform identity.

It does not mean every image ships with preloaded models, hosted services, or a built-in per-user agent runtime.

## What core images include

Shared AI-adjacent host support includes:

- host Vulkan tooling where supported by the image lane
- AMD/KFD host-side access prerequisites such as the shared DRM/KFD `uaccess` rule
- generic Podman and Quadlet capability
- shared runtime helpers needed for local container workflows

ROCm userspace is platform-lane-specific. It is included where the current platform lane supports it, currently the Alma 10 and Fedora lanes. Do not assume every supported image includes the same ROCm package set.

Current images do not ship a built-in per-user OpenClaw runtime, command wrapper, or user Quadlet template.

## What the shared admin/operator overlay adds

The shared admin/operator overlay adds:

- tenant tooling
- persistent-user admin tooling
- `openclaw-host`
- related platform-host scaffolding

`myos persistent-user-enroll --user <name>` also adds the enrolled login user to `render` and `video`, which is the repo-managed path for headless or long-lived rootless GPU workloads.

Those are real advanced capabilities, but they are not the default identity of every workstation image.

For the concrete admin steps to grant a user local GPU access for host Vulkan or rootless GPU containers, see [hardware.md](hardware.md).

## What myOS does not do

- It does not force hosted OpenClaw flows on ordinary workstation users.
- It does not preload models as branding theater.
- It does not pretend every image is an operator appliance.
- It does not automatically pass `/dev/dri` or `/dev/kfd` through every rootless workload.
- It does not make ROCm support identical across every platform lane.

Explicit device-aware container config is still required for local GPU backends.
