# Hardware

Current makes hardware and GPU policy explicit instead of hiding it behind one generic image.

## Standard lane

Images without a driver suffix are the standard lane.

Choose them when you do not need NVIDIA-specific packaging.

## NVIDIA open lane

Choose `nvidia-open` for newer supported NVIDIA GPUs on supported Alma 10 and Fedora images.

## NVIDIA 580 lane

Choose `nvidia-580` on supported Alma 9 or Fedora images when the proprietary R580 driver is needed for older supported NVIDIA GPUs.

Alma 9 uses the Alma/NVIDIA `nvidia-driver:580` module stream and prebuilt proprietary kmods. Fedora uses the BlueBuild-style path: Negativo17's Fedora 580 akmod source packages are built during the image build, verified with `modinfo`, and then the akmod/kernel-devel build path is removed from the final image. The `nvidia-580` lane is not currently available on Alma 10 in the stable matrix.

## PCP monitoring

All images include Performance Co-Pilot with `pmcd` for live metrics and `pmlogger` for local history.

NVIDIA images include the NVIDIA GPU PMDA package.

## AMD, Vulkan, and ROCm

Current treats local GPU support as host/runtime capability.

The shared baseline includes Vulkan tooling where supported by the platform lane, plus render/video group support for common GPU workflows.

ROCm userspace is platform-lane-specific. It is included where the platform lane supports it, currently Alma 10 and Fedora. Alma 9 is primarily kept for the NVIDIA 580 compatibility lane and should not be described as having the same ROCm userspace contract.

Container access to GPU hardware is still configured by the container or orchestration layer.

## Quick verification

As the target user, verify the basics:

```bash
id
vulkaninfo --summary
podman info --format '{{.Host.OCIRuntime.Name}}'
```

Useful expectations:

- `vulkaninfo --summary` should show the real GPU instead of only software rendering when the driver stack is available.
- rootless GPU container flows are safest when Podman is using `crun`.
- container access to GPU hardware should be configured explicitly by the runtime above Current.
