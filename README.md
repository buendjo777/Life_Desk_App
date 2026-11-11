# Desk for Mac

A native macOS command centre: **Today, Studying, Projects, Internship apps, Uni apps, Tutoring, Health, System**, plus a Portfolio screen. It reads a private Obsidian vault (`jose-brain`) that cloud agents update every night, and the Mac calendar. It ships with `demo-vault/`, fully invented data, and starts in Demo mode.

![Today, light](design/screenshots/today-light.png)
![Today, dark](design/screenshots/today-dark.png)

More screenshots, light and dark, for every tab: [`design/screenshots/`](design/screenshots).

- **Spec:** `SPEC.md` · **Design:** `DESIGN.md`, `design/mockup/` · **Build rules:** `CLAUDE.md`
- **How it was built:** `PLAN.md`, `BUILD_NOTES.md` (one section per step), `DECISIONS.md` (every choice the spec left open)
- **Status:** all 16 build steps done. Demo mode is verified; Live mode is implemented and tested against a throwaway repo, but has not been run against a real vault yet (see "Not verified yet").

## Requirements
- macOS 14 or later, Apple silicon.
- Xcode installed and selected: `xcode-select -p` should print a path inside `Xcode.app`.
- No third-party packages, no accounts, no cost.

## Build and install

```bash
scripts/build-app.sh
```

This builds in release, assembles `Desk.app` (binary, `Info.plist`, icon, the bundled `demo-vault/`), signs it ad hoc and installs it to `~/Applications/Desk.app`. Open it from there or drag it to the Dock. The first launch may need right-click → Open, because the app is not notarised.

For development:

```bash
swift build
```

```bash
swift test
```

```bash
swift run Desk
```

```bash
.build/debug/Desk --render-snapshots /tmp/desk-snapshots
```

The last command draws every tab in light and dark at 1440×900 and exits; it is how the screenshots in `design/screenshots/` were made. The package also opens in Xcode (`open Package.swift`).

## Demo and Live

| | Demo (default) | Live |
|---|---|---|
| Reads | the bundled `demo-vault/` | the vault folder set in Settings |
| Clock | pinned to `demo_today` (Wed 11 Nov 2026, 08:12) | real time, in `settings.timezone` |
| Calendar | `calendar/events.json` | macOS Calendar through EventKit |
| Ticks and clicks | memory only, never the disk | written to the file, committed, `pull --rebase`, pushed |
| Sync | none | `git pull --ff-only` on launch, every 15 minutes and on ⌘R |

### Switching to the live vault (once `jose-brain` exists)

1. Clone the private vault to the default place, with git credentials that can push:
   ```bash
   git clone git@github.com:buendjo777/jose-brain.git ~/jose-brain
   ```
2. Check the vault has `desk/settings.json` (name, timezone, `scheduled_run_local`, links; **no** `demo_today`) and that its `.gitignore` lists `tutoring/`.
3. Open Desk. With the default settings it switches to Live by itself as soon as `~/jose-brain` exists: the sidebar chip changes from DEMO to LIVE. For another location, open Settings (⌘, or the gear button) and set the vault folder.
4. On the first Live sync macOS asks for Calendar access. Allow it; if you refuse, the timeline tells you where to turn it on (System Settings → Privacy & Security → Calendars).
5. To go back to the demo at any time: Settings → turn off "Use the live vault when the folder exists".

What Desk writes in Live mode, and nothing else: ticks in `TASKS.md`, the study file and `uni/*.md`; one line per click in `desk/decisions.jsonl`; `tutoring/payments.csv` (written to disk, never committed). It never writes `agent/` or `nini/`. A failed sync or push shows a red banner with Retry; the view is never silently stale.

## Keys
⌘1–⌘8 tabs · ⌘9 Portfolio · ⌘R sync · ⌘F search · Space ticks the highlighted item · Return opens it in the inspector · Esc closes the inspector · ⌘, Settings · View → Customise… to show, hide and reorder each tab's sections and pick Compact or Comfortable.

## Changing the look
Every colour, font size, radius and spacing value is a token in `Sources/Desk/Theme/Theme.swift`. Each tab's cards and sections are listed once in `Sources/Desk/Tabs/TabLayout.swift`; adding, removing or reordering one is a one-line change.

## Safety rules the code enforces
- No network calls except `/usr/bin/git` in the vault and opening links in the browser. No tokens or passwords anywhere.
- Text from email or the agent is drawn with `Text(verbatim:)`. Markdown is parsed in one file only (`MarkdownView.swift`), for the trusted `nini/` mirror; a test fails if it appears anywhere else.
- Links are built by code from ids: Gmail threads, `wa.me`, `obsidian://`, `claude.ai/new?q=`. The Claude seed names a file path, never third-party text, and Tutoring has no Claude button.
- A calendar event is created only on Add, with a title and times only.
- WhatsApp is never read; Desk only opens a prefilled message that you send yourself.
- One allow-list (`VaultWriter.isWritable`) decides what can be written; tests cover it.

## Not verified yet
These need the real vault or a permission prompt, so they were built and unit-tested but not exercised end to end:
- **EventKit** (reading the Mac calendar, Add). Tested with a fake calendar only.
- **Live git sync against `jose-brain`.** Tested against a throwaway local repo: commit, `pull --rebase`, push, and the failure banner.
- Whether an ad-hoc-signed app keeps its Calendar permission across rebuilds (spec open question 4).
- Whether code-built Gmail thread links open the right thread (open question 3).
- The Settings window, the Customise sheet and the timeline's filter popover on screen. The installed app was launched in Demo mode and checked by eye (traffic lights on the sidebar, tab switching, scrolling), and tests send real mouse clicks to the view tree, but those three were only drawn offscreen.

## Before making this repo public
Run a secret scan and confirm there are no real names, emails or vault content anywhere in the history (SPEC "Portfolio mode"). `demo-vault/` is invented data only; never add real data to it.
