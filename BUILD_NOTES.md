# Build notes

The story of the one-session build, step by step: what was built, how it works and what was decided. Decisions with their reasons are in `DECISIONS.md`.

## Preflight
- The repo was cloned and pulled; Xcode 26.6 is selected; a throwaway Swift package built and rendered a SwiftUI view to PNG offscreen; a push to `main` worked.
- The session folder is the parent of the clone, so the Stop hook is installed for both.

## Step 1 — package, build script, app shell
- **Built:** `Package.swift` (one executable target, a test target, warnings as errors), `scripts/build-app.sh`, `scripts/Info.plist`, the window with a hidden title bar, the floating sidebar, tab routing and ⌘1–⌘8, and `Theme.swift` with every DESIGN.md token.
- **How it works:** `Main` checks for `--render-snapshots`; otherwise it starts the SwiftUI app. `RootView` reads the colour scheme, builds a `Theme` and puts it in the environment, so every view below reads tokens from one place. `WindowChrome` moves the real traffic lights onto the sidebar.
- **Decided:** tokens in the environment instead of system dynamic colours; a single `Window`; stand-in traffic lights in snapshots (decisions 1–8).
- **Checked:** the sidebar snapshot matches the mockup's sidebar in light and dark.

## Step 2 — models, parsers, clock, mode switch
- **Built:** `Models.swift` (the data contract), `Parsers.swift` (pure parsers for JSON, JSON Lines, front matter, checkboxes, tables, CSV and notes), `Vault.swift` (reader and loader), `Derived.swift` (today's lists, deadlines, run status, the summary sentence), `Preferences` and the real `Store`.
- **How it works:** `VaultReader` reads a file from an in-memory overlay first, then the disk. `VaultData.load` parses everything and turns a missing or malformed file into a one-line hint. `Derived(data:now:)` is a plain value, so the clock is just a parameter: Demo passes `demo_today`, Live passes the real time.
- **Decided:** lossy arrays, date-only values in the vault's zone, the master doc wins for programme deadlines, the Due-tab count follows the spec not the mockup (decisions 9–15).
- **Checked:** 34 tests: every parser against `demo-vault/`, malformed input, an empty vault, the run-status rule at its edges, exam mode.

## Step 3 — Today
- **Built:** the stat cards (Deadlines with the 90-day runway, Today with the 07:00–22:00 strip, Inbox, Health), Today's list (Focus · Due · Leftovers), Important emails, Drafts, Waiting, the right rail (month calendar, Needs confirmation, timeline), the search bar with scopes, the status chip and round buttons, and the inspector for rows and tasks.
- **How it works:** `TabLayout.sections(for:)` lists the tab's sections once; `SectionFlow` packs them into rows. `Derived+Today.swift` computes the runway, strip blocks, month grid and search hits as plain values. Ticks and Add/Dismiss go through the `Store`, which in Demo writes to an in-memory overlay and reloads through the same parsers.
- **Decided:** where Drafts and Waiting live, the demo sync time, snapshot stand-ins for scroll views, width-packed sections (decisions 16–19).
- **Checked:** light and dark snapshots against the mockup: cards, counts, calendar dots, confirm card and timeline line up. This step was interrupted by a usage limit and finished in a second session (compile fixes, the day-strip offset, the sync box).

## Step 4 — Studying
- **Built:** the ochre hero (countdown, theory/problems/papers counts, overall ring), today's target, the Theory and Problems columns with ticks, the steel plan chart (done against the plan line) and the past-papers list with score chips. An empty state when no exam is set.
- **How it works:** `Derived+Studying.swift` computes progress, `plannedPapers(by:)`, the chart series and the target. Ticks call `Store.toggleCheck`, the same path as `TASKS.md`.
- **Decided:** ticks instead of per-topic bars, the overall formula, the target rule (decisions 20–22).
- **Checked:** snapshots in light and dark; a test pins the numbers at the demo clock and on later days.

## Step 5 — Projects
- **Built:** the four board columns (Active, Waiting, Frozen, Ideas) with count chips and compact cards (next step, date, sub-item progress), and the project inspector: next step, tickable checklist, the linked `nini/` doc, Open in Obsidian and Open in Claude.
- **How it works:** `MarkdownView` is the only place Markdown is parsed, and it only ever receives `nini/` text; a test scans the sources for Markdown APIs anywhere else. The Claude seed names the file path only.
- **Decided:** columns as sections; a tiny built-in Markdown renderer (decisions 23–24).
- **Checked:** board and inspector snapshots (an extra `inspector-*.png` pair is rendered with a project open).

## Step 6 — Internship apps
- **Built:** count cards per status, the table with Apply now · All targets, rows with company, role, city, next step, days-left and status chips, the target inspector, and the Open board button (the only thing shown when `internships/targets.json` is absent).
- **Decided:** four count cards as in the design (decision 25).
- **Checked:** snapshots; counts pinned by a test.

## Step 7 — Uni apps
- **Built:** the deadline runway across programmes with a today marker, the steel programme cards (days left, checklist progress, status, next item), the programme inspector with its section of the comparison doc and a tickable checklist, and the Contacts Board (counts by status, list, inspector) or an Open board button.
- **How it works:** deadlines come from the master doc via `comparison_heading`, with the snapshot row as fallback (decision 12).
- **Decided:** the status rule and the runway length (decisions 26–27).
- **Checked:** snapshots; days left, progress and the comparison section pinned by a test.
