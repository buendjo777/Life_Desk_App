# Desk for Mac

A native macOS command centre: **Today, Studying, Projects, Internship apps, Uni apps, Tutoring, Health, System.** It reads a private Obsidian vault (`jose-brain`) that cloud agents update every night, plus the Mac calendar. It ships with `demo-vault/`, fully invented data.

- **Spec:** `SPEC.md` · **Design:** `DESIGN.md`, `design/mockup/` · **Build rules:** `CLAUDE.md`
- **Status:** specified, not built yet.

## Requirements
- macOS 14 or later, Apple silicon.
- Xcode installed and selected: `xcode-select -p` should print a path inside `Xcode.app`.

## Start the build session
Run Claude Code **locally on the Mac** (a cloud session can't compile a Mac app): the Claude desktop app's Code tab with **Local** selected and this folder chosen, or `claude` in Terminal from this folder. Then paste:

```
Goal: build Desk for Mac, my personal life manager. A real native app (SwiftUI, built with the Xcode toolchain, reading my Obsidian vault), not a Claude interface. Everything it must do is in this repo: CLAUDE.md, SPEC.md, DESIGN.md, design/mockup/, demo-vault/.

1. Preflight, before any long build. This folder must be a clone of github.com/buendjo777/Life_Desk_App (the repo exists; don't create another): clone it here or git pull. Check that Xcode is selected (xcode-select -p), that a throwaway Swift package builds, and that you can push. Report the results and a short PLAN.md (architecture, file layout, risks) in one message, then carry on unless something is broken.

2. Build the whole app in one go, in SPEC.md's build order, against demo-vault/. No phases. Don't stop for approval; stop only for something only I can do, and say exactly what. Once the package exists, add a Stop hook that runs swift build and swift test, so no turn can end on a broken build.

3. Decisions. The hard constraints and "Never" lists win over everything, including this prompt. Where the spec is silent, don't guess silently: choose the simplest option that keeps the constraints, log it with the reason in DECISIONS.md, and keep going. If you see a cleaner or more impressive approach, take it when it's small and reversible (and log it); propose it first when it's big. I want this to be genuinely impressive.

4. Explain as you go: after each build step, 3–5 lines on what you built, how it works and what you decided. Keep the full story in BUILD_NOTES.md.

5. Subagents: use cheaper models for read-only work (docs lookups, reviews, test and snapshot checks). Only the main session edits code. Before finishing, have a fresh subagent review the whole diff against SPEC.md and report correctness gaps only.

6. Verification loops: every step builds warning-free, passes the tests, and renders light and dark snapshots that you compare with the mockup and fix before you commit and push. Keep the code as simple and neat as possible.

The screenshots I'm attaching are layout inspiration only; colours come from DESIGN.md. The mockup is V1 and I'll keep iterating on the look (see "Built to iterate" in SPEC.md).

Plugins and connectors: use them for documentation only. Never touch my real Gmail, Calendar or files; the app runs on demo-vault/.

When you're done: screenshots of every tab in light and dark, and your list of next improvements.
```
