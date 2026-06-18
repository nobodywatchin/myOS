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

run_os_release_meta_smoke \
  alma10 \
  $'ID="almalinux"\nID_LIKE="rhel centos fedora"\nVERSION_ID="10.1"\nPLATFORM_ID="platform:el10"' \
  almalinux \
  10 \
  1 \
  true \
  10 \
  1

run_os_release_meta_smoke \
  fedora \
  $'ID="fedora"\nVERSION_ID="44"\nNAME="Fedora Linux"' \
  fedora \
  44 \
  0 \
  false \
  '' \
  ''

test -f files/flatpak/base/etc/profile.d/flatpak-user-default.sh
test -f files/flatpak/base/etc/systemd/system/system-flatpak-setup.service.d/10-managed-org-system.conf
grep -q "myos-flatpak-system-maintenance ensure" files/flatpak/base/etc/systemd/system/system-flatpak-setup.service.d/10-managed-org-system.conf
grep -q -- "--no-enumerate --use-for-deps org-system" files/flatpak/cleanup/usr/libexec/myos-flatpak-system-maintenance
! grep -q -- "--no-use-for-deps" files/flatpak/cleanup/usr/libexec/myos-flatpak-system-maintenance
test -f files/flatpak/base/usr/lib/environment.d/60-myos-flatpak-exports.conf
test -f files/flatpak/base/etc/xdg/autostart/myos-flatpak-session-env.desktop
grep -q "dbus-update-activation-environment --systemd" files/flatpak/base/usr/libexec/myos-flatpak-session-env
grep -q "systemctl --user import-environment" files/flatpak/base/usr/libexec/myos-flatpak-session-env
test -f files/gnome/shared/usr/share/xdg-desktop-portal/gnome-portals.conf
grep -q "default=gnome;gtk;" files/gnome/shared/usr/share/xdg-desktop-portal/gnome-portals.conf
test -f files/cosmic/shared/usr/share/xdg-desktop-portal/cosmic-portals.conf
grep -q "default=cosmic;gtk;" files/cosmic/shared/usr/share/xdg-desktop-portal/cosmic-portals.conf
grep -q "xdg-desktop-portal-gtk" recipes/layers/shared/flatpak-cosmic.yml
grep -q "xdg-desktop-portal-gnome" recipes/layers/shared/flatpak-gnome.yml
grep -q "rpm -q flatpak flatpak-selinux xdg-desktop-portal xdg-desktop-portal-cosmic xdg-desktop-portal-gtk" recipes/layers/shared/flatpak-cosmic.yml
test -f files/flatpak/base/usr/share/polkit-1/rules.d/org.freedesktop.Flatpak.rules
! grep -q "default-flatpaks" recipes/layers/shared/workstation-common.yml
! grep -q "default-flatpaks" recipes/layers/shared/workstation-gnome.yml
! grep -q "default-flatpaks" recipes/layers/shared/workstation-cosmic.yml
test -f files/workstation/shared/usr/lib/tmpfiles.d/myos-tuned-selinux.conf
grep -q "^z /etc/tuned/active_profile - - - -$" files/workstation/shared/usr/lib/tmpfiles.d/myos-tuned-selinux.conf
grep -q "^d /var/log/tuned 0755 root root -$" files/workstation/shared/usr/lib/tmpfiles.d/myos-tuned-selinux.conf
grep -q "^Z /var/log/tuned - - - -$" files/workstation/shared/usr/lib/tmpfiles.d/myos-tuned-selinux.conf

grep -q "mesa-vulkan-drivers" recipes/layers/shared/core-base.yml
grep -q "vulkan-loader" recipes/layers/shared/core-base.yml
grep -q "vulkan-tools" recipes/layers/shared/core-base.yml
grep -q "from-file: layers/features/k3s.yml" recipes/layers/shared/core-base.yml
! grep -q '^        - lvm2$' recipes/layers/shared/core-base.yml
test -f files/base/runtime/etc/ld.so.conf.d/rocm.conf
test -f files/base/runtime/etc/profile.d/rocm.sh
test -f files/base/runtime/etc/udev/rules.d/70-render.rules
grep -q 'KERNEL=="renderD\*"' files/base/runtime/etc/udev/rules.d/70-render.rules
! grep -q 'agent/runtime-core' recipes/layers/shared/core-base.yml
! grep -q 'agent/platform-host' recipes/layers/shared/core.yml

