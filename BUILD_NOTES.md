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

## Step 8 — Tutoring
- **Built:** the donut (received vs pending), the Received, Pending and Hours cards, Waiting for payment with Send reminder and Mark paid, Month end with Send on WhatsApp and Mark sent, this month per student, the payments table with status chips, this week's lessons in the rail and the student inspector with the last note.
- **How it works:** hours come from tutoring-calendar events whose title is a student's initials; amount is hours × rate. Messages fill `template.md` or `template-reminder.md` and format `{month}` in `tutoring_locale`; the wa.me link only opens WhatsApp, Jose presses send. Mark sent and Mark paid rewrite `payments.csv` through the store (memory only in Demo).
- **Decided:** decisions 28–31.
- **Checked:** snapshots; tests for the amounts, the Spanish month name, the link and that Demo leaves the file on disk untouched.

## Step 9 — Health
- **Built:** Sessions, Time and Distance cards for this week, the seven-day streak grid, 12-week bars and the activity list, all from `agent/exports/strava.json`.
- **How it works:** `Derived+Machine.swift` groups activities by ISO week in the vault's time zone. The summary says the data is as of the last run, not live.
- **Checked:** snapshots; week totals, streak and bars pinned by a test.

## Step 10 — System
- **Built:** the navy Latest run card (status, duration, scanned, drafts, usage note, the run-status word), the Models card (model → agents), the 14-day run strip with a word in every cell, and the run history with status chips, models, usage notes and failure lines.
- **How it works:** every string from `runs.jsonl` is drawn verbatim. The run-status rule is the one from step 2, shared with the chip and the sidebar.
- **Decided:** decisions 32–33.
- **Checked:** snapshots; the strip, models and failure log pinned by a test.

## Step 11 — Writes and decisions
- **Built:** `VaultWriter` (the allow-list and the disk write), `Git` and the `VaultGit` actor (one git operation at a time, off the main thread), and the store's save path for both modes. Clicks append to `desk/decisions.jsonl`.
- **How it works:** Demo edits go to an in-memory overlay that the reader checks before the disk. Live edits are written atomically, the view reloads, then the file is committed, the vault is rebased on the remote and pushed; any failure raises the banner. `tutoring/payments.csv` is written but never added to git.
- **Decided:** decisions 34–36.
- **Checked:** tests: the allow-list (including `..` and `agent/` tricks), Demo leaving the disk untouched, and a Live round trip against a throwaway bare repo in a temp folder: tick, decision and payment, then `agent/` byte-identical, `tutoring/` absent from git, HEAD equal to origin, and a broken remote raising the banner. The real vault was never touched.

## Step 12 — EventKit
- **Built:** `CalendarSource` and `EventKitCalendar`: full-access request, events around today, and Add, which creates an event with a title and times only. Demo keeps using `calendar/events.json` and adds proposed events in memory.
- **Decided:** decisions 37–38.
- **Checked:** by test with a fake calendar: Add passes only title, start and end. **Not verified:** the real EventKit path, because Live mode was not run on this Mac.

## Step 13 — Git sync, banner, Settings
- **Built:** sync on launch, every 15 minutes and on ⌘R (`git pull --ff-only`), the alert banner with Retry and Dismiss, the sidebar's sync line, the Settings window (vault path, Use the live vault, appearance, density), ⌘F for search and the Go menu.
- **How it works:** `Store.resolveMode()` picks Live only when the toggle is on and the folder exists; changing either setting switches at once.
- **Decided:** decision 39.

## Step 14 — Customise and density
- **Built:** View → Customise…: per tab, show or hide and reorder sections, Compact or Comfortable, Reset. Saved in `UserDefaults`.
- **How it works:** the panel edits `TabPrefs` (order and hidden ids); `TabLayout.arranged` applies them. Comfortable scales spacing by 1.25, makes rows 60 pt and shows fewer rows per list, all from `Theme.swift`.
- **Decided:** decisions 40–41.
- **Checked:** `customise-*.png` and `comfortable-*.png` snapshots; fixed week numbers, the now pill and sidebar labels wrapping in Comfortable; a test covers reorder, hide and reset.

## Step 15 — Portfolio
- **Built:** what the system does (navy), the evaluation card (missed-reply rate, or an honest "Not measured yet"), the architecture diagram, the agents and their models, the cost table and the failure log.
- **How it works:** `Store.showcase` is a second `Derived` loaded from the bundled demo vault at its pinned clock, so the screen is identical in Demo and Live and cannot show private data.
- **Decided:** decisions 42–44.
- **Checked:** light and dark snapshots.
