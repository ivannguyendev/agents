# Agent Instructions

Instructions for AI agents working on this project. Read this file before making any changes.

## Project Overview

AI Agents Builder — toolkit for finding, creating, and validating AI agent skills/workflows across 10 AI coding tools. Built on the `ivannguyendev/agent-templates` community catalog.

## Key Files

| File | Purpose |
|------|---------|
| `agent-builder/SKILL.md` | skill-matcher — main skill (6-step workflow) |
| `agent-builder/scripts/detect-tools.sh` | Detect active AI tools and resolve install paths |
| `agent-builder/scripts/validate-skill.sh` | Validate SKILL.md format (zero deps, bash only) |
| `scripts/generate-changelog.sh` | Auto-generate changelog from conventional commits |
| `.github/workflows/deploy-pages.yml` | GitHub Pages auto-deploy (generates changelog + Astro build) |
| `docs/` | Astro + Starlight documentation site |
| `CONVENTION.md` | Rules and style guide |
| `README.md` | Project documentation |

## Workflow: skill-matcher

The main skill follows a 6-step flow. When working on or extending it, preserve this order:

1. **Detect Environment** — Run `detect-tools.sh` to identify active AI tools
2. **Gather Requirement** — Collect user's task/goal in natural language
3. **Fetch Catalog** — Retrieve CSV indexes from GitHub (`skills/INDEXES.csv`, `workflows/INDEXES.csv`)
4. **Score Items** — Weighted keyword matching (name +3, tags +2, description +1)
5. **Present Results** — Top 3 matches or gap analysis with adaptation suggestions
6. **Create/Adapt Skill** — Interview (2-3 questions), write SKILL.md, validate, install

Step 6 triggers from: gap analysis acceptance, direct create request, edit request, or catalog fetch failure.

## Workflow: Skill Creation (Step 6)

When creating or adapting a skill:

1. **Interview** — Ask only what's missing from prior context:
   - Purpose: "What should this skill enable the AI to do?"
   - Trigger: "When should this skill activate?"
   - Output: "What's the expected output format?"

2. **Write SKILL.md** following these rules:
   - Frontmatter: `name` (kebab-case, max 64), `description` (max 1024, no angle brackets)
   - Description should be "pushy" — include keyword variations for trigger accuracy
   - Body: imperative form, explain the why, include examples, under 500 lines
   - Progressive disclosure: metadata always loaded, body on trigger, resources on demand

3. **Validate** — Always run after creation/modification:
   ```bash
   bash agent-builder/scripts/validate-skill.sh <skill-directory>
   ```

4. **Install** — Copy to the correct tool-specific path from Step 1

## Workflow: Validation

The `validate-skill.sh` script checks:
- SKILL.md exists with valid frontmatter (`---` delimiters)
- Required: `name`, `description`
- `name`: kebab-case (`[a-z0-9-]+`), no leading/trailing/double hyphens, max 64 chars
- `description`: no `<` or `>`, max 1024 chars
- Allowed keys only: name, description, license, allowed-tools, metadata, compatibility

Exit 0 = pass, exit 1 = fail. Never skip validation.

## Workflow: Tool Detection

`detect-tools.sh` supports 4 output modes:
```bash
bash agent-builder/scripts/detect-tools.sh              # Human-readable
bash agent-builder/scripts/detect-tools.sh --json       # JSON format
bash agent-builder/scripts/detect-tools.sh --first      # First detected tool name
bash agent-builder/scripts/detect-tools.sh --path <tool> # Install path for specific tool
```

10 tools supported: claude-code, copilot, antigravity, gemini-cli, opencode, cursor, aider, windsurf, openclaw, qwen.

## Rules When Making Changes

1. **Read `CONVENTION.md`** before writing any code
2. **Bash scripts only** in `agent-builder/scripts/` — zero external dependencies
3. **Validate after every skill change** — run `validate-skill.sh`
4. **Never hardcode install paths** — always resolve from `detect-tools.sh`
5. **Fetch catalog fresh** — never cache or assume what skills exist
6. **Preserve the 6-step flow** in skill-matcher — extend, don't restructure
7. **Error handling for CSV fetch** — 1 fail: continue with other, both fail: offer Step 6
8. **Follow conventional commits** — see `CONVENTION.md > Git` for format, types, scopes, and examples

## Design Decisions

These decisions were made deliberately — do not reverse without discussion:

- **Bash over Python for scripts** — zero dependencies, consistent tooling, portable across all environments
- **Interview before creating** — 2-3 short questions improve skill quality vs. generating directly from gap analysis alone
- **Validation is mandatory** — always run after create/edit, never skip
- **Workflows use sparse checkout** — they may contain multiple files (scripts, references, assets), unlike single-file skills
- **Scoring is keyword-based** — simple, transparent, no LLM dependency in the matching step
