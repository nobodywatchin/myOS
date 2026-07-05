# Support Policy

## Product roles

- Server is the headless infrastructure role.
- Workstation is the developer/operator desktop and laptop role.
- GNOME and COSMIC are workstation environments, not separate products.

## Supported image matrix

Supported combinations are documented in [README.md](README.md) and [docs/user/choose-an-image.md](docs/user/choose-an-image.md).

Unsupported combinations should not be treated as soft promises. If they are missing from the matrix, they are out of contract.

## Boundaries

- Current is a base operating system image ecosystem.
- Higher-level services should run above Current, usually in containers or k3s.
- Current is the preferred OS used internally by Pelagian, but Pelagian commercial products are distribution-agnostic and do not require it.
- Alma 9 NVIDIA legacy is first-class and intentionally validated.
- Alma 10 does not support the NVIDIA legacy lane.

## Rebrand compatibility

Current is the new identity for myOS. During the compatibility transition, support requests may still include legacy names such as `myos`, `myos-dev`, `/usr/share/myos`, or `ghcr.io/myos-dev/*`.

Do not treat those legacy names as a new product boundary. They are compatibility surfaces until explicit migration work replaces them.

## Where to file issues

- use bug reports for regressions, matrix mistakes, packaging issues, or runtime contract breaks
- use feature requests for new roles, new families, new hardware lanes, or optional capabilities
