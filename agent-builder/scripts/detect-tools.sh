#!/usr/bin/env bash
# detect-tools.sh — Detect installed AI coding tools and resolve install paths
#
# Usage:
#   ./detect-tools.sh              # detect all tools, print results
#   ./detect-tools.sh --json       # output as JSON
#   ./detect-tools.sh --first      # print only the first detected tool name
#   ./detect-tools.sh --path <tool> # print install path(s) for a specific tool
#
# Tools detected:
#   claude-code  -- Copy to .claude in current directory
#   copilot      -- Copy to .github in current directory
#   antigravity  -- Copy to .agents in current directory
#   gemini-cli   -- Copy to .gemini in current directory
#   opencode     -- Copy to .opencode in current directory
#   cursor       -- Copy to .cursor in current directory
#   aider        -- Copy CONVENTIONS.md to current directory
#   windsurf     -- Copy to .windsurf in current directory
#   openclaw     -- Copy to .openclaw in current directory
#   qwen         -- Copy to .qwen in current directory

set -eo pipefail

CWD="$(pwd)"
H="$(eval echo ~)"

# ─── Tool paths ───────────────────────────────────────────────────────────────
# Returns newline-separated install paths for a given tool name

tool_paths() {
  case "$1" in
    claude-code)  echo "${CWD}/.claude" ;;
    copilot)      echo "${CWD}/.github" ;;
    antigravity)  echo "${CWD}/.agents" ;;
    gemini-cli)   echo "${CWD}/.gemini" ;;
    opencode)     echo "${CWD}/.opencode" ;;
    cursor)       echo "${CWD}/.cursor" ;;
    aider)        echo "${CWD}" ;;
    windsurf)     echo "${CWD}/.windsurf" ;;
    openclaw)     echo "${CWD}/.openclaw" ;;
    qwen)         echo "${CWD}/.qwen" ;;
    *)            echo "" ;;
  esac
}

ALL_TOOLS="claude-code copilot antigravity gemini-cli opencode cursor aider windsurf openclaw qwen"

# ─── Detection rules ──────────────────────────────────────────────────────────

detect_tool() {
  case "$1" in
    claude-code)
      command -v claude &>/dev/null || [[ -d "${H}/.claude" ]]
      ;;
    copilot)
      { command -v gh &>/dev/null && gh extension list 2>/dev/null | grep -qi "copilot"; } ||
      [[ -d "${H}/.github" ]] || [[ -d "${H}/.copilot" ]]
      ;;
    antigravity)
      command -v antigravity &>/dev/null || [[ -d "${H}/.gemini/antigravity" ]]
      ;;
    gemini-cli)
      command -v gemini &>/dev/null || [[ -d "${H}/.gemini/extensions" ]]
      ;;
    opencode)
      command -v opencode &>/dev/null || [[ -d "${CWD}/.opencode" ]]
      ;;
    cursor)
      command -v cursor &>/dev/null ||
      [[ -d "${CWD}/.cursor" ]] ||
      [[ -d "/Applications/Cursor.app" ]]
      ;;
    aider)
      command -v aider &>/dev/null || python3 -m aider --version &>/dev/null 2>&1
      ;;
    windsurf)
      command -v windsurf &>/dev/null ||
      [[ -f "${CWD}/.windsurfrules" ]] ||
      [[ -d "/Applications/Windsurf.app" ]]
      ;;
    openclaw)
      command -v openclaw &>/dev/null || [[ -d "${H}/.openclaw" ]]
      ;;
    qwen)
      command -v qwen &>/dev/null ||
      [[ -d "${H}/.qwen" ]] ||
      [[ -d "${CWD}/.qwen" ]]
      ;;
    *)
      return 1
      ;;
  esac
}

# ─── Run detection ────────────────────────────────────────────────────────────

DETECTED=""
for tool in $ALL_TOOLS; do
  if detect_tool "$tool" 2>/dev/null; then
    DETECTED="$DETECTED $tool"
  fi
done
DETECTED="${DETECTED# }"  # trim leading space

# ─── Output modes ─────────────────────────────────────────────────────────────

print_default() {
  if [[ -z "$DETECTED" ]]; then
    echo "No AI tools detected."
    echo ""
    echo "Supported: $ALL_TOOLS"
    return
  fi
  local count
  count=$(echo "$DETECTED" | wc -w | tr -d ' ')
  echo "Detected AI tools (${count}):"
  echo ""
  for tool in $DETECTED; do
    echo "  ✓ $tool"
    while IFS= read -r path; do
      echo "    $path"
    done < <(tool_paths "$tool")
  done
}

print_json() {
  echo "{"
  echo "  \"detected\": ["
  local first=true
  for tool in $DETECTED; do
    [[ "$first" == true ]] && first=false || echo ","
    local paths_json=""
    while IFS= read -r path; do
      paths_json+="\"${path}\","
    done < <(tool_paths "$tool")
    paths_json="${paths_json%,}"
    printf '    { "tool": "%s", "paths": [%s] }' "$tool" "$paths_json"
  done
  [[ "$first" == false ]] && echo ""
  echo "  ]"
  echo "}"
}

MODE="${1:-}"

case "$MODE" in
  --json)
    print_json
    ;;
  --first)
    first_tool=$(echo "$DETECTED" | awk '{print $1}')
    echo "${first_tool:-none}"
    ;;
  --path)
    target="${2:-}"
    if [[ -z "$target" ]]; then
      echo "Usage: $0 --path <tool-name>" >&2
      exit 1
    fi
    paths=$(tool_paths "$target")
    if [[ -z "$paths" ]]; then
      echo "Unknown tool: $target" >&2
      exit 1
    fi
    echo "$paths"
    ;;
  *)
    print_default
    ;;
esac
