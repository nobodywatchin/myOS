rebase:
    #!/usr/bin/env bash
    set -euo pipefail

    command -v fzf >/dev/null || { echo "Missing 'fzf'."; exit 1; }

    matrix_file="/usr/share/myos/image-matrix.tsv"
    [ -r "$matrix_file" ] || { echo "Missing image matrix at $matrix_file."; exit 1; }

    sel="$(awk -F '\t' '
      NR == 1 { next }
      {
        role = toupper(substr($2, 1, 1)) substr($2, 2)
        printf "%s | %s | %s | %s | %s | %s:latest\n", role, $3, $4, $5, $6, $7
      }
    ' "$matrix_file" | fzf \
      --delimiter='\|' \
      --with-nth=1,2,3,4,5 \
      --header='Role | Tier | Family | Distro | Hardware' \
      --prompt='Select image: ')"

    test -n "$sel" || { echo "No image selected"; exit 1; }

    tag="$(printf '%s\n' "$sel" | cut -d'|' -f6 | tr -d ' ')"
    ref="ghcr.io/myos-dev/${tag}"
    echo "Selected: $ref"
    echo "Executing: sudo bootc switch $ref"
    sudo bootc switch "$ref"
    echo "Workstation images re-apply the correct display-manager ownership on boot after the switch."
    echo "bootc auto-apply is disabled in myOS; reboot when you are ready to activate the new image."
