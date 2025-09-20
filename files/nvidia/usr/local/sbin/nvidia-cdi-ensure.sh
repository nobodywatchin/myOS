#!/usr/bin/env bash
set -euo pipefail

# Remove the legacy OCI hook to avoid CDI conflicts
rm -f /usr/share/containers/oci/hooks.d/oci-nvidia-hook.json || true

# Ensure CDI directory exists
mkdir -p /etc/cdi

# If there’s no CDI spec yet and we appear to have NVIDIA devices, generate it
if [ ! -s /etc/cdi/nvidia.yaml ]; then
  if ls /dev/nvidia* >/dev/null 2>&1 || ls /dev/dri/renderD* >/dev/null 2>&1; then
    # Force CDI mode so podman can use --device nvidia.com/gpu=…
    nvidia-ctk config --in-place --set nvidia-container-runtime.mode=cdi || true

    # Generate the CDI spec (covers full GPUs and MIG if present)
    nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml || true
  fi
fi
