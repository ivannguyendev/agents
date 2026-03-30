---
name: skill-matcher
description: Finds the most relevant skill or workflow from the agent-templates catalog based on a natural language requirement. Auto-detects the running AI tool to install files in the correct directory. When no exact match exists, identifies the closest skill and suggests specific modifications to adapt it.
license: MIT
---

# Skill Matcher

## Overview

Match any natural language requirement to existing skills or workflows in the `ivannguyendev/agent-templates` community catalog. Reduces duplication by surfacing reusable community assets before creating new ones from scratch. Installs files into the correct directory for the active AI tool automatically.

**Keywords**: skill finder, workflow finder, agent selector, catalog search, skill recommendation, workflow recommendation, skill builder, agent templates, match skill, find workflow

## When to Use

Invoke this skill when you need to:
- Find an existing skill that covers a task
- Find a workflow that orchestrates multiple agents
- Understand which catalog items need modification to fit a custom requirement
- Avoid duplicating a skill that already exists in the community
- Create a new skill or adapt an existing one to fit a specific requirement
- Validate a skill's SKILL.md format after creation or modification

## Steps

### 1. Detect Running Environment

Before doing anything else, resolve which AI tools are active by running the detection script:

```bash
bash scripts/detect-tools.sh
```

The script checks for installed CLI commands and tool-specific directories, then prints the detected tools and their install paths. If the `scripts/` directory is not available in the current project, run the detection logic inline:

```bash
# Inline detection (no script required)
H="$(eval echo ~)"; CWD="$(pwd)"
[[ -d "$H/.claude" ]]              && echo "claude-code  $CWD/.claude"
[[ -d "$H/.github/copilot" ]]      && echo "copilot      $CWD/.github"
[[ -d "$H/.gemini/antigravity" ]]   && echo "antigravity  $CWD/.agents"
[[ -d "$H/.gemini/extensions" ]]    && echo "gemini-cli   $CWD/.gemini"
[[ -d "$CWD/.opencode" ]]          && echo "opencode     $CWD/.opencode"
[[ -d "$CWD/.cursor" ]]            && echo "cursor       $CWD/.cursor"
command -v aider &>/dev/null        && echo "aider        $CWD"
[[ -d "$CWD/.windsurf" ]]          && echo "windsurf     $CWD/.windsurf"
[[ -d "$H/.openclaw" ]]            && echo "openclaw     $CWD/.openclaw"
[[ -d "$H/.qwen" ]]                && echo "qwen         $CWD/.qwen"
```

**Install paths reference (all relative to current project directory):**
| Tool | Install path |
|---|---|
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

If no tools are detected, ask:
> "Which AI tool are you using?"

Store the detected tool name(s) as `ACTIVE_TOOLS` and use the corresponding paths in all install commands generated later.

---

### 2. Gather Requirement

If no requirement has been provided in the user's message, ask:

> "What task or goal do you need a skill or workflow for? (Describe in plain language)"

Identify the search scope from context:
- `skill` — single-agent capability
- `workflow` — multi-agent orchestration
- `both` — (default) search across both catalogs

---

### 3. Fetch Catalog

Use WebFetch to retrieve both index files simultaneously:

**Skills index:**
```
https://raw.githubusercontent.com/ivannguyendev/agent-templates/main/skills/INDEXES.csv
```

**Workflows index:**
```
https://raw.githubusercontent.com/ivannguyendev/agent-templates/main/workflows/INDEXES.csv
```

Parse each CSV file. Column headers:
- **Skills**: `name, description, license, compatibility, metadata, allowed-tools, path`
- **Workflows**: `name, description, license, skills, tags, scope, path`

**Error handling:**
- If one CSV fetch fails → continue with the other, note which catalog is unavailable:
  > "⚠️ Could not fetch the [skills/workflows] catalog. Showing results from [workflows/skills] only."
- If both fail → inform the user and offer alternatives:
  > "Could not reach the catalog. Please check your network connection. Would you like me to create a skill from scratch instead?"
  If the user agrees → proceed to Step 6 (Create or Adapt Skill).

