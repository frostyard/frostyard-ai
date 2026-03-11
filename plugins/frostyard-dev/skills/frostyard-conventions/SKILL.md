---
name: frostyard-conventions
description: >
  WHEN: Working in any frostyard GitHub organization repo.
  WHEN NOT: Non-frostyard repos, general Go questions.
---

# Frostyard Organization Conventions

> **Priority:** Org-specific conventions layered on top of Go standards. For Go style, see `uber-go-style`. For modern syntax, see `use-modern-go`. For Makefile setup, see `go-app-makefile`.

## Commit Messages

Use conventional commit format:

| Prefix | When |
|--------|------|
| `feat:` | New feature or capability |
| `fix:` | Bug fix |
| `refactor:` | Code restructuring without behavior change |
| `docs:` | Documentation only |
| `test:` | Test additions or fixes |
| `chore:` | Maintenance, deps, CI |
| `build(deps):` | Dependency updates |

- Keep subject line under 72 characters
- Use imperative mood: "add feature" not "added feature"
- Optional scope: `feat(cli):` or `fix(config):`

### Breaking Changes

- Append `!` after the type: `feat!: remove deprecated API` or `refactor!: rename config keys`
- While pre-1.0, breaking changes bump MINOR (e.g., v0.6.0 → v0.7.0)
- After 1.0, breaking changes bump MAJOR (e.g., v1.2.0 → v2.0.0)

## Release Process

All releases use semantic versioning via [svu](https://github.com/caarlos0/svu) and `make bump`:

1. Ensure all changes are committed and pushed
2. Run `make bump` — this will:
   - Build the binary
   - Run tests
   - Format code
   - Run linter
   - Verify clean working tree
   - Calculate next version with `svu next`
   - Create annotated git tag
   - Push tag to origin

Tag format: `vMAJOR.MINOR.PATCH` (e.g., `v0.6.0`, `v1.0.2`)

To release a specific version instead of auto-calculated: `git tag -a v0.7.0 -m "v0.7.0" && git push origin v0.7.0`

## Repository Structure

Standard Go project layout for frostyard repos:

```
<project>/
├── cmd/<binary>/       # Entry point(s)
│   └── main.go
├── internal/           # Private packages
├── Makefile            # Standard targets (see go-app-makefile skill)
├── go.mod              # Module: github.com/frostyard/<project>
├── CLAUDE.md           # AI assistant guidance
├── LICENSE             # MIT
└── README.md
```

## Module Naming

- Module path: `github.com/frostyard/<project>`
- Internal shared libraries: `github.com/frostyard/std` and `github.com/frostyard/clix`
- Use `replace` directives in `go.mod` for local development of shared libs:
  ```
  replace github.com/frostyard/snowkit => ../snowkit
  ```

## Go Version Policy

- No organization-wide minimum; each project specifies its own Go version in `go.mod`
- Actively maintained projects should track recent stable releases (1.25+)
- Use `use-modern-go` skill to apply version-appropriate patterns

## Linting

- Use `golangci-lint` as the standard linter
- Makefile `lint` target includes graceful fallback if not installed
- Run `make check` (fmt + lint + test) before commits and PRs

## CI

- GitHub Actions for all CI/CD
- Workflows live in `.github/workflows/`
- PRs run `make check` (fmt + lint + test)
- See `image-building` skill for OS image CI pipelines

## PR Workflow

- Feature branches off `main`
- Branch naming: `<type>/<short-description>` (e.g., `feat/cli-flags`, `fix/config-parse`)
- PRs require passing CI (`make check`)
- Keep PRs focused — one feature or fix per PR
- At least one team member should review before merge
- Reviewer should check: correctness, test coverage, adherence to Go style (uber-go-style + use-modern-go)
- Address review feedback with new commits, not force-pushes (preserves review context)
