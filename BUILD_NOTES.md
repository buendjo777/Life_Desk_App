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

## Step 16 — icon, install, screenshots, README
- **Built:** the app icon (drawn by `Desk --render-icon`, packed by `iconutil`), the final `scripts/build-app.sh`, `design/screenshots/` (every tab in light and dark, plus the inspector, Customise and Comfortable density) and the README (build, Demo and Live, switching to the live vault, what is not verified).
- **How it works:** the script builds in release, assembles the bundle in a temporary folder, signs it ad hoc, verifies the signature and copies it to `~/Applications/Desk.app`.
- **Checked on screen:** the installed app was launched in Demo mode. The traffic lights sit on the sidebar, the tabs switch and the content scrolls. `ClickTests` sends real mouse events to the real view tree in an offscreen window: a click on an email row opens the inspector, a sidebar click switches tab, and Dismiss records the click in memory while the demo file on disk stays byte-identical.

## How the session went
- One session built steps 1 and 2 and most of step 3, then hit the usage limit. A scheduled run picked the build up from the repo notes and took it through step 15 and a first round of hardening (stale-file ticks, in-place CSV edits, the git timeout, verbatim VoiceOver labels) before hitting the limit too. The first session then came back, audited every tab against the mockup, fixed what was left, and finished step 16.
- Lesson: the notes in this file, `PLAN.md` and `DECISIONS.md` were enough for a fresh session to continue the same architecture without the conversation.

## Independent review
A fresh reviewer on a cheaper model read SPEC.md, CLAUDE.md and all the code, and reported correctness gaps only. It confirmed the hard constraints hold (no packages, no network beyond git and links, one write path, verbatim untrusted text, title-and-times-only calendar events, the run-status rule, the demo numbers) and found seven narrow gaps. All seven are fixed and pinned by tests (decisions 53–58):
1. The write allow-list could be spelled around (`./agent/…`, `Agent/…`, a symlinked folder).
2. A Live write queued behind a sync could land after a switch to Demo.
3. A date-only `mode_ends` ended exam mode at the start of that day.
4. An absurd `plan_per_day` could overflow; an absurd `plan_start` could build a huge chart.
5. The WhatsApp number kept non-ASCII digits.
6. The draft's Claude seed carried a file name built from the sender.
7. Open in Gmail was only in the inspector, not on the email list.

It also noted that Internship apps shows four count cards (Open, Applied, Interview, Rejected) while the spec says "counts per status"; that follows DESIGN.md and is decision 25.

## Not verified
- EventKit against the real Calendar, and Live sync against the real vault: never run, on purpose. The Live write path is tested against a throwaway local repository; calendar Add is tested with a fake calendar.
- The Settings window, the Customise sheet and the timeline filter popover were drawn offscreen but not operated on screen.

