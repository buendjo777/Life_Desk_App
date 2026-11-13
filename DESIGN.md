# Desk — design

**The target:** `design/mockup/today-light.png` and `today-dark.png`, rendered from `design/mockup/today.html` with the demo vault's data. Match them closely for Today, and apply the same system to every other tab.

**Where it comes from.** Jose picked four dashboard shots as inspiration: a clinic dashboard with a floating dark sidebar, colour-block stat cards and a calendar rail; the same product's billing and week views; a project tracker with counted tabs; and a "Life OS" page with progress bars, a habit grid and a project board. Keep their structure. Replace their pastel pink, yellow and lavender with a darker, earthier palette (Jose: "nicer, more manly colours"). Copy no logo, name, illustration or exact layout.

## Principles
- **Heavy and physical.** Big type, solid colour blocks, a graphite panel over a warm canvas. No glass, no gradients, no emoji, no photos.
- **One glance answers "what now".** Greeting sentence → stat cards → lists → right rail.
- **Colour marks the category, words carry the meaning.** Every status has a label.
- **Calm density.** An 8-point grid, generous padding, one line per row.

## Palette
Define once in `Theme.swift` as semantic tokens. Text on accent cards is always `onAccent` in both modes.

| Token | Light | Dark | Use |
|---|---|---|---|
| `canvas` | `#ECE8E1` | `#101215` | Window background |
| `panel` | `#16181C` | `#08090B` | Sidebar (in dark mode with a 1 pt `line` border) |
| `primary` / `onPrimary` | `#16181C` / `#ECE8E1` | `#ECE8E1` / `#101215` | Primary buttons, active tabs and chips (inverted in dark mode) |
| `control` | `#16181C` | `#23272D` + 1 pt `line` border | Round icon buttons |
| `panelText` | `#ECE8E1` | `#ECE8E1` | Text on the panel |
| `panelMuted` | `#8C8A84` | `#77756F` | Section labels and hints on the panel |
| `surface` | `#E2DDD4` | `#1A1D22` | List rows, neutral cards |
| `raised` | `#F7F4EF` | `#23272D` | Search field, inspector, popovers, timeline and confirm cards |
| `line` | `#D2CCC1` | `#2E333A` | Borders, tracks, dividers |
| `ink` | `#16181C` | `#ECE8E1` | Primary text on canvas and surfaces |
| `inkMuted` | `#5F5D57` | `#9C9990` | Secondary text |
| `onAccent` | `#16181C` | `#16181C` | Text on accent cards |
| `ochre` / `ochreDeep` | `#D4A23F` / `#B4842A` | same | Deadlines, Studying |
| `rust` / `rustDeep` | `#C8763C` / `#A35A2A` | same | Today, selection, "now" |
| `steel` / `steelDeep` | `#8EA6BE` / `#6C88A5` | same | Inbox, Uni apps |
| `moss` / `mossDeep` | `#8A9A5B` / `#6B7A41` | same | Health, done, paid |
| `navy` | `#1F2C3B` | `#2A3B4F` | System cards, dark chips |
| `alert` | `#A8432F` | `#C9573F` | Failures and overdue items, always with a label |

Contrast of `onAccent` text: ochre 7.6:1, steel 7.1:1, rust 5.2:1, moss 5.8:1. `ink` on `canvas`: 14.6:1. `inkMuted` on `surface`: 4.9:1.

## Type
SF Pro (the system font). The mockup uses Inter as a stand-in.

| Role | Size / weight | Notes |
|---|---|---|
| Display (greeting) | 40 / Bold | Tracking −0.8 |
| Title | 28 / Bold | Tab titles on non-Today tabs |
| Section | 20 / Semibold | "Today's list", "Important emails" |
| Card title | 17 / Semibold | |
| Figure | 26 / Bold | `.monospacedDigit()` |
| Body | 14 / Regular · Semibold for row titles | |
| Small | 12 / Medium | Row subtitles, chips |
| Caption | 10–11 / Semibold, uppercase | Tracking +0.6, under figures |

## Layout
- Designed at 1440×900; minimum window 1280×800. Hidden title bar; the traffic lights sit on the sidebar.
- **Sidebar:** floating graphite panel, inset 12 pt from the window edges, 232 pt wide, 24 pt corners. The "Desk" wordmark and a mode chip (LIVE or DEMO). Groups with small uppercase labels: **Focus** (Today, Studying) · **Pipeline** (Projects, Internship apps, Uni apps) · **Life** (Tutoring, History, Health) · **Machine** (System). Rows 36 pt with an SF Symbol, the label and a muted ⌘ shortcut. The selected row: a 3 pt rust bar on the left and a faint light fill. At the bottom: sync time, vault and run status.
- **Content column:** a 24 pt gap after the sidebar. A search field across the top (⌘F) with scope chips; the greeting; the summary sentence; then the tab's content.
- **Right rail** (Today, Tutoring): 336 pt, 24 pt from the right edge. Status chip and round `control` icon buttons on top.
- **Inspector:** a raised panel that slides over the right rail when a row is selected; Esc closes it.
- **Density:** Compact is the mockup. Comfortable multiplies spacing and padding by 1.25, makes rows 60 pt tall and shows up to two fewer rows per list. Both read their values from `Theme.swift`.

