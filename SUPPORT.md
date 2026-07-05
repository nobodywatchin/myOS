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
- Current is maintained by Pelagian and used internally by Pelagian, but it stands alone as an open-source project.
- Alma 9 NVIDIA 580 is first-class and intentionally validated.
- Alma 10 does not support the NVIDIA 580 lane.

## Where to file issues

- use bug reports for regressions, matrix mistakes, packaging issues, or runtime contract breaks
- use feature requests for new roles, new families, new hardware lanes, or optional capabilities
