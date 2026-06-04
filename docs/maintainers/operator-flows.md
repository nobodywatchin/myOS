# Operator Flows

These are advanced shared flows.

## Tenant tooling

Tenant commands remain the supported interface for hosted OpenClaw-style service accounts.

Examples:

```bash
myos tenant-create --tenant demo
myos tenant-configure --tenant demo --model openrouter/anthropic/claude-sonnet-4-5
myos tenant-secret-set --tenant demo --key OPENROUTER_API_KEY
myos tenant-start --tenant demo
myos tenant-status --tenant demo
```

## Persistent-user administration

Persistent-user tooling remains the supported admin path for long-lived rootless service ownership.

Examples:

```bash
myos persistent-user-enroll --user alice
myos persistent-user-set-owner --user alice
myos persistent-user-install-quadlet --file ./my-api.container --enable
```

## Hosted OpenClaw wrapper

`myos openclaw-host` remains available on server/admin images for the owner-friendly hosted service path.

Examples:

```bash
myos openclaw-host enable --user alice --model openrouter/anthropic/claude-sonnet-4-5
myos openclaw-host secret-set --key OPENROUTER_API_KEY
myos openclaw-host start
```

## Boundary to keep clear

These flows are supported, but they should stay documented as advanced server/admin behavior.

They are not the defining public identity of the workstation images.
