[positional-arguments]
persistent-user-enroll *args:
    #!/usr/bin/env bash
    set -euo pipefail
    exec sudo /usr/local/libexec/myos/persistent-user-enroll "$@"

[positional-arguments]
persistent-user-remove *args:
    #!/usr/bin/env bash
    set -euo pipefail
    exec sudo /usr/local/libexec/myos/persistent-user-remove "$@"

[positional-arguments]
persistent-user-set-owner *args:
    #!/usr/bin/env bash
    set -euo pipefail
    exec sudo /usr/local/libexec/myos/persistent-user-set-owner "$@"

[positional-arguments]
persistent-user-validate *args:
    #!/usr/bin/env bash
    set -euo pipefail
    exec sudo /usr/local/libexec/myos/persistent-user-validate "$@"

[positional-arguments]
persistent-user-install-quadlet *args:
    #!/usr/bin/env bash
    set -euo pipefail
    exec /usr/local/libexec/myos/persistent-user-install-quadlet "$@"

persistent-user:
    #!/usr/bin/env bash
    set -euo pipefail

    command -v fzf >/dev/null || { echo "Missing 'fzf'."; exit 1; }

    sel="$(fzf --prompt='Persistent user action: ' --height=18 --border --exit-0 --with-nth=2.. \
      <<< $'persistent-user-enroll            Enroll a login user for lingering + baseline services\npersistent-user-set-owner         Assign or transfer the owner-only role\npersistent-user-validate          Validate a persistent-user enrollment\npersistent-user-remove            Remove managed persistent-user services\npersistent-user-install-quadlet   Install a self-service Quadlet into ~/.config/containers/systemd\n')"
    [[ -n "$sel" ]] || { echo "No selection."; exit 0; }
    target="${sel%% *}"
    echo "→ Running: myos ${target}"
    exec myos "${target}"
