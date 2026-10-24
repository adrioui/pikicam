# pikicam — Rebuild Prompt v2 (device-truth edition)

You are the implementer. You run headless and alone: no human will answer questions, and nothing outside this document, the repository, and the connected device exists for you. Read this document end to end before you touch a file. Then execute it phase by phase until §16 (Definition of Done) holds.

This document **supersedes** `docs/workflow/PROMPT.md` (v1). Where both speak, v2 wins. v1 and every research file remain in the tree as **read-only input**: never edit or delete anything under `docs/workflow/`.

Repository: `/Users/adrifadilah/Desktop/pikicam` (iOS app, Swift 6, XcodeGen).
Branch for all work: `rebuild` (already created, snapshot commit `chore: snapshot pre-rebuild state` exists).

---

## 0. Why v2 exists — what the deeper task actually is

v1 was written from digested artifacts: seven research reports, a design export, and a legacy codebase. A top professional in computational-photography pipeline engineering would not start there. Before the spec, the four questions this rewrite is built on, answered plainly:

**(1) What would a top professional do that v1 did not ask for?**
- Treat the camera as a **measuring instrument**, not a behaviour to freeze: calibrate the sensor (photon transfer curve → read noise, full well, linearity; ISO calibration; shutter-accuracy check; white-balance neutrality proof; colour matrix vs a measured chart). "No Apple processing" is only meaningful once you can quantify what the sensor itself does.
- Validate the **look** against references by **perceptual and colorimetric metrics** (ΔE2000 against measured patch data, SSIM/FLIP against reference renders), not pixel fingerprints compared against the pipeline's own baseline — self-consistency proves nothing about correctness.
- Prove **interoperability**: captured DNGs and exported HEICs must open and render sanely in independent developers (LibRaw, darktable, RawTherapee, Lightroom if licensed, Apple Photos), not merely pass a validator.
- Fuzz parsers with **coverage guidance and sanitizers** (libFuzzer + ASan/UBSan on a macOS host harness), not a fixed byte-flip corpus.
- Set every tolerance from **measured variance** (N ≥ 10 runs, band = 4σ), not from a single-shot gap; keep deterministic software-renderer goldens for CI plus per-SoC goldens on device.
- Engineer for **power, thermals, memory and interruption**: soak tests, injected interruptions mid-capture/mid-record, p95/p99 frame-time budgets — means hide judder.
- Be honest about the **display path** and **file colour tags** (CICP/HLG readback), about **adjustment-data versioning**, and about OS-drift: a golden-regression harness that re-baselines deliberately across iOS point releases.

