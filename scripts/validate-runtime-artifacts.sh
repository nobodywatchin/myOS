#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

find files/agent/platform-host/usr/local/libexec/myos -type f -print0 | xargs -0 -n1 bash -n
bash -n files/agent/platform-host/usr/local/bin/openquad
bash -n files/agent/platform-host/etc/myos/templates/apps/openclaw/scripts/openclaw-start.sh
bash -n files/scripts/just-el9.sh
bash -n modules/os-release-meta/os-release-meta.sh

node --check files/agent/platform-host/etc/myos/templates/apps/openclaw/scripts/openclaw-ui-server.mjs
python3 -m json.tool files/agent/platform-host/etc/myos/templates/apps/openclaw/config/openclaw.json.example >/dev/null

if command -v systemd-analyze >/dev/null 2>&1; then
  systemd-analyze verify files/agent/platform-host/usr/lib/systemd/system/myos-ramalama@.service >/dev/null
else
  grep -q '^\[Unit\]$' files/agent/platform-host/usr/lib/systemd/system/myos-ramalama@.service
  grep -q '^ExecStart=/usr/local/libexec/myos/ramalama-serve %i$' files/agent/platform-host/usr/lib/systemd/system/myos-ramalama@.service
  grep -q '^User=modelsvc$' files/agent/platform-host/usr/lib/systemd/system/myos-ramalama@.service
  grep -q '^WantedBy=multi-user.target$' files/agent/platform-host/usr/lib/systemd/system/myos-ramalama@.service
fi

grep -q '^\[Container\]$' files/agent/platform-host/etc/myos/templates/apps/openclaw/quadlets/openclaw.container
grep -q '^Image=' files/agent/platform-host/etc/myos/templates/apps/openclaw/quadlets/openclaw.container
grep -q '^Exec=' files/agent/platform-host/etc/myos/templates/apps/openclaw/quadlets/openclaw.container
grep -q '^EnvironmentFile=__TENANT_ROOT__/config/env/ports.env$' files/agent/platform-host/etc/myos/templates/apps/openclaw/quadlets/openclaw.container
grep -q '^EnvironmentFile=__TENANT_ROOT__/zone-c/secrets/openclaw.secrets.env$' files/agent/platform-host/etc/myos/templates/apps/openclaw/quadlets/openclaw.container
grep -q '^Volume=__TENANT_ROOT__/zone-c/state:/home/node/.openclaw:Z$' files/agent/platform-host/etc/myos/templates/apps/openclaw/quadlets/openclaw.container
grep -q '^Volume=__TENANT_ROOT__/zone-c/storage:/home/node/.openclaw/workspace:Z$' files/agent/platform-host/etc/myos/templates/apps/openclaw/quadlets/openclaw.container
grep -q '^WantedBy=default.target$' files/agent/platform-host/etc/myos/templates/apps/openclaw/quadlets/openclaw.container

grep -q '^\[Container\]$' files/agent/platform-host/etc/myos/templates/apps/openclaw/user/openclaw.container
grep -q '^Image=' files/agent/platform-host/etc/myos/templates/apps/openclaw/user/openclaw.container
grep -q '^Exec=openclaw gateway --allow-unconfigured$' files/agent/platform-host/etc/myos/templates/apps/openclaw/user/openclaw.container
grep -q '^Volume=%h/.local/share/openclaw:/home/node/.openclaw:rw,Z$' files/agent/platform-host/etc/myos/templates/apps/openclaw/user/openclaw.container
grep -q '^WantedBy=default.target$' files/agent/platform-host/etc/myos/templates/apps/openclaw/user/openclaw.container

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
