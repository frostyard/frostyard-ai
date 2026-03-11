# frostyard-ai

Claude Code plugins for the Frostyard organization. Two plugins with auto-invoked skills that activate when working on frostyard repos.

## Plugins

### frostyard-dev

Go development skills applying Uber style, modern Go idioms, and org conventions.

| Skill | Triggers when |
|-------|---------------|
| `uber-go-style` | Writing, reviewing, or refactoring Go code |
| `go-best-practices` | General Go pattern questions, code review |
| `use-modern-go` | Any Go code work (detects version from go.mod) |
| `go-app-makefile` | Creating or updating a Go project Makefile |
| `frostyard-conventions` | Working in any frostyard GitHub org repo |

Priority order: Modern Go > Uber Guide > Go best practices > Frostyard conventions.

### frostyard-os

mkosi/bootc image building skills for Debian-based immutable OS images.

| Skill | Triggers when |
|-------|---------------|
| `mkosi-config` | Working with mkosi configuration files |
| `sysext-authoring` | Creating or modifying system extensions |
| `image-building` | Building, testing, or publishing bootc/mkosi images |
| `immutable-fs` | Filesystem layout or package relocation questions |

## Install from local checkout

Clone the repo and install each plugin locally:

```bash
git clone https://github.com/frostyard/frostyard-ai.git
cd frostyard-ai

# Install both plugins
claude plugin install --local ./plugins/frostyard-dev
claude plugin install --local ./plugins/frostyard-os
```

Skills activate automatically based on context -- no slash commands needed.

To update after pulling new changes:

```bash
git pull
claude plugin install --local ./plugins/frostyard-dev
claude plugin install --local ./plugins/frostyard-os
```

To uninstall:

```bash
claude plugin remove frostyard-dev
claude plugin remove frostyard-os
```

## License

MIT
