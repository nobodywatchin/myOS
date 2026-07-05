# Runtime Branding

Current runtime-visible branding should use the Current name and command namespace.

## Current surfaces

- `os-release` display metadata: `NAME`, `PRETTY_NAME`, and `VENDOR_NAME`
- fastfetch default preset and logo
- `current` command wrapper
- `/usr/share/current/just` command payload path
- `ghcr.io/pelagians/*` image references
- `https://github.com/Pelagians/Current` docs links

## Fastfetch

The default shell alias uses:

```bash
fastfetch -c current
```

The active preset and logo are:

```text
/usr/share/fastfetch/presets/current.jsonc
/usr/share/fastfetch/logos/current
```

## Bitmap assets

The repo may still contain bitmap assets such as PNG favicon, Plymouth watermark, and system-logo files. Regenerate those in a dedicated asset pass so dimensions, transparency, and boot/desktop consumers can be verified.
