#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MATRIX_FILE="${CURRENT_IMAGE_MATRIX_FILE:-$REPO_ROOT/files/base/runtime/usr/share/myos/image-matrix.tsv}"
CURRENT_REGISTRY_NAMESPACE="${CURRENT_REGISTRY_NAMESPACE:-ghcr.io/pelagians}"
MYOS_COMPAT_REGISTRY_NAMESPACE="${MYOS_COMPAT_REGISTRY_NAMESPACE:-ghcr.io/myos-dev}"
IMAGE_TAG="${CURRENT_IMAGE_TAG:-latest}"
SKOPEO="${SKOPEO:-skopeo}"
DRY_RUN="${DRY_RUN:-false}"

CURRENT_REGISTRY_NAMESPACE="${CURRENT_REGISTRY_NAMESPACE%/}"
MYOS_COMPAT_REGISTRY_NAMESPACE="${MYOS_COMPAT_REGISTRY_NAMESPACE%/}"

if [[ ! -f "$MATRIX_FILE" ]]; then
  printf 'Missing image matrix: %s\n' "$MATRIX_FILE" >&2
  exit 1
fi

if [[ "$DRY_RUN" != "true" ]]; then
  command -v "$SKOPEO" >/dev/null || { printf 'Missing required tool: %s\n' "$SKOPEO" >&2; exit 127; }

  if [[ -z "${MYOS_COMPAT_REGISTRY_USERNAME:-}" || -z "${MYOS_COMPAT_REGISTRY_TOKEN:-}" ]]; then
    printf 'Missing MYOS_COMPAT_REGISTRY_USERNAME or MYOS_COMPAT_REGISTRY_TOKEN. Use DRY_RUN=true to preview.\n' >&2
    exit 2
  fi
fi

src_creds=()
if [[ -n "${CURRENT_REGISTRY_USERNAME:-}" && -n "${CURRENT_REGISTRY_TOKEN:-}" ]]; then
  src_creds=(--src-creds "${CURRENT_REGISTRY_USERNAME}:${CURRENT_REGISTRY_TOKEN}")
fi

dest_creds=()
if [[ -n "${MYOS_COMPAT_REGISTRY_USERNAME:-}" && -n "${MYOS_COMPAT_REGISTRY_TOKEN:-}" ]]; then
  dest_creds=(--dest-creds "${MYOS_COMPAT_REGISTRY_USERNAME}:${MYOS_COMPAT_REGISTRY_TOKEN}")
fi

count=0
while IFS=$'\t' read -r job platform role environment driver image recipe; do
  if [[ "$job" == "job" ]]; then
    continue
  fi
  if [[ -z "${image:-}" ]]; then
    continue
  fi

  src="docker://${CURRENT_REGISTRY_NAMESPACE}/${image}:${IMAGE_TAG}"
  dst="docker://${MYOS_COMPAT_REGISTRY_NAMESPACE}/${image}:${IMAGE_TAG}"
  printf '%s -> %s\n' "$src" "$dst"

  if [[ "$DRY_RUN" != "true" ]]; then
    "$SKOPEO" copy --all "${src_creds[@]}" "${dest_creds[@]}" "$src" "$dst"
  fi

  count=$((count + 1))
done < "$MATRIX_FILE"

printf 'Processed %d image alias(es).\n' "$count"
