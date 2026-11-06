# REPORT - Port of the studio system to Codex and Antigravity (WO_CODEX_UNITY_GAME_STUDIO)

Branch `port/codex-agy` -> PR https://github.com/Limbicss/LimbicsysGameStudios/pull/1 to `main` (open, not merged; C- reviews). Per-task reports: `reports/T1.md` ... `T5.md`. Mapping + doc links: `port/MAPPING.md`.

## What was ported (verified by `python3 port/convert.py --check` and `bash tests/hooks_test.sh`)
| Original (`.claude/`, untouched) | Codex | AGY |
|---|---|---|
| 49 agents | `.codex/agents/*.toml` (49) | `.agents/agents/*.md` (49) |
| 74 skills ("commands") | `.agents/skills/` (74, call `$name`) | same folder (74, call `/name`) |
| 14 path rules (Unity globs incl.) | table in `AGENTS.md` | `.agents/rules/` (14, `trigger: glob`) |
| CLAUDE.md essentials, 3-tier hierarchy, escalation, run-and-screenshot rule | `AGENTS.md` | `AGENTS.md` |
| commit/push/safety hooks | `hooks/` git hooks + `.codex/hooks.json` + `.codex/rules/studio.rules` | `hooks/` git hooks + `.agents/hooks.json` |
| 64 templates, `project.yaml`, scripts | unchanged, same paths (all 104 path references in ported files resolve except 1 upstream bug) | same |
`modes.rigor: minimal` pinned in `project.yaml`.

## No native equivalent (handled in text or left out) - details in MAPPING.md
Per-agent tool limits and `maxTurns` (advisory text), `!cmd` auto-injection ("Run first" lines), `AskUserQuestion` (numbered options in chat), Codex path-scoped rules (routing table),
Write/Edit/Read guard hooks, session logging / pre-compact / notification hooks, statusline, worktree setting. AGY workflows skipped: legacy, replaced by skills.

## Not verified
Nothing was run inside real Codex or Antigravity (no binaries/accounts in the build sandbox). Unverified: hook trust flow, rules loading, hyphenated agent names in TOML, AGY glob matching,
`commandExecutionPolicy: off`, skill names that collide with built-in slash commands, `.agents/hooks.json` working directory. First run in each tool should check these.
`codex execpolicy check` was skipped (no codex).

## Findings for C-
1. Work order said 62 templates; the repo has 64. 2. `/patch-notes` references a template that does not exist upstream (`patch-notes-template.md`). 3. OpenAI docs moved to learn.chatgpt.com.
4. Engine is still unset in `CLAUDE.md` (Godot reference only); a "Unity" studio needs `/setup-engine` first - not done here (owner decision).
5. `pre-push` also blocks direct pushes to main/master (original only warned); owner override is `PORT_ALLOW_PROTECTED_PUSH=1`.

## Credit used
Cannot be measured from inside the session (no billing tool). Estimate from work done: ~45 tool calls, no subagents, no long outputs, all file work local -> well under the $20 cap, likely a few dollars. **Unverified estimate; check the console.** Stop rule not triggered.

## How to use
Setup once per clone (Git Bash ok): `bash hooks/install.sh`   Regenerate after upstream changes: `python3 port/convert.py && python3 port/convert.py --check`

Codex (trust the project's `.codex/` layer, review hooks with `/hooks`):
```bash
codex exec 'Use the $project-stage-detect skill and report the project stage'
```
Antigravity: open the repo folder, then in the agent panel type:
```text
/project-stage-detect
```
