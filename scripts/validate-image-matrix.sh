#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

expected_recipes=(
  recipes/images/server/alma9/full.yml
  recipes/images/server/alma9/full-nvidia-open.yml
  recipes/images/server/alma9/full-nvidia-legacy.yml
  recipes/images/server/alma10/full.yml
  recipes/images/server/alma10/full-nvidia-open.yml
  recipes/images/workstation/gnome/alma9/core.yml
  recipes/images/workstation/gnome/alma9/core-nvidia-open.yml
  recipes/images/workstation/gnome/alma9/core-nvidia-legacy.yml
  recipes/images/workstation/gnome/alma9/full.yml
  recipes/images/workstation/gnome/alma9/full-nvidia-open.yml
  recipes/images/workstation/gnome/alma9/full-nvidia-legacy.yml
  recipes/images/workstation/gnome/alma10/core.yml
  recipes/images/workstation/gnome/alma10/core-nvidia-open.yml
  recipes/images/workstation/gnome/alma10/full.yml
  recipes/images/workstation/gnome/alma10/full-nvidia-open.yml
  recipes/images/workstation/cosmic/alma9/core.yml
  recipes/images/workstation/cosmic/alma9/core-nvidia-open.yml
  recipes/images/workstation/cosmic/alma9/core-nvidia-legacy.yml
  recipes/images/workstation/cosmic/alma9/full.yml
  recipes/images/workstation/cosmic/alma9/full-nvidia-open.yml
  recipes/images/workstation/cosmic/alma9/full-nvidia-legacy.yml
  recipes/images/workstation/cosmic/alma10/core.yml
  recipes/images/workstation/cosmic/alma10/core-nvidia-open.yml
  recipes/images/workstation/cosmic/alma10/full.yml
  recipes/images/workstation/cosmic/alma10/full-nvidia-open.yml
  recipes/images/console/alma10/core.yml
  recipes/images/console/alma10/core-nvidia-open.yml
)

for recipe in "${expected_recipes[@]}"; do
  [ -f "$recipe" ] || {
    printf 'Missing supported recipe: %s\n' "$recipe" >&2
    exit 1
  }
done

for retired_dir in recipes/images/core recipes/images/gnome recipes/images/cosmic; do
  [ ! -e "$retired_dir" ] || {
    printf 'Retired recipe directory still present: %s\n' "$retired_dir" >&2
    exit 1
  }
done

unsupported_globs=(
  'recipes/images/server/alma9/core*.yml'
  'recipes/images/server/alma10/core*.yml'
  'recipes/images/console/alma9/*.yml'
  'recipes/images/console/alma10/full*.yml'
  'recipes/images/workstation/*/alma10/*legacy*.yml'
)

for pattern in "${unsupported_globs[@]}"; do
  if compgen -G "$pattern" >/dev/null; then
    printf 'Found unsupported recipe pattern: %s\n' "$pattern" >&2
    compgen -G "$pattern" >&2
    exit 1
  fi
done

workflow_recipes="$(sed -n 's/.*recipe: \(\/images\/.*\.yml\).*/recipes\1/p' .github/workflows/build.yml | sort)"
expected_workflow_recipes="$(printf '%s\n' \
  /images/server/alma9/full.yml \
  /images/server/alma9/full-nvidia-open.yml \
  /images/server/alma9/full-nvidia-legacy.yml \
  /images/server/alma10/full.yml \
  /images/server/alma10/full-nvidia-open.yml \
  /images/workstation/gnome/alma9/core.yml \
  /images/workstation/gnome/alma9/core-nvidia-open.yml \
  /images/workstation/gnome/alma9/core-nvidia-legacy.yml \
  /images/workstation/gnome/alma9/full.yml \
  /images/workstation/gnome/alma9/full-nvidia-open.yml \
  /images/workstation/gnome/alma9/full-nvidia-legacy.yml \
  /images/workstation/gnome/alma10/core.yml \
  /images/workstation/gnome/alma10/core-nvidia-open.yml \
  /images/workstation/gnome/alma10/full.yml \
  /images/workstation/gnome/alma10/full-nvidia-open.yml \
  /images/workstation/cosmic/alma9/core.yml \
  /images/workstation/cosmic/alma9/core-nvidia-open.yml \
  /images/workstation/cosmic/alma9/core-nvidia-legacy.yml \
  /images/workstation/cosmic/alma9/full.yml \
  /images/workstation/cosmic/alma9/full-nvidia-open.yml \
  /images/workstation/cosmic/alma9/full-nvidia-legacy.yml \
  /images/workstation/cosmic/alma10/core.yml \
  /images/workstation/cosmic/alma10/core-nvidia-open.yml \
  /images/workstation/cosmic/alma10/full.yml \
  /images/workstation/cosmic/alma10/full-nvidia-open.yml \
  /images/console/alma10/core.yml \
  /images/console/alma10/core-nvidia-open.yml \
| sed 's#^#recipes#' | sort)"

if [ "$workflow_recipes" != "$expected_workflow_recipes" ]; then
  printf 'Workflow recipe matrix does not match the supported image set.\n' >&2
  diff -u <(printf '%s\n' "$expected_workflow_recipes") <(printf '%s\n' "$workflow_recipes") >&2 || true
  exit 1
fi
