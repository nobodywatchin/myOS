# Updates And Rollbacks

myOS keeps updates explicit.

## Updates

Use the project wrapper to update managed system Flatpaks, remove unused system Flatpak refs, and stage an OS image update:

```bash
myos update-system
```

If you only want to stage the OS image update, use plain `bootc`:

```bash
sudo bootc upgrade
```

To remove unused system Flatpak refs, including stale pinned runtimes that are no longer needed by installed system apps:

```bash
myos clean-system
```

`myos clean-system` clears system runtime pins first, then lets Flatpak remove only refs it considers unused.

myOS disables the stock `bootc-fetch-apply-updates` timer and service. Updates are downloaded and applied when you choose, then activated on reboot.

## Rebase

To switch roles, environments, distro lanes, or driver lanes:

```bash
myos rebase
```

Workstation images re-apply the expected display manager on boot after a switch so GNOME and COSMIC rebases do not leave stale `display-manager.service` state behind.

## Rollback

If a new deployment is not what you want, use normal `bootc` rollback flow:

```bash
sudo bootc rollback
```

Then reboot into the previous deployment.

## User-space updates

`myos update-user` refreshes user Flatpaks, Homebrew when present on workstation images, and Distrobox containers. Current images do not ship a built-in per-user OpenClaw runtime.
