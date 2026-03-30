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
- myOS ships these buckets empty by default. Adding files here defines the baseline or owner policy for that image or deployment.
