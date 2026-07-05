# 0001: Rebrand myOS as Current

- Status: accepted
- Date: 2026-07-05
- Decision group: Pelagian founders
- Scope: product strategy, branding, messaging, documentation, and identity
- Technical migration status: proposed separately; compatibility must be preserved until explicit implementation work lands

## Decision

myOS is being rebranded as **Current**.

Current is the flagship open-source operating system project of the Pelagian ecosystem. It remains an independent open-source project that stands on its own outside Pelagian commercial products.

This is not a rewrite of the project and not a technical redesign. The existing bootc image architecture, role-first image matrix, upstream distribution lanes, runtime contracts, validation approach, and layer ownership model remain the foundation.

## Meaning of the name

Current refers to **ocean currents**, not electrical current.

The identity should communicate:

- movement
- momentum
- reliability
- stability beneath motion
- modern infrastructure
- minimalism
- engineering discipline

The brand should not feel flashy, cyberpunk, or AI-hype driven.

## Product identity

Current is an ecosystem of immutable bootc-based Linux images.

Current is:

- container-first
- built close to upstream distributions
- distribution-agnostic in philosophy, beginning with supported Fedora and AlmaLinux lanes
- opinionated, but intentionally lightweight
- designed for developers first, especially AI developers
- useful across workstations, servers, labs, and clusters

Current does not try to replace Fedora, AlmaLinux, Debian, Arch, Universal Blue, or other Linux ecosystems. It asks what those systems can feel like when composed today around image-native updates and container-native workflows.

## Relationship to Pelagian

Current is part of the Pelagian ecosystem and is the preferred operating system used internally by Pelagian.

Current is not required for Pelagian commercial products. Nereus and Nyra are Kubernetes-native and distribution-agnostic. If Pelagian disappeared tomorrow, Current should still make sense as an independent open-source project.

## What stays the same

The rebrand preserves the strongest existing ideas from myOS:

- bootc-based immutable system images
- role-first image architecture
- workstation and server roles under one operating model
- GNOME and COSMIC as workstation environments, not separate products
- explicit supported image matrix
- explicit GPU and hardware lanes
- deliberate update, rebase, and rollback behavior
- Podman and local container workflows
- k3s host capability where appropriate
- Flatpak split between user-owned apps and curated system apps on workstations
- practical local AI/runtime readiness without preloaded models or bundled hosted AI services
- close-to-upstream distribution layering
- BlueBuild as the underlying image build framework

## What changes

Public-facing messaging should move from the old personal/project framing to the Current identity.

Use:

- Current
- image-native Linux
- container-first operating system images
- practical defaults
- close to upstream
- stable beneath motion
- developer-first
- AI-ready without AI bloat

Avoid:

- treating Current as a Fedora/AlmaLinux replacement
- framing the project as a Universal Blue competitor
- AI OS hype
- cyberpunk language
- electrical-current metaphors
- implying Pelagian commercial products require Current

## Compatibility policy

Branding and documentation can begin using Current immediately.

Technical namespaces must not be renamed casually as part of a prose-only branding pass. Existing users, scripts, registry references, and image flows may depend on legacy names such as:

- `myos` command wrappers
- `ghcr.io/myos-dev/*` image references
- `raw.githubusercontent.com/myos-dev/myOS/*` matrix/config references
- `/usr/share/myos`
- `/etc/myos`
- `MYOS_*` environment variables

A later technical migration should introduce Current-native names with compatibility aliases, redirects, or transition documentation.

## Migration sequence

1. Update public documentation and messaging to use Current.
2. Preserve technical commands and registry references until replacements exist.
3. Add compatibility notes where legacy names remain visible.
4. Introduce Current-native CLI, registry, filesystem, and environment namespaces through explicit implementation work.
5. Retire legacy names only after users have a documented migration path.

## Rejected approaches

### Full technical rename in the branding pass

Rejected because it would risk breaking image references, update/rebase flows, validation scripts, and installed-system commands without adding product clarity.

### Treating Current as a new project

Rejected because the existing architecture and documentation are already strong. Current is the evolution of myOS, not a replacement project.

### Positioning Current as a competitor to upstream distributions

Rejected because Current depends on and respects upstream distributions. The project should explain its design philosophy and let differences speak for themselves.

## Review triggers

Review this decision when:

- the GitHub repository or organization namespace is renamed
- GHCR image namespaces change
- a `current` CLI command is added
- `/usr/share/current` or `/etc/current` paths are introduced
- Current receives a standalone public website
- Debian, Arch, or additional distribution families are added to the supported image matrix
