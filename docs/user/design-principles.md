# Design Principles

myOS follows a small set of product rules.

- Stable foundation, modern experience: use the Alma base for calm long-lived behavior, then spend effort on the image and user experience.
- Curated, not inherited: each image should carry what fits its contract instead of inheriting operator stacks by accident.
- Hardware policy is explicit: GPU lanes are a conscious product choice, not something users are expected to reverse-engineer.
- Desktop first, family model: Workstation is the product role, with GNOME and COSMIC as implementations of that role.
- Governance without loss of ownership: system-wide app policy is curated, but user installs and user-owned runtime state still belong to the user.
- AI-ready, not AI-bloated: ship practical local capability, not hype-driven services or preloaded models.
