# Baseline persistent-user role

Anything dropped into `baseline/quadlets/` is installed for every user enrolled
with `myos persistent-user-enroll --user <name>`.

Use this for per-user background helpers that should exist for every opted-in
user, with each user getting their own rootless instance and their own user
systemd lifecycle.

This bucket now ships the per-user `openclaw.container` runtime template used
by `openquad` and the host-side `openclaw` CLI wrapper.
