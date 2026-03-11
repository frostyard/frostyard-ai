---
name: image-building
description: >
  WHEN: Building, testing, or publishing bootc/mkosi images.
  WHEN NOT: General container/Docker workflows unrelated to mkosi.
---

# Image Building Pipeline

Guide to building, testing, and publishing frostyard OS images with mkosi and just.

## Prerequisites

- mkosi v24+
- just (command runner)
- Root/sudo access (mkosi builds require privileges)

Install on Debian/Ubuntu:
```bash
pipx install mkosi          # mkosi v24+ (not available in distro repos)
sudo apt install just buildah systemd-container
```

## Build Commands

```bash
just                    # List all targets
just sysexts            # Build base + all 8 sysexts
just snow               # Build snow desktop image
just snowloaded         # Build snowloaded variant
just snowfield          # Build snowfield (Surface kernel)
just snowfieldloaded    # Build snowfieldloaded variant
just clean              # Remove build artifacts
```

All `just` targets run `mkosi clean` first — every build is a clean build.

## Script Execution Pipeline

For each image, mkosi runs scripts in this order:

1. **BuildScripts** — run inside chroot during package installation phase
2. **PostInstallationScripts** — run after all packages are installed
3. **FinalizeScripts** — run just before output creation
4. **PostOutputScripts** — run after image is created (outside chroot)

Scripts are specified in mkosi.conf via `BuildScripts=`, `PostInstallationScripts=`, etc. Scripts in profiles compose with (not replace) base image scripts.

## Shell Script Conventions

- Always start with `set -euo pipefail`
- Build scripts that run in chroot use `.chroot` file extension
- Keep scripts focused — one purpose per script

## Verified Download System

External binaries and resources are downloaded with integrity verification:

- `shared/download/checksums.json` — pins URLs with SHA256 hashes and versions
- `shared/download/verified-download.sh` — provides the `verified_download()` helper

Usage in build scripts:
```bash
source "$BUILDROOT/../shared/download/verified-download.sh"
verified_download "package-key" "/tmp/package.deb"
dpkg -i /tmp/package.deb
```

### Adding a new verified download:

1. Add entry to `shared/download/checksums.json`:
   ```json
   {
     "package-key": {
       "url": "https://example.com/package-1.0.0-amd64.deb",
       "sha256": "<hash>",
       "version": "1.0.0"
     }
   }
   ```

2. Pin to a specific version/commit — never use `latest` or branch names

3. Add a corresponding update check to `.github/workflows/check-dependencies.yml`

## OCI Packaging

Desktop images are packaged as OCI containers via `shared/outformat/image/buildah-package.sh`:
- Runs as a PostOutputScript
- Uses buildah to create OCI images from the directory output
- Pushes to `ghcr.io` in CI

To build an OCI image locally:
```bash
just snow                   # Builds image + runs buildah packaging
buildah images              # Verify the OCI image was created
```

The `just` targets for desktop profiles automatically invoke the buildah postoutput script.

## CI/CD

| Workflow | Purpose |
|----------|---------|
| `build.yml` | Builds base + sysexts, publishes to Frostyard repo (Cloudflare R2) |
| `build-images.yml` | Matrix build of 4 desktop profiles, pushes OCI to ghcr.io |
| `check-dependencies.yml` | Weekly check for external dependency updates, creates PRs |

## Building a Single Sysext for Testing

```bash
sudo mkosi -f -i <sysext-name>
```

This builds only the specified image (plus its dependencies like `base`).

## Testing in a VM

Boot a built desktop image with QEMU:

```bash
sudo mkosi qemu                    # Boot the default profile image
sudo mkosi -p snow qemu            # Boot a specific profile
```

mkosi handles VM configuration (UEFI, TPM, disk) automatically. Use `Ctrl-A X` to exit QEMU.

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Permission denied | Missing sudo | All mkosi builds require `sudo` |
| Package not found | Missing repository | Check `Repositories=` in root mkosi.conf |
| Script fails silently | Missing `set -euo pipefail` | Add to top of every script |
| Sysext not in output | Missing from `Dependencies=` | Add image name to root mkosi.conf |
| Stale build artifacts | Incremental cache | Run `just clean` or `mkosi clean` first |

For verbose output: `sudo mkosi -f -i <name> --debug`
