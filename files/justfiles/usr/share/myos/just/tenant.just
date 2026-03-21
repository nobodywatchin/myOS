tenant-create *args:
    #!/usr/bin/env bash
    set -euo pipefail
    exec sudo /usr/local/libexec/myos/tenant-create "$@"

tenant-configure *args:
    #!/usr/bin/env bash
    set -euo pipefail
    exec sudo /usr/local/libexec/myos/tenant-configure "$@"

tenant-secret-set *args:
    #!/usr/bin/env bash
    set -euo pipefail
    exec sudo /usr/local/libexec/myos/tenant-secret-set "$@"

tenant-secret-import *args:
    #!/usr/bin/env bash
    set -euo pipefail
    exec sudo /usr/local/libexec/myos/tenant-secret-import "$@"

tenant-start *args:
    #!/usr/bin/env bash
    set -euo pipefail
    exec sudo /usr/local/libexec/myos/tenant-start "$@"

tenant-stop *args:
    #!/usr/bin/env bash
    set -euo pipefail
    exec sudo /usr/local/libexec/myos/tenant-stop "$@"

tenant-restart *args:
    #!/usr/bin/env bash
    set -euo pipefail
    exec sudo /usr/local/libexec/myos/tenant-restart "$@"

tenant-status *args:
    #!/usr/bin/env bash
    set -euo pipefail
    exec sudo /usr/local/libexec/myos/tenant-status "$@"

tenant-validate *args:
    #!/usr/bin/env bash
    set -euo pipefail
    exec sudo /usr/local/libexec/myos/tenant-validate "$@"

tenant-backup *args:
    #!/usr/bin/env bash
    set -euo pipefail
    exec sudo /usr/local/libexec/myos/tenant-backup "$@"

tenant-restore *args:
    #!/usr/bin/env bash
    set -euo pipefail
    exec sudo /usr/local/libexec/myos/tenant-restore "$@"

tenant-remove *args:
    #!/usr/bin/env bash
    set -euo pipefail
    exec sudo /usr/local/libexec/myos/tenant-remove "$@"

tenant:
    #!/usr/bin/env bash
    set -euo pipefail

    command -v fzf >/dev/null || { echo "Missing 'fzf'."; exit 1; }

    sel="$(fzf --prompt='Tenant action: ' --height=18 --border --exit-0 --with-nth=2.. \
      <<< $'tenant-create        Create a tenant scaffold\ntenant-configure     Configure tenant runtime settings\ntenant-secret-set    Set or rotate one tenant secret\ntenant-secret-import Import tenant secrets from env file or stdin\ntenant-start         Start the tenant service\ntenant-stop          Stop the tenant service\ntenant-restart       Reconcile and restart the tenant service\ntenant-status        Show tenant status and recent logs\ntenant-validate      Run tenant preflight and health checks\ntenant-backup        Create a tenant backup archive\ntenant-restore       Restore a tenant backup archive\ntenant-remove        Remove a tenant scaffold\n')"
    [[ -n "$sel" ]] || { echo "No selection."; exit 0; }
    target="${sel%% *}"
    echo "→ Running: myos ${target}"
    exec myos "${target}"
