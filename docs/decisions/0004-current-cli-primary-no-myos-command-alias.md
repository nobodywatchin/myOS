# 0004: Current CLI Primary, No myOS Command Alias

- Status: accepted
- Date: 2026-07-05
- Decision owner: Noah / technical migration implementation
- Scope: CLI command namespace and Justfile command payload path
- Supersedes: CLI alias portions of [0003: Current Compatibility Migration Baseline](0003-current-compatibility-migration.md)

## Decision

Current does not ship a `myos` CLI compatibility command.

The command namespace is:

- `/usr/local/bin/current` is the only project CLI wrapper.
- `/usr/share/current/just` is the Justfile command payload source of truth.
- `/usr/share/myos/just` is removed.
- `/usr/local/bin/myos` is removed.

## Rationale

The user base is small and aware of the rename. Carrying a `myos` command alias makes the new `current` CLI look like a thin wrapper over the old namespace and preserves the wrong mental model.

A clean break is simpler:

```bash
current rebase
current update-system
```

instead of documenting both `current` and `myos` command forms.

## What remains compatible

This decision only removes command compatibility.

The following non-command transition surfaces can remain until separately migrated:

- `ghcr.io/myos-dev/*` image aliases when alias publishing is enabled
- selected `MYOS_*` fallback variables for existing automation
- internal `/usr/share/myos` runtime data paths that have not yet moved together

## Rejected approach

### Keep `myos` as a wrapper that execs `current`

Rejected because it preserves old command muscle memory and makes the new command look secondary.

### Make `/usr/share/current` a symlink to `/usr/share/myos`

Rejected for the command payload because Current should own the Justfile source of truth. The old path should not be the backing store for new commands.

## Review triggers

Review this if external users need a temporary `myos` package-level shim or if the remaining `/usr/share/myos` data paths are migrated to `/usr/share/current`.
