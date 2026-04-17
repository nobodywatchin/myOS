# Updates And Rollbacks

myOS keeps updates explicit.

## Updates

Use the project wrapper or plain `bootc`:

```bash
myos update-system
```

or

```bash
sudo bootc upgrade
```

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

## User runtime updates

Optional per-user OpenClaw is still user-owned. If you use it, `myos update-user` can refresh the user-side runtime helpers alongside the rest of your user-space flow.
