# pikicam

An iOS camera that does three things — shoot a photo, apply
black-and-white, record video — and is "working" only when the human
acceptance walk passes on a physical iPhone. One look, one archive, one
grammar; chrome is naked by construction.

## What & why

iOS defaults to fused, tone-mapped photos; pikicam captures one honest
frame per press (Bayer DNG where the sensor offers it), develops
black-and-white through a single derived look (the CIE P3 luminance
row — one definition shared by stills AND video), and keeps every
capture in a pikicam-only album. Every claim is measured: frame
arithmetic, audio pass-through, parity bands, and budgets live in
committed artifacts with provenance.

## Quick start

Requirements: Mac with Xcode 26, an unlocked iPhone (12 mini tested)
connected by cable, Developer Mode enabled.

    xcodegen generate
    scripts/verify.sh

That builds for the device, runs the real-pipeline test suite on it
(camera → Photos, mono develop, record, playback, flip), and lints.
The device is the only verification target — never a simulator.

## Using the app

- **PHOTO**: tap the shutter — a DNG (or HEIC where RAW is unavailable)
  lands in Apple Photos, in the pikicam album.
- **BNW**: tap `[ BNW OFF ]` to toggle — shots and clips render through
  the same monochrome look (video via the composition path).
- **VIDEO**: switch the mode strip to VIDEO, tap to record (MM:SS
  readout), tap the square to stop — the clip saves with audio and
  plays in-app from the archive.
- **Flip** the arrow button for the front camera; the archive (grid,
  bottom-left) pages swipe-style with prefetch; BACK always returns to
  the camera.

## What the code does not say

Why-decisions live in the local `docs/` tree (kept with the device that
produced the evidence, not on GitHub): the diagnosis that rebuilt this
app, the walk definition and budgets, the skin token table and its HIG
deviations, the interaction teardown with anti-patterns, the failure
taxonomy, and the measurement artifacts (ffprobe byte-truth, frame-time
decision, parity protocol). Tests enforce the skin and the look in-repo;
nothing is a claim without a judge.

## Honest non-goals

No scan modes, numeric lines, manual dials, calibration documents,
probe apps, design-token matrices, journal crash recovery, viewer
develop panels. Deleted one commit each — `git log` is the record.

## Verify & contribute

    scripts/verify.sh          # device suite + lint; the only gate

Commits: conventional `type(scope): description`, atomic, every commit
launchable. Skin rules and the banned-construct greps are enforced by
`pikicamTests` — review doesn't carry them.

## License

Proprietary — no license chosen yet.
