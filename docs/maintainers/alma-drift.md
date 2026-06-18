# Alma Drift

These are the intentional lane differences that remain between the Alma distro lanes.

## Alma 9

- supports only the NVIDIA 580 compatibility lane in the public matrix
- supports `server`, `gnome`, and `cosmic` environments on that lane
- does not support standard images or `nvidia-open`

The internal layer file now matches the public lane naming: `recipes/layers/alma9/nvidia-580.yml`.

## Alma 10

- is the stable baseline lane
- supports `server`, `gnome`, and `cosmic` environments
- supports standard images and `nvidia-open`
- does not support the NVIDIA 580 compatibility lane

## Shared across both Alma lanes

- workstation remains available with GNOME and COSMIC
- Alma-family repository setup, including EPEL/CRB enablement and subscription-manager cleanup, belongs in `recipes/layers/alma/core.yml`
- shared k3s, Ceph host, Cockpit, Podman, Vulkan, and base runtime support stay in the shared contracts where possible
- Alma-version ROCm userspace drift stays in the matching Alma version layer

When adding new divergence, prefer `recipes/layers/alma/` for Alma-family drift and `recipes/layers/alma9/` or `recipes/layers/alma10/` for version-specific drift instead of weakening the shared contracts.
