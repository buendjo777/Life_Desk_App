# Desk for Mac — build spec

**The canonical spec for the app.** It lives in this repo (`buendjo777/Life_Desk_App`). A summary and the status are in the Proyecto Nini Project (`claude/desk-app.md`); the nightly agents, the vault and the safety rules are in `claude/life-os.md` there.

## What it is
A native macOS app called **Desk**: a full window, not a menu-bar widget or a web view. Eight tabs: **Today, Studying, Projects, Internship apps, Uni apps, Tutoring, Health, System.** It reads what the nightly cloud agents write into Jose's private vault (`jose-brain`), Jose's own notes and his Mac calendar, and hands work back to Claude in one click. It ships with `demo-vault/`, invented data for every tab, which is also the portfolio showcase.

## How to build it
- **All at once.** One build session builds everything in this spec, following "Build order". No phases, no dates.
- **Against `demo-vault/`.** Every tab must render fully from it. The live vault doesn't exist yet; when it does, Jose points Settings at it and nothing else changes.
- **Stop only** for something only Jose can do (install Xcode, grant a permission), and say exactly what.

## Hard constraints
- **Zero cost.** Swift and Xcode are free. Ad-hoc signature (`codesign --force --deep --sign -`). No Apple Developer Program, no notarisation, no App Store.
- **Built on the Mac** by Claude Code with the Xcode toolchain (`xcode-select -p` must point at Xcode, not only the Command Line Tools).
- **A Swift package, not a hand-written Xcode project.** `Package.swift` with one executable target. `scripts/build-app.sh` builds in release, assembles `Desk.app` (binary, `Info.plist`, icon, bundled `demo-vault/`), signs it ad hoc and copies it to `~/Applications`. The package still opens in Xcode.
- **No server, no credentials.** The app never holds Gmail, Calendar, Strava or Claude tokens. The cloud agent reads mail and Strava; the app reads files. The live calendar comes through EventKit, which uses the accounts already on the Mac.
- **One writer per file.** The app never writes `agent/`. In Live mode it writes only Jose's own files: ticks in `TASKS.md`, the study file and `uni/*.md`; clicks in `desk/decisions.jsonl`; `tutoring/payments.csv` (local, never committed). Each committed change is followed by `git pull --rebase` and `git push`; a failure shows a banner.
- **Demo mode never writes to disk.** Ticks and clicks change in-memory state only.
- **Calendar writes only on Jose's click.** Add creates the event through EventKit. EventKit cannot add participants ("EventKit cannot add participants to an event nor change participant information", Apple, `EKParticipant`), so no invitation can leave his account. The event gets a title and times only: no notes, links or locations taken from email.
- **Untrusted text stays text.** Anything that came from email (`email` rows, `evidence`, draft bodies) renders with `Text(verbatim:)`: no Markdown, no links, no attributed strings. Links are built by code from IDs.
- **macOS 14 (Sonoma) or later, SwiftUI, Swift 5.9+.** No third-party packages.

## Architecture
```
cloud nightly agent ──writes──▶ jose-brain (private GitHub repo, separate)
                                  agent/snapshot.json       brief rows
                                  agent/runs.jsonl          one line per run
                                  agent/drafts/*.md         reply drafts
                                  agent/exports/strava.json last 12 weeks
                                  Masters/ Research/ …      Jose's docs (Nini Project copies, Obsidian wikilinks)
                                  TASKS.md study/ projects/ uni/ internships/ contacts/ desk/   Jose's files
Mac: git pull --ff-only ──▶ local clone of jose-brain ──read──▶ Desk.app
Mac: macOS Calendar (Google account added) ──EventKit──▶ Desk.app
Mac: tutoring/ (inside the vault folder, gitignored) ──read/write──▶ Desk.app
Phone: the web Desk (claude.ai) reads the same snapshot rows
```
- **Two repos.** This one (`Life_Desk_App`): the app and `demo-vault/`, public later. `jose-brain`: the private vault, never published.
- **Modes.** *Live* reads the vault path set in Settings (default `~/jose-brain`). *Demo* reads the bundled `demo-vault/` and pins the clock to `demo_today` from its `desk/settings.json`, so the demo always looks the same. Demo is the default until a live vault path is set and exists.
- **Sync (Live).** On launch, every 15 minutes and on ⌘R: `/usr/bin/git -C <vault> pull --ff-only` with Jose's existing git credentials. On failure, a banner; never a silently stale view.

