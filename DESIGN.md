# Desk — design

**The target:** `design/mockup/today-light.png` and `today-dark.png`, rendered from `design/mockup/today.html` with the demo vault's data. Match them closely for Today, and apply the same system to every other tab.

**Where it comes from.** Jose picked four dashboard shots as inspiration: a clinic dashboard with a floating dark sidebar, colour-block stat cards and a calendar rail; the same product's billing and week views; a project tracker with counted tabs; and a "Life OS" page with progress bars, a habit grid and a project board. Keep their structure. Replace their pastel pink, yellow and lavender with a darker, earthier palette (Jose: "nicer, more manly colours"). Copy no logo, name, illustration or exact layout.

## Principles
- **Heavy and physical.** Big type, solid colour blocks, a graphite panel over a warm canvas. No glass, no gradients, no emoji, no photos.
- **One glance answers "what now".** Greeting sentence → stat cards → lists → right rail.
- **Colour marks the category, words carry the meaning.** Every status has a label.
- **Calm density.** An 8-point grid, generous padding, one line per row.

## Palette
Two strong colours and one bright accent, in three colourways (Customise → Colours). Hex values live in `Theme/Palette.swift`; views read tokens from `Theme.swift` and never hold a colour.

| Colourway | Field (strong 1) | Glow (strong 2) | Bright accent |
|---|---|---|---|
| **Midnight Ember** (default) | indigo `#14124A` | coral `#FF5A3C` | lime `#E8FF6A` |
| **Oxblood Marigold** | burgundy `#6E1230` | crimson `#C8324A` | marigold `#FFC21A` |
| **Ink Saffron** | deep teal `#0E4D4F` | burnt orange `#E8742A` | saffron `#FF9E1B` |

- **Backdrop.** The field runs dark at the top to the glow at the bottom, under vertical fluted-glass ribs. Light mode uses a pale version of the same two colours.
- **Glass.** Cards and rows are smoked glass in dark mode (the field colour at 50%) and white glass in light mode (66%), with a hairline edge lit from above. Panels that float over content (inspector, search results) are opaque.
- **Accent.** `focus` is the bright accent in dark mode and the hot strong colour in light mode, where lime would not read. It marks one thing at a time: today, the selection, the primary button.
- **Signals.** `good`, `caution`, `info`, `alert`, each with a darker light-mode tone. They appear as chips, dots and a faint wash on stat cards, never as a block of colour.
- **Accessibility.** Reduce Transparency or Increase Contrast makes every surface opaque. Text on glass must reach 4.5:1 where the glow is brightest.

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
All motion is off with Reduce Motion, in Low Power Mode, in snapshots, and when Motion is switched off in Customise. The backdrop also stops while Desk is not the active app.
- **The day's tide.** The glow at the bottom of the window is a meter, not decoration: it rises and brightens as today's work gets done (today's study share plus the tasks due today), and a bright core appears on the horizon. The same number is written under the greeting on Today.
- **The time of day.** A soft column of light sits on the ribs where the day stands, 07:00 at the left edge and 22:00 at the right, as on the day strip.
- **Drift.** Two colour fields move slowly (20 frames a second, no blur). They move faster when a deadline is within two days.
- **Depth.** A card rises 2 pt under the pointer with a shadow; the shape inside a stat card drifts towards the pointer; rows brighten.
- **Entrance.** Opening a tab, sections fade up one after another (360 ms, 45 ms apart).
- **Numbers.** Digits roll when a figure changes; bars and rings fill when they appear.
- **A tick.** The checkmark bounces and eight sparks fly out.
- VoiceOver labels on every icon button. Keyboard: ⌘1–⌘9, ⌘0, ⌘R, ⌘F, Space ticks, Return opens, Esc closes the inspector.

## Don't
- Pastel pink, yellow or lavender. Glassmorphism. Gradients. Drop shadows on canvas cards (only raised panels get a soft one).
- Photos, illustrations or avatars of people (use initials in circles).
- Colour-only status.
