# Current Compatibility Migration

Current is the public identity and primary technical namespace.

## Primary names

Use these for new docs, scripts, and examples:

- CLI: `current`
- Command payload path: `/usr/share/current/just`
- Registry namespace: `ghcr.io/pelagians`
- Environment variables: `CURRENT_*`
- Repository/docs: `https://github.com/Pelagians/Current`

## Removed command compatibility

No `myos` CLI wrapper is installed.

Use:

```bash
current rebase
current update-system
```

Do not document new user flows with `myos rebase`, `myos update-system`, or other `myos` command examples.

## Remaining transition aliases

These remain compatibility or transition surfaces outside the command namespace:

- Registry namespace: `ghcr.io/myos-dev` when alias publishing is enabled
- Runtime data path: `/usr/share/myos` for payloads not yet moved, such as the image matrix metadata path
- Environment variables: selected `MYOS_*` variables as fallbacks for existing automation
- Old docs/raw URLs that GitHub redirects or compatibility notes still cover

## Registry

New examples should use:

```bash
sudo bootc switch ghcr.io/pelagians/alma10-gnome:latest
```

Legacy image references remain aliases when compatibility publishing is enabled:

```bash
sudo bootc switch ghcr.io/myos-dev/alma10-gnome:latest
```

`scripts/sync-ghcr-compat-aliases.sh` copies supported tags from `ghcr.io/pelagians` to `ghcr.io/myos-dev` when old-namespace credentials are available.

## Runtime paths

Justfile command payloads live under `/usr/share/current/just`.

The image matrix and some internal runtime metadata still use `/usr/share/myos` until a separate data-path migration moves those consumers together.

## Environment variables

Current-native variables win. Legacy variables are fallback only where explicitly supported.

Examples:

- `CURRENT_IMAGE_MATRIX_URL` falls back to `MYOS_IMAGE_MATRIX_URL`
- `CURRENT_REGISTRY_NAMESPACE` falls back to `MYOS_REGISTRY_NAMESPACE`
- `CURRENT_INSTALLER_PAYLOAD_REF` falls back to `MYOS_INSTALLER_PAYLOAD_REF`
- `CURRENT_INSTALLER_CONFIG` falls back to `MYOS_INSTALLER_CONFIG`

## Docs and redirects

Canonical docs links should use `https://github.com/Pelagians/Current`.

Old `myos-dev/myOS` URLs may still appear in user reports, package metadata, or automation. Treat them as redirect/compatibility surfaces, not as a separate product name.
