#!/usr/bin/env bash
# Auto-format files after Claude edits them
# Detects repo by path and runs appropriate formatter

FILE=$(jq -r '.tool_response.filePath // .tool_input.file_path' 2>/dev/null)
[ -z "$FILE" ] && exit 0
[ ! -f "$FILE" ] && exit 0

EXT="${FILE##*.}"

# Determine which repo we're in
case "$FILE" in
  */workspace/web/*)
    case "$EXT" in
      ts|tsx|js|jsx|css|scss|graphql|yaml|yml)
        cd ~/workspace/web && yarn format "$FILE" 2>/dev/null
        ;;
    esac
    ;;
  */workspace/zenpayroll/*)
    case "$EXT" in
      rb|rake)
        cd ~/workspace/zenpayroll && bin/rubocop -a --fail-level=fatal "$FILE" 2>/dev/null
        ;;
    esac
    ;;
  */workspace/ai-platform-services/*)
    case "$EXT" in
      py)
        cd ~/workspace/ai-platform-services
        .venv/bin/ruff check --select I --fix "$FILE" 2>/dev/null
        .venv/bin/black --quiet "$FILE" 2>/dev/null
        ;;
      ts|tsx|js|jsx)
        cd ~/workspace/ai-platform-services && npx eslint --fix "$FILE" 2>/dev/null
        ;;
      css|scss)
        cd ~/workspace/ai-platform-services && npx stylelint --fix "$FILE" 2>/dev/null
        ;;
    esac
    ;;
esac

exit 0
