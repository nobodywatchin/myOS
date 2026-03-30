# Persistent-user state

myOS writes admin-managed persistent-user state here.

- `owner.conf` records the one selected owner account.
- `users/<name>/baseline.files` and `baseline.units` track which baseline templates were installed for an enrolled user.
- `users/<name>/owner.files` and `owner.units` track which owner-only templates were installed for that same user.

These files let `myos persistent-user-*` reconcile admin-managed background services without overwriting user self-service Quadlets in `~/.config/containers/systemd/`.
