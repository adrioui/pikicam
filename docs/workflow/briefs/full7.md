CONTEXT
Repo: /Users/adrifadilah/Desktop/pikicam (iOS camera app, Swift, XcodeGen via project.yml).
Product goal: camera -> our own code -> bypass the iPhone's post-processing. Capture the least-processed sensor data iOS exposes (Bayer RAW / DNG; avoid Apple's computational pipeline: Deep Fusion, Smart HDR, Photonic Engine, sharpening, noise reduction, local tone mapping, semantic rendering), then develop it with our own code, behind a clean, excellent camera UI/UX.
The owner says the current implementation is poor: a lot of slop code and disgusting UI/UX. Your research feeds a single implementation prompt that will be used to fix everything, so be exhaustive, concrete, and cite evidence (file:line for code, URLs for external sources).

RULES
- This is a RESEARCH task. Do NOT modify, create, or delete any file except your own output file. Do not revert, stash, or discard the uncommitted working tree.
- Run fully autonomously. No human is available. Never stop to ask questions; make reasonable calls and record them as assumptions.
- Read every relevant file completely; do not skim. Prefer reading over guessing. Verify claims.
- For external facts (Apple APIs, behaviors, OS versions), use any web/search tool you have; if none, use curl against developer.apple.com docs, Apple sample code, WWDC session pages, and reputable sources. Mark anything unverified as UNVERIFIED.
- Output: a single Markdown file at the path given below. Structure: Summary (top 10 findings), Detailed findings (each with severity P0/P1/P2, evidence, why it matters, recommended fix direction), Open questions/assumptions, Sources.
TASK: Adversarial review of an implementation prompt. Do NOT edit the prompt or any repo file except your output file.

Read docs/workflow/PROMPT.md in full, then docs/workflow/research/01..06 (06 is the measured adjudication and wins on conflicts). Verify every concrete technical claim in PROMPT.md against: the research files, the iOS 26.5 SDK headers ($(xcrun --sdk iphoneos --show-sdk-path)/System/Library/Frameworks/{AVFoundation,CoreImage,Photos,PhotosUI,SwiftUI,UniformTypeIdentifiers}.framework), and quick compile checks (`xcrun --sdk iphonesimulator swiftc -target arm64-apple-ios26.5-simulator -typecheck` on tiny probe files under /tmp/pikicam-review/, never in the repo).

Check especially:
1. Every API/property/method name and signature the prompt uses exists on iOS 26.5 with that spelling (e.g. isZeroShutterLagEnabled/Supported, isResponsiveCaptureEnabled, isFastCapturePrioritizationEnabled, AVCapturePhotoOutputReadinessCoordinator, AVCaptureDevice.RotationCoordinator + its property names, centerStageControlMode/isCenterStageEnabled as class properties, isGeometricDistortionCorrectionEnabled, automaticallyAdjustsVideoHDREnabled, automaticallyConfiguresCaptureDeviceForWideColor, activeColorSpace .P3_D65, setPreparedPhotoSettingsArray, deviceWhiteBalanceGains(for:), setFocusModeLocked(lensPosition:), CIRAWFilter properties incl. isDraftModeEnabled / extendedDynamicRangeAmount / supportedDecoderVersions, CIContext.heif10Representation, CIContextOption memory target name, CIColorKernel(functionName:fromMetalLibraryData:), PHAssetResourceType.fullSizePhoto/.adjustmentData/.alternatePhoto, PHAssetCreationRequest adding .adjustmentData at creation, PHAssetChangeRequest.revertAssetContentToOriginal, PHAssetResourceManager.writeData, onCameraCaptureEvent, UTType(importedAs:), Synchronization.Mutex availability, SWIFT build setting names, MTL CI kernel flags).
2. Internal contradictions between sections (e.g. §4 vs §6 vs §7 vs §8 vs §10; type names; error cases; file layout vs references; DoD vs tests).
3. Claims that contradict research 06 or the SDK.
4. Feasibility traps for a headless implementer on this machine (simulator has no camera; xcodegen not installed; Photos permission on simulator; Swift 6 typed throws limitations with closures/generics; Sendable issues with AVFoundation/CoreImage/PhotoKit types; whether `Dependencies.fake` UI tests can show a preview; etc.).
5. Anything missing that the research found but the prompt does not address.

Output a list of findings, each: severity (BLOCKER/MAJOR/MINOR), the prompt section/line, what is wrong, evidence (header line / compile result / research section), and the exact suggested replacement text. Also list claims you verified as correct (brief).
Write output to: docs/workflow/research/07-prompt-review.md
