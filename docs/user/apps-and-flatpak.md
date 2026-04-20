# Apps And Flatpak

myOS keeps two Flatpak lanes on end-user images.

## User-managed apps

`flathub` is available in user scope for normal personal app installs.

That means the default path for a user-installed app is still the user's own home directory and user session.

## Admin-managed apps

`org-system` is the image-managed system scope for curated shared apps.

It is hidden from app and source enumeration, but Flatpak can still use it for automatic runtime dependency resolution for managed system apps.

This is where the distro or an admin can keep a clean shared app set without turning every machine into an anything-goes system-wide app bucket.

## Why this split exists

The split is there so both of these can be true at once:

- users keep ownership of their own app installs
- admins still get a real, deliberate place for shared curated apps

That is why myOS keeps the system-vs-user Flatpak model instead of flattening everything into one scope.
