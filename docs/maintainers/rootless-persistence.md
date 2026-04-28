# Rootless Persistence

myOS now has a sharper split between user-owned runtime and admin-managed persistent services.

## Plane 1: per-user runtime on every image

Every image ships the per-user `openquad` path.

That path is:

- optional
- inactive by default
- installed by the user on demand from the shipped template
- stored in user-owned locations under the user's home directory

This is the local self-service OpenClaw plane. The per-user Quadlet consumes the OpenQuad image (`ghcr.io/myos-dev/openquad:latest`) while preserving the existing `openclaw.service`, `openclaw` container name, and user-owned state directories.

The stock per-user template uses `host.containers.internal` for local Ollama and SearXNG because it targets the existing host-published rootless service pattern. A shared user-defined Podman network remains a supported customization when OpenQuad/OpenClaw and sibling services are all managed as local Quadlets on the same network.

## Plane 2: persistent-user and tenant flows on server/admin images

Server/admin images add the admin-managed persistent service plane.

That includes:

- persistent-user enrollment and owner assignment
- baseline and owner quadlet templates
- tenant runtime, secrets, storage, and proxy helpers
- `openclaw-host`

This plane is for long-lived admin/operator flows and should stay documented as such.

## Why the split matters

Before the refactor, the full payload and public docs made it easy to read every workstation as a platform host.

After the refactor:

- workstation stays a real desktop-first image family
- server is the default advanced host/operator role
- advanced platform-host tooling stays available without defining the public identity of every image
