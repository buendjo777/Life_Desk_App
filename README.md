# Desk for Mac

A native macOS command centre: **Today, Studying, Projects, Internship apps, Uni apps, Tutoring, Health, System.** It reads a private Obsidian vault (`jose-brain`) that cloud agents update every night, plus the Mac calendar. It ships with `demo-vault/`, fully invented data.

- **Spec:** `SPEC.md` · **Design:** `DESIGN.md`, `design/mockup/` · **Build rules:** `CLAUDE.md`
- **Status:** specified, not built yet.

## Requirements
- macOS 14 or later, Apple silicon.
- Xcode installed and selected: `xcode-select -p` should print a path inside `Xcode.app`.

## Start the build session
Open Claude Code on the Mac in this folder and paste:

> You're the build session for Desk for Mac. This folder must be a clone of github.com/buendjo777/Life_Desk_App: if it isn't, clone the repo here; if it is, run `git pull`. Then follow CLAUDE.md: read SPEC.md, DESIGN.md and the mockups in design/mockup/, and build the whole app in one go, in the build order, against demo-vault/. Don't stop for approval between steps. Stop only for something only I can do, and tell me exactly what. When you're done, show me the screenshots of every tab.
