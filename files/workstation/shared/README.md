# workstation/shared/

This tree contains DE-agnostic workstation payloads shared by GNOME and COSMIC.

It now focuses on workstation behavior that is truly about the workstation role itself.

## Current ownership

- the shared display-manager reconciliation unit and helper
- shared tmpfiles/relabel snippets for workstation runtime state
- workstation-wide payloads that are not specific to GNOME or COSMIC

Flatpak governance payloads moved to `files/end-user/shared/` so Workstation and Console can share the same end-user app model.

## Display-manager reconciliation

Workstation images ship:

- `usr/lib/systemd/system/myos-workstation-dm-apply.service`
- `usr/libexec/myos-workstation-dm-apply`

That helper reads the active family marker from `/usr/share/myos/workstation/desktop.env` and repairs stale `display-manager.service` ownership after bootc rebases.

It also queues the selected display manager on the first boot after a rebase, so
the handoff is not delayed until the next reboot while still avoiding a boot-time
ordering deadlock.

For COSMIC deployments, the helper also reconciles the `cosmic-greeter` PAM file
with `pam_gnome_keyring.so` when the module is installed, which keeps keyring
unlock support aligned even when `/etc` persists across image switches.

The shared tmpfiles payload also restores the policy-defined writable labels for
TuneD runtime state files under `/etc/tuned`, which avoids SELinux denials when
`tuned-ppd` updates the power-profile state on deployments that retained generic
`/etc` labels.
