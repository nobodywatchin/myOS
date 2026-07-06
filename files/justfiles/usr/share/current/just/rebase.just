rebase:
    #!/usr/bin/env bash
    set -euo pipefail

    command -v fzf >/dev/null || { echo "Missing 'fzf'."; exit 1; }
    command -v curl >/dev/null || { echo "Missing 'curl'."; exit 1; }

    default_matrix_url="https://raw.githubusercontent.com/Pelagians/Current/stable/files/base/runtime/usr/share/current/image-matrix.tsv"
    matrix_url="${CURRENT_IMAGE_MATRIX_URL:-${CURRENT_IMAGE_MATRIX_URL:-$default_matrix_url}}"
    registry_namespace="${CURRENT_REGISTRY_NAMESPACE:-${CURRENT_REGISTRY_NAMESPACE:-ghcr.io/pelagians}}"
    registry_namespace="${registry_namespace%/}"

    matrix_file="$(mktemp -t current-image-matrix.XXXXXX)"
    curl_error_file="$(mktemp -t current-image-matrix-curl.XXXXXX)"
    trap 'rm -f "$matrix_file" "$curl_error_file"' EXIT

    curl_status=0
    http_code="$(curl --location --silent --show-error --connect-timeout 10 --max-time 30 --output "$matrix_file" --write-out '%{http_code}' "$matrix_url" 2>"$curl_error_file")" || curl_status=$?
    if [ "$curl_status" -ne 0 ]; then
      case "$curl_status" in
        5|6|7|28|35)
          echo "Could not reach GitHub to download the image matrix from $matrix_url. Check your internet connection." >&2
          ;;
        *)
          echo "Failed to download the image matrix from $matrix_url." >&2
          ;;
      esac
      if [ -s "$curl_error_file" ]; then
        cat "$curl_error_file" >&2
      fi
      exit 1
    fi

    case "$http_code" in
      200)
        ;;
      404)
        echo "No image matrix found at $matrix_url." >&2
        exit 1
        ;;
      *)
        echo "GitHub returned HTTP $http_code while downloading the image matrix from $matrix_url." >&2
        exit 1
        ;;
    esac

    expected_header=$'job\tplatform\trole\tenvironment\tdriver\timage\trecipe'
    if ! IFS= read -r actual_header < "$matrix_file"; then
      echo "No image matrix entries were found at $matrix_url." >&2
      exit 1
    fi
    actual_header="${actual_header%$'\r'}"
    if [ "$actual_header" != "$expected_header" ]; then
      echo "Downloaded image matrix from $matrix_url, but it did not have the expected TSV header." >&2
      exit 1
    fi

    picker_status=0
    picker_rows="$(awk -F $'\t' '
      NR == 1 { next }
      NF != 7 {
        printf "Invalid image matrix row %d: expected 7 tab-separated fields.\n", NR > "/dev/stderr"
        bad = 1
        next
      }
      {
        found = 1
        role = toupper(substr($3, 1, 1)) substr($3, 2)
        environment = $4
        if (environment == "gnome") {
          environment = "GNOME"
        } else if (environment == "cosmic") {
          environment = "COSMIC"
        } else {
          environment = toupper(substr(environment, 1, 1)) substr(environment, 2)
        }
        printf "%s | %s | %s | %s | %s:latest\n", role, environment, $2, $5, $6
      }
      END {
        if (bad) {
          exit 3
        }
        if (!found) {
          exit 2
        }
      }
    ' "$matrix_file")" || picker_status=$?

    case "$picker_status" in
      0)
        ;;
      2)
        echo "No image matrix entries were found at $matrix_url." >&2
        exit 1
        ;;
      *)
        echo "Could not parse the image matrix downloaded from $matrix_url." >&2
        exit 1
        ;;
    esac

    sel="$(printf '%s\n' "$picker_rows" | fzf           --delimiter='\|'           --with-nth=1,2,3,4           --header='Role | Environment | Platform | Driver'           --prompt='Select image: ')" || { echo "No image selected"; exit 1; }

    test -n "$sel" || { echo "No image selected"; exit 1; }

    tag="$(printf '%s\n' "$sel" | cut -d'|' -f5 | tr -d ' ')"
    ref="${registry_namespace}/${tag}"
    echo "Selected: $ref"
    echo "Executing: sudo bootc switch $ref"
    sudo bootc switch "$ref"
    echo "Workstation images re-apply the correct display-manager ownership on boot after the switch."
    echo "bootc auto-apply is disabled in Current; reboot when you are ready to activate the new image."