## Data contract
Unknown fields are ignored. A missing or malformed file gives an empty state with a one-line hint, never a crash. Dates are ISO 8601: a date (`2026-11-12`) or a datetime with an offset (`2026-11-18T12:30:00Z`). Times display in `settings.timezone`.

### `desk/settings.json`
`name` · `timezone` · `scheduled_run_local` (`"06:18"`, the live run) · `exam {title, file, mode_starts, mode_ends}` · `tutoring_calendar` · `tutoring_locale` · `currency` · `links {internship_board, contacts_board, run_now}` · `demo_today` (demo vault only).

### `agent/snapshot.json`
A JSON array of rows. The web Desk reads the same file.

| Field | Type | Notes |
|---|---|---|
| `id` | string | Unique |
| `section` | `run` · `deadline` · `today` · `confirm` · `event` · `draft` · `waiting` · `email` · `workout` | |
| `rank` | integer, optional | Order within a section |
| `title` | string | For `email` rows: the sender |
| `detail` | string, optional | For `email` rows: the one-line summary |
| `when` | ISO 8601, optional | |
| `source` | string | A vault path, `Gmail <thread id>`, `Calendar` or `Strava` |
| `mode` | `manual` · `nightly` | `run` row only |
| `subject` | string, optional | `email` rows |
| `tag` | `needs_reply` · `deadline` · `fyi` | `email` rows |
| `action` | `tick` · `add_event` | `confirm` rows |
| `event` | `{title, start, end, all_day}`, optional | `add_event` and `event` rows |
| `evidence` | string, optional | The email line behind a proposal. Untrusted |

`deadline` rows are parsed by code from `Masters/Deadlines 2027.md` (a table with `Closes` and `Programme` columns); that doc stays the master.

### Jose's docs
`Masters/Deadlines 2027.md`, `Masters/Programme comparison.md` (one `###` heading per programme, grouped under `##` sections) and each project's `doc:` file are copies of the Nini Project docs. They contain Obsidian wikilinks (`[[Note]]`, `[[path|label]]`), which Desk shows as plain text (the label, or the note's name). They render as trusted Markdown; a `doc:` path under `agent/` is never loaded.

### Other agent files
- `agent/runs.jsonl`: one JSON object per line: `started_at, finished_at, status (ok|failed|aborted), mode, agents [{name, model}], messages_scanned, drafts, usage_note, failures [string]`.
- `agent/drafts/<date>-<slug>.md`: front matter `to, thread, status (unreviewed|reviewed), created`; the body is the draft. Untrusted text.
- `agent/exports/strava.json`: the last 12 weeks: `[{id, date, type (Run|Ride|Strength|Swim|Walk), name, duration_s, distance_m?, avg_hr?}]`.

### Jose's files
- `TASKS.md`: Markdown checkboxes under `##` sections. Due date as `📅 YYYY-MM-DD` (Obsidian Tasks format).
- The study file (path in `settings.exam.file`): front matter `exam, date, plan_per_day, plan_start`; sections `## Theory` and `## Problems` (one checkbox per topic) and `## Past papers` (`- [x] June 2025 — 2026-11-08 — 6.5/10`; unticked papers have no date or score).
- `projects/<slug>.md`: front matter `title, status (active|waiting|frozen|idea), next, next_date?, doc?` (`doc` is a vault path, e.g. `Research/EMG project.md`). Body: sub-items as checkboxes. Never restates the doc's facts.
- `uni/<slug>.md`: front matter `title, deadline_row` (a snapshot `deadline` id) and `comparison_heading` (a `###` heading in `Masters/Programme comparison.md`). Body: the checklist (portal, CV, statement, letters, transcript, fee, submitted).
- `internships/targets.json` (optional; absent until the board moves into the vault): `[{id, company, role, city, country, list (apply_now|target), status (open|applied|interview|offer|rejected|watching), graduate_ok, deadline?, next?, url?}]`.
- `contacts/people.json` (optional, same rule): `[{id, name, programme, role, status (not_contacted|drafted|sent|replied|call_booked|no_reply), last_contact?, next?}]`.
- `desk/decisions.jsonl`: one line per click: `{at, row, action (add|dismiss|confirm|reopen)}`. The agent reads it, so it never re-proposes and can count clean confirmations.
- `calendar/events.json` (**demo vault only**): `[{id, calendar, title, start, end, all_day, location?}]`. Stands in for EventKit in Demo mode.

