# Support Policy

## Product roles

- Server is the headless infrastructure role.
- Workstation is the operator desktop and laptop role.
- GNOME and COSMIC are workstation environments, not separate products.

## Supported image matrix

Supported combinations are documented in [README.md](README.md) and [docs/user/choose-an-image.md](docs/user/choose-an-image.md).

Unsupported combinations should not be treated as soft promises. If they are missing from the matrix, they are out of contract.

## Boundaries

- myOS is a base operating system image project.
- Higher-level services should run above myOS, usually in containers or k3s.
- Alma 9 NVIDIA legacy is first-class and intentionally validated.
- Alma 10 does not support the NVIDIA legacy lane.

## Where to file issues

- use bug reports for regressions, matrix mistakes, packaging issues, or runtime contract breaks
- use feature requests for new roles, new families, new hardware lanes, or optional capabilities
