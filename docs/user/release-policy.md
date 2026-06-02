# Release Policy

myOS publishes a small image matrix with explicit contracts.

## Stability policy

- `alma10` is the stable baseline lane.
- `fedora` is the edge lane.
- `alma9` is reserved for the legacy NVIDIA 580 compatibility lane.
- role, environment, platform, and driver lanes are all explicit supported contracts.

## Update policy

- published images are meant to be updated intentionally, not auto-applied behind your back
- rebases between supported images are part of the normal workflow
- workstation-environment rebases are expected to preserve the correct display-manager ownership on boot

## Support boundaries

- Workstation is the flagship user-facing role.
- Server is the headless admin/operator lane.
- Tenant and hosted OpenClaw flows are supported advanced functionality, not the primary story of every image.

Repository-wide support expectations are documented in [SUPPORT.md](../../SUPPORT.md).