### `tutoring/` (local only)
Inside the vault folder, so Obsidian sees it; listed in the vault's `.gitignore`, so it never reaches GitHub or the cloud agent.
- `students.md`: a table `Initials | Level | Subject | Rate (€/h) | Pays by`.
- `payments.csv`: `month,initials,lessons,hours,amount,sent,paid` (dates, or empty).
- `notes/<initials>.md`: `## YYYY-MM-DD` entries, newest last.
- `template.md` (the monthly message) and `template-reminder.md`, with the placeholders `{parent} {student} {month} {lessons} {hours} {amount} {method}`.
- `contacts.json`: `{initials: {parent, student, phone}}`, the phone in international format. The only file with names, and it never leaves the Mac.
- Initials everywhere else. GDPR likely applies (paid work is not a "purely personal or household activity"), so keep only what invoicing needs.
- Messages format `{month}` in `settings.tutoring_locale` (e.g. `es_ES` → "octubre").

## Tabs
A custom three-part layout (floating sidebar · content · right rail or inspector), not `NavigationSplitView`. See DESIGN.md and `design/mockup/`. ⌘1–⌘8 in this order.

1. **Today**
   - The greeting and one summary sentence built by code, e.g. "4 due today, 3 leftovers, 2 to confirm. 16 days to the exam, 19 to Alpine Tech."
   - Stat cards: **Deadlines** (the nearest three, days left, a 90-day runway) · **Today** (focus, due, leftovers, to confirm; a 07:00–22:00 day strip with a now marker) · **Inbox** (important, need reply, deadline; last scan) · **Health** (sessions and time this week, last workout).
   - **Today's list**, tabs Focus (the `today` rows) · Due (TASKS.md items due today, minus titles already in Focus) · Leftovers (unticked items dated before today). Worked out by code; no AI.
   - **Important emails**, tabs All · Needs reply · Deadline: sender, subject, summary, tag, Open in Gmail. As of the last run, not live. Tutoring email is never scanned.
   - Right rail: the run-status chip and round buttons (sync, Run now, settings); a month calendar; **Needs confirmation** (ticks, and proposed events with Add and Dismiss; deadlines and changes to existing dates are always confirm-only); today's **timeline**.
   - Drafts and Waiting open in the inspector.
2. **Studying.** The exam in `settings.exam`: countdown, overall progress, progress per topic for theory and problems, past papers done against the plan line (`plan_per_day` from `plan_start`), today's target. Between `mode_starts` and `mode_ends` (exam mode) it becomes the first screen, and Today hides drafts and waiting. With no exam set: an empty state.
3. **Projects.** Board columns Active · Waiting · Frozen · Ideas; one card per project with its next step and date. The inspector renders the linked doc (trusted Markdown, wikilinks as plain text) and the sub-item checklist. Open in Obsidian, Open in Claude.
4. **Internship apps.** From `internships/targets.json`: counts per status; list tabs Apply now · All targets; rows with company, role, city, status, deadline and next step. Without the file: an Open board button (`links.internship_board`).
5. **Uni apps.** A deadline runway across all programmes; one card per `uni/*.md` with days left, checklist progress and status; the inspector shows that programme's section of the comparison doc. The Contacts Board from `contacts/people.json` (counts by status, list), or an Open board button.
6. **Tutoring.**
   - This month: hours and amount per student from the tutoring calendar (event titles are initials; amount = hours × rate); received vs pending as a donut.
   - **Waiting for payment**: sent, unpaid rows, each with **Send reminder** (wa.me with `template-reminder.md`).
   - **Month end**: for a finished month not yet sent, **Send on WhatsApp** per student (wa.me with `template.md`), then Mark sent.
   - The payments table with status chips (Not sent · Sent · Paid) and Mark paid.
   - This week's lessons; the last note per student in the inspector.
7. **Health.** From `strava.json`: this week's sessions, time and distance; a 7-day streak grid; 12-week bars; the activity list.
8. **System.** Run history from `runs.jsonl` (time, status, duration, models, failures, usage note); a 14-day strip of runs; models used. This is the showcase panel.

