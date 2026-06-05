# Rootless Persistence

myOS keeps a sharp split between generic rootless prerequisites and admin-managed persistent services.

## Shared baseline on every image

Every image keeps only the generic pieces that belong to the cross-image core contract:

- Podman and Quadlet capability
- AMD/ROCm host-side access prerequisites
- shared helper libraries and cluster/runtime support that are not OpenClaw-specific

Current images do not ship a built-in per-user OpenClaw runtime.

## Persistent-user and tenant flows on images with the shared admin/operator overlay

The shared admin/operator overlay adds the admin-managed persistent service plane.

That includes:

- persistent-user enrollment and owner assignment
- baseline and owner quadlet templates
- tenant runtime, secrets, storage, and proxy helpers
- `openclaw-host`

This plane is for long-lived admin/operator flows and should stay documented as such.

## Why the split matters

- workstation stays a real desktop-first image family
- server is the default advanced host/operator role
- advanced platform-host tooling stays available without defining the public identity of every image
