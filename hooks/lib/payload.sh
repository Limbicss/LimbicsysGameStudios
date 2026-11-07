#!/usr/bin/env bash
# payload.sh - read a Codex or Antigravity tool-hook payload.
# Extracts the tool name and the command text without requiring jq.
# Order: jq, then python3/python, then a small bash/grep string scan.
# Returns 1 when none of those can parse the payload. Callers must fail closed.
#
# Usage (sourced):
#   payload_decode codex "$PAYLOAD"   # or: payload_decode agy "$PAYLOAD"
#   -> sets PAYLOAD_TOOL and PAYLOAD_TEXT, returns 0 on success

PAYLOAD_TOOL=""
PAYLOAD_TEXT=""

payload__split() {
  local out="$1" body
  case "$out" in
    *$'\n---PAYLOAD-END-7f3a---') ;;
    *) return 1 ;;
  esac
  body="${out%$'\n---PAYLOAD-END-7f3a---'}"
  PAYLOAD_TOOL="${body%%$'\n'*}"
  if [ "$body" = "$PAYLOAD_TOOL" ]; then
    PAYLOAD_TEXT=""
  else
    PAYLOAD_TEXT="${body#*$'\n'}"
  fi
  return 0
}

# Codex and AGY filters print: tool \n text \n---PAYLOAD-END-7f3a---
PAYLOAD_JQ_CODEX='(.tool_name // "") + "\n" + (.tool_input | if type == "string" then . elif type == "object" then (.command // .cmd // tojson) elif type == "null" then "" else tojson end) + "\n---PAYLOAD-END-7f3a---"'
PAYLOAD_JQ_AGY='(.toolCall.name // "") + "\n" + (.toolCall.args | if type == "object" then (.CommandLine // tojson) elif type == "string" then . elif type == "null" then "" else tojson end) + "\n---PAYLOAD-END-7f3a---"'

PAYLOAD_PY='import json, sys
mode = sys.argv[1]
raw = sys.stdin.read()
try:
    data = json.loads(raw)
except Exception:
    sys.exit(1)
if not isinstance(data, dict):
    sys.exit(1)

def finish(tool, text):
    if not isinstance(tool, str):
        tool = ""
    if not isinstance(text, str):
        text = ""
    sys.stdout.write(tool + "\n" + text + "\n---PAYLOAD-END-7f3a---")

def tool_input_text(ti):
    if isinstance(ti, str):
        return ti
    if isinstance(ti, dict):
        for key in ("command", "cmd"):
            val = ti.get(key)
            if isinstance(val, str):
                return val
        return json.dumps(ti, separators=(",", ":"))
    if ti is None:
        return ""
    return json.dumps(ti)

if mode == "agy":
    tc = data.get("toolCall")
    if not isinstance(tc, dict):
        finish("", "")
    else:
        name = tc.get("name") or ""
        args = tc.get("args")
        if isinstance(args, dict) and isinstance(args.get("CommandLine"), str):
            text = args["CommandLine"]
        elif isinstance(args, str):
            text = args
        elif args is None:
            text = ""
        else:
            text = json.dumps(args, separators=(",", ":"))
        finish(name if isinstance(name, str) else "", text)
else:
    tool = data.get("tool_name") or ""
    finish(tool if isinstance(tool, str) else "", tool_input_text(data.get("tool_input")))
'

payload__from_jq() {
  local mode="$1" payload="$2" filter out
  command -v jq >/dev/null 2>&1 || return 1
  if [ "$mode" = "agy" ]; then
    filter="$PAYLOAD_JQ_AGY"
  else
    filter="$PAYLOAD_JQ_CODEX"
  fi
  out="$(printf '%s' "$payload" | jq -r "$filter" 2>/dev/null)" || return 1
  payload__split "$out" || return 1
}

payload__from_python() {
  local mode="$1" payload="$2" py out
  if command -v python3 >/dev/null 2>&1; then
    py=python3
  elif command -v python >/dev/null 2>&1; then
    py=python
  else
    return 1
  fi
  out="$(printf '%s' "$payload" | "$py" -c "$PAYLOAD_PY" "$mode" 2>/dev/null)" || return 1
  payload__split "$out" || return 1
}

# Last resort: pull a JSON string value out of the raw text. Not a full parser.
payload__json_string() {
  local payload="$1" key="$2" needle rest c n out i len
  needle="\"$key\""
  rest="$payload"
  while true; do
    case "$rest" in
      *"$needle"*) ;;
      *) return 1 ;;
    esac
    rest="${rest#*"$needle"}"
    while [ -n "$rest" ]; do
      case "${rest:0:1}" in
        [[:space:]]) rest="${rest:1}" ;;
        *) break ;;
      esac
    done
    [ "${rest:0:1}" = ":" ] || continue
    rest="${rest:1}"
    while [ -n "$rest" ]; do
      case "${rest:0:1}" in
        [[:space:]]) rest="${rest:1}" ;;
        *) break ;;
      esac
    done
    [ "${rest:0:1}" = '"' ] || continue
    rest="${rest:1}"
    out=""
    len=${#rest}
    i=0
    while [ "$i" -lt "$len" ]; do
      c="${rest:$i:1}"
      if [ "$c" = "\\" ]; then
        n="${rest:$((i + 1)):1}"
        case "$n" in
          n) out="${out}"$'\n' ;;
          t) out="${out}"$'\t' ;;
          '"') out="${out}\"" ;;
          \\) out="${out}\\" ;;
          *) out="${out}${n}" ;;
        esac
        i=$((i + 2))
        continue
      fi
      if [ "$c" = '"' ]; then
        printf '%s' "$out"
        return 0
      fi
      out="${out}${c}"
      i=$((i + 1))
    done
    return 1
  done
}

payload__from_grep() {
  local mode="$1" payload="$2" tool="" text="" slice
  if [ "$mode" = "agy" ]; then
    slice="$payload"
    case "$payload" in
      *'"toolCall"'*) slice="${payload#*\"toolCall\"}" ;;
    esac
    tool="$(payload__json_string "$slice" name)" || tool=""
    if text="$(payload__json_string "$payload" CommandLine)"; then
      :
    else
      case "$tool" in
        ""|run_command)
          case "$payload" in
            *[![:space:]{}]*) return 1 ;;
            *) PAYLOAD_TOOL=""; PAYLOAD_TEXT=""; return 0 ;;
          esac
          ;;
        *) text="$payload" ;;
      esac
    fi
  else
    tool="$(payload__json_string "$payload" tool_name)" || tool=""
    if text="$(payload__json_string "$payload" command)"; then
      :
    elif text="$(payload__json_string "$payload" cmd)"; then
      :
    else
      case "$tool" in
        ""|Bash|exec_command|shell)
          case "$payload" in
            *[![:space:]{}]*) return 1 ;;
            *) PAYLOAD_TOOL=""; PAYLOAD_TEXT=""; return 0 ;;
          esac
          ;;
        *) text="$payload" ;;
      esac
    fi
  fi
  PAYLOAD_TOOL="$tool"
  PAYLOAD_TEXT="$text"
  return 0
}

payload_decode() {
  local mode="$1" payload="$2"
  PAYLOAD_TOOL=""
  PAYLOAD_TEXT=""
  payload__from_jq "$mode" "$payload" && return 0
  payload__from_python "$mode" "$payload" && return 0
  payload__from_grep "$mode" "$payload" && return 0
  PAYLOAD_TOOL=""
  PAYLOAD_TEXT=""
  return 1
}
