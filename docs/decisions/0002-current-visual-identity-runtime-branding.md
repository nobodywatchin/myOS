# 0002: Current Visual Identity and Runtime Branding Baseline

- Status: accepted
- Date: 2026-07-05
- Decision group: Pelagian founders
- Scope: visual identity, README presentation, runtime-visible display branding, and compatibility boundaries

## Decision

Current receives a Phase 2 visual identity baseline.

This baseline introduces:

- a simple circular ocean-current mark
- color and white SVG wordmarks
- brand guidance under `docs/brand/`
- README wordmark usage
- Current fastfetch preset and logo
- Current `os-release` display metadata

This does not change the bootc image architecture, image matrix, registry namespace, command namespace, runtime filesystem namespace, or installer/update contracts.

## Rationale

The Phase 1 rebrand established Current's product strategy and messaging. Phase 2 makes that identity visible without turning the rebrand into a technical namespace migration.

The mark intentionally evolves the old myOS circular logo gesture rather than replacing it with an unrelated symbol. The design should communicate movement, momentum, and stability beneath motion while avoiding cyberpunk, AI-hype, or electrical-current associations.

## Runtime branding boundary

These display surfaces are allowed to say Current now:

- README logo and docs assets
- fastfetch preset/logo
- `os-release` `NAME`, `PRETTY_NAME`, and `VENDOR_NAME`

These compatibility surfaces remain unchanged until a later migration:

- `myos` command
- `/usr/share/myos`
- `/etc/myos`
- `MYOS_*` environment variables
- `ghcr.io/myos-dev/*` image references
- existing image tags

## Fastfetch policy

The `current` fastfetch preset is the new default.

The legacy `myos` fastfetch preset remains available as a compatibility alias and renders Current branding.

## Bitmap asset policy

Legacy bitmap assets are not removed in this phase. PNG/favicon/Plymouth replacement should happen in a later asset regeneration pass with dimension and consumer verification.

## Review triggers

Review this decision when:

- bitmap assets are regenerated
- the `current` command wrapper is introduced; resolved by [0004](0004-current-cli-primary-no-myos-command-alias.md)
- runtime paths move from `/usr/share/myos` to `/usr/share/current`
- registry namespaces move from `myos-dev` to a Current-native namespace
- a public website is added
