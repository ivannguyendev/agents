# Convention

Rules and style guide for the AI Agents Builder project.

## File Naming

- **kebab-case** for all files and directories: `my-skill-name`, `detect-tools.sh`
- Skill definition files are always named `SKILL.md` (uppercase)
- Scripts use their language extension: `.sh` for bash, `.py` for Python

## Skill Format

### Frontmatter (YAML)

Required fields:
- `name` — kebab-case, max 64 characters, no leading/trailing/consecutive hyphens
- `description` — max 1024 characters, no angle brackets (`<` or `>`)

Optional fields:
- `license` — e.g., `MIT`, `Apache-2.0`
- `allowed-tools` — tools the skill is compatible with
- `metadata` — additional structured data
- `compatibility` — dependency requirements, max 500 characters

No other frontmatter keys are allowed. Run `validate-skill.sh` to verify.

### Body

- Keep under 500 lines; extract long content into `references/` subdirectory
- Use imperative form: "Run the script", not "You should run the script"
- Explain **why** behind instructions rather than rigid MUST/NEVER rules
- Include concrete Input/Output examples where applicable

### Directory Structure

```
skill-name/
├── SKILL.md          (required)
├── scripts/          (optional — deterministic tasks)
├── references/       (optional — domain docs)
└── assets/           (optional — templates, icons)
```

## Scripts

### Bash Scripts

- Shebang: `#!/usr/bin/env bash`
- Always `set -eo pipefail`
- Zero external dependencies — use only standard Unix tools
- Include usage comment header with: purpose, usage examples, exit codes
- Use section dividers for readability:
  ```bash
  # ─── Section Name ──────────────────────────────────────────────────────
  ```

## Catalog

- Skills and workflows are indexed via CSV files in the `agent-templates` repo
- Skills CSV columns: `name, description, license, compatibility, metadata, allowed-tools, path`
- Workflows CSV columns: `name, description, license, skills, tags, scope, path`
- Always fetch fresh from GitHub — never cache catalog data

## Scoring

Keyword matching with weighted points:
- `name` match: +3
- `tags` match: +2
- `description` match: +1
- Stopwords ignored: a, the, to, for, with, and, or, in
- Scores normalized to 0-10 range

## Install Paths

Skills install into tool-specific directories. Never hardcode paths — always resolve from `detect-tools.sh`:

| Tool | Path |
|------|------|
| claude-code | `.claude/` |
| copilot | `.github/` |
| antigravity | `.agents/` |
| gemini-cli | `.gemini/` |
| opencode | `.opencode/` |
| cursor | `.cursor/` |
| aider | `./` (CONVENTIONS.md) |
| windsurf | `.windsurf/` |
| openclaw | `.openclaw/` |
| qwen | `.qwen/` |

## Validation

Run validation after every skill creation or modification:

```bash
bash agent-builder/scripts/validate-skill.sh <skill-directory>
```

Exit code 0 = pass, 1 = fail. Do not skip validation.

## Git

### Conventional Commits

Format: `<type>(<scope>): <subject>`

**Types:**

| Type | When to use |
|------|-------------|
| `feat` | New feature or skill |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `style` | Formatting, whitespace (no logic change) |
| `refactor` | Code restructure (no feature/fix) |
| `test` | Add or update tests |
| `chore` | Build, CI, tooling, dependencies |
| `perf` | Performance improvement |

**Scopes:** `skill-matcher`, `detect-tools`, `validate-skill`, `ci`, `docs`

**Rules:**
- Subject: imperative mood, lowercase, no period, max 72 chars
- Body (optional): explain **why**, not what — wrap at 80 chars
- Footer (optional): `BREAKING CHANGE:` for incompatible changes
- One logical change per commit

**Examples:**

```
feat(skill-matcher): add workflow sparse checkout support
fix(detect-tools): handle missing CLI path on macOS
docs: update quick start with auto-detect usage
chore(ci): add GitHub Pages deployment workflow
refactor(validate-skill): extract frontmatter parser into function
```

### General

- Do not commit secrets, API keys, or `.env` files
- Run linting and validation before commit
