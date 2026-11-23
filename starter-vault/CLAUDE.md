# This folder is a Desk vault

Desk for Mac (github.com/buendjo777/Life_Desk_App) shows what is in these plain text files. If you are an AI
assistant helping the owner set it up: ask what they study, their projects and their deadlines, then write
the files below. Keep to these formats exactly; Desk ignores what it cannot parse. Working examples of every
file are in `demo-vault/` in the repository.

## Files
- `desk/settings.json`: `{"name": "Ana", "currency": "EUR", "exam": {"title": "Physics", "file": "study/physics.md"}}`.
  `exam` is optional and points at the study file.
- `TASKS.md`: `## Section` headings, then `- [ ] Task 📅 2027-01-31`. The date is optional. `- [x]` is done.
- `projects/<name>.md`: front matter `title`, `status` (`active`, `waiting`, `frozen` or `idea`), `next`,
  optional `next_date: 2027-01-31`; then a checklist of `- [ ]` steps.
- `study/<name>.md`: front matter `exam`, `date` (2027-01-31 or 2027-01-31T10:30:00+01:00), `plan_per_day`,
  `plan_start`, optional `counts: Sheets = Sheet, Videos = Video` (an extra count per pair: list lines starting
  with that word). Sections `## Theory`, `## Problems` and `## Past papers` hold checklists. Any other
  `## Title — due 2027-01-31` section is a to-do list with a due day; `### Group` splits it; `· 60 min` at the
  end of a line is a duration. A finished paper reads `- [x] June 2025 — 2027-01-12 — 7/10`.
  `## Review` holds concepts to practise through the papers: a checkbox each, indented bullets as notes; it
  shows first and never counts towards progress.
- `uni/<name>.md`: front matter `title`, then a checklist of application steps.
- `internships/board.json`, `contacts/board.json`, `tutoring/`: copy the shape from `demo-vault/`.

## Rules
- Never put passwords, tokens or other people's private details in this folder.
- Never write to `agent/`.
- Tabs with no file stay empty; the owner hides them in Customise (⌘K → Tabs).
