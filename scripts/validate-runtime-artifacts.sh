#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

command -v node >/dev/null 2>&1 || { printf 'Missing required tool: node
' >&2; exit 127; }
command -v python3 >/dev/null 2>&1 || { printf 'Missing required tool: python3
' >&2; exit 127; }

find files/agent/runtime-core/usr/local/libexec/myos -type f -print0 | xargs -0 -n1 bash -n
find files/agent/platform-host/usr/local/libexec/myos -type f -print0 | xargs -0 -n1 bash -n
bash -n files/agent/runtime-core/usr/local/bin/openquad
bash -n files/agent/platform-host/etc/myos/templates/apps/openclaw/scripts/openclaw-start.sh
bash -n files/scripts/just-el9.sh
bash -n files/workstation/shared/usr/libexec/myos-workstation-dm-apply
bash -n files/agent/nvidia/usr/local/libexec/myos/myos-pcp-nvidia-pmda-apply
bash -n modules/os-release-meta/os-release-meta.sh

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

run_os_release_meta_smoke() {
  local name="$1"
  local os_release_body="$2"
  local expected_distro="$3"
  local expected_major="$4"
  local expected_minor="$5"
  local expected_el_family="$6"
  local expected_el_major="$7"
  local expected_el_minor="$8"
  local root="${tmpdir}/${name}"

  mkdir -p "${root}/etc/dnf/vars" "${root}/usr/share/myos"
  printf '%s
' "${os_release_body}" > "${root}/os-release"

  OS_RELEASE_META_OS_RELEASE_PATH="${root}/os-release"   OS_RELEASE_META_ENV_PATH="${root}/usr/share/myos/os-release-meta.env"   OS_RELEASE_META_DNF_VARS_DIR="${root}/etc/dnf/vars"     bash modules/os-release-meta/os-release-meta.sh

  (
    set -euo pipefail
    # shellcheck disable=SC1090
    . "${root}/usr/share/myos/os-release-meta.env"
    [ "${DISTRO_ID}" = "${expected_distro}" ]
    [ "${DISTRO_MAJOR}" = "${expected_major}" ]
    [ "${DISTRO_MINOR}" = "${expected_minor}" ]
    [ "${EL_FAMILY}" = "${expected_el_family}" ]
    [ "${EL_MAJOR}" = "${expected_el_major}" ]
    [ "${EL_MINOR}" = "${expected_el_minor}" ]
  )

  if [[ "${expected_el_family}" == true ]]; then
    [ "$(cat "${root}/etc/dnf/vars/releasever_major")" = "${expected_major}" ]
    [ "$(cat "${root}/etc/dnf/vars/releasever_minor")" = "${expected_minor}" ]
  else
    [ ! -e "${root}/etc/dnf/vars/releasever_major" ]
    [ ! -e "${root}/etc/dnf/vars/releasever_minor" ]
  fi
}

run_os_release_meta_smoke   alma10   $'ID="almalinux"
ID_LIKE="rhel centos fedora"
VERSION_ID="10.1"
PLATFORM_ID="platform:el10"'   almalinux   10   1   true   10   1

run_os_release_meta_smoke   fedora43   $'ID="fedora"
VERSION_ID="43"
NAME="Fedora Linux"'   fedora   43   0   false   ''   ''

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
grep -q "mesa-vulkan-drivers" recipes/layers/shared/core-base.yml
grep -q "vulkan-loader" recipes/layers/shared/core-base.yml
grep -q "vulkan-tools" recipes/layers/shared/core-base.yml
grep -q 'TAG+="uaccess"' files/agent/runtime-core/etc/udev/rules.d/70-amdgpu.rules
grep -q "for group in render video; do" files/agent/platform-host/usr/local/libexec/myos/persistent-user-enroll
grep -q "podman info --format" files/agent/runtime-core/usr/local/bin/openquad
grep -q 'groups = \["wheel", "render", "video"\]' image.toml
test -f files/agent/nvidia/usr/local/libexec/myos/myos-pcp-nvidia-pmda-apply
test -f files/agent/nvidia/usr/lib/systemd/system/myos-pcp-nvidia-pmda-apply.service
grep -q '^ExecStart=/usr/local/libexec/myos/myos-pcp-nvidia-pmda-apply$' files/agent/nvidia/usr/lib/systemd/system/myos-pcp-nvidia-pmda-apply.service
grep -q '^Before=pmlogger.service$' files/agent/nvidia/usr/lib/systemd/system/myos-pcp-nvidia-pmda-apply.service

grep -q "import '/usr/share/myos/just/rebase.just'" files/justfiles/usr/share/myos/just/index.just
grep -q '^rebase:$' files/justfiles/usr/share/myos/just/rebase.just
grep -q 'raw.githubusercontent.com/myos-dev/myOS/stable/files/base/runtime/usr/share/myos/image-matrix.tsv' files/justfiles/usr/share/myos/just/rebase.just
grep -q 'Could not reach GitHub to download the image matrix' files/justfiles/usr/share/myos/just/rebase.just
grep -q 'No image matrix found at' files/justfiles/usr/share/myos/just/rebase.just
grep -q "import '/usr/share/myos/just/tenant.just'" files/agent/justfiles/usr/share/myos/just/index.just
grep -q "import '/usr/share/myos/just/openclaw-host.just'" files/agent/justfiles/usr/share/myos/just/index.just
grep -q '^tenant-list ' files/agent/justfiles/usr/share/myos/just/tenant.just
grep -q '^tenant-dashboard ' files/agent/justfiles/usr/share/myos/just/tenant.just
grep -q '^tenant-config ' files/agent/justfiles/usr/share/myos/just/tenant.just
grep -q '^tenant-models ' files/agent/justfiles/usr/share/myos/just/tenant.just
grep -q '^tenant-openclaw ' files/agent/justfiles/usr/share/myos/just/tenant.just
grep -q '^tenant-tailscale ' files/agent/justfiles/usr/share/myos/just/tenant.just
grep -q '^openclaw-host ' files/agent/justfiles/usr/share/myos/just/openclaw-host.just
