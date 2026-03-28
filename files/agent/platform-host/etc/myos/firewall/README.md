# Firewall scaffold

Tenant ingress is intentionally inactive by default.

- Per-tenant firewall placeholders: `/etc/myos/firewall/tenants/`
- Rendered plan output: `/etc/myos/firewall/rendered/`

The provisioning helpers only generate scaffolding so an operator can review
tenant routing and egress policy before activation.