test -f files/k3s/shared/usr/lib/modules-load.d/90-myos-k3s.conf
test -f files/k3s/shared/usr/lib/sysctl.d/90-myos-k3s.conf
grep -q '^overlay$' files/k3s/shared/usr/lib/modules-load.d/90-myos-k3s.conf
grep -q '^br_netfilter$' files/k3s/shared/usr/lib/modules-load.d/90-myos-k3s.conf
grep -q '^net.bridge.bridge-nf-call-iptables=1$' files/k3s/shared/usr/lib/sysctl.d/90-myos-k3s.conf
grep -q '^net.bridge.bridge-nf-call-ip6tables=1$' files/k3s/shared/usr/lib/sysctl.d/90-myos-k3s.conf
grep -q '^net.ipv4.ip_forward=1$' files/k3s/shared/usr/lib/sysctl.d/90-myos-k3s.conf
test -f files/k3s/shared/usr/lib/systemd/system/k3s.service
test -f files/k3s/shared/usr/lib/systemd/system/k3s-agent.service
grep -q '^ExecStart=/usr/local/bin/k3s server$' files/k3s/shared/usr/lib/systemd/system/k3s.service
grep -q '^ExecStart=/usr/local/bin/k3s agent$' files/k3s/shared/usr/lib/systemd/system/k3s-agent.service
grep -q "version='v1.36.1+k3s1'" recipes/layers/features/k3s.yml
grep -q 'sha256sum-amd64.txt' recipes/layers/features/k3s.yml
grep -q 'sha256sum-arm64.txt' recipes/layers/features/k3s.yml
grep -q 'sha256sum -c' recipes/layers/features/k3s.yml
grep -q 'k3s-agent.service' recipes/layers/features/k3s.yml

test -f files/ceph-host/shared/usr/lib/modules-load.d/90-myos-ceph-host.conf
grep -q '^ceph$' files/ceph-host/shared/usr/lib/modules-load.d/90-myos-ceph-host.conf
grep -q '^rbd$' files/ceph-host/shared/usr/lib/modules-load.d/90-myos-ceph-host.conf
grep -q 'from-file: layers/features/ceph.yml' recipes/layers/shared/core.yml
grep -q '^        - kernel-modules-core$' recipes/layers/alma9/ceph-host.yml
grep -q '^        - kernel-modules-core$' recipes/layers/alma10/ceph-host.yml
grep -q '^        - kernel-modules-core$' recipes/layers/fedora/ceph-host.yml
grep -q '^        - lvm2$' recipes/layers/alma9/ceph-host.yml
grep -q '^        - lvm2$' recipes/layers/alma10/ceph-host.yml
grep -q '^        - lvm2$' recipes/layers/fedora/ceph-host.yml

grep -q 'groups = \["wheel", "render", "video"\]' image.toml
! grep -q 'source: agent/nvidia' recipes/layers/shared/nvidia-base.yml
grep -q '^        - pcp-pmda-nvidia-gpu$' recipes/layers/shared/nvidia-base.yml
test -f files/nvidia/usr/local/libexec/myos/myos-pcp-nvidia-pmda-apply
test -f files/nvidia/usr/lib/systemd/system/myos-pcp-nvidia-pmda-apply.service
grep -q '^ExecStart=/usr/local/libexec/myos/myos-pcp-nvidia-pmda-apply$' files/nvidia/usr/lib/systemd/system/myos-pcp-nvidia-pmda-apply.service

grep -q "import '/usr/share/myos/just/default.just'" files/justfiles/usr/share/myos/just/index.just
grep -q "import '/usr/share/myos/just/rebase.just'" files/justfiles/usr/share/myos/just/index.just
grep -q "import '/usr/share/myos/just/update.just'" files/justfiles/usr/share/myos/just/index.just
! grep -q "cluster.just" files/justfiles/usr/share/myos/just/index.just
grep -q "^flatpak-clean-system:$" files/justfiles/usr/share/myos/just/update.just
grep -q "^clean-system:$" files/justfiles/usr/share/myos/just/update.just
grep -q "myos flatpak-clean-system" files/justfiles/usr/share/myos/just/update.just
grep -q "^flatpak-repair-system:$" files/justfiles/usr/share/myos/just/update.just
grep -q "^flatpak-status:$" files/justfiles/usr/share/myos/just/update.just
grep -q "myos-flatpak-system-maintenance cleanup" files/justfiles/usr/share/myos/just/update.just
grep -q "myos-flatpak-system-maintenance repair" files/justfiles/usr/share/myos/just/update.just
grep -q "flatpak pin --system --remove" files/flatpak/cleanup/usr/libexec/myos-flatpak-system-maintenance
grep -q "flatpak uninstall --system --unused -y --noninteractive" files/flatpak/cleanup/usr/libexec/myos-flatpak-system-maintenance
grep -q "flatpak repair --system" files/flatpak/cleanup/usr/libexec/myos-flatpak-system-maintenance
grep -q '^rebase:$' files/justfiles/usr/share/myos/just/rebase.just
grep -q 'raw.githubusercontent.com/myos-dev/myOS/stable/files/base/runtime/usr/share/myos/image-matrix.tsv' files/justfiles/usr/share/myos/just/rebase.just
grep -q 'Could not reach GitHub to download the image matrix' files/justfiles/usr/share/myos/just/rebase.just
grep -q 'No image matrix found at' files/justfiles/usr/share/myos/just/rebase.just
