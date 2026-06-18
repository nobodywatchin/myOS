# Validation

Use the repo validation scripts as the source of truth for the supported image matrix.

Primary checks:

- scripts/validate-runtime-artifacts.sh
- scripts/validate-image-matrix.sh

The runtime validator checks shared payloads, image support files, workstation helpers, k3s wiring, Ceph wiring, NVIDIA wiring, and update/rebase commands.

The image-matrix validator checks that recipes, CI, and the shipped matrix describe the same supported image set.
