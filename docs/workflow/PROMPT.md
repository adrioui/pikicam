# pikicam — Rebuild Prompt

You are the implementer. You run headless and alone: no human will answer questions, and nothing outside this document and the repository exists for you. Read this document end to end before you touch a file. Then execute it phase by phase until the Definition of Done holds.

Repository: `/Users/adrifadilah/Desktop/pikicam` (iOS app, Swift, XcodeGen).
Research behind every claim here: `docs/workflow/research/01…07-*.md` (06 = measured adjudication of conflicts; 07 = compile-verified review of this prompt's API names). Read a research file when a task below cites it; do not re-derive what it already measured.
Design source: `docs/design-source/` — the Maison Margiela camera design export (two specification documents, two Tailwind screens with renders, one Stitch theme file). §5.0 governs how it is used; it is raw material, not law.

---

## 0. Mission

**camera → our code → no iPhone post-processing.**

pikicam captures one un-fused Bayer RAW exposure from a physical rear camera. It keeps the untouched DNG. It develops that DNG — in colour or in monochrome — with a pipeline whose look is defined by our code, not Apple's. It records video through the same deterministic device configuration, with the same look applied by our code to every frame. It presents all of this through a pro camera UI that is legible on any scene, fully accessible, and honest about what the hardware did.

The current codebase is presumed stupid and shitty. That covers committed and uncommitted code, the in-progress design system, the design docs, the tests, the CI and the scripts. Nothing in it is authoritative. Measured examples: the develop recipe has never once been applied (wrong initializer → stub filter), the gallery shows Apple's render, the viewfinder is Apple-corrected while the file is not, the test suite crashes, the design lint reports 777 violations and has three parser bugs of its own, and there are ~5,800 lines of contradictory design prose for ~1,900 lines of SwiftUI. You are rebuilding the app, not repairing it. Section 3 lists the few facts and behaviours that are already correct and must survive. Everything else is rewritten or deleted.

### 0.1 Definition of Done (all must hold)

1. `xcodegen generate` is deterministic for this tree. Regenerating after the final commit produces no diff (`xcodegen generate && git diff --exit-code -- pikicam.xcodeproj`, covering project and schemes). `scripts/verify.sh` asserts this in CI (§6.1).
2. `scripts/verify.sh` exits 0. It builds with Swift 6 language mode, complete strict concurrency and warnings-as-errors, and runs all unit tests and all UI tests on an iOS 26.5 simulator with **0 failures**. Skips are allowed only in four documented classes, each listed in `verify.sh`'s allowlist and printed by class at the end: fixture-gated (§7.9), device-only (`pikicamDeviceTests`, not in the main scheme), Photos-authorization-gated (§8 Phase 4), and harness-gated (§7.11: the reference-diff Python environment is unavailable).
3. Every row in §2 (diagnosis) is resolved, and each resolution is traceable to a test or to a line in `docs/DECISIONS.md`.
4. The capture contract (§4.1) is enforced positively in code at the boundary. "Bayer RAW, `.speed`, zoom 1.0, crop factor 1.0, no processed companion, ProRAW off" is asserted, not merely absent.
5. The develop contract (§4.2) is asserted by tests that read back every `CIRAWFilter` control on a real filter and compare pixel fingerprints against Apple's default render.
6. The camera UI is reachable and fully exercised on the simulator through the fake-dependency launch mode (§7.8). No UI test is dead.
7. No file from the delete list (§6.11) remains, and nothing references one.
8. `README.md`, `AGENTS.md` and `docs/DECISIONS.md` describe the app that exists (§8, Phase 10).
9. `docs/DEVICE-CHECKLIST.md` exists. It lists every claim the simulator cannot prove, as an on-device step with the expected observation.
10. Every platform claim is backed by a committed, re-runnable probe: the Phase 0 probes live in the `pikicamProbes` target (§6.1) and stay runnable. A probe result always outranks this document (§1 rule 9).
11. The oracle stack of §1.5 is wired into `scripts/verify.sh` and CI, and green: SwiftLint strict (zero findings), `periphery scan` (zero dead symbols), the reference-diff harness within committed tolerances, the DNG/journal fuzz corpus, and a Thread-Sanitizer run of the unit suite. The mutation score of `Domain/` and `Support/` is recorded in `docs/DECISIONS.md`.
12. The video contract (§4.5) is enforced like the capture contract: device determinism asserted for the video configuration, `AVCaptureMovieFileOutput` absent from the source, colour tags verified by a test, and every video asset follows the master/rendition model — an untouched master original, the rendition committed as its first edit, Revert returning the master.
13. Monochrome output is bit-honest: every monochrome render has R == G == B within 10-bit quantisation (§4.2.6), and every preset's weights are unit-tested.
14. The design reconciliation (§5.0) is complete: every token, component and string of the export is adopted, adapted or rejected in the reconciliation ledger with a reason; the chrome matches the committed reference renders within recorded tolerances at the reference viewports (§7.13); and no false telemetry string survives (§10 greps).
15. The scan mode (§4.6) is honest and proven: built from ISP frames with the ceiling stated, look applied to the assembled image, the drop and stall guards enforced by tests, master/rendition storage with Revert, and provenance recording the scan configuration.

---

## 1. Hard rules

1. **Autonomy.** Never ask a question; never stop to wait for input. When this document leaves a genuine gap, decide, then record the decision and its reason in `docs/DECISIONS.md` (one entry: date, decision, why, what would change it).
2. **No skills, no prompt templates, no external agent instructions.** Ignore `.agents/`. Do not load any skill.
3. **Scope.** Work only inside the repo. `docs/workflow/` (research, briefs, logs, this prompt) is read-only input: never edit or delete it. `docs/design-source/` is likewise read-only input, with one exception: Phase 0 may generate and commit `docs/design-source/references/` (the render references of §5.0). Never edit the export files themselves.
4. **Source of truth for the project file is `project.yml`.** Never hand-edit `project.pbxproj` or the scheme. Regenerate with `xcodegen generate` after every change to `project.yml` or to the file tree, and commit the regenerated project in the same commit.
5. **Git.** Work on a branch named `rebuild` created from the current `HEAD`. First commit the current working tree as-is on that branch (`chore: snapshot pre-rebuild state`) so everything you delete is recoverable. Commit at the end of every phase (Conventional Commits, e.g. `feat(capture): …`). Never push, never rewrite history, never touch `main`.
6. **Verification is not optional.** A phase is done only when its acceptance commands pass. If something cannot be verified on the simulator, add it to `docs/DEVICE-CHECKLIST.md` and implement a device-only probe test for it (§7.9). Never claim it works.
7. **No slop.** No comments that restate code. No "TODO" or "for now". No dead code, unused parameters, speculative abstractions, or protocols with one conformer that is not swapped in tests. A comment exists only to state a non-obvious *why*: a platform rule, a measured fact, or an invariant, with its source (SDK header line, research section, or Apple doc URL). Mechanical gates enforce this (§7.5, §1.5, §10): a violation fails the build, it is not a review note.
8. **Platform truth.** When this document disagrees with the iOS 26.5 SDK headers, the headers win. When it disagrees with research 06 (the measured adjudication), 06 wins, unless this document records a deliberate deviation with its measurement (e.g. `isGamutMappingEnabled`, §4.2.2). Record every such case in `docs/DECISIONS.md`. The headers are at `$(xcrun --sdk iphoneos --show-sdk-path)/System/Library/Frameworks/<Framework>.framework/Headers/`. Swift-only names live in `.apinotes` and `.swiftinterface` files, so compile a probe when in doubt.
9. **Evidence standard.** Authority ranks in this order, highest first: (1) a probe you ran on the iOS 26.5 simulator or a device; (2) the SDK headers and `.swiftinterface`/`.apinotes` files; (3) the Adobe DNG specification; (4) research 06 (measured adjudication); (5) Apple documentation and WWDC transcripts; (6) this document. Prose summaries — blog posts, the research files' narrative, memory — never outrank a measurement. When code relies on a fact, it cites its rank-1 source in a comment or in `docs/DECISIONS.md`.
10. **Care.** You are leaving this codebase to a person. Zero third-party runtime dependencies. SwiftFormat-clean formatting. No file over ~300 lines and no function over ~40, both enforced by a test (§7.5). Comments state a non-obvious *why* with a source; the target comment density is under 10% of lines. Every layer speaks only its own error type. When a hack is tempting, delete the requirement instead of adding the hack.

---

## 1.5 Raw materials, methods, and oracles

This section separates a rebuild that *claims* correctness from one that *measures* it. Everything here is binding.

**Raw materials (authority, highest first).** Read these before trusting any summary, including this document:

- **The SDK itself.** `SDK=$(xcrun --sdk iphoneos --show-sdk-path)`. Framework contracts: `$SDK/System/Library/Frameworks/<F>.framework/Headers/*.h`. Swift-only names: `<F>.framework/Modules/<F>.swiftmodule/*.swiftinterface` and `.apinotes` (e.g. `CIContextOption.memoryTarget` exists only in apinotes). When behaviour is undocumented, read the header comment; when the header is silent, probe.
- **The Adobe DNG specification** (latest, 1.7 or newer, helpx.adobe.com/camera-raw/dng-spec.html) and its base, **TIFF/EP (ISO 12234-2)**. Every tag `DNGInspector` reads — `PhotometricInterpretation`, CFA tags, `BlackLevel`, `WhiteLevel`, `ColorMatrix1/2`, `AsShotNeutral` — is read with the spec's tag table open, not from memory.
- **The Adobe DNG SDK** (github.com/adobe/dng_sdk). Phase 0 builds its `dng_validate` tool; it is the independent conformance oracle for every DNG we write or capture. If building it proves impractical, record that and use the `exiftool` + LibRaw decode pair as the proxy oracle.
- **Independent RAW developers as render oracles:** LibRaw (via `rawpy` in the `scripts/` harness), darktable and RawTherapee (their filmic-curve and gamut-compression source is the reference implementation for §4.2.3). Their source code is the material; their UIs are not.
- **Apple's primary material:** the WWDC session videos and transcripts on ProRAW and RAW capture, `AVCapturePhotoOutput` and deferred photo delivery, and video capture (`AVCaptureVideoDataOutput`, 10-bit HDR, ProRes). Sample code: the AVCam lineage. Read transcripts, not blog posts about them.
- **Published physical data:** the X-Rite ColorChecker 24-patch reference values (BabelColor dataset) for the device ΔE measurement (§7.9, Phase 9).
- **Halide's Process Zero engineering write-ups** — corroboration for pipeline decisions only. They describe a different codebase under different constraints; they are never authority.
- **The device.** A real iPhone produces the only true Bayer DNGs that exist here. Everything else on this machine is ProRAW or simulation (§7.9 caveat).

**Methods (all mandatory):**

- **Compile-probe every API claim.** Any API name this document or the code relies on that is not already probe-backed gets a probe: a minimal file compiled against the 26.5 SDK and run on the simulator, asserting signature and behaviour. Probes live in the `pikicamProbes` target and stay runnable; decisions they settle cite them from `docs/DECISIONS.md`.
- **Stage isolation.** Build a control matrix for `CIRAWFilter`: render the fixture with every §4.2.2 control at neutral, then with each control alone at its extreme, and diff the renders (max, mean, changed-pixel count). Commit the matrix to `docs/DECISIONS.md`. A control whose extreme does not move a single pixel is recorded as inert on that input. A control inert at neutral *and* extreme is a candidate for removal in the next recipe version — never a silent no-op.
- **Differential rendering.** `scripts/reference-diff.py` (Python 3, `rawpy`, `numpy`, no network) renders the same fixture twice — once through our neutral `CIRAWFilter` pipeline read back as linear floats, once through LibRaw with camera WB, gamma off, no auto-bright — and compares scene-linear per-channel statistics (mean, median, 1st/99th percentile, max). The pipelines will not agree exactly (different demosaic and colour handling); Phase 0 measures the gap on the fixture and commits the tolerance. The test then asserts the gap stays inside the committed tolerance, so a future OS update that silently changes `CIRAWFilter` output fails a test instead of shipping.
- **Pixel fingerprints.** Every develop decision is pinned by committed metrics (highlight-clip count, crushed-black count, Laplacian variance, per-channel histograms), computed in Phase 0 and asserted at half the measured gap (§7.3). Re-baselining a fingerprint requires a recorded reason.
- **Fuzz the boundaries.** `DNGInspector` and `FileJournal` are fed a deterministic corpus of mutated inputs (byte flips, truncations, oversized and underflowing IFD fields, generated from the fixture with a fixed seed) and must return typed errors — never crash, never hang. The full corpus runs in CI; a 50-variant smoke runs in every test-suite run.
- **Concurrency proof.** The unit suite runs once under Thread Sanitizer (`xcodebuild test -enableThreadSanitizer YES`) in CI. Any report is a defect, not noise.
- **Mutation testing.** `muter` runs on `Domain/` and `Support/` before the final audit; the score and surviving mutants are recorded in `docs/DECISIONS.md`. A surviving mutant that represents undetected real behaviour gets a test; the rest get a recorded reason.
- **Dead-code detection.** `periphery scan` reports zero unused symbols, configured to acknowledge the probe and test targets.
- **Performance budgets.** `traced` (§6.8) emits signpost intervals per pipeline stage. Budgets, measured in Phase 0 and asserted in CI at ≤ 2× the recorded baseline: develop to a 512 px thumbnail ≤ 50 ms and to full fixture resolution ≤ 500 ms on the iOS 26.5 simulator; the video look pass holds 30 fps at 1080p on device (§4.5, checked by the device probe).
- **Chart-truth on device.** The device round photographs a ColorChecker 24; `scripts/colorcheck.py` computes ΔE2000 per patch against the BabelColor reference after mapping through our pipeline. Median ΔE ≤ 8 is the v1 bar. Without a calibrated reference this is an order-of-magnitude gate; record it with that caveat.

**Oracles — who else says the result is right (besides you and the owner):** the compiler (Swift 6, warnings-as-errors); the CI runner executing `verify.sh` from a clean checkout; `dng_validate` on saved DNGs; `exiftool` dumps read against the DNG spec; LibRaw's independent decode; the committed fingerprints and tolerances; Thread Sanitizer; `muter`; `periphery`; SwiftLint strict; XCUITest's `performAccessibilityAudit()` (§7.8); Apple Photos itself on device (it must display our render, and Revert must return the DNG); and the measured world — chart patches, EXIF readings, sustained frame rates. A claim no oracle can check does not ship as a claim; it ships as a question in `docs/DEVICE-CHECKLIST.md`.

---

## 2. Diagnosis — what is wrong (consolidated, de-duplicated)

Severity: **P0** = breaks the product promise, loses data, or crashes. **P1** = materially wrong or blocks the rebuild. **P2** = slop that must not survive. Evidence is `file:line` in the pre-rebuild tree (snapshot commit) or a research section. Each row's required resolution is in §4–§7; the "→" column points there.

### 2.1 Capture (research 01, 02)

| # | Sev | Defect | Evidence | → |
|---|---|---|---|---|
| C1 | P0 | Geometric distortion correction is ON by default and is "always applied to `AVCaptureVideoPreviewLayer`", but "RAW photo captures never have GDC applied". The viewfinder is Apple-corrected and narrower; the DNG is not. The app never touches GDC. | `AVCaptureDevice.h:2267,2272-2286`; 0 repo hits | §4.1.3 |
| C2 | P0 | Center Stage defaults to user control from Control Center and may pan, tighten or widen the frame; the app never takes control. | `AVCaptureDevice.h:2340-2366`; 0 repo hits | §4.1.3 |
| C3 | P1 | The quality-prioritization guarantee is accidental. The code refuses to set `photoQualityPrioritization` and its comment claims the default is `.balanced`. Measured (research 06 C9): the RAW factory defaults to `.speed`, setting `.speed` explicitly is accepted, and only `.quality` throws. The rule "Bayer RAW **must** be `.speed`" (`AVCapturePhotoOutput.h:85`) is therefore met by a factory side effect, not by our code. `maxPhotoQualityPrioritization` stays at `.balanced`. | `CaptureService.swift:536-539,668-675`; research 06 C9 | §4.1.4 |
| C4 | P0 | The preview is 100% Apple ISP output. `automaticallyAdjustsVideoHDREnabled` defaults to YES, which fuses two exposures per frame. | `PreviewView.swift:14-20,62-64`; `AVCaptureDevice.h:2144-2151` | §4.1.3, §4.4 |
| C5 | P1 | Nothing proves the payload is Bayer RAW: `resolvedSettings` is discarded, `isRawPhoto` is never checked, the pixel format is never checked, and `CapturedDNG` only checks "non-empty". | `PhotoCapture.swift:99-103`; `CaptureService.swift:556-560`; `PhotoLibraryManager.swift:29-35` | §4.1.5 |
| C6 | P1 | `maxPhotoDimensions` is never set, so the settings default to the **smallest** supported dimensions. `activeFormat` is never read. | `AVCapturePhotoOutput.h:539-547,1449-1456`; 0 repo hits | §4.1.2 |
| C7 | P1 | "Zoom" is a centred software crop. Capture snaps to 1× with a 250 ms sleep, and the framing overlays stay frozen at 1×. The `2.0x` chip promises detail the file does not contain. | `CaptureService.swift:479-533`; `CameraView.swift:355`; `CameraControls.swift:198-215` | §4.1.2, §5.3 |
| C8 | P1 | The front camera has no Bayer RAW; every front capture fails with a red caption. | `CaptureService.swift:235,507-509,657-665` | §4.1.1 |
| C9 | P1 | No manual ISO, shutter, white balance or focus. Apple's auto exposure and auto white balance decide everything. | 0 repo hits for `exposureDuration`, `whiteBalance`, `.ISO` | §4.1.6 |
| C10 | P1 | No capture provenance: no ISO, shutter, lens, WB or dimensions are recorded. | `PhotoLibraryManager.swift:84-101,907-921` | §4.1.5 |
| C11 | P1 | Hand-rolled Bayer OSType list instead of `AVCapturePhotoOutput.isBayerRAWPixelFormat(_:)`. | `CaptureService.swift:641-654` | §4.1.2 |
| C12 | P1 | `videoScaleAndCropFactor` is never checked, although it must be 1.0 for Bayer RAW. | 0 repo hits; `AVCapturePhotoOutput.h:84-86` | §4.1.4 |
| C13 | P2 | The configuration lock is held across an unbounded `await` in `setExposureBias`; a lost completion deadlocks every later lock. | `CaptureService.swift:428-443` | §6.9 |
| C14 | P2 | Torch "flash" fires with no settle and lights the whole exposure. Whether a real flash is legal with RAW is unverified. | `CaptureService.swift:543-556` | §4.1.7 |
| C15 | P2 | Three code comments contradict the SDK (static vs instance `availableRawPhotoPixelFormatTypes`, prioritization, "Deferred Start"). | `CaptureService.swift:618-622,668-673`; `PreviewView.swift:14-15` | deleted with files |
| C16 | P2 | Cold start: `startRunning()` blocks the actor; `setPreparedPhotoSettingsArray` is unused. | `CaptureService.swift:166,206` | §4.1.8 |
| C17 | P2 | Three uncoordinated orientation sources (AVFoundation EXIF, `UIDevice.orientation`, preview hard-coded `90°`). | `CameraViewModel.swift:281`; `CameraPreview.swift:16,27,35` | §4.1.9 |
| C18 | P2 | The delegate is kept alive by `objc_setAssociatedObject` keyed by its own address. On timeout the photo is dropped *and* the device-state restore is skipped. | `PhotoCapture.swift:34,143-153` | §6.9 |
| C19 | P1 | `stopSession()` lacks the in-flight guard every other mutator has, so backgrounding mid-exposure tears down the session under `capturePhoto`. | `CaptureService.swift:171-179`; research 04 P1-5 | §4.1.8 |
| C20 | P1 | Zero shutter lag is "automatically enabled when supported" for apps linked on iOS 17+ and is never decided. A ZSL frame can predate the press, which conflicts with honest capture time. | `AVCapturePhotoOutput.h:699`; 0 repo hits | §4.1.4 |
| C21 | P1 | `CaptureSessionBox: @unchecked Sendable` hands the raw session to the main thread, undoing the serial-executor design. `queryActiveBayerFormat()` hops to the main actor on every capture. | `CaptureService.swift:625-631,686-691` | §6.9 |

### 2.2 Develop (research 02, 03)

| # | Sev | Defect | Evidence | → |
|---|---|---|---|---|
| D1 | P0 | **The recipe has never applied.** `CIRAWFilter(imageData:)` (1-arg) returns a `CIRAWFilterImpl` stub that implements none of the properties. `responds(to:)` returns false for all 15 setters, so the code silently skips them and renders Apple's full default look. `CIRAWFilter(imageData:identifierHint:)` and `CIRAWFilter(imageURL:)` return the real class. | `CIRAWZeroProcessor.swift:31,121-125`; research 03 §P0-1 (measured) | §4.2.1 |
| D2 | P0 | `highlightRecoveryEnabled` defaults to **true** and is left on. The stated reason ("unavailable since iOS 19") is wrong: `NS_AVAILABLE(16_0,19_0)` means deprecated, and the property is settable and measured `true`. | `CIRAWZeroProcessor.swift:60-62`; research 02 D10, 03 P0-5 | §4.2.2 |
| D3 | P0 | `baselineExposure = 0` overrides the DNG's own value (−0.302 EV on the fixture), adding an undeclared +0.30 EV edit. | `CIRAWZeroProcessor.swift:65`; research 02 D10, 03 P0-6 | §4.2.2 |
| D4 | P0 | No tone curve. `boostAmount = 0` gives linear response with nothing replacing it, so the image is flat and milky. | `CIRAWZeroProcessor.swift:67`; research 03 P0-4 | §4.2.3 |
| D5 | P0 | No output encoder. A developed image can never leave the app. | research 03 P0-2 | §4.2.5 |
| D6 | P0 | The gallery and camera thumbnail use `PHImageManager` `.current`/`.fast`, i.e. Photos' own RAW render; the viewer uses ours. The same photo has two looks. | `PhotoLibraryManager.swift:676-695` | §4.3.4 |
| D7 | P0 | `decoderVersion` is unpinned, so the look drifts with OS updates. On RAW 9, three recipe controls become no-ops. | `CIRAWZeroProcessor.swift:59`; research 03 P0-8 | §4.2.2 |
| D8 | P1 | Zero app-authored pixels: no `linearSpaceFilter`, no kernel, no LUT. | research 03 P1-9 | §4.2.3 |
| D9 | P1 | `CIContext` is created on the main thread per viewer, with the export configuration (`cacheIntermediates: false`) used for interactive work. The working space is implicit, output is 8-bit, and every view renders at full resolution. | `GalleryView.swift:154`; `DevelopService.swift:21-33,77` | §4.2.4 |
| D10 | P1 | Orientation is correct only by an undocumented default. `CaptureOrientation` is persisted and never read. | `DevelopService.swift:45-53,91-104` | §4.2.1 |
| D11 | P1 | Two error cases with no recovery. The viewer failure state has no Retry and no Dismiss. | `RAWProcessor.swift:38-52`; `GalleryView.swift:169-176` | §6.4, §5.6 |
| D12 | P1 | The test fixture `IMG_1361.DNG` is **Apple ProRAW / Linear DNG**, which the app never produces. It is 12-bit LinearRaw with no CFA tags and an embedded semantic sky matte. | research 01 F12, 02 D13 | §7.9 |
| D13 | P2 | Fractional crop rects; `zoomFactor` unvalidated at the develop boundary; no `autoreleasepool`; the rendition duplicates memory. | research 03 P2-15..18 | §4.2 |
| D14 | P0 (design trap) | **Custom kernels cannot run inside `linearSpaceFilter`.** Measured on the iOS 26.5 simulator and on macOS: any `CIColorKernel`/`CIKernel` inside it either makes `outputImage` nil or is silently discarded. Only built-in `CIFilter`s survive there, and a `CIFilter` subclass there must declare `@objc dynamic var inputImage: CIImage?` or the process crashes. `CIColorCube` inside it renders black. Research 03's "our kernels in `linearSpaceFilter`" plan does not work. | research 06 C5.3 | §4.2.3 |
| D15 | P1 (design trap) | `CIRAWFilter.supportedCameraModels` (934 entries) does **not** contain `"iPhone13,3 back camera"`, yet that DNG decodes perfectly. Gating on it rejects valid files. | research 06 §10.1 | §4.2.1 |
| D16 | P1 (design trap) | `CIContext.render(_:toBitmap:…format: .RGBAh…)` into a malloc'd buffer traps (SIGTRAP) at full size. Float readback must use `render(_:to: CVPixelBuffer(kCVPixelFormatType_64RGBAHalf), bounds:, colorSpace:)`. | research 06 C6, §10.11 | §4.2.4 |
| D17 | info | `CIRAWFilter` **can** deliver scene-linear values with headroom. With `boostAmount = 0` and `extendedDynamicRangeAmount` = 1 or 2, rendered into a `64RGBAHalf` extended-linear target, max 1.85 or 2.69 on the iOS 26.5 simulator (at EDR 0 only 5 px exceed 1.0). `outputImage.colorSpace` is tagged Display P3 regardless. | research 06 C6 | §4.2.3 |

### 2.3 Storage (research 01, 02, 03)

| # | Sev | Defect | Evidence | → |
|---|---|---|---|---|
| S1 | P0 | `isDNGResource` matches one exact UTI string on `.photo`. If Photos normalises it, every capture vanishes from the gallery. | `PhotoLibraryManager.swift:893-895` | §4.3.3 |
| S2 | P1 | Backgrounding during save silently drops the result (generation guard). There is no journal, so a crash between capture and save loses the photo. | `CameraViewModel.swift:146,332-339` | §4.3.1 |
| S3 | P1 | Deleting from the viewer blanks the full-screen cover during the Photos round-trip. | `PikicamLibraryModel.swift:54-63`; `GalleryView.swift:56-68,219-222` | §5.6 |
| S4 | P2 | `UTType(...)!` force unwrap; `creationDate` never set; no metadata injection. | `PhotoLibraryManager.swift:217,290-292` | §4.3.2 |

### 2.4 UI/UX (research 05)

| # | Sev | Defect | → |
|---|---|---|---|
| U1 | P0 | No camera controls: no ISO, shutter, WB, focus, histogram, clipping, level, AE/AF lock or reticle. Five toggles and a zoom chip row. | §5.3 |
| U2 | P0 | Controls are invisible over a bright scene: HUD caption ≈1.1:1, shutter 1.0:1, mask border 1.6:1, chips 3.98:1. | §5.1 |
| U3 | P0 | Zero Dynamic Type, Reduce Motion, Increase Contrast, Reduce Transparency, Differentiate Without Color or haptics. Nine hard-coded font sizes. The product claim truncates at AX5. | §5.7 |
| U4 | P0 | Hit targets of 17–29 pt; no 44 pt contract. | §5.1 |
| U5 | P0 | VoiceOver: gallery cells say "Button, image"; the EV slider is not adjustable; hiding viewer chrome removes the only exits. | §5.7 |
| U6 | P0 | The aperture mask is computed over the full screen while ~26% of it sits under the chrome. The develop crop uses those same numbers, so what is cropped is not what was framed. | §5.3, §4.2.3 |
| U7 | P1 | No capture feedback except a 30% veil on the shutter; the thumbnail shows the *previous* capture. | §5.3 |
| U8 | P1 | Landscape is enabled but undesigned; the preview rotation is hard-coded. | §5.2 |
| U9 | P1 | Volume-button shutter: dead at volume 0 and 1, with the system HUD over the viewfinder. | §5.3 (replaced by `onCameraCaptureEvent`) |
| U10 | P1 | The shutter silently cancels the timer; the "tap anywhere to cancel" comment is false. | §5.3 |
| U11 | P1 | Permissions: one "Open Settings" for every state, including `.restricted`; on the simulator the gate can strand the user on the welcome screen. | §5.5 |
| U12 | P1 | Errors appear as red caption text near the home indicator, undismissable and cleared by the next shutter press. | §5.8 |
| U13 | P1 | `.preferredColorScheme(.dark)` is forced at the root. | §5.1 |
| U14 | P1 | No share, no settings, no zoom in the viewer, no paging, no metadata. | §5.6 |
| U15 | P1 | The "design system" is 2 inert files. The lint allowlists 5 files that don't exist, reports 777 violations, and 6 of its own 26 tests fail. | §6.11 |
| U16 | P1 | The scheme omits `pikicamUITests`, so 812 lines of UI tests never run. The tests and views disagree on 6 identifiers. | §7.9 |
| U17 | P2 | Two different destructive-confirmation presentations; duplicate accessibility identifiers. | §5.6 |

### 2.5 Code quality, build and CI

Source: research 04, which is the full audit with a per-file verdict.

| # | Sev | Defect | Evidence | → |
|---|---|---|---|---|
| Q1 | P0 | Unit suite red. `testZeroRecipeReachesEveryControlOnARealFilter` crashes the host (`doesNotRecognizeSelector`), which aborts the rest of the suite ("Executed 0 tests" on restart). `testZeroDevelopProducesViewableJPEGFromRealDNG` passes vacuously (asserts extent > 1000 and luminance > 5). 35 of 36 unit tests assert only arithmetic on value types. | `PikicamPipelineTests.swift:38-66,514-590`; research 04 §Build | §7 |
| Q2 | P0 | CI is a false green. The only workflow (`design.yml`) is "expected to be RED", runs no build and no unit tests, checks the pbxproj but not the scheme, and hard-codes the simulator `iPhone 17`, which does not exist here (`iPhone 17 Pro` does). `.pre-commit-config.yaml` calls the deleted `scripts/verify.sh`. `xcodegen` is **not installed** on this machine. | research 04 P0-4 | §6.1, Phase 0 |
| Q3 | P1 | Swift 6 does not compile. `SWIFT_VERSION 6.0` fails at `PhotoLibraryManager.swift:829` (global mutable `inFlightSaveIDs`). Strict concurrency reports a nonisolated `deinit` touching actor state (`CaptureService.swift:60`), a main-actor `@objc` tap handler reached from a nonisolated context (`CameraPreview.swift:55-57`), and non-Sendable `AVCapturePhoto` sent across executors (`PhotoCapture.swift:49,129`). There are 39 decorative `nonisolated` annotations and a redundant `@unchecked Sendable` on a `@MainActor` class. | research 04 P1-5 | §6.1, §6.9 |
| Q4 | P1 | `CameraViewModel` is a god object: 20 published properties, three overlapping busy-state machines (`phase`, two tasks, two generation counters), state mirrored from the actor that nothing resyncs, and `error: Error?` rendered as raw `localizedDescription`. | `CameraViewModel.swift:41-83,159-164,266-306` | §6.2, §6.3 |
| Q5 | P1 | Storage is a 1,015-line journal/index/reconciler. Every save triggers `refresh()` on the shutter path, which takes a process-wide `NSLock` and may scan **every asset and resource in the user's library**. Losing the JSON index hides photos that are still in Photos. The change observer has no debounce and refreshes on the app's own saves. | `PhotoLibraryManager.swift:429-560`; `PikicamLibraryModel.swift:43-84` | §4.3 |
| Q6 | P1 | Zero dependency seams: models hard-code `CaptureService()`/`PhotoLibraryManager()` and spawn tasks in `init`. `RAWProcessor` is a protocol with one conformer that is never swapped. | research 04 P1-8, §A-E | §6.6 |
| Q7 | P1 | A `CIContext` + Metal device is rebuilt on every `GalleryView` re-init (`@State` default-value expression), while the comment above it claims the opposite. | `GalleryView.swift:150-154` | §4.2.4 |
| Q8 | P1 | Two Info.plist sources with divergent user-facing strings: `GENERATE_INFOPLIST_FILE` in `project.yml`, but the pbxproj still sets `INFOPLIST_FILE` for Release. The test targets use device family `1,2`. | research 04 P2-11 | §6.1 |
| Q9 | P1 | `PrivacyInfo.xcprivacy` declares three required-reason APIs (file timestamp, disk space, boot time) that the app never calls. It is a false declaration. | research 04 P2-11 | §6.1 |
| Q10 | P1 | Layering is violated: `Core/Storage` depends on `Features/Camera` and `Features/Develop` types (`AspectRatio`, `CaptureOrientation`). | research 04 §A | §6.11 |
| Q11 | P2 | Dead code: `Room`, `ControlIDRegistry`, `AspectRatio.next()`, `PreviewView.layerPoint`, `PikicamCapture.pixelWidth/Height/orientation`, `DNGDisplayRendition.ciImage`, write-only `invalidationTask`. Two identical thumbnail views; two identical PhotoKit continuation bridges; a duplicated device-lock block. ~22% of lines are comments, much of them incident archaeology. | research 04 P2-10 | delete |
| Q12 | P2 | `.swiftlint.yml`/`.swift-format` are never enforced (SwiftLint is not installed). `.agents/skills/swift-coding-standards/SKILL.md` describes types and folders that do not exist. | research 04 P2-11, per-file verdicts | §6.11 |
| Q13 | P2 | Test anti-patterns: a "probe" test that writes six assets into the user's real library, a test that documents its own unsoundness, copy-assertion tests, `RunLoop` sleeps and blind coordinate taps in the UI suite, and a `#filePath`-rooted regex lint. | research 04 P1-8 | §7 |

---

## 3. What is already correct — do not regress

These are verified (research 01 "Verified-correct", 02 D1-D6). Keep them, and add positive assertions for each (§4.1.5).

1. ProRAW is off: `photoOutput.isAppleProRAWEnabled = false`, set before `startRunning()`.
2. No processed companion: settings come from `AVCapturePhotoSettings(rawPixelFormatType:)`, and `format`/`processedFormat`/`previewPhotoFormat` are never set. This leaves Deep Fusion, Smart HDR, Night fusion, semantic rendering, red-eye, content-aware distortion correction and virtual-device fusion all off by platform default for Bayer RAW.
3. Capture at `videoZoomFactor == 1.0` is **mandatory** for Bayer RAW (`AVCapturePhotoOutput.h:84-86`), not a hack.
4. A **physical** device is selected, never a virtual one. Virtual devices do not support `.custom` exposure or custom WB gains (`AVCaptureDevice.h:540-561`). Manual control depends on this.
5. Video stabilization defaults to off.
6. Tap-to-focus mapping via `captureDevicePointConverted(fromLayerPoint:)` is correct.
7. The DNG UTI is `com.adobe.raw-image`. Define it once as `enum DNG { static let uti = "com.adobe.raw-image"; static let type = UTType(importedAs: uti) }`; no force unwraps.

Platform ceilings that shape the product. These are facts, not bugs:
- Bayer RAW on iOS is a single, un-fused, 1× exposure per physical lens, capped at the ~12 MP readout. This follows from Apple's documented rules (research 06 C8): Bayer RAW requires `.speed` (`AVCapturePhotoOutput.h:85`); 48 MP requires `.balanced`/`.quality`; 18/24 MP are multi-frame fused and deferred-only (`:114`, `:545`, WWDC26-304). Halide's statement is corroboration only. The device probe records the real `rawPhotoDimensions`; the UI never implies more.
- The live preview can never be Apple-free. The honest design is a deterministic ISP preview plus a post-capture review rendered by our pipeline (research 02 D20).
- `CIRAWFilter.outputImage` is always *tagged* Display P3. With `boostAmount = 0` and EDR headroom, its values are linear-response and exceed 1.0 (research 06 C6). Custom kernels cannot run inside `linearSpaceFilter` (research 06 C5.3), so our pixels run after `outputImage` (§4.2).
- Apple's demosaic, black level, linearization and colour matrix remain Apple's in v1. The `Developer` protocol is the seam for a future own-demosaic from `AVCapturePhoto.pixelBuffer` (§9). The README states this plainly.
- Video can never be Bayer. iOS exposes no raw sensor video stream; the ISP always demosaics and shapes video frames. §4.5 defines honest video as deterministic device configuration plus our look applied by our code to the best available frames (10-bit HLG where the probe confirms it).

---

## 4. Target behaviour

### 4.1 Capture

**4.1.1 Devices.** The rear physical devices are `.builtInUltraWideCamera`, `.builtInWideAngleCamera` and `.builtInTelephotoCamera`. For each one present, configure it and read `photoOutput.availableRawPhotoPixelFormatTypes`. Offer a lens only if that list contains a format for which `AVCapturePhotoOutput.isBayerRAWPixelFormat(_:)` is true. Lens availability is probed once at launch, by configuring each lens in turn before the preview starts. Everything per-lens (RAW formats, `supportedMaxPhotoDimensions`, ISO/exposure/WB limits) is re-read inside every configuration transaction and cached **per configuration**, never per launch: these values belong to the current device and `activeFormat` (`AVCapturePhotoOutput.h:230-232`). The front camera is not offered (no Bayer RAW), and virtual devices are never used. Switching lens reconfigures the session to that physical device. The lens rail shows each lens's 35 mm-equivalent focal length, computed inside the configuration transaction as `round(18 / tan(activeFormat.videoFieldOfView° / 2))` (horizontal FOV against a 36 mm frame width). After the first capture it is cross-checked against EXIF `FocalLenIn35mmFilm`; a difference > 2 mm is logged and the rail label gains a `≈`. A digital crop is offered only as a framing choice (`CROP`, §5.3), never as a lens.

**4.1.2 Format and dimensions.** Use `sessionPreset = .photo`. After `addInput`/`addOutput`, set `photoOutput.maxPhotoDimensions` to the largest entry (by pixel count) of `device.activeFormat.supportedMaxPhotoDimensions`, before `startRunning()`. For each capture, set `settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions`. Choose the Bayer format with `availableRawPhotoPixelFormatTypes.first(where: AVCapturePhotoOutput.isBayerRAWPixelFormat)` and delete the literal OSType list. Log `activeFormat`, all RAW formats, and the chosen dimensions once per configuration (`os.Logger`, category `capture`).

**4.1.3 Device determinism.** Inside one configuration transaction (`beginConfiguration`/`commitConfiguration`, with the device locked synchronously, and no `await` inside the lock):
- `AVCaptureDevice.centerStageControlMode = .app`; `AVCaptureDevice.isCenterStageEnabled = false` (class properties, set before `startRunning()`).
- If `device.isGeometricDistortionCorrectionSupported`, then `device.isGeometricDistortionCorrectionEnabled = false`. Preview FOV must equal RAW FOV.
- `device.automaticallyAdjustsVideoHDREnabled = false`; if `activeFormat.isVideoHDRSupported`, then `device.isVideoHDREnabled = false`.
- `session.automaticallyConfiguresCaptureDeviceForWideColor = false` **first** (it defaults to YES and would undo the next line; `AVCaptureSession.h:597`). Then `device.activeColorSpace = device.activeFormat.supportedColorSpaces.contains(.P3_D65) ? .P3_D65 : .sRGB`; the support list is on the **format** (`AVCaptureDevice.h:3411`). Never Apple Log: photo capture is unsupported under it (`AVCapturePhotoOutput.h:115-116`).
- `device.isLowLightBoostEnabled` stays false: assert `automaticallyEnablesLowLightBoostWhenAvailable == false`.
- On the preview connection: `preferredVideoStabilizationMode = .off`.

Each of these values is read back after commit into `DeviceDeterminism` (a struct of Bools plus the colour space). If any value is not as required, it is a typed configuration error. The exception is unsupported features, which are recorded as `.notSupported`.

**4.1.4 Per-shot settings.** Build them in one place, `CaptureRequest.makeSettings()`:
```
let settings = AVCapturePhotoSettings(rawPixelFormatType: request.bayerFormat.osType)
settings.photoQualityPrioritization = .speed   // already the RAW-factory default (research 06 C9); set so the rule is our code, AVCapturePhotoOutput.h:85
settings.maxPhotoDimensions = output.maxPhotoDimensions   // a RAW settings object reads (0,0) until set (research 06 C8)
settings.flashMode = .off                       // see 4.1.7
settings.metadata = request.metadata            // §4.1.5
```
At configuration time (before `startRunning()`):
- Set `photoOutput.maxPhotoQualityPrioritization = .speed`. Never offer `.balanced` or `.quality`; `.quality` throws for RAW and enables OIS-driven multi-frame (`AVCapturePhotoOutput.h:344`).
- If `photoOutput.isZeroShutterLagSupported`, set `photoOutput.isZeroShutterLagEnabled = false`: the exposure must start after the press, so capture time is honest. Also set `isResponsiveCaptureEnabled = false` and `isFastCapturePrioritizationEnabled = false` where supported.
- On the output: `photoOutput.isAutoDeferredPhotoDeliveryEnabled = false` (an output property, not a settings property). Deferred proxies are never RAW (`AVCapturePhotoOutput.h:114,2304-2310`).

Immediately before `capturePhoto`, assert `device.videoZoomFactor == 1.0` and `photoOutput.connection(with: .video)?.videoScaleAndCropFactor == 1.0`. A violation is a programmer bug (`preconditionFailure` with a message citing `AVCapturePhotoOutput.h:85`): the design never sets zoom. Pinch and "crop" are framing-only (§4.2.3), and the device zoom stays at 1.0 forever, so the 250 ms settle dance is deleted.

Call `photoOutput.setPreparedPhotoSettingsArray([representative], completionHandler:)` after configuration and after every lens switch. Build a **fresh** representative with `CaptureRequest.makeSettings()` each time: a settings object is single-use, and reusing a `uniqueID` throws (`AVCapturePhotoOutput.h:71`). A second prepare call fires the first call's handler with `prepared == NO` (`:146`), so track `prepared` per configuration generation. Drive shutter enablement from `AVCapturePhotoOutputReadinessCoordinator` (`captureReadiness`), not from a hand-rolled boolean.

**4.1.5 Boundary validation and provenance.** A capture is accepted only when every check below passes. Each failure is a distinct typed case.
- `photo.isRawPhoto == true`; if `photo.pixelBuffer != nil`, its `CVPixelBufferGetPixelFormatType` equals the requested Bayer OSType.
- In `didFinishCaptureFor resolvedSettings`: `rawPhotoDimensions` is non-zero, `expectedPhotoCount == 1`, and `!isVirtualDeviceFusionEnabled`, `!isContentAwareDistortionCorrectionEnabled`, `!isStillImageStabilizationEnabled`, `!isRedEyeReductionEnabled`.
- `fileDataRepresentation()` is non-nil, starts with a TIFF header (`II*\0` or `MM\0*`), and parses as a DNG whose raw IFD has `PhotometricInterpretation == 32803` (CFA). `34892` (LinearRaw) means Apple-processed data and is rejected. If a device delivers CFA data without CFA geometry tags, accept and record `cfaTagsPresent = false`; the device probe settles this.
- Provenance is captured at shutter: device `uniqueID`, `deviceType`, lens, `lensAperture`, `activeFormat` description, Bayer OSType, `rawPhotoDimensions`, `iso` (Swift spelling), `exposureDuration`, `lensPosition`, WB gains and temperature/tint, exposure mode, `DeviceDeterminism`, ZSL state, iOS version and app version. There is no `AVCaptureDevice.aperture`. The f-number, like ISO, shutter, lens and date, is also in the DNG's own EXIF and is read on demand.
- `settings.metadata` injects `kCGImagePropertyTIFFSoftware = "pikicam <version>"`. No GPS in v1 (no location permission; recorded as a non-goal).

**4.1.6 Manual exposure, white balance and focus** (physical devices only; every value clamped to device limits read from `activeFormat`).
- Exposure mode `auto(bias: EV)` uses `.continuousAutoExposure` plus `setExposureTargetBias`, clamped to `min/maxExposureTargetBias`. Mode `manual(iso:duration:)` uses `setExposureModeCustom(duration:iso:)`, clamped to `activeFormat.minISO/maxISO` and `min/maxExposureDuration`.
- White balance: `auto`, `lockedCurrent`, or `locked(kelvin:tint:)` via `device.setWhiteBalanceModeLocked(whiteBalanceTemperatureAndTintValues:handler:)`, the iOS 26 API (`AVCaptureDevice.h:1782`). Validate before calling: convert with `deviceWhiteBalanceGains(for:)` and reject any (K, tint) whose gains fall outside `[1, maxWhiteBalanceGain]`, because out-of-range values raise an exception (`:1855`). Do not clamp afterwards.
- Focus: `continuousAuto`, `auto(point)`, or `locked(lensPosition)` via `setFocusModeLocked(lensPosition:)`, guarded by `isLockingFocusWithCustomLensPositionSupported`.
- The AE/AF lock toggle locks the current values.
- Completion handlers are awaited **outside** the configuration lock: set values under `withDeviceLock` (synchronous closure), leave the lock, then await completion with `withTimeout(1 s)` (§6.8).
- Live device readings (ISO, exposure duration, exposure target offset, lens position, WB gains → temperature/tint, `isAdjustingFocus`/`isAdjustingExposure`) are published through KVO as an `AsyncStream<DeviceReadings>`, throttled to 15 Hz.

**4.1.7 Light.** Default is no light. If `photoOutput.supportedFlashModes.contains(.on)` with RAW-only settings and the device probe confirms a RAW capture succeeds with `flashMode = .on`, offer `FLASH`. Otherwise offer `TORCH` labelled as such: turn it on, wait for `torchLevel` to reach the target (KVO, 300 ms timeout), capture, then turn it off. Never call a torch "flash". Until the probe has run on a device, ship `TORCH` only.

**4.1.8 Lifecycle and latency.** `startRunning`/`stopRunning` run on the capture actor's serial queue (custom executor, §6.9), never on the main thread.
- Handle `AVCaptureSession.wasInterruptedNotification`, `interruptionEndedNotification` and `runtimeErrorNotification` (`mediaServicesWereReset` → rebuild the session once, then surface failure), plus scene phase: stop on background, start on active.
- `stop()` while a capture is in flight waits for that capture to finish or time out first; it never tears down the session under `capturePhoto`.
- Lens switching is transactional: remove the old input, add the new one; if anything fails, restore the previous input and configuration inside the same `beginConfiguration`/`commitConfiguration` block, then throw.
- Use iOS 26 deferred start (`session.automaticallyRunsDeferredStart`, `isDeferredStartEnabled` on the photo and meter outputs; both exist on 26.5, research 07), so the preview paints before the photo pipeline is ready.

**4.1.9 Orientation.** There is one source of truth: `AVCaptureDevice.RotationCoordinator(device:previewLayer:)`. `videoRotationAngleForHorizonLevelPreview` drives the preview connection's `videoRotationAngle`; `videoRotationAngleForHorizonLevelCapture` is applied to the photo connection before each capture, so the DNG's EXIF orientation is right. Delete `UIDevice.current.orientation` sampling and `CaptureOrientation`. The developer reads orientation from the DNG (§4.2.1).

### 4.2 Develop

Pipeline shape (decided from measurements; research 06 C2-C6):
```
DNG ─► CIRAWFilter (real class, neutral recipe, pinned decoder, EDR headroom on)
    ─► outputImage   [tagged Display P3; values = linear-response, headroom > 1.0]
    ─► Core Image colour-matches it into the working space extendedLinearDisplayP3  (= scene-linear for us)
    ─► PikicamLook: our Metal CI kernels — exposure → tone curve → gamut compression
    ─► framing crop (FrameGeometry) ─► output space Display P3 (display / HEIC 10-bit)
```
`linearSpaceFilter` is **not used**: custom kernels inside it are discarded or nil the output (D14). Our pixels run after `outputImage`, where Core Image kernels behave normally.

**4.2.1 Front end.**
- Create the filter **only** as `CIRAWFilter(imageData: data, identifierHint: DNG.uti)`, or `CIRAWFilter(imageURL:)` for journaled files. The 1-arg spelling binds to the deprecated `CIFilter.filterWithImageData:options:` category and returns a legacy `CIRAWFilterImpl` that ignores every property (D1, research 06 C2). A unit test fails if any source file constructs `CIRAWFilter(imageData:` without `identifierHint:`.
- After creation, require `type(of: filter) == CIRAWFilter.self`, otherwise `DevelopError.filterUnavailable`. There are no `responds(to:)` checks anywhere: properties are assigned directly and type-checked by the compiler.
- Validate decodability by `filter.outputImage != nil` and `filter.nativeSize != .zero`. **Do not** gate on `supportedCameraModels` (D15).
- `decoderVersion`: choose the highest member of `filter.supportedDecoderVersions` that is not `CIRAWDecoderVersion.version9` or `.version9DNG` (the Swift spellings, `CIRAWFilter.h:28-29`; these symbols exist on 26.5 but must never be selected automatically). Set it explicitly and record it. If nothing qualifies, throw `DevelopError.decoderUnavailable`.
- `orientation`: set explicitly from `filter.properties[kCGImagePropertyOrientation]` (default `.up`).
- `scaleFactor` and `isDraftModeEnabled`: from the render target (§4.2.4).

**4.2.2 Neutral recipe** (defines "Apple's look is not applied"). Assign every control below directly. Read every one back. Produce a `RecipeApplication` listing `applied`, `unsupported` (only where the matching `is…Supported` is false), and runtime defaults that differed from neutral.

| Control | Neutral value | Note |
|---|---|---|
| `boostAmount` | 0 | linear response; our tone curve replaces Apple's (4.2.3) |
| `boostShadowAmount` | 1 | documented neutral; measured inert at boost 0 |
| `shadowBias` | 0 | per-image Apple bias; measured *not* inert, so it is set |
| `localToneMapAmount` | 0 | |
| `contrastAmount` | 0 | |
| `sharpnessAmount` | 0 | |
| `detailAmount` | 0 | |
| `luminanceNoiseReductionAmount` | 0 | |
| `colorNoiseReductionAmount` | 0 | |
| `moireReductionAmount` | 0 | |
| `extendedDynamicRangeAmount` | `E` (Phase 0 chooses 1 or 2) | headroom for our tone curve, not an HDR output. Choose the largest value whose linear render differs from EDR 0 by < 1% mean on pixels below 0.8; else 1 |
| `isLensCorrectionEnabled` | false | geometry stays sensor-true, matching the GDC-off preview |
| `isGamutMappingEnabled` | false | **Deliberate deviation from research 06 C6, which recommends `true`.** Our stage owns gamut compression (4.2.3). Measured cost at boost 0: min −0.008, ~5 negative px at 0.25 scale. Phase 0 records the negative-pixel fraction at the chosen `E`; if it exceeds 0.1%, switch to `true` and record |
| `highlightRecoveryEnabled` | false | deprecated in 19, still present and settable, measured `true` by default. Its measured effect at boost 0 is ≤ 0.06% of pixels, but an Apple enhancement must not be on. Assign directly, `filter.isHighlightRecoveryEnabled = false`: `NS_AVAILABLE(16_0,19_0)` produces no Swift warning on the 26.5 SDK (verified under `-warnings-as-errors`, research 07 F12) |
| `exposure` | 0 | user EV lives in our stage. Apple's `exposure` is applied at a different point than a linear multiply (research 06 C5.1) |
| `baselineExposure` | **not set** | equals the DNG's tag (−0.302 on the fixture); forcing 0 is a +0.30 EV edit |
| `neutralTemperature`/`neutralTint` | as-shot, unless the user edits WB | WB through the DNG colour model (`ColorMatrix1/2` + `AsShotNeutral`, both present: research 06 C1) is the honest white-balance stage |
| `despeckleAmount` | 0 under `if #available(iOS 27, *)` | future control |

The recipe is a versioned value (`NeutralRecipe.version = 1`). A golden test pins it (§7).

**4.2.3 Our stage: `PikicamLook`.** A `CIFilter` subclass (`@objc dynamic var inputImage: CIImage?` plus typed parameters), applied to `outputImage` in the working space `extendedLinearDisplayP3`.
- Kernels are Metal CI kernels in `Develop/PikicamLook.ci.metal`, compiled through Xcode's build rule with the CI kernel flags (§6.1) and loaded from the bundle's `.metallib`.
- Per-pixel stages are `CIColorKernel(functionName:fromMetalLibraryData:)`. A Metal colour kernel receives its own pixel as `coreimage::sample_t`, which is all max(R,G,B) needs.
- Use `CIKernel(functionName:fromMetalLibraryData:)` only for a stage that reads *neighbouring* pixels; v1 has none.
- Do not use runtime kernel-source strings: that path is deprecated, and research 06 C5.3 showed its colour kernels cannot `sample()`.
- Phase 0 item 4 compiles and runs one kernel of each kind to confirm.

In order:
1. **Exposure:** multiply RGB by `2^EV` (user, default 0).
2. **Tone curve:** a filmic curve from scene-linear input to display-linear output.
   - **Input** may exceed 1.0: that is the EDR headroom from `extendedDynamicRangeAmount = E`. Measured linear max is 1.85 at E=1 and 2.69 at E=2 on the iOS 26.5 simulator (research 06 C6).
   - **Output** lies in [0, 1].
   - Default "Standard": 0 → 0; mid-grey 0.18 → 0.18; a toe near black; a shoulder that approaches 1.0 asymptotically, so the maximum headroom input maps just below 1.0 with no hard clip.
   - User parameters `contrast`, `highlights` and `shadows`, each in [-1, 1] and 0 by default.
   - Applied to max(R,G,B) with ratio-preserving scaling, so hue does not shift. Document the formula and its source in the kernel.
3. **Gamut compression:** soft-compress negative and out-of-gamut values toward the achromatic axis (distance-based, ACES reference-gamut-compression style; document the parameters).
4. **Noise reduction and sharpening:** none in v1 (non-goal).

Framing crop (aspect ratio plus optional crop zoom) is applied last, as an integral-rounded `cropped(to:)`. The crop rect comes from `FrameGeometry`, the same normalised rect the viewfinder overlay uses (§5.3), so the two cannot disagree.

**4.2.4 Contexts and rendering.** Use exactly two `CIContext`s, created once, lazily, off the main thread, and owned by the developer actor. Neither is ever created from a SwiftUI `@State` default. Colour spaces are built with `CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)!` / `CGColorSpace(name: CGColorSpace.displayP3)!`: the `CGColorSpace.*` constants are `CFString` *names*.
- `interactive`: `[.workingColorSpace: extendedLinearP3, .workingFormat: CIFormat.RGBAh, .cacheIntermediates: true, .outputColorSpace: displayP3]`.
- `export`: the same colour settings, `.cacheIntermediates: false`, `.memoryTarget: 1024`. The Swift name `CIContextOption.memoryTarget` comes from `CoreImage.apinotes`, not `CIContext.h`.
- The 26.5 SDK has no rendering-intent option. The final working → Display P3 match is therefore ColorSync's default, which is itself a gamut map, applied after `PikicamLook`. It is the one place Apple colour management still touches a pixel, and the reason our gamut compression is soft. Record this in `docs/DECISIONS.md`.

Render targets:
- `.thumbnail(maxPixel: 512)`: `scaleFactor = 512 / longEdge`, `isDraftModeEnabled = true`.
- `.display(pixelSize:)`: `scaleFactor` fitted to screen pixels.
- export (a separate `Developer.export` method): full resolution.

Float readback (tests, meters) **must** use `render(_:to: CVPixelBuffer(kCVPixelFormatType_64RGBAHalf), bounds:, colorSpace:)`. Never use `render(_:toBitmap:)` with `.RGBAh` into malloc'd memory; it traps at full size (D16). Display output is `ctx.createCGImage(image, from: rect, format: .RGBA16, colorSpace: displayP3)`, a 16-bit Display-P3-tagged `CGImage`; Phase 0 item 5 verifies it at full size, otherwise go through a `CVPixelBuffer`. Never an untagged 8-bit image. Every render checks `Task.checkCancellation()` between stages and runs inside `autoreleasepool`.

**4.2.5 Encode.** Export is HEIC 10-bit Display P3 via `try await ctx.heif10Representation(of: image, colorSpace: displayP3, options: [:])`. It returns `Data?`; a `nil` is `DevelopError.encodeFailed`. Metadata: the DNG's EXIF (ISO, exposure, f-number, lens, focal length, date) from `filter.properties`, plus `Software = "pikicam <version>"`. The DNG is never modified.

**4.2.6 Monochrome (BNW).** Monochrome is a develop-path decision, not a camera decision: the DNG is always the same untouched Bayer file, and mono is a reversible look.
- `LookParameters` gains `mono: MonoState?` — `nil` is colour; non-nil is monochrome. `MonoState` is a `MonoPreset` plus optional custom `MonoWeights` (three floats, non-negative, sum 1.0, `init(validating:)` rejects anything else).
- Conversion happens in scene-linear, after exposure and **before** the tone curve: `y = w·rgb`, then the curve applies to `y`. This is the classic filter-model order and keeps the curve's meaning identical between colour and mono.
- The default weights derive from the working primaries' RGB→XYZ luminance row. The derivation is stated in the kernel source with its matrix source (a spec citation, not a folk constant).
- Presets (`MonoPreset`): `Neutral` (the luminance row), plus Yellow, Orange, Red, Green and Blue filter simulations as committed weight vectors, each with a one-line rationale. A preset is data, not a new kernel.
- The tone curve in mono is the same Standard curve; mono-specific contrast uses the existing `contrast` parameter.
- **Dither:** the final pre-encode stage adds triangular-PDF dither of ±0.5 LSB at 10-bit output, so flat skies do not band. The dither is deterministic per pixel (a hash of coordinates), not random, so fingerprints stay reproducible.
- Every mono render asserts R == G == B within 10-bit quantisation (DoD 13).
- UI: a `MONO` toggle in Quick Settings and a preset row in the Develop panel (§5.4, §5.6). Mono state is part of `AdjustmentPayload`, so it round-trips through Photos like every other edit and Revert removes it.

**4.2.7 The 0–23 numeric lines (look presets, honestly mapped).** The design export's Numeric Line Matrix (`docs/design-source/`, the Margiela 0–23 collection taxonomy) is pikicam's preset engine. A line is a `LineProfile`: an optional `LookParameters` preset, an optional `MonoPreset`, an optional camera-behaviour binding (lens, level lock). Two rules keep it honest:

1. **A line never fakes a look the pipeline does not have.** The export describes lines as "vaporous grain", "halation", "soft-focus diffusion" — grain and halation are v1 non-goals (§9). Such lines ship **dormant**: rendered in the matrix, muted, non-interactive, labelled `DORMANT` with the reason in its accessibility hint. Never a placebo preset.
2. **Preset values are tuned, then pinned.** Each shipped line's parameters are tuned in Phase 3 against the export's one-line intent, then pinned by pixel fingerprints like every other develop decision. The export's prose is the brief, not the numbers.

| Line | Name | v1 mapping |
|---|---|---|
| (0) | Artisanal | NeutralRecipe + the Standard curve — the house default. The badge's `[RAW]` state. |
| 1 | Collection Femme | Softer: contrast −, shadows +, highlights − (tune to "soft architectural contrast, desaturated skin"); colour |
| 3 | Fragrance | **DORMANT** — grain and halation are non-goals |
| 4 | Garde-Robe | Neutral colorimetry — recorded as an alias of (0) in v1 (ledger entry) |
| 10 | Collection Homme | Harder: contrast +, highlights − ("hard structural shadows, high micro-contrast"); colour |
| 11 | Accessoires | Binds the telephoto lens; the edge-detection overlay is **DORMANT** |
| 14 | Fundamentals | Mono: `MonoPreset.neutral` weights + contrast + ("Ilford HP5 emulsion" intent) |
| 22 | Tabi | Binds the level lock (horizon hold); perspective correction is **DORMANT** |
| all others | — | **DORMANT** by default |

The active line is part of `LookParameters` (a `line: Int?` tag), so it round-trips through `AdjustmentPayload` and re-render, and the Info sheet reports it. Selecting a line never changes capture settings silently: lines 11 and 22 announce their binding (lens switch, level lock) as visible state changes.

### 4.3 Storage

Photos is the store; the app keeps no index file. A side index whose loss hides photos is exactly the failure research 04 P1-7 found.

**4.3.1 Journal first (crash safety only).** On capture acceptance, atomically write the DNG and a `JournalEntry` (Codable, versioned) to `Application Support/Journal/<CaptureID>/`, then develop and save. The journal entry is deleted only after the Photos save succeeds. On launch, `RecoveryFlow` finishes every pending entry before the shutter enables. `UIApplication.beginBackgroundTask` wraps develop + save, so backgrounding never drops a capture.

**4.3.2 Photos asset.** One `PHAssetCreationRequest` per capture, with `creationDate = capturedAt`, added to the app's album "pikicam" in the same `performChanges` block.
- Resources are added with `request.addResource(with:fileURL:options:)`.
- A `PHAssetResourceCreationOptions` sets `originalFilename` (`PIKI_<yyyyMMdd_HHmmss>_<4 hex>.dng` / `.heic`) and `contentType` (`DNG.type` / `.heic`). `uniformTypeIdentifier` is the deprecated spelling; do not use it.

**Goal:** Photos (and every app reading the library) displays **our** render, the untouched DNG stays in the asset, and our `AdjustmentPayload` travels with it. Which resource layout achieves this is not documented reliably, so Phase 0 item 8 decides it empirically on the simulator Photos library. Try these candidates in order and ship the first that passes:

| | Resources | Notes |
|---|---|---|
| **A** | `.photo` = DNG, `.fullSizePhoto` = our HEIC, `.adjustmentData` = `PHAdjustmentData("piki.pikicam.look", "1", JSON(payload))` | "DNG original + pikicam edit"; Photos' Revert returns to the DNG |
| **B** | `.photo` = our HEIC, `.alternatePhoto` = DNG | LibreCam/Halide style (research 02 D17 option A) |
| **C** | `.photo` = DNG, `.alternatePhoto` = our HEIC | the pairing Apple's RAW capture guide describes (research 02 D17) |

**Pass criterion:**
1. `PHAssetCreationRequest.supportsAssetResourceTypes(...)` is true for the set.
2. `performChanges` succeeds.
3. `PHImageManager.requestImage(… version: .current …)` returns pixels matching our HEIC (mean absolute difference < 2/255 at 256 px).
4. The DNG bytes come back unchanged via `PHAssetResourceManager`.

For B and C, the payload is committed right after creation as the first content edit, in the same flow and through the `EditFlow` node, so every shape ends with our adjustment data on the asset. Record the chosen shape, and the results for all three, in `docs/DECISIONS.md`.

If develop fails at capture time, save the DNG alone as `.photo` (divergent strategy, §6.11). The capture shows as `.pending` until the viewer re-develops it and saves an edit.

**4.3.3 What is a pikicam capture.** An asset is pikicam's when it is in the "pikicam" album **and** has a resource that is a DNG (UTI in `{com.adobe.raw-image, public.camera-raw-image}` or filename ending `.dng`), regardless of resource type. Find the album by its `localIdentifier` stored in `UserDefaults`, falling back to title lookup, and recreate it if it is missing. Library listing is one album fetch (newest first) and never a whole-library scan. `PHPhotoLibraryChangeObserver` changes are debounced (250 ms) and coalesced, and the app's own saves update the list directly instead of triggering a refetch. Limited library access is handled explicitly (§5.5): with `.limited`, assets the app created remain visible.

**4.3.4 Thumbnails and display.** Every in-app image is rendered by our developer from the DNG plus the asset's `LookParameters`:
- thumbnails at 512 px, cached on disk as `Caches/Thumbs/<CaptureID>-<lookHash>.heic`, with an `NSCache` in front;
- concurrent requests for the same key share one task.

`PHImageManager` is not used anywhere in the app; only the Phase 0 probe uses it. The DNG bytes come from `PHAssetResourceManager`, located by `AssetBoundary` at whichever resource type the shipped shape uses. A cell that is still rendering shows a neutral placeholder.

**4.3.5 Edits.** Viewer edits (exposure, WB temperature/tint, contrast, highlights, shadows) form a `LookParameters` value. Committing writes a `PHContentEditingOutput` with the same adjustment format and a re-rendered HEIC. "Revert to original" calls `PHAssetChangeRequest.revertAssetContentToOriginal()`. The DNG resource is never modified. Adjustment data with an unknown format or version means the asset was edited elsewhere: show it as "Edited outside pikicam". Our develop starts from neutral defaults, and saving overwrites that edit only after a confirmation.

**4.3.6 Share.** "Share original" shares the DNG file: `ShareLink` with a `Transferable` that exports the DNG resource to a temp file via `PHAssetResourceManager.writeData`. "Share developed" shares the HEIC.

### 4.4 Preview and meters

- The preview is `AVCaptureVideoPreviewLayer` with `.resizeAspect`: the whole sensor frame is visible, letterboxed inside the viewfinder rect. No `.resizeAspectFill`, since that hides sensor area that will be captured.
- Meters come from an `AVCaptureVideoDataOutput` with `alwaysDiscardsLateVideoFrames = true`, on its own queue, sampled at ≤10 Hz. Pixel format: `kCVPixelFormatType_420YpCbCr8BiPlanarFullRange` if it is in `availableVideoPixelFormatTypes`, else `…VideoRange`, chosen at configuration time (an unsupported value throws at `startRunning`). Computed:
  - a 64-bin luminance histogram from the Y plane, using `vImage`;
  - the highlight and shadow clip fractions, using range-aware thresholds: full range Y ≥ 250 / Y ≤ 5; video range Y ≥ 235 / Y ≤ 16.

  The results go out as `AsyncStream<MeterReading>`. The UI labels them `PREVIEW METER`, because they measure the ISP stream, not the RAW.
- A level (horizon) indicator comes from CoreMotion `CMMotionManager.deviceMotion` gravity at 30 Hz, active only while the camera screen is visible.
- After every capture, an instant review shows a 512 px render from our developer, in the dock thumbnail, as soon as it is ready. That review is the honest image.

### 4.5 Video

**Ceiling first (§3):** iOS exposes no raw Bayer video. Every video frame the SDK delivers has been demosaiced and tone-mapped by the ISP, and nothing public removes that. "Same bypassing mechanism" is therefore the layers we *can* own; anything more is a lie and does not go in the README:

1. **Determinism:** the video configuration asserts the same `DeviceDeterminism` as §4.1.3 — GDC off, Center Stage app-controlled and off, video HDR decided (never automatic), colour space pinned, low-light boost off, stabilization `.off` (a stabilized frame is a cropped, warped frame; honest framing wins).
2. **Manual parity:** ISO, shutter, WB and focus are the same `CameraSettings` values driving both paths; changing them changes photo and video identically, including mid-clip.
3. **Our look, our encoder, two files:** frames come from `AVCaptureVideoDataOutput` at the highest-fidelity format the probe confirms (target: a 10-bit YCbCr 4:2:0 format with HLG; the exact OSType and colour-tag flags are Phase 0 probe 9 — this document does not guess them). Each clip is written by `AVAssetWriter` as **two files from the same frames**:
   - **Master** (the original): the ISP frames exactly as delivered, pixels untouched. This is the closest thing video has to a DNG, and Revert returns to it.
   - **Rendition**: the same frames through `PikicamLook` (§4.2.3, mono §4.2.6) with the look active at record time.

   This mirrors the photo model exactly: original + rendition + adjustment payload, edits re-render from the master, and nothing user-specific is ever destroyed.

Rules:
- `AVCaptureMovieFileOutput` is banned: it decides its own pipeline and gives no frame access. §10 greps for it.
- Two `AVAssetWriter`s (or one writer with two inputs — whichever the probe shows holds budget; record which) append during recording, both HEVC 10-bit with the probe-confirmed HLG tags. Audio from `AVCaptureAudioDataOutput` feeds both files. A recording mode is offered only when **both** files hold the frame budget.
- Recording modes: `1080p30` default; `1080p60` and `4K30` are offered only if the Phase 9 device probe proves both files hold the frame rate with the look pass (the budget ladder). The mode lives in Quick Settings; the badge shows it (`VIDEO · 4K30`). On the simulator, fake mode records 1080p30 with synthetic frames. ProRes 422 HQ is probed and offered only on hardware where the probe proves it and the budget holds.
- **Zoom:** photos are pinned to `videoZoomFactor == 1.0` (§4.1.4) because Bayer RAW requires it. Video has no such constraint, so in VIDEO mode pinch drives `videoZoomFactor` (ramped, detents at 1×/2×/3×/4× up to the lens maximum). It is the ISP's crop on the demosaiced stream — a user choice applied to real frames, never a hidden one — and every change is a provenance event. The zoom chip shows the active factor. PHOTO mode keeps crop-only framing.
- **Mid-clip control changes** (ISO, shutter, WB, focus, EV, mono) are allowed and applied live; each change is recorded with a timestamp.
- **Provenance travels in the file:** the writer's metadata input records creation date, `software = "pikicam <version>"`, and a `pikicam.provenance` JSON item (mode, settings at start, timed control-change events, dropped-frame count, iOS version). A test reads it back.
- Torch is legal while recording; the Light toggle stays active in VIDEO.
- Audio defaults: AAC, 48 kHz stereo (probe confirms the writer settings). `MUTE` toggle in Quick Settings; a microphone-permission denial records silently, shown as a state, not an error.
- `alwaysDiscardsLateVideoFrames = false` on the recorder output: a dropped frame is a gap in the record. The meter stream keeps `true`. Dropped frames above 1% of a clip are recorded in provenance and surfaced in Info.
- Frame timing comes from the sample buffer; never re-timestamp. Rotation comes from the `RotationCoordinator` angle at record start, applied to the connection.
- Budget: the look pass holds the mode's frame rate at the mode's resolution on device (device probe; on the simulator a reduced resolution is a recorded fake-scenario). If Core Image cannot hold the budget, the fallback is a precomputed 1-D tone LUT plus a fixed-function Metal pass — still our code, still §4.2.3's curve, a single page of kernels. Phase 8 records which path shipped.
- **Live-look viewfinder in VIDEO is a stretch goal, gated on the probe:** only if preview-look plus both writers hold the budget does the viewfinder render our look live. Otherwise it keeps the ISP preview and shows the `PREVIEW: ISP` caption — honest, like `PREVIEW METER`.
- Storage: after stop, the master is promoted out of the journal directory and the asset is created with the master as one `.movie` resource in the "pikicam" album; the rendition is then committed as the first content edit with `PHAdjustmentData` carrying the look — the same shapes and pass criteria as §4.3.2, probed there. Viewer playback shows the rendition; Revert returns to the master. Recording writes into the journal directory; a crash mid-recording leaves partial files that launch cleanup removes and the UI reports as "recording lost".
- `RecordingState`: `.idle | .starting | .recording(since: ContinuousClock.Instant) | .stopping | .failed(RecordingError)`. The dock shutter becomes the record control (§5.3): red ring, elapsed `MM:SS` in `.monospacedDigit()`, tap to stop. Thermal `.serious` pauses recording with a banner and resumes at `nominal`.
- Errors: `RecordingError`: `.formatUnavailable(reason)`, `.writerFailed(code:)`, `.framesDropped(Int)`, `.cancelled`.

### 4.6 Scan (slit-scan stills)

Reference behaviour: `docs/design-source/slit-scan/` (a slit-scan camera's gallery and capture screens). **Ceiling first, same as §4.5:** a scan assembles its image from `AVCaptureVideoDataOutput` frames — ISP output, never Bayer. The README states it. The bypass layers that apply are the ones we own: the scan configuration asserts the same `DeviceDeterminism` as §4.1.3, the same `CameraSettings` drive the frames (manual parity, changes mid-scan allowed and recorded), and **our look applies to the assembled image** — `PikicamLook`, mono (§4.2.6) and numeric lines (§4.2.7) all work on scans.

**Mechanism.** A scan samples a slit from each delivered frame and appends it to an assembly buffer.
- Axis `H` (default): the slit is a vertical column of width `w`; assembly advances left → right. Axis `V`: a horizontal row, top → bottom.
- `movingSlit` (off by default): the sampled position oscillates across the frame — position = centre + amplitude·sin(2π·elapsed/period) — while assembly still advances along the axis.
- The relation is fixed and shown before capture: `estimated duration = outputLength / (slitWidth × frameRate)`. `slitWidth ∈ {1, 2, 4, 8, 16}` px (default 8). The assembly is complete when the axis is filled; the scan then auto-stops.
- Assembly is a Metal region copy into an `MTLTexture` — one blit per frame, no per-pixel Core Image work in the loop. On stop or completion, `PikicamLook` renders the assembled texture (look, mono, line) and encodes HEIC 10-bit.
- Rotation: the `RotationCoordinator` angle at scan start tags the result (as in §4.5).
- **Drops:** `alwaysDiscardsLateVideoFrames = false` on the scan output. A dropped frame is a sampling gap: the previous slit is duplicated into the gap, the drop is counted, and drops above 1 % of the scan auto-stop it. The partial scan is saved and marked `PARTIAL · DROPS 1.4 %` in provenance and Info. Never silent.

**Buffer guards** (§5.0, expanded sheet): no frame within 3× the nominal frame interval aborts with `ScanError.framesStalled`; a Metal command-buffer failure retries once, then surfaces `ScanError.gpuFailed(code:)` with the assembly preserved; memory pressure beyond `.warning` downscales the assembly target one step with a recorded event.

**Storage — the video model again.** The scan saves **two stills per asset**: the **master** (the neutral assembly, no look — the honest original) and the **rendition** (the look applied at scan end), with `AdjustmentPayload` (look, mono, line) and provenance (axis, slit width, moving slit, frame count, drops, duration). Edits re-render from the master; Revert returns to it; §4.3's pass criteria apply with the master as `.photo`.

**UI.**
- The mode strip reads `PHOTO | VIDEO | SCAN` (Z0). In SCAN the shutter is the scan control: tap to start, tap to stop, auto-stop on completion. The viewfinder shows the assembly filling in real time — the reference app's core behaviour, adopted — with a `[ SCANNING · 64 % ]` caption; completion shows the rendition, then the normal capture flow (thumbnail, library).
- Axis, slit width and moving-slit toggles live in Quick Settings as `EmulsionToggleCard` rows / bracket rows.
- `ScanState`: `.idle | .scanning(progress: Double, since: ContinuousClock.Instant) | .finishing | .failed(ScanError)`.
- Errors: `ScanError`: `.framesStalled`, `.gpuFailed(code:)`, `.tooManyDrops(Int)`, `.cancelled`.

---

## 5. UI/UX specification

Benchmarks: Halide, Kino, Obscura, Leica LUX, Adobe Project Indigo (research 05 §Benchmark).
Brand source: the Maison Margiela camera export at `docs/design-source/` (§5.0).

Principles:
1. The viewfinder is the product: chrome frames it and never covers it.
2. Exposure parameters are always-visible values.
3. No gesture is the only path to anything.
4. Every overlay is legible on a white sky and on a black night.
5. Motion is feedback only.
6. The shutter must be felt.
7. One-handed: everything essential sits in the bottom 55% in portrait.
8. The brand is monochrome; the photograph supplies the colour.

### 5.0 Design source and reconciliation (`docs/design-source/`)

The export is **raw material, not law**. It contains: `maison_margiela_camera_ui_design_system_spec.md` (tokens, component anatomy, motion and haptics), `margiela_camera_ui_component_library_spec.md` (React/Tailwind component implementations), two Tailwind screens (`*/code.html`) with rendered references (`*/screen.png`), `artisanal_vision/DESIGN.md` (a second, conflicting Stitch theme), and `expanded/` — two revised-and-expanded specification sheets (`component-primitives-rev2.png`, `engineering-spec-rev2.png`) carrying per-component prop contracts, a Metal grain-kernel sketch, and camera buffer-starvation guards. Read all of them; the two MM specs take precedence over `artisanal_vision/DESIGN.md` where they conflict, and the expanded sheets refine the MM specs where they agree with them.

**Precedence.** Binding order, highest first: (1) platform law and this document's accessibility gates (WCAG pairs, 44 pt targets, Dynamic Type, Reduce Motion, system shutter sound); (2) this document's functional requirements (§5.2 zones, one-handed reach, legibility over any scene, state coverage); (3) the export. Where the export loses, adapt it and record the deviation — never fake compliance, never ship the violation.

**Reconciliation ledger.** `docs/DECISIONS.md` gains one table, started in Phase 1 and completed by Phase 10: every export token, component and copy string → **adopted / adapted / rejected**, with the reason and, for adaptations, the replacement. Decisions already made by this document (the implementer verifies, then records):

- **False telemetry is rejected.** The care label's `48MP PRO-RAW`, `REC.2020`, and a fixed `F/1.78` describe a different camera. pikicam shows the truth in the same format: real Bayer megapixels, `BAYER RAW` (never "PRO-RAW"), `DISPLAY P3`, and the f-number from the DNG's EXIF. The *format* — brackets, middots, care-label rows — is adopted in full.
- **The subject-classification stamp is adapted.** There is no ML subject classification in v1. The stamp above the reticle displays the active numeric line designation instead: `(14) FUNDAMENTALS · MONO`, `(0) ARTISANAL · RAW`.
- **The two token systems are resolved.** The MM palette (gesso/muslin/calico/ash/carbon/photometric) is the raw layer. `artisanal_vision`'s Material-3 roles are rejected as a parallel system; where its values differ (e.g. `#131313` surface vs `#080808` photometric-deep), the MM spec wins and the ledger records it.
- **Geist is rejected.** The export contradicts itself ("variable width fonts are forbidden" — then assigns Geist to labels). One family ships: Space Mono, bundled from Google Fonts (OFL; commit the licence beside the font files), registered via `UIAppFonts`. If the download is impossible, fall back to SF Mono and record the deviation.
- **Icons are SF Symbols.** The export's Material Symbols and emoji glyphs are replaced; weights adjusted to match the 1.75 px stroke language.
- **px → pt at 1:1, with a legibility floor.** Every export size converts 1:1 to points *except* the sub-9 pt roles: `nano` (7.5 px) and `micro` (9 px) floor at 9 pt and 10 pt respectively — recorded deviations. Every role scales with Dynamic Type (§5.1).
- **Hit targets are 44 pt.** The export's 28 px circled digits and 44 px buttons become ≥ 44 pt targets via padded hit areas; the visuals stay brand-sized.
- **The monochrome discipline is adopted, including for status.** `clip` amber and `fail` red are replaced by geometry and pattern: clipping bars become striped gesso, failure becomes an inverted carbon block with a `[ FAIL ]` stamp. Differentiate Without Color passes by construction. Colour appears only in the photograph.
- **The gesso shutter wash is adopted** (the 40 ms white mirror-slap) with Reduce Motion falling back to the plain one-frame dim.
- **The stitch pulse and the 0 ms mechanics are adopted** with Reduce Motion derivatives: the 1.2 Hz square-wave pulse goes static at 100 %; 0 ms transitions are already RM-safe; the 120 ms drawer becomes 0 ms.
- **The .ahap haptic patterns are adopted** (transients only); the custom shutter-sound waveform is rejected — region law and §5.3 keep the system shutter sound.
- **The export's single-screen arrangement is adapted to the zone contract.** The mock stacks the calibration dial, emulsion cards and archive deck under the viewfinder — impossible on a live viewfinder screen. §5.2's zones remain the functional skeleton; the export's components dress the zones, and the below-viewfinder stack becomes sheets and panels (Manual panel = the Tactile Calibration Dial; Quick Settings = the component system; Library = the Archive Roll Deck).
- **The bottom mode strip is adapted.** Time-lapse and Cinematic are non-goals: the strip shows `PHOTO | VIDEO` only. Looks live in the numeric line matrix (§4.2.7), never in fake modes.
- **Dark-only is adopted as brand.** Library and Viewer render in the export's dark surfaces regardless of system appearance — a recorded deviation from follow-the-system; the camera screen is black by construction either way.
- **The texture overlays are adopted where they are real.** The calico grain overlay (multiply, ~3.5 %) and the typewriter strike-pressure treatment are effects on chrome surfaces only — never over the viewfinder, never under text contrast pairs that §5.7 measures. The expanded sheet's grain kernel sketch is translated into a **Metal CI kernel in the `.ci.metal` file** (same pipeline as `PikicamLook`): the sketch's string-kernel form is rejected — runtime kernel-source strings are deprecated and cannot `sample()` (research 06 C5.3). Parameters (density, opacity) come from the sketch; the hash-based noise math is kept with its source cited. The ribbon drop-shadow filter is rejected if it degrades contrast measurements; test, then decide.
- **The buffer-starvation guards are adopted behaviourally** (expanded sheet): no frame within 3× the nominal frame interval is a typed stall error, Metal command-buffer failures retry once then surface typed, and memory pressure downscales with a recorded event. They bind the video (§4.5) and scan (§4.6) paths. The sheet's decorative claims ("6-BIT RAW") are rejected as noise — raw is 10/12/16-bit or it is not raw.
- **Per-component prop contracts are verified, not re-typed.** The expanded sheets' prop tables (labels, values, states per component) are checked against §5.1's component list in the ledger; where a prop implies behaviour pikicam rejects (fake subject labels, ProRAW strings), the §5.0 verdicts above win.

### 5.1 Design system (`pikicam/DesignSystem/`, exactly these files)

- `Palette.swift`: the raw Margiela layer — exactly the export's seven values, each with its hex, OKLCH and export token name in the source comment: gesso pure `#FFFFFF`, bleached muslin `#F4F3EF`, raw calico `#D6D3CB`, thread ash `#888681`, carbon matrix `#262524`, photometric low `#141312`, photometric deep `#080808`. Nothing else in the app may name a raw colour (§7.5 greps it).
- `Tokens.swift`: the semantic layer, resolved from environment (`colorSchemeContrast`, `accessibilityReduceMotion`, `accessibilityReduceTransparency`, `accessibilityDifferentiateWithoutColor`, `dynamicTypeSize`) through `@Environment`. Every value traces to a `Palette` member or a §5.0 ledger entry.
  - Ink and surfaces:
    - `ink` = gesso; `inkSecondary` = bleached muslin; `inkMuted` = raw calico; `inkDisabled` = thread ash (disabled states only — never body text).
    - Surfaces are **solid plates, not scrims**: `plate` = photometric low; `canvas` = photometric deep; rules and borders = carbon matrix, 1 pt, sharp corners. The old gradient scrims are replaced by the export's console trays; over the viewfinder, text sits on plates or on the `keyline` stamp treatment (photometric-deep backing behind micro type, per the export's classification tag).
    - Selection = inverted fill (gesso on carbon) + 1 pt outline, never colour alone.
    - Status without colour: clipping = striped gesso bars; failure = inverted carbon block + `[ FAIL ]` stamp (§5.0). Increase Contrast: rules 2 pt, `inkSecondary` → `ink`. Reduce Transparency: no change — plates are already opaque.
  - Type: Space Mono only, bundled (§5.0). Roles carry the export's tracking and the §5.0 floors; every role has a `@ScaledMetric(relativeTo:)` base and scales with Dynamic Type — a fixed-pitch brand font does not excuse static type. Numbers are tabular by nature of the mono family; `.monospacedDigit()` is still applied to any non-mono numeral that ever appears.
    - `display` 18 pt / bold / tracking 0.18 em (headline-lg)
    - `title` 13 pt / bold / 0.14 em (headline)
    - `readout` 11 pt / regular / 0.12 em (telemetry — ISO, shutter, Kelvin, EV)
    - `label` 10 pt / regular / 0.14 em (floored from micro; buttons, rows)
    - `micro` 9 pt / regular / 0.16 em (floored from nano; care-label headers, serials — never the only rendering of actionable text)
    - Strict uppercase for telemetry and labels (enforced by a token-level `uppercased()` helper, not per-call-site `.uppercased()` scatter, so localization stays possible).
  - Spacing: the export's U-grid — `1U 4, 2U 8, 4U 16, 6U 24, 8U 32`, plus `hairline 1`. No other vertical padding exists in the app (§7.5).
  - Radius: **Level 0 sharp** for every container, plate and rule; circles only where the brand circles: the shutter discs, the line-matrix rings, the focus pip, the reticle needle. No other radius exists.
  - Motion: mechanical, per the export — state snaps are 0 ms; the drawer curve `cubic-bezier(0, 0, 0.2, 1)` at 120 ms for panel reveals; focus snap 60 ms linear. Reduce Motion: everything 0 ms, the stitch pulse static (§5.0).
  - Haptics: CoreHaptics with committed `.ahap` patterns in `Haptics/` — shutter dual-stage (transient 0.95/0.85, then the low-tension→trip pair), dial detent 0.8/0.6, matrix tick 0.35/1.0, failure 0.6/0.2. Where a pattern cannot be verified on the simulator it is listed in `docs/DEVICE-CHECKLIST.md` and felt on device.
- `Components/` (a folder; no file over 300 lines), each component built from the export's anatomy (§5.0 ledger governs adaptations):
  - `BastingStitchReticle`: four corner stitches — 20 pt leg, 6 pt drop return, 1.75 pt gesso stroke, 28 pt inset — plus the classification stamp above the top bar and the right-axis EV scale. States: searching (square-wave pulse 1.2 Hz), locked (instant snap), Reduce Motion (static).
  - `CareLabelStrip`: the telemetry band — model row, specimen row, bracketed EXIF row — with pikicam's true values (§5.0).
  - `NumericLineMatrix`: the 0–23 selector; active digit circled (1.5 pt gesso ring, ⌀28 pt visual in a ≥ 44 pt target), dormant digits muted and non-interactive (§4.2.7).
  - `TurretFocalSelector`: the lens rail — equivalent-focal chips (`.5 · 1× · 2 · 3` with mm), active chip inverted on carbon.
  - `TactileCalibrationDial`: the milled ruler scrubber used by the Manual panel — 1 pt ticks, 2×18 pt needle cursor, detent haptics.
  - `EmulsionToggleCard`: the binary switch card used by Quick Settings rows (grid, level, mono, mute, CROP…).
  - `GessoShutterActuator`: ⌀72 outer ring (1.5 pt thread-ash) + ⌀60 gesso disc; pressed: 0 ms scale 0.94, fill → muslin, wash overlay (§5.0).
  - `ArchiveRollDeck`: library cells and the dock thumbnail — swatch frame, tack corners, roll id, size, extension, `INSPECT ↗` affordance.
  - `BracketButton` (the former ChromeButton): square carbon border, uppercase label, 44×44 minimum via `.frame(minWidth: 44, minHeight: 44).contentShape(.rect)`.
  - `ErrorBanner`: care-label banner — reason, primary action, Dismiss; failure styling per §5.0.
  - `Plate` (the former Scrim).
- `Contrast.swift`: WCAG 2.2 relative luminance and contrast-ratio functions, used by tests to assert every token pair (§5.7).
- `AccessibilityID.swift`: one `enum AccessibilityID: String` used by both views and UI tests. It is the single identifier contract and replaces `ControlIDRegistry`.
- `Fonts/`: SpaceMono-Regular and SpaceMono-Bold (OFL), the licence file beside them, registered via `UIAppFonts` in `project.yml`'s generated plist. `Type.swift` is the only file that may call `Font.custom` (§7.5).

SF Symbols only for icons (Material Symbols and emoji glyphs are rejected, §5.0). Every icon carries a visible text label wherever space permits, and always an `accessibilityLabel`. The app is dark-only by brand (§5.0); no `.preferredColorScheme` is needed — the palette simply has no light variant.

### 5.2 Layout

Portrait zones, top to bottom (the zone contract is functional and unchanged; §5.0's components dress it):
- **Z0 status bar, 44 pt + photometric plate:**
  - leading: the capture badge in care-label brackets `[ RAW · 26MM · (0) ]` — state, equivalent focal, active line (tap → Quick Settings);
  - trailing: Mode (`PHOTO/VIDEO/SCAN`), Light, Timer and Grid toggles plus `MANUAL`, each a 44×44 `BracketButton`.
- **Z1 viewfinder:** the preview fitted (`.resizeAspect`) into the rect left between Z0 and Z2. The framing mask, grid, reticle, level and histogram (top-leading, on a photometric plate, 96×44) are computed **from this rect only**. Focus is the `BastingStitchReticle`; the classification stamp above it shows the active line designation (§5.0); the grid renders as chalk-dash hairlines with the aspect labelled (`4:3 · ARTISANAL`).
- **Z2 readout rail, 56 pt:** a one-line `CareLabelStrip`: `[26MM] · F/1.78 · 1/250 · ISO 64 · 5200K · EV +0.3 · AF`/`MF 0.42`, each bracketed value a tap target opening the Manual panel focused on that parameter. Values are the real ones (§5.0 — never "PRO-RAW", never "REC.2020").
- **Z3 lens rail, 52 pt:** the `TurretFocalSelector` — physical lenses by computed equivalent focal length with mm sub-labels (`.5 · 1× · 2` → `13 · 26 · 77`), active chip inverted on carbon; plus a `CROP` toggle showing the active crop (`[ CROP 2× · 3 MP ]`) when enabled.
- **Z3.5 line matrix, 44 pt:** the `NumericLineMatrix` (§4.2.7) — one horizontally scrollable row, active digit circled, dormant digits muted with a `DORMANT` accessibility hint. It never covers the viewfinder.
- **Z4 dock, 96 pt, inside `safeAreaInset(edge: .bottom)`:**
  - leading: last-capture thumbnail as an `ArchiveRollDeck` swatch (64×64, tack corners, roll id);
  - centre: the `GessoShutterActuator`, ⌀72 ring / ⌀60 disc (≥ 44 pt target maintained);
  - trailing: aspect cycle `4:3 / 3:2 / 16:9 / 1:1` as bracket chips.

Landscape (designed): the viewfinder is full height. A trailing rail 120 pt wide holds:
- the readout rail as a stacked `CareLabelStrip`, wrapped with `ViewThatFits` (2 + 3, or one column);
- the lens choice as a compact `TurretFocalSelector` menu button;
- the shutter, thumb-centred, with the aspect chips;
- the line matrix as a compact menu of enabled lines.

Z0 collapses into a leading column. The rail needs ≥ 5 × 44 pt of readout height plus the shutter, so the landscape UI test measures it rather than assuming it. The layout is driven by `verticalSizeClass` + `RotationCoordinator`, from one view tree with two arrangements, and no duplicated controls.

At `dynamicTypeSize >= .accessibility1`, use compact chrome: the readout rail becomes `ViewThatFits` of one row of five → rows of 3 + 2 → one column, the lens rail becomes a menu, and the line matrix collapses into a menu of enabled lines. Labels never truncate meaning (`.minimumScaleFactor(0.8)` for numerals only).

### 5.3 Camera screen behaviour

- **Tap viewfinder:** focus + meter at the point. The `BastingStitchReticle` clamps to the point (60 ms linear snap, per the export). Double-tap toggles AE/AF lock: the stitches snap static and an `[ AE/AF LOCK ]` bracket chip appears. The reticle persists through capture and clears on lens switch. The classification stamp tracks the active line (§4.2.7), never a fake subject label.
- **Vertical drag in the viewfinder** in auto mode: EV bias, rendered as the reticle's right-axis tick scale with the needle cursor (§5.1); detent haptic every 1/3 EV. The same control is in the readout rail and the Manual panel.
- **Manual panel** (trailing sheet, also opened by `MANUAL`): ISO, Shutter, WB and Focus, each a `TactileCalibrationDial` + `Stepper` showing device-limit min/max, with the export's milled-ruler styling and detent haptics (0.8/0.6).
  - ISO uses 1/3-stop detents; shutter uses standard 1/3-stop speeds clamped to device limits.
  - WB uses `AUTO` / `LOCK` / Kelvin 2000–10000 in 100 K steps + tint −150…+150.
  - Focus uses `AF` / `MF`, with a lens-position dial (0.00–1.00, the device's `lensPosition`). Never claim metric distance: `lensPosition` is not calibrated to distance.

  An unavailable control shows the reason and never disappears.
- **Pinch** changes only the framing crop, 1×–4× with detents at 1×/2×/3×/4×, when `CROP` is enabled. It is shown as a frame mask, never as device zoom. The Z3 `CROP` toggle shows the active value and resulting megapixels (`CROP 3× · 1.3 MP`). In VIDEO mode pinch instead drives device zoom with a ramp (§4.5), and the chip shows the active factor (`2.0×`).
- **Shutter** states (the `GessoShutterActuator`, §5.1):
  - `ready`
  - `pressed` (0 ms scale 0.94, fill → muslin)
  - `countdown` (stop glyph + `CANCEL`; a tap cancels; the remaining seconds are shown large, centred, on a plate)
  - `capturing` (progress ring; the 40 ms gesso wash fires, Reduce Motion → one-frame dim; disabled)
  - `saving` (thumbnail shows our 512 px review with a `SAVING` caption)
  - `failed` (failure haptic + `ErrorBanner`)
- **Hardware shutter:** `import AVKit` and `.onCameraCaptureEvent(isEnabled:defaultSoundDisabled:action:)` on the camera screen. This API lives in AVKit's SwiftUI overlay, **not** in SwiftUI. Its handler receives an `AVCaptureEvent`; act on `.ended` only, calling the same `shutterPressed()` intent. Pass `defaultSoundDisabled: false`, keeping the system shutter sound required in some regions. Delete the `MPVolumeView` hack entirely.
- **Timer:** off / 3 s / 10 s, anchored to `ContinuousClock`, cancellable.
- **Mode:** `PHOTO / VIDEO / SCAN` (Z0). In VIDEO the shutter is the record control per §4.5, the timer is disabled, and the badge reads `VIDEO · 26mm`. In SCAN the shutter is the scan control per §4.6: the viewfinder shows the live assembly with the `[ SCANNING · n% ]` caption. Switching mode never reorders the other controls.
- **Mono:** Quick Settings `MONO` toggle; when on, a preset row (Neutral, Y, O, R, G, B) with a live readout of the active weights. The histogram stays luminance-based (it already measures Y).
- **Grid:** off / thirds / 4×4. **Level:** on/off (Settings). A 1 pt `ink` hairline with the stamp backing, plus a tilt readout in degrees; it turns solid with a detent haptic when within ±1°. Highlight clipping owns the striped-gesso treatment (§5.0), so the level never uses it.
- **Histogram:** off / luminance; clipping shows as striped-gesso edge bars on the plate. The `PREVIEW METER` caption appears on first enable.
- **Last-capture thumbnail:** driven by the capture that just completed, never by "first item in library". States: empty / rendering / ready / failed (tap → retry).

### 5.4 Quick Settings (bottom sheet from the badge)

Lens info (dimensions, Bayer pattern), mode, video mode (`1080p30 / 1080p60 / 4K30` — only modes the budget ladder proved), mute, scan setup (axis `H/V`, slit width `1/2/4/8/16`, moving slit, with the estimated duration readout), mono (toggle + preset), active line (with the enabled/dormant line list, §4.2.7), aspect, grid, level, histogram, light, timer, and the `CROP` enable. Rows render as `EmulsionToggleCard` components where they are binary and as bracket rows elsewhere; each row is a 44 pt control with label + value.

### 5.5 Permissions

Per-permission rows: Camera (required) and Photos Add/ReadWrite (required to save and browse).
- `.notDetermined` → Request.
- `.denied` → Open Settings.
- `.restricted` → explanation only (no Settings button).
- `.limited` (photos) → a notice that only assets the user has shared with pikicam appear, plus "Manage": `PHPhotoLibrary.shared().presentLimitedLibraryPicker(from:)`, from `import PhotosUI`, called from the hosting view controller.

The gate passes the moment the required states are satisfied, re-evaluated on `scenePhase == .active`. Never strand the user. Copy is plain: what pikicam does, in one sentence each.

### 5.6 Library and Viewer

- **Library:** the `ArchiveRollDeck` grid — 3 columns in portrait, 5 in landscape, 2 pt gutters, newest first, identified by `CaptureID`; each cell is a swatch frame with tack corners, roll id and size. Leading `Done`. Multi-select for share/delete. Empty state: an empty cotton patch — "NO ROLLS YET" + Open Camera (a designed state, not a blank). VoiceOver label per cell: `"Photo 3 of 41, 30 September 2026, 14:22, ISO 64, 1/250 s"`. Video cells carry a duration badge (`0:42`) and the VoiceOver label says "Video".
- **Viewer:**
  - **Image and navigation:** paging (`TabView(.page)` keyed by `CaptureID`); zoom/pan with double-tap fit ⇄ 2.5×; chrome on photometric plates (not floating glyphs). Hiding chrome keeps an `.accessibilityAction(.escape)` and a swipe-down dismiss.
  - **Video playback:** `AVPlayer` on the rendition — play/pause, scrubber, elapsed/total in `.monospacedDigit()`, mute. Leaving the page or hiding chrome pauses playback.
  - **Actions:** `Info` (a care-label sheet: the provenance of §4.1.5 laid out as a garment label — model row, specimen row, bracketed EXIF — plus the `RecipeApplication` summary, e.g. "APPLE PROCESSING: OFF (15/15 NEUTRAL) · DECODER 8.DNG"; for video: mode, fps, dropped frames, timed control-change events); `Develop` (the panel of `LookParameters` dials with live preview at display scale, plus the mono toggle and preset row and the numeric line matrix, §4.2.6–4.2.7; for video, saving re-renders from the master with a progress sheet and `Cancel`; `Reset`, `Save`, `Revert to original`); `Share` (original DNG / developed HEIC; master .mov / rendition .mov); `Delete` (one confirmation style app-wide).
  - **States:** develop failure shows `ErrorBanner` with Retry and Back. On delete, dismiss first, then delete; a failure is reported in the library.

### 5.7 Accessibility (acceptance criteria)

Every control has:
- a label stating the action, a value stating the state, and a hint stating the consequence;
- an adjustable action wherever it is continuous;
- a 44 pt minimum target (88 pt shutter).

Reading order: status → meters → readouts → lenses → dock (`accessibilitySortPriority`). Rotor custom actions on Camera are "Capture", "Lock focus and exposure" and "Open library".

All text scales; AX5 never truncates meaning — including Space Mono: the §5.1 roles scale with Dynamic Type, and the AX5 layout test proves it. Differentiate Without Color passes by construction (the §5.0 monochrome discipline — status is geometry, never hue). Every text pair meets ≥ 4.5:1 and every non-text pair ≥ 3:1, measured with `Contrast.swift` (`ratio(_:_:)`, `over(_:alpha:background:)`): `ink`, `inkSecondary` and `inkMuted` on `plate` and on `canvas`; every over-viewfinder element either sits on a plate or carries the stamp backing — the test composites that backing over pure white and pure black and asserts the pair. The measured ratios are recorded beside the tokens.

### 5.8 States and errors

The app renders each of these as designed UI in the brand's care-label language (§5.0), with plain truthful copy — never a blank, never a raw caption, and never brand prose that hides the fact:
- every `PermissionState` of the gate (§5.5), and every `SessionState` (§6.2): `idle`, `configuring`, `running`, `interrupted(reason)` (another app / phone call / multitasking / thermal), `unavailable(reason)`, `failed(error)`;
- `thermalState ≥ .serious` → the care-label banner: `[ THERMAL REGISTRATION ACTIVE ]` with the plain line "Camera paused: device is hot" (from `AVCaptureSession` interruption or `ProcessInfo.thermalState`);
- storage full (`PHPhotosError` / journal write failure);
- limited library;
- develop failure.

Each error state has a primary action (Retry / Open Settings / Manage) and Dismiss.

### 5.9 Settings

A sheet from Quick Settings with Grid style, Level, Histogram default, Haptics (respects the system setting; an in-app off switch), `CROP` enable, "Show capture badge", and About (version, "What pikicam does to your photo" — a short honest explainer of §3's platform ceilings). Persisted with `@AppStorage` keys centralised in one `SettingsKeys` enum.

---

## 6. Implementation design (sinthink: X → Graph → Effect<A, E, R>, in Swift 6)

This section follows the sinthink method. Effect-TS concepts map to Swift as follows. Hold to the mapping exactly.

| sinthink | Swift 6 in this codebase |
|---|---|
| `Effect<A, E, R>` | `func node(_ input: In) async throws(E) -> A` on a type whose **stored, protocol-typed dependencies are R** |
| `Stream<A, E, R>` | `AsyncStream<A>` / `AsyncThrowingStream<A, E>` |
| Schema at the boundary | `init(validating raw: Raw) throws(BoundaryError)` on a trusted value type; raw framework types never leave the boundary file |
| Layer | a `Dependencies` struct with `static func live() -> Self` and `static func fake(...) -> Self`, built once in `PikicamApp` |
| `Effect.gen` body = A | the body of a node: straight-line `try await` calls, **no `do/catch` inside** |
| `.pipe()` = E | one wrapping function per layer boundary that maps every inner error to the layer's error type (`mapError`), plus behaviour wrappers (`retrying`, `withTimeout`, `traced`); see §6.8 |
| `die` | `preconditionFailure("<invariant> — <source>")` |
| `Scope` | `defer`, `withDeviceLock { }` (synchronous closure), actor lifetime, `withTaskCancellationHandler`, single-resume continuation guard |

### 6.1 Project and build (the compile-time half of R)

`project.yml`:
- `SWIFT_VERSION: "6.0"`, `SWIFT_STRICT_CONCURRENCY: complete`, `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES`, `GCC_TREAT_WARNINGS_AS_ERRORS: YES`, `ENABLE_USER_SCRIPT_SANDBOXING: YES`. Deployment target iOS 26.5, iPhone only, portrait + landscape.
- Metal CI kernels: `MTL_COMPILER_FLAGS: -fcikernel` and `MTLLINKER_FLAGS: -cikernel` on the app target. Research 07 confirmed the compiler accepts the flag; Phase 0 item 4 confirms a real build.
- The scheme `pikicam` tests `pikicamTests` and `pikicamUITests`. Add scheme `pikicam-device` with test target `pikicamDeviceTests` (§7.9). Add target `pikicamProbes` (a unit-test-style target, excluded from the main scheme's test action) with scheme `probes`: the Phase 0 probe files are committed there and stay runnable (DoD 10). Probes never link the app's sources; they probe the platform.
- `GENERATE_INFOPLIST_FILE: YES` is the only plist source. No `INFOPLIST_FILE` anywhere, and `pikicam/Resources/Info.plist` is deleted. Keep the three usage strings, rewritten to plain truthful copy, plus `UIRequiredDeviceCapabilities: [still-camera]` via the `INFOPLIST_KEY_` equivalent.
- All targets use `TARGETED_DEVICE_FAMILY: "1"`. Enable code coverage in the scheme. Leave `DEVELOPMENT_TEAM` unset; signing for device runs is the owner's step in `docs/DEVICE-CHECKLIST.md`.
- `pikicam/Fakes/` compiles only in Debug (`#if DEBUG` around every file's contents). Release builds contain no fake code. The UI tests run the Debug configuration.
- `.gitignore` already contains `pikicamTests/Fixtures/*.DNG` and `build/`; leave it.

`scripts/verify.sh` (the one script):
1. `xcodegen generate`
2. when `CI=1`, `git diff --exit-code -- pikicam.xcodeproj` (project **and** `xcshareddata/xcschemes`). Locally the regenerated project is simply part of the commit.
3. resolve a simulator (prefer `iPhone 17 Pro`, iOS 26.5; else the newest available iPhone)
4. `xcodebuild … -scheme pikicam -derivedDataPath build/dd build-for-testing`
5. `test-without-building`
6. parse the `.xcresult` to fail if tests executed == 0 or skipped > allowed list
7. `swiftlint lint --strict` (zero findings; the committed `.swiftlint.yml` is the strict one created in Phase 1)
8. `periphery scan` (zero unused symbols; config acknowledges the probe and test targets)
9. `python3 scripts/reference-diff.py --check` (tolerances from `docs/DECISIONS.md`; a missing `rawpy` is a loud skip, listed like a fixture skip)

`.github/workflows/ci.yml` runs `scripts/verify.sh` on a macOS runner with Xcode 26.x selected via `xcodes`/`sudo xcode-select`, plus a second job that runs the unit suite under Thread Sanitizer (`xcodebuild test -enableThreadSanitizer YES`). If no hosted runner provides Xcode 26, keep the workflows and record the limitation in `docs/DECISIONS.md`.

### 6.2 §1 Shapes — the nouns (`pikicam/Domain/`, imports Foundation + CoreGraphics only)

**IDs** (distinct types, never bare strings):
- `struct CaptureID: Hashable, Codable, Sendable { let raw: UUID }`
- `struct AssetID: Hashable, Codable, Sendable { let localIdentifier: String }`
- `struct ClipID: Hashable, Codable, Sendable { let raw: UUID }`
- `enum LensKind: String, Codable, Sendable { case ultraWide, wide, telephoto }`
- `struct Lens: Hashable, Sendable { let kind: LensKind; let uniqueID: String; let equivalentFocalLength: Int }`
- `struct BayerFormat: Hashable, Sendable { let osType: OSType }`. Constructed only by the capture boundary after `isBayerRAWPixelFormat`.

**Records:**
- `ExposureMode`: `.auto(bias: EV)`, `.manual(iso: ISO, duration: ShutterSpeed)`, with `EV`, `ISO` and `ShutterSpeed` as validated value types clamped by `ExposureLimits`.
- `WhiteBalanceMode`: `.auto`, `.lockedCurrent`, `.locked(Kelvin, Tint)`.
- `FocusMode`: `.continuousAuto`, `.auto(point: NormalizedPoint)`, `.locked(lensPosition: LensPosition)`.
- `CameraSettings`: lens + exposure + white balance + focus + light + aspect + crop + timer.
- `DeviceCapabilities`: lenses, `ExposureLimits` per lens, `WhiteBalanceLimits`, supports-flash, supports-focus-lock, `rawDimensions`, `bayerFormat`. Cached per configuration (time-bounded: invalid after reconfiguration).
- `DeviceDeterminism`: GDC / Center Stage / video HDR / low-light / color space, as `.off`, `.notSupported` or `.on`.
- `CaptureRequest`: `CaptureID`, lens, `BayerFormat`, dimensions, `CameraSettings`, metadata, created-at.
- `RawCapture`: `CaptureID`, `dng: Data`, `Provenance`.
- `Provenance`: everything in §4.1.5.
- `FrameGeometry`: aspect + crop zoom → normalised rect in sensor space. The same value is used by the overlay and by develop.
- `NeutralRecipe` (version), `LookParameters`, `DecoderVersion`, `RecipeApplication`.
- `MonoState` and `MonoPreset`/`MonoWeights` (§4.2.6), validated at the boundary.
- `MediaKind`: `.photo | .video(ClipInfo)` on `LibraryItem`. `VideoMode`: `1080p30 | 1080p60 | 4K30 | proRes422HQ`, each valid only while the budget ladder proves it (§4.5).
- `RecordingIntent` (settings, look, mono, audio enable, `VideoMode`) and `VideoClip`: `ClipID`, master URL, rendition URL, `VideoMode`, duration, frame count, dropped-frame count, timed control-change events, `LookParameters`.
- `ScanConfig`: axis (`H | V`), `slitWidth: 1|2|4|8|16`, `movingSlit: Bool`, settings, look, mono. `ScanResult`: master still `Data`, rendition `Data`, provenance (axis, slit width, moving slit, frame count, drops, duration), `LookParameters`. `ScanState`: `.idle | .scanning(progress: Double, since: ContinuousClock.Instant) | .finishing | .failed(ScanError)` (§4.6).
- `ScanError`: `.framesStalled`, `.gpuFailed(code:)`, `.tooManyDrops(Int)`, `.cancelled`.
- `Rendition`: HEIC `Data` + pixel size + recipe hash.
- `LibraryItem`: `CaptureID`, `AssetID`, `MediaKind` (photo or video, §6.2), provenance, look, `developState`.
- `JournalEntry`: `CaptureID`, phase, `Provenance`, `FrameGeometry`, `LookParameters`.
- Value types for dials: `ISO`, `ShutterSpeed`, `EV`, `Kelvin`, `Tint`, `LensPosition`, `NormalizedPoint`, `Aspect`, each with `init(clamping:to:)`.
- Stream elements: `DeviceReadings`, `MeterReading`, `LevelReading`.
- `DNGFacts`: trusted DNG metadata (§6.7).
- `PreviewTarget`: `.thumbnail(maxPixel: Int) | .display(pixelSize: CGSize)`.
- `DisplayImage`: `struct DisplayImage: Sendable { let cgImage: CGImage; let pixelSize: CGSize }`. `CGImage` is `Sendable` on this SDK, so no `@unchecked` is needed.
- `RetryPolicy<E: Error>`: `maxAttempts`, `backoff: [Duration]`, `isTransient: @Sendable (E) -> Bool`.
- Error `code:` payloads are `Int` domain codes. The original `NSError` never leaves its boundary file.

**Variants (state machines; no bags of Bools):**
- `SessionState`: `.idle | .configuring | .running(Lens) | .interrupted(InterruptionReason) | .unavailable(UnavailableReason) | .failed(CaptureError)`. `UnavailableReason`: `.noBayerLens | .noCamera | .thermal`. Permission is not a session state: the gate (§5.5) renders `PermissionState` before the camera exists.
- `ShutterState`: `.ready | .pressed | .countdown(remaining: Int) | .capturing(CaptureID) | .saving(CaptureID) | .failed(CameraError)`
- `RecordingState`: `.idle | .starting | .recording(since: ContinuousClock.Instant) | .stopping | .failed(RecordingError)` (§4.5)
- `PermissionState`: per permission `.notDetermined | .granted | .limited | .denied | .restricted`
- `DevelopState`: `.developed | .pending | .failed(DevelopError)`
- `JournalPhase`: `.captured | .developed | .saved`
- `AdjustmentPayload`: `{ look, geometry, recipeVersion, decoderVersion, provenance }`, versioned Codable, the `data` of our `PHAdjustmentData`.

**Errors** (typed enums carrying context, `Error & Sendable`; no `String` errors, no `localizedDescription` plumbing; user copy lives in one `UserMessage` mapping per feature):
- `CaptureError`:
  - `.noBayerLens`, `.configurationRejected(DeviceDeterminism)`, `.sessionStartFailed(code:)`, `.interrupted(InterruptionReason)`, `.mediaServicesReset`
  - `.notBayer(pixelFormat:)`, `.unexpectedResolvedSettings(ResolvedSettingsViolation)`, `.noFileData`, `.notADNG`
  - `.timedOut`, `.deviceLockFailed`
- `DevelopError`: `.filterUnavailable`, `.undecodable`, `.decoderUnavailable`, `.recipeNotApplied([String])`, `.renderFailed`, `.encodeFailed`, `.cancelled`
- `LibraryError`: `.notAuthorized(PermissionState)`, `.saveFailed(code:)`, `.storageFull`, `.assetMissing(AssetID)`, `.resourceMissing`, `.editFailed`, `.foreignAdjustment(formatIdentifier:)`, `.albumUnavailable`
- `JournalError`: `.writeFailed`, `.corrupt(CaptureID)`
- `CameraError` (feature-level, what the UI sees): `.capture(CaptureError)`, `.journal(JournalError)`, `.library(LibraryError)`. A permission denial is not an error: it is `PermissionState`, published by `PermissionClient` and rendered by the gate.
- `ViewerError`: `.develop(DevelopError)`, `.library(LibraryError)`
- `RecordingError`: `.formatUnavailable(reason)`, `.writerFailed(code:)`, `.framesDropped(Int)`, `.cancelled`

### 6.3 §2 A — the happy-path call graph

```
CAPTURE (one-shot, per shutter press)
ShutterIntent
  → CameraModel.makeRequest(settings, capabilities)          : CaptureRequest
  → CaptureClient.capture(request)                            : RawCapture        [boundary: AVCapturePhoto → RawCapture]
  → Journal.persist(raw, geometry, look)                      : JournalEntry
  → Developer.export(raw.dng, look, geometry)                 : Rendition?         [divergent: nil on develop failure]
  → Library.save(raw, rendition, payload)                     : LibraryItem
  → Journal.complete(captureID)                               : Void
  → CameraModel.didCapture(item) ; ThumbnailStore.thumbnail(item) → dock

VIEW (one-shot, per viewer page)
CaptureID → Library.dng(for:) : Data → Developer.image(dng, item.look, item.geometry, .display(pixelSize)) : DisplayImage

EDIT (one-shot, per Save)
LookParameters → Library.dng(for:) → Developer.export(dng, look, geometry) : Rendition → Library.commitEdit(id, payload, rendition) : LibraryItem

RECOVERY (one-shot per pending entry, at launch, before the shutter is enabled)
Journal.pending() : [JournalEntry] → Journal.dng(entry) → Developer.export → Library.save → Journal.complete

RECORD (stateful, one clip, two files from the same frames)
RecordIntent.start(settings, look, mono, mode, audio)
  → RecordingClient.start(intent)                              [boundary: AVRecordingClient]
  → frames : AsyncStream<Frame> → VideoFrameBoundary
      → Writer.append (master: frames as delivered)
      → VideoLook.apply(frame, look, mono) → Writer.append (rendition)
  → RecordIntent.stop → RecordingClient.stop() : VideoClip
  → Library.saveVideo(clip, payload) → RecordingState.idle → thumbnail from first frame

SCAN (stateful, one still assembled from many frames)
ScanIntent.start(config : ScanConfig)
  → ScanClient.start(config)                                   [boundary: AVScanClient]
  → frames : AsyncStream<Frame> → VideoFrameBoundary → ScanAssembler.append (Metal blit per frame, drops policy §4.6)
  → ScanIntent.stop (or completion) → ScanClient.stop() : ScanResult
  → Developer.renderScan(result, look, mono) : Rendition       [look applied to the assembly, once, at the end]
  → Library.saveScan(result, rendition, payload) → ScanState.idle → thumbnail
```

Each node is one function, and the body of each top-level flow (in `CaptureFlow.run`, `ViewerModel.load`, `EditFlow.commit`, `RecoveryFlow.run`) is literally the arrows above as consecutive `try await` lines.

### 6.4 §3 Cardinality

| Node | Kind | Swift |
|---|---|---|
| `capture`, `persist`, `export`, `image`, `save`, `commitEdit`, `complete` | one value | `async throws(E) -> A` |
| `CaptureClient.sessionStates` | many | `AsyncStream<SessionState>` |
| `CaptureClient.readings` | many, 15 Hz | `AsyncStream<DeviceReadings>` |
| `CaptureClient.meters` | many, ≤10 Hz | `AsyncStream<MeterReading>` |
| `MotionClient.level` | many, 30 Hz | `AsyncStream<LevelReading>` |
| `Library.changes` | many | `AsyncStream<[LibraryItem]>` (from `PHPhotoLibraryChangeObserver`, debounced 250 ms, own saves applied directly) |
| `PermissionClient.states` | many (re-evaluated on scene active) | `AsyncStream<Permissions>` |
| `RecordingClient.states` | many | `AsyncStream<RecordingState>` |
| `ScanClient.states` | many | `AsyncStream<ScanState>` |
| `capabilities` | time-bounded | cached until the next reconfiguration; concurrent reads dedupe on the actor |
| thumbnails | time-bounded | disk + `NSCache`, key `CaptureID + lookHash`; concurrent requests for one key share one `Task` |
| `decoderVersion` choice | time-bounded | per process |

Streams are consumed by `@MainActor @Observable` models in `.task { for await … }` tied to view lifetime. Cancelling the view task ends the subscription.

### 6.5 §4 E — break points on the graph

| Node | Failure | Strategy |
|---|---|---|
| `capture` | `.timedOut` (10 s), `.interrupted` | **escape**: surface `CameraError`, restore device state, shutter → `.ready` |
| `capture` | `.notBayer`, `.unexpectedResolvedSettings`, `.notADNG` | **escape** + log fault: it is a platform contract violation, not retryable |
| `capture` | zoom ≠ 1, crop factor ≠ 1, ProRAW enabled, processed format set | **die**: our invariant |
| `persist` | `.writeFailed` | **escape**: abort the flow with `CameraError.journal(.writeFailed)`, shown as "Not saved: storage full". Without the journal there is no crash safety, so nothing proceeds unjournaled; there is only one divergent strategy (§6.11) |
| `export` during capture | any `DevelopError` | **divergent strategy** (§6.11): escape to DNG-only save, mark `.pending` |
| `save` | `PHPhotosError` transient (`.libraryVolumeOffline`, network) | **retry** ×3, backoff 0.5 s / 1 s / 2 s; then escape (journal keeps it for recovery) |
| `save` | `.notAuthorized`, `.storageFull` | **escape**: journal keeps the capture; UI shows the actionable banner |
| `scan` | `.framesStalled`, `.gpuFailed` (after retry), `.tooManyDrops` | **escape**: auto-stop; a partial assembly is saved and marked `PARTIAL` (§4.6); typed banner |
| `image(.display)` | `.cancelled` | swallowed by the caller (expected) |
| `image(.display)` | other | **escape**: viewer `ErrorBanner` with Retry |
| `image(.thumbnail)` | any | **escape**: placeholder with retry glyph |
| session start | `.mediaServicesReset` | **retry** once (rebuild session), then escape |
| album lookup | `.albumUnavailable` | **retry** once by recreating the album, then escape (save still succeeds without album membership; listing falls back to the journal's recent IDs) |
| adjustment decode | `.foreignAdjustment` | **escape**: show "Edited outside pikicam", develop from neutral |
| continuation resumed twice / never | — | **die** in debug via the single-resume guard's `assertionFailure`; in release, the second resume is ignored and logged |

**Error scoping by layer.**
- `AVFoundation NSError` → `CaptureError` (inside `AVCaptureClient`)
- CI nil / exceptions → `DevelopError` (inside `CoreImageDeveloper`)
- `PHPhotosError` → `LibraryError` (inside `PhotoKitLibrary`)
- sample-buffer and Metal writer errors → `RecordingError` / `ScanError` (inside `AVRecordingClient` / `AVScanClient`)
- `CaptureError` / `LibraryError` / `DevelopError` → `CameraError` or `ViewerError` (inside the flow)
- feature error → `UserMessage` (inside the view model)

No view ever sees an `NSError`, and no flow ever sees an `AVError`.

### 6.6 §5 R — what each node needs

```swift
protocol CaptureClient: Sendable {            // AVCaptureClient (live), FakeCaptureClient (tests/UI tests)
  func capabilities() async throws(CaptureError) -> DeviceCapabilities
  func start(lens: Lens) async throws(CaptureError)
  func stop() async
  func apply(_ settings: CameraSettings) async throws(CaptureError)
  func capture(_ request: CaptureRequest) async throws(CaptureError) -> RawCapture
  var sessionStates: AsyncStream<SessionState> { get }
  var readings: AsyncStream<DeviceReadings> { get }
  var meters: AsyncStream<MeterReading> { get }
  var preview: PreviewSource { get }          // .live(SessionHandle) | .synthetic(aspect: Aspect)
}
// PreviewSource lives in Capture/. `.live` wraps the AVCaptureSession in an opaque, Sendable SessionHandle
// that only Features/Camera/PreviewLayerView.swift can unwrap; `.synthetic` makes Viewfinder draw a
// LinearGradient with the sensor aspect, so in fake mode the viewfinder rect and overlays are real pixels.
protocol Developer: Sendable {                // CoreImageDeveloper (live), FakeDeveloper (UI tests: solid gradient)
  func image(_ dng: Data, look: LookParameters, geometry: FrameGeometry, target: PreviewTarget) async throws(DevelopError) -> DisplayImage
  func export(_ dng: Data, look: LookParameters, geometry: FrameGeometry) async throws(DevelopError) -> Rendition
  func inspect(_ dng: Data) async throws(DevelopError) -> (DNGFacts, RecipeApplication)
}

protocol Library: Sendable {                  // PhotoKitLibrary (live), InMemoryLibrary (tests)
  func save(_ raw: RawCapture, rendition: Rendition?, payload: AdjustmentPayload) async throws(LibraryError) -> LibraryItem
  func saveVideo(_ clip: VideoClip, payload: AdjustmentPayload) async throws(LibraryError) -> LibraryItem
  func saveScan(_ result: ScanResult, payload: AdjustmentPayload) async throws(LibraryError) -> LibraryItem
  func items() async throws(LibraryError) -> [LibraryItem]
  func dng(for id: CaptureID) async throws(LibraryError) -> Data
  func commitEdit(_ id: CaptureID, payload: AdjustmentPayload, rendition: Rendition) async throws(LibraryError) -> LibraryItem
  func revert(_ id: CaptureID) async throws(LibraryError) -> LibraryItem
  func delete(_ ids: [CaptureID]) async throws(LibraryError)
  var changes: AsyncStream<[LibraryItem]> { get }
}
protocol Journal: Sendable { … }              // FileJournal (live, injectable root URL), FileJournal(tempDir) in tests
protocol RecordingClient: Sendable {          // AVRecordingClient (live), FakeRecordingClient (tests/UI tests)
  func start(_ intent: RecordingIntent) async throws(RecordingError)
  func stop() async throws(RecordingError) -> VideoClip
  var states: AsyncStream<RecordingState> { get }
}
protocol ScanClient: Sendable {               // AVScanClient (live), FakeScanClient (tests/UI tests)
  func start(_ config: ScanConfig) async throws(ScanError)
  func stop() async throws(ScanError) -> ScanResult
  var states: AsyncStream<ScanState> { get }
}
protocol PermissionClient: Sendable { … }     // SystemPermissions, FakePermissions
protocol MotionClient: Sendable { … }         // CoreMotionClient, FakeMotion
protocol ThumbnailStore: Sendable { … }       // DiskThumbnailStore(root:), in tests a temp root
struct Dependencies: Sendable {
  let capture: any CaptureClient; let developer: any Developer; let library: any Library
  let journal: any Journal; let recording: any RecordingClient; let scan: any ScanClient
  let permissions: any PermissionClient; let motion: any MotionClient
  let thumbnails: any ThumbnailStore; let clock: any Clock<Duration>
  static func live() -> Self
  static func fake(scenario: FakeScenario) -> Self   // also used by UI tests via launch argument
}
```

Rules:
- Feature models receive exactly the dependencies they use, through `init`. No singletons. No `.shared`/`.default()` outside `live()` and the live clients.
- `PHPhotoLibrary.shared()`, `PHImageManager`, `AVCaptureDevice.default`, `UIApplication.shared` and `CMMotionManager()` appear only in the live client files.
- Everything that sleeps or measures time takes the injected `Clock`.

### 6.7 §6 Boundary — untrusted → trusted (one file per boundary)

| Boundary | File | Raw input | Trusted output |
|---|---|---|---|
| AVFoundation photo | `Capture/PhotoBoundary.swift` | `AVCapturePhoto`, `AVCaptureResolvedPhotoSettings`, requested `BayerFormat` | `RawCapture` (all §4.1.5 checks) |
| DNG bytes | `Develop/DNGInspector.swift` | `Data` | `DNGFacts` (TIFF header, `PhotometricInterpretation`, CFA present, `UniqueCameraModel`, orientation, `BaselineExposure`, `AsShotNeutral`), via `CGImageSourceCopyPropertiesAtIndex` + `CIRAWFilter.properties`, plus a minimal IFD walker for `PhotometricInterpretation`/CFA tags that ImageIO hides |
| Device limits | `Capture/CapabilitiesProbe.swift` | `AVCaptureDevice`, `AVCaptureDevice.Format`, `AVCapturePhotoOutput` | `DeviceCapabilities` |
| User input | `Domain/Exposure.swift` etc. | `Double` from dials | clamped `ISO` / `ShutterSpeed` / `Kelvin` / `EV` via `init(clamping:to:)` |
| Photos | `Library/AssetBoundary.swift` | `PHAsset`, `[PHAssetResource]`, `PHAdjustmentData` | `LibraryItem` / `LookParameters` (format id + version checked) |
| Video frames | `Capture/VideoFrameBoundary.swift` | `CMSampleBuffer`, `CVPixelBuffer` | trusted `Frame` (format, timing, rotation); a mismatch is `RecordingError.formatUnavailable` |
| Persistence | `Library/FileJournal.swift`, `Library/AdjustmentCodec.swift` | journal JSON on disk; `PHAdjustmentData` | versioned `Codable` decode; an unknown journal version is `JournalError.corrupt`; an unknown adjustment format/version is `.foreignAdjustment` |

Inside the boundary, trust the types: no re-validation, no optional chaining on trusted values.

### 6.8 §7 Behavior — wrappers that do not change the graph (`pikicam/Support/`)

- `func mapError<A, F: Error>(_ map: (any Error) -> F, _ body: () async throws -> A) async throws(F) -> A`. This is the **only** place a heterogeneous body (nodes throwing different error types) becomes one typed error. Its body closure is deliberately untyped: Swift cannot give a closure that throws several typed errors a single typed-throws signature.
- `func retrying<A, E: Error>(_ policy: RetryPolicy<E>, clock: any Clock<Duration>, _ op: () async throws(E) -> A) async throws(E) -> A`. The policy carries the transient predicate, so `E` is inferred from the operation, e.g. `static var photosSave: RetryPolicy<LibraryError>`.
- `func withTimeout<A, E>(_ d: Duration, clock:, onTimeout: E, _ op: @Sendable () async throws(E) -> A) async throws(E) -> A`
- `func traced<A, E>(_ name: StaticString, _ op: () async throws(E) -> A) async throws(E) -> A`, which emits an `OSSignposter` interval and a `Logger` line with duration and outcome.
- `withCheckedContinuationOnce`: a continuation box that resumes exactly once (atomic flag via `Synchronization.Mutex`); a second resume is logged and asserted in debug. It replaces every ad-hoc continuation, including the photo delegate.

The flows read like the graph; wrapping is applied at the call site, e.g. `try await traced("save") { try await retrying(.photosSave, clock: clock) { try await library.save(…) } }`. `E` is inferred from the innermost typed operation (`LibraryError`). Nothing inside `library.save` knows about retry. Phase 1 lands these wrappers with a test file that compiles the §6.11 exemplar shape verbatim, so a type-checker surprise surfaces in Phase 1, not Phase 4.

### 6.9 §8 Scope — acquire/release tied to lifecycle

- `AVCaptureClient` is an `actor` that runs on AVFoundation's session queue: `private let queue = DispatchSerialQueue(label: "piki.capture")` and `nonisolated var unownedExecutor: UnownedSerialExecutor { queue.asUnownedSerialExecutor() }`. `DispatchSerialQueue` is itself a `SerialExecutor`, so **do not** hand-roll a `SerialExecutor` class; research 07 F3 measured a type-checker crash on Swift 6.3.3 for that form.
  - Phase 0 compiles this exact form under `-swift-version 6 -warnings-as-errors`.
  - If it also fails, fall back to a plain `actor`, with every blocking AVFoundation call (`startRunning`, `stopRunning`, `commitConfiguration`) issued as `await withCheckedContinuation { c in queue.async { session.startRunning(); c.resume() } }`. The closures are synchronous, with no `await` inside GCD. Record which form shipped.
  - `AVCaptureSession` lives inside the actor. The preview receives it only through `PreviewSource.live(SessionHandle)`, a `Sendable` wrapper whose one-line proof comment cites AVFoundation's documented permission to set `AVCaptureVideoPreviewLayer.session` from the main thread. This is the single allowed `@unchecked Sendable`; §10's grep allows it by file name.
- `withDeviceLock(_ device:, _ body: (AVCaptureDevice) throws -> Void) throws(CaptureError)` performs lock, body, and unlock via `defer`. `body` is synchronous by type, so an `await` cannot occur inside the lock.
- Photo capture: the `PhotoCaptureDelegate` object is retained by the actor in a `[Int64: PhotoCaptureDelegate]` keyed by `resolvedSettings.uniqueID` until `didFinishCaptureFor`, then removed. There is no associated-object trick. On timeout, the delegate is removed and device state is restored; the late callback finds no entry and is logged.
- Session: `start` on scene active, `stop` on background; interruption observers live inside the actor and are removed in `stop`.
- `CIContext`s live as long as the `CoreImageDeveloper` (app lifetime). Render memory is scoped with `autoreleasepool` per render.
- Journal: a directory per capture, created by `persist` and removed by `complete`; recovery runs before the shutter enables.
- Background work: `beginBackgroundTask`/`endBackgroundTask` wrap develop + save in `CaptureFlow`, ended in `defer`.
- Motion updates start in the camera view's `.task` and stop when the task is cancelled (`withTaskCancellationHandler`).
- The recorder owns its writer session: `stop` finishes and closes the file before the state returns to `.idle`, and scene-phase background stops recording (a background app cannot keep a writer alive). Partial files are removed by launch cleanup (§4.5).
- Viewer renders are `Task`s keyed by `CaptureID`, cancelled on page change.

### 6.10 §9 Test — swap R, same graph

The graphs in §6.3 run unchanged against `Dependencies.fake(...)`. If a test needs to mock something not in `Dependencies`, the design has a hidden dependency: fix the design, not the test.

### 6.11 §10 Code — body = A, wrappers = E

Rules:
1. Each flow function body is the call graph and contains no `do/catch`. One `mapError` per flow turns the heterogeneous body into the flow's typed error:

```swift
func run(_ request: CaptureRequest) async throws(CameraError) -> LibraryItem {
  try await mapError(CameraError.init(mapping:)) {                       // E: one enumeration for the layer
    let raw = try await deps.capture.capture(request)                     // throws(CaptureError)
    let entry = try await deps.journal.persist(raw, geometry: request.geometry, look: .standard)  // throws(JournalError)
    let rendition = await developForCapture(raw, entry)                  // divergent strategy, rule 2
    let payload = AdjustmentPayload(entry, rendition: rendition)
    let item = try await traced("save") {                                 // E inferred: LibraryError
      try await retrying(.photosSave, clock: deps.clock) {
        try await deps.library.save(raw, rendition: rendition, payload: payload)
      }
    }
    try await deps.journal.complete(entry.id)
    return item
  }
}
```

   `CameraError.init(mapping:)` is the complete enumeration. It `switch`es on exactly the error types the body's nodes declare (`CaptureError`, `JournalError`, `LibraryError`); any other type is a programmer bug and hits `preconditionFailure`. A unit test feeds one value of each type through it. Every layer defines its own `init(mapping:)` the same way (`ViewerError`, etc.), so consumers never see an error from two layers down. If the toolchain rejects the exemplar as written, map per node instead (`try await mapError(CameraError.init(mapping:)) { try await deps.capture.capture(request) }` on each line) and record it. The Phase 1 compile test (§6.8) catches this early.

2. **The one divergent strategy** is `developForCapture`. A develop failure must not fail the capture, while a save failure must. It is therefore handled inline and *named*:

```swift
/// Divergent strategy: a develop failure must not lose the capture; it falls back to a DNG-only save (DevelopState.pending).
private func developForCapture(_ raw: RawCapture, _ entry: JournalEntry) async -> Rendition? {
  do { return try await deps.developer.export(raw.dng, look: entry.look, geometry: entry.geometry) }
  catch { log.error("develop at capture failed: \(error, privacy: .public)"); return nil }
}
```

   This is the only `do/catch` inside a flow. `try?` appears nowhere in `pikicam/`.

3. Each live client's public methods wrap a private `…Body` whose throws are the client's own error type. Translation from framework errors happens only in the boundary/client file.

4. Views are dumb: they render `@Observable` model state and send intents (`model.shutterPressed()`). No business logic, AVFoundation, Photos or Core Image in any `View`. The exceptions are `Features/Camera/PreviewLayerView.swift`, the one view that owns an `AVCaptureVideoPreviewLayer` and unwraps a `SessionHandle`, and the AVKit import for `onCameraCaptureEvent` in `CameraScreen.swift`.

**File layout (create exactly this; delete every other source file under `pikicam/`; keep `Resources/` assets, including `AppIcon`):**

```
pikicam/
  App/            PikicamApp.swift, Dependencies.swift, RootView.swift (permission gate → Camera)
  Domain/         IDs.swift, Exposure.swift, WhiteBalance.swift, Focus.swift, CameraSettings.swift,
                  Capabilities.swift, CaptureRequest.swift, RawCapture.swift, Provenance.swift,
                  FrameGeometry.swift, Look.swift, Mono.swift, Recipe.swift, LibraryItem.swift, Journal.swift,
                  Recording.swift, States.swift, Errors.swift
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
  Features/
    Camera/       CameraModel.swift, CameraScreen.swift, Viewfinder.swift, PreviewLayerView.swift,
                  ReadoutRail.swift, LensRail.swift, Dock.swift, Shutter.swift, RecordButton.swift,
                  ScanOverlay.swift, ManualPanel.swift, QuickSettings.swift,
                  Overlays.swift (grid, level, reticle, histogram, frame mask)
    Library/      LibraryModel.swift, LibraryScreen.swift
    Viewer/       ViewerModel.swift, ViewerScreen.swift, PlayerView.swift, DevelopPanel.swift, InfoSheet.swift
    Permissions/  PermissionsModel.swift, PermissionsScreen.swift
    Settings/     SettingsScreen.swift, SettingsKeys.swift
  DesignSystem/   Palette.swift, Tokens.swift, Type.swift, Contrast.swift, AccessibilityID.swift,
                  Fonts/ (SpaceMono-Regular.ttf, SpaceMono-Bold.ttf, OFL.txt), Haptics/ (shutter.ahap, detent.ahap, tick.ahap, failure.ahap),
                  Components/ (BastingStitchReticle.swift, CareLabelStrip.swift, NumericLineMatrix.swift,
                  TurretFocalSelector.swift, TactileCalibrationDial.swift, EmulsionToggleCard.swift,
                  GessoShutterActuator.swift, ArchiveRollDeck.swift, BracketButton.swift, ErrorBanner.swift, Plate.swift)
  Support/        Retry.swift, Timeout.swift, Tracing.swift, ContinuationOnce.swift, MapError.swift
  Fakes/          FakeCaptureClient.swift, FakeDeveloper.swift, InMemoryLibrary.swift,
                  FakeRecordingClient.swift, FakeScanClient.swift, FakePermissions.swift, FakeMotion.swift,
                  FakeScenario.swift   (Debug only, `#if DEBUG`; selected by launch argument `-pikicam.fake <scenario>`)
  Resources/      Assets.xcassets (keep AppIcon — project.yml names it; give AccentColor real values), PrivacyInfo.xcprivacy
```

Test targets: `pikicamTests/` (unit tests, mirroring the app folders), `pikicamUITests/` (`CameraUITests.swift`, `LibraryUITests.swift`, `PermissionsUITests.swift`, `Support/AppLauncher.swift`) and `pikicamDeviceTests/DeviceProbeTests.swift`.

No file may exceed ~300 lines; split by responsibility if it does. `Domain/` files import only Foundation/CoreGraphics (a unit test greps their imports).

**Delete list (§0.1 item 7):**
- `pikicam/Core/**` (Design/Room.swift, Design/ControlIDRegistry.swift, Storage/PhotoLibraryManager.swift)
- `pikicam/Features/Camera/*` (old), `pikicam/Features/Develop/*`, `pikicam/Features/Gallery/*`
- `pikicam/Resources/Info.plist` (generated plist is used)
- `pikicamTests/DesignLintTests.swift`, `pikicamTests/CameraControlTests.swift`, `pikicamTests/PikicamPipelineTests.swift`. They are replaced. Port into the new Domain tests the NaN/infinity/out-of-range edge cases from `CameraControlTests` (the best tests in the old repo) and the "developed extent is upright" assertion from `PikicamPipelineTests`. Drop copy-assertion tests.
- `pikicamUITests/SmokeLaunchTest.swift` (replaced)
- `scripts/verify-design.sh`, `.github/workflows/design.yml`
- `docs/.P.DESIGN.md`, `docs/design/**`, `docs/prompt-next.md`
- (`AGENTS.md`, `docs/xcodegen.md` and `scripts/verify.sh` are already deleted in the working tree; recreate only `AGENTS.md` and `scripts/verify.sh` as specified.)

Also delete `.pre-commit-config.yaml` (it calls a deleted script), `.swiftlint.yml` and `.swift-format` (never enforced; the tools aren't installed), and `.agents/` (it describes a repo that does not exist). Structural rules live in the test suite (§7.5). Rewrite `pikicam/Resources/PrivacyInfo.xcprivacy` to declare only APIs actually used: `UserDefaults` (`CA92.1`) for `@AppStorage`, and nothing else unless the code calls it.

---

## 7. Tests (`pikicamTests/`, `pikicamUITests/`, `pikicamDeviceTests/`)

Use Swift Testing (`import Testing`, `@Test`, `#expect`) for unit tests and XCTest for UI tests.

1. **Domain:**
   - clamping of ISO / shutter / Kelvin / EV at limits and out-of-range values;
   - `FrameGeometry`: aspect × crop → rect; integral rounding; the overlay rect equals the develop rect for every aspect and crop at three viewfinder sizes.
2. **Capture (fake AV seams):**
   - `CaptureRequest.makeSettings()` yields `.speed`, a Bayer format, max dimensions, no processed format, flash off (inspect the real `AVCapturePhotoSettings` object, which is constructible on the simulator);
   - `PhotoBoundary` rejects non-RAW, wrong pixel format, fusion-enabled resolved settings, non-TIFF bytes and LinearRaw DNGs (use the ProRAW fixture when present; synthetic TIFF bytes otherwise);
   - single-resume continuation: double resume and timeout paths.
3. **Develop** (real `CIRAWFilter`, fixture-gated per 7.9):
   - the source contains no 1-arg `CIRAWFilter(imageData:)`;
   - every recipe control reads back neutral through its declared property, on a filter whose class was first asserted to be `CIRAWFilter`, so the test fails cleanly instead of crashing on a stub;
   - `highlightRecoveryEnabled == false` after apply;
   - `baselineExposure` equals the DNG tag (untouched);
   - `decoderVersion` pinned and ≠ RAW 9;
   - `type(of: filter) == CIRAWFilter.self` for the production factory;
   - EDR headroom: the neutral render read back through a `64RGBAHalf` `CVPixelBuffer` in `extendedLinearDisplayP3` has max > 1.0;
   - `PikicamLook` with EV −1 halves the linear mean (±3%), and EV 0 + neutral curve keeps mid-grey;
   - the source contains no `linearSpaceFilter` and no `responds(to:`;
   - pixel fingerprint: the neutral `CIRAWFilter` output differs measurably from Apple's default render of the same DNG. Take the thresholds from the Phase 0 measurement (highlight-clip count, crushed-black count, Laplacian variance as a sharpening proxy), set each at half the measured gap, and record them in `docs/DECISIONS.md`;
   - tone curve: monotone; 0 → 0; mid-grey 0.18 → 0.18 ± 0.01; output ≤ 1 for every input up to 4.0; an input of 2.69 (E=2 headroom) maps to > 0.95 and < 1.0, i.e. no hard clip;
   - HEIC export decodes, is 10-bit, and is tagged Display P3;
   - `RecipeApplication.unapplied` is empty on the simulator, where *unapplied* means a control we set whose read-back differs from neutral. `unsupported` is reported separately; on the ProRAW fixture it is expected to contain exactly the lens-correction control (`isLensCorrectionSupported == false`, measured; research 02 D9).
   - **Mono (§4.2.6):** every preset yields R == G == B within 1/1024 after the tone curve; `MonoWeights.init(validating:)` rejects negatives and sums ≠ 1; the dither is deterministic (same input pixels → same output bytes); mono and colour share the identical curve output on a mid-grey input.
4. **Library/Journal** (temp directories, `InMemoryLibrary`):
   - persist → crash (drop the in-memory object) → `RecoveryFlow` completes the save exactly once;
   - journal decode of an unknown version → `JournalError.corrupt`; `AdjustmentCodec` round-trips v1 and rejects a foreign format id;
   - `AssetBoundary` accepts DNG as either `.photo` or `.alternatePhoto` and accepts the UTI variants or the `.dng` extension.
5. **Design system:**
   - every text and non-text token pair ≥ 4.5:1 / 3:1 on `plate` and `canvas` and under the stamp backing over white and black, computed by `Contrast.swift`;
   - a source scan fails on: raw colour outside `Palette.swift` (`Color(red:`, hex literals, `Color.yellow|red|blue`), `Font.custom` or `.font(.system(size:` outside `Type.swift`, spacing literals outside the U-grid values, any radius other than 0 or circle, `.preferredColorScheme(`, or the strings `PRO-RAW`, `REC.2020`, `Material Symbols` anywhere in `pikicam/`;
   - every `Button` in `Features/` is a `BracketButton` or carries the 44 pt modifier;
   - every user-visible string literal in `Features/` goes through `String(localized:)` (`Text("…")` with a literal is a `LocalizedStringKey` and passes);
   - each `.ahap` file parses and its events reference only bundled or transient parameters (no missing waveform references);
   - the fonts resolve: `Type.swift`'s roles render with the bundled family (assert via `UIFont(name:)` non-nil for both weights), and both licence files exist beside the font files;
   - the numeric line table: enabled lines equal §4.2.7's mapping; every other line reports `DORMANT` and is non-interactive.

   These structural checks use strict regexes, each with its own tests (e.g. `(Color\.(yellow|red|blue))`). Do not add a SwiftSyntax package: it adds a dependency and plugin-sandbox failure modes under `ENABLE_USER_SCRIPT_SANDBOXING`.
   - A small brace-counting scanner in the test target fails on any function in `pikicam/` whose body exceeds 40 lines, and on any file over 300 lines (§1 rule 10).
6. **Flows** (all fakes): capture happy path; develop failure → DNG-only + `.pending`; save transient failure → retry then success; save `.storageFull` → journal retained + `CameraError.library(.storageFull)`; interruption mid-capture → `.ready` + banner; record start → stop → `saveVideo` happy path; a writer failure mid-record → `.failed` + partial files cleaned at next launch; scan start → stop → `saveScan` happy path; a stall or drop-threshold stop → partial scan saved and marked `PARTIAL`.
7. **Models:** `ShutterState` transitions including countdown cancel; `CameraModel` never publishes a lens without Bayer; permission gate passes on scene-active re-evaluation.
8. **UI tests** (launch argument `-pikicam.fake <scenario>`, which builds `Dependencies.fake`: `PreviewSource.synthetic`, canned captures, scripted permission states):
   - permissions each state;
   - camera reachable;
   - shutter → thumbnail updates to the new capture;
   - manual panel: set ISO via stepper; VoiceOver adjustable action on EV;
   - timer start/cancel;
   - landscape layout snapshot of control frames (all ≥ 44 pt, none overlapping the viewfinder rect);
   - AX5 layout: no truncated labels. `XCUIElement` has no truncation flag, so assert structurally: every identified control's frame is ≥ 44 pt, lies inside the window, and does not overlap the viewfinder rect or a sibling control. Add a unit-level check that each token's label fits its container width at AX5, measured with `NSString.size(withAttributes:)` on the token's `UIFont`;
   - library → viewer → info → develop → save → revert → delete;
   - viewer chrome hidden → escape still exits;
   - record in fake mode: start, elapsed readout ticks, stop → clip appears in the library; playback controls work (play, scrub, pause on page change);
   - video Develop save shows the progress sheet and completes; Revert on a video returns to the master;
   - scan in fake mode: start, live assembly progress caption, stop → still appears in the library with its scan provenance in Info;
   - XCUITest accessibility audit: `performAccessibilityAudit()` runs on the camera and library screens; any audit failure fails the suite (iOS 17+ API, available on 26.5).

   Identifiers come only from `AccessibilityID`.
9. **Fixtures and device tests:**
   - The ProRAW fixture stays git-ignored. Fixture-gated tests call `try #require(Fixture.proRAW)` with a message naming the path. `scripts/verify.sh` prints a loud warning listing every fixture-gated test that skipped, and fails if the fixture is present but a gated test skipped.
   - `pikicamDeviceTests` (scheme `pikicam-device`, skipped on the simulator by `#if targetEnvironment(simulator)`) runs the **device probe**. Per lens, it records: device type, `isVirtualDevice`, GDC supported/enabled after configuration, Center Stage active, video HDR state, color space, `supportedMaxPhotoDimensions`, all RAW formats, `supportedFlashModes`, exposure/WB limits. It captures once and dumps `resolvedSettings`, `photo.metadata` EXIF and the DNG's IFD tags (`PhotometricInterpretation`, CFA tags, `BitsPerSample`, `WhiteLevel`, `BlackLevel`, `LinearizationTable` presence, `ColorMatrix1/2`). It then attempts a `flashMode = .on` RAW capture, saves the §4.3.2 asset shape (and the fallback shape) to Photos, and writes everything as JSON to the app's Documents (`probe-<date>.json`). It also copies one captured DNG to `Documents/fixture-bayer.dng` so the owner can add it as a Bayer fixture.
10. **Fuzz:** `DNGInspector` and `FileJournal` accept the mutated corpus (seeded generator inside the test target; 50 variants per suite run, full corpus in CI) with no crash, no hang (per-case timeout) and typed errors only.
11. **Reference diff:** `scripts/reference-diff.py` asserts the fixture's committed per-channel scene-linear statistics against the Phase 0 tolerances (§1.5). A missing Python environment is a loud skip, listed by `verify.sh` like a fixture skip.
12. **Video:** both files decode with `AVAsset` (duration, track count, colour tags read back); the look with EV −1 halves the linear mean on a synthetic frame, and the **master's pixels are untouched** (decoded master matches a reference render of the delivered frames within quantisation); the `pikicam.provenance` metadata item round-trips, including a timed control-change event; injected late frames are counted and surface as `.framesDropped`, never silently dropped; a mode outside the recorded budget ladder is rejected with `.formatUnavailable`; `MUTE` produces a video-only asset; `saveVideo` creates the asset with the master as `.movie`, commits the rendition as the first content edit, and Revert restores the master.
13. **Design parity (DoD 14):** XCUITest captures the fake-mode camera screen at the reference device size; `scripts/design-diff.py` compares it against the export's committed reference render (§8 Phase 0) region-by-region — plates, rails, dock — with the viewfinder content region masked. Each region's mean pixel difference stays inside its committed tolerance, recorded in `docs/DECISIONS.md` after Phase 5's first measured baseline. Missing screenshot tooling is a loud skip, listed by `verify.sh` like a fixture skip. The reconciliation ledger covers every token and component of the export: adopted, adapted, or rejected with a reason.
14. **Scan (§4.6, DoD 15):** a synthetic frame stream assembles to the exact expected geometry (slit order, width, axis; moving-slit phase math); the master is the neutral assembly and the rendition carries the look (EV −1 halves the linear mean); the drop policy duplicates the previous slit into a gap, counts it, and auto-stops above 1 % with a `PARTIAL` provenance mark; the stall guard fires at 3× the nominal interval; memory-pressure downscale is a recorded event; `saveScan` creates the asset with the neutral master as `.photo`, the rendition as its first content edit, and Revert restores the master.

---

## 8. Execution plan

Every phase ends with `scripts/verify.sh` green (from Phase 1 on) and one commit. When a phase is done, append a short entry to `docs/DECISIONS.md` covering what was decided and why.

**Phase 0: Read and probe.**
- Read this file, then `docs/workflow/research/04-code-quality.md` and `06-adjudication.md` in full. Read 01, 02, 03 and 05 at the sections cited in §2. Where research files disagree, 06 (measured adjudication) wins over 01/02/03.
- Tooling: `xcodegen` is not installed. Run `brew install xcodegen swiftlint periphery exiftool` and `python3 -m pip install --user rawpy numpy imageio` (the reference-diff harness); `muter` is installed at Phase 10 (its runtime is long). Confirm `xcodegen --version`. If installation is impossible, stop editing `project.yml`-dependent structure, record the blocker in `docs/DECISIONS.md`, and continue with code that does not need regeneration. Confirm `xcodebuild -version` (Xcode 26.x) and that an `iPhone 17 Pro` iOS 26.5 simulator exists (`xcrun simctl list devices available`).
- Create branch `rebuild` and the snapshot commit.
- Write throwaway probes under `/tmp/pikicam-probe/` (never in the repo). Reuse `/tmp/pikicam-adjudicate/` probes if they still exist. On the iOS 26.5 simulator, confirm each of the following and record the result in `docs/DECISIONS.md`:
  1. `CIRAWFilter(imageData:identifierHint:)` returns the real class, and every §4.2.2 control assigns and reads back.
  2. `filter.isHighlightRecoveryEnabled = false` compiles with zero warnings under `-warnings-as-errors` and reads back false.
  3. The EDR value `E` per the rule in §4.2.2.
  4. In a scratch Xcode project generated by xcodegen under `/tmp/pikicam-probe/` (the CI-kernel language needs Xcode's build rule; bare `xcrun metal` cannot resolve it), a `.ci.metal` file builds with `MTL_COMPILER_FLAGS=-fcikernel` / `MTLLINKER_FLAGS=-cikernel`. One `CIColorKernel` (exposure gain on `coreimage::sample_t`) and one `CIKernel` (sampling passthrough) both load from the `.metallib` and apply to `outputImage`: EV −1 halves the linear mean, and passthrough is identity. Record the working flags.
  5. `createCGImage(…format: .RGBA16, colorSpace: displayP3)` at full fixture size does not trap.
  6. The `AVCaptureClient` executor form (§6.9) compiles under `-swift-version 6 -warnings-as-errors`; the §6.8 wrappers and the §6.11 exemplar shape type-check.
  7. Already verified by research 07, so only re-check if a build fails: `onCameraCaptureEvent` (AVKit), `RotationCoordinator`, `AVCapturePhotoOutputReadinessCoordinator`, deferred start, the WB temperature/tint lock, `CIContextOption.memoryTarget`, `heif10Representation` (async, `Data?`), and `CIRAWDecoderVersion.version9`.
  8. The PhotoKit asset shape: run candidates A → B → C from §4.3.2 against the pass criterion on the simulator Photos library, using the ProRAW fixture as the DNG payload. Grant access *after* the probe app is installed: `xcrun simctl privacy booted grant photos <bundle>` and `photos-add`. Delete every probe asset afterwards.
  9. Video (§4.5): enumerate `AVCaptureVideoDataOutput` `availableVideoPixelFormatTypes` on the simulator; record the best 10-bit format actually offered, and confirm `AVAssetWriter` accepts the HEVC 10-bit + HLG colour-tag settings with a synthetic frame. Record whether ProRes codec types are reported as available at all.
  10. Mono kernel (§4.2.6): the weights math in a `CIColorKernel` — the Neutral preset on the fixture yields R == G == B within quantisation, and each filter preset moves the linear mean in its documented direction.
  11. Fuzz smoke: 50 seeded variants of the fixture through the `DNGInspector` walker — typed errors only, no crash, no hang.
  12. Performance baseline: signpost the neutral develop at thumbnail and full fixture size, and the rawpy reference render; record the numbers as the CI budgets (§1.5).
  13. Design references (§5.0): download Space Mono Regular/Bold (Google Fonts, OFL) and verify the licence file ships beside them; render the two export screens (`docs/design-source/*/code.html`) to PNG at the reference device's logical size with whatever headless tooling exists (`npx playwright screenshot`, `chrome --headless --screenshot`, or equivalent) and commit the renders plus the tooling used to `docs/design-source/references/`. If no headless renderer is available, the export's own `screen.png` files are the references; record their viewport and the scaling used. Parse the export's Tailwind config and CSS custom properties into a token table committed beside them, so the Palette is built from extraction, not transcription by eye.
- Commit the probes: every probe file lands in the `pikicamProbes` target (§6.1), not `/tmp`, so DoD 10 holds. The `/tmp` scratch remains the workspace while iterating; the committed form is the runnable record.
- Any probe that contradicts this document changes the implementation, not the probe: follow the probe, and record the change.
- **Fixture caveat.** The only DNG on this machine, `pikicamTests/Fixtures/IMG_1361.DNG`, is Apple **ProRAW / LinearRaw** (`PhotometricInterpretation 34892`, no CFA tags; research 06 C1), a file the app never captures. Every develop measurement in Phases 0–4 is therefore ProRAW-measured. Say so at the top of `docs/DECISIONS.md`. Re-run the develop suite against `fixture-bayer.dng` once the owner's device probe (§7.9) produces it, and list that in `docs/DEVICE-CHECKLIST.md`.

**Phase 1: Skeleton.**
- Apply the delete list (`docs/design-source/` is input — it is never deleted).
- Rewrite `project.yml` (§6.1), create the §6.11 folders, `Domain/` shapes, `Support/` wrappers, the `DesignSystem/` two-layer tokens (`Palette.swift` from the Phase 0 token extraction), bundled fonts and `.ahap` files, the reconciliation ledger (§5.0) opened in `docs/DECISIONS.md`, `Dependencies` with fakes, `scripts/verify.sh` and `ci.yml`.
- Make the app launch to a placeholder `RootView`.
- In `docs/DECISIONS.md`, record each Q-row in §2.5 with its resolution.
- Accept: verify green; Domain and Support tests pass; the contrast test passes against the Margiela palette; the font-registration test passes.

**Phase 2: Capture core.**
- Build `AVCaptureClient`, configuration (§4.1.2–4.1.4), determinism read-back, `PhotoBoundary`, delegate scoping, readings, meters, rotation, lifecycle.
- Accept: capture unit tests green; the fake client drives the same protocol.

**Phase 3: Develop core.**
- Build `CoreImageDeveloper`, `NeutralRecipe`, `PikicamLook` + Metal kernel, mono stage and presets (§4.2.6), `DNGInspector`, contexts, render targets, HEIC encode.
- Accept: every develop test in §7.3 green with the fixture present (it is present on this machine at `pikicamTests/Fixtures/IMG_1361.DNG`; verify it exists first), including the mono and dither tests.

**Phase 4: Library, journal, flows.**
- Build `PhotoKitLibrary`, `AssetBoundary`, `Album`, `AdjustmentCodec`, `FileJournal`, `ThumbnailStore`, Share, and `CaptureFlow`/`RecoveryFlow`/`EditFlow`.
- Add an integration test that runs against the real simulator Photos library: the scheme grants Photos access before tests via `xcrun simctl privacy`, or the test is gated on authorization with a loud skip message listed in `verify.sh`. It saves one asset (using the ProRAW fixture as the `.photo` payload) and asserts album membership, the resource set, the adjustment round-trip and deletion. It deletes every asset it creates.
- Accept: §7.4 and §7.6 green.

**Phase 5: Camera UI.**
- Build all of §5.2, §5.3 and §5.4 from the §5.1 Margiela components only, including the line matrix, the care-label rail and the basting reticle.
- Accept: UI tests for camera green in portrait, landscape and AX5; the §7.13 design-parity baseline measured and its tolerances recorded.

**Phase 6: Library and Viewer UI.**
- Build §5.6, including develop edits and share.
- Accept: library/viewer UI tests green.

**Phase 7: Permissions, states, settings.**
- Build §5.5, §5.8 and §5.9.
- Accept: permission/state UI tests green.

**Phase 8: Video and scan.**
- Build `RecordingClient`, `AVRecordingClient`, `VideoFrameBoundary`, `VideoLook`, the two-writer pipeline (master + rendition, §4.5), `RecordFlow`, `RecordButton`, `PlayerView`, and the Quick Settings plumbing (video mode, mute, mono-mode).
- Build `ScanClient`, `AVScanClient`, `ScanAssembler`, `ScanFlow`, `ScanOverlay`, and the Quick Settings scan rows (§4.6), including the buffer guards (stall, GPU retry, memory-pressure downscale).
- Apply probe 9's recorded format decisions; if the probe contradicts §4.5's target format, follow the probe and record.
- Implement the budget ladder as data: modes are offered from the probe-measured table, never hard-coded as always-available.
- Implement zoom ramp, mid-clip control-change events, and the `pikicam.provenance` metadata writer.
- Accept: video unit tests (§7.12) and scan unit tests (§7.14) green; fake-mode record, playback, re-render, and scan UI tests green; `git grep -n "AVCaptureMovieFileOutput" -- pikicam` finds nothing.

**Phase 9: Device probe target.**
- Build §7.9 `pikicamDeviceTests` and the `pikicam-device` scheme (build-only on the simulator: `xcodebuild build-for-testing -scheme pikicam-device` must succeed).
- Write `docs/DEVICE-CHECKLIST.md`. It must cover:
  - the GDC/preview FOV match (frame a ruler edge-to-edge; the DNG matches);
  - no exposure override in a dark scene (manual 1/4 s ISO 400 → DNG EXIF matches);
  - flash legality;
  - Bayer dimensions;
  - CFA tags;
  - `CIRAWFilter` neutral recipe on a real **Bayer** DNG (read-back + fingerprint);
  - Photos shows our render, and Revert shows the DNG;
  - thermal and interruption banners;
  - Camera Control / volume shutter;
  - landscape capture develops upright;
  - all four permission states;
  - the video budget ladder: for each mode (1080p30, 1080p60, 4K30, ProRes if reported) whether **both** writers hold the frame rate with the look pass on device — this table is the shipped mode list;
  - `exiftool` on one recorded `.mov` shows the HLG colour tags and the `pikicam.provenance` item; a mid-clip control change appears as a timed event;
  - a 5-minute recording does not trip thermal pause, or the pause/resume banner is observed;
  - zoom ramp during recording is smooth and each detent is a provenance event; mute and mic-denied record silently;
  - Photos shows the rendition, and Revert returns to the master;
  - scan on device: a scan of a moving subject shows the expected slit geometry; walking while scanning shows real drop behaviour (the drop policy and `PARTIAL` mark are observed, not assumed); the stall guard is exercised by covering the lens;
  - the haptics bench: each `.ahap` pattern is felt and judged on device — shutter dual-stage, dial detents, matrix ticks, failure (haptics cannot be verified on the simulator);
  - chrome legibility over real scenes: the care-label rail, badge and reticle are checked over a white sky, a night scene and skin tones (the export was designed over one moody B&W photo — the gates, not one render, decide);
  - ColorChecker capture for `scripts/colorcheck.py` (median ΔE ≤ 8, §1.5);
  - `dng_validate` (if built in Phase 0) accepts one captured DNG and one exported DNG unchanged.

**Phase 10: Documentation and final audit.**
- `README.md`: what pikicam does and does not do, the platform ceilings in plain words (no Bayer video and no Bayer scan, §4.5–4.6; ProRAW-measured develop until the device fixture lands), how to build, how to run `verify.sh`, the reference-diff harness, and the device probe.
- `AGENTS.md`: ≤ 80 lines covering project rules (XcodeGen, Swift 6, sinthink structure, delete-don't-comment, verify before commit).
- `docs/DECISIONS.md`: complete.
- Run the full hygiene pass and record every result in `docs/DECISIONS.md`: SwiftLint strict (zero), `periphery scan` (zero), SwiftFormat check (clean), `muter` score on `Domain/` + `Support/` with surviving-mutant dispositions, Thread-Sanitizer suite run (clean), reference-diff within tolerances, full fuzz corpus pass.
- Complete the §5.0 reconciliation ledger: every export token, component and copy string carries its adopted / adapted / rejected verdict; run the §7.13 design-parity diff one final time.
- Then run §10.

---

## 9. Non-goals (v1)

Out of scope for v1:
- Our own demosaic from `AVCapturePhoto.pixelBuffer`. The `Developer` protocol is the seam for a future `MetalDeveloper`; do not build it.
- Noise reduction and sharpening.
- HDR/EDR display and EDR stills export (HLG video, §4.5, is in scope).
- ProRAW mode.
- Front camera.
- Cinematic mode, spatial video, slow-mo and timelapse (plain 30 fps record only, §4.5). ProRes on devices the Phase 9 probe cannot prove.
- The dormant numeric lines' effects — grain, halation, soft-focus diffusion, edge-detection overlays (§4.2.7). They render DORMANT, never as placebos.
- A light theme (dark-only brand, §5.0). Custom shutter sounds (the system sound is kept, §5.0).
- ML subject classification (the reticle stamp shows the active line instead, §5.0).
- Bracketing and multi-frame merge.
- Focus peaking and zebras (the histogram + clip bars cover clipping).
- GPS.
- iPad.
- Lens distortion correction (there are no coefficients without multi-camera delivery; research 02 D9).
- iCloud-specific flows beyond `isNetworkAccessAllowed` for original resource fetch.
- Localisation beyond English. Copy still goes through `String(localized:)`, enforced by §7.5.

---

## 10. Final self-check (run before the last commit; fix anything that fails)

- [ ] `scripts/verify.sh` green from a clean `build/` directory; tests executed > 0; skipped tests are only the documented fixture-gated / device ones.
- [ ] `git grep -nE "CIRAWFilter\(imageData: *[A-Za-z_.]+\)"` → nothing. `git grep -n "PHImageManager" -- pikicam` → nothing (originals come from `PHAssetResourceManager`).
- [ ] `git grep -nE "photoQualityPrioritization *= *\.(balanced|quality)"` → nothing. `git grep -n "videoZoomFactor *="` → nothing (zoom is never set).
- [ ] `git grep -nE "linearSpaceFilter|responds\(to:|supportedCameraModels|objc_setAssociatedObject|MPVolumeView" -- pikicam` → nothing. `git grep -n "@unchecked Sendable" -- pikicam` → only the `SessionHandle` declaration (§6.9), with its proof comment.
- [ ] `git grep -n "try?" -- pikicam` → nothing. `git grep -n "\.shared\b\|\.default()"` → only live clients and `Dependencies.live()`.
- [ ] `git grep -nE "TODO|FIXME|for now|XXX"` → nothing. No commented-out code.
- [ ] `git grep -n "AVCaptureMovieFileOutput" -- pikicam` → nothing. `git grep -ni "cinematic" -- pikicam` → nothing.
- [ ] Video: the master-untouched test, the provenance round-trip test, and the saveVideo/Revert test exist and pass; the shipped mode list equals the recorded budget-ladder table.
- [ ] Design: `git grep -nE "PRO-RAW|REC\.2020|Material Symbols" -- pikicam` → nothing. No raw colour, `Font.custom`, non-grid spacing or non-zero flat radius outside `Palette.swift`/`Type.swift` (the §7.5 scan passes). The reconciliation ledger in `docs/DECISIONS.md` covers every export token and component, and the §7.13 design-parity diff is inside tolerances.
- [ ] Scan: the geometry, drop-policy, stall-guard and saveScan/Revert tests exist and pass; the README states the scan ceiling (ISP frames, §4.6).
- [ ] Hygiene green and recorded in `docs/DECISIONS.md`: SwiftLint strict zero, `periphery scan` zero, SwiftFormat clean, mutation score with dispositions, Thread-Sanitizer run clean, reference-diff inside committed tolerances, full fuzz corpus passed.
- [ ] The R == G == B mono test exists and passes; every `MonoPreset` has a unit test.
- [ ] The performance budgets are recorded with measured numbers, and CI asserts ≤ 2× each.
- [ ] No file in `pikicam/` over ~300 lines; `Domain/` imports only Foundation/CoreGraphics.
- [ ] Every §2 row maps to a test or a `docs/DECISIONS.md` entry; spot-check C1, C3, D1, D2, D3, D6, S1, U2, U6, U16.
- [ ] Every flow body in `Flows/` matches §6.3 node for node; the only inline error handling is `developForCapture`; every `init(mapping:)` has its exhaustiveness test.
- [ ] Every delete-list path is gone; `docs/workflow/` untouched.
- [ ] `README.md` claims nothing the code does not do.
