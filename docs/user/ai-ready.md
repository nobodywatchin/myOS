# AI-Ready

In myOS, AI-ready means local host/runtime capability without turning the OS image into a hosted service platform.

It does not mean every image ships with preloaded models, hosted services, or a built-in application runtime.

## What core images include

Shared local-runtime support includes:

- host Vulkan tooling where supported by the image lane
- generic Podman capability
- k3s host capability for users who want Kubernetes on their own machines
- shared runtime helpers needed for local container workflows

ROCm userspace is platform-lane-specific. It is included where the current platform lane supports it, currently the Alma 10 and Fedora lanes. Do not assume every supported image includes the same ROCm package set.

## What myOS does not do

- It does not ship a hosted application platform.
- It does not preload models as branding theater.
- It does not pretend every image is an appliance for a specific service.
- It does not automatically pass GPU devices through every rootless workload.
- It does not make ROCm support identical across every platform lane.

Explicit device-aware container config is still required for local GPU backends.

Higher-level services belong above myOS, usually in containers or k3s.