**Run-status rule** (the same as the web Desk): red when the last successful run is older than the latest scheduled run (`scheduled_run_local` in `timezone`, with 60 minutes' grace) or older than 30 hours; amber for a manual snapshot; green otherwise. Always with a word, never colour alone.

## Built to iterate
The Today mockup is V1 and a little dense, and Jose will keep changing the look. So:
- Every colour, font size, radius and spacing value lives in `Theme.swift`. Views use tokens, never literals.
- Every card and section is its own view, listed once per tab in a `TabLayout`. Adding, removing or reordering one is a one-line change.
- **Customise** (View → Customise…): per tab, show or hide and reorder its cards and sections, and pick the density: Compact (the mockup) or Comfortable (more space, fewer rows). Saved as app preferences, not in the vault. Reset restores the defaults.


## Integrations: what is possible and what is not
- **WhatsApp: never read.** Reading a personal account needs an unofficial tool, and WhatsApp's terms forbid access "through automated or other means" and allow suspending the account (https://www.whatsapp.com/legal/terms-of-service-eea). Sending uses the official click-to-chat link with prefilled text (https://whatsapp.com/faq/en/general/26000030); Jose presses send.
- **Calendar.** Live: EventKit with full access (`NSCalendarsFullAccessUsageDescription`; Apple TN3152). Google's own "Show events from Gmail" adds flights, trains, hotels, restaurants and tickets; it is off by default in the EEA (https://support.google.com/calendar/answer/6084018). Anything else arrives as an `add_event` proposal. Agents never write the calendar.
- **Strava** through the nightly run; Garmin only through Strava's own sync. Not live.
- **Boards.** The email-reading run never gets a tool that can edit the artifact boards. Their data reaches the app by moving into the vault.

## Hand-offs
- **Open in Claude**: `https://claude.ai/new?q={urlencoded seed}`. The seed is Jose's own work order and never contains third-party text: it names the item and where it lives. No seed for anything about money, health or credentials.
- **Open in Gmail**: `https://mail.google.com/mail/u/0/#all/<thread id>` (check it opens the right thread).
- **Send on WhatsApp**: `https://wa.me/<digits only, international>?text=<urlencoded>`. Nothing is sent until Jose presses send.
- **Open in Obsidian**: `obsidian://open?vault=<vault folder name>&file=<path>`.
- **Run now**: opens `links.run_now` in the browser.

## Verification
- Unit tests for every parser against `demo-vault/`, plus malformed input (empty state, no crash).
- Snapshots: `Desk --render-snapshots <dir>` renders every tab in light and dark at 1440×900 with `ImageRenderer`, then exits. Compare with `design/mockup/`. If a view can't render offscreen, use `screencapture -l<windowID>` on the running app (Jose grants Screen Recording once).
- At the end: screenshots of all eight tabs, light and dark, in `design/screenshots/`.

## Build order (one session, no stops between steps)
1. The package, `scripts/build-app.sh`, the app shell: window (hidden title bar), floating sidebar, tab routing, ⌘1–⌘8, theme tokens from DESIGN.md, light and dark.
2. Models and parsers for every file above, with tests. A clock service (real time, or `demo_today`). The mode switch.
3. Today.
4. Studying.
5. Projects.
6. Internship apps.
7. Uni apps.
8. Tutoring.
9. Health.
10. System.
11. Writes (Live: commit, pull --rebase, push; Demo: memory only) and `desk/decisions.jsonl`.
12. EventKit: live calendar and Add (Live); `calendar/events.json` (Demo).
13. Git sync, the banner, the Settings window (vault path, mode).
14. Customise panel and density ("Built to iterate").
15. The Portfolio screen.
16. App icon, final build and install, screenshots, README.

## Portfolio mode
- The demo vault plus a Portfolio screen: what the system does, an architecture diagram, the agents and their models, the evaluation result (missed-reply rate), the cost table, the failure log, a link to the thesis repo.
- Never reads the live vault.
- Distribution: the public repo plus a recorded demo and screenshots, not a download (unsigned apps are hard for others to run).
- Before the first public commit: run a secret scan and confirm no real names, emails or vault content anywhere in the history.

## Open questions (none blocks the build)
1. The real exam topics and past papers: Jose fills the study file in his vault.
2. Does Jose's Garmin auto-upload to Strava?
3. Do code-built Gmail thread links open the right thread on his Mac?
4. Does an ad-hoc-signed app keep its Calendar permission across rebuilds?
5. Does the Comillas Outlook account work in macOS Calendar?

## Do not
- Make network calls beyond `git` and opening links.
- Store or ask for any token or password.
- Render email-derived text as Markdown or HTML.
- Read, scrape or automate WhatsApp beyond opening a wa.me link.
- Put attendees, notes, links or locations from email into a calendar event.
- Write to `agent/`, or write to disk in Demo mode.
- Commit real personal data to this repo.
- Add third-party packages.
