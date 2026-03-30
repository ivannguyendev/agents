#!/usr/bin/env bash
# validate-skill.sh — Validate SKILL.md format and frontmatter
#
# Usage:
#   ./validate-skill.sh <skill-directory>
#   ./validate-skill.sh .                    # validate current dir
#
# Checks:
#   - SKILL.md exists
#   - YAML frontmatter format (opening/closing ---)
#   - Required fields: name, description
#   - name: kebab-case, max 64 chars
#   - description: no angle brackets, max 1024 chars
#   - Allowed frontmatter keys only
#
# Exit codes: 0 = valid, 1 = invalid

set -eo pipefail

# ─── Args ────────────────────────────────────────────────────────────────────

TARGET="${1:-.}"
SKILL_FILE="${TARGET}/SKILL.md"
ERRORS=0

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1"; ERRORS=$((ERRORS + 1)); }

# ─── Check SKILL.md exists ───────────────────────────────────────────────────

if [[ ! -f "$SKILL_FILE" ]]; then
  fail "SKILL.md not found in $TARGET"
  echo ""
  echo "Result: FAILED (${ERRORS} error)"
  exit 1
fi
pass "SKILL.md found"

# ─── Read file content ───────────────────────────────────────────────────────

CONTENT=$(<"$SKILL_FILE")
FIRST_LINE=$(head -n 1 "$SKILL_FILE")

# ─── Check frontmatter delimiters ────────────────────────────────────────────

if [[ "$FIRST_LINE" != "---" ]]; then
  fail "No YAML frontmatter (first line must be '---')"
  echo ""
  echo "Result: FAILED (${ERRORS} error)"
  exit 1
fi

# Find closing --- (skip first line)
CLOSE_LINE=0
LINE_NUM=0
while IFS= read -r line; do
  LINE_NUM=$((LINE_NUM + 1))
  if [[ $LINE_NUM -gt 1 && "$line" == "---" ]]; then
    CLOSE_LINE=$LINE_NUM
    break
  fi
done < "$SKILL_FILE"

if [[ $CLOSE_LINE -eq 0 ]]; then
  fail "Frontmatter not closed (missing closing '---')"
  echo ""
  echo "Result: FAILED (${ERRORS} error)"
  exit 1
fi
pass "Frontmatter valid (lines 1-${CLOSE_LINE})"

# ─── Extract frontmatter ─────────────────────────────────────────────────────
# Get lines between first --- and closing ---

FRONTMATTER=$(sed -n "2,$((CLOSE_LINE - 1))p" "$SKILL_FILE")

# ─── Parse top-level keys ────────────────────────────────────────────────────
# Only match lines that start with a non-space char and contain a colon

ALLOWED_KEYS="name description license allowed-tools metadata compatibility"

FOUND_KEYS=""
while IFS= read -r line; do
  # Skip empty lines and lines starting with whitespace (continuation/nested)
  [[ -z "$line" ]] && continue
  [[ "$line" =~ ^[[:space:]] ]] && continue

  # Extract key (everything before first colon)
  KEY="${line%%:*}"
  KEY=$(echo "$KEY" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//') # trim whitespace

  [[ -z "$KEY" ]] && continue

  FOUND_KEYS="$FOUND_KEYS $KEY"

  # Check if key is allowed
  ALLOWED=false
  for ak in $ALLOWED_KEYS; do
    if [[ "$KEY" == "$ak" ]]; then
      ALLOWED=true
      break
    fi
  done

  if [[ "$ALLOWED" == false ]]; then
    fail "Unknown key '${KEY}' in frontmatter (allowed: ${ALLOWED_KEYS})"
  fi
done <<< "$FRONTMATTER"

# ─── Check required fields ───────────────────────────────────────────────────

# Extract name value
NAME=""
while IFS= read -r line; do
  if [[ "$line" =~ ^name: ]]; then
    NAME="${line#name:}"
    NAME=$(echo "$NAME" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed "s/^['\"]//;s/['\"]$//")
    break
  fi
done <<< "$FRONTMATTER"

# Extract description value (handle single-line and multiline indicators)
DESC=""
while IFS= read -r line; do
  if [[ "$line" =~ ^description: ]]; then
    VALUE="${line#description:}"
    VALUE=$(echo "$VALUE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Check for YAML multiline indicators
    if [[ "$VALUE" == ">" || "$VALUE" == "|" || "$VALUE" == ">-" || "$VALUE" == "|-" ]]; then
      # Read continuation lines (indented)
      CONTINUATION=""
      PAST_DESC=false
      while IFS= read -r fline; do
        if [[ "$PAST_DESC" == true ]]; then
          if [[ "$fline" =~ ^[[:space:]] ]]; then
            CONTINUATION="$CONTINUATION $(echo "$fline" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
          else
            break
          fi
        fi
        if [[ "$fline" =~ ^description: ]]; then
          PAST_DESC=true
        fi
      done <<< "$FRONTMATTER"
      DESC=$(echo "$CONTINUATION" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    else
      DESC=$(echo "$VALUE" | sed "s/^['\"]//;s/['\"]$//")
    fi
    break
  fi
done <<< "$FRONTMATTER"

# ─── Validate name ───────────────────────────────────────────────────────────

if [[ -z "$NAME" ]]; then
  fail "Missing required field 'name'"
else
  NAME_LEN=${#NAME}

  # Check kebab-case
  if ! echo "$NAME" | grep -qE '^[a-z0-9-]+$'; then
    fail "name '${NAME}' must be kebab-case (lowercase letters, digits, hyphens only)"
  elif [[ "$NAME" == -* || "$NAME" == *- ]]; then
    fail "name '${NAME}' cannot start or end with a hyphen"
  elif [[ "$NAME" == *--* ]]; then
    fail "name '${NAME}' cannot contain consecutive hyphens"
  elif [[ $NAME_LEN -gt 64 ]]; then
    fail "name too long (${NAME_LEN} chars, max 64)"
  else
    pass "name: ${NAME} (kebab-case, ${NAME_LEN} chars)"
  fi
fi

# ─── Validate description ────────────────────────────────────────────────────

if [[ -z "$DESC" ]]; then
  fail "Missing required field 'description'"
else
  DESC_LEN=${#DESC}

  if [[ "$DESC" == *"<"* || "$DESC" == *">"* ]]; then
    fail "description cannot contain angle brackets (< or >)"
  elif [[ $DESC_LEN -gt 1024 ]]; then
    fail "description too long (${DESC_LEN} chars, max 1024)"
  else
    pass "description: ${DESC_LEN} chars"
  fi
fi

# ─── Result ──────────────────────────────────────────────────────────────────

echo ""
if [[ $ERRORS -eq 0 ]]; then
  echo "Result: PASSED"
  exit 0
else
  echo "Result: FAILED (${ERRORS} error(s))"
  exit 1
fi
