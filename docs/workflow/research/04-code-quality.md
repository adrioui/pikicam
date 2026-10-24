# 04 — Code quality / slop audit (whole codebase)

**Research date:** 2026-10-02 · **Repo:** `/Users/adrifadilah/Desktop/pikicam` @ `e5e976a` + dirty working tree
**Toolchain observed:** Xcode 26.6 (17F113), Swift 6.3.3, SDK `iphonesimulator26.5`, host macOS 26.5. `xcodegen` **not installed** on this machine.
**Scope read in full:** every `.swift` file in `pikicam/` (21 files, 4 535 lines), `pikicamTests/` (4 files, 1 836 lines), `pikicamUITests/` (1 file, 812 lines), `project.yml`, `pikicam.xcodeproj/project.pbxproj`, the shared `.xcscheme`, `.github/workflows/design.yml`, `.pre-commit-config.yaml`, `.swiftlint.yml`, `.swift-format`, `.gitignore`, `.agents/skills/swift-coding-standards/SKILL.md`, deleted `AGENTS.md` + `scripts/verify.sh` (via `git show HEAD:`), `README.md`, and the heads of `docs/.P.DESIGN.md` / `docs/prompt-next.md` / `docs/design/**` / `docs/workflow/**`.
**Stance applied:** nothing in the repo is authoritative. Every judgement below is derived from first principles against the product goal (least-processed Bayer RAW capture → our own development → clean pro camera UX).

---

## Summary — top 10 findings

