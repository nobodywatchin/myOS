# agent/runtime-core/

This tree contains the runtime pieces that are safe to ship on every myOS image.

It owns:

- the `openquad` command
- shared library helpers used by the per-user runtime
- the shipped per-user OpenClaw template
- ROCm runtime support files that are part of the shared core contract

This is separate from `agent/platform-host/`, which is full-tier only.