---

### 4. Score Each Item

For every catalog item, compute a relevance score against the user's requirement:

| Match location | Points |
|---|---|
| Keyword found in `name` | +3 |
| Keyword found in `tags` (workflows) | +2 |
| Keyword found in `description` | +1 |

- Tokenize the requirement into individual keywords (ignore stopwords: a, the, to, for, with, and, or, in)
- Sum points across all matching keywords
- Normalize the final score to a 0–10 range based on the highest scorer
- Exclude items with score 0

---

### 5. Present Results

#### When matches are found (at least one item scored > 0):

List the top 3 results sorted by score descending.

```
## Skill Matcher Results

**Requirement:** <user's input>

### ✅ Top Matches

| Rank | Name | Type | Score | Description |
|------|------|------|-------|-------------|
| 1    | ...  | Skill / Workflow | X/10 | ... |
| 2    | ...  | Skill / Workflow | X/10 | ... |
| 3    | ...  | Skill / Workflow | X/10 | ... |

**To install a skill** (single file):
mkdir -p <install-path>
curl -o <install-path>/<name>.md \
  https://raw.githubusercontent.com/ivannguyendev/agent-templates/main/<path>

**To install a workflow** (may contain multiple files — scripts, references, assets):
git clone --depth 1 --filter=blob:none --sparse \
  https://github.com/ivannguyendev/agent-templates.git /tmp/agent-templates
git -C /tmp/agent-templates sparse-checkout set workflows/<name>
cp -r workflows/<name>/* <install-path>/
rm -rf /tmp/agent-templates
```

For each result, offer to fetch and display the full file content so the user can inspect it before installing.

---

#### When no exact match exists (all scores = 0, or best score < 2):

Show the single closest item (highest raw score or highest substring overlap) and perform a gap analysis:

```
## Skill Matcher Results

**Requirement:** <user's input>

### ⚠️ No Exact Match Found

The closest item in the catalog is:

**[name]** (`[type]`) — [description]

**Gap analysis:**
- ✅ Covers: [what the existing skill already handles]
- ❌ Missing: [specific capability the user needs that isn't covered]
- 🔧 Needs adjustment: [specific sections/fields to modify]

To adapt this skill, the following changes are recommended:
1. [Concrete change #1]
2. [Concrete change #2]

Do you want me to generate a modified version of this skill tailored to your requirement?
```

If the user answers yes → proceed to Step 6.

---

### 6. Create or Adapt Skill

This step activates when:
- The user agrees to generate a modified version from gap analysis (Step 5)
- The user directly requests creating a new skill (bypassing catalog search)
- The user wants to edit an already-installed skill
- Both catalog fetches failed and user opts to create from scratch

#### 6.1 Quick Interview

Before writing, clarify the skill's purpose with 2-3 short questions. Skip any question already answered from prior context (requirement, gap analysis, etc.):

1. **Purpose** — "What should this skill enable the AI to do?"
2. **Trigger context** — "When should this skill activate? What would a user typically say?"
3. **Expected output** — "What's the expected output? (files, text, format)"

#### 6.2 Write the SKILL.md

Create the skill following this structure:

**Frontmatter (required):**
```yaml
---
name: kebab-case-name
description: >
  Clear description of what the skill does AND when to trigger it.
  Include keyword variations to improve trigger accuracy.
  Be slightly "pushy" — list contexts where the skill should activate,
  even if the user doesn't explicitly name it.
license: MIT
---
```

**Body guidelines:**
- Use imperative form for instructions ("Run the script", not "You should run the script")
- Explain the **why** behind each instruction — models respond better to reasoning than rigid rules
- Include concrete examples with Input/Output pairs where applicable
- Keep the body under 500 lines; extract long references into `references/` subdirectory

