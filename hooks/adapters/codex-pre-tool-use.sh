#!/usr/bin/env bash
# Codex PreToolUse adapter. Registered in .codex/hooks.json.
# stdin: Codex hook JSON {tool_name, tool_input:{command,...}, cwd, ...}
# Block = exit 2 + reason on stderr (documented Codex contract).
# Reuses hooks/lib/guard.sh and the original .claude/hooks/validate-commit.sh / validate-push.sh.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$ROOT/hooks/lib/guard.sh"
. "$ROOT/hooks/lib/payload.sh"
PAYLOAD="$(cat)"

# jq, then python, then a string scan. If none can parse, refuse the command.
if ! payload_decode codex "$PAYLOAD"; then
  echo "Blocked: could not parse the tool payload, so the command was refused." >&2
  exit 2
fi
TOOL="$PAYLOAD_TOOL"
TEXT="$PAYLOAD_TEXT"

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
