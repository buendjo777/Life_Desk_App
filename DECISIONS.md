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
| 23 | 5 | Each board column is its own section, so Customise can reorder or hide columns. | Falls out of the one-list-per-tab layout; no extra code. |
| 24 | 5 | Markdown is rendered by one small view (headings, bullets, table rows, paragraphs, inline styles) and only for `nini/` docs. | No third-party parser is allowed, and a single file keeps the "untrusted text stays text" rule checkable by a test. |
| 25 | 6 | The count cards are Open, Applied, Interview and Rejected (DESIGN.md); Offer and Watching targets still show in the table with their status chip. | The design names four cards; the data contract has six statuses. |
| 26 | 7 | A programme is "Submitted" when its Submitted item is ticked, "Not started" with no ticks, otherwise "In progress". | The spec asks for a status but `uni/*.md` has no status field; the checklist already says it. |
| 27 | 7 | The Uni runway covers 90 days, or more when the last programme deadline is later. | A fixed 90 days could push a real deadline off the line. |
| 28 | 8 | "This month" counts lessons that have already ended; the month's planned hours are shown next to them. | Billing lessons that have not happened yet would overstate the amount. |
| 29 | 8 | The donut compares money received this month (by paid date) with everything sent and still unpaid. | It answers "what came in, what is still owed" on one ring. |
| 30 | 8 | Month end lists a finished month when a row has no sent date, or when the calendar has lessons and `payments.csv` has no row; Mark sent writes the row with today's date. | The spec says "a finished month not yet sent" without saying where the figures come from; the calendar is the source for hours. |
| 31 | 8 | Tutoring has no Open in Claude button, and the tab shows initials only. | "No seed for anything about money"; names live only in `contacts.json` and are read only to fill a WhatsApp message. |
| 32 | 9 | The 12-week bars show training time per week; the streak grid is the current week, Monday to Sunday. | Time compares runs, rides and strength on one axis; distance does not. |
| 33 | 10 | A day in the 14-day strip is "Fail" when any run that day failed or aborted; an ok run that logged a failure line gets an amber icon in the history. | A partial failure should stay visible without turning a successful day red. |
| 34 | 11 | One allow-list (`VaultWriter.isWritable`) decides what Desk may write: `TASKS.md`, the study file, `uni/*.md`, `desk/decisions.jsonl`, `tutoring/payments.csv`. Project checklists are shown but read-only. | The spec's write list does not include `projects/`; a single function makes "never write `agent/`" a tested fact. The same rule applies in Demo so both modes behave alike. |
| 35 | 11 | A Live write saves the file first, then queues `commit`, `pull --rebase --autostash`, `push`; a failed rebase is aborted. | The tick is never lost; `--autostash` lets Jose's own unsaved Obsidian edits coexist; an aborted rebase leaves the vault clean, and the banner says the sync failed. |
| 36 | 11 | Each write is its own commit of that one file ("Desk: tick in TASKS.md"). | Small commits rebase cleanly against the agent's nightly push. |
| 37 | 12 | Live loads events from 62 days back to 120 days ahead and adds new events to the default calendar. | Enough for last month's tutoring hours and the deadline runway without scanning the whole calendar. |
| 38 | 12 | Calendar access is asked for on the first Live sync; if refused, the timeline shows where to turn it on. | Demo must never trigger the permission prompt. |
| 39 | 13 | Settings uses standard macOS form controls. | A Settings window should look like one; theme tokens style the main window. |
| 40 | 14 | Customise reorders with up and down buttons, and hidden sections stay in the list with a crossed eye. | Simpler and more accessible than drag and drop, and nothing disappears from the panel. |
| 41 | 14 | The sidebar's insets do not scale with density. | The sidebar keeps its 232 pt width, so scaled insets truncated "Internship apps". |
| 42 | 15 | The Portfolio screen always loads the bundled demo vault itself, even in Live mode, and is reached from System, the Go menu and ⌘9. | "Never reads the live vault"; it is a ninth screen, so it stays out of the eight sidebar tabs. |
| 43 | 15 | The evaluation result and the thesis link come from an optional `desk/portfolio.json` (`evaluation {missed_reply_rate, sample, note}`, `thesis_url`); without it the card says "Not measured yet". | Neither exists yet, and a showcase must not invent a result. |
| 44 | 15 | The cost table lists the spec's zero-cost facts and quotes the agent's latest usage note. | Those are the only cost facts the repo holds. |
| 45 | 16 | The icon is drawn by the app (`--render-icon`) from theme colours and packed by `iconutil` in the build script. | No binary asset to keep in sync with the palette, and no extra tools. |
| 46 | 16 | `build-app.sh` assembles and signs the bundle in a temporary folder, then copies it to `~/Applications`. | The repo sits in an iCloud-synced folder, which adds Finder attributes that make `codesign` refuse the bundle. |
| 47 | 16 | A Live edit re-reads the file and finds its checkbox again by title before writing; if the item is gone or ambiguous nothing is written and a banner says so. | Obsidian or the nightly agent may have changed the file since Desk read it; a tick must never land on a different item. |
| 48 | 16 | Marking a payment sent or paid rewrites only that row of `payments.csv`. | Lines Desk cannot parse (notes, odd rows) are Jose's and must survive. |
| 49 | 16 | Sync falls back to rebase and push when the clone is ahead of the remote. | After a failed push a fast-forward pull is impossible, and the unpushed tick would sit there for ever. |
| 50 | 16 | git is stopped after 90 seconds. | A git waiting for a passphrase or a dead network must not block every later write. |
| 51 | 16 | Open in Claude is hidden when the seed mentions money, health or credentials, and row ids are checked (letters, digits, dashes) before they go in a seed. | The spec forbids those seeds; an id is agent-written, so it is validated rather than trusted. |
| 52 | 16 | Every interpolated VoiceOver label and tooltip is built with `Text(verbatim:)`; a test fails on any other form. | String-literal labels are localisation keys, which parse Markdown: an email subject could otherwise inject formatting or a link into a label. |
| 53 | 16 | The allow-list rejects `.`, `..` and empty path parts, treats `agent/`, `nini/` and `.git/` as protected in any letter case, and refuses a write whose folder resolves, through symlinks, outside the vault or into a protected folder. | Found by the independent review: `exam.file: ./agent/…` or `Agent/…` slipped past a prefix check. |
| 54 | 16 | Queued git work carries the "epoch" it was queued in; a mode or vault change bumps the epoch and older work is dropped without writing. | Found by the review: a tick queued behind a slow sync could be written to the live vault after switching to Demo. |
| 55 | 16 | A `mode_ends` without a time covers that whole day. | Found by the review: exam mode would otherwise switch off at 00:00 on the exam day. |
| 56 | 16 | `plan_per_day` is capped at 50 and the plan chart at 366 days. | Found by the review: an absurd number or date in the study file must give an odd chart, not a crash. |
| 57 | 16 | The draft's Claude seed names the snapshot row, not the draft's file name. | Found by the review: the file name is built from the sender's name, which is third-party text. |
| 58 | 16 | Open in Gmail appears on an email row under the pointer or when selected, and in the inspector. | The spec lists it for the list; a permanent button on every row would crowd the mockup's one-line rows. |
| 59 | 16 | Rows and cards expose an accessibility action as well as a click. | VoiceOver and Full Keyboard Access could see the rows but not open them. |
| 60 | 16 | A section header drops its tabs under the title when both do not fit. | In Comfortable density "Important emails" was truncated. |
| 61 | 16 | A store without stored preferences (tests, snapshots) is always Demo. | Found by the Stop hook the moment `~/jose-brain` was cloned: default in-memory preferences resolved to Live and pointed tests at the real vault. Nothing was written, and now nothing can be. |
