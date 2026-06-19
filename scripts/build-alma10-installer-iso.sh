#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PAYLOAD_REF="${MYOS_INSTALLER_PAYLOAD_REF:-ghcr.io/myos-dev/alma10-server:latest}"
INSTALLER_IMAGE="${MYOS_INSTALLER_IMAGE:-localhost/myos-alma10-server-installer:dev}"
BUILDER_IMAGE="${BOOTC_IMAGE_BUILDER:-quay.io/centos-bootc/bootc-image-builder:latest}"
ROOTFS="${MYOS_INSTALLER_ROOTFS:-xfs}"
OUTPUT_DIR="${MYOS_INSTALLER_OUTPUT_DIR:-$REPO_ROOT/output/installer/alma10-server}"
CONFIG="${MYOS_INSTALLER_CONFIG:-$REPO_ROOT/installer/alma10-server/iso.toml}"
CONTAINERFILE="${MYOS_INSTALLER_CONTAINERFILE:-$REPO_ROOT/installer/alma10-server/Containerfile}"
PODMAN="${PODMAN:-podman}"
SUDO="${SUDO:-sudo}"

if [[ ! -f "$CONFIG" ]]; then
  echo "Missing installer config: $CONFIG" >&2
  exit 1
fi

if [[ ! -f "$CONTAINERFILE" ]]; then
  echo "Missing installer Containerfile: $CONTAINERFILE" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

cat <<EOF
== myOS Alma 10 installer ISO build ==
Payload ref:     $PAYLOAD_REF
Installer image: $INSTALLER_IMAGE
Builder image:   $BUILDER_IMAGE
Rootfs:          $ROOTFS
Config:          $CONFIG
Output:          $OUTPUT_DIR
EOF

$SUDO "$PODMAN" pull "$PAYLOAD_REF"

$SUDO "$PODMAN" build \
  --build-arg "MYOS_PAYLOAD_REF=$PAYLOAD_REF" \
  -f "$CONTAINERFILE" \
  -t "$INSTALLER_IMAGE" \
  "$REPO_ROOT"

$SUDO "$PODMAN" pull "$BUILDER_IMAGE"

$SUDO "$PODMAN" run \
  --rm \
  --privileged \
  --pull=newer \
  --security-opt label=type:unconfined_t \
  -v "$CONFIG:/config.toml:ro" \
  -v "$OUTPUT_DIR:/output" \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  "$BUILDER_IMAGE" \
  build \
  --type bootc-installer \
  --rootfs "$ROOTFS" \
  --installer-payload-ref "$PAYLOAD_REF" \
  --output /output \
  "$INSTALLER_IMAGE"

ISO_PATH="$(find "$OUTPUT_DIR" -type f -iname '*.iso' | head -n1 || true)"

if [[ -z "$ISO_PATH" ]]; then
  echo "No ISO produced under $OUTPUT_DIR" >&2
  find "$OUTPUT_DIR" -maxdepth 4 -type f -print >&2 || true
  exit 1
fi

sha256sum "$ISO_PATH" | tee "$ISO_PATH.sha256"

cat <<EOF
== installer ISO complete ==
ISO:    $ISO_PATH
SHA256: $ISO_PATH.sha256
EOF
