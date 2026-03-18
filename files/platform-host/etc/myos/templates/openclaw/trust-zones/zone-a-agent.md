# Zone A agent services

Use Zone A for the OpenClaw control plane and any trusted agent logic.

- Mount only the data and config paths that Zone A needs.
- Reach shared inference over loopback through the host RamaLama endpoint.
- Do not place browser profiles or hostile uploads in this zone.
