# Zone B hostile-input services

Use Zone B for browsers, parsers, and other workloads that process untrusted content.

- Keep browser profile and parser scratch paths isolated from Zone A.
- Publish only localhost ports for operator control.
- Treat downloads as quarantined until reviewed by tenant-local policy.
