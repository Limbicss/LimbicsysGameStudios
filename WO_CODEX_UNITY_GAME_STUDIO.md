# WO_CODEX_UNITY_GAME_STUDIO — สร้างระบบสตูดิโอเกมของเราเอง (ฉบับแก้ 2026-11-04 15:09)

> ผู้สั่ง: C- (สั่งด้วยเสียง 2026-11-04 15:02 น. และแก้ทิศทาง 15:09 น. เวลาไทย) | ผู้เขียน: N (NODUS)
> ผู้ทำ: Claude Code บนคลาวด์ · เครดิตคงเหลือจริง $82 · ใช้ $10–20 สำหรับงานนี้ · หลังจบงานจะเหลือ ~$62–72 เก็บไว้ทำงาน QUARMICUS จริง
> ปลายทาง: repo `limbicsys-game-studio`
> กันพลาด: ห้ามพอร์ตหรือดัดแปลงกฎ ขั้นตอน หรือแม่แบบเอกสารของ Donchitos · ห้ามมีโครงเอเจนต์ 49 ตัวหรือคำสั่ง 74 ตัว · ห้ามแตะ QUARMICUS main · ห้ามอ่าน/ใส่ key, token, .env · ห้ามเขียนลง F:\QUARMICUS-q-stage-v1

## ทิศทาง
- สร้างระบบใหม่ทั้งหมดเป็นของเราเอง มีกฎของตัวเอง เขียนให้น้อย อ่านง่าย
- QUARMICUS เป็นเกม Unity และใช้ Official Unity plugin for Codex เป็นฐาน
- จาก Donchitos (https://github.com/Donchitos/Claude-Code-Game-Studios) ให้ดูได้แค่ "จุดที่นักพัฒนาควรเตือนตัวเอง" คือ (1) รันเกมแล้วถ่ายภาพหน้าจอก่อนปิดงาน (2) ตรวจก่อน commit/push แล้วเขียนใหม่ในแบบของเรา ห้ามก๊อปข้อความหรือโครงสร้างของเขา
- ตั้งชื่อเอเจนต์ คำสั่ง และไฟล์ให้ C- อ่านแล้วเข้าใจทันที เป็นคำธรรมดา ไม่ใช้ศัพท์สตูดิโอ

## Tasks (each task ends with a short markdown report: `reports/T<n>.md`, ≤ 15 lines)

### T1 — Project skeleton + plain-language naming
- Create the repo layout (few folders only), plus `AGENTS.md` (Codex reads this first) and `NAMES.md` listing every agent/command/file in a one-line plain-language description.
- Max 3 roles total, named plainly (e.g. `builder`, `checker`, `planner`); no tiers.
- Accept: AGENTS.md ≤ 60 lines; every name is understandable without explanation; nothing copied from Donchitos; `reports/T1.md`.

### T2 — Our own short rules for Unity
- Write original `rules/unity.md` (≤ 40 lines): our own do/don't for Unity C# in QUARMICUS (data-driven values, no secrets in code, tests live in `Assets/Tests/`).
- Accept: original wording; no Donchitos text or structure; works for Codex with the Unity plugin; `reports/T2.md`.

### T3 — Self-warning: run and screenshot before closing
- Write `rules/before-done.md`: any change the player can see is not done until the game has been run (Play mode or build) and a screenshot saved to `evidence/<task>-<date>.png`. A passing test alone is not enough.
- Accept: ≤ 20 lines; it has a filename format and a one-line checklist; `reports/T3.md`.

### T4 — Self-warning: commit and push checks
- Write original git hooks `hooks/pre-commit` and `hooks/pre-push` (Git Bash on Windows): block key/token-like strings and `.env`, block invalid JSON, block force push, warn on push to `main`.
- Accept: a `tests/hooks_test.sh` with one bad case (blocked) and one good case (passes); install line `git config core.hooksPath hooks` in the README; `reports/T4.md`.

### T5 — Light process setting + final report
- `settings.yaml` ≤ 15 lines: light mode by default, working on its own without asking at every step, and asking C- only for push to main, merge, delete, install or spending money.
- `REPORT.md`: file list, the credit used (must be ≤ $20), and how to clone. Then stop.
- Accept: the whole repo stays small (no doc templates, no command catalog); credit ≤ $20; `reports/T5.md`.

## Done when
T1–T5 pass, the credit used is ≤ $20, and every task has its report. C- reviews before anything goes into QUARMICUS.
