---
name: immutable-fs
description: >
  WHEN: Filesystem layout questions, package relocation, service enablement in immutable OS images.
  WHEN NOT: Standard Linux filesystem questions for mutable systems.
---

# Immutable Filesystem Rules

Guide to the immutable filesystem layout used by frostyard bootc images.

## Filesystem Layout

| Path | Access | Purpose | Notes |
|------|--------|---------|-------|
| `/usr` | Read-only | Binaries, libraries, system configs | All package contents must live here |
| `/etc` | Overlay | System configuration | Overlay on `/usr/etc`. Base configs in image, user changes persist across boots |
| `/var` | Read-write | State, logs, container storage | Persistent across boots and updates |
| `/opt` | Bind-mount | Third-party software | Bind-mount to `/var/opt`. **Writable at runtime but shadowed by sysext overlays** |
| `/home` | Read-write | User data | Persistent |

## The /opt Problem

`/opt` is a bind-mount to `/var/opt`, which means it's writable at runtime. However, sysext overlays can shadow `/opt` contents, causing conflicts. Packages that install to `/opt` **must be relocated** at build time.

### Relocation Pattern

```bash
# In a postinstall script (.chroot)
set -euo pipefail

# Move from /opt to /usr/lib
mv /opt/<package> /usr/lib/<package>

# Create symlinks for binaries
ln -sf /usr/lib/<package>/bin/<binary> /usr/bin/<binary>
```

This applies to both desktop images and sysexts. Common packages needing relocation: 1Password, some proprietary tools.

## User Service Enablement in Chroot

`systemctl --user enable` does not work inside a mkosi chroot — there's no user session or D-Bus. System services work fine via `systemctl enable`, but user services require manual symlink creation:

```bash
# In a postinstall script
mkdir -p /etc/systemd/user/<target>.wants
ln -sf /usr/lib/systemd/user/<service> /etc/systemd/user/<target>.wants/<service>
```

The target (e.g., `gnome-session.target`) comes from the service's `WantedBy=` in its `[Install]` section.

### Known Issue: deb-systemd-helper Gap

`deb-systemd-helper` creates `.dsh-also` tracking files in `/var/lib/systemd/deb-systemd-user-helper-enabled/` during the build but may not create the actual enablement symlinks in `/etc/systemd/user/`. If a user service isn't auto-starting after reboot:

1. Check if its symlink exists in `/etc/systemd/user/<target>.wants/`
2. Compare against its `.dsh-also` file
3. If missing, add a manual symlink in the build script

## Shell Script Conventions

- `set -euo pipefail` at the top of every script
- Build scripts running in chroot use `.chroot` extension (e.g., `snow.postinst.chroot`)
- Non-chroot scripts use standard `.sh` extension
- External downloads must use `verified_download()` from `shared/download/verified-download.sh`
- Always pin external URLs to specific versions/commits — never `latest` or branch names

## Sysext Filesystem Rules

Sysexts have additional constraints beyond the base image:

- Can ONLY provide files under `/usr`
- Cannot modify `/etc` or `/var` at runtime
- For `/etc` configs, use the factory pattern:
  1. Capture to `/usr/share/factory/etc/` during build
  2. Inject at boot via `systemd-tmpfiles` `C` (copy) directive
- See `sysext-authoring` skill for details
