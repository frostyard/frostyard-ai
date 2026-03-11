---
name: go-app-makefile
description: >
  WHEN: Creating a new Go application, setting up a Go project Makefile, or when a Go project
  lacks standard build/test/lint targets. Also when adding version injection, release tagging,
  or CI-friendly check targets.
  WHEN NOT: Non-Go projects, projects that already have a complete Makefile.
---

# Go Application Makefile

## Overview

Standard Makefile template for Go applications with build, test, lint, format, and release targets. Injects version and build time via ldflags.

## Template

```makefile
.PHONY: all build clean fmt lint test test-cover tidy install check bump help

# Build variables
VERSION?=$(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
BUILD_TIME := $(shell date -u '+%Y-%m-%dT%H:%M:%SZ')
LDFLAGS := -ldflags "-X main.version=$(VERSION) -X main.buildTime=$(BUILD_TIME) -s -w"

# Go commands
GO := go
GOFMT := gofmt
GOFILES := $(shell find . -type f -name '*.go' -not -path "./vendor/*")

all: fmt build

## build: Build the binary
build:
	$(GO) build $(LDFLAGS) -o build/<app-name> ./cmd/<app-name>

## install: Install binary to GOPATH/bin
install:
	$(GO) install $(LDFLAGS) ./cmd/<app-name>

## clean: Remove build artifacts
clean:
	rm -rf build/
	$(GO) clean

## fmt: Format Go source files
fmt:
	$(GOFMT) -w $(GOFILES)

## lint: Run linter
lint:
	@golangci-lint run || echo "golangci-lint not installed, skipping"

## test: Run tests
test:
	$(GO) test -v ./...

## test-cover: Run tests with coverage
test-cover:
	$(GO) test -coverprofile=coverage.out ./...
	$(GO) tool cover -html=coverage.out -o coverage.html

## tidy: Tidy go modules
tidy:
	$(GO) mod tidy

## check: Run fmt, lint, and test
check: fmt lint test

## bump: Tag and push next semantic version (requires clean tree + svu)
bump:
	@$(MAKE) build
	@$(MAKE) test
	@$(MAKE) fmt
	@$(MAKE) lint
	@if [ -n "$$(git status --porcelain)" ]; then \
		echo "Working directory not clean. Commit or stash first."; \
		exit 1; \
	fi
	@version=$$(svu next); \
		git tag -a $$version -m "Version $$version"; \
		echo "Tagged $$version"; \
		git push origin $$version

## help: Show this help message
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@sed -n 's/^## //p' $(MAKEFILE_LIST) | column -t -s ':'
```

## Quick Reference

| Target | Purpose | When to run |
|--------|---------|-------------|
| `make build` | Build binary to `build/` | After changes |
| `make fmt` | Format all `.go` files | After every change |
| `make lint` | Run golangci-lint | Before commit |
| `make test` | Run all tests | After changes |
| `make check` | fmt + lint + test | Before commit/PR |
| `make test-cover` | Tests with HTML coverage | Review coverage |
| `make tidy` | `go mod tidy` | After dep changes |
| `make clean` | Remove build artifacts | Fresh rebuild |
| `make bump` | Tag next version with svu | Release time |
| `make help` | Show available targets | Discovery |

## Common Mistakes

- Using `go fmt` instead of `gofmt -w` — `gofmt -w` writes changes in-place to specific files; `go fmt` is a wrapper that reformats whole packages
- Hardcoding help text instead of parsing `##` comments — hardcoded help drifts out of sync with actual targets
- Missing graceful lint fallback — `golangci-lint run` without `|| echo "not installed"` breaks builds on machines without the linter

## Adaptation Notes

- Replace `<app-name>` with actual binary/module name
- Adjust `./cmd/<app-name>` to match entry point location
- Add `-X` flags to LDFLAGS for additional build-time variables
- For multi-binary projects, add per-binary targets: `build-server`, `build-client`, then `build: build-server build-client`
- For code generation (protobuf, mockgen), add a `generate` target:
  ```makefile
  .PHONY: generate
  ## generate: Run code generation
  generate:
  	$(GO) generate ./...
  ```
- For cross-compilation, add per-platform targets:
  ```makefile
  ## build-linux: Cross-compile for Linux amd64
  build-linux:
  	GOOS=linux GOARCH=amd64 $(GO) build $(LDFLAGS) -o build/<app>-linux-amd64 ./cmd/<app>
  ```
- `svu` is required for `make bump` — install from https://github.com/caarlos0/svu or replace with manual `git tag -a vX.Y.Z -m "vX.Y.Z"`
- The `help` target parses `## target: description` comments from the Makefile itself

## Go-Side Version Variables

Declare these in your `main` package to receive values from ldflags:

```go
var (
    version   = "dev"
    buildTime = "unknown"
)

func main() {
    fmt.Printf("%s (built %s)\n", version, buildTime)
}
```

The Makefile's `-X main.version=$(VERSION)` sets these at link time.
