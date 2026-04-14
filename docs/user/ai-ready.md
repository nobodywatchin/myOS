# AI-Ready

In myOS, AI-ready means local capability without forced platform identity.

## What core images include

- ROCm userspace
- the `openquad` command
- the shipped per-user OpenClaw Quadlet template
- user-owned runtime paths under the user's home directory

The per-user runtime stays inert until the user chooses to install and start it.

## What full images add

- tenant tooling
- persistent-user admin tooling
- `openclaw-host`
- related platform-host scaffolding

Those are real advanced capabilities, but they are not the default identity of every workstation image anymore.

## What myOS does not do

- it does not force hosted OpenClaw flows on ordinary workstation users
- it does not preload models as branding theater
- it does not pretend every image is an operator appliance
