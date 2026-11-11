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
