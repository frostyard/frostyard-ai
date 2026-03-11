# CLAUDE.md

This file provides guidance for developing the frostyard-ai plugin repository itself.

## Project Structure

This is a Claude Code plugin marketplace containing two plugins:

- `frostyard-dev` — Go development skills (Uber style, best practices, modern Go, Makefile, org conventions)
- `frostyard-os` — mkosi/bootc image building skills

## Adding a New Skill

1. Create a directory under the appropriate plugin: `plugins/<plugin>/skills/<skill-name>/`
2. Create `SKILL.md` with YAML frontmatter:
   ```yaml
   ---
   name: skill-name
   description: >
     WHEN: Conditions that trigger this skill.
     WHEN NOT: Conditions where this skill should not activate.
   ---
   ```
3. Write skill content with actionable rules and code examples
4. Target ~100-200 lines per skill
5. Test locally: `claude plugin install --local ./plugins/<plugin>`

## Adding a New Plugin

1. Create `plugins/<plugin-name>/.claude-plugin/plugin.json`
2. Create `plugins/<plugin-name>/skills/` directory
3. Add the plugin entry to `.claude-plugin/marketplace.json`
4. Keep all plugin versions in sync

## Conventions

- All plugins share the same version number
- Skills use `WHEN:` / `WHEN NOT:` trigger syntax in descriptions
- Skills are auto-invoked, not slash commands
- frostyard-dev priority order: Modern Go > Uber Guide > Go best practices > Frostyard conventions
