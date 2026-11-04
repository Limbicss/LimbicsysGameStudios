#!/usr/bin/env bash
# guard.sh - shared command guard for the git hooks and the Codex / Antigravity tool hooks.
# One source of truth for "what must never run". Mirrors the deny list in .claude/settings.json
# (force push, hard reset, clean -f, rm -rf, sudo, chmod 777, reading .env).
#
# Usage (sourced):  guard_check_command "<shell command text>"   -> prints a reason, returns 1 when blocked
#                   guard_check_env_text "<any text>"            -> same, only the .env rule
# POSIX ERE only, bash 3.2 safe (Git Bash on Windows). No jq, no python.

guard__segments() {
  # split a command line into one command per line on && || ; | and newlines
  printf '%s' "$1" | sed -e 's/&&/\n/g' -e 's/||/\n/g' -e 's/;/\n/g' -e 's/|/\n/g'
}

guard_check_env_text() {
  local text="$1"
  # a .env path token: preceded by start/space/slash/quote/=, optional .suffix, followed by a delimiter
  if printf '%s' "$text" | grep -Eq '(^|[[:space:]/"'"'"'=\\])\.env(\.[A-Za-z0-9_-]+)?([[:space:]"'"'"';|&)\\,]|$)'; then
    if ! printf '%s' "$text" | grep -Eq '\.env\.(example|sample|template)'; then
      echo "Blocked: touching a .env file (secrets). Ask the owner; use .env.example for templates."
      return 1
    fi
  fi
  return 0
}

guard_check_command() {
  local cmd="$1" seg
  guard_check_env_text "$cmd" || return 1
  while IFS= read -r seg; do
    [ -z "$seg" ] && continue
    # force push: --force*, -f / -uf style bundles, +refspec, delete refspec or --delete
    if printf '%s' "$seg" | grep -Eq '(^|[[:space:]])git([[:space:]]+-[^[:space:]]+)*[[:space:]]+push([[:space:]]|$)'; then
      if printf '%s' "$seg" | grep -Eq '[[:space:]]--force|[[:space:]]-[A-Za-z]*f[A-Za-z]*([[:space:]]|$)|[[:space:]]\+[^[:space:]]'; then
        echo "Blocked: force push. Needs the owner's explicit approval."; return 1
      fi
      if printf '%s' "$seg" | grep -Eq '[[:space:]]--delete|[[:space:]]:[^[:space:]]'; then
        echo "Blocked: deleting a remote branch/tag. Needs the owner's explicit approval."; return 1
      fi
    fi
    if printf '%s' "$seg" | grep -Eq '(^|[[:space:]])git([[:space:]]+-[^[:space:]]+)*[[:space:]]+(commit|push|merge|am|rebase)([[:space:]].*)?[[:space:]]--no-verify'; then
      echo "Blocked: --no-verify skips the safety hooks."; return 1
    fi
    if printf '%s' "$seg" | grep -Eq '(^|[[:space:]])git([[:space:]]+-[^[:space:]]+)*[[:space:]]+reset([[:space:]].*)?[[:space:]]--hard'; then
      echo "Blocked: git reset --hard can destroy uncommitted work."; return 1
    fi
    if printf '%s' "$seg" | grep -Eq '(^|[[:space:]])git([[:space:]]+-[^[:space:]]+)*[[:space:]]+clean([[:space:]].*)?[[:space:]](-[A-Za-z]*f|--force)'; then
      echo "Blocked: git clean -f deletes untracked files."; return 1
    fi
    if printf '%s' "$seg" | grep -Eq '(^|[[:space:]])rm([[:space:]]|$)'; then
      if printf '%s' "$seg" | grep -Eq '[[:space:]](-[A-Za-z]*[rR][A-Za-z]*|--recursive)([[:space:]]|$)' &&
         printf '%s' "$seg" | grep -Eq '[[:space:]](-[A-Za-z]*f[A-Za-z]*|--force)([[:space:]]|$)'; then
        echo "Blocked: recursive forced delete (rm -rf)."; return 1
      fi
    fi
    if printf '%s' "$seg" | grep -Eq '(^|[[:space:]])Remove-Item([[:space:]].*)?[[:space:]]-Recurse'; then
      echo "Blocked: Remove-Item -Recurse."; return 1
    fi
    if printf '%s' "$seg" | grep -Eq '(^|[[:space:]])sudo([[:space:]]|$)'; then
      echo "Blocked: sudo."; return 1
    fi
    if printf '%s' "$seg" | grep -Eq '(^|[[:space:]])chmod[[:space:]]+(-[A-Za-z]+[[:space:]]+)?777'; then
      echo "Blocked: chmod 777."; return 1
    fi
  done <<EOT
$(guard__segments "$cmd")
EOT
  return 0
}
