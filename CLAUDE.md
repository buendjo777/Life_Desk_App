# Life_Desk_App — instructions for the build session

You are building **Desk for Mac**, a native SwiftUI app, on Jose's Mac. Everything you need is in this repo.

## Read first, in this order
1. `SPEC.md`: what to build, the data contract, the rules, the build order.
2. `DESIGN.md`: how it looks (palette, type, components, per-tab layouts).
3. `design/mockup/today-light.png` and `today-dark.png`: the visual target.
4. `demo-vault/`: the invented data every tab renders from.

## How to work
- **Build the whole app in one go**, following "Build order" in SPEC.md. No phases, no dates, no stopping for approval between steps.
- Stop only for something only Jose can do (install Xcode, grant a permission). Say exactly what, then carry on with the rest.
- Use a Swift package plus `scripts/build-app.sh`. Never hand-write an `.xcodeproj`.
- After each step: build, render snapshots (SPEC "Verification"), compare light and dark with the mockup and DESIGN.md, fix, then move on.
- Keep the build warning-free and the parser tests green.
- Commit after each step with a clear message, and push to `main`.
- If the spec is ambiguous, choose the simplest option that keeps every hard constraint, write it in `DECISIONS.md`, and keep going.

## Never
- Store or ask for tokens or passwords. No network calls beyond `git` and opening links.
- Render email-derived text as Markdown or HTML: use `Text(verbatim:)`.
- Read, scrape or automate WhatsApp beyond opening a wa.me link.
- Put attendees, notes, links or locations from email into a calendar event.
- Write to `agent/` in any vault, or to disk in Demo mode.
- Commit real personal data. `demo-vault/` is invented data only.
- Add third-party Swift packages.

## Done means
- All eight tabs match DESIGN.md and render fully from `demo-vault/`, in light and dark.
- `scripts/build-app.sh` installs `Desk.app` to `~/Applications`, and it launches from the Dock.
- Screenshots of every tab, light and dark, in `design/screenshots/`.
- README explains how to build, and how to switch to the live vault once `jose-brain` exists.
