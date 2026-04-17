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

for retired_dir in \
  recipes/images/core \
  recipes/images/gnome \
  recipes/images/cosmic

do
  [ ! -e "$retired_dir" ] || {
    printf 'Retired recipe directory still present: %s\n' "$retired_dir" >&2
    exit 1
  }
done

for retired_path in \
  recipes/images/console \
  recipes/layers/shared/console.yml \
  files/console/shared/usr/share/myos/console/role.env \
  scripts/verify-alma9-nvidia-legacy.ps1

do
  [ ! -e "$retired_path" ] || {
    printf 'Retired path still present: %s\n' "$retired_path" >&2
    exit 1
  }
done

if find recipes/images/workstation -type f -name 'full*.yml' 2>/dev/null | grep -q .; then
  printf 'Workstation full recipes are no longer supported and must be removed.\n' >&2
  exit 1
fi

platform_recipe_counts=(
  'alma9:3'
  'alma10:6'
  'fedora43:5'
)

for entry in "${platform_recipe_counts[@]}"; do
  platform="${entry%%:*}"
  expected="${entry##*:}"
  count="$(python3 "$matrix_script" recipes --platform "$platform" | wc -l | tr -d ' ')"
  [ "$count" = "$expected" ] || {
    printf 'Lane %s should have %s supported recipes, found %s.\n' "$platform" "$expected" "$count" >&2
    exit 1
  }
done

matrix_render_counts=(
  'server-images:4'
  'workstation-images:10'
  'alma9:server-images:1'
  'alma9:workstation-images:2'
  'alma10:server-images:2'
  'alma10:workstation-images:4'
  'fedora43:server-images:1'
  'fedora43:workstation-images:4'
)

json_count() {
  python3 -c 'import json, sys; print(len(json.load(sys.stdin)))'
}

for entry in "${matrix_render_counts[@]}"; do
  if [ "$(printf '%s' "$entry" | awk -F: '{print NF}')" -eq 2 ]; then
    job="${entry%%:*}"
    expected="${entry##*:}"
    count="$(python3 "$matrix_script" gha "$job" | json_count)"
    [ "$count" = "$expected" ] || {
      printf 'Rendered %s matrix should have %s entries, found %s.\n' "$job" "$expected" "$count" >&2
      exit 1
    }
  else
    platform="${entry%%:*}"
    rest="${entry#*:}"
    job="${rest%%:*}"
    expected="${rest##*:}"
    count="$(python3 "$matrix_script" gha --platform "$platform" "$job" | json_count)"
    [ "$count" = "$expected" ] || {
      printf 'Rendered %s matrix for %s should have %s entries, found %s.\n' "$job" "$platform" "$expected" "$count" >&2
      exit 1
    }
  fi
done

python3 "$matrix_script" rebase >/dev/null

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
    printf 'Workflow is missing manifest-driven matrix wiring: %s\n' "$snippet" >&2
    exit 1
  }
done

for forbidden_snippet in \
  'workstation_core_images' \
  'workstation_full_images' \
  'console_images' \
  'workstation-core-images:' \
  'workstation-full-images:' \
  'console-images:' \
  'verify-alma9-nvidia-legacy.ps1' \
  'validate-branch-lane:' \
  'github.base_ref || github.ref_name' \
  '--branch "$active_branch"'

do
  if grep -Fq -- "$forbidden_snippet" "$workflow_file"; then
    printf 'Workflow still contains retired matrix wiring: %s\n' "$forbidden_snippet" >&2
    exit 1
  fi
done

if grep -Fq -- 'recipe: /images/' "$workflow_file"; then
  printf 'Workflow still contains hard-coded recipe entries instead of manifest-driven matrices.\n' >&2
  exit 1
fi
