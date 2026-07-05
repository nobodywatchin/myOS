#!/usr/bin/env bash
set -euo pipefail

os_release_path="${OS_RELEASE_META_OS_RELEASE_PATH:-/etc/os-release}"
env_output_path="${OS_RELEASE_META_ENV_PATH:-/usr/share/current/os-release-meta.env}"
dnf_vars_dir="${OS_RELEASE_META_DNF_VARS_DIR:-/etc/dnf/vars}"

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

version_major=
version_minor=0
if [[ -n "${os_version}" ]]; then
  version_major="${os_version%%.*}"
  if [[ "${os_version}" == *.* ]]; then
    version_minor="${os_version#*.}"
    version_minor="${version_minor%%.*}"
  fi
fi

el_family=false
if contains_word "${distro_id_like}" "rhel"; then
  el_family=true
elif [[ "${platform_id}" =~ ^platform:el([0-9]+)$ ]]; then
  el_family=true
elif [[ "${distro_id}" =~ ^(almalinux|centos|rhel|rocky|ol|eurolinux)$ ]]; then
  el_family=true
fi

if [[ ! "${version_major}" =~ ^[0-9]+$ ]]; then
  if [[ "${platform_id}" =~ ^platform:el([0-9]+)$ ]]; then
    version_major="${BASH_REMATCH[1]}"
    os_version="${version_major}"
  else
    printf 'os-release-meta: could not derive distro major version from VERSION_ID=%s PLATFORM_ID=%s\n' \
      "${os_version:-unknown}" "${platform_id:-unknown}" >&2
    exit 1
  fi
fi

if [[ ! "${version_minor}" =~ ^[0-9]+$ ]]; then
  printf 'os-release-meta: could not derive distro minor version from VERSION_ID=%s\n' \
    "${os_version:-unknown}" >&2
  exit 1
fi

el_major=
el_minor=
if [[ "${el_family}" == true ]]; then
  el_major="${version_major}"
  el_minor="${version_minor}"
fi

if [[ "${el_family}" == true && ! "${el_major}" =~ ^[0-9]+$ ]]; then
  printf 'os-release-meta: could not derive EL major version from VERSION_ID=%s PLATFORM_ID=%s\n' \
    "${os_version:-unknown}" "${platform_id:-unknown}" >&2
  exit 1
fi

if [[ "${el_family}" == true && ! "${el_minor}" =~ ^[0-9]+$ ]]; then
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

install -d "$(dirname "${env_output_path}")"

{
  printf 'DISTRO_ID=%q\n' "${distro_id}"
  printf 'DISTRO_ID_LIKE=%q\n' "${distro_id_like}"
  printf 'OS_VERSION=%q\n' "${os_version}"
  printf 'DISTRO_MAJOR=%q\n' "${version_major}"
  printf 'DISTRO_MINOR=%q\n' "${version_minor}"
  printf 'EL_MAJOR=%q\n' "${el_major}"
  printf 'EL_MINOR=%q\n' "${el_minor}"
  printf 'EL_FAMILY=%q\n' "${el_family}"
  printf 'IS_ALMA=%q\n' "${is_alma}"
  printf 'IS_CENTOS_STREAM=%q\n' "${is_centos_stream}"
} > "${env_output_path}"

if [[ "${el_family}" == true ]]; then
  install -d "${dnf_vars_dir}"
  printf '%s\n' "${version_major}" > "${dnf_vars_dir}/releasever_major"
  printf '%s\n' "${version_minor}" > "${dnf_vars_dir}/releasever_minor"
else
  rm -f "${dnf_vars_dir}/releasever_major" "${dnf_vars_dir}/releasever_minor"
fi
