# pikicam project generation (xcodegen)

`pikicam.xcodeproj` is hand-maintained but fully modeled in [`project.yml`](../project.yml)
for deterministic regeneration.

- **Install xcodegen:** `brew install xcodegen`
- **Regenerate:** `xcodegen generate` (run from repo root; overwrites `pikicam.xcodeproj`)
- **Why:** `pbxproj` is not diff/merge friendly for agents; `project.yml` is a
  declarative source of truth (app target + `pikicamTests` unit-test target +
  shared scheme + DNG fixture resource).

**Current status (2026-08-09):** xcodegen is **not installed** on this machine
(no Homebrew). `project.yml` is kept in sync with the hand-written project;
generation has NOT been run, so `project.pbxproj` is still authoritative. Do not
edit `project.yml` out of sync with the pbxproj. After generating, verify with:

```sh
xcodebuild -project pikicam.xcodeproj -scheme pikicam \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```
