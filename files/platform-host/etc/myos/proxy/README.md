# Reverse proxy scaffold

- nginx is the baked reverse proxy substrate.
- The stock config remains loopback-only at `127.0.0.1:8088`.
- Reviewed tenant route fragments belong in `/etc/myos/proxy/tenants/*.conf`.
- Example route fragments render to `/etc/myos/proxy/tenants/<tenant>.conf.example`.