## Components
- **Stat card.** 24 pt corners, 20 pt padding, accent background, card title, two to four figures with uppercase captions, an optional mini chart in `onAccent`. One large geometric shape in the accent's deep tone at about 55% opacity, anchored top right and clipped by the card. Shapes per card: Today → circle (a sun) · Deadlines → triangle · Inbox → eight-point star · Health → heart · Studying → triangle · Projects → hexagon · Internship apps → square rotated 15° · Uni apps → chevron · Tutoring → ring · History → eight-point star · System → twelve-tooth cog. Draw them as SwiftUI `Shape`s.
- **List row.** `surface`, 18 pt corners, 52 pt tall: a 34 pt round icon badge (accent tint), a semibold title, a muted subtitle, a capsule chip on the right. Selected: `rust` background.
- **Counted tabs.** Capsules such as "Focus 3 · Due 4 · Leftovers 3". Active: `primary` with `onPrimary`. Inactive: outlined.
- **Buttons.** Primary: a `primary` capsule with `onPrimary` text. Secondary: an outlined capsule. Icon: a 44 pt `control` circle with a `panelText` symbol.
- **Chips.** Capsules, 12 pt medium, tinted at about 25% of the accent with `ink` text; status chips always say the status.
- **Month calendar.** A week-number column, Monday first, weekends muted, today in a `rust` circle, small dots for events and deadlines, the month name in a `rust`-tinted pill between arrows.
- **Timeline.** A time column on the left, then event cards (`raised`, 16 pt corners) with an icon badge, title, place and time range. Past events at 45% opacity. Now: a dashed `rust` line with a time pill.
- **Progress bar.** An 8 pt capsule track in `line` with an accent fill; label on the left, value on the right.
- **Streak grid.** Seven rounded squares, Monday to Sunday: `moss` = trained, `line` = rest.
- **Board columns** (Projects). Column headers with count chips; compact cards inside.
- **Money** (Tutoring). A donut (received vs pending), stat cards for received, pending and hours, and table rows with status chips and an action button.
- **Empty state.** One muted line plus a hint, e.g. "No exam set — add one in desk/settings.json."

## Per tab
- **Today:** as the mockup. Cards in two rows: Deadlines (ochre) + Today (rust), then Inbox (steel) + Health (moss). Below: Today's list and Important emails side by side. Right rail: calendar, Needs confirmation, timeline.
- **Studying:** a hero card (ochre: countdown, overall progress ring); today's target, with today's share of a list ticked right on the card; the study file's own lists under it (a header with the due day, days left and items to go, then two group cards per row); progress bars per topic in two columns (Theory, Problems); a plan chart (steel: papers done against the plan line); the past-papers list with score chips; today's target.
- **Projects:** four board columns; the inspector shows the project's linked doc and the checklist.
- **Internship apps:** a row of stat cards (Open, Applied, Interview, Rejected); counted tabs Apply now · All targets; the table.
- **Uni apps:** a horizontal deadline runway with a today marker; a grid of programme cards (steel) with a progress bar and days left; the Contacts Board section below.
- **Tutoring:** the billing layout: this year's donut (received against still to come) and three money cards (this month so far, owed, hours) on the left; rows carry the student's name; Waiting for payment cards with Send reminder; Month end; the payments table; right rail with this week's lessons.
- **History:** four stat cards (this year and last year in steel, all time in moss, best month in ochre); 24 monthly bars (steel, this month in the deep tone, the year under each January); By year and By student lists side by side.
- **Health:** stat cards (sessions, time, distance); the streak grid; 12-week bars (moss); the activity list.
- **System:** navy cards with light text for the latest run and the models; the 14-day run strip; the history table with status chips.

## Motion and accessibility
- 180 ms ease-out on selection, tab and inspector changes. Numbers don't animate. Respect Reduce Motion.
- VoiceOver labels on every icon button. Keyboard: ⌘1–⌘9, ⌘0, ⌘R, ⌘F, Space ticks, Return opens, Esc closes the inspector.

## Don't
- Pastel pink, yellow or lavender. Glassmorphism. Gradients. Drop shadows on canvas cards (only raised panels get a soft one).
- Photos, illustrations or avatars of people (use initials in circles).
- Colour-only status.
