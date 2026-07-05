# files/

This tree contains payloads copied into images by BlueBuild `files` modules.

Keep this tree boring. It should contain image payloads only: branding, runtime defaults, service units, helper scripts, desktop environment files, hardware-lane support files, and packaging policy.

Top-level payload groups:

- `base/`: shared runtime files, image matrix, branding, ROCm/Vulkan host config, and common OS metadata
- `ceph-host/`: Ceph host prerequisites copied by the Ceph feature layer
- `cosmic/`: COSMIC workstation environment payloads
- `dnf/`: repository and DNF configuration payloads
- `flatpak/`: workstation Flatpak policy, remotes, portal integration, and cleanup helpers
- `gnome/`: GNOME workstation environment payloads
- `justfiles/`: user-facing `current` Just command surface
- `k3s/`: k3s systemd units and host integration files
- `nvidia/`: NVIDIA lane support payloads and PMDA registration helper
- `scripts/`: image-build helper scripts consumed by recipe layers
- `workstation/`: shared workstation helper scripts and display-manager reconciliation

Do not put hosted application platforms, tenant runtimes, or product-specific services in this tree. Those belong above Current, usually in containers or k3s.
