# Choose An Image

Choose in this order.

## 1. Pick a role

- `workstation`: the default choice for most people. This is the flagship desktop role.
- `server`: for full-tier admin/operator systems.
- `console`: Alma 10 only, core only, currently a preview role.

## 2. Pick a tier

- `core`: the normal daily-use base. It keeps the modern app/runtime model, ROCm userspace, and optional per-user OpenClaw support without host/operator defaults.
- `full`: adds Cockpit, OpenTofu, Kubernetes CLI, tenant tooling, persistent-user admin tooling, and `openclaw-host`.

If you do not already know that you need the operator tooling, choose `core` for Workstation and `full` only for Server or advanced workstation/admin use.

## 3. Pick a distro lane

- `alma9`: the conservative lane, and the only lane with first-class `nvidia-legacy` support.
- `alma10`: the newer lane, with Console support and no legacy NVIDIA branch.

## 4. Pick a hardware lane

- `default`: no NVIDIA image-specific add-on.
- `nvidia-open`: newer supported NVIDIA GPUs.
- `nvidia-legacy`: Alma 9 only, for the supported older-GPU proprietary R580 path.

## 5. If you chose Workstation, pick a family

- `GNOME`: the default documented workstation experience.
- `COSMIC`: a parallel supported workstation family.

## Supported combinations

| Distro | Role | Tier | Workstation family | Hardware |
| --- | --- | --- | --- | --- |
| Alma 9 | Workstation | core | GNOME, COSMIC | default, nvidia-open, nvidia-legacy |
| Alma 9 | Workstation | full | GNOME, COSMIC | default, nvidia-open, nvidia-legacy |
| Alma 9 | Server | full | n/a | default, nvidia-open, nvidia-legacy |
| Alma 10 | Workstation | core | GNOME, COSMIC | default, nvidia-open |
| Alma 10 | Workstation | full | GNOME, COSMIC | default, nvidia-open |
| Alma 10 | Server | full | n/a | default, nvidia-open |
| Alma 10 | Console | core | preview | default, nvidia-open |

Unsupported combinations are intentional.

- no `core/server`
- no `full/console`
- no Alma 9 Console
- no Alma 10 NVIDIA legacy

## Published tag examples

- Full GNOME Workstation on Alma 10 default GPU lane: `gnome-alma10`
- Core GNOME Workstation on Alma 10 default GPU lane: `workstation-core-gnome-alma10`
- Full COSMIC Workstation on Alma 9 legacy NVIDIA lane: `cosmic-alma9-nvidia-legacy`
- Full Server on Alma 10 default GPU lane: `core-full-alma10`
- Core Console preview on Alma 10 default GPU lane: `console-core-alma10`

`myos rebase` shows the full list grouped by role, tier, family, distro, and hardware.
