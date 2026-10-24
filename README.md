# pikicam

An iOS camera that does exactly three things — shoot a photo, apply
black-and-white, record video — and is "working" only when the human
acceptance walk passes on the physical device.

## The three verbs

- **SHOOT PHOTO.** One tap, one capture: a Bayer DNG when the hardware
  offers it (untouched sensor file), otherwise HEIC. It lands in Apple
  Photos.
- **APPLY BLACK-AND-WHITE.** The BNW toggle develops the capture
  through the real RAW decoder with saturation zeroed and saves the
  monochrome rendition; the DNG bytes are never modified.
- **RECORD VIDEO.** One file, with audio. Backgrounding mid-recording
  saves the clip recorded so far instead of losing it.

## Working means one thing

`docs/WALK.md` holds the eight-step acceptance walk (launch, shoot,
BNW, video, archive BACK, background-save, permission denial, naive
user) and the measured budgets: launch-to-preview **0.20 s** (< 2 s),
shutter-to-capture **0.21 s** (< 1 s), save 0.18 s. A human runs the
walk before every ship; no test result substitutes for it.

## What the code does not say

- The app was rebuilt because the previous one failed the walk at its
  first step: every capture deadlocked at save (a blocking wait nested
  inside PhotoKit's performChanges) and the archive opened as a trap
  door with no way back. `docs/DIAGNOSIS.md` records the seven findings.
- Strict Swift concurrency is not negotiable here — the PhotoKit save
  crashed (SIGTRAP) until the write moved to a nonisolated helper; the
  fix is structural, visible in `CameraEngine.performPhotoWrite`.
- Photo-library denial is a banner with OPEN SETTINGS, never a broken
  camera: the shutter keeps working, saving resumes when access is
  granted. Camera and mic permissions are asked only when first needed.
- The entire skin is one file (`Support/Skin.swift`): system
  monospace, four sizes, black/white/grey, 1px rules, radius 0, motion
  0 ms, text states. `pikicamTests/SkinTests.swift` fails the build on
  any stray color, font size, radius, or animation. Deliberate HIG
  deviations and their reasons: `docs/SKIN.md`.
- The record state is inverted TEXT (REC 0:08), not a red dot — the
  greyscale test passes by construction.
- `.gitignore` is an allow-list: `/*` blocks every top-level path, each
  `!` exception carries its reason.
- Free provisioning re-trusts roughly weekly (see WALK.md operator
  notes); the symptom is a launch refusal, not a bug.

## Verify

    xcodegen generate
    scripts/verify.sh    # device build + real-pipeline suite + lint

Device only (iPhone 12 mini, iOS 26.6.2). Never a simulator.

## Non-goals

Scan modes, numeric lines, manual dials, calibration docs, probe apps,
design-token matrices, journal crash recovery, viewer develop panels.
Deleted, one commit each, walk intact — `git log` is the record.
