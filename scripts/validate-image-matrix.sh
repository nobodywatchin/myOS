    #!/usr/bin/env bash
    set -euo pipefail

    cd "$(dirname "$0")/.."

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

    for retired_dir in recipes/images/core recipes/images/gnome recipes/images/cosmic; do
      [ ! -e "$retired_dir" ] || {
        printf 'Retired recipe directory still present: %s
' "$retired_dir" >&2
        exit 1
      }
    done

    for retired_path in       recipes/images/console       recipes/layers/shared/console.yml       files/console/shared/usr/share/myos/console/role.env       scripts/verify-alma9-nvidia-legacy.ps1
    do
      [ ! -e "$retired_path" ] || {
        printf 'Retired path still present: %s
' "$retired_path" >&2
        exit 1
      }
    done

    find recipes/images/workstation -type f -name 'full*.yml' 2>/dev/null | grep -q . && {
      printf 'Workstation full recipes are no longer supported and must be removed.
' >&2
      exit 1
    }

    branch_recipe_counts=(
      "alma9:3"
      "alma10:6"
      "fedora43:5"
    )

    for entry in "${branch_recipe_counts[@]}"; do
      branch="${entry%%:*}"
      expected="${entry##*:}"
      count="$(python3 "$matrix_script" recipes --branch "$branch" | wc -l | tr -d ' ')"
      [ "$count" = "$expected" ] || {
        printf 'Branch %s should have %s supported recipes, found %s.
' "$branch" "$expected" "$count" >&2
        exit 1
      }
    done

    matrix_render_counts=(
      "alma9:server-images:1"
      "alma9:workstation-images:2"
      "alma10:server-images:2"
      "alma10:workstation-images:4"
      "fedora43:server-images:1"
      "fedora43:workstation-images:4"
    )

    json_count() {
      python3 -c 'import json, sys; print(len(json.load(sys.stdin)))'
    }

    for entry in "${matrix_render_counts[@]}"; do
      branch="${entry%%:*}"
      rest="${entry#*:}"
      job="${rest%%:*}"
      expected="${rest##*:}"
      count="$(python3 "$matrix_script" gha --branch "$branch" "$job" | json_count)"
      [ "$count" = "$expected" ] || {
        printf 'Rendered %s matrix for %s should have %s entries, found %s.
' "$job" "$branch" "$expected" "$count" >&2
        exit 1
      }
    done

    python3 "$matrix_script" rebase >/dev/null

    required_workflow_snippets=(
      'define-image-matrix:'
      'server_images: ${{ steps.render.outputs.server_images }}'
      'workstation_images: ${{ steps.render.outputs.workstation_images }}'
      'github.base_ref || github.ref_name'
      'contains(fromJson('["stable","alma9","alma10","fedora43"]'), github.base_ref || github.ref_name)'
      'raw_branch="${{ github.base_ref || github.ref_name }}"'
      'stable) active_branch="alma10" ;;'
      'emit_output server_images python3 ./scripts/render-image-matrix.py gha --branch "$active_branch" server-images'
      'emit_output workstation_images python3 ./scripts/render-image-matrix.py gha --branch "$active_branch" workstation-images'
      'include: ${{ fromJSON(needs.define-image-matrix.outputs.server_images) }}'
      'include: ${{ fromJSON(needs.define-image-matrix.outputs.workstation_images) }}'
      './scripts/verify-alma9-nvidia-580.ps1'
    )

    for snippet in "${required_workflow_snippets[@]}"; do
      grep -Fq "$snippet" "$workflow_file" || {
        printf 'Workflow is missing manifest-driven matrix wiring: %s
' "$snippet" >&2
        exit 1
      }
    done

    for forbidden_snippet in       'workstation_core_images'       'workstation_full_images'       'console_images'       'workstation-core-images:'       'workstation-full-images:'       'console-images:'       'verify-alma9-nvidia-legacy.ps1'
    do
      if grep -Fq "$forbidden_snippet" "$workflow_file"; then
        printf 'Workflow still contains retired matrix wiring: %s
' "$forbidden_snippet" >&2
        exit 1
      fi
    done

    if grep -Fq 'recipe: /images/' "$workflow_file"; then
      printf 'Workflow still contains hard-coded recipe entries instead of manifest-driven matrices.
' >&2
      exit 1
    fi
