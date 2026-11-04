#!/usr/bin/env bash
# tests/hooks_test.sh - T3 acceptance. Runs in a throwaway copy of the working tree; touches nothing here.
#   1 bad commit (blocked)  + 1 good commit (passes)  + force push blocked
#   .env read denied by the Codex and AGY tool-hook adapters.  Usage: bash tests/hooks_test.sh
set -u
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PASS=0; FAILN=0
ok()  { PASS=$((PASS+1)); echo "  PASS  $1"; }
bad() { FAILN=$((FAILN+1)); echo "  FAIL  $1"; }
expect_fail() { local name="$1"; shift; if "$@" >/dev/null 2>"$TMP/err"; then bad "$name (expected block, got success)"; else ok "$name  <- $(head -c 90 "$TMP/err" | tr '\n' ' ')"; fi; }
expect_ok()   { local name="$1"; shift; if "$@" >/dev/null 2>"$TMP/err"; then ok "$name"; else bad "$name (expected success) $(head -c 200 "$TMP/err")"; fi; }

WORK="$TMP/work"; REMOTE="$TMP/remote.git"
mkdir -p "$WORK"
( cd "$SRC" && tar --exclude=.git -cf - . ) | ( cd "$WORK" && tar -xf - )
git init -q --bare "$REMOTE"
cd "$WORK" || exit 1
git init -q -b main . && git config user.email t@t && git config user.name t
git config core.hooksPath hooks && git remote add origin "$REMOTE"
chmod +x hooks/pre-commit hooks/commit-msg hooks/pre-push

echo "== git hooks"
# seed commit on main via the explicit owner override (also proves the override works)
git add -A >/dev/null 2>&1
git -c core.hooksPath=/dev/null commit -q -m "chore: seed"
PORT_ALLOW_PROTECTED_PUSH=1 git push -q origin main 2>/dev/null && ok "owner override allows main push" || bad "owner override"
git checkout -q -b feature/test

mkdir -p assets/data && echo '{"hp": ' > assets/data/broken.json
git add assets/data/broken.json
expect_fail "BAD commit: invalid data JSON blocked" git commit -q -m "fix: add broken data"
git reset -q && rm assets/data/broken.json

echo "TOKEN=1" > .env; git add -f .env
expect_fail "BAD commit: staged .env blocked" git commit -q -m "chore: add env"
git reset -q && rm .env

echo "x" > a.txt; git add a.txt
expect_fail "BAD commit: non-conventional message blocked" git commit -q -m "update stuff"

echo '{"hp": 10}' > assets/data/good.json; git add assets/data/good.json a.txt
expect_ok   "GOOD commit passes" git commit -q -m "feat(data): add good data" -m "Task: T3"

expect_ok   "normal push of a feature branch passes" git push -q origin feature/test
echo y >> a.txt; git add a.txt; git commit -q -m "fix: tweak a"
git commit -q --amend -m "fix: tweak a (amended)" 2>/dev/null
git commit -q --amend --no-edit 2>/dev/null
git reset -q --soft HEAD~2 && git commit -q -m "feat(data): rewritten history"
expect_fail "FORCE push blocked (non-fast-forward)" git push -f origin feature/test
expect_fail "push to main blocked without owner override" git push origin feature/test:main
expect_fail "remote branch delete blocked" git push origin --delete feature/test

echo "== Codex tool hook (.codex/hooks.json adapter)"
CX="bash hooks/adapters/codex-pre-tool-use.sh"
cx() { printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/^/"/; s/$/"/')" | $CX; }
expect_fail "codex: git push --force denied (exit 2)" cx "git push --force origin main"
expect_fail "codex: git push origin x -f (flag after args) denied" cx "git push origin x -f"
expect_fail "codex: reading .env denied" cx "cat .env"
expect_fail "codex: rm -rf denied" cx "rm -rf build"
expect_fail "codex: --no-verify denied" cx "git commit --no-verify -m x"
expect_ok   "codex: harmless command allowed" cx "ls -la"
expect_ok   "codex: .env.example allowed" cx "cat .env.example"
expect_ok   "codex: normal push allowed" cx "git push origin feature/x"
# exit code must be 2 (documented block code)
cx "git push --force" >/dev/null 2>&1; RC=$?; [ "$RC" = "2" ] && ok "codex block exit code is 2" || bad "codex exit code $RC"
printf '{"tool_name":"apply_patch","tool_input":{"command":"*** Update File: .env\\n"}}' | $CX >/dev/null 2>&1; RC=$?
[ "$RC" = "2" ] && ok "codex: apply_patch on .env denied" || bad "codex apply_patch .env rc=$RC"

echo "== AGY tool hook (.agents/hooks.json adapter)"
AG="bash hooks/adapters/agy-pre-tool-use.sh"
ag() { printf '{"toolCall":{"name":"%s","args":{"CommandLine":"%s"}}}' "$1" "$2" | $AG; }
ag run_command "git push --force origin main" | grep -q '"decision":"deny"' && ok "agy: force push -> deny JSON" || bad "agy force push"
ag run_command "type .env" | grep -q '"decision":"deny"' && ok "agy: reading .env -> deny JSON" || bad "agy .env"
printf '{"toolCall":{"name":"view_file","args":{"AbsolutePath":"/w/.env"}}}' | $AG | grep -q '"decision":"deny"' && ok "agy: view_file .env -> deny JSON" || bad "agy view_file .env"
ag run_command "ls" | grep -q '"decision"' && bad "agy: ls wrongly denied" || ok "agy: harmless command allowed"

echo "== Codex execpolicy rules (needs the codex binary)"
if command -v codex >/dev/null 2>&1; then
  codex execpolicy check --pretty --rules .codex/rules/studio.rules -- git push --force origin main | grep -q forbidden && ok "codex execpolicy: force push forbidden" || bad "codex execpolicy"
else
  echo "  SKIP  codex binary not installed here - rules file is syntax-checked only"
  python3 -c "import ast,sys;ast.parse(open('.codex/rules/studio.rules').read())" && ok "studio.rules parses (Starlark is a Python subset)" || bad "studio.rules syntax"
fi

echo; echo "RESULT: $PASS passed, $FAILN failed"
[ "$FAILN" = 0 ]
