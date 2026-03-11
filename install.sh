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
if [ "$(realpath "$repo_root")" != "$(realpath "$(pwd)")" ]; then
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
    if ! jq empty "$SETTINGS_FILE" 2>/dev/null; then
      echo "Error: $SETTINGS_FILE exists but is not valid JSON. Fix it and re-run." >&2
      exit 1
    fi
    # Merge: recursive object merge; frostyard keys overwrite conflicts, other keys preserved
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
