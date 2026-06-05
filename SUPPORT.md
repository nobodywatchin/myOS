# Support Policy

## Product roles

- Workstation is the flagship role.
- Server is the headless admin/operator role, while the shared admin/operator overlay is available across the matrix.
- Console is an Alma 10 core-only preview role.

## Supported image matrix

Supported combinations are documented in [README.md](README.md) and [docs/user/choose-an-image.md](docs/user/choose-an-image.md).

Unsupported combinations should not be treated as soft promises. If they are missing from the matrix, they are out of contract.

## Boundaries

- Tenant tooling, persistent-user administration, and `openclaw-host` are advanced flows exposed through the shared admin/operator overlay.
- Built-in per-user OpenClaw is out of contract for current images.
- Alma 9 NVIDIA legacy is first-class and intentionally validated.
- Alma 10 does not support the NVIDIA legacy lane.

## Where to file issues

- use bug reports for regressions, matrix mistakes, packaging issues, or runtime contract breaks
- use feature requests for new roles, new families, new hardware lanes, or optional capabilities
