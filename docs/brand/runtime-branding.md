# Runtime Branding

Phase 2 introduced Current as the runtime-visible display identity. Phase 3 adds Current-native technical entrypoints while preserving myOS compatibility aliases.

## Changes in Phase 2

Phase 2 may safely update product-visible branding surfaces:

- README wordmark
- docs brand assets
- `os-release` display metadata: `NAME`, `PRETTY_NAME`, and `VENDOR_NAME`
- fastfetch default branding
- fastfetch Current preset and logo

These are display identity surfaces, not command, path, registry, or image-tag migrations.

## Compatibility surfaces

Phase 3 makes these Current-native surfaces primary:

- `current` command wrapper
- `/usr/share/current/just` command payload path
- `CURRENT_*` environment variables
- `ghcr.io/pelagians/*` image references
- `https://github.com/Pelagians/Current` docs links

These non-command legacy surfaces may remain during the transition:

- `/usr/share/myos` internal data paths not yet migrated
- `/etc/myos` config scaffold
- `MYOS_*` environment variables
- `ghcr.io/myos-dev/*` image references when aliases are published
- existing image tags such as `alma10-gnome`

## Fastfetch transition

Phase 2 adds a `current` fastfetch preset and logo.

The default shell alias now points to:

```bash
fastfetch -c current
```

The legacy `myos` preset and logo remain as compatibility aliases, but they render Current branding.

## Bitmap assets

The repo still contains legacy bitmap assets such as PNG favicon, Plymouth watermark, and system-logo files. Those require a dedicated asset regeneration pass so dimensions, transparency, and boot/desktop consumers can be verified separately.

Do not remove those files in Phase 2.

## Phase 3 migration

Phase 3 introduced the registry, path, docs, and environment compatibility baseline. Phase 4 made `current` the only CLI and moved the Justfile command payload to `/usr/share/current/just`. See [docs/compatibility.md](../compatibility.md), [0003: Current Compatibility Migration Baseline](../decisions/0003-current-compatibility-migration.md), and [0004: Current CLI Primary, No myOS Command Alias](../decisions/0004-current-cli-primary-no-myos-command-alias.md).

`/etc/current` is not introduced yet. `/etc/myos` remains the compatibility config scaffold until a real Current-native config consumer exists.
