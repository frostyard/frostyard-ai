# Project-Level Installation for frostyard-ai

## Problem

Currently frostyard-ai only supports local (user-scoped) installation via `claude plugin install --local`. There's no way to add frostyard plugins at the project level so that all team members on a repo get prompted to install them.

## Solution

Use Claude Code's [team marketplaces](https://code.claude.com/docs/en/discover-plugins#configure-team-marketplaces) feature. This works by adding `extraKnownMarketplaces` and `enabledPlugins` to a target project's `.claude/settings.json`. When team members trust the folder, Claude Code prompts them to install the marketplace and plugins.

## Deliverables

### 1. install.sh

A shell script at the repo root that users run from their target project's root directory. It adds frostyard-ai as a team marketplace to that project's `.claude/settings.json`.

**Behavior:**

1. Verify the current directory is a git repository root using `git rev-parse --show-toplevel` (handles worktrees and submodules correctly; exit 1 if not a repo root).
2. Create `.claude/` directory if it doesn't exist.
3. Check for `jq` availability and whether `.claude/settings.json` already exists.
4. Write or merge the following config:

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

**Four cases:**

| `jq` available | settings.json exists | Action |
|---|---|---|
| yes | no | Write fresh config |
| yes | yes | Merge into existing config using `jq` (additive deep merge) |
| no | no | Write fresh config directly |
| no | yes | Print the exact JSON snippet to merge manually, then exit 1 |

**The script is idempotent.** Running it multiple times produces the same result. When merging with `jq`, existing keys in `extraKnownMarketplaces` and `enabledPlugins` are preserved; frostyard-ai entries are overwritten if already present.

**Exit codes:** 0 on success, 1 on failure.

**On success:** Print confirmation and remind the user to commit `.claude/settings.json` to their repo (this is project-scoped config intended to be shared with teammates).

**On failure:** Print actionable error message.

### 2. README update

Add a "Project installation (recommended)" section before the existing "Install from local checkout" section. Contents:

- **One-liner**: `curl` the install script from GitHub raw, pipe to `bash`, run from target project root.
- **What it does**: Brief explanation of the team marketplace mechanism.
- **Manual alternative**: Raw JSON snippet for hand-editing `.claude/settings.json`.
- **What happens next**: Teammates get prompted on folder trust.

Rename existing section from "Install from local checkout" to "User-wide installation" for clarity.

## Out of scope

- agentskills.io integration
- Plugin selection (both plugins enabled by default; users disable via `/plugin` UI)
- CI/CD or automation around plugin updates
