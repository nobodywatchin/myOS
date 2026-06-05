# Rootless service templates

myOS ships two rootless workload planes:

- `apps/openclaw/`: dedicated platform-host tenant templates rendered by the `tenant-*` helpers into managed service accounts under `/srv/tenants/<tenant>/`
- `persistent-users/`: template buckets for existing login users that are explicitly enrolled for lingering persistent workloads

Desktop or session-only Quadlets do not live here. This tree is for shared
platform-host and persistent-user templates used by the shared admin/operator flows.
