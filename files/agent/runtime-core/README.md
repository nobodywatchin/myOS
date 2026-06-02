# agent/runtime-core/

This tree contains the runtime pieces that are safe to ship on every myOS image.

It owns:

- shared library helpers used across the runtime-core contract
- the `myos cluster` helper and related support files
- ROCm runtime support files and AMD host-access prerequisites that are part of the shared core contract

This is separate from `agent/platform-host/`, which is server/admin only.
