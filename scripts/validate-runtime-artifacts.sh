#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

command -v python3 >/dev/null 2>&1 || { printf 'Missing required tool: python3\n' >&2; exit 127; }

bash -n files/scripts/just-el9.sh
bash -n files/workstation/shared/usr/libexec/myos-workstation-dm-apply
bash -n files/flatpak/base/usr/libexec/myos-flatpak-session-env
bash -n files/flatpak/cleanup/usr/libexec/myos-flatpak-system-maintenance
bash -n files/nvidia/usr/local/libexec/myos/myos-pcp-nvidia-pmda-apply
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
  printf '%s\n' "${os_release_body}" > "${root}/os-release"

  OS_RELEASE_META_OS_RELEASE_PATH="${root}/os-release" \
  OS_RELEASE_META_ENV_PATH="${root}/usr/share/myos/os-release-meta.env" \
  OS_RELEASE_META_DNF_VARS_DIR="${root}/etc/dnf/vars" \
    bash modules/os-release-meta/os-release-meta.sh

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

run_os_release_meta_smoke alma10 $'ID="almalinux"\nID_LIKE="rhel centos fedora"\nVERSION_ID="10.1"\nPLATFORM_ID="platform:el10"' almalinux 10 1 true 10 1
run_os_release_meta_smoke fedora $'ID="fedora"\nVERSION_ID="44"\nNAME="Fedora Linux"' fedora 44 0 false '' ''

test -f files/flatpak/base/etc/profile.d/flatpak-user-default.sh
test -f files/flatpak/base/etc/systemd/system/system-flatpak-setup.service.d/10-managed-org-system.conf
grep -q "myos-flatpak-system-maintenance ensure" files/flatpak/base/etc/systemd/system/system-flatpak-setup.service.d/10-managed-org-system.conf
test -f files/workstation/shared/usr/libexec/myos-workstation-dm-apply

grep -q 'from-file: layers/shared/workstation-substrate.yml' recipes/layers/shared/workstation-common.yml
grep -q 'from-file: layers/shared/workstation-admin-tools.yml' recipes/layers/shared/workstation-common.yml
grep -q 'from-file: layers/shared/workstation-policy.yml' recipes/layers/shared/workstation-common.yml
grep -q 'from-file: layers/shared/workstation-user-tools.yml' recipes/layers/shared/workstation-common.yml
! grep -q 'brave-browser-rpm-beta' recipes/layers/shared/workstation-common.yml
! grep -q 'myos-workstation-dm-apply.service' recipes/layers/shared/workstation-common.yml
grep -q '^        - ModemManager$' recipes/layers/shared/workstation-substrate.yml
grep -q '^        - tcpdump$' recipes/layers/shared/workstation-admin-tools.yml
grep -q 'myos-workstation-dm-apply.service' recipes/layers/shared/workstation-policy.yml
grep -q 'brave-origin-beta' recipes/layers/shared/workstation-user-tools.yml

test -f files/base/runtime/etc/ld.so.conf.d/rocm.conf
test -f files/base/runtime/etc/profile.d/rocm.sh
test -f files/base/runtime/etc/udev/rules.d/70-render.rules
test -f files/base/runtime/etc/udev/rules.d/70-amdgpu-kfd.rules
! grep -q 'agent/runtime-core' recipes/layers/shared/core-base.yml
! grep -q 'agent/platform-host' recipes/layers/shared/core.yml
! grep -q '/etc/myos/dns' recipes/layers/shared/core.yml
! grep -q '/etc/myos/firewall' recipes/layers/shared/core.yml

grep -q 'from-file: layers/features/k3s.yml' recipes/layers/shared/core-base.yml
grep -q 'from-file: layers/features/pcp.yml' recipes/layers/shared/core-base.yml
grep -q 'from-file: layers/features/tailscale.yml' recipes/layers/shared/core-base.yml
grep -q 'from-file: layers/shared/system-policy.yml' recipes/layers/shared/core-base.yml
! grep -q 'tailscale.repo' recipes/layers/shared/core-base.yml
! grep -q 'pmcd.service' recipes/layers/shared/core-base.yml
! grep -q 'bootc-fetch-apply-updates' recipes/layers/shared/core-base.yml
grep -q '^        - pcp$' recipes/layers/features/pcp.yml
grep -q 'pmcd.service' recipes/layers/features/pcp.yml
grep -q 'tailscale.repo' recipes/layers/features/tailscale.yml
grep -q 'tailscaled.service' recipes/layers/features/tailscale.yml
grep -q 'bootc-fetch-apply-updates.service' recipes/layers/shared/system-policy.yml
grep -q 'transparent_hugepage=madvise' recipes/layers/shared/system-policy.yml

test -f files/k3s/shared/usr/lib/systemd/system/k3s.service
test -f files/k3s/shared/usr/lib/systemd/system/k3s-agent.service
grep -q "version='v1.36.1+k3s1'" recipes/layers/features/k3s.yml
! grep -q 'myos cluster' recipes/layers/features/k3s.yml

test -f files/ceph-host/shared/usr/lib/modules-load.d/90-myos-ceph-host.conf
grep -q 'from-file: layers/features/ceph.yml' recipes/layers/shared/core.yml

grep -q '^        - pcp-pmda-nvidia-gpu$' recipes/layers/shared/nvidia-base.yml
grep -q 'nvidia-container-toolkit.repo' recipes/layers/shared/nvidia-base.yml
grep -q 'repo_gpgcheck=0' recipes/layers/shared/nvidia-base.yml
grep -q 'gpgcheck=1' recipes/layers/shared/nvidia-base.yml
test -f files/nvidia/usr/local/libexec/myos/myos-pcp-nvidia-pmda-apply
test -f files/nvidia/usr/lib/systemd/system/myos-pcp-nvidia-pmda-apply.service

grep -q "import '/usr/share/myos/just/default.just'" files/justfiles/usr/share/myos/just/index.just
grep -q "import '/usr/share/myos/just/rebase.just'" files/justfiles/usr/share/myos/just/index.just
grep -q "import '/usr/share/myos/just/update.just'" files/justfiles/usr/share/myos/just/index.just
! grep -q "cluster.just" files/justfiles/usr/share/myos/just/index.just
test ! -e files/justfiles/usr/share/myos/just/cluster.just
grep -q '^rebase:$' files/justfiles/usr/share/myos/just/rebase.just
