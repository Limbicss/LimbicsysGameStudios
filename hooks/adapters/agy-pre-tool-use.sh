#!/usr/bin/env bash
# Antigravity (AGY) PreToolUse adapter. Registered in .agents/hooks.json.
# stdin: {"toolCall":{"name":"run_command","args":{"CommandLine":"..."}}, ...}
# Block = print {"decision":"deny","reason":"..."} on stdout, exit 0 (documented AGY contract).
# Tool arg names other than CommandLine are not documented, so the whole args object is scanned.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$ROOT/hooks/lib/guard.sh"
. "$ROOT/hooks/lib/payload.sh"
PAYLOAD="$(cat)"

deny() { printf '{"decision":"deny","reason":"%s"}\n' "$(printf '%s' "$1" | tr -d '"\\')"; exit 0; }

# jq, then python, then a string scan. If none can parse, refuse the command.
if ! payload_decode agy "$PAYLOAD"; then
  deny "Blocked: could not parse the tool payload, so the command was refused."
fi
NAME="$PAYLOAD_TOOL"
TEXT="$PAYLOAD_TEXT"

case "$NAME" in
  run_command|"") REASON="$(guard_check_command "$TEXT")" || deny "$REASON" ;;
  *)              REASON="$(guard_check_env_text "$TEXT")" || deny "$REASON" ;;
esac
printf '{}\n'
exit 0
