# Release Policy

myOS publishes a small image matrix with explicit contracts.

## Stability policy

- `alma10` is the stable baseline lane.
- `fedora` is the edge lane for newer userspace and hardware enablement.
- `alma9` is reserved for the legacy NVIDIA 580 compatibility lane.
- Role, environment, platform, and driver lanes are all explicit supported contracts.

## Update policy

- Published images are meant to be updated intentionally, not auto-applied behind your back.
- Rebases between supported images are part of the normal workflow.
- Workstation-environment rebases are expected to preserve the correct display-manager ownership on boot.
- The supported image matrix is the source of truth for published tags and `myos rebase`.

## Support boundaries

- Server and lab infrastructure are the primary targets.
- Workstation is the operator desktop and laptop lane for the same image-based system model.
- GNOME and COSMIC are workstation environments, not separate product lines.
- Tenant, persistent-user, and hosted OpenClaw flows are supported advanced functionality, not the primary story of every image.
- Images outside the published matrix are unsupported unless they are added to the manifest and validation flow.

Repository-wide support expectations are documented in [SUPPORT.md](../../SUPPORT.md).
