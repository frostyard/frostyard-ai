# Project-Level Installation Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an install script and README docs so teams can adopt frostyard plugins at the project level via Claude Code's team marketplaces feature.

**Architecture:** A single shell script (`install.sh`) writes or merges `extraKnownMarketplaces` and `enabledPlugins` into a target project's `.claude/settings.json`. The README gains a new section documenting both the script and manual setup.

**Tech Stack:** POSIX shell, jq (optional)

---

## Chunk 1: install.sh and README update

### Task 1: Create install.sh

**Files:**
- Create: `install.sh`

- [ ] **Step 1: Write the install script**

Create `install.sh` at the repo root with the following content:

```bash
#!/usr/bin/env bash
set -euo pipefail

# frostyard-ai project-level installer
# Run this from your target project's root directory.
# It adds frostyard-ai as a Claude Code team marketplace
# to .claude/settings.json in the current project.

SETTINGS_DIR=".claude"
SETTINGS_FILE="$SETTINGS_DIR/settings.json"

FROSTYARD_CONFIG='{
  "extraKnownMarketplaces": {
    "frostyard-ai": {
      "source": "github",
      "repo": "frostyard/frostyard-ai"
    }
  },
  "enabledPlugins": {
    "frostyard-dev@frostyard-ai": true,
    "frostyard-os@frostyard-ai": true
  }
}'

# 1. Verify we're at a git repo root
repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Error: not inside a git repository." >&2
  exit 1
}
if [ "$repo_root" != "$(pwd)" ]; then
  echo "Error: run this from the repository root ($repo_root)." >&2
  exit 1
fi

# 2. Create .claude/ if needed
mkdir -p "$SETTINGS_DIR"

# 3. Check for jq and existing settings
has_jq=false
if command -v jq >/dev/null 2>&1; then
  has_jq=true
fi

if [ -f "$SETTINGS_FILE" ]; then
  # Settings file exists
  if [ "$has_jq" = true ]; then
    # Merge: additive deep merge, preserving existing keys
    merged=$(jq -s '.[0] * .[1]' "$SETTINGS_FILE" - <<< "$FROSTYARD_CONFIG")
    printf '%s\n' "$merged" > "$SETTINGS_FILE"
  else
    echo "Error: $SETTINGS_FILE already exists and jq is not installed." >&2
    echo "" >&2
    echo "Install jq and re-run, or manually merge this into $SETTINGS_FILE:" >&2
    echo "" >&2
    echo "$FROSTYARD_CONFIG" >&2
    exit 1
  fi
else
  # No existing settings — write fresh
  if [ "$has_jq" = true ]; then
    printf '%s\n' "$FROSTYARD_CONFIG" | jq . > "$SETTINGS_FILE"
  else
    printf '%s\n' "$FROSTYARD_CONFIG" > "$SETTINGS_FILE"
  fi
fi

echo "frostyard-ai marketplace added to $SETTINGS_FILE"
echo ""
echo "Next steps:"
echo "  1. Commit $SETTINGS_FILE to your repo"
echo "  2. When teammates open this project in Claude Code and trust the folder,"
echo "     they'll be prompted to install the frostyard plugins."
```

- [ ] **Step 2: Make install.sh executable**

Run: `chmod +x install.sh`

- [ ] **Step 3: Test — fresh repo, jq available, no existing settings**

```bash
tmpdir=$(mktemp -d)
git init "$tmpdir"
cd "$tmpdir"
bash /home/bjk/projects/frostyard/frostyard-ai/install.sh
cat .claude/settings.json
cd -
rm -rf "$tmpdir"
```

Expected: `.claude/settings.json` written with pretty-printed frostyard config. Exit 0.

- [ ] **Step 4: Test — jq available, existing settings (merge + idempotency)**

