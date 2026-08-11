# AGENTS.md — pikicam

Native iOS camera app: single-exposure RAW (DNG) capture + "zero-process" develop
pipeline. SwiftUI front end, CoreImage RAW decoding (`CIRAWFilter` with every
enhancement explicitly disabled — no custom shaders, no LibRaw), Photos-library
persistence. Single Xcode project, XCTest suite.

## Commands

Verify chain (swift-format lint → SwiftLint (if installed) → xcodebuild build):

```sh
./scripts/verify.sh
```

Build (simulator; iPhone 17 Pro):

```sh
xcodebuild -project pikicam.xcodeproj -scheme pikicam \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Run the test suite:

```sh
xcodebuild -project pikicam.xcodeproj -scheme pikicam \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

The shared scheme's test action runs `pikicamTests` and `pikicamUITests`;
`SmokeLaunchTest` self-skips per environment (launch smoke check targets the
simulator, the capture walkthrough targets a physical device).

Tool availability on this machine: `xcrun swift-format` (Xcode toolchain) is
**installed**; `SwiftLint`, `xcbeautify`, and `xcodegen` are **not**. `verify.sh`
SKIPs missing tools with install hints (use `--force` to make them FAIL); parse raw
xcodebuild output when `xcbeautify` is absent. There is no CI.

Never claim "tests pass" without running the test action in the paragraph above and
quoting the result.

## Repo map

- `pikicam/App/` — SwiftUI entry points (`PikicamApp.swift`, `RootView.swift`).
- `pikicam/Core/Storage/` — `PhotoLibraryManager.swift` (Photos persistence;
  simulator rejects RAW companions with `PHPhotosErrorChangeNotSupported`).
- `pikicam/Features/Camera/` — `CaptureService.swift` (pure Bayer RAW format
  selection, not ProRAW), `PhotoCapture.swift`, `CameraPreview.swift` (live preview
  pipeline), `CameraViewModel.swift`, `CameraView.swift`, `PreviewView.swift`,
  `Views/ShutterButton.swift`.
- `pikicam/Features/Develop/` — the RAW develop pipeline: `RAWProcessor.swift`
  (`CaptureMode` zero/standard/rawOnly + `DevelopError`), `CIRAWZeroProcessor.swift`
  (CoreImage zero-process recipe), `DevelopService.swift` (Metal-backed `CIContext`
  rendering, JPEG encoding). A future custom Metal pipeline is slated but **does not
  exist yet** — do not reference `MetalPipelineRunner`/`shaders/` as if they do.
- `pikicam/Features/DualCamera|Gallery|Review|Settings/` — removed and committed;
  do not resurrect them unless asked.
- `pikicamTests/` — XCTest suite: `PikicamPipelineTests.swift` (capture/develop/
  storage behavior; currently 5 tests, incl. device-only Photos probes).
  DNG fixture: `pikicamTests/Fixtures/IMG_1361.DNG` (large, untracked; tests
  `XCTSkip` when it is absent).
- `pikicamUITests/` — `SmokeLaunchTest.swift`: simulator launch smoke check (typed
  camera-unavailable message) and physical-device capture→save walkthrough with
  screenshots.
- `scripts/verify.sh` — the verify chain defined above; `scripts/verify_coverage.sh`
  — coverage-gap report (a feature needs a dedicated test file or a runtime ref in
  `pikicamTests/`/`pikicamUITests/`; `--fail-on-gap` exits 1 on gaps); `.swiftlint.yml` +
  `.swift-format` are the lint/format configs; `project.yml` is the xcodegen model
  (regeneration requires a machine with xcodegen; the checked-in pbxproj is
  hand-maintained and must stay in sync).

## Conventions

- **Swift 5 mode** (`SWIFT_VERSION = 5.0`): no strict concurrency by default. Keep
  UI work on the main thread/actor; run RAW decoding/development off-main
  (`CIRAWZeroProcessor` is `nonisolated`; `DevelopService`'s CIContext is
  Metal-backed — never touch it from the main thread).
- **Error handling at boundaries**: capture/develop/storage failures use typed
  enums (`CaptureError`, `DevelopError`, `StorageServiceError`,
  `CameraViewModelError`), not bare throws or string errors. Match on them in
  tests.
- **No custom DNG/TIFF byte parsing**: legacy `DNGTagParser`/`DNG+Raw` were
  removed with the old pipeline. DNG tags are consumed via CoreImage
  (`CIRAWFilter` reads black level, color matrix, AsShotNeutral). Do not re-introduce
  raw byte pokes.
- **Photos persistence** goes through `PhotoLibraryManager`; sensor-dependent
  behavior can't be exercised on a simulator (no Bayer sensor, Photos rejects RAW
  companions) — tests encode that reality instead of mocking it.
- **Zero-process honesty**: `CaptureMode.zero` must keep every enhancement knob
  explicitly disabled; do not silently add exposure/nr/sharpening.

## Repository state (2026-08)

- Working tree is **clean**: 7 commits on `main` (initial + 6 setup/docs/device
  commits: AGENTS.md, lint/format + verify chain, xcodegen model, test target +
  legacy-pipeline removal, swift-coding-standards skill, device walkthrough test +
  iOS 26.6 findings). Do not mass-`git add -A` or commit unrelated files; stage
  only what the current task touches.
- No CI, no license file. SwiftLint not installed (verify.sh degrades to SKIP).
- Bundle id `piki.pikicam` (tests `piki.pikicamTests` + `piki.pikicamUITests`),
  iOS deployment target 26.5, shared scheme `pikicam` (test action runs both test
  targets; UI tests self-skip per environment).