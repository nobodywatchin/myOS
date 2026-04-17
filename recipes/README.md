# recipes/

This tree defines the buildable images and the reusable layers they compose.

## Image tree

```text
recipes/images/
  workstation/
    gnome/
      alma9/
      alma10/
      fedora43/
    cosmic/
      alma9/
      alma10/
      fedora43/
  server/
    alma9/
    alma10/
    fedora43/
```

The repo is role-first.

- `workstation` is the flagship desktop role.
- `server` is the headless admin/operator role.
- GNOME and COSMIC are workstation environments under the workstation role.

Supported published tags are short and come from the shipped image matrix rather than from the internal filenames.

## How images relate

- Server recipes build from an explicit distro core plus `shared/full.yml`.
- The supported workstation recipes live in the current `core*.yml` files and are now the canonical public workstation images.
- Fedora 43 has both workstation and server recipes.
- Console and workstation-full recipes are retired and should not come back without a deliberate product-model change.

## Reading order

1. open the target image under `recipes/images/**`
2. follow each `from-file:` in order
3. use `recipes/layers/README.md` to understand what each layer is allowed to own
4. use `files/README.md` when a `files` module pulls payload trees
