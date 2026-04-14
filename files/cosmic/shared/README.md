# cosmic/shared/

This tree contains COSMIC-only session payloads layered only by the COSMIC
workstation images.

Current usage is intentionally small:

- `usr/share/myos/workstation/desktop.env` publishes the active desktop marker
  consumed by the shared workstation display-manager reconciliation helper
- `etc/greetd/config.toml` makes `greetd.service` run the upstream
  `cosmic-greeter-start` flow explicitly on myOS

Keep COSMIC-only portals, greeter/session glue, and future COSMIC payloads
here instead of mixing them into `files/workstation/shared/`.
