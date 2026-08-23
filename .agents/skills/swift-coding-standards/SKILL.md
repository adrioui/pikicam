---
name: swift-coding-standards
description: Pikicam's Swift coding standards and decision priority for agent work in this repo — decision-priority order, parse-don't-validate, typed errors at engine boundaries, MainActor UI / off-main engine rule, inspect-before-adding, and the boundary clause for legacy patterns. Apply when writing, reviewing, or refactoring Swift in pikicam.
---

# Pikicam Swift Coding Standards

Standards for agent work in the pikicam codebase (SwiftUI camera app, RAW/DNG capture
and develop pipeline). Read this before writing or reviewing Swift here. The rules are
ordered by priority: when rules conflict, the lower-numbered rule wins.

## Decision priority order

1. **Keep the app shipping and the pipeline honest.** Pikicam is a camera app: capture
   and develop paths must degrade with explicit, typed errors — never crash, never
   silently swallow a failed decode. A simulator build must build; sensor-dependent
   behavior is encoded in tests as an expectation (no Bayer sensor → clean typed
   error), never mocked into pretending it exists.
2. **Parse, don't validate.** Convert raw bytes / unstructured data into typed values
   at the boundary as early as possible. Once data is typed, Swift's type system does
   the validation for free. Raw byte pokes scattered through feature code are a defect.
3. **Typed errors at engine boundaries.** Decode/capture/storage failures are typed
   enums conforming to `LocalizedError` (and `Equatable` where tests compare them), e.g.
   `CaptureError`, `StorageServiceError`. Match on them in tests. Bare `throw`s of
   `Error`/`String`, `fatalError`, and force-unwraps in the pipeline are defects.
4. **UI on the main actor; engines off the main thread.** SwiftUI/`@Observable` UI
   state stays on the main thread. Metal, RAW decode, and Core Image heavy work run
   off-main; never render from the develop pipeline to the screen.
5. **Inspect before you add.** Before introducing a new type, helper, or abstraction,
   check the repo map for an existing one that already does it (camera services in
   `Features/Camera/`, develop services in `Features/Develop/`, typed parsers in
   `Core/`, storage in `Core/Storage/PhotoLibraryManager.swift`). Reuse or extend before
   adding; if you add, place it next to its domain, not in a grab-bag.
6. **Minimal diffs, honest commits.** The tree is intentionally dirty WIP; stage only
   what the current task touches. Never mass `git add -A`. Tests run via
   `xcodebuild ... test` on the simulator; never claim "tests pass" without quoting the
   result.

## Parse, don't validate

- Unstructured input (DNG/TIFF bytes, `AVCaptureDevice` formats, `PHAsset` resources)
  is parsed into typed values as close to the boundary as the platform allows.
- Typed parsers live in `Core/` (the DNG/TIFF tag parser heritage is the reference
  shape: parse header/endianness/fields into typed structs, reject malformed input
  with typed errors — no crash, no raw `Data` pokes in feature code).
- Once parsed, features consume typed values; the type system enforces invariants.

## Errors at engine boundaries

- `CaptureError` (Features/Camera/CaptureService.swift), `StorageServiceError`
  (Core/Storage/PhotoLibraryManager.swift), and the develop pipeline's typed errors
  are the contract. New failure modes extend these enums; they do not introduce bare
  `throw Error` paths.
- Tests match on the enum case (`XCTAssertEqual(error, .noBayerFormatAvailable)`),
  so adding a case is a visible, test-covered change.

## MainActor UI / off-main engines

- SwiftUI views and `@Observable`/view-model state: main thread (Swift 5 mode; no
  strict concurrency by default — keep the discipline manually).
- Metal resources, RAW decode, and CI rendering: off-main. The developing pipeline
  never renders to the screen.

## Inspect-before-adding

- Repo map: `pikicam/App/`, `pikicam/Core/{Extensions,Metal,Storage}/`,
  `pikicam/Features/Camera/`, `pikicam/Features/Develop/`, `pikicamTests/`.
- Before adding a file, confirm nothing existing covers it; before adding a
  dependency, confirm the stdlib/CoreImage/AVFoundation already doesn't.
- Tests live in `pikicamTests/` (fixture in `Fixtures/`, git-ignored; tests `XCTSkip`
  when it is absent).

## Boundary clause: existing legacy patterns

- Legacy patterns that predate these standards (staged pipeline removals, historical
  extension files, any ad-hoc `Data` handling) are **contained at the boundary**: they
  are acknowledged, isolated, and not spread into new code. Do not "fix" them
  wholesale outside the current task; do not extend them. New code follows the
  standards above.

## How an agent uses this skill

1. Read this file first when touching Swift in pikicam.
2. Before a change: locate the owning domain via the repo map (rule 5).
3. During review: check rules 1–4 for each touched path (typed errors, typed parse,
   threading, no new crash paths).
4. Before claiming done: run `xcodebuild -project pikicam.xcodeproj -scheme pikicam
   -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test` and quote the result.