**(2) The rawest material they would start from** (v1 started from other agents' summaries):
The physical device and the DNGs it produces; the iOS 26.x SDK headers, `.swiftinterface` and `.apinotes` themselves; the Adobe DNG Specification 1.7+ and TIFF/EP (ISO 12234-2) and the **Adobe DNG SDK source** (dng_validate as oracle); **LibRaw source**; **darktable's filmic-rgb and gamut-compression source**; RawTherapee; the **ACES reference gamut compression** (CTL/OCIO); the ICC.1 specification; CIE 15 colorimetry and the **Sharma 2005 ΔE2000 test vectors**; the **BabelColor ColorChecker 24 measured dataset**; ISO 12232/15739/14524 measurement standards; Apple's sample code and WWDC transcripts. Everything in this repo — v1 included — is *below* all of those.

**(3) The specific methods and tools:**
On-device probe apps driven by `devicectl`; `os_signpost`/Instruments; MetricKit; Python science stack (`numpy`, `rawpy`, `colour-science`, `scikit-image` SSIM, NVIDIA FLIP for video); ArgyllCMS (`icclu`/`xicclu`); `exiftool`; `ffprobe`; ImageMagick `compare`; `darktable-cli` and `rawtherapee-cli` as headless reference renders; libFuzzer/AFL++ with ASan/UBSan on a macOS host target; Swift 6 complete strict concurrency + ThreadSanitizer; SwiftLint strict, `periphery`, `swift-format`; XCUITest with `performAccessibilityAudit()` and injected interruptions; N-run benchmark statistics for every tolerance.

**(4) What, other than the implementer or the owner, shows the result is right:**
The physics (PTC linearity, WB neutrality, exposure-tag accuracy); standards validators (`dng_validate`, ICC tools, exiftool read against the DNG spec's tag table); independent decoders (LibRaw, darktable, RawTherapee, Lightroom trial, Apple Photos); the measured world (ΔE2000 vs BabelColor patches, sustained frame rates, thermal behaviour over 5-minute sessions); perceptual metrics (SSIM/FLIP); the compiler (Swift 6, warnings-as-errors); ThreadSanitizer; mutation testing; `periphery`; the CI runner from a clean checkout; and a real VoiceOver pass on device. A claim none of these can check does not ship as a claim — it ships as a question in `docs/DEVICE-CHECKLIST.md`.

v2 encodes all of this. It also inherits the strongest part of v1 — the sinthink design discipline (`/Users/adrifadilah/.claude/skills/sinthink`) — and makes it the spine of the whole document (§6), not one section.

---

## 1. Epistemic constitution — nothing in this repository is true yet

**Every artifact in the repo is a hypothesis**: `docs/workflow/PROMPT.md` (v1), research 01–07, the design export, the legacy code, and their "MEASURED" labels. Research 06's numbers were measured by another agent on another runtime; they are starting hypotheses, not facts. No claim from them may inform code until a probe you ran re-establishes it on **this device**.

**Evidence ladder** (highest first):
1. A probe you compiled and ran on the connected iPhone 12 mini (iOS 26.6.2).
2. The iOS 26.x SDK headers, `.swiftinterface` and `.apinotes` files.
3. The Adobe DNG Specification (1.7+) and the Adobe DNG SDK source.
4. Source code of independent RAW developers (LibRaw, darktable, RawTherapee) and ACES reference transforms.
5. Apple documentation and WWDC transcripts.
6. Repo artifacts (v1, research, legacy code) — **lowest**. Prose never outranks measurement.

**Discrepancy protocol.** When a probe contradicts any artifact (including this document), follow the probe, change the implementation, and record the discrepancy in `docs/DECISIONS.md` (date, decision, why, what would change it). v1 §1 rule 9's spirit survives; its simulator-era specifics do not.

**Claims-under-test ledger.** `docs/DECISIONS.md` opens with this table. Each row is a load-bearing claim from the repo corpus → the probe that re-establishes it → status (`proven | refuted | amended`). Seed rows (add every further claim you rely on):

| Claim (source) | Probe on the 12 mini |
|---|---|
| `CIRAWFilter(imageData:)` 1-arg binds to deprecated `CIFilter` category → stub (research 06 C2) | AST-dump typecheck + runtime class print in probe app |
| `CIRAWFilter(imageData:identifierHint:)` returns real class; all §8.2 controls assign+read back (research 06 C2) | per-control assign/readback loop, dumped as JSON |
| RAW settings default `photoQualityPrioritization = .speed`; `.quality` throws; `.balanced`/`.speed` accepted (research 06 C9) | settings-object print + exception trap |
| RAW settings `maxPhotoDimensions` reads (0,0) until set (research 06 C8) | print on device |
| EDR headroom: `extendedDynamicRangeAmount` 1→max≈1.85, 2→≈2.69 linear (research 06 C6) | `64RGBAHalf` CVPixelBuffer readback on device A14 |
| `render(_:toBitmap:.RGBAh)` into malloc traps at full size (research 06 C6) | trap probe (debug only) |
| `heif10Representation` async returns `Data?`; `CIContextOption.memoryTarget` exists (research 07) | compile probe |
| `AVCaptureClient` actor on `DispatchSerialQueue` executor compiles Swift 6 warnings-as-errors (v1 §6.9) | compile probe |
| PhotoKit resource shapes A/B/C behaviour (v1 §4.3.2) | device Photos library probe, pass criteria below |
| Simulator-era unknowns: Bayer formats per lens, `supportedMaxPhotoDimensions`, GDC support, Center Stage support, ZSL default, flash+RAW legality, HLG 10-bit video formats, `AVAssetWriter` acceptance | device probe app, JSON dump |
| `onCameraCaptureEvent` (AVKit), `RotationCoordinator`, readiness coordinator, deferred start, WB temperature/tint lock (research 07) | compile+run probes |
| Tone-curve / gamut-compression reference behaviour (darktable filmic) | render fixture through `darktable-cli` neutral pipeline, compare statistics |

The device closes v1's biggest gap: v1's only DNG fixture is Apple ProRAW/LinearRaw, which the app never captures. **On the 12 mini, capture real Bayer DNGs** and they become the primary develop fixtures (§4.3).

---

## 2. The instrument — device truth, no simulator

- The verification target is the connected **iPhone 12 mini** (iPhone13,1, iOS 26.6.2, Developer Mode enabled, paired; signing identity "Apple Development: adrifaddlh@gmail.com (GV4GK5XGN5)", team `GV4GK5XGN5`). Set `DEVELOPMENT_TEAM: GV4GK5XGN5` in `project.yml` — a recorded deviation from v1 §6.1, made because the owner connected the device for use.
- **Never use a simulator** (owner instruction). All builds, tests, probes and UI tests run on the device via `-destination 'platform=iOS,id=<udid>'` (`xcrun devicectl list devices` → `A1AA422E-FCD9-56CD-B667-51CCBB84E1B2`). Every v1 instruction that says "on the simulator" is amended to "on the device".
- `scripts/verify.sh` runs everything locally against the device. `.github/workflows/ci.yml` keeps hosted-runner checks that need no device: `xcodegen` determinism, `xcodebuild build` (generic iOS device, no signing), SwiftLint strict, `periphery`, the macOS-side fuzz harness, and the Python reference-diff oracles. Record the "no hosted device" limitation in `docs/DECISIONS.md`.
- The 12 mini's hardware shapes the product truthfully: dual rear physical cameras (wide + ultra-wide; **no telephoto** — the lens rail shows only what exists), a real flash (flash+RAW legality is probed, §7), A14 GPU (golden images keyed to it).
- What still cannot be verified without the owner's hands stays in `docs/DEVICE-CHECKLIST.md` — now short: photographing a physical chart, feeling haptics, judging chrome legibility over real scenes, one manual Revert check in Apple Photos.

---

## 3. Raw materials (binding authority order)

1. **The device.** Probe app (`pikicamProbes` target, §14) committed and runnable on the 12 mini.
2. **The SDK.** `SDK=$(xcrun --sdk iphoneos --show-sdk-path)`; headers, `<F>.framework/Modules/<F>.swiftmodule/*.swiftinterface`, `.apinotes`. Header comments are Apple's most authoritative behaviour docs.
3. **Adobe DNG Specification 1.7+** (+ TIFF 6.0, TIFF/EP ISO 12234-2) and the **Adobe DNG SDK** (github.com/adobe/dng_sdk): build `dng_validate` (macOS host) as the conformance oracle for every DNG written or captured. If the build is impractical, record it and use `exiftool` + LibRaw decode as the proxy oracle.
4. **Independent developers' source:** LibRaw (via `rawpy` and source), darktable (`filmicrgb.c`, gamut compression), RawTherapee — source is the reference for §8.3's curve and gamut stages; their CLIs are render oracles.
5. **ACES reference gamut compression** (CTL/OCIO) — the parameterization reference for §8.3 stage 3.
6. **ICC.1:2022** (rendering-intent semantics), **CIE 15** colorimetry, **Sharma et al. 2005 ΔE2000 test vectors** (unit-test the implementation against them), **BabelColor ColorChecker 24 dataset**.
7. **ISO 12232 / 15739 / 14524** — the measurement standards behind Phase A calibration.
8. **Apple sample code** (AVCam lineage) and **WWDC transcripts** (ProRAW/RAW capture, `AVCapturePhotoOutput`, 10-bit HDR video). Transcripts, not blog posts.
9. **Halide's Process Zero write-ups** — corroboration only, never authority.
10. **Repo artifacts** — hypotheses (§1).

Tooling (install if missing, record versions): `xcodegen`, `swiftlint`, `periphery`, `exiftool`, `swift-format`, Python venv with `rawpy numpy imageio colour-science scikit-image`, `darktable-cli`/`rawtherapee-cli` (brew casks), ImageMagick, `ffmpeg` (ffprobe), ArgyllCMS, `muter` (Phase 10). A macOS-side libFuzzer/ASan/UBSan harness target for the parsers (§4.6).

---

## 4. Binding methods — how correctness is measured

**4.1 Probe-first.** Any API name or behavioural fact from the corpus that is not already probe-backed gets a probe (§1 ledger) before code relies on it. Probes live in the committed `pikicamProbes` target and stay runnable on the device.

**4.2 Stage isolation matrix.** For `CIRAWFilter` on the device: render the Bayer fixture with every §8.2 control at neutral, then each control alone at its extreme; diff (max/mean/changed-pixel count). A control that moves nothing is recorded inert; inert at neutral *and* extreme is a removal candidate next recipe version — never a silent no-op. Commit the matrix to `docs/DECISIONS.md`.

**4.3 Calibration (Phase A) — the camera as instrument.** Produce `docs/CALIBRATION.md`, every number with its method:
- **PTC (photon transfer curve):** flat-field DNG series across exposure times and ISOs (device probe captures automatically; lens capped, scene = even wall or blank screen in darkness); mean–variance per ISO → read noise (e⁻), full-well estimate, linear range; verify stored sensels are linear in exposure time and ISO within the measured band.
- **Shutter accuracy:** tagged `exposureDuration` vs. set value across the ladder.
- **WB neutrality:** grey/white patch shots under D65-ish illumination; after our pipeline with as-shot WB, neutral patches must have Δa*/Δb* ≈ 0 within a measured band.
- **Colour fidelity — two tiers, honestly recorded:** Tier 1 if the owner provides a ColorChecker 24 (photograph it via the probe; `scripts/colorcheck.py` computes ΔE2000 per patch vs BabelColor; median ΔE ≤ 8 is the v1 bar, aim lower). Tier 0 without a chart: WB neutrality + exposure linearity + interop sanity, and the README says so.
- **Fixtures:** device-captured Bayer DNGs (flat series, chart scene, one rich scene) registered in `docs/CALIBRATION.md` by SHA256, git-ignored like the ProRAW fixture; plus a **tiny synthetic Bayer DNG generator** (committed, `dng_validate`-clean) for parser unit tests. The ProRAW `IMG_1361.DNG` remains only as an adversarial/foreign-input fixture.

**4.4 Dual render oracles + perceptual gates.** `scripts/reference-diff.py` renders the fixture through (a) our neutral pipeline read back as linear floats and (b) **both** LibRaw (camera WB, gamma off, no auto-bright) and `darktable-cli` neutral scene-referred; compares scene-linear per-channel statistics (mean/median/p1/p99/max). The two references bound the harness: our pipeline must sit within the committed tolerance of the LibRaw/darktable *bracket*. Look-regression tests use SSIM (stills) and FLIP (video frames) with thresholds from Phase A variance, so GPU rounding noise cannot fail and real look changes cannot pass.

**4.5 Statistical tolerances and goldens.** Every fingerprint/budget/tolerance comes from N ≥ 10 device runs: band = mean ± 4σ (or the tighter of that and the half-gap heuristic v1 used). Golden images: deterministic **software-renderer** renders committed for CI-stable assertions; per-SoC (A14) device goldens keyed by device model; re-baselining requires a `docs/DECISIONS.md` entry naming the OS build.

**4.6 Fuzzing.** `DNGInspector` and `FileJournal` fuzzed two ways: (a) the committed deterministic corpus (seeded mutations of fixtures — byte flips, truncations, oversized/underflowing IFD fields), 50-variant smoke per suite run, full corpus in CI; (b) a **coverage-guided libFuzzer harness on macOS** (host target wrapping the same parser sources) with ASan/UBSan; crashes filed as P0 defects. Typed errors only — never crash, never hang (per-case timeout).

**4.7 Soak, power, interruption.** 5-minute device recording sessions (thermal state sampled; pause/resume banner behaviour observed); Instruments Energy Log for a capture+develop+save cycle; interruption injection tests (XCUITest: background/foreground mid-capture, phone-call simulation via `devicectl`, lock mid-record) asserting journal recovery and no data loss; frame-time **p95/p99** budgets for the video look pass, not just means.

**4.8 Interop matrix.** Committed `docs/INTEROP.md`: for one captured DNG and one exported HEIC and one recorded pair (.mov master/rendition): opens in LibRaw, darktable, RawTherapee, Apple Photos (device), Lightroom if licensed; tags via `exiftool`/`ffprobe` read against the spec tables; CICP/HLG colour tags on video read back and asserted by a unit test. Any cast/orientation/garbage render is a defect.

**4.9 Concurrency, structure, mutation.** Swift 6 language mode, complete strict concurrency, warnings-as-errors; ThreadSanitizer run of the unit suite on device; `muter` score on `Domain/`+`Support/` recorded with surviving-mutant dispositions; `periphery scan` zero; SwiftLint strict zero; `swift-format` clean; file ≤ 300 lines, function ≤ 40 lines enforced by a scanner test.

---

## 5. Product mission and platform ceilings (unchanged in substance from v1 §0/§3 — restated for a standalone document)

**camera → our code → no iPhone post-processing.** pikicam captures one un-fused Bayer RAW exposure from a physical rear camera; keeps the untouched DNG; develops it — colour or monochrome — with a pipeline whose look is our code; records video through the same deterministic device configuration with the same look applied by our code to every frame; presents a pro camera UI legible on any scene, fully accessible, honest about what the hardware did.

Ceilings stated as facts (each probe-backed where possible): Bayer RAW on iOS is single, un-fused, 1× per physical lens, ≤ ~12 MP (`.speed` prioritization rule); the live preview is always ISP output (honest design: deterministic preview + post-capture review from our pipeline); video and scan frames are always ISP-demosaiced (§10–11 own the layers that can be owned); Apple's demosaic/black-level/linearization/colour-matrix front end stays Apple's in v1 (the `Developer` protocol is the seam); `CIRAWFilter.outputImage` is tagged Display P3 regardless of actual values; with `boostAmount = 0` + EDR, values are linear-response with headroom > 1.0 — re-proven on device (§1 ledger).

Non-goals (v1 §9 list stands): own demosaic; NR/sharpening; EDR stills export; ProRAW mode; front camera; timelapse/Cinematic/slow-mo; dormant line effects as placebos; light theme; custom shutter sounds; ML subject labels; bracketing; focus peaking/zebras; GPS; iPad; lens-distortion correction; iCloud flows; localisation beyond English.

---

## 6. The design — the sinthink pipeline (this section is law)

Method: `X → Graph → Effect<A, E, R>` per `/Users/adrifadilah/.claude/skills/sinthink`. **The code IS the graph. If the code doesn't match the graph, the implementation is wrong.** Swift mapping (held exactly):

| sinthink | Swift 6 here |
|---|---|
| `Effect<A, E, R>` | `func node(_ input: In) async throws(E) -> A` on a type whose stored, protocol-typed dependencies are R |
| `Stream<A, E, R>` | `AsyncStream<A>` / `AsyncThrowingStream<A, E>` |
| Schema at boundary | `init(validating raw: Raw) throws(BoundaryError)`; framework types never leave the boundary file |
| Layer | `Dependencies` struct with `static func live() -> Self` / `static func fake(scenario:) -> Self`, built once in `PikicamApp` |
| `.pipe()` | one `mapError` per layer boundary + behaviour wrappers (`retrying`, `withTimeout`, `traced`) |
| `die` | `preconditionFailure("<invariant> — <source>")` |
| Scope | `defer`, `withDeviceLock { }` (synchronous closure), actor lifetime, `withTaskCancellationHandler`, single-resume continuation guard |

### 6.1 §1 Shapes — the nouns (`pikicam/Domain/`, imports Foundation + CoreGraphics only)

**IDs** (distinct types, never bare strings): `CaptureID(UUID)`, `AssetID(localIdentifier)`, `ClipID(UUID)`; `LensKind { ultraWide, wide, telephoto }`; `Lens { kind, uniqueID, equivalentFocalLength }`; `BayerFormat { osType: OSType }` (constructed only after `isBayerRAWPixelFormat`).

**Records:** `ExposureMode { auto(bias: EV) | manual(iso: ISO, duration: ShutterSpeed) }`; `WhiteBalanceMode { auto | lockedCurrent | locked(Kelvin, Tint) }`; `FocusMode { continuousAuto | auto(point: NormalizedPoint) | locked(lensPosition: LensPosition) }`; `CameraSettings` (lens + exposure + WB + focus + light + aspect + crop + timer); `DeviceCapabilities` (lenses, `ExposureLimits` per lens, `WhiteBalanceLimits`, flash/focus-lock support, `rawDimensions`, `bayerFormat`; cached per configuration, time-bounded); `DeviceDeterminism` (GDC / Center Stage / video HDR / low-light / colour space as `.off | .notSupported | .on`); `CaptureRequest`; `RawCapture { id, dng: Data, provenance }`; `Provenance` (§7.5); `FrameGeometry` (aspect + crop → normalised sensor-space rect; the same value drives overlay and develop); `NeutralRecipe` (versioned), `LookParameters`, `DecoderVersion`, `RecipeApplication`; `MonoState`/`MonoPreset`/`MonoWeights` (§9); `LineProfile` + `line: Int?` tag (v1 §4.2.7's 0–23 matrix, dormant rules unchanged); `MediaKind { photo | video(ClipInfo) }`, `VideoMode { 1080p30 | 1080p60 | 4K30 | proRes422HQ }` (valid only while the budget ladder proves them); `RecordingIntent`, `VideoClip`; `ScanConfig`, `ScanResult`; `Rendition { heic: Data, pixelSize, recipeHash }`; `LibraryItem`; `JournalEntry`; dial value types (`ISO`, `ShutterSpeed`, `EV`, `Kelvin`, `Tint`, `LensPosition`, `NormalizedPoint`, `Aspect`) each with `init(clamping:to:)`; stream elements (`DeviceReadings`, `MeterReading`, `LevelReading`); `DNGFacts`; `PreviewTarget { .thumbnail(maxPixel:) | .display(pixelSize:) }`; `DisplayImage { cgImage, pixelSize }`; `RetryPolicy<E>`.

**Variants (state machines, no bags of Bools):** `SessionState { idle | configuring | running(Lens) | interrupted(reason) | unavailable(reason) | failed(CaptureError) }`; `ShutterState { ready | pressed | countdown(remaining:) | capturing(CaptureID) | saving(CaptureID) | failed(CameraError) }`; `RecordingState { idle | starting | recording(since:) | stopping | failed(RecordingError) }`; `ScanState { idle | scanning(progress:since:) | finishing | failed(ScanError) }`; `PermissionState` per permission; `DevelopState { developed | pending | failed(DevelopError) }`; `JournalPhase { captured | developed | saved }`; `AdjustmentPayload { look, geometry, recipeVersion, decoderVersion, provenance }` (versioned Codable — the `data` of our `PHAdjustmentData`; foreign format/version ⇒ `LibraryError.foreignAdjustment` and the asset renders as "Edited outside pikicam").

**Errors** (typed enums, `Error & Sendable`, context-carrying; no `String` errors; user copy in one `UserMessage` map per feature): `CaptureError` (`.noBayerLens`, `.configurationRejected(DeviceDeterminism)`, `.sessionStartFailed(code:)`, `.interrupted(reason)`, `.mediaServicesReset`, `.notBayer(pixelFormat:)`, `.unexpectedResolvedSettings(...)`, `.noFileData`, `.notADNG`, `.timedOut`, `.deviceLockFailed`); `DevelopError` (`.filterUnavailable`, `.undecodable`, `.decoderUnavailable`, `.recipeNotApplied([String])`, `.renderFailed`, `.encodeFailed`, `.cancelled`); `LibraryError` (`.notAuthorized`, `.saveFailed(code:)`, `.storageFull`, `.assetMissing`, `.resourceMissing`, `.editFailed`, `.foreignAdjustment(formatIdentifier:)`, `.albumUnavailable`); `JournalError` (`.writeFailed`, `.corrupt(CaptureID)`); `RecordingError` (`.formatUnavailable(reason)`, `.writerFailed(code:)`, `.framesDropped(Int)`, `.cancelled`); `ScanError` (`.framesStalled`, `.gpuFailed(code:)`, `.tooManyDrops(Int)`, `.cancelled`); `CameraError { capture | journal | library }`; `ViewerError { develop | library }`. `code:` payloads are Int domain codes; `NSError` never leaves its boundary file.

### 6.2 §2 A — happy-path call graphs

```
CAPTURE (one-shot per press)
ShutterIntent
  → CameraModel.makeRequest(settings, capabilities)      : CaptureRequest
  → CaptureClient.capture(request)                        : RawCapture      [boundary §6.6]
  → Journal.persist(raw, geometry, look)                  : JournalEntry
  → Developer.export(raw.dng, look, geometry)             : Rendition?      [divergent §6.4]
  → Library.save(raw, rendition, payload)                 : LibraryItem
  → Journal.complete(id) ; ThumbnailStore.thumbnail(item) → dock

VIEW   CaptureID → Library.dng(for:) → Developer.image(dng, look, geometry, .display) : DisplayImage
EDIT   LookParameters → Library.dng(for:) → Developer.export → Library.commitEdit(id, payload, rendition)
RECOVER (launch, before shutter enables)  Journal.pending() → dng → export → save → complete (idempotent)

RECORD (stateful; two files from the same frames)
RecordIntent.start(settings, look, mono, mode, audio)
  → RecordingClient.start(intent)                         [boundary]
  → frames: AsyncStream<Frame> → VideoFrameBoundary
       ├→ Writer.appendMaster(frame)                      (untouched ISP frames)
       └→ VideoLook.apply(frame, look, mono) → Writer.appendRendition(frame′)
  → RecordIntent.stop → RecordingClient.stop() : VideoClip
  → Library.saveVideo(clip, payload) ; thumbnail from first frame

SCAN (stateful; one still assembled from many frames)
ScanIntent.start(ScanConfig) → ScanClient.start → frames → ScanAssembler.append (Metal blit/frame; drop policy §11)
  → stop/completion → ScanClient.stop() : ScanResult
  → Developer.renderScan(result, look, mono) : Rendition   (look once, at the end)
  → Library.saveScan(result, rendition, payload)
```

Flow bodies (`CaptureFlow.run`, `ViewerModel.load`, `EditFlow.commit`, `RecoveryFlow.run`, `RecordFlow`, `ScanFlow`) are literally these arrows as consecutive `try await` lines.

### 6.3 §3 Cardinality

| Node | Kind |
|---|---|
| `capture`, `persist`, `export`, `image`, `save`, `commitEdit`, `complete`, `renderScan` | one-shot `async throws(E) -> A` |
| `CaptureClient.sessionStates` / `.readings` (15 Hz) / `.meters` (≤10 Hz) | many |
| `MotionClient.level` (30 Hz), `RecordingClient.states`, `ScanClient.states`, `PermissionClient.states`, `Library.changes` (debounced 250 ms, own saves applied directly) | many |
| `capabilities`, `decoderVersion` choice, thumbnails (disk + `NSCache`, concurrent requests for one key share one Task) | time-bounded; cached; deduped on the actor |

Streams are consumed by `@MainActor @Observable` models in `.task { for await … }` tied to view lifetime.

### 6.4 §4 E — break points, per-layer scoping, the one divergent strategy

| Node | Failure | Strategy |
|---|---|---|
| `capture` | `.timedOut` (10 s), `.interrupted` | escape: surface `CameraError`, restore device state, shutter → `.ready` |
| `capture` | `.notBayer`, `.unexpectedResolvedSettings`, `.notADNG` | escape + fault log (platform contract violation) |
| `capture` preconditions | zoom ≠ 1, crop factor ≠ 1, ProRAW on, processed format set | **die** (our invariant; `AVCapturePhotoOutput.h:85`) |
| `persist` | `.writeFailed` | escape: abort flow, "Not saved: storage full" banner; nothing proceeds unjournaled |
| `export` at capture | any `DevelopError` | **divergent strategy** (below) |
| `save` | transient `PHPhotosError` | retry ×3 (0.5/1/2 s backoff) then escape (journal keeps it) |
| `save` | `.notAuthorized`, `.storageFull` | escape: journal retained; actionable banner |
| session start | `.mediaServicesReset` | retry once (rebuild), then escape |
| album lookup | `.albumUnavailable` | retry once by recreating album, then escape (save succeeds; listing falls back to journal IDs) |
| adjustment decode | `.foreignAdjustment` | escape: "Edited outside pikicam", develop from neutral |
| `image(.display)` | `.cancelled` / other | swallow (expected) / escape: viewer banner with Retry |
| record / scan | `.framesStalled`, `.gpuFailed` (after one retry), `.tooManyDrops`, `.writerFailed` | escape: typed state; scan saves the partial assembly marked `PARTIAL` |
| continuation resumed twice / never | — | **die** in debug (`assertionFailure`); release: second resume logged+ignored |

**E scoping at graph layers** (each layer's error type is a complete enumeration of what *it* received; consumers never see implementation errors from deeper):

```
AVFoundation NSError → CaptureError        (inside AVCaptureClient)
CI nil/exception      → DevelopError       (inside CoreImageDeveloper)
PHPhotosError         → LibraryError       (inside PhotoKitLibrary)
sample-buffer/Metal   → RecordingError | ScanError (inside the AV clients)
Capture|Journal|Library → CameraError | ViewerError (inside the flow)
feature error         → UserMessage        (inside the view model)
```

**The one divergent strategy** — `developForCapture`: a develop failure must not lose the capture, while a save failure must. Handled inline, *named*, and the only `do/catch` inside any flow:

```swift
/// Divergent strategy: develop failure falls back to a DNG-only save (DevelopState.pending).
private func developForCapture(_ raw: RawCapture, _ entry: JournalEntry) async -> Rendition? {
  do { return try await deps.developer.export(raw.dng, look: entry.look, geometry: entry.geometry) }
  catch { log.error("develop at capture failed: \(error, privacy: .public)"); return nil }
}
```

`try?` appears nowhere in `pikicam/`.

### 6.5 §5 R — dependencies as compile-time proof

Protocols (all `Sendable`): `CaptureClient` (`capabilities`, `start(lens:)`, `stop()`, `apply(CameraSettings)`, `capture(CaptureRequest) -> RawCapture`, streams `sessionStates`/`readings`/`meters`, `preview: PreviewSource`), `Developer` (`image`, `export`, `inspect`), `Library` (`save`, `saveVideo`, `saveScan`, `items`, `dng(for:)`, `commitEdit`, `revert`, `delete`, `changes`), `Journal`, `RecordingClient`, `ScanClient`, `PermissionClient`, `MotionClient`, `ThumbnailStore`. `struct Dependencies: Sendable { … ; static func live() -> Self; static func fake(scenario: FakeScenario) -> Self }` built once in `PikicamApp`; UI tests select fakes via launch argument `-pikicam.fake <scenario>`. Models receive exactly what they use via `init`. No singletons; `.shared`/`.default()` only inside live clients and `Dependencies.live()`. Everything that sleeps or measures takes the injected `Clock`.

### 6.6 §6 Boundary — untrusted → trusted, one file per boundary

| Boundary | File | Raw in | Trusted out |
|---|---|---|---|
| AVFoundation photo | `Capture/PhotoBoundary.swift` | `AVCapturePhoto`, resolved settings | `RawCapture` (all §7.4 checks) |
| DNG bytes | `Develop/DNGInspector.swift` | `Data` | `DNGFacts` (TIFF header, `PhotometricInterpretation`, CFA tags, `UniqueCameraModel`, orientation, `BaselineExposure`, `AsShotNeutral`) via `CGImageSource` + `CIRAWFilter.properties` + minimal IFD walker for tags ImageIO hides |
| Device limits | `Capture/CapabilitiesProbe.swift` | `AVCaptureDevice`/`.Format`/output | `DeviceCapabilities` |
| User input | `Domain/Exposure.swift` etc. | `Double` from dials | clamped value types |
| Photos | `Library/AssetBoundary.swift` | `PHAsset`, resources, `PHAdjustmentData` | `LibraryItem` / `LookParameters` |
| Video frames | `Capture/VideoFrameBoundary.swift` | `CMSampleBuffer` | trusted `Frame` (format, timing, rotation) |
| Persistence | `Library/FileJournal.swift`, `AdjustmentCodec.swift` | JSON on disk; `PHAdjustmentData` | versioned Codable; unknown version ⇒ `.corrupt` / `.foreignAdjustment` |

Inside the boundary, trust the types: no re-validation, no optional chaining on trusted values.

### 6.7 §7 Behavior — wrappers that do not change the graph (`pikicam/Support/`)

`mapError` (the only place a heterogeneous body becomes one typed error), `retrying(RetryPolicy, clock:)`, `withTimeout(d, clock:, onTimeout:)`, `traced(name)` (OSSignposter interval + Logger line), `withCheckedContinuationOnce` (atomic single resume via `Synchronization.Mutex`). Wrapping at the call site: `try await traced("save") { try await retrying(.photosSave, clock:) { try await library.save(…) } }` — nothing inside `save` knows about retry. Phase 1 lands these with a compile test of the §6.10 exemplar so type-checker surprises surface early.

### 6.8 §8 Scope — acquire/release tied to lifecycle

`AVCaptureClient` is an actor on AVFoundation's session queue (`DispatchSerialQueue` + `unownedExecutor` — compile-probe first, §1 ledger; fallback: plain actor + `queue.async` continuations for blocking calls, recorded). `AVCaptureSession` lives inside the actor; the preview gets it only via `PreviewSource.live(SessionHandle)` — a `Sendable` wrapper whose one-line proof comment cites AVFoundation's permission to set the preview layer's session from the main thread (the single allowed `@unchecked Sendable`). `withDeviceLock` is synchronous-by-type so no `await` can occur inside. Photo delegates are retained by the actor in `[Int64: Delegate]` keyed by `resolvedSettings.uniqueID` until `didFinishCaptureFor` — no associated objects. `CIContext`s live as long as the `CoreImageDeveloper`; renders in `autoreleasepool` with `Task.checkCancellation()` between stages. Journal: directory per capture; `persist` creates, `complete` removes; recovery before shutter enables. `beginBackgroundTask` wraps develop+save. Recorder owns its writer session; `stop` closes files before `.idle`; scene-phase background stops recording; launch cleanup removes partial files and reports "recording lost". Motion updates tied to view task lifetime via `withTaskCancellationHandler`. Viewer renders are Tasks keyed by `CaptureID`, cancelled on page change.

### 6.9 §9 Test — swap R, same graph

Every graph in §6.2 runs unchanged against `Dependencies.fake(...)`. If a test needs something not in `Dependencies`, the design has a hidden dependency: fix the design, not the test.

### 6.10 §10 Code — gen body = A, pipe = E

Flow bodies are the arrows of §6.2 with **no `do/catch`** except §6.4's named divergent strategy. One `mapError` per flow:

```swift
func run(_ request: CaptureRequest) async throws(CameraError) -> LibraryItem {
  try await mapError(CameraError.init(mapping:)) {
    let raw = try await deps.capture.capture(request)                    // CaptureError
    let entry = try await deps.journal.persist(raw, geometry: request.geometry, look: .standard)
    let rendition = await developForCapture(raw, entry)                  // divergent
    let payload = AdjustmentPayload(entry, rendition: rendition)
    let item = try await traced("save") { retrying(.photosSave, clock: deps.clock) {
      try await deps.library.save(raw, rendition: rendition, payload: payload) } }
    try await deps.journal.complete(entry.id)
    return item
  }
}
```

`CameraError.init(mapping:)` switches exactly the error types the body's nodes declare; anything else is `preconditionFailure`. Each layer defines its own `init(mapping:)`; each has an exhaustiveness test. Views are dumb (render `@Observable` state, send intents); the only view-level AVFoundation is `PreviewLayerView.swift` and the AVKit `onCameraCaptureEvent` import in `CameraScreen.swift`.

---

## 7. Capture contract

**7.1 Devices.** Rear physical devices only (`.builtInUltraWideCamera`, `.builtInWideAngleCamera` — telephoto probed, absent on 12 mini). A lens is offered only if its `availableRawPhotoPixelFormatTypes` (instance property, read per configuration) contains a format passing `AVCapturePhotoOutput.isBayerRAWPixelFormat(_:)`. Per-lens values (RAW formats, `supportedMaxPhotoDimensions`, ISO/exposure/WB limits) are re-read inside every configuration transaction and cached per configuration, never per launch. Front camera never (no Bayer RAW); virtual devices never (no `.custom` exposure / custom WB). Equivalent focal length computed in-transaction as `round(18 / tan(activeFormat.videoFieldOfView° / 2))`; cross-checked against EXIF `FocalLenIn35mmFilm` after first capture (> 2 mm difference ⇒ log + `≈` on the label). `CROP` is a framing choice, never a lens.

**7.2 Format and dimensions.** `sessionPreset = .photo`; after addInput/addOutput set `photoOutput.maxPhotoDimensions` to the largest (by pixel count) of `device.activeFormat.supportedMaxPhotoDimensions` before `startRunning()`; per capture `settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions` (RAW settings read (0,0) until set — ledger). Bayer format chosen with `availableRawPhotoPixelFormatTypes.first(where: AVCapturePhotoOutput.isBayerRAWPixelFormat)` — no literal OSType list. Log `activeFormat`, RAW formats, chosen dimensions once per configuration (`os.Logger`, category `capture`).

**7.3 Device determinism** (one transaction; `beginConfiguration`/`commitConfiguration`; device locked synchronously; no `await` inside the lock): `centerStageControlMode = .app` + `centerStageEnabled = false` (class properties, pre-start); if `isGeometricDistortionCorrectionSupported` then `isGeometricDistortionCorrectionEnabled = false` (preview FOV = RAW FOV; `AVCaptureDevice.h:2267-2286`); `automaticallyAdjustsVideoHDREnabled = false` and `isVideoHDREnabled = false` where supported; `session.automaticallyConfiguresCaptureDeviceForWideColor = false` **first** (`AVCaptureSession.h:597`), then `activeColorSpace = .P3_D65` if the **format** supports it else `.sRGB` (`AVCaptureDevice.h:3411`); never Apple Log (`AVCapturePhotoOutput.h:115-116`); low-light boost stays off (assert `automaticallyEnablesLowLightBoostWhenAvailable == false`); preview connection `preferredVideoStabilizationMode = .off`. Every value read back after commit into `DeviceDeterminism`; mismatch ⇒ typed `.configurationRejected`. Unsupported features recorded `.notSupported`. **On the 12 mini, the probe records which of these are supported at all** — Centre Stage may not exist there; the record is the truth.

**7.4 Per-shot settings and boundary validation.** Built in one place, `CaptureRequest.makeSettings()`: `AVCapturePhotoSettings(rawPixelFormatType:)`; `photoQualityPrioritization = .speed` (explicit — the rule is our code, `AVCapturePhotoOutput.h:85`); `maxPhotoDimensions = output.maxPhotoDimensions`; `flashMode = .off` pending §7.6; `metadata` injects `kCGImagePropertyTIFFSoftware = "pikicam <version>"` (no GPS — non-goal). At configuration: `maxPhotoQualityPrioritization = .speed`; `isZeroShutterLagEnabled = false` where supported (capture time honest); `isResponsiveCaptureEnabled = false`, `isFastCapturePrioritizationEnabled = false` where supported; output-level `isAutoDeferredPhotoDeliveryEnabled = false` (deferred proxies are never RAW). Immediately before `capturePhoto`: assert `device.videoZoomFactor == 1.0` and connection `videoScaleAndCropFactor == 1.0` — violation is `preconditionFailure` citing `AVCapturePhotoOutput.h:85`; device zoom stays 1.0 forever in PHOTO (pinch = framing crop only). `setPreparedPhotoSettingsArray([fresh representative])` after configuration and after each lens switch (fresh object each time — settings are single-use; `uniqueID` reuse throws); readiness from `AVCapturePhotoOutputReadinessCoordinator`, not a hand-rolled bool.

A capture is accepted only when: `photo.isRawPhoto == true`; pixelBuffer format (if any) equals the requested Bayer OSType; resolved settings: `rawPhotoDimensions` non-zero, `expectedPhotoCount == 1`, and fusion/CADC/stabilization/red-eye all false; `fileDataRepresentation()` non-nil, TIFF header (`II*\0`/`MM\0*`), parses as DNG whose raw IFD has `PhotometricInterpretation == 32803` (CFA) — `34892` (LinearRaw/ProRAW) is **rejected** as Apple-processed; if CFA data lacks CFA geometry tags, accept and record `cfaTagsPresent = false`. Each failure a distinct typed case.

**7.5 Provenance at shutter:** device `uniqueID`/`deviceType`, lens, `lensAperture`, `activeFormat` description, Bayer OSType, `rawPhotoDimensions`, `iso`, `exposureDuration`, `lensPosition`, WB gains + temperature/tint, exposure mode, `DeviceDeterminism`, ZSL state, iOS + app version. F-number also lives in the DNG's EXIF and is read on demand (no `AVCaptureDevice.aperture` exists).

**7.6 Light.** Default none. The 12 mini has a true flash: the device probe attempts a RAW capture with `flashMode = .on`; if it succeeds and `supportedFlashModes.contains(.on)` for RAW-only settings, offer `FLASH`; else offer `TORCH` (labelled torch; settle via `torchLevel` KVO, 300 ms timeout). Never call a torch a flash. Until probed, `TORCH` only.

**7.7 Manual exposure, WB, focus** (physical devices; clamp to `activeFormat` limits): exposure auto(bias)/manual via `setExposureTargetBias` / `setExposureModeCustom(duration:iso:)`; WB `auto | lockedCurrent | locked(kelvin:tint:)` via the temperature/tint lock (`AVCaptureDevice.h:1782`), pre-validated through `deviceWhiteBalanceGains(for:)` against `[1, maxWhiteBalanceGain]` — reject, never clamp-after (`:1855`); focus continuous / point / `locked(lensPosition:)` guarded by `isLockingFocusWithCustomLensPositionSupported`. Completions awaited **outside** the device lock with `withTimeout(1 s)`. Live readings via KVO as `AsyncStream<DeviceReadings>` at 15 Hz. AE/AF lock toggle locks current values.

**7.8 Lifecycle.** `startRunning`/`stopRunning` on the actor's queue, never main. Interruption/runtime-error observers inside the actor (`mediaServicesWereReset` → rebuild once); scene phase: stop on background, start on active. `stop()` waits for in-flight capture. Lens switching transactional with rollback. Deferred start (`automaticallyRunsDeferredStart` etc. — probe-verified) so preview paints early.

**7.9 Orientation.** Single source: `AVCaptureDevice.RotationCoordinator(device:previewLayer:)`; `videoRotationAngleForHorizonLevelPreview` → preview connection; `videoRotationAngleForHorizonLevelCapture` → photo connection before each capture. No `UIDevice.orientation`, no `CaptureOrientation`.

---

## 8. Develop contract

Pipeline shape (each stage re-proven on device — §1 ledger):

```
DNG → CIRAWFilter (real class; neutral recipe; pinned decoder; EDR headroom = E)
    → outputImage [tagged Display P3; values linear-response, headroom > 1.0]
    → colour-match into working space extendedLinearDisplayP3  (= scene-linear for us)
    → PikicamLook (our Metal CI kernels, post-outputImage — custom kernels inside
       linearSpaceFilter are discarded/nil it; research 06 C5.3, re-probe):
         exposure (2^EV) → MONO (§9, scene-linear, before curve) → tone curve (filmic)
         → gamut compression (soft, ACES-reference style) → [dither at encode, §9]
    → framing crop (FrameGeometry; integral-rounded cropped(to:))
    → output Display P3 (display / HEIC 10-bit)
```

**8.1 Front end.** Construct only as `CIRAWFilter(imageData: data, identifierHint: DNG.uti)` or `CIRAWFilter(imageURL:)` — a unit test fails on any 1-arg `CIRAWFilter(imageData:` in source. Require `type(of: filter) == CIRAWFilter.self` else `.filterUnavailable`; no `responds(to:)` anywhere. Decodability: `outputImage != nil` && `nativeSize != .zero`; never gate on `supportedCameraModels` (rejects valid files — ledger). `decoderVersion`: highest member of `supportedDecoderVersions` that is not `.version9`/`.version9DNG`; explicit and recorded; none qualifies ⇒ `.decoderUnavailable`. `orientation` explicit from properties; `scaleFactor`/`isDraftModeEnabled` from the render target.

**8.2 Neutral recipe** (assigned directly, every control read back into `RecipeApplication{applied, unsupported, defaultsDiffering}`; versioned `NeutralRecipe.version = 1`, golden-tested; per-image default values are re-measured on the **Bayer fixture**, and the matrix §4.2 records inert/extreme behaviour): `boostAmount 0`; `boostShadowAmount 1`; `shadowBias 0`; `localToneMapAmount 0`; `contrastAmount 0`; `sharpnessAmount 0`; `detailAmount 0`; `luminanceNoiseReductionAmount 0`; `colorNoiseReductionAmount 0`; `moireReductionAmount 0`; `extendedDynamicRangeAmount = E` (Phase A chooses 1 or 2 by the < 1 % mean-difference rule below 0.8, else 1); `isLensCorrectionEnabled false` (geometry sensor-true, matches GDC-off preview); `isGamutMappingEnabled false` — deliberate deviation from research 06's recommendation: our stage owns gamut compression; Phase A records the negative-pixel fraction at the chosen `E`, switching to `true` if > 0.1 %; `highlightRecoveryEnabled false` (deprecated-in-19 but present/settable — compile-probe under `-warnings-as-errors`); `exposure 0` (user EV lives in our stage; Apple's `exposure` is not a linear multiply); `baselineExposure` **not set** (equals the DNG tag; forcing 0 is a +EV edit); `neutralTemperature/Tint` as-shot unless user edits WB; `despeckleAmount 0` under `#available(iOS 27,*)`.

**8.3 PikicamLook.** A `CIFilter` subclass (`@objc dynamic var inputImage: CIImage?` + typed parameters) applied to `outputImage` in `extendedLinearDisplayP3`. Kernels are Metal CI kernels in `Develop/PikicamLook.ci.metal` (build rule, `-fcikernel`/`-cikernel` — probe-verified flags), loaded from the bundle `.metallib`; per-pixel stages are `CIColorKernel(functionName:fromMetalLibraryData:)`; no runtime kernel-source strings (deprecated; colour kernels can't `sample()`). Stages in order:
1. **Exposure:** RGB × 2^EV (default 0).
2. **Mono (§9):** when active, `y = w·rgb` in scene-linear, before the curve.
3. **Tone curve:** filmic, scene-linear → display-linear; input may exceed 1 (EDR headroom; re-measure max at chosen `E` on device); output ∈ [0,1]; default "Standard" fixes 0→0, mid-grey 0.18→0.18, toe near black, asymptotic shoulder (input 2.69 → > 0.95 and < 1.0 — no hard clip); user `contrast`, `highlights`, `shadows` ∈ [−1,1]; applied to max(R,G,B) with ratio-preserving scaling (hue-stable); formula + source (darktable filmic-rgb as reference) documented in the kernel; `highlights`/`shadows` operate around the pivot with the ACES/darktable-style weighting — the exact equations are extracted from the reference source, cited, and pinned by tests.
4. **Gamut compression:** distance-based soft compression of negative/out-of-gamut values toward the achromatic axis (ACES reference-gamut-compression parameterization, cited; documented parameters).
5. NR/sharpening: none in v1.
Framing crop last, from `FrameGeometry` — the same normalised rect the viewfinder overlay uses.

**8.4 Contexts and rendering.** Exactly two lazily-created `CIContext`s owned by the developer actor, never from SwiftUI `@State` defaults: `interactive` (`workingColorSpace: extendedLinearP3`, `workingFormat: .RGBAh`, `cacheIntermediates: true`, `outputColorSpace: displayP3`) and `export` (same colour settings, `cacheIntermediates: false`, `memoryTarget: 1024` — apinotes name). No rendering-intent option exists on this SDK: the final working→P3 match is ColorSync's default (itself a gamut map, after our compression) — recorded in `docs/DECISIONS.md`. Targets: `.thumbnail(maxPixel: 512)` (scaleFactor 512/longEdge, draft mode), `.display(pixelSize:)`, export full-res. Float readback **must** use `render(_:to: CVPixelBuffer(kCIPixelFormatType_64RGBAHalf), bounds:, colorSpace:)` — never `render(toBitmap:)` with `.RGBAh` into malloc (traps). Display output via `ctx.createCGImage(…, format: .RGBA16, colorSpace: displayP3)` (full-size verified in Phase A; else CVPixelBuffer route). Never untagged 8-bit.

**8.5 Encode.** HEIC 10-bit Display P3 via `try await ctx.heif10Representation(of:colorSpace:options:)`; nil ⇒ `.encodeFailed`. Metadata: the DNG's EXIF from `filter.properties` + `Software = "pikicam <version>"`. The DNG is never modified.

---

## 9. BNW — the monochrome filter (first-class, user-mandated)

Monochrome is a **develop-path decision**: the DNG stays the untouched Bayer file; mono is a reversible look riding in `AdjustmentPayload` (`LookParameters.mono: MonoState?`), so it round-trips through Photos and Revert removes it.

**9.1 Types.** `MonoState { preset: MonoPreset, custom: MonoWeights? }`; `MonoPreset { neutral, yellow, orange, red, green, blue }` — a preset is data (a `MonoWeights` vector + one-line rationale), never a new kernel; `MonoWeights { r, g, b: Float }` with `init(validating:)` rejecting negatives and any sum ≠ 1.0 (tolerance 1e-5).

**9.2 Kernel math.** Conversion happens in scene-linear, **after exposure and before the tone curve**: `y = w·rgb`; the curve then applies to `y` — the classic filter-model order, keeping the curve's meaning identical between colour and mono. The mono kernel is one `CIColorKernel` in `PikicamLook.ci.metal`:
- Default (Neutral) weights = the luminance row (Y) of the linear Display-P3→XYZ matrix. The constants are **extracted, not transcribed**: a committed script `scripts/p3-luminance.py` computes them from the P3 primaries (SMPTE RP 431-2; D65 white) with the derivation printed and cited; a unit test recomputes via the same script and asserts the kernel constants match (≈ 0.22897, 0.69174, 0.07929 expected).
- Filter presets simulate classic Wratten factors on those primaries — committed vectors, tuned in Phase 3 against a real scene, then pinned by fingerprints: Yellow (W8) ≈ (0.30, 0.70, 0.00) "passes R+G, absorbs B"; Orange (W15) ≈ (0.45, 0.55, 0.00); Red (W25) ≈ (0.85, 0.15, 0.00); Green (W58) ≈ (0.05, 0.90, 0.05); Blue (W47) ≈ (0.05, 0.15, 0.80). Each preset's one-line rationale lives beside its vector.

**9.3 Curve and contrast.** Mono uses the same Standard filmic curve; mono-specific contrast uses the existing `contrast` parameter. No separate mono curve.

**9.4 Dither.** The final pre-encode stage adds deterministic triangular-PDF dither of ±0.5 LSB at 10-bit output (hash of pixel coordinates, not RNG) so flat skies don't band; determinism keeps fingerprints reproducible.

**9.5 Bit-honesty and tests (DoD).** Every mono render asserts R == G == B within 10-bit quantisation (1/1023) post-encode; `MonoWeights.init(validating:)` rejects negatives and non-unit sums; dither is byte-deterministic for identical input; mono and colour share identical curve output on a mid-grey input; every preset has a unit test asserting its linear-mean direction on the fixture (e.g., Red preset on a blue sky lowers mean vs Neutral). UI: `MONO` toggle in Quick Settings + preset row with live weight readout; the histogram stays luminance-based.

---

## 10. Video — the same bypass, honestly (first-class, user-mandated)

**Ceiling first:** iOS exposes no raw Bayer video; every frame the SDK delivers is ISP-demosaiced and tone-mapped. The README says so. The bypass is the layers we own, and every one is asserted:

1. **Determinism parity:** the video configuration asserts the same `DeviceDeterminism` as §7.3 — GDC off, Center Stage app-controlled and off, video HDR decided (never automatic; target 10-bit HLG where the probe confirms), colour space pinned, low-light boost off, stabilization `.off` (a stabilized frame is a cropped warped frame; honest framing wins). Asserted and read back, not assumed.
2. **Manual parity:** ISO, shutter, WB and focus are the same `CameraSettings` driving photo and video; changing them changes both identically, **including mid-clip** (each change a timestamped provenance event).
3. **Our look, our encoder, two files:** frames from `AVCaptureVideoDataOutput` at the probe-confirmed highest-fidelity format (target: 10-bit YCbCr 4:2:0 + HLG; exact OSType and colour-tag flags from the device probe — never guessed). Each clip is written by `AVAssetWriter` as **two files from the same frames**:
   - **Master** (the original): ISP frames exactly as delivered, pixels untouched — video's DNG; Revert returns to it.
   - **Rendition:** the same frames through `PikicamLook` — exposure → **mono (§9, same kernel)** → filmic curve → gamut compression — at record-time look, with the mono state live-changeable mid-clip (recorded as a provenance event).

Rules: `AVCaptureMovieFileOutput` banned (grep-enforced). Two writers (or one writer two inputs — whichever the probe shows holds budget; recorded). Audio from `AVCaptureAudioDataOutput` into both; AAC 48 kHz stereo (probe-confirmed); `MUTE` toggle; mic denial is a state, not an error. `alwaysDiscardsLateVideoFrames = false` on the recorder output (a dropped frame is a gap in the record; > 1 % of a clip ⇒ recorded in provenance and surfaced in Info); the meter stream keeps `true`. Frame timing from the sample buffer, never re-timestamped; rotation from `RotationCoordinator` at record start. Modes `1080p30` default; `1080p60`/`4K30`/ProRes offered only where the **device-measured budget ladder** proves both writers hold the mode's rate with the look pass — the ladder is data, not hard-coded. Budget metric: **p95 and p99 frame time** under §4.7 soak, not means. If Core Image can't hold budget, the fallback is a precomputed 1-D LUT of §8.3's curve + a fixed-function Metal pass — still our code, still the same curve; Phase 8 records which shipped. Zoom: video has no Bayer constraint, so VIDEO-mode pinch drives `videoZoomFactor` (ramped, detents 1×/2×/3×/4× to lens max), shown on the chip, every change a provenance event; PHOTO keeps crop-only framing. Provenance travels in the file: creation date, `software`, and a `pikicam.provenance` JSON item (mode, settings at start, timed control-change events, dropped-frame count, iOS version) — a test reads it back. Storage: master promoted from journal → asset with master as one `.movie` resource in the "pikicam" album; rendition committed as first content edit with `PHAdjustmentData` (same shapes + pass criteria as §12.2). Crash mid-record ⇒ launch cleanup removes partials, UI reports "recording lost". `RecordingState` as §6.1; dock shutter becomes the record control (red ring, `MM:SS` monospaced, tap to stop); thermal `.serious` pauses with banner, resumes at `nominal`. Live-look viewfinder is a stretch goal gated on the probe: only if preview-look + both writers hold budget; otherwise the ISP preview shows an honest `PREVIEW: ISP` caption.

**Tests (DoD):** both files decode (`AVAsset`: duration, tracks, colour tags read back); master pixels untouched (decoded master matches a reference render of the delivered frames within quantisation); look EV −1 halves the linear mean on a synthetic frame; mono rendition is R==G==B within quantisation; provenance round-trips including a timed control-change event; injected late frames surface as `.framesDropped`; out-of-ladder mode rejected `.formatUnavailable`; `MUTE` yields a video-only asset; saveVideo creates master-as-`.movie` + rendition first-edit, and Revert restores the master.

---

## 11. Scan (slit-scan stills) — same honesty

Ceiling as §10: a scan assembles from ISP frames, never Bayer; README states it. The scan configuration asserts §7.3 determinism; the same `CameraSettings` drive frames (changes mid-scan allowed and recorded); **our look applies to the assembled image** — `PikicamLook`, mono (§9) and numeric lines all work on scans. Mechanism: sample a slit per frame (`axis H` default — vertical column, assembly advances left→right; `V` top→bottom; `movingSlit` oscillates the sampled position centre + amplitude·sin(2π·elapsed/period) while assembly still advances); `slitWidth ∈ {1,2,4,8,16}` px (default 8); relation shown pre-capture: `duration = outputLength / (slitWidth × frameRate)`; auto-stop on completion. Assembly = one Metal blit per frame into an `MTLTexture` (no per-pixel CI in the loop); on stop, `PikicamLook` renders the assembly once and encodes HEIC 10-bit. Rotation from `RotationCoordinator` at scan start. Drops: `alwaysDiscardsLateVideoFrames = false`; a dropped frame duplicates the previous slit into the gap, is counted, and > 1 % drops auto-stop; partial scan saved and marked `PARTIAL · DROPS n %` in provenance and Info — never silent. Guards (adopted from the design export's expanded sheets): no frame within 3× nominal interval ⇒ `.framesStalled`; Metal command-buffer failure retries once then `.gpuFailed(code:)` with assembly preserved; memory pressure beyond `.warning` downscales the assembly target with a recorded event. Storage: **two stills per asset** — master (neutral assembly, no look) as `.photo` + rendition as first content edit with `AdjustmentPayload` (look, mono, line) + provenance (axis, slit width, moving slit, frame count, drops, duration); §12.2 pass criteria apply. UI: mode strip `PHOTO | VIDEO | SCAN`; shutter = scan control; viewfinder shows the assembly filling live with `[ SCANNING · n% ]`; axis/slit/moving-slit rows in Quick Settings; `ScanState`/`ScanError` as §6.1.

---

## 12. Storage — Photos is the store

**12.1 Journal first (crash safety).** On capture acceptance, atomically write the DNG + versioned `JournalEntry` to `Application Support/Journal/<CaptureID>/`; develop and save; delete the entry only after the Photos save succeeds. `RecoveryFlow` finishes pending entries at launch before the shutter enables. `beginBackgroundTask` wraps develop+save. Unknown journal version ⇒ `.corrupt` (fuzz-covered §4.6).

**12.2 Photos asset shape — decided by device probe, not by v1's table.** One `PHAssetCreationRequest` per capture (`creationDate = capturedAt`, album "pikicam" in the same `performChanges`); resources with `PHAssetResourceCreationOptions` (`originalFilename` `PIKI_<yyyyMMdd_HHmmss>_<4hex>.dng|.heic`, `contentType` via `UTType`; never `uniformTypeIdentifier`). Candidate shapes tried in order on the device Photos library, first that passes ships: **A** `.photo` = DNG + `.fullSizePhoto` = our HEIC + `.adjustmentData` = `PHAdjustmentData("piki.pikicam.look", "1", JSON(payload))`; **B** `.photo` = HEIC + `.alternatePhoto` = DNG; **C** `.photo` = DNG + `.alternatePhoto` = HEIC. Pass criteria: `supportsAssetResourceTypes` true; `performChanges` succeeds; a `.current`-version image request returns pixels matching our HEIC (mean abs diff < 2/255 at 256 px); DNG bytes return unchanged via `PHAssetResourceManager`. Results for all three recorded in `docs/DECISIONS.md`. Develop failure at capture ⇒ DNG-only save, `.pending` until the viewer re-develops. No `PHImageManager` anywhere in the app (grep-enforced); DNG bytes always via `PHAssetResourceManager` through `AssetBoundary`.

**12.3 Identity, listing, thumbnails.** An asset is pikicam's when it is in the album **and** has a DNG resource (UTI ∈ {`com.adobe.raw-image`, `public.camera-raw-image`} or `.dng` extension), regardless of resource type. Album by `localIdentifier` in UserDefaults, title fallback, recreate if missing. Listing = one album fetch, newest first, never whole-library scans. Change observer debounced 250 ms; own saves applied directly. Limited access: assets the app created stay visible; Manage via `presentLimitedLibraryPicker`. Every in-app image is rendered by our developer from DNG + asset `LookParameters`: 512 px thumbnails cached `Caches/Thumbs/<CaptureID>-<lookHash>.heic` with an `NSCache` front; concurrent requests share one task; rendering cells show a neutral placeholder.

**12.4 Edits, share.** Viewer edits form a `LookParameters` (exposure, WB temp/tint, contrast, highlights, shadows, mono, line); commit writes `PHContentEditingOutput` with the same adjustment format + re-rendered HEIC; Revert = `revertAssetContentToOriginal()`; the DNG resource is never modified; foreign adjustment ⇒ "Edited outside pikicam", develop from neutral, overwrite only after confirmation. Share original = DNG via `PHAssetResourceManager` temp file; share developed = HEIC; video: master/rendition .mov (§10).

---

## 13. UI/UX

Brand source: the Maison Margiela export in `docs/design-source/` — **raw material, not law** (and per §1, its factual claims are hypotheses; its *aesthetic* is the brief). Precedence: platform law and accessibility gates > this document's functional requirements > the export. The reconciliation ledger in `docs/DECISIONS.md` records every export token/component/string → adopted/adapted/rejected with reason. Standing verdicts from v1 §5.0 carry over verbatim in substance: false telemetry rejected (real Bayer megapixels, `BAYER RAW` never "PRO-RAW", `DISPLAY P3`, EXIF f-number); classification stamp shows the active numeric line; MM palette beats the Stitch theme's parallel token system; Geist rejected — Space Mono (OFL licence committed) or SF Mono fallback, recorded; SF Symbols only; px→pt 1:1 with the 9 pt/10 pt floors for nano/micro; 44 pt targets (88 shutter); monochrome status discipline (striped-gesso clip bars, inverted-carbon `[ FAIL ]` — Differentiate Without Color passes by construction); gesso shutter wash + stitch pulse + `.ahap` haptics adopted with Reduce Motion derivatives; system shutter sound kept (custom waveform rejected); zones stay the functional skeleton with the export's components dressing them; mode strip `PHOTO | VIDEO | SCAN`; dark-only brand; texture overlays chrome-only, never over the viewfinder or under measured contrast pairs.

**Design system** (`pikicam/DesignSystem/`): `Palette.swift` (the seven export values only, with hex/OKLCH/token comments — nothing else may name a raw colour); `Tokens.swift` (semantic layer resolved from environment: inks gesso/muslin/calico/ash; solid plates photometric low/deep, carbon rules; inverted-fill selection; type roles display 18/title 13/readout 11/label 10/micro 9 with export tracking, `@ScaledMetric` everywhere, token-level `uppercased()` helper; U-grid spacing {4,8,16,24,32}+hairline; radius 0 except brand circles; motion 0 ms snaps / 120 ms drawer `cubic-bezier(0,0,0.2,1)` / 60 ms focus snap, Reduce Motion ⇒ 0; CoreHaptics with committed `.ahap` patterns); `Components/` built from export anatomy (`BastingStitchReticle`, `CareLabelStrip`, `NumericLineMatrix` with dormant digits, `TurretFocalSelector`, `TactileCalibrationDial`, `EmulsionToggleCard`, `GessoShutterActuator`, `ArchiveRollDeck`, `BracketButton` ≥44 pt, `ErrorBanner`, `Plate`); `Contrast.swift` (WCAG 2.2 relative luminance/ratio used by tests); `AccessibilityID.swift` (single identifier contract for views and UI tests); `Fonts/` + `Haptics/`. `Type.swift` is the only file that may call `Font.custom`.

**Layout (portrait zones):** Z0 status 44 pt plate — capture badge `[ RAW · 26MM · (0) ]` + mode/light/timer/grid/manual as 44×44 `BracketButton`s; Z1 viewfinder — `AVCaptureVideoPreviewLayer` `.resizeAspect` (whole sensor visible, never `.resizeAspectFill`), all overlays (framing mask, grid, reticle, level, histogram 96×44 on a plate) computed from this rect only; Z2 readout rail 56 pt `CareLabelStrip` with real values, each bracketed value opening the Manual panel on that parameter; Z3 lens rail 52 pt `TurretFocalSelector` + `CROP` chip; Z3.5 line matrix 44 pt scrollable row; Z4 dock 96 pt — thumbnail swatch / `GessoShutterActuator` / aspect chips. Landscape: full-height viewfinder + 120 pt trailing rail (`ViewThatFits` stacked readouts, compact lens menu, thumb-centred shutter, compact line menu), measured by UI test (≥ 5×44 pt + shutter). AX sizes: compact chrome (readout 5→3+2→column, menus), no truncated meaning. Manual panel (trailing sheet): ISO 1/3-stop detents, shutter 1/3-stop speeds, WB AUTO/LOCK/Kelvin 2000–10000 step 100 + tint ±150, Focus AF/MF lens-position dial (never metric distance) — each `TactileCalibrationDial` + stepper with device-limit min/max; unavailable controls show the reason, never disappear. Camera behaviour: tap = focus+meter (reticle 60 ms snap); double-tap = AE/AF lock chip; vertical drag = EV bias with 1/3-stop detent haptics; pinch = framing crop 1×–4× (PHOTO) or device zoom ramp (VIDEO, §10); shutter states ready/pressed/countdown/capturing(gesso wash)/saving/failed per v1 §5.3; hardware shutter via AVKit `.onCameraCaptureEvent` (`.ended` only, `defaultSoundDisabled: false`), `MPVolumeView` hack deleted; timer 3 s/10 s anchored to `ContinuousClock`, cancellable; thumbnail driven by the capture that just completed (empty/rendering/ready/failed→retry). Meters: `AVCaptureVideoDataOutput` ≤10 Hz, vImage 64-bin Y histogram, range-aware clip thresholds (full ≥250/≤5, video ≥235/≤16), `PREVIEW METER` caption; level from CoreMotion gravity 30 Hz, solid + detent haptic within ±1°; post-capture review = our 512 px render in the dock. Quick Settings sheet: lens info, mode, video mode (ladder-proved only), mute, scan setup with duration estimate, mono toggle + preset row, active line, aspect, grid, level, histogram, light, timer, CROP. Permissions gate (per-permission rows; `.restricted` explanation-only; `.limited` notice + Manage; re-evaluated on scene-active, never strands). States/errors: every `PermissionState`/`SessionState`/thermal banner/storage-full/limited/develop-failure rendered as designed care-label UI with primary action + Dismiss — never a blank or raw caption. Settings sheet: grid style, level, histogram default, haptics, CROP, badge toggle, About ("what pikicam does to your photo" — the ceilings in plain words), `@AppStorage` keys in one `SettingsKeys` enum. Library: `ArchiveRollDeck` grid 3/5 columns, newest first by `CaptureID`, VoiceOver label per cell ("Photo 3 of 41, date, ISO, shutter"), video cells with duration badge; empty state designed. Viewer: paging `TabView`, zoom/pan double-tap fit⇄2.5×, plates not floating glyphs, escape + swipe-down when chrome hidden; `AVPlayer` on the rendition with controls that pause on page change/chrome-hide; Info care-label sheet (provenance + `RecipeApplication` summary "APPLE PROCESSING: OFF (n/n NEUTRAL) · DECODER x.dng"; video: mode, fps, drops, timed events); Develop panel (look dials live at display scale, mono toggle + preset row, line matrix; video re-render with progress sheet + Cancel; Reset/Save/Revert); Share (DNG/HEIC/master/rendition); one delete-confirmation style app-wide, dismiss-then-delete.

**Accessibility gates (acceptance):** every control has label+value+hint, adjustable action where continuous, ≥44 pt (88 shutter); reading order status→meters→readouts→lenses→dock; rotor actions Capture / Lock AE-AF / Open library; all text scales (AX5 layout test: structural no-truncation — frames ≥44 pt, in-window, non-overlapping; plus `NSString.size` fit checks per token); every text pair ≥ 4.5:1, non-text ≥ 3:1, measured by `Contrast.swift` including stamp-backing composited over pure white/black; `performAccessibilityAudit()` on camera and library screens in the UI suite; real VoiceOver pass on device listed in `docs/DEVICE-CHECKLIST.md`.

**Numeric lines (0–23):** `LineProfile` = optional look preset + optional mono preset + optional camera binding (lens, level lock), per v1 §4.2.7's table (0 Artisanal = house default; 1 softer; 3 Fragrance dormant; 4 alias of 0; 10 harder; 11 binds telephoto — dormant on 12 mini which has none, shown but explained; 14 mono HP5 intent; 22 level lock; others dormant). A line never fakes a look the pipeline lacks — dormant lines render muted, non-interactive, with the reason in the accessibility hint; shipped lines' parameters tuned in Phase 3 then pinned by fingerprints; the active line tags `LookParameters` and round-trips; bindings announce themselves as visible state changes.

---

## 14. Project, build, structure, hygiene

`project.yml`: `SWIFT_VERSION 6.0`, `SWIFT_STRICT_CONCURRENCY complete`, warnings-as-errors (Swift + GCC), `ENABLE_USER_SCRIPT_SANDBOXING YES`, deployment iOS 26.5, `TARGETED_DEVICE_FAMILY "1"` all targets, `DEVELOPMENT_TEAM GV4GK5XGN5`, `MTL_COMPILER_FLAGS -fcikernel` + `MTLLINKER_FLAGS -cikernel` (app target), coverage on. Scheme `pikicam` tests `pikicamTests` + `pikicamUITests`; scheme `pikicam-device` tests `pikicamDeviceTests`; target `pikicamProbes` (probe files committed, excluded from the main test action; never links app sources). `GENERATE_INFOPLIST_FILE YES` only (delete `pikicam/Resources/Info.plist`); three truthful usage strings; `UIAppFonts` for Space Mono; `UIRequiredDeviceCapabilities [still-camera]`. `pikicam/Fakes/` compiles only in Debug (`#if DEBUG` per file); UI tests run Debug. Rewrite `PrivacyInfo.xcprivacy` to declare only what the code calls (UserDefaults CA92.1 for `@AppStorage`; nothing else unproven).

`scripts/verify.sh` (the one script): `xcodegen generate` → CI-only project/scheme diff check → resolve the **device** destination (devicectl; fail loudly if absent) → `xcodebuild -scheme pikicam -derivedDataPath build/dd build-for-testing -destination id=<udid>` → `test-without-building` on device → xcresult parse (executed > 0; skips only in the four documented classes: fixture-gated, device-only-scheme, Photos-auth-gated, harness-gated rawpy/darktable missing) → `swiftlint lint --strict` → `periphery scan` → `python3 scripts/reference-diff.py --check` (LibRaw + darktable brackets) → fuzz corpus run → prints skip classes at the end. `.github/workflows/ci.yml`: hosted macOS + Xcode 26 via `xcodes`; host-side only (xcodegen diff, device-less build, lint, periphery, fuzz harness, python oracles); second job: ThreadSanitizer unit run where host-runners allow, else local-only and recorded.

**File layout** (create exactly; delete every other source file under `pikicam/`):

```
pikicam/
  App/            PikicamApp.swift, Dependencies.swift, RootView.swift
  Domain/         IDs.swift, Exposure.swift, WhiteBalance.swift, Focus.swift, CameraSettings.swift,
                  Capabilities.swift, CaptureRequest.swift, RawCapture.swift, Provenance.swift,
                  FrameGeometry.swift, Look.swift, Mono.swift, Recipe.swift, LibraryItem.swift,
                  Journal.swift, Recording.swift, Scan.swift, States.swift, Errors.swift
  Capture/        CaptureClient.swift, AVCaptureClient.swift, DeviceConfiguration.swift,
                  CapabilitiesProbe.swift, PhotoCaptureDelegate.swift, PhotoBoundary.swift,
                  ReadingsObserver.swift, MeterTap.swift, RotationBinding.swift,
                  RecordingClient.swift, AVRecordingClient.swift, VideoFrameBoundary.swift,
                  ScanClient.swift, AVScanClient.swift
  Develop/        Developer.swift, CoreImageDeveloper.swift, NeutralRecipe.swift, PikicamLook.swift,
                  PikicamLook.ci.metal, VideoLook.swift, ScanAssembler.swift, DNGInspector.swift, Encoder.swift
  Library/        Library.swift, PhotoKitLibrary.swift, AssetBoundary.swift, Album.swift,
                  AdjustmentCodec.swift, FileJournal.swift, ThumbnailStore.swift, Share.swift
  Platform/       PermissionClient.swift, MotionClient.swift
  Flows/          CaptureFlow.swift, RecordFlow.swift, ScanFlow.swift, RecoveryFlow.swift, EditFlow.swift
  Features/       Camera/ (CameraModel, CameraScreen, Viewfinder, PreviewLayerView, ReadoutRail,
                  LensRail, Dock, Shutter, RecordButton, ScanOverlay, ManualPanel, QuickSettings,
                  Overlays)
                  Library/ (LibraryModel, LibraryScreen)  Viewer/ (ViewerModel, ViewerScreen,
                  PlayerView, DevelopPanel, InfoSheet)  Permissions/ (…Model, …Screen)
                  Settings/ (SettingsScreen, SettingsKeys)
  DesignSystem/   Palette.swift, Tokens.swift, Type.swift, Contrast.swift, AccessibilityID.swift,
                  Fonts/ (SpaceMono-Regular.ttf, SpaceMono-Bold.ttf, OFL.txt),
                  Haptics/ (shutter.ahap, detent.ahap, tick.ahap, failure.ahap),
                  Components/ (the eleven §13 components)
  Support/        Retry.swift, Timeout.swift, Tracing.swift, ContinuationOnce.swift, MapError.swift
  Fakes/          FakeCaptureClient, FakeDeveloper, InMemoryLibrary, FakeRecordingClient,
                  FakeScanClient, FakePermissions, FakeMotion, FakeScenario   (Debug only)
  Resources/      Assets.xcassets (keep AppIcon; real AccentColor), PrivacyInfo.xcprivacy
Host-side: FuzzHarness/ (macOS libFuzzer target wrapping DNGInspector/FileJournal sources)
Scripts: verify.sh, reference-diff.py, colorcheck.py, design-diff.py, p3-luminance.py
Docs produced: DECISIONS.md, CALIBRATION.md, INTEROP.md, DEVICE-CHECKLIST.md, COLOR.md
Tests: pikicamTests/ (mirroring app folders), pikicamUITests/ (CameraUITests, LibraryUITests,
       PermissionsUITests, Support/AppLauncher), pikicamDeviceTests/DeviceProbeTests.swift
```

Delete list (v1 §6.11 stands): `pikicam/Core/**`, old `Features/**` sources, `pikicamTests/{DesignLintTests,CameraControlTests,PikicamPipelineTests}.swift` (port the NaN/infinity/out-of-range edge cases and the upright-extent assertion into new Domain tests), `pikicamUITests/SmokeLaunchTest.swift`, `scripts/verify-design.sh`, `.github/workflows/design.yml`, `docs/.P.DESIGN.md`, `docs/design/**`, `docs/prompt-next.md`, `.pre-commit-config.yaml`, `.swiftlint.yml`, `.swift-format` (recreated as enforced config), `.agents/`. `docs/design-source/` is read-only input, plus Phase 0 may add `docs/design-source/references/` renders.

Structural laws: no file > ~300 lines, no function > ~40 (scanner test); `Domain/` imports only Foundation/CoreGraphics (test-grepped); comments only for non-obvious *why* with a source, density < 10%; zero third-party runtime dependencies; `swift-format` clean. Banned by grep (§17): 1-arg `CIRAWFilter(imageData:)`, `PHImageManager`, `photoQualityPrioritization = .balanced|.quality`, `videoZoomFactor =` outside the video ramp client, `linearSpaceFilter`, `responds(to:`, `supportedCameraModels`, `objc_setAssociatedObject`, `MPVolumeView`, `AVCaptureMovieFileOutput`, `try?`, stray `.shared`/`.default()`, `TODO|FIXME|for now|XXX`, `PRO-RAW|REC.2020|Material Symbols`, raw colours/`Font.custom`/system-size fonts/spacing/radius outside their homes, `.preferredColorScheme(`.

---

## 15. Tests

Swift Testing for units, XCTest for UI. Beyond v1 §7 (all of which stands, amended to run on device and against Bayer fixtures where possible):

1. **Domain:** clamping at/outside limits for every dial type; `FrameGeometry` aspect×crop → rect, integral rounding, overlay rect == develop rect at three viewfinder sizes; `MonoWeights` validation; `LineProfile` table equals §13's mapping with dormant lines non-interactive.
2. **Capture (fake seams + real settings on device):** `makeSettings()` yields `.speed` + Bayer format + max dimensions + no processed format + flash off (inspecting the real `AVCapturePhotoSettings`); `PhotoBoundary` rejects non-RAW / wrong pixel format / fusion-enabled resolved settings / non-TIFF bytes / LinearRaw (ProRAW fixture as the adversarial case); single-resume continuation double-resume and timeout paths.
3. **Develop (real CIRAWFilter, Bayer fixture; ProRAW as foreign input):** no 1-arg init in source; every recipe control reads back neutral through its declared property on a filter whose class was first asserted `CIRAWFilter`; `highlightRecoveryEnabled == false`; `baselineExposure` untouched (equals tag); `decoderVersion` pinned ≠ RAW 9; EDR headroom max > 1.0 via `64RGBAHalf` in `extendedLinearDisplayP3`; EV −1 halves linear mean ±3 %; EV 0 + Standard keeps mid-grey; no `linearSpaceFilter`/`responds(to:` in source; neutral output differs measurably from Apple's default render (thresholds from Phase A stats); tone curve monotone, 0→0, 0.18→0.18±0.01, ≤1 up to input 4.0, 2.69→(0.95,1.0); HEIC decodes 10-bit tagged P3; `RecipeApplication.unapplied` empty on device, `unsupported` reported separately; **§9's mono suite** (bit-honesty, presets, dither determinism, curve parity); ΔE2000 implementation validated against Sharma 2005 test vectors.
4. **Library/Journal:** persist → simulated crash → recovery completes exactly once; unknown journal version `.corrupt`; `AdjustmentCodec` round-trip v1, rejects foreign; `AssetBoundary` accepts DNG under either resource type and UTI/extension variants; device integration test against the real Photos library (gated on authorization with loud skip): save, album membership, resource set, adjustment round-trip, delete-everything.
5. **Design system:** contrast pairs ≥ 4.5:1 / 3:1 on plate/canvas and stamp backing over white/black; the §14 source-scan greps as individual regex tests; every `Button` in Features is `BracketButton` or 44 pt-modified; `String(localized:)` discipline; `.ahap` parse + parameter validity; fonts resolve (`UIFont(name:)` non-nil both weights) + licences beside; line/function size scanner.
6. **Flows (fakes):** capture happy path; develop failure → DNG-only `.pending`; save transient → retry then success; `.storageFull` → journal retained + typed error; interruption mid-capture → `.ready` + banner; record start→stop→saveVideo; writer failure → `.failed` + partial cleanup at next launch; scan happy, stall, drop-threshold → `PARTIAL`.
7. **Models:** `ShutterState` incl. countdown cancel; no lens published without Bayer; permission gate re-evaluates on scene-active.
8. **UI (fake launch args, on device):** permissions each state; camera reachable; shutter → thumbnail updates; manual panel ISO stepper; VoiceOver adjustable EV; timer start/cancel; landscape frame assertions; AX5 structural assertions; library→viewer→info→develop→save→revert→delete; chrome hidden → escape exits; fake record (elapsed ticks, stop, library, playback controls, pause on page change); video develop progress sheet; video Revert → master; fake scan (progress caption, stop, provenance in Info); `performAccessibilityAudit()` on camera + library; interruption injection (background mid-capture recovers via journal).
9. **Fixtures & device tests:** fixtures SHA-registered; gated tests `#require` with loud path-naming skips; `pikicamDeviceTests` = the §7/§10 device probe (JSON dump to Documents + `fixture-bayer.dng` copy) and the budget ladder measurement.
10. **Fuzz:** §4.6 both tracks.
11. **Reference diff:** §4.4 bracket within committed tolerances.
12. **Video:** §10's test list.
13. **Design parity:** fake-mode camera screenshot at reference device size vs committed reference render, region-by-region with viewfinder masked, tolerances from Phase 5 baseline (`scripts/design-diff.py`).
14. **Scan:** §11's list (geometry, drop policy, stall guard, memory downscale, saveScan/Revert).

---

## 16. Execution plan and Definition of Done

Phases (each ends with `verify.sh` green + one commit + a `docs/DECISIONS.md` entry):
- **Phase 0 — Attestation.** Tooling (§3 list) installed and versioned; device destination proven; claims-under-test ledger probes run on the 12 mini; design references rendered + token extraction (`docs/design-source/references/`); Space Mono downloaded (OFL) with fallback decision; fixtures captured (§4.3) + synthetic Bayer generator passing `dng_validate`; dng_validate built (or proxy recorded).
- **Phase A — Calibration.** §4.3 in full → `docs/CALIBRATION.md`; E chosen; stage-isolation matrix (§4.2) committed; performance baselines (thumbnail ≤ 50 ms, full ≤ 500 ms budgets at 2×; video p95/p99) recorded with N-run variance; tolerance bands derived.
- **Phase 1 — Skeleton.** Delete list applied; `project.yml` per §14; Domain shapes; Support wrappers + compile exemplar; DesignSystem two layers + fonts + haptics; `Dependencies` + fakes; `verify.sh` + CI; app launches to placeholder; Q-rows recorded.
- **Phase 2 — Capture core.** `AVCaptureClient` (executor form per probe), configuration + determinism read-back, `PhotoBoundary`, delegate scoping, readings, meters, rotation, lifecycle. Fake client drives the same protocol.
- **Phase 3 — Develop core + BNW.** `CoreImageDeveloper`, `NeutralRecipe` (values pinned by device measurement), `PikicamLook` Metal kernels incl. **the mono kernel and presets (§9)**, dither, `DNGInspector`, contexts, HEIC encode; ΔE00 vectors green.
- **Phase 4 — Library, journal, flows.** §12 in full + device Photos integration test; asset shape decided by probe.
- **Phase 5 — Camera UI.** §13 zones/behaviour/Quick Settings from the components; portrait/landscape/AX5 UI tests green; design-parity baseline measured.
- **Phase 6 — Library and Viewer UI.** Including develop edits, share, video playback surface.
- **Phase 7 — Permissions, states, settings.**
- **Phase 8 — Video + scan.** §10 and §11 in full: two-writer pipeline, mono in video, budget ladder measured on device as data, provenance writer, zoom ramp, scan assembler + guards. `AVCaptureMovieFileOutput` grep clean.
- **Phase 9 — Interop + soak.** `docs/INTEROP.md` matrix; 5-minute thermal soak; power log; interruption suite; haptics bench + chart + legibility items written into `docs/DEVICE-CHECKLIST.md` (owner-physical only).
- **Phase 10 — Documentation + final audit.** README (mission, ceilings incl. video/scan, ProRAW→Bayer fixture status, build/verify instructions, harness docs); AGENTS.md ≤ 80 lines; `docs/DECISIONS.md` complete (ledger + reconciliation + all deviations); `docs/COLOR.md` (working-space choices, curve/gamut sources, luminance derivation); hygiene pass recorded (SwiftLint 0, periphery 0, swift-format clean, muter score + dispositions, TSan clean, reference-diff in tolerance, full fuzz); then §17.

**Definition of Done (all must hold):**
1. `xcodegen generate` deterministic (`git diff --exit-code -- pikicam.xcodeproj`).
2. `scripts/verify.sh` exits 0 **on the device**: Swift 6, complete strict concurrency, warnings-as-errors, all unit + UI tests, 0 failures; skips only in the four documented classes.
3. Every §1 ledger row resolved (`proven/refuted/amended`), every §2 diagnosis row mapped to a test or DECISIONS entry.
4. Capture contract enforced positively (§7.4) and provenance complete.
5. Develop contract asserted by readback tests + fingerprint + dual-oracle bracket.
6. **BNW bit-honest** (§9.5) and preset-tested; mono round-trips and Reverts.
7. **Video bypass proven** (§10 tests): determinism parity asserted, master untouched, provenance round-trip, mono in the look pass, ladder measured, `AVCaptureMovieFileOutput` absent.
8. **Scan honest** (§11 tests) with `PARTIAL` semantics.
9. Camera UI fully exercised on device via fake mode; no dead UI test; accessibility audits pass.
10. `docs/CALIBRATION.md` exists with measured numbers and method per number; tier stated.
11. `docs/INTEROP.md` matrix green (or each gap a defect/decision).
12. Tolerances derived from N-run statistics; goldens committed (software renderer) + A14 device set.
13. Fuzz both tracks clean; TSan clean; muter recorded; periphery/lint/format zero.
14. Design reconciliation ledger complete; no false telemetry string (greps).
15. `README.md`, `AGENTS.md`, `docs/DECISIONS.md` describe the app that exists; `docs/DEVICE-CHECKLIST.md` holds only owner-physical items.
16. All probes committed and runnable in `pikicamProbes` on the device.

---

## 17. Final self-check (before the last commit; fix everything that fails)

- [ ] `verify.sh` green from a clean `build/` on the device; tests executed > 0; skips only documented classes.
- [ ] `git grep -nE "CIRAWFilter\(imageData: *[A-Za-z_.]+\)"` → nothing; `git grep -n "PHImageManager" -- pikicam` → nothing.
- [ ] `git grep -nE "photoQualityPrioritization *= *\.(balanced|quality)"` → nothing; `videoZoomFactor =` only in the video ramp client.
- [ ] `git grep -nE "linearSpaceFilter|responds\(to:|supportedCameraModels|objc_setAssociatedObject|MPVolumeView|AVCaptureMovieFileOutput"` → nothing; `@unchecked Sendable` only the `SessionHandle` with its proof comment.
- [ ] `git grep -n "try?" -- pikicam` → nothing; `.shared|.default()` only in live clients; `TODO|FIXME|for now|XXX` → nothing; no commented-out code.
- [ ] `git grep -nE "PRO-RAW|REC\.2020|Material Symbols" -- pikicam` → nothing; design-scan greps clean.
- [ ] Video: master-untouched, provenance round-trip, saveVideo/Revert tests exist and pass; shipped mode list equals the measured ladder.
- [ ] Scan: geometry/drop/stall/save tests pass; README states the scan ceiling.
- [ ] Mono: R==G==B test passes; every preset unit-tested; luminance constants == `scripts/p3-luminance.py` output.
- [ ] Calibrated numbers recorded; CI asserts budgets ≤ 2× baselines; every tolerance cites its N-run derivation.
- [ ] Every flow body matches §6.2 node-for-node; the only inline handler is `developForCapture`; every `init(mapping:)` exhaustiveness-tested.
- [ ] Delete list gone; `docs/workflow/` untouched.
- [ ] README claims nothing the code does not do.
