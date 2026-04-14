# Hardware

myOS makes GPU policy explicit instead of hiding it behind one generic image.

## Default lane

Choose `default` when you do not need NVIDIA-specific packaging.

## NVIDIA open lane

Choose `nvidia-open` for newer supported NVIDIA GPUs on Alma 9 or Alma 10.

## NVIDIA legacy lane

Choose `nvidia-legacy` only on Alma 9.

That lane is first-class and intentionally pinned to the proprietary `nvidia-driver:580` stream for supported older GPUs. It is not available on Alma 10.

## AMD and ROCm

ROCm userspace stays in the core contract across all roles.

That means local AMD-oriented compute readiness is present even on core images, without forcing hosted services or model payloads into the image.

## Console role

Console currently exists only on Alma 10 and only as a core-tier preview role. It reuses the end-user runtime/app model and keeps room for gaming-oriented evolution without pretending the role is finished today.
