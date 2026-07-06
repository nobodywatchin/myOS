# 0003: Current Compatibility Migration Baseline

- Status: accepted
- Date: 2026-07-05
- Decision owner: Noah / technical migration implementation
- Scope: CLI command namespace, registry namespace, runtime path compatibility, docs redirects, and environment-variable compatibility

## Decision

Current-native technical entrypoints are introduced while myOS-era entrypoints remain compatibility aliases.

The new primary surfaces are:

- `current` CLI wrapper
- `ghcr.io/pelagians/*` image references
- `/usr/share/current` installed runtime path
- `CURRENT_*` environment variables for new scripts and overrides
- `https://github.com/Pelagians/Current` documentation and repo URLs

The legacy surfaces remain supported during the transition:

- `myos` CLI wrapper
- `ghcr.io/myos-dev/*` image references when compatibility aliases are published
- `/usr/share/myos` installed runtime path and repository source path
- `MYOS_*` environment variables
- old GitHub docs/raw URLs where GitHub redirects or explicit notes cover the move

## Compatibility policy

`current` is the primary command. `myos` is a compatibility wrapper that execs `current`.

`ghcr.io/pelagians` is the primary registry namespace. `ghcr.io/myos-dev` remains a compatibility alias namespace and is populated by `scripts/sync-ghcr-compat-aliases.sh` when credentials are available.

`/usr/share/myos` remains the canonical source-tree path for payloads that already live there, including the image matrix. Installed systems expose `/usr/share/current` as a symlink to `/usr/share/myos` so new commands have a Current-native path without duplicating payloads.

`CURRENT_*` environment variables take precedence. Matching `MYOS_*` variables remain fallbacks for existing automation.

## Registry alias implementation

CI publishes images normally under the Current repository owner namespace. After successful stable-branch image builds, the compatibility alias job can copy each supported image tag from:

```text
ghcr.io/pelagians/<image>:latest
```

to:

```text
ghcr.io/myos-dev/<image>:latest
```

The alias job is intentionally skipped unless compatibility registry credentials are configured. This avoids breaking normal builds when the old namespace is not writable from the new repository.

Required secrets for alias publication:

- `MYOS_COMPAT_REGISTRY_USERNAME`
- `MYOS_COMPAT_REGISTRY_TOKEN`

## Docs redirect policy

Canonical docs links should use `https://github.com/Pelagians/Current`.

Old `myos-dev/myOS` docs and raw URLs are transition surfaces only. They may continue to work through GitHub repository redirects or legacy raw paths, but new docs should point to the Current repository and mention old names only as compatibility aliases.

## Rejected approaches

### Rename all source paths immediately

Rejected because source paths such as `files/base/runtime/usr/share/current/image-matrix.tsv` are consumed by scripts, docs, and installed systems. A symlink gives installed systems a Current-native path without duplicating source payloads.

### Drop old image references after the repo move

Rejected because existing installed systems and docs may still reference `ghcr.io/myos-dev/*`. Compatibility aliases protect rebases and manual `bootc switch` flows during the transition.

### Let `MYOS_*` and `CURRENT_*` conflict silently with legacy values winning

Rejected because new automation should be able to opt into Current-native naming without being overridden by old environment exports. `CURRENT_*` wins; `MYOS_*` remains fallback.

## Review triggers

Review this decision when:

- compatibility registry aliases are no longer pulled by active users
- source-tree paths are ready to move from `files/.../usr/share/myos` to `files/.../usr/share/current`
- `/etc/current` config paths are introduced
- `MYOS_*` compatibility variables are deprecated
- the old GitHub namespace stops redirecting reliably
