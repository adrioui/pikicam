# AGENTS.md — pikicam

Native iOS camera app: RAW (DNG) capture + develop pipeline. SwiftUI front end, Metal
GPU pipeline (debayer / LUT / grain), LibRaw + CoreImage RAW decoders, Photos-library
persistence. Single Xcode project, XCTest suite.

## Commands

Build (simulator; iPhone 17 Pro is currently booted):

```sh
xcodebuild -project pikicam.xcodeproj -scheme pikicam \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Run the test suite:

```sh
xcodebuild -project pikicam.xcodeproj -scheme pikicam \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Notes on output: `xcbeautify`, `SwiftLint`, `SwiftFormat`, and `xcodegen` are **not**
installed on this machine. Pipe builds through `xcbeautify` only if it is installed;
otherwise parse the raw output. There is no `verify.sh` yet — do not invent one at
runtime; ask the user if a verify step is needed.

Never claim "tests pass" without running the test action in the paragraph above and
quoting the result.

## Repo map

- `pikicam/App/` — SwiftUI entry points (`PikicamApp.swift`, `RootView.swift`).
- `pikicam/Core/Metal/` — `MetalPipelineRunner.swift` + `shaders/*.metal` (debayer,
  grain, LUT).
- `pikicam/Core/Extensions/` — `DNGTagParser.swift`, `DNG+Raw.swift`,
  `CIImage+Raw.swift`, `AVCaptureDevice+Raw.swift`.
- `pikicam/Core/Storage/` — `PhotoLibraryManager.swift`, `AdjustmentStore.swift`.
- `pikicam/Features/Camera/` — `CaptureService.swift`, `PhotoCapture.swift`,
  `CameraPreview.swift`, `CameraView.swift`, `PreviewView.swift`, `Views/` (shutter,
  exposure, WB, format, grid, histogram).
- `pikicam/Features/Develop/` — the RAW develop pipeline: `RAWDecoder.swift`,
  `LibRawProcessor.swift`, `CIRAWZeroProcessor.swift`, `DevelopService.swift`,
  `PipelineManager.swift`, `MetalDebayer.swift`, `LUTLoader.swift`, `RAWProcessor.swift`,
  `DemosaicAlgorithm.swift`.
- `pikicam/Features/DualCamera|Gallery|Review|Settings/` — were removed from the
  working tree (staged deletions pending); do not resurrect them unless asked.
- `pikicamTests/` — XCTest suite: `PikicamPipelineTests.swift` (capture/develop/
  storage behavior), `StorageProbeTests.swift` (diagnostic probes that print
  `PROBE_*` diagnostics). DNG fixture: `pikicamTests/Fixtures/IMG_1361.DNG`
  (large, untracked; tests `XCTSkip` when it is absent).

## Conventions

- **Swift 5 mode** (`SWIFT_VERSION = 5.0`): no strict concurrency by default. Keep
  UI work on the main thread/actor; run Metal and RAW decode off-main.
- **Error handling at boundaries**: decode/capture failures use typed enums
  (`CaptureError`, etc.), not bare throws or string errors. Match on them in tests.
- **Parse, don't validate**: parse DNG/TIFF structures into typed values via
  `DNGTagParser`/`DNG+Raw`; do not sprinkle raw byte pokes.
- **Photos persistence** goes through `PhotoLibraryManager`; sensor-dependent
  behavior can't be exercised on a simulator (no Bayer sensor) — tests encode that
  reality instead of mocking it.
- **Metal** resources stay off the main thread; never render to the screen from the
  develop pipeline.

## Repository state (2026-07/08)

- Working tree is intentionally **dirty**: large staged-but-uncommitted WIP vs the
  single commit. Do not mass-`git add -A` or commit unrelated files; stage only what
  the current task touches.
- No CI, no lint/format config, no license file.
- Bundle id `piki.pikicam`, iOS deployment target 26.5, shared scheme `pikicam`
  (includes the `pikpTests` test action).