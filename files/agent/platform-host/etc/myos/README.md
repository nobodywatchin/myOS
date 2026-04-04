# myOS platform host scaffold

This image ships the host substrate for two kinds of rootless workloads:

- dedicated OpenClaw tenant service accounts under `/srv/tenants/<tenant>/`
- explicitly enrolled login users that are allowed to host persistent rootless services with lingering

Key paths:

- Shared RamaLama state lives under `/srv/models/ramalama`.
- Dedicated tenant app templates live under `/etc/myos/templates/apps/openclaw/`.
- Persistent login-user template buckets live under `/etc/myos/templates/persistent-users/`.
- Persistent-user state and the selected owner assignment live under `/etc/myos/persistent-users/`.
- Provisioning helpers live under `/usr/local/libexec/myos/`.
- Reverse proxy scaffolding lives under `/etc/nginx/conf.d/myos-platform.conf` and `/etc/myos/proxy/`.
- The supported operator interfaces are the `myos tenant-*`, `myos persistent-user-*`, `myos openclaw-host *`, and per-user `openquad` command surfaces.

This image does not bake live tenant accounts, real secrets, active tenant OpenClaw services, or globally lingered login users into the image.
