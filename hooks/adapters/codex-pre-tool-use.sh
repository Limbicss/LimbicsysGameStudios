#!/usr/bin/env bash
# Codex PreToolUse adapter. Registered in .codex/hooks.json.
# stdin: Codex hook JSON {tool_name, tool_input:{command,...}, cwd, ...}
# Block = exit 2 + reason on stderr (documented Codex contract).
# Reuses hooks/lib/guard.sh and the original .claude/hooks/validate-commit.sh / validate-push.sh.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$ROOT/hooks/lib/guard.sh"
PAYLOAD="$(cat)"

TOOL=""; TEXT="$PAYLOAD"
if command -v jq >/dev/null 2>&1; then
  TOOL="$(printf '%s' "$PAYLOAD" | jq -r '.tool_name // empty' 2>/dev/null)"
  TEXT="$(printf '%s' "$PAYLOAD" | jq -r '.tool_input | if type=="string" then . else (.command // .cmd // tojson) end' 2>/dev/null)"
  [ -z "$TEXT" ] && TEXT="$PAYLOAD"
fi

case "$TOOL" in
  Bash|exec_command|shell|"")
    REASON="$(guard_check_command "$TEXT")" || { echo "$REASON" >&2; exit 2; }
    # original Claude-era checks read the same {tool_input:{command}} shape
    if printf '%s' "$PAYLOAD" | grep -Eq '"command"[[:space:]]*:[[:space:]]*"[^"]*git'; then
      for h in validate-commit.sh validate-push.sh; do
        [ -f "$ROOT/.claude/hooks/$h" ] || continue
        ERR="$(printf '%s' "$PAYLOAD" | bash "$ROOT/.claude/hooks/$h" 2>&1 >/dev/null)"; RC=$?
        if [ "$RC" = "2" ]; then echo "$ERR" >&2; exit 2; fi
      done
    fi
    ;;
  *)
    # file-edit tools (apply_patch / Edit / Write / MCP): only the .env rule applies
    REASON="$(guard_check_env_text "$TEXT")" || { echo "$REASON" >&2; exit 2; }
    ;;
esac
exit 0
