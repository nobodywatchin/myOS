# myOS platform host scaffold

This image ships the host substrate for a multi-tenant OpenClaw deployment.

- Shared RamaLama state lives under `/srv/models/ramalama`.
- Shared RamaLama unit templates live under `/etc/myos/ramalama/`.
- Tenant templates live under `/etc/myos/templates/openclaw/`.
- Provisioning helpers live under `/usr/local/libexec/myos/`.
- Reverse proxy scaffolding lives under `/etc/nginx/conf.d/myos-platform.conf` and `/etc/myos/proxy/`.

This image does not bake live tenant accounts, real secrets, or active tenant OpenClaw services into the image.
