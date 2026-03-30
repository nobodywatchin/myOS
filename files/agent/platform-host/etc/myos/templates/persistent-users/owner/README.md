# Owner-only persistent-user role

Anything dropped into `owner/quadlets/` is installed only for the one login
user selected through `myos persistent-user-set-owner --user <name>`.

Use this for rootless background workloads that should follow a designated owner
without making every other opted-in user run the same service.
