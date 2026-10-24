# pikicam

An iOS camera that captures one un-fused Bayer RAW exposure, keeps it
untouched, and develops it with pikicam's own colour pipeline — no Apple
tone mapping, no fusion, no silent processing.

## What & why

The iPhone camera stack delivers fused, tone-mapped images by default, and
the default RAW develop path quietly re-applies Apple's rendering. pikicam
takes the opposite contract: one honest Bayer frame per press, stored
losslessly as the DNG the sensor wrote, developed by our code (exposure,
monochrome, filmic curve, gamut compression), with the UI truthful about
every stage that is or is not ours.

What pikicam does NOT do (honest scope):

- No own demosaic, noise reduction, or sharpening — Apple's front end decodes;
  the `Developer` seam is where our stage begins.
- No live "true RAW" preview — the viewfinder is always ISP output; the UI
  labels it rather than pretending.
- No video Bayer capture — iOS exposes none. Video and scan frames are
  ISP-demosaiced; what we own is determinism, manual parity, and the look
  applied to every frame (two files per clip: untouched master + rendition).
- No ProRAW mode, front camera, bracketing, focus peaking, GPS, or iPad.

## Quick start

Requirements: Mac with Xcode 26, an unlocked iPhone 12 mini connected by
cable (Developer Mode enabled, trust the developer certificate once).

    xcodegen generate
    scripts/verify.sh

`verify.sh` builds for the device, runs the unit + UI suites on it, then the
lint and oracle gates. The device is the only verification target — never a
simulator.

To explore the app on the device without capturing:

    # PikicamApp reads -pikicam.fake <scenario> for the fake dependency graph
    scenarios: standard, emptyLibrary, developFails, saveFailsTransient,
               storageFull, recorderFails, scanStalls, deniedPermissions

## How it is built

Photo capture is a composition of small typed steps (no orchestration
object):

    AVCaptureClient.capture : CaptureRequest -> RawCapture     (throws CaptureError)
    FileJournal.persist     : RawCapture -> JournalEntry       (crash-safe journal)
    developForCapture       : RawCapture -> Rendition?         (divergent: failure -> nil,
                                                               the capture is never lost)
    SaveRetry.perform       : (...) -> LibraryItem             (3 attempts, 0.5/1/2 s backoff)
    FileJournal.complete    : CaptureID -> Void                (entry removed once saved)

Develop is one Metal CI kernel chain over `CIRAWFilter` with a neutral,
read-back-verified recipe; export is HEIC 10-bit Display P3. Video runs the
same look per frame into two writers. Full data flow and per-module
internals: the source tree (`pikicam/`) mirrors this shape directory by
directory.

## What the code does not say (inversion)

Decisions, constraints, and gotchas — the WHY that is not in the source:

- **The 1-arg `CIRAWFilter(imageData:)` trap.** It compiles, returns a
  filter whose class is `CIRAWFilterImpl`, and silently ignores every modern
  control. Only the 2-arg `identifierHint:` form is real. A scanner test
  fails the build on the 1-arg spelling — that test exists because v1
  shipped this exact bug.
- **Why `.speed` everywhere.** The SDK header mandates it for Bayer RAW
  (`AVCapturePhotoOutput.h:85`); `.balanced` throws on-device. It is not a
  performance trade-off we made.
- **Why ZSL is disabled explicitly.** On the 12 mini it defaults ON; leaving
  it on would make capture-time dishonest. The device probe proved the
  default; the code just records the decision.
- **Why trust the 64RGBAHalf readback, never the colorSpace tag.** The
  `outputImage.colorSpace` tag always says Display P3 regardless of actual
  values; EDR headroom is provable only by rendering into half-float and
  measuring. The ledger row exists because two research reports disagreed
  until measured.
- **Why single-IFD handling in the DNG inspector.** Apple's device DNGs are
  single-IFD tiled (CFA tags in IFD0); ProRAW is multi-SubIFD LinearRaw. A
  walker that assumes the ProRAW shape rejects valid captures.
- **Why the journal deletes entries on success.** It is a to-do list for
  crash recovery, not a log; `RecoveryFlow` finishes pending entries exactly
  once at launch, before the shutter enables.
- **Why deterministic dither.** Random dither would break byte-identical
  fingerprint tests; the hash-of-coordinates triangular PDF keeps flat skies
  from banding without sacrificing reproducibility.
- **Why the .gitignore is an allow-list.** `*` then `!` with a reason per
  path: working corpora (old prompts, design exports, agent skills) must
  stay local; nothing lands in the repo by accident.

External constraints (outside the repo):

- Device truth is one iPhone 12 mini (iPhone13,1, iOS 26.6.2): two rear
  Bayer lenses (`'rgg4'`), no telephoto, flash+RAW legal, low-light boost
  unsupported (setting it throws).
- Free provisioning: 3 app slots per device, 7-day profiles, no workflow
  OAuth scope — hosted CI stays host-side; the device suite is local.
- darktable is uninstallable on this host (upstream cask disabled); the
  bracket oracle is LibRaw + RawTherapee.

Open questions — marked, not invented:

- [unconfirmed] EDR headroom on a bright Bayer scene (needs one face-up
  recapture session).
- [unconfirmed] PhotoKit asset-shape pass criteria on-device (every creation
  variant currently returns error 3300; probes armed for the next run).
- [unconfirmed] Video p95/p99 frame-time ladder under both writers (soak
  pending the same session).
- [unconfirmed] VoiceOver legibility, haptic feel, physical-chart ΔE —
  owner-physical items in `docs/DEVICE-CHECKLIST.md`.

## Documentation map

- `docs/DECISIONS.md` — claims ledger (every corpus claim → probe →
  verdict) and recorded deviations with reversal conditions.
- `docs/CALIBRATION.md` — measured numbers and the method behind each.
- `docs/INTEROP.md` — independent-decoder matrix for our outputs.
- `docs/COLOR.md` — sources for every colour constant in the kernel.
- `docs/DEVICE-CHECKLIST.md` — the six owner-physical verifications.
- `AGENTS.md` — the operating contract for coding agents.

## Contributing

Commits are conventional (`type(scope): description`), atomic, imperative.
Swift 6 complete strict concurrency with warnings-as-errors; banned-API and
design-token rules are enforced by scanner tests, not review vigilance.

## License

Proprietary — the owner has not chosen a license yet.
