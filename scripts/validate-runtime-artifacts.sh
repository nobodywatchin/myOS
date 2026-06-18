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
    [ "${EL_MINOR}" = "${expected_minor}" ]
  )
}

run_os_release_meta_smoke alma10 $'ID="almalinux"\nID_LIKE="rhel centos fedora"\nVERSION_ID="10.1"\nPLATFORM_ID="platform:el10"' almalinux 10 1 true 10 1
run_os_release_meta_smoke fedora $'ID="fedora"\nVERSION_ID="44"\nNAME="Fedora Linux"' fedora 44 0 false '' ''

test -f files/flatpak/base/etc/profile.d/flatpak-user-default.sh
