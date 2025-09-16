#!/usr/bin/env bash
set -euo pipefail

# Run akmods if NVIDIA akmod is present (-nvidia images),
# or if wl akmod is installed AND this machine actually needs wl.
if rpm -q akmod-nvidia >/dev/null 2>&1; then
  exit 0
fi

if rpm -q akmod-wl >/dev/null 2>&1 && /usr/local/sbin/needs-wl.sh; then
  exit 0
fi

# Optional: avoid noisy failures when Secure Boot key isn't enrolled yet.
if mokutil --sb-state 2>/dev/null | grep -qi 'SecureBoot enabled'; then
  if ! mokutil --test-key /etc/pki/akmods/certs/public_key.der >/dev/null 2>&1; then
    logger -t akmods-should-run 'Skipping akmods: Secure Boot enabled and akmods key not enrolled'
    exit 1
  fi
fi

# Otherwise: skip akmods cleanly (ExecCondition= failure => unit is "skipped", not "failed").
exit 1