## 12 Nov — the vault's new layout
- **The vault was stuck.** The Obsidian Git plugin (backup every 10 minutes, merge pulls) had stopped mid-rebase at 23:11 on 11 Nov. Jose's rename of `nini/` to `Proyecto Nini/` collided with a cloud reorganisation into topic folders, and the next auto-backup was committed on top of the half-finished rebase. Fix: backup refs to both commits, `rebase --quit`, `main` moved to the newest backup, rebased onto the 4 cloud commits (no conflicts), pushed. Nothing was lost; the `Proyecto Nini/` copies were kept for Jose to decide.
- **Desk now leaves another tool's git work alone** (decision 66), with a test that simulates a stuck rebase.
- **Docs moved:** `nini/` is gone. Desk reads `Masters/Deadlines 2027.md`, `Masters/Programme comparison.md` (`###` headings) and each project's `doc:` path, with wikilinks shown as plain text (decisions 62–65, 67).
- **Agent and Strava:** the run is scheduled for 06:18 (already in the vault's settings). `scripts/desk.py` writes the sections and date format Desk parses. Strava is gone; Health shows its empty state.
- **Checked:** 68 tests; the project inspector renders `Research/AF detection.md` with its wikilink as plain text.

## 12 Nov — Classes importer and the first live check
- **Importer:** `Desk --import-classes [--dry-run]` (decisions 69–73), tested on invented notes. A test caught a real leak along the way: a possessive ("Bermúdez's") slipped past word-based redaction. Names are now matched as letter runs.
- **Blocked on one click:** the dry run waits for macOS's "Desk wants access to control Notes" prompt, which only works on the Mac itself. Two runs timed out while Jose was away.
- **The agent's first run** finished at 11:48 (ok: 1 run row, 11 deadlines, 3 focus items). It wrote and staged `agent/snapshot.json` and `runs.jsonl` but did not commit or push them; Desk leaves them alone.
- **Live check** (`LiveVaultCheck`, decision 74): Today reads "1 due today, 0 leftovers and 0 to confirm. 15 days to the exam, 18 to ETH. Last run 11:48, all green." All 10 uni files find their comparison section, all 8 project docs load, and no wikilinks are left. The ETH duplicate on the Deadlines card is fixed (decision 75).
- **Ticks reached GitHub:** between 11:30:39 and 11:31:19, Desk (reopened at 11:30) committed and pushed 12 ticks to `study/resis.md`, a net change of 4 checkboxes. That is the live write path working end to end; whoever was at the Mac should confirm the ticks were meant.

## 12 Nov — Desk reads the Classes note; History tab
- **Importer rewritten** around the note's real layout (decisions 76–80). A one-off script sorted the note first, so Jose could correct the rates. The Swift port reproduces that sort exactly; the only differences come from Jose's three corrections. Two lines are left to check: a family total with no lessons under it, and a student with two rates written.
- **Desk writes `tutoring/` itself** on launch and ⌘R. A backup was compared before the first write: `payments.csv` came out identical, and the archive gained the one row whose rate was unknown before.
- **History tab** (decision 82), with invented demo data in `demo-vault/tutoring/lessons.csv` that matches the demo payments and calendar.
- **Checked:** 80 tests (1 opt-in skipped), plus the live-vault check; History and Tutoring rendered in light and dark.

## 12 Nov — Studying: instant ticks and the weekend lists
- **Why ticks felt slow:** two causes, both measured. First, every tick was its own commit, pull and push, and later ticks queued behind it: ten quick ticks took 24 s to reach GitHub. Second, every tick re-read the whole vault on the main thread, at 100–200 ms each, mostly regex work on the Masters docs and new date formatters.
- **Fix** (decisions 86–88): ticks show at once, syncs wait for a 2-second pause, and only the changed file is re-read (about 2–3 ms). Docs are cached, formatters are shared, and checkboxes are matched by hand. `LiveVaultCheck` now prints these timings.
- **Lists** (decisions 84–85): the study file's own `##` lists appear in Studying, and today's target paces them to their due day. The real weekend lists live in the private vault; the demo vault has an invented one.
- **Checked:** 83 tests (1 opt-in skipped), including a test that two ticks during a running sync show at once and land in one commit and one push. Studying rendered in light and dark.

## 13 Nov — Tutoring matches History; the target board's format
- **Tutoring** (decisions 89–90): names, the full payment archive, this year's money in place of "this month's", and the week from the note's lesson dates.
- **Internship apps** (decisions 91–92): reads the board's own export. The first export waits for claude.ai's artifact store, which was down (HTTP 502) when this was built.
- **Found while checking the tabs:** the "Morning Desk" routine that feeds Today and System is disabled, so the last run is Thursday's. The "daily" internship scan runs on Mondays only.
- **Checked:** 84 tests (1 opt-in skipped).
- **First run since Thursday** (Morning Desk turned back on, 13 Nov 12:03): the board export worked, with 199 openings and 89 targets, and System is green. Email and calendar were skipped: the repo's deny rules did not load in the routine's session, so the skill left them out on purpose. The run did not commit, because Jose's own notes had uncommitted changes; Obsidian Git's backup commits them all.

## 13 Nov — Today's study items, card filters, runway lanes, stable signing
- Decisions 94–97. Checked live: Today shows today's 7 study items; the Rejected card lists the two rejected applications with their links; the Uni runway shows ten deadlines with no label on top of another.
- **Email:** the morning run moved from a Cowork task, which never loads the vault's `.claude/` (its deny rules, hook and agents), to a cloud routine that clones jose-brain. In the cloud routine the deny rules load, and the injection eval passed: 61 checks, 0 failed.
- **Checked:** 85 tests (1 opt-in skipped).

## 13 Nov — Self-contained internships, student details, past papers
- Past papers: the 16 May and June sittings (2017–2025) are listed newest first in the study file. From Monday, today's papers can be ticked on Studying and Today (decision 98).
- Internships (decision 99): 199 openings and 89 targets moved into `internships/board.json`. A new Monday scan routine replaces the Cowork one, and the morning skill no longer exports the board, so the injection eval was re-run for the new skill version.
- Student details, the timed Classes import and hidden Health: decisions 100–102. `finance/` is gitignored, ready for a Revolut statement export.
- **Checked:** 88 tests (1 opt-in skipped).

## 14 Nov — Refactor, a living backdrop, three palettes
- **How it was decided:** three reviewers ran first, on cheaper models: a design voice (palettes and motion), a risk voice (eight ways it could go wrong) and a code audit (25 refactor items). A fourth reviewed the first screenshots and judged them "not premium yet"; its main fix (darker glass, lighter tints) is in. Decisions 103–109.
- **Refactor:** done on a separate branch by a helper while the visual work went on, then merged with no conflicts. 88 tests before and after.
- **Not done:** `Store.swift` is still one file (decision 108). The "show 30 more" pattern is still repeated in eight lists.
- **Checked:** 88 tests (1 opt-in skipped); every tab rendered in light and dark; the installed app idles at 0% CPU when it is not the active window.

## 14 Nov — Calmer look, slim sidebar
- Decisions 110 and 111: no stripes, two hues, white pills, neutral stat cards, and a sidebar rail that opens on hover.
- **Checked:** 88 tests (1 opt-in skipped); every tab rendered in light and dark.