**Skill anatomy (progressive disclosure):**
```
skill-name/
├── SKILL.md          (required — under 500 lines)
├── scripts/          (optional — deterministic/repetitive tasks)
├── references/       (optional — domain docs, loaded as needed)
└── assets/           (optional — templates, icons, fonts)
```

Three loading levels:
1. **Metadata** (name + description) — always in context (~100 words)
2. **SKILL.md body** — loaded when skill triggers
3. **Bundled resources** — loaded on demand (scripts can execute without loading into context)

For multi-domain skills, organize references by variant:
```
cloud-deploy/
├── SKILL.md
└── references/
    ├── aws.md
    ├── gcp.md
    └── azure.md
```

#### 6.3 Validate

After creating or modifying the skill, run the validation script:

```bash
bash scripts/validate-skill.sh <skill-directory>
```

The script checks: frontmatter format, required fields (name, description), kebab-case naming (max 64 chars), description length (max 1024 chars), and allowed frontmatter keys.

If validation fails → fix the reported errors → re-validate until it passes.

#### 6.4 Install

Copy the created/modified files into the correct install path resolved from Step 1:

```bash
mkdir -p <install-path>
cp <skill-name>/SKILL.md <install-path>/<skill-name>.md
# If the skill has bundled resources:
cp -r <skill-name>/scripts/ <install-path>/scripts/
cp -r <skill-name>/references/ <install-path>/references/
```

Ensure the local directory name matches the skill's `name` field before copying. Confirm to the user what was installed and where.

---

## Output Format Reference

### Full Match Output

```
## Skill Matcher Results

**Requirement:** I need help building a REST API with authentication

### ✅ Top Matches

| Rank | Name | Type | Score | Description |
|------|------|------|-------|-------------|
| 1 | backend-architect | Skill | 9/10 | API design, database architecture, scalability |
| 2 | security-engineer | Skill | 6/10 | Threat modeling, secure code review |
| 3 | development-landing-page | Workflow | 2/10 | Full landing page sprint |

**To install backend-architect (Skill):**
# claude-code
mkdir -p .claude && curl -o .claude/backend-architect.md \
  https://raw.githubusercontent.com/ivannguyendev/agent-templates/main/skills/backend-architect/SKILL.md

**To install development-landing-page (Workflow — multiple files):**
# claude-code
git clone --depth 1 --filter=blob:none --sparse \
  https://github.com/ivannguyendev/agent-templates.git /tmp/agent-templates
git -C /tmp/agent-templates sparse-checkout set workflows/development-landing-page
cp -r workflows/development-landing-page/* .claude/
rm -rf /tmp/agent-templates
```

### Gap Analysis Output

```
## Skill Matcher Results

**Requirement:** Build a Rust embedded firmware controller

### ⚠️ No Exact Match Found

Closest: **embedded-firmware-engineer** (Skill) — Bare-metal, RTOS, ESP32/STM32/Nordic firmware

**Gap analysis:**
- ✅ Covers: embedded systems, bare-metal, RTOS workflows
- ❌ Missing: Rust-specific toolchain (cargo-embed, probe-rs, defmt)
- 🔧 Needs adjustment: language preference section, toolchain commands

Recommended modifications:
1. Add Rust/Cargo toolchain references in the "Tools" section
2. Replace C code examples with Rust equivalents using `embassy` or `RTIC`
3. Add `probe-rs` as the preferred flashing/debugging tool

Do you want me to generate a modified version of this skill tailored to your requirement?
```

## Technical Notes

- **Environment detection runs first**, before any user interaction or catalog fetch
- Both CSV fetches should happen before scoring begins
- Error handling for fetch failures is defined in Step 3 — follow those rules
- The catalog is community-maintained and grows over time; always fetch fresh (do not rely on cached knowledge of what skills exist)
- When generating a skill file, follow the SKILL.md frontmatter format and validate with `scripts/validate-skill.sh`
- All generated install commands must use the resolved `INSTALL_BASE`, never hardcode a tool path
- Workflows may contain multiple files (scripts, references, assets) — use sparse checkout to install the full directory
