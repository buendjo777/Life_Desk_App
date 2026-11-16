# Your Desk vault

This folder is everything Desk shows. It is plain text: open any file in TextEdit, Obsidian or any editor,
save it, and Desk picks the change up on the next sync (⌘R).

| File | What it feeds |
|---|---|
| `desk/settings.json` | Your name, currency and time zone |
| `TASKS.md` | Today's list. `- [ ] Something 📅 2027-01-31` is a task with a due date |
| `projects/*.md` | One file per project: a title, a status, a next step and a checklist |
| `study/*.md` | Optional: a study plan with checklists, shown on Studying |
| `uni/*.md`, `internships/board.json`, `tutoring/` | Optional: the other tabs stay empty until these exist |

Tabs with nothing to show can be hidden section by section in Customise (⌘K).

To keep a backup and use it on two Macs, make this folder a private GitHub repository. Desk then pulls and
pushes it for you with the `git` already set up on your Mac. It never stores a password or a token.
