# Release Policy

myOS publishes a small image matrix with explicit contracts.

## Stability policy

- Alma is treated as the boring stable base.
- Role, tier, distro, and hardware lanes are all explicit supported contracts.
- Alma 9 NVIDIA legacy remains a first-class supported lane.

## Update policy

- published images are meant to be updated intentionally, not auto-applied behind your back
- rebases between supported images are part of the normal workflow
- workstation-family rebases are expected to preserve the correct display-manager ownership on boot

## Support boundaries

- Workstation is the flagship user-facing role.
- Server is the full-tier admin/operator role.
- Console is currently an Alma 10 core-only preview role.
- Full-tier tenant and hosted OpenClaw flows are supported as advanced functionality, not the primary story of every image.

Repository-wide support expectations are documented in [SUPPORT.md](../../SUPPORT.md).
