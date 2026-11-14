# AboutJose

A storytelling portfolio for Mac, built on the same platform as Desk (`Sources/DeskKit`). One window, five chapters: Opening, Thesis, Desk, Tutoring, Next. Scroll, press the arrow keys, or click the rail on the left. The glow at the bottom rises as the story goes on. Top right: three colourways and light or dark.

## Change the words
Everything the app says is in **`about/story.json`**. Edit it, then build again. No code needed.

- A contact row with an empty `"value"` shows a **Placeholder** chip. Fill `"value"` (what is shown) and `"url"` (an `https://` link, or leave it empty).
- `"symbol"` is an SF Symbol name.
- Desk screens: `"file"` is a name from `design/screenshots/` without `-light.png`.
- If the file has a mistake, the app opens with a sentence saying which key is wrong.

## Build
```bash
./scripts/build-about.sh
```
Installs `~/Applications/AboutJose.app`. To run from source instead:
```bash
swift run AboutJose
```

## Web copy (for people without a Mac)
```bash
./scripts/build-web.sh
```
Writes `docs/`: one static page with the same five chapters, the same words (`about/story.json`) and the same colours (read from the app). It works on a phone. Open `docs/index.html` to read it; nothing to install, no server.

**Live at https://buendjo777.github.io/Life_Desk_App/** (GitHub Pages, branch `main`, folder `/docs`, switched on 14 Nov 2026). To update it: change the words, run the script, commit and push to `main`. A test fails if `docs/` is older than the story.

## Snapshots
```bash
swift run AboutJose --render-snapshots design/about
```
Every chapter, light and dark, at 1440 × 900.

## Where things are
| What | Where |
|---|---|
| The words | `about/story.json` |
| The app | `Sources/AboutJose/` (`Chapters/` has one file per chapter) |
| Sizes and type only this app uses | `Sources/AboutJose/StoryTheme.swift` |
| Colours, glass, motion, backdrop (shared with Desk) | `Sources/DeskKit/` |
| The web page | `web/index.html` (layout and behaviour), built into `docs/` |
| Tests | `Tests/AboutJoseTests/` |

## Rules it keeps
- Nothing invented: every fact comes from Jose's own notes. The ECG trace is drawn by the app and says so.
- No grade average, no student names, no earnings.
- No third-party packages, no network calls: links open in the browser, https only.
