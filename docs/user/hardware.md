# Hardware

myOS makes hardware and GPU policy explicit instead of hiding it behind one generic image.

## Standard lane

Images without a driver suffix are the standard lane.

Choose them when you do not need NVIDIA-specific packaging.

## NVIDIA open lane

Choose `nvidia-open` for newer supported NVIDIA GPUs on supported Alma 10 and Fedora images.

## NVIDIA 580 lane

Choose `nvidia-580` only on Alma 9.

That lane is intentionally pinned to the proprietary `nvidia-driver:580` stream for supported older GPUs. It is not available on Alma 10 or Fedora.

## PCP monitoring

All images include Performance Co-Pilot with `pmcd` for live metrics and `pmlogger` for local history.

NVIDIA images also include the NVIDIA GPU PMDA and register it automatically on boot so NVIDIA metrics are available through PCP without a manual PMDA install step.

## AMD, Vulkan, and ROCm

myOS treats AMD and local GPU support as host/runtime capability.

The shared baseline provides host-side pieces that are useful across image roles, including Vulkan tooling where supported and the DRM/KFD access prerequisites needed for local GPU workflows.

ROCm userspace is platform-lane-specific. It is included where the platform lane supports it, currently Alma 10 and Fedora. Alma 9 is primarily kept for the NVIDIA 580 compatibility lane and should not be described as having the same ROCm userspace contract.

For actual device-node access:

- local graphical sessions can use the DRM/KFD `uaccess` ACL path
- headless or long-lived rootless service users on server images should use `myos persistent-user-enroll --user <name>`, which adds `render` and `video`

myOS does not auto-inject `/dev/dri` or `/dev/kfd` into every rootless container. Local GPU containers and hosted OpenClaw workloads must still opt into explicit device pass-through.

## Admin steps for GPU access

If an admin wants a login user to run host Vulkan tools or rootless GPU-aware containers, use one of these paths.

### Server images: supported myOS enrollment path

Use this when the user is meant to host long-lived rootless workloads:

```bash
sudo myos persistent-user-enroll --user alice
