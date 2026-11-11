# Desk for Mac — build plan

Short plan for the one-session build. The spec is `SPEC.md`; the look is `DESIGN.md`. Decisions taken where they are silent go in `DECISIONS.md`; the story of the build goes in `BUILD_NOTES.md`.

## Architecture

```
demo-vault/ or ~/jose-brain ──▶ VaultReader ──▶ Parsers (pure, tested) ──▶ VaultData
EventKit (Live) / calendar/events.json (Demo) ─────────────────────────▶ events
VaultData + clock ──▶ Derived (pure, tested: lists, run status, months, weeks)
Derived ──▶ Store (@Observable, main actor) ──▶ SwiftUI views (tokens from Theme)
clicks ──▶ Store ──▶ VaultWriter ──▶ Live: file + git commit, pull --rebase, push
                                     Demo: in-memory overlay, never the disk
```

- **One executable target** (`Desk`) plus a test target. No third-party packages. Warnings are errors.
- **Pure core, thin views.** Parsers turn text into models; `Derived` turns models plus a clock into what each tab shows. Both are plain functions, so the tests cover them without any UI.
- **One read path for both modes.** `VaultReader` reads a file from disk unless an in-memory overlay has it. Demo writes go to the overlay, Live writes go to disk and git; everything then reloads through the same parsers.
- **Untrusted text.** Everything the agent wrote is drawn with `Text(verbatim:)`. Markdown is rendered in exactly one file, used only for `nini/` docs; a test fails if Markdown parsing appears anywhere else.
- **Built to iterate.** `Theme.swift` holds every colour, font, radius and spacing token and the density scale. Each tab is a list of sections in `TabLayout.swift`; Customise reorders and hides them.
- **Snapshots.** `Desk --render-snapshots <dir>` draws every tab, light and dark, at 1440×900 with `ImageRenderer`. Scroll views and the search field are swapped for plain stand-ins in snapshot mode, because `ImageRenderer` cannot draw AppKit-backed controls.

## File layout

```
Package.swift
scripts/build-app.sh        release build → Desk.app → ad-hoc sign → ~/Applications
scripts/stop-hook.sh        swift build + swift test, used by the Stop hook
Sources/Desk/
  App/         Main (CLI flags), DeskApp (scenes, menus), Store, Preferences, Snapshots
  Theme/       Theme (all tokens), Shapes (card shapes), TextStyles
  Model/       Models, Parsers, Vault (reader + loader), Derived, DeskCalendar
  Services/    Links, Git, VaultWriter, CalendarService (EventKit)
  Components/  StatCard, ListRow, CountedTabs, Chips, Buttons, ProgressBar,
               MonthCalendar, Timeline, Donut, MarkdownView, EmptyState
  Shell/       RootView, Sidebar, SearchBar, Inspector, Banner, WindowChrome
  Tabs/        TabLayout, Today/…, Studying, Projects, Internships, Uni,
               Tutoring, Health, System, Portfolio
  Settings/    SettingsView, CustomiseView
Tests/DeskTests/            parsers, derived values, writes, git round trip
design/screenshots/         final light and dark shots of every tab
```

## Build order
As in SPEC.md, steps 1 to 16, one commit and push per step, each one warning-free, tested and compared with the mockup in light and dark.

## Risks

| Risk | Plan |
|---|---|
| `ImageRenderer` cannot draw scroll views, text fields or menus | Snapshot mode swaps them for plain SwiftUI stand-ins; fall back to `screencapture` only if needed |
| Traffic lights must sit on the floating sidebar | Reposition the standard window buttons from a small AppKit hook; redo it on resize |
| EventKit and Live git sync cannot be tested without touching real data | EventKit code is isolated behind one service and stays untested live; git is tested against a throwaway local repo |
| An ad-hoc-signed app may lose its Calendar permission on rebuild | Open question 4 in the spec; noted in the README |
| The Portfolio screen needs an evaluation result and a thesis link that are not in the vault | Read an optional `desk/portfolio.json`; show an honest empty state until Jose supplies them |
| The mockup and the spec disagree in places (for example the Due count) | The spec wins; each case is logged in `DECISIONS.md` |
| The session folder is the parent of the repo, so project hooks may not load from the repo | Install the Stop hook in both the repo and the session folder |
