# Current Compatibility Migration

Current is the public identity and primary technical namespace. myOS-era names remain compatibility aliases during the transition.

## Primary names

Use these for new docs, scripts, and examples:

- CLI: `current`
- Registry namespace: `ghcr.io/pelagians`
- Installed runtime path: `/usr/share/current`
- Environment variables: `CURRENT_*`
- Repository/docs: `https://github.com/Pelagians/Current`

## Compatibility aliases

These remain supported for existing users and automation:

- CLI: `myos`
- Registry namespace: `ghcr.io/myos-dev`
- Installed/source runtime path: `/usr/share/myos`
- Environment variables: `MYOS_*`
- Old docs/raw URLs that GitHub redirects or compatibility notes still cover

## CLI

`current` is the primary wrapper. `myos` remains installed as a compatibility alias and execs `current`.

Prefer:

```bash
current rebase
current update-system
```

Old commands still work:

```bash
myos rebase
myos update-system
```

## Registry

New examples should use:

```bash
sudo bootc switch ghcr.io/pelagians/alma10-gnome:latest
```

Legacy references are aliases when compatibility publishing is enabled:

```bash
sudo bootc switch ghcr.io/myos-dev/alma10-gnome:latest
```

`scripts/sync-ghcr-compat-aliases.sh` copies supported tags from `ghcr.io/pelagians` to `ghcr.io/myos-dev` when old-namespace credentials are available.

## Runtime paths

Installed systems expose `/usr/share/current` as a symlink to `/usr/share/myos`.

The repository still keeps shared payloads under `files/.../usr/share/myos` to avoid duplicating the image matrix and Justfile payloads during the migration.

## Environment variables

Current-native variables win. Legacy variables are fallback only.

Examples:

- `CURRENT_IMAGE_MATRIX_URL` falls back to `MYOS_IMAGE_MATRIX_URL`
- `CURRENT_REGISTRY_NAMESPACE` falls back to `MYOS_REGISTRY_NAMESPACE`
- `CURRENT_INSTALLER_PAYLOAD_REF` falls back to `MYOS_INSTALLER_PAYLOAD_REF`
- `CURRENT_INSTALLER_CONFIG` falls back to `MYOS_INSTALLER_CONFIG`

## Docs and redirects

Canonical docs links should use `https://github.com/Pelagians/Current`.

Old `myos-dev/myOS` URLs may still appear in user reports, package metadata, or automation. Treat them as redirect/compatibility surfaces, not as a separate product name.
