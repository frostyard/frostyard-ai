---
name: mkosi-config
description: >
  WHEN: Working with mkosi configuration files, mkosi.conf, Include= directives.
  WHEN NOT: General Linux configuration, non-mkosi build systems.
---

# mkosi Configuration Composition

Brief guide to mkosi's configuration system as used in frostyard image builds.

## Configuration Hierarchy

mkosi composes configuration from multiple levels:

```
mkosi.conf (root)          # Global settings: distribution, repos, output
├── mkosi.images/          # Image definitions (base + sysexts)
│   ├── base/mkosi.conf    # Base image: core packages, format=directory
│   ├── dev/mkosi.conf     # Sysext: development tools
│   ├── docker/mkosi.conf  # Sysext: Docker runtime
│   └── ...                # Each sysext has its own mkosi.conf
├── mkosi.profiles/        # Desktop image variants
│   ├── snow/              # Snow desktop profile
│   ├── snowloaded/        # Snow + all sysexts
│   └── ...
└── shared/                # Reusable fragments included via Include=
    ├── kernel/            # Kernel configs (backports, surface, stock)
    ├── packages/          # Package set definitions
    ├── outformat/         # Output format configs
    └── sysext/            # Shared sysext scripts
```

## Root mkosi.conf

The root config sets global defaults inherited by all images:

- `Distribution=debian`, `Release=trixie`
- `Repositories=main,contrib,non-free,non-free-firmware`
- `CacheDirectory=mkosi.cache`, `Incremental=yes`
- `WithNetwork=true` (needed for package downloads)
- `Dependencies=` lists all images that must build (base + all sysexts)
- `BaseTrees=%O/base` — all images layer on top of the base image output

## Image Definitions (mkosi.images/)

Each subdirectory under `mkosi.images/` defines one buildable image.

**Base image** (`mkosi.images/base/mkosi.conf`):
- `Format=directory` — outputs a directory tree, not a disk image
- Contains core packages: systemd, bootc, NetworkManager, firmware, etc.
- All other images use `BaseTrees=%O/base` to layer on this

**Sysext images** (e.g., `mkosi.images/dev/mkosi.conf`):
- `Format=sysext` — outputs a system extension
- `Overlay=yes` — only includes files not in the base
- `Dependencies=base` — requires base to build first
- `PostOutputScripts=%D/shared/sysext/postoutput/sysext-postoutput.sh`
- `Environment=KEYPACKAGE=<pkg>` — identifies the primary package for versioning

## Profiles (mkosi.profiles/)

Profiles define desktop image variants that compose:
- Package sets from `shared/packages/`
- Kernel variant from `shared/kernel/`
- Output format from `shared/outformat/`
- Build/postinstall/finalize/postoutput scripts

## Include= Directive

`Include=` pulls in additional config fragments:

```ini
[Config]
Include=../../shared/packages/desktop.conf
         ../../shared/kernel/backports.conf
         ../../shared/outformat/image/image.conf
```

Paths are relative to the config file using the directive. Fragments are merged in order — later values override earlier ones for single-value keys; list keys accumulate.

## Key Variables

- `%D` — source directory (repo root)
- `%O` — output directory for the current image
- `%o` — output path of the current image

## Adding a New Sysext

1. Create `mkosi.images/<name>/mkosi.conf` with sysext boilerplate (copy from `dev` or `1password-cli`)
2. Set `ImageId=`, `Output=`, and `Packages=`
3. Set `Environment=KEYPACKAGE=<primary-package>`
4. Add the image name to root `mkosi.conf` `Dependencies=`
5. Create `.transfer` and `.feature` files (see `sysext-authoring` skill)
