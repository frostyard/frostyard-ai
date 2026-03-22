---
name: mkdocs
description: >
  WHEN: Creating, configuring, or deploying MkDocs documentation sites. Working with mkdocs.yml,
  Material theme, plugins (mkdocstrings, gen-files, literate-nav, mermaid2), or CI/CD for docs.
  WHEN NOT: Non-MkDocs static site generators (Sphinx, Docusaurus, Hugo).
---

# MkDocs

Comprehensive guide for building documentation sites with MkDocs and Material for MkDocs theme. Covers CLI usage, configuration, theming, plugins, and deployment.

## Quick Start

```bash
# Create and serve a new project
pip install mkdocs-material
mkdocs new my-docs && cd my-docs
mkdocs serve  # http://127.0.0.1:8000
```

Minimal `mkdocs.yml`:

```yaml
site_name: My Documentation
theme:
  name: material
  palette:
    - scheme: default
      toggle:
        icon: material/brightness-7
        name: Switch to dark mode
    - scheme: slate
      toggle:
        icon: material/brightness-4
        name: Switch to light mode
  features:
    - navigation.instant
    - navigation.tabs
    - search.suggest
    - search.highlight
    - content.code.copy
nav:
  - Home: index.md
```

## Source Directory

The standard source directory for documentation content is `site/` (not MkDocs' default `docs/`). Before creating or configuring a project, ask the user whether `site/` is acceptable or if they prefer an alternate. Set it in `mkdocs.yml`:

```yaml
docs_dir: site  # standard — ask the user before using a different directory
```

## Key Configuration Patterns

### Navigation

```yaml
nav:
  - Home: index.md
  - Guide:
      - guide/index.md        # Section index (with navigation.indexes)
      - Installation: guide/install.md
      - Configuration: guide/config.md
  - API Reference: api/
```

### Markdown Extensions (Recommended Set)

```yaml
markdown_extensions:
  - admonition
  - pymdownx.details
  - pymdownx.superfences:
      custom_fences:
        - name: mermaid
          class: mermaid
          format: !!python/name:pymdownx.superfences.fence_code_format
  - pymdownx.highlight:
      anchor_linenums: true
  - pymdownx.tabbed:
      alternate_style: true
  - pymdownx.tasklist:
      custom_checkbox: true
  - attr_list
  - toc:
      permalink: true
```

### Environment Variables

```yaml
site_url: !ENV SITE_URL
site_name: !ENV [SITE_NAME, "Default Name"]
strict: !ENV [STRICT, false]
```

### Configuration Inheritance

```yaml
# mkdocs.yml
INHERIT: base.yml
site_name: My Docs - Development
```

> **Full reference:** See `configuration_reference.md` for all settings and valid values.

## Material Theme

Key features to enable:

```yaml
theme:
  features:
    - navigation.instant       # SPA-like loading
    - navigation.tabs          # Top-level tabs
    - navigation.tabs.sticky   # Sticky tabs
    - navigation.sections      # Grouped sidebar sections
    - navigation.indexes       # Section index pages
    - navigation.top           # Back-to-top button
    - navigation.footer        # Previous/next links
    - content.code.copy        # Code copy button
    - content.code.annotate    # Code annotations
    - search.suggest           # Search suggestions
    - search.highlight         # Highlight results
    - toc.follow               # Auto-scroll TOC
```

> **Full reference:** See `material_theme_reference.md` for colors, fonts, social cards, analytics, versioning, and all theme options.

## Common Plugin Configurations

### API Documentation (Python)

```yaml
plugins:
  - search
  - gen-files:
      scripts:
        - scripts/gen_ref_pages.py
  - literate-nav:
      nav_file: SUMMARY.md
  - mkdocstrings:
      handlers:
        python:
          options:
            docstring_style: google
            show_source: true
            show_root_heading: true
```

### CLI Documentation (Typer)

```yaml
plugins:
  - search
  - mkdocs-typer2:
      pretty: true
  - termynal
```

> **Full reference:** See `plugins_reference.md` for mkdocstrings, gen-files, literate-nav, mkdoxy, mermaid2, termynal, and more.

## Deployment

### GitHub Pages (GitHub Actions)

```yaml
# .github/workflows/docs.yml
name: Deploy Docs
on:
  push:
    branches: [main]
    paths: ["docs/**", "mkdocs.yml"]

permissions:
  contents: read
  pages: write
  id-token: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.x"
      - run: pip install -r requirements-docs.txt
      - run: mkdocs build --strict
      - uses: actions/upload-pages-artifact@v3
        with:
          path: ./site
  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
    steps:
      - uses: actions/deploy-pages@v4
```

### GitLab Pages

```yaml
# .gitlab-ci.yml
pages:
  image: python:3.11-alpine
  script:
    - pip install -r requirements-docs.txt
    - mkdocs build --strict --site-dir public
  artifacts:
    paths: [public]
  only: [main]
```

### Quick Deploy (gh-deploy)

```bash
mkdocs gh-deploy              # Deploy to gh-pages branch
mkdocs gh-deploy --strict     # With strict mode
```

> **Full reference:** See `real_world_examples.md` for versioned deployments with mike, multi-environment configs, and production examples.

## CLI Quick Reference

| Command | Purpose |
|---------|---------|
| `mkdocs new <dir>` | Create new project |
| `mkdocs serve` | Dev server with live reload |
| `mkdocs serve -a 0.0.0.0:8080` | Serve on custom address |
| `mkdocs serve --dirtyreload` | Fast rebuild (large sites) |
| `mkdocs build` | Build static site |
| `mkdocs build --strict` | Build with warnings as errors |
| `mkdocs build -d public` | Build to custom directory |
| `mkdocs gh-deploy` | Deploy to GitHub Pages |
| `mkdocs get-deps` | Show required Python packages |

> **Full reference:** See `cli_reference.md` for all commands, options, and environment variables.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Missing `site_url` | Set it — required for sitemaps, social cards, and canonical links |
| Not using `--strict` in CI | Always build with `--strict` to catch broken links and warnings early |
| Forgetting `fetch-depth: 0` in CI | Required for git-revision-date and git-committers plugins |
| Plugin order wrong | Use: gen-files → literate-nav → mkdocstrings → other plugins |
| Large site slow rebuilds | Use `mkdocs serve --dirtyreload` during development |

## References

This skill includes detailed reference documentation:

- **`cli_reference.md`** — All CLI commands, options, and workflows
- **`configuration_reference.md`** — Complete mkdocs.yml settings and valid values
- **`material_theme_reference.md`** — Material theme colors, fonts, navigation, plugins, and advanced features
- **`plugins_reference.md`** — mkdocstrings, gen-files, literate-nav, mkdoxy, typer2, mermaid2, termynal
- **`real_world_examples.md`** — Production examples, GitHub/GitLab CI/CD workflows, deployment patterns
