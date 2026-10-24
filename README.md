# pikicam — inversion documentation

This README records what the code does not say: intent, decisions, rejected
alternatives, external constraints, and gotchas. What the system *does* is in
the source.

## Intent

A photographer wants the iPhone sensor read out as an instrument: one
un-fused Bayer exposure kept forever as the untouched DNG, and a develop look
that is entirely pikicam's code. iOS defaults to fused, tone-mapped output;
the default RAW develop path silently re-applies Apple's rendering. pikicam
captures one honest Bayer frame, stores it losslessly, develops it with our
own pipeline, and is truthful in the UI about every stage that is or is not
ours.

Platform ceilings, device-probed (evidence in docs/DECISIONS.md):
- Bayer RAW photo: single, un-fused, <=12 MP; `.speed` prioritization is
  mandated by the SDK header, not taste.
- Live preview is always ISP output; the UI says `PREVIEW: ISP` rather than
  pretending otherwise.
- Video frames are always ISP-demosaiced. What pikicam owns: determinism
  (GDC/HDR/Center Stage/stabilization off), manual parity with photo, and the
  look applied per-frame to TWO files — an untouched ISP master and a
  rendered rendition.
- Scan assembles from ISP frames; the Info sheet says so.

## Data flow

Photo capture is a composition of small typed steps (compose over the arrow
chain — no orchestration object):

```
CaptureFlow.run : CaptureRequest -> Future<LibraryItem>

  AVCaptureClient.capture : CaptureRequest -> RawCapture        (throws CaptureError)
  FileJournal.persist     : RawCapture -> JournalEntry          (throws JournalError)
  developForCapture       : RawCapture -> Rendition?            (divergent: failure -> nil, capture never lost)
  SaveRetry.perform       : (RawCapture, Rendition?, AdjustmentPayload) -> LibraryItem
                                                                  (retry, backoff [0.5, 1, 2] s)
  FileJournal.complete    : CaptureID -> Void                   (entry removed — the journal is a
                                                                  to-do list, not a log)
```

Develop, one frame:

```
CIRAWFilter(imageData:identifierHint:) : Data -> CIRAWFilter
NeutralRecipe.apply                   : CIRAWFilter -> RecipeApplication
PikicamLook kernel                    : CIImage -> CIImage
crop(to: FrameGeometry)               : CIImage -> CIImage
HEICEncoder.heic10                    : CIImage -> Rendition
```

Video: AVCaptureVideoDataOutput -> SampleBufferForwarder ->
AVRecordingClient.ingest fans each frame out to two writers (untouched
master; PikicamLook rendition, P3-D65 primaries, HLG transfer), drops
counted, provenance timestamped. Scan: AVScanClient.ingest renders one slit
column per frame into an MTLTexture; a drop duplicates the previous column
and is counted.

## Decisions and rejected alternatives

| Decision | Rejected | Why |
|---|---|---|
| Actor on DispatchSerialQueue executor for AVFoundation state | plain actor + queue.async bridging | the executor form makes the session queue the isolation domain; compiles under complete concurrency (ledger L8) |
| Typed Result boundary in PhotoBoundary | typed-throws closures | this toolchain mis-infers `throws(E)` in closure literals; named functions only; Result keeps the boundary total |
| Untouched DNG + HEIC rendition + PHAdjustmentData | editing the DNG | Revert must return to the sensor's file; edits are replayable data |
| Deterministic triangular dither in the kernel | RNG dither | identical input yields byte-identical output (fingerprint tests) |
| Two CIContexts (interactive / export) | one shared context | cache vs memoryTarget conflict; export wants memoryTarget 1024 |
| Mono before the tone curve | mono after curve | the curve's meaning stays identical between colour and mono |
| Personal team V7BF8622ZR for device builds | paid team GV4GK5XGN5 | the paid account is not signed into Xcode; identity exists but cannot mint profiles headlessly (DECISIONS D1) |

## Constraints (outside the repo)

- Device truth is the connected iPhone 12 mini (iPhone13,1, iOS 26.6.2):
  two rear lenses, both `'rgg4'` Bayer; no telephoto; flash+RAW legal; ZSL
  defaults ON and must be disabled; low-light boost unsupported — setting it
  throws; `.balanced` on RAW settings throws on-device (amends L3).
- Free provisioning: 3 app slots per device, 7-day profile life, no workflow
  OAuth scope — the device suite stays local; hosted CI is host-side only.
- darktable is uninstallable on this host (upstream cask disabled); the
  bracket oracle is LibRaw + RawTherapee (DECISIONS D2).
- PTC/shutter/WB calibration numbers need one owner-assisted recapture with
  the phone unlocked and face-up; both automated sessions photographed a
  face-down phone. Procedure: docs/CALIBRATION.md.

## Gotchas a reader would not guess

- `CIRAWFilter(imageData:)` — 1 arg — compiles and returns a filter whose
  class is CIRAWFilterImpl, silently ignoring every modern control. Only the
  2-arg identifierHint form is real. A scanner test fails the build on the
  1-arg spelling.
- AVCapturePhotoSettings.maxPhotoDimensions reads (0,0) until set; RAW
  resolution comes from activeFormat.supportedMaxPhotoDimensions, set on the
  output after attach, never before startRunning.
- extendedDynamicRangeAmount is the linearisation lever; the outputImage
  colorSpace TAG always says Display P3 regardless of values. Trust the
  64RGBAHalf readback, never the tag.
- Apple device DNGs are single-IFD tiled: CFA tags live in IFD0 itself.
  Multi-SubIFD walking (ProRAW) finds LinearRaw instead — the inspector
  handles both shapes.
- Journal pending() synthesizes placeholder entries for unparsable
  directories instead of crashing recovery; corruption is a typed per-directory
  error.
- The .gitignore is an allow-list (`*` then `!`); new top-level paths are
  invisible to git until explicitly allowed with a reason comment.

## Open questions (marked, not invented)

- [unconfirmed] EDR headroom magnitudes on a bright Bayer scene (needs the
  face-up recapture).
- [unconfirmed] PhotoKit A/B/C pass criteria on-device: every creation
  variant currently returns PHPhotosError 3300 even when authorized; control
  and full-shape probes are armed for the next device run.
- [unconfirmed] VoiceOver legibility over bright scenes, haptic feel,
  physical-chart deltaE — owner-physical items in docs/DEVICE-CHECKLIST.md.
- [unconfirmed] Video budget ladder (p95/p99 frame times) under two writers —
  soak pending the same unlocked-device session.

## Verify

    xcodegen generate
    scripts/verify.sh   # device suite + lint + oracles (device connected, unlocked)

Swift 6, complete strict concurrency, warnings-as-errors. Unit and UI tests
run on the connected iPhone 12 mini only — never a simulator.
