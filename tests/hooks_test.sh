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

BASH_BIN="$(command -v bash)"
HOOK_PATH=""
run_adapter() {
  if [ -n "$HOOK_PATH" ]; then PATH="$HOOK_PATH" "$BASH_BIN" "$@"; else "$BASH_BIN" "$@"; fi
}
json_quote() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/^/"/; s/$/"/'; }

# PATH for the adapters only. Excludes named binaries (jq, python) so fallbacks are real.
build_path_excluding() {
  local dest="$1"; shift
  local exclude=" $* "
  mkdir -p "$dest"
  local d p n
  while IFS= read -r d; do
    [ -n "$d" ] && [ -d "$d" ] || continue
    for p in "$d"/*; do
      [ -e "$p" ] || continue
      n="$(basename "$p")"
      case "$exclude" in *" $n "*) continue ;; esac
      [ -e "$dest/$n" ] && continue
      ln -s "$p" "$dest/$n" 2>/dev/null || true
    done
  done <<EOF
$(printf '%s' "$PATH" | tr ':' '\n')
EOF
}

echo "== Codex tool hook (.codex/hooks.json adapter)"
cx() { printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(json_quote "$1")" | run_adapter hooks/adapters/codex-pre-tool-use.sh; }
expect_fail "codex: git push --force denied (exit 2)" cx "git push --force origin main"
expect_fail "codex: git push -f denied" cx "git push -f origin main"
expect_fail "codex: git push origin x -f (flag after args) denied" cx "git push origin x -f"
expect_fail "codex: git push --force-with-lease denied" cx "git push --force-with-lease origin main"
expect_fail "codex: reading .env denied" cx "cat .env"
expect_fail "codex: .env beside .env.example still denied" cx "cat .env .env.example"
expect_fail "codex: .env.example beside .env still denied" cx "cat .env.example .env"
expect_fail "codex: .env.example2 is not a template" cx "cat .env.example2"
expect_fail "codex: rm -rf denied" cx "rm -rf build"
expect_fail "codex: rm -fr denied" cx "rm -fr /tmp/build"
expect_fail "codex: rm -r -f denied" cx "rm -r -f build"
expect_fail "codex: --no-verify denied" cx "git commit --no-verify -m x"
expect_ok   "codex: harmless command allowed" cx "ls -la"
expect_ok   "codex: .env.example allowed" cx "cat .env.example"
expect_ok   "codex: .env.sample allowed" cx "cat .env.sample"
expect_ok   "codex: normal push allowed" cx "git push origin feature/x"
# exit code must be 2 (documented block code)
cx "git push --force" >/dev/null 2>&1; RC=$?; [ "$RC" = "2" ] && ok "codex block exit code is 2" || bad "codex exit code $RC"
printf '{"tool_name":"apply_patch","tool_input":{"command":"*** Update File: .env\\n"}}' | run_adapter hooks/adapters/codex-pre-tool-use.sh >/dev/null 2>&1; RC=$?
[ "$RC" = "2" ] && ok "codex: apply_patch on .env denied" || bad "codex apply_patch .env rc=$RC"
printf 'this is not json' | run_adapter hooks/adapters/codex-pre-tool-use.sh >/dev/null 2>&1; RC=$?
[ "$RC" = "2" ] && ok "codex: unparseable payload blocked" || bad "codex unparseable rc=$RC"

echo "== AGY tool hook (.agents/hooks.json adapter)"
ag() { printf '{"toolCall":{"name":"%s","args":{"CommandLine":"%s"}}}' "$1" "$2" | run_adapter hooks/adapters/agy-pre-tool-use.sh; }
ag_deny() {
  local name="$1" cmd="$2"
  if ag run_command "$cmd" | grep -q '"decision":"deny"'; then ok "agy: $name"; else bad "agy: $name"; fi
}
ag_deny "force push -> deny JSON" "git push --force origin main"
ag_deny "git push -f -> deny JSON" "git push -f"
ag_deny "git push origin x -f -> deny JSON" "git push origin x -f"
ag_deny "--force-with-lease -> deny JSON" "git push --force-with-lease"
ag_deny "reading .env -> deny JSON" "type .env"
ag_deny ".env beside .env.example -> deny JSON" "cat .env .env.example"
ag_deny ".env.example2 is not a template" "cat .env.example2"
ag_deny "rm -rf -> deny JSON" "rm -rf build"
ag_deny "rm -fr -> deny JSON" "rm -fr build"
ag_deny "--no-verify -> deny JSON" "git commit --no-verify -m x"
printf '{"toolCall":{"name":"view_file","args":{"AbsolutePath":"/w/.env"}}}' | run_adapter hooks/adapters/agy-pre-tool-use.sh | grep -q '"decision":"deny"' && ok "agy: view_file .env -> deny JSON" || bad "agy view_file .env"
ag run_command "ls" | grep -q '"decision"' && bad "agy: ls wrongly denied" || ok "agy: harmless command allowed"
ag run_command "cat .env.example" | grep -q '"decision"' && bad "agy: .env.example wrongly denied" || ok "agy: .env.example allowed"
printf 'this is not json' | run_adapter hooks/adapters/agy-pre-tool-use.sh | grep -q '"decision":"deny"' && ok "agy: unparseable payload denied" || bad "agy unparseable"

run_hidden_parser_cases() {
  local tag="$1"
  expect_fail "$tag codex: git push --force denied" cx "git push --force origin main"
  expect_fail "$tag codex: git push -f denied" cx "git push -f"
  expect_fail "$tag codex: git push origin x -f denied" cx "git push origin x -f"
  expect_fail "$tag codex: --force-with-lease denied" cx "git push --force-with-lease"
  expect_fail "$tag codex: rm -rf denied" cx "rm -rf build"
  expect_fail "$tag codex: rm -fr denied" cx "rm -fr build"
  expect_fail "$tag codex: --no-verify denied" cx "git push --no-verify"
  expect_fail "$tag codex: reading .env denied" cx "cat .env"
  expect_fail "$tag codex: .env beside template denied" cx "cat .env .env.example"
  expect_ok   "$tag codex: harmless command allowed" cx "ls -la"
  expect_ok   "$tag codex: .env.example allowed" cx "cat .env.example"
  cx "git push --force" >/dev/null 2>&1; RC=$?
  [ "$RC" = "2" ] && ok "$tag codex block exit code is 2" || bad "$tag codex exit code $RC"
  ag_deny "$tag force push -> deny JSON" "git push --force origin main"
  ag_deny "$tag git push -f -> deny JSON" "git push -f"
  ag_deny "$tag flag-after-args -> deny JSON" "git push origin x -f"
  ag_deny "$tag rm -rf -> deny JSON" "rm -rf build"
  ag_deny "$tag rm -fr -> deny JSON" "rm -fr /var/tmp/build"
  ag_deny "$tag --no-verify -> deny JSON" "git commit --no-verify -m x"
  ag run_command "ls" | grep -q '"decision"' && bad "$tag agy: ls wrongly denied" || ok "$tag agy: harmless command allowed"
  printf 'this is not json' | run_adapter hooks/adapters/codex-pre-tool-use.sh >/dev/null 2>&1; RC=$?
  [ "$RC" = "2" ] && ok "$tag codex: unparseable payload blocked" || bad "$tag codex unparseable rc=$RC"
  printf 'this is not json' | run_adapter hooks/adapters/agy-pre-tool-use.sh | grep -q '"decision":"deny"' && ok "$tag agy: unparseable payload denied" || bad "$tag agy unparseable"
}

echo "== tool hooks with jq hidden"
NOJQ="$TMP/path-nojq"
build_path_excluding "$NOJQ" jq
if PATH="$NOJQ" command -v jq >/dev/null 2>&1; then
  bad "jq still visible after hiding"
else
  ok "jq hidden from adapter PATH"
fi
HOOK_PATH="$NOJQ"
run_hidden_parser_cases "nojq"
HOOK_PATH=""

echo "== tool hooks with jq and python hidden"
SEDONLY="$TMP/path-sedonly"
build_path_excluding "$SEDONLY" jq python python3
if PATH="$SEDONLY" command -v jq >/dev/null 2>&1 || PATH="$SEDONLY" command -v python3 >/dev/null 2>&1 || PATH="$SEDONLY" command -v python >/dev/null 2>&1; then
  bad "jq or python still visible in sed-only PATH"
else
  ok "jq and python hidden from adapter PATH"
fi
HOOK_PATH="$SEDONLY"
run_hidden_parser_cases "sedonly"
HOOK_PATH=""

echo "== Codex execpolicy rules (needs the codex binary)"
if command -v codex >/dev/null 2>&1; then
  codex execpolicy check --pretty --rules .codex/rules/studio.rules -- git push --force origin main | grep -q forbidden && ok "codex execpolicy: force push forbidden" || bad "codex execpolicy"
else
  echo "  SKIP  codex binary not installed here - rules file is syntax-checked only"
  python3 -c "import ast,sys;ast.parse(open('.codex/rules/studio.rules').read())" && ok "studio.rules parses (Starlark is a Python subset)" || bad "studio.rules syntax"
fi

echo; echo "RESULT: $PASS passed, $FAILN failed"
[ "$FAILN" = 0 ]
