    rebase:
        #!/usr/bin/env bash
        set -euo pipefail

        command -v fzf >/dev/null || { echo "Missing 'fzf'."; exit 1; }

        matrix_file="/usr/share/myos/image-matrix.tsv"
        [ -r "$matrix_file" ] || { echo "Missing image matrix at $matrix_file."; exit 1; }

        sel="$(awk -F '	' '
          NR == 1 { next }
          {
            role = toupper(substr($4, 1, 1)) substr($4, 2)
            environment = $5
            if (environment == "gnome") {
              environment = "GNOME"
            } else if (environment == "cosmic") {
              environment = "COSMIC"
            } else {
              environment = toupper(substr(environment, 1, 1)) substr(environment, 2)
            }
            printf "%s | %s | %s | %s | %s:latest
", role, environment, $3, $6, $7
          }
        ' "$matrix_file" | fzf           --delimiter='\|'           --with-nth=1,2,3,4           --header='Role | Environment | Platform | Driver'           --prompt='Select image: ')"

        test -n "$sel" || { echo "No image selected"; exit 1; }

        tag="$(printf '%s
' "$sel" | cut -d'|' -f5 | tr -d ' ')"
        ref="ghcr.io/myos-dev/${tag}"
        echo "Selected: $ref"
        echo "Executing: sudo bootc switch $ref"
        sudo bootc switch "$ref"
        echo "Workstation images re-apply the correct display-manager ownership on boot after the switch."
        echo "bootc auto-apply is disabled in myOS; reboot when you are ready to activate the new image."
