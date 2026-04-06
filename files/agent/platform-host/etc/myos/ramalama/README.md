# Shared RamaLama substrate

Optional Alma 10-only host feature.

`modelsvc` is the dedicated host account for shared inference.

- Shared model state: `/srv/models/ramalama`
- Instance env files: `/etc/myos/ramalama/models/*.env`
- Systemd template: `myos-ramalama@.service`
- Launcher: `/usr/local/libexec/myos/ramalama-serve`

The shipped service is conservative by default:

- it expects loopback binding configuration
- it refuses to start if the installed RamaLama release does not expose a host-binding flag and `RAMALAMA_ALLOW_WIDE_BIND=1` is not set
- it is not enabled automatically
