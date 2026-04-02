#!/usr/bin/env bash
set -euo pipefail

os_release_path=/etc/os-release

if [[ ! -r "${os_release_path}" ]]; then
  printf 'os-release-meta: missing %s\n' "${os_release_path}" >&2
  exit 1
fi

# shellcheck source=/dev/null
. "${os_release_path}"

distro_id="${ID:-}"
distro_id_like="${ID_LIKE:-}"
os_version="${VERSION_ID:-}"
platform_id="${PLATFORM_ID:-}"

contains_word() {
  local haystack="$1"
  local needle="$2"

  case " ${haystack} " in
    *" ${needle} "*) return 0 ;;
    *) return 1 ;;
  esac
}

el_family=false
if contains_word "${distro_id_like}" "rhel"; then
  el_family=true
elif [[ "${platform_id}" =~ ^platform:el([0-9]+)$ ]]; then
  el_family=true
elif [[ "${distro_id}" =~ ^(almalinux|centos|rhel|rocky|ol|eurolinux)$ ]]; then
  el_family=true
fi

if [[ "${el_family}" != true ]]; then
  printf 'os-release-meta: expected EL-family base image, got ID=%s ID_LIKE=%s PLATFORM_ID=%s\n' \
    "${distro_id:-unknown}" "${distro_id_like:-unknown}" "${platform_id:-unknown}" >&2
  exit 1
fi

el_major=
el_minor=0
if [[ -n "${os_version}" ]]; then
  el_major="${os_version%%.*}"
  if [[ "${os_version}" == *.* ]]; then
    el_minor="${os_version#*.}"
    el_minor="${el_minor%%.*}"
  fi
elif [[ "${platform_id}" =~ ^platform:el([0-9]+)$ ]]; then
  el_major="${BASH_REMATCH[1]}"
  os_version="${el_major}"
fi

if [[ ! "${el_major}" =~ ^[0-9]+$ ]]; then
  printf 'os-release-meta: could not derive EL major version from VERSION_ID=%s PLATFORM_ID=%s\n' \
    "${os_version:-unknown}" "${platform_id:-unknown}" >&2
  exit 1
fi

if [[ ! "${el_minor}" =~ ^[0-9]+$ ]]; then
  printf 'os-release-meta: could not derive EL minor version from VERSION_ID=%s\n' \
    "${os_version:-unknown}" >&2
  exit 1
fi

is_alma=false
if [[ "${distro_id}" == "almalinux" ]]; then
  is_alma=true
fi

is_centos_stream=false
if [[ "${distro_id}" == "centos" ]]; then
  is_centos_stream=true
fi

install -d /usr/share/myos /etc/dnf/vars

{
  printf 'DISTRO_ID=%q\n' "${distro_id}"
  printf 'DISTRO_ID_LIKE=%q\n' "${distro_id_like}"
  printf 'OS_VERSION=%q\n' "${os_version}"
  printf 'EL_MAJOR=%q\n' "${el_major}"
  printf 'EL_MINOR=%q\n' "${el_minor}"
  printf 'EL_FAMILY=%q\n' "${el_family}"
  printf 'IS_ALMA=%q\n' "${is_alma}"
  printf 'IS_CENTOS_STREAM=%q\n' "${is_centos_stream}"
} > /usr/share/myos/os-release-meta.env

printf '%s\n' "${el_major}" > /etc/dnf/vars/releasever_major
printf '%s\n' "${el_minor}" > /etc/dnf/vars/releasever_minor
