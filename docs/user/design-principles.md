# Design Principles

Current follows a small set of product rules.

- Developer first, infrastructure capable: Current is built for developer workstations, AI development, self-hosted systems, small internal labs, servers, and cluster hosts.
- Reliable base, useful surface: the system should be predictable, rebuildable, and easy to reason about before it is interesting.
- Image-native by default: installation, updates, rebases, rollbacks, and remixes should flow through bootc images where practical.
- Container-first: applications and services belong in containers whenever practical; the OS provides the reliable runtime underneath.
- Shared operating model: servers, desktops, laptops, and lab machines should follow the same image-based system model where practical.
- Curated, not inherited: each image should carry what fits its contract instead of inheriting operator stacks by accident.
- Hardware policy is explicit: GPU lanes are a conscious product choice, not something users are expected to reverse-engineer.
- Workstation is the developer desktop lane: GNOME and COSMIC are workstation environments, not separate products.
- Governance without loss of ownership: system-wide app policy is curated, but user installs and user-owned runtime state still belong to the user.
- AI-ready, not AI-bloated: ship practical local capability, not hype-driven services, preloaded models, or forced hosted infrastructure.
- Close to upstream: Current should add practical image-native defaults without pretending to replace the upstream distributions it builds on.
- Just enough: Current is not minimal for minimalism's sake and not bloated for convenience's sake. It should ship enough to make modern Linux practical.
