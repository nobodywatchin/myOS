#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

command -v node >/dev/null 2>&1 || { printf 'Missing required tool: node\n' >&2; exit 127; }
command -v python3 >/dev/null 2>&1 || { printf 'Missing required tool: python3\n' >&2; exit 127; }

find files/agent/runtime-core/usr/local/libexec/myos -type f -print0 | xargs -0 -n1 bash -n
find files/agent/platform-host/usr/local/libexec/myos -type f -print0 | xargs -0 -n1 bash -n
bash -n files/agent/runtime-core/usr/local/bin/openquad
bash -n files/agent/platform-host/etc/myos/templates/apps/openclaw/scripts/openclaw-start.sh
bash -n files/scripts/just-el9.sh
bash -n files/workstation/shared/usr/libexec/myos-workstation-dm-apply
bash -n modules/os-release-meta/os-release-meta.sh

node --check files/agent/platform-host/etc/myos/templates/apps/openclaw/scripts/openclaw-ui-server.mjs
python3 -m json.tool files/agent/platform-host/etc/myos/templates/apps/openclaw/config/openclaw.json.example >/dev/null

grep -q '^\[Container\]$' files/agent/platform-host/etc/myos/templates/apps/openclaw/quadlets/openclaw.container
grep -q '^Image=' files/agent/platform-host/etc/myos/templates/apps/openclaw/quadlets/openclaw.container
grep -q '^Exec=' files/agent/platform-host/etc/myos/templates/apps/openclaw/quadlets/openclaw.container
grep -q '^EnvironmentFile=__TENANT_ROOT__/config/env/ports.env$' files/agent/platform-host/etc/myos/templates/apps/openclaw/quadlets/openclaw.container
grep -q '^EnvironmentFile=__TENANT_ROOT__/zone-c/secrets/openclaw.secrets.env$' files/agent/platform-host/etc/myos/templates/apps/openclaw/quadlets/openclaw.container
grep -q '^Volume=__TENANT_ROOT__/zone-c/state:/home/node/.openclaw:Z$' files/agent/platform-host/etc/myos/templates/apps/openclaw/quadlets/openclaw.container
grep -q '^Volume=__TENANT_ROOT__/zone-c/storage:/home/node/.openclaw/workspace:Z$' files/agent/platform-host/etc/myos/templates/apps/openclaw/quadlets/openclaw.container
grep -q '^WantedBy=default.target$' files/agent/platform-host/etc/myos/templates/apps/openclaw/quadlets/openclaw.container

grep -q '^\[Container\]$' files/agent/runtime-core/etc/myos/templates/apps/openclaw/user/openclaw.container
grep -q '^Image=' files/agent/runtime-core/etc/myos/templates/apps/openclaw/user/openclaw.container
grep -q '^Pull=missing$' files/agent/runtime-core/etc/myos/templates/apps/openclaw/user/openclaw.container
grep -q '^Exec=openclaw gateway --allow-unconfigured$' files/agent/runtime-core/etc/myos/templates/apps/openclaw/user/openclaw.container
grep -q '^Volume=%h/.local/share/openclaw:/home/node/.openclaw:rw,Z$' files/agent/runtime-core/etc/myos/templates/apps/openclaw/user/openclaw.container
grep -q '^TimeoutStartSec=15min$' files/agent/runtime-core/etc/myos/templates/apps/openclaw/user/openclaw.container
grep -q '^WantedBy=default.target$' files/agent/runtime-core/etc/myos/templates/apps/openclaw/user/openclaw.container

test -f files/end-user/shared/etc/profile.d/flatpak-user-default.sh
test -f files/end-user/shared/etc/systemd/system/system-flatpak-setup.service.d/10-hide-org-system.conf
test -f files/end-user/shared/usr/lib/environment.d/60-myos-flatpak-exports.conf
test -f files/end-user/shared/usr/share/polkit-1/rules.d/org.freedesktop.Flatpak.rules
test -f files/console/shared/usr/share/myos/console/role.env

grep -q "import '/usr/share/myos/just/rebase.just'" files/justfiles/usr/share/myos/just/index.just
grep -q "import '/usr/share/myos/just/tenant.just'" files/agent/justfiles/usr/share/myos/just/index.just
grep -q "import '/usr/share/myos/just/openclaw-host.just'" files/agent/justfiles/usr/share/myos/just/index.just
grep -q '^tenant-list ' files/agent/justfiles/usr/share/myos/just/tenant.just
grep -q '^tenant-dashboard ' files/agent/justfiles/usr/share/myos/just/tenant.just
grep -q '^tenant-config ' files/agent/justfiles/usr/share/myos/just/tenant.just
grep -q '^tenant-models ' files/agent/justfiles/usr/share/myos/just/tenant.just
grep -q '^tenant-openclaw ' files/agent/justfiles/usr/share/myos/just/tenant.just
grep -q '^tenant-tailscale ' files/agent/justfiles/usr/share/myos/just/tenant.just
grep -q '^openclaw-host ' files/agent/justfiles/usr/share/myos/just/openclaw-host.just
