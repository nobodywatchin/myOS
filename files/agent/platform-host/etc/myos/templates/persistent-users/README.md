# Persistent login-user templates

These template buckets target existing login users that an admin explicitly
opts into persistent hosting with `myos persistent-user-enroll`.

Layout:

- `baseline/quadlets/`: installed for every enrolled user
- `owner/quadlets/`: installed only for the single selected owner user

Important rules:

- Units in these directories become per-user instances, not a single shared machine-wide singleton.
- Prefer `%h`, `%u`, `%U`, `%t`, and other user-aware specifiers over hardcoded paths.
- Avoid fixed shared host ports in baseline units unless you parameterize them outside the template.
- If a workload should be shared once per machine, it belongs in a system unit rather than here.
- myOS can ship shared baseline policy here.
- Adding files here defines the baseline or owner policy for that image or deployment.
- OpenClaw tenant templates live under `apps/openclaw/`; these baseline and owner buckets are reserved for admin-managed persistent-user services.