```bash
tmpdir=$(mktemp -d)
git init "$tmpdir"
cd "$tmpdir"
mkdir -p .claude
echo '{"permissions":{"allow":["Read"]}}' > .claude/settings.json
bash /home/bjk/projects/frostyard/frostyard-ai/install.sh
bash /home/bjk/projects/frostyard/frostyard-ai/install.sh
cat .claude/settings.json
cd -
rm -rf "$tmpdir"
```

Expected: `permissions.allow` preserved, frostyard config present, second run produces identical output. Exit 0.

- [ ] **Step 5: Test — no jq, no existing settings**

```bash
tmpdir=$(mktemp -d)
git init "$tmpdir"
cd "$tmpdir"
PATH=$(printf '%s' "$PATH" | tr ':' '\n' | grep -v "$(dirname "$(which jq)")" | tr '\n' ':') \
  bash /home/bjk/projects/frostyard/frostyard-ai/install.sh
cat .claude/settings.json
cd -
rm -rf "$tmpdir"
```

Expected: `.claude/settings.json` written with frostyard config (not pretty-printed). Exit 0.

- [ ] **Step 6: Test — no jq, existing settings (should fail with snippet)**

```bash
tmpdir=$(mktemp -d)
git init "$tmpdir"
cd "$tmpdir"
mkdir -p .claude
echo '{"permissions":{}}' > .claude/settings.json
PATH=$(printf '%s' "$PATH" | tr ':' '\n' | grep -v "$(dirname "$(which jq)")" | tr '\n' ':') \
  bash /home/bjk/projects/frostyard/frostyard-ai/install.sh 2>&1; echo "exit: $?"
cd -
rm -rf "$tmpdir"
```

Expected: Error message with the exact JSON snippet to merge manually. Exit 1.

- [ ] **Step 7: Test — not a git repo (should fail)**

```bash
tmpdir=$(mktemp -d)
cd "$tmpdir"
bash /home/bjk/projects/frostyard/frostyard-ai/install.sh 2>&1; echo "exit: $?"
cd -
rm -rf "$tmpdir"
```

Expected: Error message about not being inside a git repository. Exit 1.

- [ ] **Step 8: Test — repo subdirectory (should fail)**

```bash
tmpdir=$(mktemp -d)
git init "$tmpdir"
mkdir -p "$tmpdir/subdir"
cd "$tmpdir/subdir"
bash /home/bjk/projects/frostyard/frostyard-ai/install.sh 2>&1; echo "exit: $?"
cd -
rm -rf "$tmpdir"
```

Expected: Error message telling user to run from the repository root. Exit 1.

- [ ] **Step 9: Commit install.sh**

```bash
git add install.sh
git commit -m "feat: add project-level install script"
```

### Task 2: Update README.md

**Files:**
- Modify: `README.md` (replace "## Install from local checkout" section heading and add new section before it)

- [ ] **Step 1: Add "Project installation" section and rename existing section**

Insert a new "Project installation (recommended)" section before the existing install section. Rename "Install from local checkout" to "User-wide installation". The new section content:

```markdown
## Project installation (recommended)

Add frostyard plugins to your project so all team members get them automatically. Run this from your project's root directory:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/frostyard/frostyard-ai/main/install.sh)
```

This adds frostyard-ai as a [team marketplace](https://code.claude.com/docs/en/discover-plugins#configure-team-marketplaces) in your project's `.claude/settings.json`. When teammates open the project in Claude Code and trust the folder, they'll be prompted to install the plugins.

Commit `.claude/settings.json` to share it with your team.

### Manual setup

If you prefer to configure it by hand, add this to your project's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "frostyard-ai": {
      "source": "github",
      "repo": "frostyard/frostyard-ai"
    }
  },
  "enabledPlugins": {
    "frostyard-dev@frostyard-ai": true,
    "frostyard-os@frostyard-ai": true
  }
}
```

## User-wide installation
```

- [ ] **Step 2: Verify README renders correctly**

Read the full README to verify section ordering and formatting.

- [ ] **Step 3: Commit README update**

```bash
git add README.md
git commit -m "docs: add project-level installation instructions to README"
```
