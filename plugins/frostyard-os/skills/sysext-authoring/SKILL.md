---
name: sysext-authoring
description: >
  WHEN: Creating or modifying system extensions (sysexts).
  WHEN NOT: Working on base images or desktop profiles without sysext involvement.
---

# System Extension (Sysext) Authoring

Guide to creating and modifying systemd system extensions for frostyard OS images.

## What is a Sysext?

A system extension (sysext) is an overlay image that extends `/usr` on an immutable OS. Sysexts are managed by `systemd-sysupdate` and applied at boot via `systemd-sysext`.

## Constraints

- Sysexts can **ONLY** provide files under `/usr`
- Cannot modify `/etc` or `/var` at runtime
- For configs needed in `/etc`, use the factory pattern (see below)

## Sysext mkosi.conf Template

Minimal sysext config (copy from existing like `1password-cli`):

```ini
[Config]
Dependencies=base

[Output]
ImageId=<name>
Output=<name>
Overlay=yes
ManifestFormat=json
Format=sysext

[Content]
Bootable=no
BaseTrees=%O/base
PostOutputScripts=%D/shared/sysext/postoutput/sysext-postoutput.sh
Environment=KEYPACKAGE=<primary-package>

Packages=<package-list>
```

Key fields:
- `Overlay=yes` — only includes files that differ from the base
- `Format=sysext` — produces a sysext image
- `KEYPACKAGE` — the primary package whose version is used for sysext naming
- `PostOutputScripts` — MUST point to the shared postoutput script

## Required sysupdate.d Files

Every sysext needs two files in `mkosi.images/base/mkosi.extra/usr/lib/sysupdate.d/`:

### Transfer file (`<name>.transfer`)

Tells `systemd-sysupdate` how to download the sysext:

```ini
[Transfer]
Features=<name>
Verify=false

[Source]
Type=url-file
Path=https://repository.frostyard.org/ext/<name>/
 MatchPattern=<name>_@v_@a.raw.zst \
             <name>_@v_@a.raw.xz \
             <name>_@v_@a.raw.gz \
             <name>_@v_@a.raw

[Target]
Type=regular-file
Path=/var/lib/extensions.d/
 MatchPattern=<name>_@v_@a.raw.zst \
             <name>_@v_@a.raw.xz \
             <name>_@v_@a.raw.gz \
             <name>_@v_@a.raw
CurrentSymlink=<name>.raw
```

### Feature file (`<name>.feature`)

Provides metadata and default enable state:

```ini
[Feature]
Description=<Human-readable description>
Documentation=https://frostyard.org
Enabled=false
```

`Enabled=false` is the default — users opt-in to sysexts.

## Shared Postoutput Script

The script at `shared/sysext/postoutput/sysext-postoutput.sh` runs after image creation:

1. Validates `KEYPACKAGE` env var is set
2. Reads the manifest JSON from the output directory
3. Extracts version of `KEYPACKAGE` from the manifest
4. Extracts architecture from the manifest
5. Renames output: `<name>_<version>_<arch>.raw[.zst|.xz|.gz]`
6. Creates a symlink to the versioned file
7. Creates a versioned manifest JSON

Do not modify this script per-sysext. If custom post-processing is needed, add a separate script.

## Version Management

Package versions come from the APT repositories configured in mkosi. To update a sysext's version:

1. The version is determined by the `KEYPACKAGE` version in the repository
2. For pinned/external packages, update the version in `shared/download/checksums.json`
3. Rebuild: `sudo mkosi -f -i <name>` — the postoutput script extracts and applies the new version

## Factory Pattern for /etc Configs

When a sysext needs files in `/etc` at runtime:

1. In the build, capture configs to `/usr/share/factory/etc/`:
   ```bash
   # In mkosi.finalize or postinstall script
   mkdir -p /usr/share/factory/etc/myapp
   cp /etc/myapp/config.toml /usr/share/factory/etc/myapp/
   ```

2. Create a tmpfiles rule to inject at boot:
   ```ini
   # /usr/lib/tmpfiles.d/myapp.conf
   C /etc/myapp - - - - /usr/share/factory/etc/myapp
   ```

This works because `systemd-tmpfiles` runs early in boot and copies factory defaults to `/etc` if they don't already exist.

## Service Enablement in Sysexts

Sysexts cannot run `systemctl enable` at build time. To enable a systemd service shipped by a sysext:

**System services:** Use a systemd preset file:
```ini
# /usr/lib/systemd/system-preset/50-<name>.preset
enable <service-name>.service
```

**User services:** Use the factory pattern to create the enablement symlink:
```bash
# In postinstall script
mkdir -p /usr/share/factory/etc/systemd/user/<target>.wants
ln -sf /usr/lib/systemd/user/<service> /usr/share/factory/etc/systemd/user/<target>.wants/<service>
```

Then add a tmpfiles rule:
```ini
# /usr/lib/tmpfiles.d/<name>-user-service.conf
C /etc/systemd/user/<target>.wants/<service> - - - - /usr/share/factory/etc/systemd/user/<target>.wants/<service>
```

## Step-by-Step: Adding a New Sysext

1. **Create the mkosi.conf:**
   ```bash
   mkdir mkosi.images/<name>
   # Copy and adapt from mkosi.images/1password-cli/mkosi.conf
   ```

2. **Set the config fields:** `ImageId`, `Output`, `KEYPACKAGE`, `Packages`

3. **Add to root dependencies:**
   Edit `mkosi.conf` and add `<name>` to the `Dependencies=` list

4. **Create sysupdate.d files:**
   ```bash
   # In mkosi.images/base/mkosi.extra/usr/lib/sysupdate.d/
   # Copy and adapt <name>.transfer and <name>.feature from an existing sysext
   ```

5. **Handle /opt packages** (if applicable):
   If the package installs to `/opt`, add a postinstall script to relocate:
   ```bash
   # mkosi.images/<name>/mkosi.postinst.chroot
   set -euo pipefail
   mv /opt/<package> /usr/lib/<package>
   ln -sf /usr/lib/<package>/bin/<binary> /usr/bin/<binary>
   ```

6. **Handle /etc configs** (if applicable):
   Use the factory pattern described above

7. **Test the build:**
   ```bash
   sudo mkosi -f -i <name>
   ```

## Testing a Sysext Locally

After building with `sudo mkosi -f -i <name>`:

1. Copy the `.raw` output to `/var/lib/extensions.d/`
2. Refresh sysext overlays: `sudo systemd-sysext refresh`
3. Verify the overlay: `systemd-sysext status`
4. Check files are present: `ls /usr/bin/<expected-binary>`
5. To remove: delete the `.raw` file and run `sudo systemd-sysext refresh`

## Limitations

- **Inter-sysext dependencies:** Sysexts are independent overlays. One sysext cannot depend on another. If two sysexts share a library, both must include it.
- **Removing a sysext:** Delete its `mkosi.images/<name>/` directory, remove from root `Dependencies=`, and delete its `.transfer` and `.feature` files from `mkosi.images/base/mkosi.extra/usr/lib/sysupdate.d/`.
