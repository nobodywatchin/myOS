#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

matrix_file="files/base/runtime/usr/share/myos/image-matrix.tsv"
matrix_script="scripts/render-image-matrix.py"
workflow_file=".github/workflows/build.yml"

supported_recipes="$(python3 "$matrix_script" recipes | sort)"
actual_recipes="$(find recipes/images -type f -name '*.yml' | sort)"

if [ "$actual_recipes" != "$supported_recipes" ]; then
  printf 'Recipe tree does not match the supported image manifest.
' >&2
  diff -u <(printf '%s
' "$supported_recipes") <(printf '%s
' "$actual_recipes") >&2 || true
  exit 1
fi

for retired_dir in   recipes/images/core   recipes/images/gnome   recipes/images/cosmic

do
  [ ! -e "$retired_dir" ] || {
    printf 'Retired recipe directory still present: %s
' "$retired_dir" >&2
    exit 1
  }
done

for retired_path in   recipes/images/console   recipes/layers/shared/console.yml   files/console/shared/usr/share/myos/console/role.env   recipes/layers/alma9/full.yml   recipes/layers/alma10/full.yml   recipes/layers/fedora43/gnome.yml   recipes/layers/shared/gnome-base.yml   recipes/layers/shared/nvidia-gnome.yml   recipes/layers/features/rocm-developer-tools.yml   files/gnome/flatpak/README.md   scripts/verify-alma9-nvidia-legacy.ps1

do
  [ ! -e "$retired_path" ] || {
    printf 'Retired path still present: %s
' "$retired_path" >&2
    exit 1
  }
done

if find recipes/images/workstation -type f -name 'full*.yml' 2>/dev/null | grep -q .; then
  printf 'Workstation full recipes are no longer supported and must be removed.
' >&2
  exit 1
fi

if rg -n 'nvidia-legacy' files/base/runtime/usr/share/myos/image-matrix.tsv recipes/images scripts/render-image-matrix.py >/dev/null; then
  printf 'Legacy NVIDIA naming still leaks into the active matrix or recipe tree.
' >&2
  exit 1
fi

json_check() {
  python3 -c 'import json, sys; payload=json.load(sys.stdin); assert isinstance(payload, list)'
}

while IFS= read -r platform; do
  [ -n "$platform" ] || continue
  python3 "$matrix_script" recipes --platform "$platform" >/dev/null

done < <(tail -n +2 "$matrix_file" | cut -f2 | sort -u)

while IFS= read -r job; do
  [ -n "$job" ] || continue
  python3 "$matrix_script" gha "$job" | json_check >/dev/null

done < <(tail -n +2 "$matrix_file" | cut -f1 | sort -u)

while IFS=$'	' read -r job platform; do
  [ -n "$job" ] || continue
  [ -n "$platform" ] || continue
  python3 "$matrix_script" gha --platform "$platform" "$job" | json_check >/dev/null

done < <(tail -n +2 "$matrix_file" | cut -f1,2 | sort -u)

python3 "$matrix_script" rebase | grep -q .

required_workflow_snippets=(
  'define-image-matrix:'
  'server_images: ${{ steps.render.outputs.server_images }}'
  'workstation_images: ${{ steps.render.outputs.workstation_images }}'
  'validate-alma9-nvidia-580:'
  './scripts/verify-alma9-nvidia-580.ps1'
  'emit_output server_images python3 ./scripts/render-image-matrix.py gha server-images'
  'emit_output workstation_images python3 ./scripts/render-image-matrix.py gha workstation-images'
  'include: ${{ fromJSON(needs.define-image-matrix.outputs.server_images) }}'
  'include: ${{ fromJSON(needs.define-image-matrix.outputs.workstation_images) }}'
)

for snippet in "${required_workflow_snippets[@]}"; do
  grep -Fq -- "$snippet" "$workflow_file" || {
    printf 'Workflow is missing manifest-driven matrix wiring: %s
' "$snippet" >&2
    exit 1
  }
done

for forbidden_snippet in   'workstation_core_images'   'workstation_full_images'   'console_images'   'workstation-core-images:'   'workstation-full-images:'   'console-images:'   'verify-alma9-nvidia-legacy.ps1'   'github.base_ref || github.ref_name'   '--branch "$active_branch"'

do
  if grep -Fq -- "$forbidden_snippet" "$workflow_file"; then
    printf 'Workflow still contains retired matrix wiring: %s
' "$forbidden_snippet" >&2
    exit 1
  fi
done

if grep -Fq -- 'recipe: /images/' "$workflow_file"; then
  printf 'Workflow still contains hard-coded recipe entries instead of manifest-driven matrices.
' >&2
  exit 1
fi
