#!/usr/bin/env bash
set -eo pipefail

# ─── Purpose ───────────────────────────────────────────────────────────────────
# Generate CHANGELOG.md from conventional commits in git history.
# Groups commits by type (feat, fix, docs, etc.) within each tag/date section.
# Zero external dependencies — uses only git and standard Unix tools.
#
# Usage:
#   ./generate-changelog.sh                  # Output to stdout
#   ./generate-changelog.sh -o CHANGELOG.md  # Write to file
#   ./generate-changelog.sh --jekyll         # Add Jekyll front matter
#   ./generate-changelog.sh --astro          # Add Astro/Starlight front matter
#
# Exit codes:
#   0 — success
#   1 — not a git repository

# ─── Config ────────────────────────────────────────────────────────────────────

OUTFILE=""
JEKYLL=false
ASTRO=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) OUTFILE="$2"; shift 2 ;;
    --jekyll) JEKYLL=true; shift ;;
    --astro) ASTRO=true; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  echo "Error: not a git repository" >&2
  exit 1
fi

# ─── Type Labels ───────────────────────────────────────────────────────────────

type_label() {
  case "$1" in
    feat)     echo "Features" ;;
    fix)      echo "Bug Fixes" ;;
    docs)     echo "Documentation" ;;
    style)    echo "Styles" ;;
    refactor) echo "Refactoring" ;;
    test)     echo "Tests" ;;
    chore)    echo "Chores" ;;
    perf)     echo "Performance" ;;
    *)        echo "Other" ;;
  esac
}

# Ordered types for consistent output
TYPES="feat fix docs style refactor test chore perf other"

# ─── Collect Tags ──────────────────────────────────────────────────────────────

TAGS=()
while IFS= read -r tag; do
  [[ -n "$tag" ]] && TAGS+=("$tag")
done < <(git tag --sort=-version:refname 2>/dev/null)

# Build revision ranges: tag..prev_tag, then oldest_tag..root
RANGES=()
LABELS=()

if [[ ${#TAGS[@]} -gt 0 ]]; then
  # Unreleased commits (HEAD to latest tag)
  unreleased_count=$(git rev-list "${TAGS[0]}..HEAD" --count 2>/dev/null || echo 0)
  if [[ "$unreleased_count" -gt 0 ]]; then
    RANGES+=("${TAGS[0]}..HEAD")
    LABELS+=("Unreleased")
  fi

  # Between tags
  for ((i = 0; i < ${#TAGS[@]} - 1; i++)); do
    RANGES+=("${TAGS[i+1]}..${TAGS[i]}")
    tag_date=$(git log -1 --format='%Y-%m-%d' "${TAGS[i]}" 2>/dev/null)
    LABELS+=("${TAGS[i]} — $tag_date")
  done

  # From root to oldest tag
  RANGES+=("${TAGS[-1]}")
  tag_date=$(git log -1 --format='%Y-%m-%d' "${TAGS[-1]}" 2>/dev/null)
  LABELS+=("${TAGS[-1]} — $tag_date")
else
  # No tags — all commits grouped by date
  RANGES+=("HEAD")
  LABELS+=("Unreleased")
fi

# ─── Generate ──────────────────────────────────────────────────────────────────

generate() {
  if [[ "$JEKYLL" == true ]]; then
    echo "---"
    echo "layout: default"
    echo "title: Changelog"
    echo "nav_order: 2"
    echo "---"
    echo ""
  fi

  if [[ "$ASTRO" == true ]]; then
    echo "---"
    echo "title: Changelog"
    echo "description: Auto-generated changelog from conventional commits"
    echo "---"
    echo ""
  fi

  echo "# Changelog"
  echo ""
  echo "*Auto-generated from conventional commits.*"
  echo ""

  for ((r = 0; r < ${#RANGES[@]}; r++)); do
    range="${RANGES[r]}"
    label="${LABELS[r]}"

    # Collect commits for this range
    # Format: type|scope|subject|hash
    commits=""
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue

      hash="${line%% *}"
      msg="${line#* }"
      short_hash="${hash:0:7}"

      # Parse conventional commit: type(scope): subject
      # Compatible with bash 3.x (macOS default)
      ctype=""
      scope=""
      subject=""

      if echo "$msg" | grep -qE '^[a-z]+(\([^)]*\))?!?: '; then
        ctype=$(echo "$msg" | sed -E 's/^([a-z]+).*/\1/')
        if echo "$msg" | grep -qE '^\w+\([^)]+\)'; then
          scope=$(echo "$msg" | sed -E 's/^[a-z]+\(([^)]*)\).*/\1/')
        fi
        subject=$(echo "$msg" | sed -E 's/^[a-z]+(\([^)]*\))?!?: //')
      else
        ctype="other"
        subject="$msg"
      fi

      commits+="${ctype}|${scope}|${subject}|${short_hash}"$'\n'
    done < <(git log --format='%H %s' "$range" 2>/dev/null)

    [[ -z "$commits" ]] && continue

    echo "## $label"
    echo ""

    # Group by type
    for t in $TYPES; do
      type_commits=""
      while IFS= read -r entry; do
        [[ -z "$entry" ]] && continue
        IFS='|' read -r etype escope esubject ehash <<< "$entry"
        [[ "$etype" != "$t" ]] && continue

        if [[ -n "$escope" ]]; then
          type_commits+="- **${escope}:** ${esubject} (\`${ehash}\`)"$'\n'
        else
          type_commits+="- ${esubject} (\`${ehash}\`)"$'\n'
        fi
      done <<< "$commits"

      if [[ -n "$type_commits" ]]; then
        echo "### $(type_label "$t")"
        echo ""
        echo -n "$type_commits"
        echo ""
      fi
    done
  done
}

# ─── Output ────────────────────────────────────────────────────────────────────

if [[ -n "$OUTFILE" ]]; then
  generate > "$OUTFILE"
  echo "Changelog written to $OUTFILE"
else
  generate
fi
