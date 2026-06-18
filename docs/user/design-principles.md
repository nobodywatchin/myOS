# Design Principles

myOS follows a small set of product rules.

- Infrastructure first, workstation included: myOS is built for homelabs, self-hosted systems, small internal labs, servers, and operator machines.
- Boring base, useful surface: the system should be predictable, rebuildable, and easy to reason about before it is interesting.
- Shared operating model: servers, desktops, laptops, and lab machines should follow the same image-based system model where practical.
- Curated, not inherited: each image should carry what fits its contract instead of inheriting operator stacks by accident.
- Hardware policy is explicit: GPU lanes are a conscious product choice, not something users are expected to reverse-engineer.
- Workstation is the operator desktop lane: GNOME and COSMIC are workstation environments, not separate products.
- Governance without loss of ownership: system-wide app policy is curated, but user installs and user-owned runtime state still belong to the user.
- AI-ready, not AI-bloated: ship practical local capability, not hype-driven services, preloaded models, or forced hosted infrastructure.
