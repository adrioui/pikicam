# pikicam

A native iOS camera app for honest photographs: one Bayer RAW (DNG) exposure
per shot, developed with every computational-photography enhancement
explicitly disabled — no AI, no Smart HDR, no sharpening, no hidden print.

SwiftUI front end. Core Image RAW decoding via `CIRAWFilter`. Photos-library
persistence with a provenance index. Single Xcode project, XCTest suite.

## The zero-process pipeline

- **Capture** — pure Bayer RAW selection (no ProRAW), full sensor, exactly one
  `.photo` DNG resource saved per shot. No processed JPEG is produced or
  retained.
- **Develop** — `CIRAWFilter` with boost, shadow recovery, local tone mapping,
  noise reduction, sharpening, contrast, lens correction, and gamut mapping all
  set to their neutral/disabled values. Missing controls are treated as already
  absent, never as errors.
- **Preview vs. record** — framing aids (photo/square aperture, zoom) are
  viewfinder concerns only. The recorded DNG is always the unchanged
  full-sensor original.

## Features

- Live full-screen camera preview with rule-of-thirds grid
- Pinch zoom (1×–max) with generation-safe state
- Exposure compensation ±3 EV in 1/3-stop steps, applied atomically with the
  next capture
- Flash as a continuous torch (off / on / auto)
- Self-timer (3s / 10s), tap to cancel
- Front/back camera switching with transactional rollback
- Volume-button shutter
- Gallery with DNG-only indexing, thumbnails, full-screen zero-process DNG
  viewer, and delete
- Crash-safe persistence journaling (`pending` → `stored`) and reconciliation
- Limited Photos authorization support

## Requirements

- Xcode 26+ (project uses iOS 26.5 SDK)
- iOS 26.5+ device or simulator
- A physical iPhone for capture — the simulator has no Bayer sensor and is
  used for build/unit/UI smoke tests only

## Getting started

```sh
git clone https://github.com/adrioui/pikicam.git
cd pikicam
open pikicam.xcodeproj
```

Select the `pikicam` scheme and run on your iPhone. Grant camera and photo
library access on first launch.

## Commands

Verify chain (swift-format lint → SwiftLint if installed → simulator build):

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

Run the device walkthrough (physical iPhone with the app installed):

```sh
xcodebuild -project pikicam.xcodeproj -scheme pikicam \
  -destination 'platform=iOS,id=<DEVICE_UDID>' \
  -only-testing:pikicamUITests/SmokeLaunchTest/testDeviceCaptureWalkthrough test
```

The shared scheme's test action runs `pikicamTests` and `pikicamUITests`.
The device capture walkthrough is skipped on the simulator; the simulator
launch smoke test is skipped on a device.

> [!NOTE]
> The `pikicamTests/Fixtures/IMG_1361.DNG` fixture is large and intentionally
> untracked. Tests that need it skip when it is absent, so a fresh clone still
> runs.

## How it works

- `pikicam/Features/Camera/` — session, preview, capture, controls, HUD.
- `pikicam/Features/Develop/` — `CIRAWFilter` zero-process develop pipeline.
- `pikicam/Core/Storage/` — `PhotoLibraryManager`, the sole PhotoKit boundary.
- `pikicam/Features/Gallery/` — library grid, DNG viewer, thumbnails.
- `pikicamTests/` and `pikicamUITests/` — XCTest suites.

DNGs are written as a single `.photo` resource with a namespaced
`pikicam-<uuid>.dng` filename. A private versioned index in Application
Support records capture provenance and reconciles saves, deletions, and
limited-authorization visibility changes. No image bytes, `PHAsset` objects,
or JPEGs enter the index.

## Conventions

- Swift 5 mode; UI on the main actor, RAW decoding/development off-main.
- Typed errors at engine boundaries (`CaptureError`, `DevelopError`,
  `PhotoLibraryError`).
- No custom DNG/TIFF byte parsing — tags are consumed through Core Image.
- Working tree discipline: stage only what the current task touches.

## Project structure

```
pikicam.xcodeproj   Xcode project
project.yml         XcodeGen model (regeneration requires xcodegen)
pikicam/            App, Core, Features
pikicamTests/       Unit tests (+ large untracked DNG fixture)
pikicamUITests/     UI tests (simulator smoke + device walkthrough)
scripts/verify.sh   Lint + build verification chain
docs/               Project notes
```