| # | Sev | Finding | Anchor |
|---|-----|---------|--------|
| 1 | **P0** | **The zero-process recipe is inert and its own test proves it by crashing the test host.** `CIRAWFilter.apply` guards every assignment with `responds(to:)`; on the real `CIRAWFilterImpl` the declared setters do not exist, so every entry is skipped and the filter renders with Apple's defaults. The proof test reads back `filter.baselineExposure` and hard-crashes with `-[CIRAWFilterImpl baselineExposure]: unrecognized selector` → `NSInvalidArgumentException`. The crash also aborts the rest of the unit suite (`Executed 0 tests` on the restart). **The product's entire claim currently applies nothing.** | `pikicam/Features/Develop/CIRAWZeroProcessor.swift:108`, `pikicamTests/PikicamPipelineTests.swift:555`, build log `/tmp/pikicam-build-r4b.log:1250-1270` |
| 2 | **P0** | **The entire design system is a test-only fiction.** `pikicam/Core/Design/{Room,ControlIDRegistry}.swift` are referenced by **zero lines of app code**; `DesignLintTests.swift` (918 lines) allowlists six token files that **do not exist** (`ChromeInk.swift`, `ChromeType.swift`, `ChromeRule.swift`, `Tack.swift`, `WordControl.swift`, plus the app's own `Room.swift`), asserts `.environment(\.room, …)` on six screens that have none, and reports **777 violations for 63 unique defects** because `DesignLint.run()` multiplies every rule's findings by the rule count. It is a regex linter, not a design system. | `pikicam/Core/Design/Room.swift:16`, `pikicamTests/DesignLintTests.swift:236-247`, `:672-680`, `:519-535` |
| 3 | **P0** | **The capture configuration relies on an Apple-documented-invalid default.** Apple states Bayer RAW **must** use `photoQualityPrioritization == .speed` and `videoZoomFactor == videoScaleAndCropFactor == 1.0`, else `NSInvalidArgumentException`. The code explicitly *refuses* to set quality prioritization and pins only `videoZoomFactor`, on the strength of an uncited on-device observation. | `pikicam/Features/Camera/CaptureService.swift:433-436`, `AVCapturePhotoOutput.h:85` |
| 4 | **P0** | **CI is a false green and the whole 812-line UI suite is unreachable.** The shared scheme's `TestAction` contains **only** `pikicamTests` — `pikicamUITests` is not a testable and not even in `BuildActionEntries`, contradicting `project.yml`. `.pre-commit-config.yaml` invokes `./scripts/verify.sh`, which is **deleted** in the working tree. The CI drift check inspects `project.pbxproj` only, never the scheme. The UI suite self-skips entirely on the simulator (the only destination CI uses), so all 812 lines are unexercised — and when read closely they target an accessibility-ID contract the app does not implement. | `pikicam.xcodeproj/xcshareddata/xcschemes/pikicam.xcscheme:31-45`, `.pre-commit-config.yaml:31`, `scripts/verify.sh` (deleted), `.github/workflows/design.yml:36-44` |
| 5 | **P1** | **Swift 6 does not compile; strict concurrency is off and the hazards are real.** `SWIFT_VERSION = 5.0`, no `SWIFT_STRICT_CONCURRENCY`. Forcing `SWIFT_VERSION=6.0` fails at `PhotoLibraryManager.swift:829`; forcing `SWIFT_STRICT_CONCURRENCY=complete` produces five distinct errors-as-warnings, including a **`nonisolated deinit` touching actor state** and a **UIKit `@objc` action reaching main-actor state from a `nonisolated` context**. | `pikicam/Core/Storage/PhotoLibraryManager.swift:829`, `pikicam/Features/Camera/CaptureService.swift:60`, `pikicam/Features/Camera/CameraPreview.swift:55-57`, `pikicam/Features/Camera/PhotoCapture.swift:49,129` |
| 6 | **P1** | **`CameraViewModel` is a god object carrying three independent "is busy" state machines** (20 stored properties; `phase` enum + `captureTask` + `selfTimerTask` + `captureGeneration` + `zoomGeneration`), and **mirrors** the actor's `cameraPosition`/`flashMode` as a second source of truth that nothing keeps in sync on interruption. | `pikicam/Features/Camera/CameraViewModel.swift:41-83`, `:159-164`, `pikicam/Features/Camera/CaptureService.swift:178-201` |
| 7 | **P1** | **The storage layer is a 1 015-line journal/index/reconciler that makes the gallery the failure surface.** Every `save()` triggers `refresh()` on the shutter critical path, which takes a process-wide `NSLock` and can enumerate **every image asset and every resource in the entire photo library**. Losing the JSON index hides photos that are still in Photos. | `pikicam/Core/Storage/PhotoLibraryManager.swift:429-460`, `:543-560`, `pikicam/Features/Gallery/PikicamLibraryModel.swift:76-84` |
| 8 | **P1** | **Zero tests exist for every behavior-bearing type.** No test touches `CameraViewModel`, `CaptureService`, `PhotoLibraryManager`, `DevelopService`, or any view — because none of them accept injected dependencies (`CameraViewModel.init` hard-codes `CaptureService()`; `PikicamLibraryModel.init` hard-codes `PhotoLibraryManager()` and self-spawns two `Task`s in `init`). 35 of 36 unit tests assert pure arithmetic on `struct`s/enums. | `pikicam/Features/Camera/CameraViewModel.swift:36`, `pikicam/Features/Gallery/PikicamLibraryModel.swift:8,15-22`, `pikicamTests/CameraControlTests.swift` (all 35) |
| 9 | **P1** | **A `CIContext` (Metal device + render pipeline) is constructed on every gallery re-render.** `@State private var developService = DevelopService()` evaluates its initializer during the parent's `body`, so SwiftUI discards it and rebuilds a Metal-backed `CIContext` each time the view struct is re-created. The doc comment above it states the opposite. | `pikicam/Features/Gallery/GalleryView.swift:150-154`, `pikicam/Features/Develop/DevelopService.swift:18-33` |
| 10 | **P2** | **Systemic noise:** 39 decorative `nonisolated` annotations with no `SWIFT_DEFAULT_ACTOR_ISOLATION`; `public`/`nonisolated public` on 15 declarations in a single-target app; one `fatalError`; two near-identical thumbnail views; a hand-rolled Swift lexer in the test target; a 6× duplicated Home-coordinates `.red` rule; and a `PrivacyInfo.xcprivacy` that declares three required-reason APIs the app never calls. | `pikicam/Core/Storage/PhotoLibraryManager.swift:11-152`, `pikicam/Features/Camera/CameraView.swift:309`, `pikicam/Features/Gallery/GalleryView.swift:250`, `pikicam/Resources/PrivacyInfo.xcprivacy` |

---

## Build & test results (headless, reproduced)

Command actually run (no `xcodegen`, no file modified):

```
xcodebuild -project pikicam.xcodeproj -scheme pikicam \
  -derivedDataPath /tmp/pikicam-dd-r4 \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build test
```
Simulators available: `xcrun simctl list devices available` → iOS 26.5; `iPhone 17 Pro` (booted) selected.

**Result: `** BUILD SUCCEEDED **` then `** TEST FAILED **`.**

```
CameraControlTests      Executed 35 tests, 0 failures   (0.025 s)
DesignLintTests         Executed 26 tests, 6 failures   (1.015 s)
PikicamPipelineTests    9 executed, 3 skipped, then CRASHED → restart reported "Executed 0 tests"
```

* `pikicamUITests` **never ran** — not a testable in the shared scheme.
* Compiler warnings from the app target: **0**. (`warning: Metadata extraction skipped. No AppIntents.framework dependency found.` ×3 is toolchain noise.)
* Failing tests:
  * `DesignLintTests.testNoDesignViolations` — reports `777 design violation(s)`, of which **63 are unique** (7× duplicated by `DesignLint.run()`, `DesignLintTests.swift:672-680`). Kind breakdown (unique): 27 `missingIdentifier`, 15 `capsuleOrCircleShape`, 9 `rawRoundedType`, 7 `iconInChrome`, 4 `forbiddenColor`, 1 `tapTargetBelow44`.
  * `DesignLintTests.testSFSymbolIsAViolation` — the lint's own symbol parser is broken: `"camera.aperture").font(.largeTitle)"` leaks into the reported symbol name (`DesignLintTests.swift:375-381`).
  * `DesignLintTests.testTapTargetMinimumIsEnforced` (×3 assertions) and `testTapTargetRequiresBothAxes` — the `.frame(minWidth:…)` regex (`:432-449`) truncates multi-digit values to their first digit (`Double("44, minHeight: 4")` fails, `Double("32, minHeight: 3")` = 3.0), so the rule's unit test is red on itself.
  * `PikicamPipelineTests.testZeroRecipeReachesEveryControlOnARealFilter` — 16 × `XCTAssertTrue failed - CIRAWFilter does not respond to setBaselineExposure: / setExposure: / setBoostAmount: / … / setGamutMappingEnabled:` followed by `*** Terminating app due to uncaught exception 'NSInvalidArgumentException', reason: '-[CIRAWFilterImpl baselineExposure]: unrecognized selector sent to instance 0x106ff1e00'` and `Restarting after unexpected exit, crash, or test timeout`.

**Language-mode probes (also headless, no file modified):**

```
xcodebuild … SWIFT_VERSION=6.0 build                       → ** BUILD FAILED **
  PhotoLibraryManager.swift:829:24: error: static property 'inFlightSaveIDs' is not
  concurrency-safe because it is nonisolated global shared mutable state

xcodebuild … SWIFT_STRICT_CONCURRENCY=complete build       → ** BUILD SUCCEEDED ** (5 warnings, all "error in the Swift 6 language mode")
  PhotoLibraryManager.swift:829:24  nonisolated global shared mutable state
  CaptureService.swift:60:25        cannot access property 'sessionObservers' with a non-Sendable
                                   type '[any NSObjectProtocol]' from nonisolated deinit
  CameraPreview.swift:55:41         main actor-isolated property 'view' can not be referenced
                                   from nonisolated context
  CameraPreview.swift:56:39         call to main actor-isolated instance method 'location(in:)'
  CameraPreview.swift:57:25         call to main actor-isolated instance method 'devicePoint(for:)'
  PhotoCapture.swift:49:28          passing closure as a 'sending' parameter risks causing data races
  PhotoCapture.swift:129:21         sending 'capturedPhoto' risks causing data races
```

**Bottom line:** the project compiles clean today only because strict concurrency is disabled and because the crashing test happens to be the last-but-two case. Turning on Swift 6 breaks the build today.

---

## Architecture map (as built) and why it is wrong

### The graph as it exists

Single app target `pikicam` (no modules/frameworks; `project.yml:24-49`). 21 Swift files, one flat namespace, everything `internal` except 15 `public` declarations in `PhotoLibraryManager.swift`.

```
PikicamApp (App/PikicamApp.swift:11)
└─ @State CameraViewModel  ── @Environment ──▶ RootView ─▶ CameraView ─▶ GalleryView ─▶ FullScreenViewer

CameraViewModel  @MainActor @Observable        (Features/Camera/CameraViewModel.swift:16)
  ├─ owns CaptureService()                      ← hard-coded, no injection
  ├─ owns 20 published stored properties        ← two mirrored from CaptureService
  └─ 3 Tasks + 2 generation counters            ← 3 overlapping "busy" machines

CaptureService  actor + DispatchSerialQueue unownedExecutor   (Features/Camera/CaptureService.swift:14)
  ├─ AVCaptureSession / AVCapturePhotoOutput
  ├─ hand-rolled state: isRunning / isConfigured / isCaptureInFlight
  └─ NotificationCenter observers → 3 Task hops  ← misses the VM entirely
       │
       ├─ AVCapturePhotoOutput.capturePhoto(with:)  (Features/Camera/PhotoCapture.swift:128)
       │     └─ PhotoCapture (delegate, NSLock + 15 s timeout + objc_setAssociatedObject keyed on self)
       └─ queryActiveBayerFormat() → await MainActor.run { }   ← actor hops OUT to main

Capture  → CapturedDNG (Core/Storage/PhotoLibraryManager.swift:11)
           → PikicamLibraryModel.save  (Features/Gallery/PikicamLibraryModel.swift:76)  → await refresh() ← on the shutter path
                → PhotoLibraryManager.save  (actor, :294)
                     ├─ JSON journal in Application Support (pending → stored)
                     ├─ PHPhotoLibrary.performChanges (one .photo DNG resource)
                     └─ every refresh: reconcile pending by scanning the WHOLE library (:543-560)
           → PikicamCapture → libraryModel.select → viewer

Viewer  → PhotoLibraryManager.loadOriginalDNG (:604)
       → DevelopService.render (actor, Features/Develop/DevelopService.swift:17)
            → CIRAWZeroProcessor.develop (CoreImage CIRAWFilter, recipe guarded by responds(to:))
            → PrintCrop.rect (Features/Camera/CameraControls.swift:186)
            → CIContext.createCGImage → CGImage → UIImage

Core/Design/Room.swift + ControlIDRegistry.swift ──▶ referenced by NOTHING except pikicamTests
```

### Why the shape is wrong

**A. One target, one namespace, zero enforced layering — and the layering is already violated.**
`Core/Storage/PhotoLibraryManager.swift` (the bottom layer) `import`s and depends on `AspectRatio` (defined in `Features/Camera/CameraControls.swift:130`) and `CaptureOrientation` (defined in `Features/Develop/DevelopService.swift:89`). The dependency arrow points *upward*. `GalleryView` also depends on `PrintCrop` (a Camera-folder type) through `DevelopService`. Nothing stops this growing; only a compiler error would, and there is none because there are no modules.

**B. Three overlapping state machines for "is a capture in flight."**
`CameraViewModel.phase` (`.idle/.countdown/.capturing/.savingDNG`, `:20-30`), `CameraViewModel.captureTask`/`selfTimerTask` (`:60,:80`), `CameraViewModel.captureGeneration` (`:83`), `CameraViewModel.zoomGeneration` (`:75`), and `CaptureService.isCaptureInFlight` (`CaptureService.swift:50`). Six pieces of mutable state must agree for one boolean fact. Every mutator in `CaptureService` guards on `isCaptureInFlight` — **except `stopSession()`** (`CaptureService.swift:171-179`), so `RootView`'s scenePhase `.background` handler can tear down the session while an exposure is in flight.

**C. Authoritative state lives in two places and only one is notified.**
`CaptureService` owns `cameraPosition` (`:33`) and `flashMode` (`:36`); `CameraViewModel` publishes `cameraPosition` (`:63`) and `flashMode` (`:64`) copied by `refreshCameraControlState()` (`CameraViewModel.swift:159-164`). When `handleSessionInterrupted()` (`CaptureService.swift:195-197`) sets the service's `isRunning = false`, nothing tells the view model. `isConfigured` (`:55`) and `isSessionRunning` (`:54`) are two booleans encoding one state, and the possible combination "running but not configured" is representable.

**D. The design layer is a test artifact pretending to be a module.**
`Room`, `EnvironmentValues.room`, `RoomKey`, `ControlID`, `ControlIDRegistry` compile into the app binary and are used by nothing. `ControlIDRegistry.cameraZoomPreset(_:)` (`:110`) and `.cameraAspect(_:)` (`:115`) are used by nothing, not even tests.

**E. Zero dependency seams.**
`CameraViewModel.init` (`:36`) constructs `CaptureService()`; `PikicamLibraryModel.init` (`:15-22`) constructs `PhotoLibraryManager()` *and* fires two unowned `Task`s as a side effect of construction; `DevelopService.init(processor: RAWProcessor? = nil)` (`:20`) defaults to `CIRAWZeroProcessor()`. `RAWProcessor` is a protocol with exactly one implementation (over-abstraction) injected through a defaulted parameter that is never overridden (so it tests nothing). Result: the entire camera/storage/develop stack is untestable without a device, which is exactly what happened.

---

## Detailed findings

### P0-1 — The develop recipe is a no-op guarded by `responds(to:)`

**Evidence**
* `pikicam/Features/Develop/CIRAWZeroProcessor.swift:62-79` — `recipe` is 15 `(objcProperty, neutralize)` pairs.
* `:108` — `guard filter.responds(to: setter) else { return }`; the setter name is *derived by string surgery* (`:117-120`) from the recipe string.
* `:93-98` — the comment even admits "A missing setter is skipped rather than raised … the probe would then skip the control in silence."
* Build log: 16 × `CIRAWFilter does not respond to set<Name>:` then `-[CIRAWFilterImpl baselineExposure]: unrecognized selector` (`/tmp/pikicam-build-r4b.log:1249-1268`).
* Corroborated independently in `docs/prompt-next.md:36-58`, which enumerates the real `CIRAWFilterImpl` methods: `setInputBaselineExposure:`, `setInputBoost:`, `setInputLocalToneMapAmount:`, `setInputEnableSharpening:`, `setInputEnableVendorLensCorrection:`, `setInputDisableGamutMap:` — **none** of which match the derived `set<Name>:` form, and whose polarity differs per control (`DisableGamutMap` vs `EnableVendorLensCorrection`).

**Why it matters.** The product's entire claim is "we neutralise Apple's processing." Today the app calls `CIRAWFilter`, asks for nothing, and gets Apple's default render: `boostAmount` default **1.0 = "full global tone curve"** (per the SDK header), `contrastAmount` default **1.0**, `detailAmount` **1.0**, `sharpnessAmount` **1.0**, `localToneMapAmount` default documented as image-dependent, `luminanceNoiseReductionAmount` documented as image-dependent, plus `lensCorrectionEnabled` default **YES** and `gamutMappingEnabled` default **YES** (`CIRAWFilter.h:75-98`). The app ships a fully-processed photo and labels it "zero-process."

**Additional recipe gaps against the SDK header (`CIRAWFilter.h`):** `orientation` (`:52`), `draftModeEnabled` (`:55`, default **unverified** — if YES, the app is developing a *draft*), and `scaleFactor` (`:63`) are never set. `boostShadowAmount = 0` (`:81`) is semantically "darken shadows"; it is inert only because `boostAmount = 0` is set in the same list — an undocumented coupling. And the test's own list-against-SDK check (`PikicamPipelineTests.swift:466-499`) enumerates 15 names but never diffs against the header's actual declared set, so the "single source of truth" claim is not verified.

**Fix direction.** Delete `responds(to:)` string-derivation entirely. Assign every documented property directly and let the compiler type-check it. Read values back through the *declared* properties (which are guaranteed by the header) rather than through `responds(to:)` on derived selectors — the declared getters are what made the test crash, so they must be verified on-device, not assumed. Add a device-gated assertion test that every knob reads its neutral value. Decide `draftMode`, `scaleFactor`, `orientation` explicitly. If the goal is genuinely "our own development", plan for a real pipeline (demosaic + white balance + matrix from the DNG's own tags) and treat `CIRAWFilter` as a fallback/reference, not the product.

---

### P0-2 — The "design system" is a test-only fiction with a self-failing linter

**Evidence**
* `pikicam/Core/Design/Room.swift:16` (`enum Room`), `:24-29` (`EnvironmentValues.room`), `:31` (`RoomKey`) — `grep -rn "Room" pikicam/` returns hits **only inside `Room.swift` itself**.
* `pikicam/Core/Design/ControlIDRegistry.swift:38` — `grep -rn "ControlIDRegistry" pikicam/` returns hits **only inside `ControlIDRegistry.swift` itself**.
* `pikicamTests/DesignLintTests.swift:236-247` — `tokenLayerPaths` allowlists six files. Five **do not exist**; `Room.swift` is allowlisted but contains no colour literal. The allowlist's escape hatch therefore silently permits nothing while pretending to.
* `:388-401` — `Screens.all` names six screens and demands exactly one `.environment(\.room, …)` each. None of the six has any (`grep -rn "environment(\\.room" pikicam/` → 0 hits). Each contributes a fabricated `missingIdentifier` violation naming a *file:struct* pseudo-location (`:576-580`) — the reason the log shows entries like `GalleryView.swift#GalleryView:5`.
* `:672-680` — `DesignLint.run()`:
  ```swift
  for rule in ForbiddenPattern.allCases {
      all += ForbiddenPattern.violations(in: path, numbered: numbered)   // ← ignores `rule`
  }
  ```
  `violations(in:numbered:)` returns findings for *all* seven rules, so the set is multiplied by 7. 777 reported vs 63 unique = 12.33; the residual is the non-duplicated `tapTargetBelow44`/`missingIdentifier`/room rules. Confirmed empirically by the log (`forbiddenColor` appears 7 consecutive times per site).
* `:402-428` — `strippingComments` is a hand-rolled lexer that handles `//`, `/* */`, escapes and plain `"` strings only. Raw strings (`#"..."#`), multi-line strings (`"""`), character escapes inside interpolation, and regex literals all corrupt line numbers. The file acknowledges this (`:410-416`) and calls it "stated rather than hidden."
* `:421-425` — `forbiddenColor` checks `.red` with the regex `\.red\b`, so **Home-coordinates (0.5, 0.5, 0.5) also matches "red"** and is reported as `literal .red outside ChromeInk.fail`.
* `:100-107` — `static let repoRoot: URL = … #filePath …` — the lint finds the repo by the *compile-time source path* of the test file. Works only because the test bundle runs from a machine that also has the checkout; breaks for any out-of-tree/CI-artifact execution, and silently reads the *developer's* working copy rather than the *built* one.
* `testEveryScreenIsCountedExactlyOnce` (`:796-810`) asserts each declared screen has a file and a `struct` — it does **not** assert the screen uses the registry, so a renamed screen stays "green" while the real coverage count is a fiction.
* CI: `.github/workflows/design.yml:17-19` openly states the workflow "is expected to be RED"; `:36-44` runs the design lint and then runs `xcodebuild test … -skip-testing:pikicamTests/DesignLintTests` — i.e. the only workflow that could ever be green is not.

**Why it matters.** 918 lines of test code, 213 lines of spec, a 60-line CI workflow, a 90-line shell script and two "token" source files exist to describe a design system that is 212 lines of unused declarations. Meanwhile the actual UI (`CameraView.swift:126-215`, `GalleryView.swift:60-140`) is exactly the thing the spec forbids. The enforcement surface is theatre that actively consumes the maintenance budget.

**Fix direction.** Delete `DesignLintTests.swift`, `ControlIDRegistry.swift`, `Room.swift`, `verify-design.sh`, `.github/workflows/design.yml`, and `docs/design/**` + `docs/.P.DESIGN.md`. If a design system is wanted, express it as *real* SwiftUI types (`Design.Ink`, `Design.Type`, `Design.Space`, `Design.Motion`) that views actually consume, so misuse is a compile error or an obvious grep, not a 918-line regex harness with a `#filePath` root. Any UI-test identifier contract must be defined in **app** code (one `enum ControlID`) and *consumed* by the views, so drift is impossible by construction — that is the one genuinely good idea buried in this code, and it should be kept in that form.

---

### P0-3 — Capture config depends on an Apple-documented-invalid default

**Evidence (Apple SDK, authoritative)**
`AVCapturePhotoOutput.h:83-86`:
> Bayer RAW rules (isBayerRAWPixelFormat: returns yes for rawPhotoPixelFormatType):
> - `photoQualityPrioritization` must be set to `AVCapturePhotoQualityPrioritizationSpeed` (deprecated `autoStillImageStabilizationEnabled` must be set to NO).
> - the `videoZoomFactor` of the source device **and the `videoScaleAndCropFactor` of the photo output's video connection** must both be 1.0. Ensure no zoom is applied before requesting a RAW capture, and don't change the zoom during RAW capture.

`AVCapturePhotoOutput.h:117-118`: "If any of these rules is violated, an `NSInvalidArgumentException` is thrown."
`AVCapturePhotoOutput.h:1380` and `:344`: the **default** is `AVCapturePhotoQualityPrioritizationBalanced`.

**Code**
`pikicam/Features/Camera/CaptureService.swift:433-436`:
```swift
// Never set `photoQualityPrioritization` on RAW captures: AVFoundation
// raises NSInvalidArgumentException ("Unsupported when capturing RAW")
// at capture time. The default (.balanced) is used.
```
and `CaptureService.swift:522-541` resets only `device.videoZoomFactor`; `videoScaleAndCropFactor` is never touched.

**Why it matters.** The code asserts the opposite of Apple's documented requirement, based on an unreproducible observation, for a setting whose documented value for this exact configuration is the opposite of the one being relied on. This is the identical class of failure already recorded twice in this file's comments (`CaptureService.swift:413-418`, `:672-679`, both citing real SIGABRTs). An iOS update that enforces the documented rule turns every shutter press into a crash.

**Also relevant (UNVERIFIED, flag for research 01/02):** `AVCapturePhotoOutput.h:699` — "For apps linked on or after iOS 17 zero shutter lag is automatically enabled when supported." ZSL buffers frames from *before* the shutter press, which contradicts the app's provenance model (a timestamp and orientation sampled at press, `CameraViewModel.swift:281`). The code never touches `zeroShutterLagEnabled`. For a camera whose selling point is "the least-processed sensor data," whether ZSL is on is a product decision that must be made explicitly, not inherited.

**Verified NOT a defect (do not chase):** `AVCapturePhotoOutput.h:984` says for a `rawPhotoPixelFormatType` capture the delegate must respond to *either* `didFinishProcessingPhoto:error:` **or** the deprecated raw-sample-buffer variant. `PhotoCapture` implements the former (`PhotoCapture.swift:80-89`), so the mandatory-delegate rule is satisfied.

**Fix direction.** Explicitly set `settings.photoQualityPrioritization = .speed` and `photoOutput.maxPhotoQualityPrioritization = .speed` before `startRunning()`, and pin `videoScaleAndCropFactor = 1.0` on the connection, then verify on device. Put every "AVFoundation raises on this" rule into one table with the SDK header line that justifies it, and add a device-only test that exercises it.

---

### P0-4 — CI/pre-commit are broken and the UI suite is unreachable

**Evidence**
* `pikicam.xcodeproj/xcshareddata/xcschemes/pikicam.xcscheme:31-45` — `TestAction` lists exactly one `TestableReference` (`pikicamTests`). `pikicamUITests` is absent from `Testables` *and* from `BuildActionEntries` (`:7-25`). `project.yml:70-77` and `:88-96` both declare it in the scheme. **The checked-in scheme contradicts the source of truth.**
* `AGENTS.md:48-50` (deleted in the working tree) asserted "The shared scheme's test action runs `pikicamTests` and `pikicamUITests`" — verifiably false.
* `git status`: `D scripts/verify.sh`, yet `.pre-commit-config.yaml:31-38` still declares `entry: ./scripts/verify.sh` with `language: system, always_run: true` → every commit fails, or the hook is silently broken depending on install.
* `.github/workflows/design.yml:36-44` checks `git diff --quiet -- pikicam.xcodeproj/project.pbxproj` **only** — the scheme drift above would not be caught. `:24` `runs-on: macos-15` with a comment admitting the SDK pin is unresolved; `:49-53` and `scripts/verify-design.sh:53` both hard-code `name=iPhone 17`, which is not in this machine's simulator list (only `iPhone 17 Pro`/`Max`/`e`/`Air` exist under iOS 26.5).
* `scripts/verify-design.sh:24` regenerates the project *inside the verify script* — so "verify" mutates tracked files, then asserts they didn't change. A linter that rewrites the thing it lints is not a linter.
* Only one workflow exists, and it is named `Design`. There is **no** build workflow and **no** unit-test workflow: `xcodebuild build` and the 35-test unit suite are never run by CI.

**Why it matters.** The repository's automated quality signal is a red design lint plus nothing else. A green branch means "someone hand-edited the pbxproj without running xcodegen." The UI suite — the only thing that could catch a crash on the shutter — has never executed and cannot execute.

**Fix direction.** Delete `.github/workflows/design.yml`, `scripts/verify-design.sh`, `.pre-commit-config.yaml`, and the `.swiftlint.yml`/`.swift-format` pair unless they are wired into a CI job that actually runs. Add one workflow: `xcodegen generate` → `git diff --exit-code` over **both** `project.pbxproj` **and** `xcschemes/` → `xcodebuild build` → `xcodebuild test -only-testing:pikicamTests`. Pin `DEVELOPMENT_TEAM` and a real device, or accept that device coverage is a documented manual checklist, not CI.

---

### P1-5 — Swift 6 / strict concurrency

**Evidence** (probe output in §Build above)

| Location | Diagnostic |
|---|---|
| `PhotoLibraryManager.swift:829` | `static var inFlightSaveIDs: Set<String>` — process-wide mutable global guarded by an `NSLock`; a hard **error** under Swift 6 |
| `CaptureService.swift:60` | `deinit` (nonisolated) iterates `sessionObservers`, an actor-isolated non-`Sendable` array |
| `CameraPreview.swift:55-57` | `Coordinator.handleTap(_:)` is a plain `@objc` method in a non-`MainActor` nested class reading `recognizer.view`, `location(in:)`, `devicePoint(for:)` — all main-actor |
| `PhotoCapture.swift:49` | `Task { … self?.failWithTimeout() }` passed to a `sending` parameter |
| `PhotoCapture.swift:129` | `pending.resume(returning: capturedPhoto)` — sending a non-`Sendable` `AVCapturePhoto` across executors |

**Additional hazards the compiler does not yet flag but are real:**

1. **`CaptureSessionBox: @unchecked Sendable` (`CaptureService.swift:686-691`) is an isolation escape hatch.** The whole design — a custom serial executor so *no* AVFoundation call happens off the capture queue — is undone by handing the raw `AVCaptureSession` to the main thread, where `CameraPreview.updateUIView` assigns `previewLayer.session` (`CameraPreview.swift:41`). The `@unchecked` is where the safety argument went to die.
2. **`queryActiveBayerFormat()` (`:625-631`) hops *out* of the actor to `MainActor`** to read a static format list, on **every** capture. A capture now depends on the main run loop being free; a blocked main thread stalls the shutter. There is no reason for the hop.
3. **`PlaceholderBox` data race** (`PhotoLibraryManager.swift:966-968`, used at `:366-374`): a `@unchecked Sendable` class with an unsynchronised `var localIdentifier`, written inside `performChanges` and read in the completion handler. PhotoKit's ordering makes it work in practice; the compiler is right that it is a race.
4. **`RequestIDBox` install-after-issue race** (`:610-650`, `:690-720`): `requestIDBox.current = requestID` runs *after* `requestData`/`requestImage` returns. If cancellation lands in between, `onCancel` sees `nil`, resumes with `CancellationError`, and the PhotoKit request is orphaned.
5. **`stopSession()` lacks the `isCaptureInFlight` guard** every other mutator has (`:171-179` vs `:214`, `:319`, `:355`, `:373`, `:381`, `:424`). A scenePhase `.background` during an exposure tears the session out from under `capturePhoto`.
6. **39 decorative `nonisolated` annotations** (`PhotoLibraryManager.swift` ×19, `CameraControls.swift` ×8, `PhotoCapture.swift` ×3, others ×9). `nonisolated` on a *type declaration* only has meaning under Swift 6.2 default MainActor isolation; `SWIFT_DEFAULT_ACTOR_ISOLATION` appears in **neither** `project.yml` nor `project.pbxproj` (verified by grep). Today they are comments the compiler ignores.
7. **`PikicamLibraryModel: @unchecked Sendable` (`PikicamLibraryModel.swift:7`) is redundant** — a `@MainActor` class is already `Sendable`. It is a lie that makes future unsoundness invisible.
8. **`PhotoCapture`'s delegate is keyed on its own address** (`PhotoCapture.swift:132-134` and `:76-82`): `Unmanaged.passUnretained(self).toOpaque()` used as the associated-object key, cleared with `.OBJC_ASSOCIATION_ASSIGN`. It works only because the `RETAIN` association keeps the delegate alive for exactly as long as the key is valid. A recycled address plus a stale callback can clear an unrelated association. This is a hand-rolled lifetime protocol with no test.

**Fix direction.** Target `SWIFT_VERSION = 6.0` + `SWIFT_STRICT_CONCURRENCY = complete` from day one (the toolchain is Swift 6.3.3 — there is no reason to stay on 5 language mode). Replace the `inFlightSaveIDs` global with actor state. Move `sessionObservers` out of `deinit` (register/unregister on explicit lifecycle calls) or make the box `@unchecked Sendable` with a lock and justify it. Mark `CameraPreview.Coordinator` `@MainActor` and mark the `@objc` entry point `MainActor.assumeIsolated`. Replace `CaptureSessionBox` with a `PreviewSink` protocol so the view never receives the session. Drop the `MainActor.run` hop in `queryActiveBayerFormat`. Use `OSAllocatedUnfairLock`/an actor for the PhotoKit boxes instead of `@unchecked Sendable` + `NSLock`.

---

### P1-6 — `CameraViewModel` god object and duplicated state

**Evidence**
* 20 stored properties (`CameraViewModel.swift:41-83`), 19 of them `private(set) var` published to the whole view tree via `@Observable`.
* Three concurrency mechanisms for one flow: `phase` enum (`:20-30,59`), `captureTask`+`selfTimerTask` (`:60,80`), `captureGeneration`+`zoomGeneration` (`:75,83`).
* `runCapture` (`:266-306`) is a 40-line function with five `guard !Task.isCancelled, captureGeneration == gen` repetition sites (`:271,272,278,282,284,292,295`), one `await` on the actor for zoom reconciliation (`:299`), and a `catch` that inspects `error is CaptureError` (`:296`) — type-sniffing the error to decide which recovery to run.
* Mirrored state: `:63-64` vs `CaptureService.swift:33,36`, refreshed only by `refreshCameraControlState()` (`:159-164`).
* `stop()` (`:153-158`) cancels the timer and capture but never resets `isConfigured` or `isSessionRunning`'s companion — `isConfigured` survives a stop, so `CameraView`'s `if viewModel.isConfigured` guard (`:33,105`) keeps rendering a HUD for a torn-down session.
* `error: Error?` (`:56`) is an untyped published error. It is rendered by raw `localizedDescription` in a `.red` `Text` at the bottom of the control stack (`CameraView.swift:207-213`) — a stringly-typed error surface with no severity, no recovery affordance, and no accessibility role.

**Why it matters.** Every new camera feature (ISO, shutter speed, focus lock, manual exposure — i.e. everything a *pro* RAW camera needs) lands in this class, and the class is untestable because `CaptureService()` is hard-coded at `:36`.

**Fix direction.** Split into: `CameraSessionController` (owns `AVCaptureSession`, injected protocol), `CameraState` (a single `enum SessionState { case idle, starting, running, interrupted(reason), failed(CaptureFailure) }` — one representable state instead of two booleans), `CaptureCoordinator` (owns the single capture task and the timer, with **one** cancellation token), and `CameraViewModel` as a thin `@MainActor @Observable` façade over an `AsyncStream<CameraEvent>`. Replace `error: Error?` with `captureFailure: CaptureFailure?` where `CaptureFailure` is a typed enum carrying a user-facing message and a recovery hint.

---

### P1-7 — Storage: a journal whose failure mode is "your photos vanish from the app"

**Evidence**
* `PhotoLibraryManager.swift` is **1 015 lines**, 32 functions, in one type.
* `save()` (`:294-360`) writes a `pending` JSON record, calls PhotoKit, then rewrites the record as `stored`. Filename `pikicam-<uuid>.dng` (`:852`) is the crash-recovery correlation key.
* `captures()` (`:429-490`) takes the process-wide `indexLock` (`:823`) and, inside the lock, runs `reconcilePendingRecords` (`:442`) which — when any pending record exists — does `PHAsset.fetchAssets(with:)` with **no limit** and calls `PHAssetResource.assetResources(for:)` for **every image asset in the entire library** (`:556-560`). Then `pruneVanishedRecords` re-fetches by identifier (`:507`).
* `PikicamLibraryModel.save()` (`:76-84`) calls `await refresh()` **after** every save — so the shutter's completion path includes a possible whole-library resource scan.
* `watchInvalidation()` (`:43-48`) loops `for await _ in updates { await refresh() }` with **no debounce**, and PhotoKit fires `photoLibraryDidChange` for the app's *own* saves — the code comments acknowledge the redundancy (`:80-82`) and solve it with an extra refresh rather than with suppression.
* Failure semantics: if the JSON file is deleted, corrupt, or from another schema version, `loadIndex()` (`:836-853`) returns `.empty()` and the gallery shows **zero photos** while every photo is still in the user's library. `loadIndex`'s own comment calls this "the same false-negative bias" (`:847-849`) — the design choice is that the app under-reports rather than over-reports, i.e. the user loses their library view.
* `invalidationTask` (`:13,19`) is **write-only** — assigned, never read, never cancelled. Dead stored state.
* Limited-authorization handling adds `retain`/`prune` asymmetry in three separate places (`:503`, `:543`, `:746`) — three implementations of one policy rule.

**Why it matters.** A camera app's gallery is a *view* of Photos, not a second store. The index duplicates the only fact that matters (which asset is a pikicam capture) into a file the app can lose, in exchange for provenance that the DNG's own filename and EXIF already carry. Meanwhile the cost of the current design is a lock held across PhotoKit I/O on the shutter path.

**Fix direction.** Identify pikicam captures by the resource filename `pikicam-*.dng` on the asset itself (`PHAssetResource.assetResources(for:).contains { $0.originalFilename.hasPrefix("pikicam-") }`), which is already the naming scheme (`:852`) and needs no side file, no journal, no pending/stored states, no reconciliation, no pruning, and no in-flight registry. Store the develop-time metadata (aspect, zoom, capture timestamp) in a sidecar resource *on the same asset* (`PHAssetCreationRequest.addResource(with: .alternatePhoto, …)` is not appropriate — use a `fullSizeImage`/custom UTI or write it into the DNG's EXIF via `CGImageDestination` at save time) so provenance travels with the photo. Delete `CaptureIndex`, `IndexRecord`, `mutateIndex`, `mutateIndexIfChanged`, `pruneVanishedRecords`, `reconcilePendingRecords`, `inFlightSaveIDs`, and the static locks. Add debouncing/coalescing to the invalidation loop.

---

### P1-8 — No test seam; the suite only tests arithmetic

**Evidence**
* 36 unit tests total. `CameraControlTests.swift` (35) asserts only `ZoomMath`, `GridGeometry`, `AspectRatio`, `PrintCrop`, `ExposureCompensation`, `ZoomPresets`, `FlashMode`, `CameraPosition`, `SelfTimerOption`, `CaptureOrientation` — all pure value types.
* Zero tests for: `CameraViewModel`, `CaptureService`, `PhotoLibraryManager`, `PikicamLibraryModel`, `DevelopService`, `CIRAWZeroProcessor.develop` end-to-end, `PhotoCapture`, any view.
* Cause: `CameraViewModel.init(libraryModel:)` takes one dependency and hard-codes the other (`CameraViewModel.swift:36`); `PikicamLibraryModel.init` hard-codes `PhotoLibraryManager` and spawns tasks (`:8,15-22`); `DevelopService.init(processor:)` defaults and is never overridden.
* Tests that assert nothing meaningful:
  * `CameraControlTests.testFlashModeLabels` / `testAspectRatioLabels` / `testCameraPositionMapsToAVCapturePosition` assert UI strings — these break on every copy edit and catch no bug.
  * `PikicamPipelineTests.testZeroRecipeEnumeratesEveryEnhancementControl` (`:466`) asserts a hard-coded literal set equals a hard-coded literal set in the same file. It cannot detect a missing SDK property.
* Brittle/environment-dependent:
  * `testStorageSavesDNGSinglePhotoResourceToPhotos` **skipped** here ("No Photos write access in this environment"); it also depends on the test host's Photos authorisation and writes into a real library.
  * `testDeviceProbePhotosSaveResourceVariants` (`:281-375`) is a **diagnostic probe that creates six assets in the user's real photo library** (`PikicamProbe-*`), prints results, and deletes them by filename. A debugging tool shipped in the shipping test target, with `print()` as its output channel.
  * `testDevicePhotosLibraryContainsCapturedDNGSingleResource` (`:181-278`) carries a 25-line comment explaining that it is **not bound** to the UI test's capture and can pass on any stale asset — a test that documents its own unsoundness and is still committed.
* UI test quality (all currently unreachable, all read anyway): `SmokeLaunchTest.swift:124,530` query `app.buttons["camera-shutter"]` — **`ShutterButton` sets no accessibility identifier at all** (`Views/ShutterButton.swift:7-32`); `:217,627` query `"camera-library"` but the app uses `"gallery-thumbnail"` (`CameraView.swift:196`); `:303` queries `"viewer-hide-show"` vs the app's `"viewer-chrome-toggle"` (`GalleryView.swift:199`); `:220,447,633` query `app.navigationBars["LIBRARY"]` vs `.navigationTitle("Library")` (`GalleryView.swift:49`); `:227,454,463` wait for `"0 / NO CAPTURES"`, a string that **exists nowhere** in the app; `:233,248,472,491` use `"room-shoot"` vs the app's `"gallery-camera"` (`GalleryView.swift:45`). `:13-22` of the file's own header comment describes the intended identifier contract, which is `ControlIDRegistry`'s — a contract the app does not implement.
  * Consequence chain: `"LIBRARY"` never matches → `waitForExistence(10 s)` fails → `baselineCount` stays `nil` (`:216`) → `safeToCommitDelete = (nil == 0) == false` (`:409-411`) → the entire delete-commit half of the walkthrough is **permanently unreachable**. The suite is ~400 lines of untested prose.
  * `:778-786` `assertNoErrorShown` searches `staticTexts` for label prefix `"Error:"`. `CameraView` sets `.accessibilityLabel("Error: …")` on a `Text` (`CameraView.swift:212`), which SwiftUI surfaces as a label, not a static-text label — and the camera error `Text` is only rendered inside `if viewModel.isConfigured` (`:107`). The assertion is a no-op guard on a critical path.
  * Flakiness surface: `RunLoop.current.run(until:)` sleeps (`:104,127,242,265,279,320,424,…`), `app.tap()` blind taps (`:329,331`), `coordinate(...).tap()` fallbacks (`:665`), 120 s capture waits, `XCTAttachment` screenshots with `.keepAlways` — none of which belong in a suite that cannot run.

**Fix direction.** Introduce protocols at every seam (`CameraControlling`, `CaptureStoring`, `Developing`, `PreviewBinding`) injected at construction, then test the real state machines with synchronous fakes. Delete `testDeviceProbePhotosSaveResourceVariants` and `testDevicePhotosLibraryContainsCapturedDNGSingleResource`. Delete the label-assertion tests. Keep the 35 arithmetic tests (they are genuinely good and cheap) but move them next to their types. Rewrite the UI suite from scratch with a real identifier contract owned by app code, at most ~5 flows, no sleeps, and a documented manual device checklist for capture.

---

### P1-9 — `DevelopService` is rebuilt on every view update

**Evidence**
`pikicam/Features/Gallery/GalleryView.swift:150-154`:
```swift
/// … the actor owns a Metal-backed `CIContext`, which is too expensive to
/// rebuild for every DNG load.
@State private var developService = DevelopService()
```
and `pikicam/Features/Develop/DevelopService.swift:18-33` — `init` calls `MTLCreateSystemDefaultDevice()` and constructs a `CIContext`.

**Why it matters.** In SwiftUI, a `@State` property's default-value expression is evaluated every time the `View` struct is initialised — i.e. on every parent `body` evaluation — and is then **discarded** if a value already exists. `GalleryView`'s body re-runs whenever `library.captures`, `isLoading`, or `error` changes (all `@Observable`). So a Metal device lookup + `CIContext` allocation happens on every one of those transitions, and the comment states the exact opposite of what the code does. The correct forms are an injected `let` from the composition root, or `DevelopService` as a `shared` singleton, or a `@State` seeded via `init(_:)` from a parent-owned instance.

**Fix direction.** Create the develop service once in `PikicamApp.init` and pass it down (`@State private let developService: DevelopService` in `GalleryView`, initialised explicitly), or make it a single `static let shared`. Delete the misleading comment.

---

### P2-10 — Systemic noise, duplication, and naming

**Duplicated code**
* `CameraView.swift:309-333` (`ThumbnailImage`) and `GalleryView.swift:250-274` (`AsyncThumbnail`) are the same view — same `@State image`, same `Group`/`Rectangle` fallback, same `.task { try await library.loadThumbnail(...) }`, same `catch { image = nil }`. Two names, one thing.
* `PhotoLibraryManager.swift:604-663` (`loadOriginalDNG`) and `:665-744` (`requestThumbnail`) are structurally identical: `ContinuationBox` + `RequestIDBox` + `withTaskCancellationHandler` + `onCancel`. Extract one `awaitPhotoKit<T>(…)` helper.
* `CaptureService.swift:341-350` and `:390-399` are the same `lockForConfiguration` / `defer unlock` / wrap-in-`CaptureError.deviceLockFailed` block.

**Over-abstraction**
* `RAWProcessor` (`Features/Develop/RAWProcessor.swift:18`) — one implementation, injected through a defaulted parameter that is never overridden. Either delete the protocol or make `DevelopService` take a required `any RAWProcessor` and actually test a fake.
* `PhotoLibraryAuthorization` (`PhotoLibraryManager.swift:118-127`) mirrors `PHAuthorizationStatus` 1:1 and adds one derived property. The app already stores the framework type directly in `CameraViewModel` (`:42`) — two representations of one fact.
* `PhotoFailure` (`:133-148`) is a hand-rolled `NSError` wrapper; `Error.localizedDescription` plus a domain/code pair is already `Sendable` via `NSError`'s bridging in Swift 6. It exists mostly so the errors can be `Equatable` — a testing convenience pushed into production types.

**Under-abstraction / wrong home**
* `CameraControls.swift` (296 lines) holds eight unrelated types: `CameraPosition`, `FlashMode`, `ZoomMath`, `GridGeometry`, `AspectRatio`, `PrintCrop`, `ZoomPresets`, `ExposureCompensation`. `AspectRatio` is consumed by `Core/Storage` and `Features/Develop`; `PrintCrop` by `Features/Camera` and `Features/Develop`. One file, three layers.
* `Features/Camera/Views/ShutterButton.swift` is the only file in a `Views/` subdirectory (54 lines, 2 types).
* `CaptureOrientation` (defined in `Features/Develop/DevelopService.swift:89-104`) is a capture-provenance type consumed by `Core/Storage`.
* `CaptureError` is declared in `CaptureService.swift:700-762` (a 63-line `enum` + `==` + `errorDescription`) at the bottom of a service file rather than beside the other error types.

**Dead code (verified by `grep` across `pikicam/`)**

| Symbol | Location | Status |
|---|---|---|
| `AspectRatio.next()` | `CameraControls.swift:161-165` | only caller is `CameraControlTests.swift:145` |
| `PreviewView.layerPoint(for:)` | `CameraPreview.swift:69-71` | zero callers |
| `enum Room`, `EnvironmentValues.room`, `RoomKey` | `Room.swift:16,24-32` | zero app callers |
| `ControlID`, `ControlIDRegistry` (all 31 IDs) | `ControlIDRegistry.swift:8-180` | zero app callers |
| `ControlIDRegistry.cameraZoomPreset`, `.cameraAspect(_:)` | `:110,115` | zero callers anywhere |
| `PikicamCapture.pixelWidth` / `.pixelHeight` | `PhotoLibraryManager.swift:96,97` | app never reads; only `PikicamPipelineTests.swift:141-145` |
| `PikicamCapture.orientation` + `CapturedDNG.orientation` + the index field | `:100,16,909-915` | round-tripped only; `DevelopService.swift:88` explicitly documents that the develop pipeline does **not** consume it |
| `DNGDisplayRendition.ciImage` | `RAWProcessor.swift:32` | app uses only `.cgImage` (`GalleryView.swift:239`); tests use both |
| `PikicamLibraryModel.invalidationTask` | `:13,19` | write-only |
| `SelfTimerOption.label` "10s"/"3s" | `CameraViewModel.swift:352-356` | used only in a HUD caption with no unit affordance |
| `CaptureError.captureTimedOut` | `:723` | reachable only via `PhotoCapture`'s 15 s timer |

**Comment slop**
* 22.6 % of app lines and 21.0 % of test lines are comments (`grep -cE "^\s*(///|//|/\*|\*)"`). Much of it is **incident archaeology** rather than specification: `CaptureService.swift:413-418` ("verified in on-device crash logs"), `:672-679`, `PhotoCapture.swift:1-27` (27 lines of doc comment on a 155-line type), `DesignLintTests.swift:1-30` (a comment block transcribing a spec's §, "R3: the spec's intent is unambiguous, so this is transcription, not reconciliation"), `PikicamPipelineTests.swift:181-205` (25 lines explaining a test cannot be trusted).
* Directly contradicted by code, exactly the class of thing the repo's own rules call a defect: `GalleryView.swift:150-153` ("too expensive to rebuild") vs the `@State` behaviour (P1-9); `CaptureService.swift:433-436` vs `AVCapturePhotoOutput.h:85` (P0-3); `AGENTS.md:48-50` (scheme contents) vs the scheme.
* `.agents/skills/swift-coding-standards/SKILL.md` documents a repo that does not exist: it names `StorageServiceError` (lines 24, 50) — the real type is `PhotoLibraryError`; a repo map of `Core/{Extensions,Metal,Storage}` (line 47) — `Core/` contains only `Design/` and `Storage/`; and "the DNG/TIFF tag parser heritage is the reference shape" (line 33) — no such parser exists. It is the file an agent reads first, so it actively misleads.

**Naming**
* `PikicamLibraryModel` (`:7`) and `PikicamApp` — the `Pikicam` prefix is redundant inside a module already named `pikicam`; `GalleryModel` / `App` is idiomatic.
* `CIRAWZeroProcessor` — `CIRAW` duplicates `import CoreImage`; `ZeroProcessDeveloper` or `CIRAWDeveloper` reads better and matches `DevelopService`.
* `dngData:` parameter name on `RAWProcessor.develop` / `DevelopService.render` — Swift API guidelines say the label should read as a sentence at the call site (`develop(_ dng:)`).
* `ZoomMath.clamped(_:range:)` returning a value for NaN input, and `ExposureCompensation.init(stops:)` silently saturating NaN to 0 — correct behaviour, wrong shape. These are *parse* functions (per the repo's own rule 2) and should be `init?`/`init(thirds:)` with an explicit failable/throwing boundary, not silent saturation. The saturation is also only defended by tests (`CameraControlTests.swift:311-329`) rather than by types.

**Error handling**
* One `fatalError` in app code: `PreviewView.swift:23` — reachable only through a `layerClass` contract, so it is arguably fine, but a `precondition` + a `UIView` fallback is cheaper to reason about.
* `try?` swallow sites: `PhotoLibraryManager.swift:324` (pending-record cleanup — comment says "a secondary index failure is not reported"; that is a **deliberate** data-integrity hole), `CaptureService.swift:555,572,575` (documented best-effort restores), `CameraView.swift:98` (sleep), `PhotoCapture.swift:50` (sleep). Each is individually justified by a comment, which is itself the smell: five places where an error is intentionally destroyed, each needing prose to justify it.
* `CameraViewModel.error: Error?` → `error.localizedDescription` in the UI (`CameraView.swift:207-213`). No severity, no retry, no dismissal, no VoiceOver role, and it is never cleared except by the next successful shutter (`:247`).
* `PikicamLibraryModel.refresh()` (`:27-40`) sets `error = PhotoLibraryError.unknownFailure` for *any* unrecognised error (`:37-38`) — a catch-all that erases the real failure.

---

### P2-11 — Build configuration

* `project.yml:18-22` — `SWIFT_VERSION: "5.0"` with no `SWIFT_STRICT_CONCURRENCY`. The toolchain is Swift 6.3.3. This is the single highest-leverage line in the project.
* `project.yml:13-14` — `deploymentTarget: iOS: "26.5"`. A camera-RAW app pinned to a single point release of a brand-new OS, with a comment-free justification, has no users on any earlier device and no fallback path. Either lower it (and gate features with `#available`) or own the choice explicitly in the README.
* **Two Info.plist sources, with divergent user-facing strings.** `project.yml:29-30` sets `GENERATE_INFOPLIST_FILE: YES` and excludes `pikicam/Resources/Info.plist`; but `project.pbxproj:468` and `:558` both still set `INFOPLIST_FILE = pikicam/Resources/Info.plist`. The Debug product (verified from the built bundle) uses the *project.yml* strings; the Release product would use the *file's* strings — which are different text for the same three keys (`pikicam/Resources/Info.plist:5-11`). The file additionally carries `UIRequiredDeviceCapabilities: [arm64, still-camera]` and `UISupportedInterfaceOrientations~ipad`, none of which appear in the Debug bundle, and the iPad key is dead because `TARGETED_DEVICE_FAMILY = 1`.
* `TARGETED_DEVICE_FAMILY`: app `1`, tests `1,2` (`project.pbxproj:440,454,483`). A UI test run against an iPad destination would target a device family the app does not support.
* `project.yml:88-96` — `gatherCoverageData: false`. No coverage gate, no threshold, no baseline.
* `.swiftlint.yml:16-18` — `pikicamTests` **excluded entirely**; `:29-33` disables `identifier_name`, `type_name`, `trailing_whitespace`, `force_cast`; `:35` `warning_threshold: 0`; `:37` `reporter: "xcode"` (useless in a terminal/CI context). And `scripts/verify.sh` — the only thing that invoked SwiftLint — is deleted.
* No `DEVELOPMENT_TEAM`, no `CODE_SIGN_STYLE` in `project.yml`; Release only gets `CODE_SIGN_IDENTITY = "iPhone Developer"` (`project.pbxproj:466`). Nothing can archive from CI.
* `pikicam/Resources/PrivacyInfo.xcprivacy` declares three required-reason API categories — `NSPrivacyAccessedAPICategoryFileTimestamp` (`C617.1`), `…DiskSpace` (`E174.1`), `…SystemBootTime` (`35F9.1`) — with comments claiming "reading DNG file creation dates", "checking free space before saving photos", "timing camera session operations". **None of these APIs is called anywhere** (verified by grep: no `creationDate`, no `volumeAvailableCapacityKey`, no `systemUptime`/`mach_absolute_time` in `pikicam/`). A privacy manifest that asserts usage of APIs you do not use is a false declaration in the one file App Review reads most carefully.
* `.gitignore` covers `build/`, `.build/`, `DerivedData/`, `pikicamTests/Fixtures/*.DNG`. Both `build/` and `.build/` are nevertheless **present** in the working tree (a full `Release-iphoneos` signed `.app` with `embedded.mobileprovision` at `build/Release-iphoneos/pikicam.app/`). Not tracked, so harmless, but it means a local Release build already succeeded with the drifted `INFOPLIST_FILE`.

---

## Per-file verdict

### App
| File | Lines | Verdict | Reason |
|---|---:|---|---|
| `pikicam/App/PikicamApp.swift` | 27 | **rewrite** | Fine as a composition root, but it hard-codes both models and duplicates them into two `@State`s (`:12-19`); models must be injected so the develop/library services can be shared and faked. |
| `pikicam/App/RootView.swift` | 118 | **rewrite** | Three screens in one file; ad-hoc `didRequestPermissions` + `hasRequiredAuth` + `scenePhase` produce three sources of truth for permission state (`:12-24`). Collapse to one `AppState.phase: enum { onboarding, denied, camera }`. The `.onChange` double-start with `CameraView.task` (`CameraView.swift:59-62`) is a real race. Delete `:106-118` (`PermissionsDeniedView` duplicates `PermissionsView`). |

### Core
| File | Lines | Verdict | Reason |
|---|---:|---|---|
| `pikicam/Core/Design/Room.swift` | 32 | **delete** | Zero app references. |
| `pikicam/Core/Design/ControlIDRegistry.swift` | 180 | **rewrite (keep the idea)** | Zero app references and a name set that does not match the app or the UI tests. Replace with a 20-line `enum ControlID` in app code that views and UI tests both import. |
| `pikicam/Core/Storage/PhotoLibraryManager.swift` | 1015 | **rewrite** | 1 015 lines, 32 functions, one type. Deleting the JSON index (P1-7) removes ~300 lines and all the reconciliation state. Keep `CapturedDNG` (with the init validation), `PhotoLibraryError`, and the PhotoKit bridges. |

### Features/Camera
| File | Lines | Verdict | Reason |
|---|---:|---|---|
| `CameraViewModel.swift` | 386 | **rewrite** | God object; 20 published properties; three busy-state machines; mirrors actor state; untestable (P1-6). |
| `CaptureService.swift` | 768 | **rewrite** | Sensible actor + serial-queue skeleton, but `unownedExecutor` is then undone by `CaptureSessionBox` (`:686`), the Bayer-RAW config is wrong (P0-3), `stopSession` lacks the in-flight guard, and 60 % of the file is prose about past bugs. Keep the transactional camera-switch rollback (`:264-284`, `:296-317`) — that is genuinely well-reasoned. |
| `PhotoCapture.swift` | 155 | **rewrite** | 27 lines of doc comment on a 155-line type; hand-rolled ObjC association keyed on `self`; a 15 s timeout bolted on because nothing else can guarantee a resume. Delete and replace with a small `AVCapturePhotoOutput` async bridge in `CaptureService`, with the delegate held in an actor property rather than an associated object. |
| `CameraControls.swift` | 296 | **split, then keep** | `ZoomMath`, `GridGeometry`, `AspectRatio`, `PrintCrop`, `ExposureCompensation`, `ZoomPresets`, `CameraPosition`, `FlashMode` are all good, well-tested pure value types. Split one-per-file and move `AspectRatio` + `PrintCrop` to a shared location both `Core` and `Features` can depend on. |
| `CameraView.swift` | 493 | **rewrite** | One 200-line `controls` builder (`:102-215`), hand-tuned paddings, raw string identifiers, hard-coded 44 pt violations. See research 05 for the target UI; structurally it must become small `CameraChrome` subviews. |
| `CameraPreview.swift` | 72 | **keep + fix** | Good structure; fix the `Coordinator` isolation (`:52-58`) and delete the unused `layerPoint(for:)` (`:69`). |
| `PreviewView.swift` | 65 | **keep** | Minimal, correct `layerClass` wrapper. The `fatalError` (`:23`) is defensible; add a comment saying why. |
| `CameraHUDButton.swift` | 59 | **rewrite** | Takes `identifier: String` as a parameter (`:10`) — a design system that accepts an arbitrary string is not a design system. Delete the 22-line `#Preview` (`:32-59`). |
| `GridOverlayView.swift` | 72 | **rewrite** | 34 of 72 lines are `#Preview` scaffolding (`:45-72`) that does not match the current API. |
| `Views/ShutterButton.swift` | 54 | **rewrite** | The only file in a `Views/` directory. **Has no accessibility identifier at all** — the UI test's `app.buttons["camera-shutter"]` can never match. Move up one level. |
| `VolumeButtonCaptureView.swift` | 70 | **delete** | A hidden `MPVolumeView` that does not suppress the system HUD (its own comment, `:11-13`), fires on the *slider* rather than the button, and polls for a subview 10× with `DispatchQueue.main.asyncAfter`. For a pro camera this is a gimmick that changes system volume while taking photos. |
| `ZoomIndicatorView.swift` | 25 | **keep** | Small and correct; delete the `#Preview` (`:19-24`). |

### Features/Develop
| File | Lines | Verdict | Reason |
|---|---:|---|---|
| `RAWProcessor.swift` | 52 | **rewrite** | Protocol with one implementation + a defaulted injection that is never used; `DNGDisplayRendition.ciImage` unused by the app. |
| `DevelopService.swift` | 105 | **rewrite** | Correctly keeps `CIContext` off main; but `CaptureOrientation` (`:89-104`) is a capture-layer type in the wrong file and is unused by the pipeline it lives next to; `MTLCreateSystemDefaultDevice()` + `CIContext` are constructed per viewer (P1-9). |
| `CIRAWZeroProcessor.swift` | 127 | **rewrite (P0)** | The `responds(to:)` guard makes the whole recipe a no-op (P0-1). The recipe list must be replaced with direct assignments plus explicit decisions about `draftModeEnabled`, `scaleFactor`, and `orientation`. |

### Features/Gallery
| File | Lines | Verdict | Reason |
|---|---:|---|---|
| `GalleryView.swift` | 274 | **rewrite** | `GalleryView` + `FullScreenViewer` + `AsyncThumbnail` in one file; duplicated thumbnail (`:250-274` vs `CameraView.swift:309`); `@State developService = DevelopService()` (`:154`); hard-coded strings; navigation title `"Library"` contradicting the design's `"LIBRARY"`. |
| `PikicamLibraryModel.swift` | 90 | **rewrite** | Constructor spawns tasks (`:15-22`); `invalidationTask` is write-only; `@unchecked Sendable` is a redundant lie (`:7`); `refresh()` is on the shutter path; `catch → .unknownFailure` erases diagnostics (`:37-38`). |

### Tests
| File | Lines | Verdict | Reason |
|---|---:|---|---|
| `pikicamTests/CameraControlTests.swift` | 328 | **keep (trim)** | The best code in the repo. Delete the label-assertion tests (`:11-17`, `:31-34`, `:156-160`) — they test copy, not behaviour. Move alongside the types. |
| `pikicamTests/PikicamPipelineTests.swift` | 590 | **rewrite** | Delete `testDeviceProbePhotosSaveResourceVariants` (`:281-375`, writes 6 assets to the user's library) and `testDevicePhotosLibraryContainsCapturedDNGSingleResource` (`:181-278`, self-documented as unbound). `testZeroRecipeReachesEveryControlOnARealFilter` (`:514-590`) **crashes the host** and truncates the suite. `testZeroRecipeEnumeratesEveryEnhancementControl` (`:466-512`) compares a literal to a literal. |
| `pikicamTests/DesignLintTests.swift` | 918 | **delete** | P0-2. |
| `pikicamUITests/SmokeLaunchTest.swift` | 812 | **delete and rewrite** | Not in the scheme (P0-4); targets identifiers the app does not have; half the flow is unreachable; uses `RunLoop` sleeps and blind taps. |

### Config / scripts / docs
| Path | Verdict | Reason |
|---|---|---|
| `project.yml` | **rewrite** | `SWIFT_VERSION 5.0` → `6.0` + `SWIFT_STRICT_CONCURRENCY: complete`; drop the `INFOPLIST_FILE`/generated-plist ambiguity; decide the deployment target; set `DEVELOPMENT_TEAM`; enable coverage. |
| `pikicam.xcodeproj/**` | **regenerate, never hand-edit** | Contains hand-edited PBXBuildFile IDs (`NEW01BUILD`, `UITSPROD01` in the committed version) and a scheme that contradicts `project.yml`. Make the pbxproj **and** the scheme a CI-checked artifact. |
| `.github/workflows/design.yml` | **delete** | Red by design; runs no build and no unit tests; hard-codes a simulator that may not exist. |
| `scripts/verify-design.sh` | **delete** | Regenerates the project it is verifying. |
| `scripts/verify.sh` (deleted) | **either restore + wire, or delete** | `.pre-commit-config.yaml` still references it. |
| `.pre-commit-config.yaml` | **delete** | Points at a deleted script; hooks cannot run in CI anyway. |
| `.swiftlint.yml` / `.swift-format` | **delete** | Never enforced (SwiftLint not installed; `verify.sh` deleted). Two linters plus a regex lint is three half-tools. |
| `.agents/skills/swift-coding-standards/SKILL.md` | **rewrite or delete** | Describes a repo that does not exist (`StorageServiceError`, `Core/Extensions`, `Core/Metal`, a DNG/TIFF parser). |
| `AGENTS.md` (deleted) | **keep deleted** | Contained a false claim about the scheme. Do not restore without fixing. |
| `pikicam/Resources/Info.plist` | **delete** | Duplicates the generated plist with divergent strings; the iPad orientation key is dead. |
| `pikicam/Resources/PrivacyInfo.xcprivacy` | **rewrite** | Declares three required-reason APIs the app never calls. Declare only what is used (`UserDefaults` if introduced; nothing today). |
| `README.md` | **rewrite** | Currently advertises "zero-process" as a working feature (`:12-19`). It is not. |
| `docs/.P.DESIGN.md`, `docs/design/**`, `docs/prompt-next.md` | **delete** | 3 500+ lines of spec describing a UI and a token layer that do not exist. `docs/prompt-next.md` is the single most valuable artifact in the repo **as research** (its §0.1 correctly diagnosed P0-1) and worthless **as a spec**. Extract the verified findings into the implementation prompt; delete the rest. |

---

## Target architecture (proposed from scratch)

**Principles.** (1) The device's `AVFoundation`/`PhotoKit` types never leave their boundary file. (2) Every stateful service is an `actor` with injected protocol dependencies; every UI-facing model is `@MainActor @Observable` over an `AsyncStream` of events. (3) Pure geometry/format code is in a dependency-free `Core` and is the only thing that is exhaustively unit-tested. (4) Build in **Swift 6 language mode with complete strict concurrency** from the first commit. (5) No file over ~250 lines; one primary type per file.

```
pikicam/
  App/
    PikicamApp.swift                 @main, owns the object graph
    RootView.swift                   one `AppState.phase` switch — 4 cases, no booleans
  DesignSystem/                      real SwiftUI types the views consume
    Ink.swift        enum Ink { case primary, secondary, accent, fail; func color(in room: Room) -> Color }
    Type.swift       enum Type { case shutterWord, hudLabel, caption; var font: Font { Font.custom("CourierNew-Bold", size:relativeTo:) } }
    Space.swift      enum Space { case xs, s, m, l; var points: CGFloat }
    Motion.swift     enum Motion { static func spring(_:) -> Animation }
    ControlID.swift  enum ControlID: String — owned by app code, imported by views AND UI tests
    Room.swift       enum Room { case camera, library }  + `\.room` EnvironmentKey
    Chrome.swift     HStack/VStack of WordControl, so a control cannot be built ad hoc
  Capture/                           the ONLY place AVFoundation appears
    AVCaptureEngine.swift      protocol: start/stop/deviceState/supportedZoomRange
    AVCaptureEngineImpl.swift  actor + DispatchSerialQueue; owns AVCaptureSession
    BayerConfiguration.swift    pure: which rawPixelFormatType, which photoQualityPrioritization,
                                which scaleFactor — a value, table-driven, unit-testable
    PhotoRequester.swift        actor; the only AVCapturePhotoCaptureDelegate implementation;
                                delegate held in an actor property, never an associated object
    CaptureCoordinator.swift    actor; the ONE capture task, ONE cancellation token,
                                an AsyncStream<CaptureEvent> for the UI
    CameraControls.swift        CameraPosition, FlashMode, Zoom, EV — one per file, all pure
  Develop/
    DNGHeader.swift        pure TIFF/IFD parser: black level, WB, color matrix, black/white iso,
                           crop origin — the inputs a real pipeline needs (this is the
                           "parse don't validate" rule actually applied)
    DevelopPipeline.swift  protocol: `func develop(_ dng: DNGHeader, _ data: Data, params: DevelopParams) throws -> CIImage`
    CIRAWDevelop.swift     the CIRAWFilter fallback, every knob assigned unconditionally
    DevelopEngine.swift    actor; owns ONE long-lived CIContext; render-to-bitmap, resize,
                           color management (Display P3 in, sRGB/P3 out, explicit)
  Storage/
    CaptureRecord.swift    Codable value: captureID, assetID(localIdentifier), capturedAt,
                           aspect, zoom — the ONLY app-owned metadata, stored as a resource on
                           the asset (or in the DNG's EXIF). No side-index file.
    CaptureStore.swift     protocol: save/delete/records/thumbnail/original
    PhotoKitStore.swift    the ONLY place PhotoKit appears; actor; debounced invalidation stream
  Features/
    Camera/  CameraScreen, CameraChrome, ShutterControl, TopBar, FramingOverlay, Viewer
    Library/ LibraryScreen, ViewerScreen
```

**Four state enums that replace today's booleans and counters**

```swift
enum SessionState: Equatable, Sendable { case idle, starting, running, interrupted(InterruptionReason), failed(CaptureFailure) }
enum CapturePhase:  Equatable, Sendable { case idle, counting(remaining: Int), exposing, committing, failed(CaptureFailure) }
enum Framing:      Equatable, Sendable { case standard(AspectRatio), zoomed(factor: Double, aspect: AspectRatio) }
enum CaptureFailure: Error, Equatable, Sendable { case noCamera, noBayerFormat, sessionNotConfigured, deviceLocked(String), photosDenied(PhotoAccess), saveFailed(SaveCause), timedOut, cancelled }
```

**Test plan that is actually achievable**
* *Pure (exhaustive, no device):* `DNGHeader` parsing against the checked-in fixture DNG; `DevelopParams`; `PrintCrop`; `ZoomMath`; `EVCompensation`; `BayerConfiguration` table; `CaptureRecord` round-trip. — keep and extend the existing 35.
* *Fake-driven (no device):* `CaptureCoordinator` against a `FakeCaptureEngine` — asserts the phase machine, single-flight, cancellation, and that the zoom is restored on failure. `PhotoKitStore` against an in-memory `CaptureStore` — asserts save/delete/invalidation. `CameraScreen` reducer against a scripted event stream. **All of these are impossible today because there are no seams** (P1-8).
* *Device-only, manual checklist (documented, not CI):* press the shutter at 1× and at 5×; confirm one `.photo` DNG resource; confirm the Bayer rules at `AVCapturePhotoOutput.h:85`; confirm every `CIRAWFilter` knob reads neutral after the recipe; confirm Photos shows the original.
* *UI (≤ 5 flows, real identifiers, no sleeps):* launch → permission; tap-to-meter; capture; library shows the new capture; viewer renders.

---

## Open questions / assumptions

1. **Deployment target.** I assume 26.5 is a default nobody chose (nothing in `project.yml` justifies it). If the owner truly wants iOS 26.5+ only, that must be a stated product decision and `#available` gating is unnecessary. Everything else in this report is target-independent.
2. **Gallery = Photos, or gallery = own store?** P1-7 assumes the gallery is a *view* of Photos and the DNG original is the artifact. If the owner wants an in-app library with its own database, that is a different architecture and `PhotoLibraryManager`'s index becomes legitimate — but it must then be an actual database (SwiftData), not a JSON file under an `NSLock`.
3. **`CaptureOrientation` provenance.** I treated it as dead because `DevelopService.swift:88` documents that the pipeline ignores it. If the intent is to record how the phone was *held* (not the EXIF tag), it has no consumer today and should either be shown in the viewer or dropped.
4. **Zero shutter lag.** I flagged `AVCapturePhotoOutput.h:699` as UNVERIFIED in impact. Whether ZSL should be on is a product decision (honest capture timestamp vs shutter responsiveness) that research 01/02 should settle with a device measurement.
5. **`CIRAWFilter` on device.** `docs/prompt-next.md:52-58` correctly notes that only the *simulator* runtime has been enumerated. Whether a device `CIRAWFilterImpl` implements the declared `set<Name>:` selectors is UNVERIFIED and must be measured on hardware before any conclusion is drawn about which knobs are live.
6. **`AGENTS.md` / `SKILL.md` deletion.** I assume deleting `AGENTS.md` was intentional (it contained a false claim) and that `SKILL.md` should be rewritten to match reality rather than restored. If an agent harness depends on `SKILL.md` existing, rewrite it in one sitting; do not leave it stale.
7. **Volume-button capture.** I recommend deletion. If it is a product requirement, it needs a documented, honest implementation (there is no public API to suppress the system volume HUD) and an explicit statement that pressing volume changes the user's volume.
8. **Committing the working tree.** I made no changes. The eventual implementation will be replacing ~4 000 lines of app code, ~2 600 lines of test code, and ~3 500 lines of docs. The cleanest path is a single branch that deletes before it adds; the owner should expect the diff to be dominated by deletions.

---

## Sources

**Local SDK headers (authoritative; `/Applications/Xcode.app/.../iPhoneSimulator26.5.sdk`)**
- `System/Library/Frameworks/CoreImage.framework/Headers/CIRAWFilter.h` — full property set: `orientation` (:52), `draftModeEnabled` (:55), `decoderVersion` (:58), `scaleFactor` (:63), `exposure` (:66), `baselineExposure` (:69), `shadowBias` (:72), `boostAmount` (:75, "A value of 0 indicates no global tone curve… default value is 1"), `boostShadowAmount` (:78, "no effect if the boostAmount is 0… default is 1"), `highlightRecoveryEnabled` (:88, `NS_AVAILABLE(16_0,19_0)`), `gamutMappingEnabled` (:92, "default value is true"), `lensCorrectionEnabled` (:98), the six `…Supported` capability probes (:87,:97,:105,:113,:121,:129,:137,:145,:153), `extendedDynamicRangeAmount` (:161), neutrals (:168-171), `linearSpaceFilter` (:174), `previewImage` (:177), semantic-segmentation mattes (:179-183).
- `System/Library/Frameworks/AVFoundation.framework/Headers/AVCapturePhotoOutput.h`
  - :71-119 — the full validation rule list; **:83-86 Bayer RAW rules** (`photoQualityPrioritization must be set to AVCapturePhotoQualityPrioritizationSpeed`; `videoZoomFactor` **and** `videoScaleAndCropFactor` must both be 1.0; don't change zoom during RAW capture); :80 delegate must respond to `didFinishProcessingRawPhotoSampleBuffer:…`; :117-118 "If any of these rules is violated, an `NSInvalidArgumentException` is thrown."
  - :981-984 — "All callbacks are marked optional, but … some callbacks become mandatory … If your delegate does not implement the mandatory callbacks, an `NSInvalidArgumentException` is thrown." and the RAW case is satisfied by `didFinishProcessingPhoto:error:`.
  - :190-202 — `isAppleProRAWSupported` / `isAppleProRAWEnabled` ("Enabling this property requires a lengthy reconfiguration of the capture render pipeline, so you should set this property to YES before calling `-[AVCaptureSession startRunning]`").
  - :324-334 — `AVCapturePhotoQualityPrioritization` raw values: Speed = 1, Balanced = 2, Quality = 3.
  - :344 — `maxPhotoQualityPrioritization` default is `.balanced`.
  - :699 — `zeroShutterLagEnabled`: "For apps linked on or after iOS 17 zero shutter lag is automatically enabled when supported… isn't available when using manual exposure."
  - :755 — `captureReadiness` / `AVCapturePhotoOutputReadinessCoordinator` (the correct way to drive shutter enablement from a background queue).
  - :1237-1239 — `+photoSettingsWithRawPixelFormatType:` "specifying RAW only output".
- `System/Library/Frameworks/AVFoundation.framework/Headers/AVCaptureSession.h` — :484-497 `beginConfiguration`/`commitConfiguration` pairing rules; :66-72 interruption notifications and `AVCaptureSessionInterruptionReasonVideoDeviceNotAvailableInBackground`.

**External**
- <https://www.avanderlee.com/concurrency/default-actor-isolation-in-swift-6-2/> — Swift 6.2 default MainActor isolation (`nonisolated` on a type declaration only has meaning with it).
- <https://www.donnywals.com/setting-default-actor-isolation-in-xcode-26/> — same, from the Swift compiler team.
- <https://stackoverflow.com/questions/79930456/swift-concurrency-swift-default-actor-isolation> — "If the `SWIFT_DEFAULT_ACTOR_ISOLATION` is set to `MainActor`, then `struct TokenResponse` will be main actor isolated. Otherwise, the struct will be nonisolated."
- <https://developer.apple.com/documentation/xcode/build-settings-reference> — authoritative list of `SWIFT_*` build settings (neither `SWIFT_STRICT_CONCURRENCY` nor `SWIFT_DEFAULT_ACTOR_ISOLATION` is set in this project).

**Local build/test evidence**
- `/tmp/pikicam-build-r4b.log` — full `xcodebuild … build test` (BUILD SUCCEEDED / TEST FAILED; 777→63 design violations; `-[CIRAWFilterImpl baselineExposure]: unrecognized selector` crash; "Restarting after unexpected exit, crash, or test timeout; summary will include totals from previous launches"; "Executed 0 tests").
- `/tmp/pikicam-swift6.log` — `SWIFT_VERSION=6.0` build failure at `PhotoLibraryManager.swift:829`.
- `/tmp/pikicam-strict.log` — `SWIFT_STRICT_CONCURRENCY=complete` build succeeded with 5 errors-as-warnings (see P1-5 table).
- `xcrun simctl list devices available` — iOS 26.5 runtimes; `iPhone 17 Pro` booted. `xcodebuild -version` → Xcode 26.6 (17F113); `swift --version` → 6.3.3.
- `xcodegen` is **not installed** on this machine, so the scheme/pbxproj drift was established by reading both files, not by regenerating.

**Repo artifacts read**
`project.yml`; `pikicam.xcodeproj/project.pbxproj`; `pikicam.xcodeproj/xcshareddata/xcschemes/pikicam.xcscheme`; `.github/workflows/design.yml`; `scripts/verify-design.sh`; `git show HEAD:scripts/verify.sh`; `.pre-commit-config.yaml`; `.swiftlint.yml`; `.swift-format`; `.gitignore`; `git show HEAD:AGENTS.md`; `.agents/skills/swift-coding-standards/SKILL.md`; `README.md`; `docs/.PDESIGN.md` (head); `docs/prompt-next.md` (head, incl. §0.1's device/simulator `CIRAWFilterImpl` selector enumeration, which this report independently confirms from the build log); `docs/workflow/briefs/*`; `docs/workflow/logs/r4.log`, `r5.log`; `pikicam/Resources/Info.plist`; `pikicam/Resources/PrivacyInfo.xcprivacy`; the built Debug product's `Info.plist` at `/tmp/pikicam-dd-r4/Build/Products/Debug-iphonesimulator/pikicam.app/Info.plist`.