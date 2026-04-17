#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

matrix_script="scripts/render-image-matrix.py"
workflow_file=".github/workflows/build.yml"

supported_recipes="$(python3 "$matrix_script" recipes | sort)"
actual_recipes="$(find recipes/images -type f -name '*.yml' | sort)"

if [ "$actual_recipes" != "$supported_recipes" ]; then
  printf 'Recipe tree does not match the supported image manifest.\n' >&2
  diff -u <(printf '%s\n' "$supported_recipes") <(printf '%s\n' "$actual_recipes") >&2 || true
  exit 1
fi

for retired_dir in recipes/images/core recipes/images/gnome recipes/images/cosmic; do
  [ ! -e "$retired_dir" ] || {
    printf 'Retired recipe directory still present: %s\n' "$retired_dir" >&2
    exit 1
  }
done

expected_fedora43="$(printf '%s\n' \
  recipes/images/workstation/gnome/fedora43/core.yml \
  recipes/images/workstation/gnome/fedora43/core-nvidia-open.yml \
  recipes/images/workstation/cosmic/fedora43/core.yml \
  recipes/images/workstation/cosmic/fedora43/core-nvidia-open.yml \
| sort)"
fedora43_recipes="$(python3 "$matrix_script" recipes --distro fedora43 | sort)"

if [ "$fedora43_recipes" != "$expected_fedora43" ]; then
  printf 'Fedora 43 recipe set does not match the supported workstation-core lane.\n' >&2
  diff -u <(printf '%s\n' "$expected_fedora43") <(printf '%s\n' "$fedora43_recipes") >&2 || true
  exit 1
fi

for job in server-images workstation-core-images workstation-full-images console-images; do
  python3 "$matrix_script" gha "$job" >/dev/null
done
python3 "$matrix_script" rebase >/dev/null

required_workflow_snippets=(
  'define-image-matrices:'
  'server_images: ${{ steps.render.outputs.server_images }}'
  'workstation_core_images: ${{ steps.render.outputs.workstation_core_images }}'
  'workstation_full_images: ${{ steps.render.outputs.workstation_full_images }}'
  'console_images: ${{ steps.render.outputs.console_images }}'
  'emit_output server_images python3 ./scripts/render-image-matrix.py gha server-images'
  'emit_output workstation_core_images python3 ./scripts/render-image-matrix.py gha workstation-core-images'
  'emit_output workstation_full_images python3 ./scripts/render-image-matrix.py gha workstation-full-images'
  'emit_output console_images python3 ./scripts/render-image-matrix.py gha console-images'
  'include: ${{ fromJSON(needs.define-image-matrices.outputs.server_images) }}'
  'include: ${{ fromJSON(needs.define-image-matrices.outputs.workstation_core_images) }}'
  'include: ${{ fromJSON(needs.define-image-matrices.outputs.workstation_full_images) }}'
  'include: ${{ fromJSON(needs.define-image-matrices.outputs.console_images) }}'
)

for snippet in "${required_workflow_snippets[@]}"; do
  grep -Fq "$snippet" "$workflow_file" || {
    printf 'Workflow is missing manifest-driven matrix wiring: %s\n' "$snippet" >&2
    exit 1
  }
done

if grep -Fq 'recipe: /images/' "$workflow_file"; then
  printf 'Workflow still contains hard-coded recipe entries instead of manifest-driven matrices.\n' >&2
  exit 1
fi
