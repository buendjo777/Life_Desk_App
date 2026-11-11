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
