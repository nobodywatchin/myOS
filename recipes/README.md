# recipes/

This tree defines the buildable images and the reusable layers they compose.

## Image tree

```text
recipes/images/
  workstation/
    gnome/
      alma9/
      alma10/
    cosmic/
      alma9/
      alma10/
  server/
    alma9/
    alma10/
  console/
    alma10/
```

The repo is role-first now.

- `workstation` is the flagship role.
- `server` is the full-tier admin/operator role.
- `console` is the Alma 10 core-only preview role.

GNOME and COSMIC are workstation families under the workstation role.

## How images relate

- Server full recipes build directly from the AlmaLinux BootC base and publish the compatibility `core-full-*` tags.
- Workstation full recipes still build on top of the published `core-full-*` images for compatibility.
- Workstation core recipes build directly from the shared core plus workstation layers.
- Console core recipes build directly from the shared core plus end-user and console layers.

## Reading order

1. open the target image under `recipes/images/**`
2. follow each `from-file:` in order
3. use `recipes/layers/README.md` to understand what each layer is allowed to own
4. use `files/README.md` when a `files` module pulls payload trees
