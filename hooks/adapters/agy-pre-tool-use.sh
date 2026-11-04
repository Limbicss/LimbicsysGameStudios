#!/usr/bin/env bash
# Antigravity (AGY) PreToolUse adapter. Registered in .agents/hooks.json.
# stdin: {"toolCall":{"name":"run_command","args":{"CommandLine":"..."}}, ...}
# Block = print {"decision":"deny","reason":"..."} on stdout, exit 0 (documented AGY contract).
# Tool arg names other than CommandLine are not documented, so the whole args object is scanned.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$ROOT/hooks/lib/guard.sh"
PAYLOAD="$(cat)"

NAME=""; TEXT="$PAYLOAD"
if command -v jq >/dev/null 2>&1; then
  NAME="$(printf '%s' "$PAYLOAD" | jq -r '.toolCall.name // empty' 2>/dev/null)"
  TEXT="$(printf '%s' "$PAYLOAD" | jq -r '.toolCall.args | (.CommandLine // tojson)' 2>/dev/null)"
  [ -z "$TEXT" ] && TEXT="$PAYLOAD"
fi

deny() { printf '{"decision":"deny","reason":"%s"}\n' "$(printf '%s' "$1" | tr -d '"\\')"; exit 0; }

case "$NAME" in
  run_command|"") REASON="$(guard_check_command "$TEXT")" || deny "$REASON" ;;
  *)              REASON="$(guard_check_env_text "$TEXT")" || deny "$REASON" ;;
esac
printf '{}\n'
exit 0
