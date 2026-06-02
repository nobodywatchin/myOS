[positional-arguments]
cluster *args:
	#!/usr/bin/env bash
	set -euo pipefail
	exec sudo /usr/local/libexec/myos/cluster "$@"
