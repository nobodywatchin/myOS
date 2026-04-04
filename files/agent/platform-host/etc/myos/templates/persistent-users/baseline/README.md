# Baseline persistent-user role

Anything dropped into `baseline/quadlets/` is installed for every user enrolled
with `myos persistent-user-enroll --user <name>`.

Use this for per-user background helpers that should exist for every opted-in
user, with each user getting their own rootless instance and their own user
systemd lifecycle.

This bucket is for admin-managed baseline services that should exist for every
enrolled user.

The per-user OpenClaw runtime is intentionally not installed from this bucket.
Users provision their own `openclaw.container` explicitly through `openquad`.
