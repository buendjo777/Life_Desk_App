# Decisions

Choices made where SPEC.md and DESIGN.md are silent or disagree. Each one is the simplest option that keeps every hard constraint. Newest last.

| # | Step | Decision | Why |
|---|---|---|---|
| 1 | 1 | Warnings are errors (`-warnings-as-errors` in `Package.swift`). | "Warning-free" is then enforced by the compiler, not by reading logs. |
| 2 | 1 | The package has one executable target plus a test target that imports it. | The spec asks for one executable target; tests need a target of their own and SwiftPM lets it import the executable. |
| 3 | 1 | One `Window`, not a `WindowGroup`. | Desk is a single-window app; this removes New Window and duplicate state. |
| 4 | 1 | The traffic lights are moved onto the sidebar by resizing the title-bar container from a small AppKit hook. | SwiftUI has no API for it and the design puts them on the sidebar. It is reapplied on resize. |
| 5 | 1 | Offscreen snapshots draw stand-in traffic lights. | `ImageRenderer` draws SwiftUI content only, not window chrome; the mockup shows the lights. |
| 6 | 1 | The Stop hook is installed twice: `.claude/settings.json` in the repo and `settings.local.json` in the parent session folder. | The build session was started in the parent folder; a session started in the repo uses the committed one. |
| 7 | 1 | Theme tokens are a `Theme` value in the SwiftUI environment, not dynamic system colours. | The colour scheme and density then resolve the same way on screen and in offscreen snapshots. |
| 8 | 1 | Spacing tokens are named by their Compact value (`sp8`, `sp12`…). Comfortable scales them by 1.25. | Short, predictable names on the 8-point grid. |
| 9 | 2 | The demo vault is found inside `Desk.app` first, then in the repo (from the source file's path). | SwiftPM cannot bundle a folder outside the target; this keeps `swift run`, the tests and the app on one copy. |
| 10 | 2 | A bad element in a JSON array is skipped; the rest of the file still loads. A file that is not an array at all gives the empty state. | "Never a crash", and one bad row from the agent should not blank a tab. |
| 11 | 2 | A date without a time (`2026-12-15`) means that day in `settings.timezone`. `2026-11-30 11:59 CET` in the master deadlines doc is read as wall-clock time in that zone; the zone letters are ignored. | Days-left are counted in calendar days in Jose's zone; abbreviations like CET are ambiguous. |
| 12 | 2 | A programme's deadline comes from `nini/masters-deadlines-2027.md` when a `uni/` file links the row; the snapshot row is the fallback. | The spec says that doc "stays the master". |
| 13 | 2 | The Due tab lists tasks due today minus Focus titles (1 in the demo), while the Today card and the sentence count every task due today (4). The mockup shows "Due 4". | The spec defines the Due tab that way; a tab count that disagrees with its own list would be a bug. |
| 14 | 2 | Run status uses the snapshot's `run` row (time and mode); `runs.jsonl` is the fallback. | The web Desk reads the same row, so both show the same colour. |
| 15 | 2 | Live is chosen automatically when the vault folder exists and "Use the live vault" is on (the default); otherwise Demo. | "Demo is the default until a live vault path is set and exists." |
| 16 | 3 | Drafts and Waiting are two short lists under Today's list; a click opens the row in the inspector. Both are hidden in exam mode. | The spec says they "open in the inspector" but not where the rows live; a list is the simplest entry point. |
| 17 | 3 | In Demo the sidebar says "Synced" two minutes before the pinned clock. | There is no sync in Demo; a fixed time keeps the demo looking the same, like the mockup. |
| 18 | 3 | Snapshot mode draws scroll views as clipped plain content anchored to the top. | `ImageRenderer` cannot draw `ScrollView`; clipping shows exactly the first screenful. |
| 19 | 3 | Sections carry a design width; a tab's sections are packed into rows by width and each row stretches to fill. | One list per tab drives both the layout and Customise, so reordering never needs layout code. |
| 20 | 4 | Topics are ticks, so each Theory and Problems column shows one progress bar and the topic checklist under it. | A bar per topic could only be empty or full; the column bar plus ticks says the same with less ink. |
| 21 | 4 | Overall progress counts theory ticks, problem ticks and past papers equally. | The spec asks for "overall progress" without a formula; an unweighted count is the simplest honest one. |
| 22 | 4 | Before `plan_start` today's target points at the next open theory topics; from then on it is the papers needed to reach the plan line. | The plan only defines papers per day from its start date. |
