# AI-Ready

In myOS, AI-ready means local capability without forced platform identity.

## What core images include

- ROCm userspace
- host Vulkan tooling (`mesa-vulkan-drivers`, `vulkan-loader`, and `vulkaninfo`)
- the `openquad` command
- the shipped per-user OpenClaw Quadlet template, rendered with `ghcr.io/myos-dev/openquad:latest` by default
- user-owned runtime paths under the user's home directory

The per-user runtime stays inert until the user chooses to install and start it. It publishes the OpenClaw gateway on `127.0.0.1:18789` and defaults local Ollama/SearXNG endpoints to `host.containers.internal`, matching the current rootless Podman flow where those sibling services are host-published rather than joined to a managed MyOS bridge network.

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
- it does not automatically pass `/dev/dri` or `/dev/kfd` through every shipped
  rootless OpenClaw Quadlet; explicit device-aware container config is still
  required for local GPU backends
