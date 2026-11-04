# WO_CODEX_UNITY_GAME_STUDIO — พอร์ตระบบ Claude-Code-Game-Studios ให้ Codex และ AGY ใช้ได้ (ฉบับแก้ 2026-11-04 15:13)

> ผู้สั่ง: C- (สั่งด้วยเสียง 2026-11-04 15:02 น. แก้ทิศทาง 15:09 น. และ 15:13 น. เวลาไทย) | ผู้เขียน: N (NODUS)
> ผู้ทำ: Claude Code บนคลาวด์ · เครดิตคงเหลือจริง $82 · ใช้ $10–20 สำหรับงานนี้ · หลังจบงานจะเหลือ ~$62–72 เก็บไว้ทำงาน QUARMICUS จริง
> Repo: `limbicsys-game-studio` = https://github.com/Limbicss/LimbicsysGameStudios (ใน repo มีระบบ Donchitos v1.2.0 ครบอยู่แล้ว ซึ่งคือต้นทาง)
> กันพลาด: ห้ามลบหรือทำลายต้นฉบับ `.claude/` · ห้ามแตะ QUARMICUS main · ห้ามอ่าน/ใส่ key, token, .env · ห้ามเขียนลง F:\QUARMICUS-q-stage-v1 · ถ้าเครดิตใกล้ $20 ให้หยุดแล้วรายงาน

## ทิศทาง
- เก็บระบบเดิมไว้ครบ: เอเจนต์ 49 ตัว คำสั่ง 74 ตัว โครงสร้าง 3 ชั้น สคริปต์ตรวจ และแม่แบบเอกสาร
- พอร์ตให้ไม่ผูกกับ Claude Code อย่างเดียว เป้าหลักคือ **Codex** และ **AGY (Antigravity)** เพราะ C- มีโควต้าของสองตัวนี้เยอะ
- แปลงไวยากรณ์เฉพาะของ Claude (slash commands, agent frontmatter, hooks ใน settings.json) ให้เป็นของที่ Codex และ AGY ใช้ได้เอง ตรวจรูปแบบไฟล์จากเอกสารทางการของทั้งสองตัวก่อนแปลง แล้วระบุลิงก์ที่ใช้
- ให้คงกฎเขียนโค้ด Unity, การตรวจก่อน commit/push และกฎรันเกมแล้วถ่ายภาพหน้าจอก่อนปิดงานไว้
- โครงเดิม `.claude/` ยังอยู่ที่เดิม ส่วนของใหม่ให้เพิ่มคู่ขนาน

## Tasks (each task ends with `reports/T<n>.md`, ≤ 15 lines)

### T1 — Map the source + target formats
- Inventory `.claude/` (agents, skills, hooks, rules, templates, settings.json, CLAUDE.md).
- Look up from official docs: Codex (AGENTS.md, skills/prompts, config.toml, hooks if supported) and AGY/Antigravity (rules, workflows, agent config).
- Output: `port/MAPPING.md`, a table from each Claude concept to its Codex equivalent and its AGY equivalent, with a "no native equivalent, how we handle it" column.
- Accept: every concept is covered; doc links are cited; `reports/T1.md`.

### T2 — Port agents + commands (49 agents, 74 commands)
- Generate Codex versions (e.g. `AGENTS.md` index + `.codex/` or `.agents/skills/` files) and AGY versions (e.g. `.agent/rules/`, `.agent/workflows/`) from the originals. Prefer a script `port/convert.py` over hand-copying, so it can be rerun after upstream updates.
- Keep the 3-tier hierarchy and escalation rules as text the agents read.
- Accept: all 49 agents and 74 commands exist for both targets (the count is checked by the script); no Claude-only syntax is left in the ported files; `reports/T2.md`.

### T3 — Port hooks: commit/push checks + safety
- Make `validate-commit` / `validate-push` (and the other checks that still matter) work without Claude hook events: as git hooks (`hooks/` + `git config core.hooksPath hooks`) usable by Codex and AGY on Windows Git Bash, plus Codex native hooks where docs support them.
- Accept: `tests/hooks_test.sh` with one bad commit (blocked) and one good commit (passes); force push is blocked; reading `.env` is denied in both tools' config where supported; `reports/T3.md`.

### T4 — Unity rules + run-and-screenshot rule
- Port the path-scoped Unity coding rules (`Assets/**/Gameplay/`, `Assets/Tests/`, data JSON, etc.) for both targets.
- Port the rule that a story touching anything the player sees is not done until the game has been run and a screenshot saved in `production/qa/evidence/`.
- Accept: both rules are loaded by Codex and by AGY (show where); default `modes.rigor: minimal`; `reports/T4.md`.

### T5 — Templates, settings, final report
- Keep the 62 document templates and `project.yaml` usable from Codex/AGY (only fix paths).
- `REPORT.md`: what was ported, what has no equivalent, the credit used (≤ $20), and how to use it from Codex and from AGY (one example command each).
- Commit on a branch `port/codex-agy`, push it, and open a PR to main. Do not merge; C- reviews it.
- Accept: credit ≤ $20; the PR exists; `reports/T5.md`.

## Done when
T1–T5 pass, the credit used is ≤ $20, and every task has its report. C- reviews before anything goes into QUARMICUS.
