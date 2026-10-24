# 07 — Adversarial review of `docs/workflow/PROMPT.md`

**Reviewed:** `/Users/adrifadilah/Desktop/pikicam/docs/workflow/PROMPT.md` (975 lines, 97,408 B), in full.
**Against:** `docs/workflow/research/01`–`06` (06 wins on conflicts), the shipping `iPhoneOS26.5.sdk`
headers, and ~35 compile probes run with
`xcrun --sdk iphonesimulator swiftc -target arm64-apple-ios26.5-simulator -typecheck [-swift-version 6 -warnings-as-errors]`
on throwaway files under `/tmp/pikicam-review/`. **No repo file other than this one was read-modified-written;
the working tree, including the uncommitted rebuild, was left untouched.**
**Toolchain observed:** Xcode 26.6 (17F113), Swift 6.3.3, SDK `iPhoneOS26.5.sdk` / `iPhoneSimulator26.5.sdk`,
host macOS 26.5, `iPhone 17 Pro` (iOS 26.5) booted, **`xcodegen` NOT installed**, Homebrew 7.0.7 present.
**Repro commands for every claim below are in §Sources.**

**Verdict:** the prompt's *technical spine* is correct and unusually well-sourced — the initializer bug,
the `photoQualityPrioritization` correction, the ZSL/GDC/Center-Stage fixes, the `linearSpaceFilter`
measurement and the `render(_:toBitmap:)` trap are all right and match research 06. **But the prompt's
own executable code, its own design-system values, and its own test list are internally inconsistent**, and
four of its §6.10 exemplar snippets **do not type-check on this toolchain**. A headless implementer
following the prompt literally will fail in Phase 1–3 and will not know the failures are the prompt's.

---

## Summary — top 10 findings

| # | Sev | Finding |
|---|-----|---------|
| 1 | **BLOCKER** | §6.10 rule 1's exemplar flow **does not compile**. `try await mapError(CameraError.init(mapping:)) { … }` needs a wrapper that §6.8 never defines with an *untyped* closure parameter; `retrying(…, isTransient: \.isTransient)` fails ("value of type `any Error` has no member `isTransient`"); nesting `traced { retrying { … } }` fails ("invalid conversion of thrown error type `any Error` to `LibraryError`"); and the function is declared `-> ` with no return type yet does `return item`. (§6.10, lines 726–739) |
| 2 | **BLOCKER** | §5.1's colour tokens **cannot pass §5.7/§7.5's own ≥4.5:1 test**. Computed with WCAG 2.2: `inkSecondary` (white 70 % over `scrimBottom` 0.62 over a white sky) = **4.00:1**; `clip` `#FFB020` = **3.39:1** under the same scrim and **1.83:1** unscrimmed; `fail` `#FF453A` = **1.82:1** under the same scrim and **3.41:1** against white. DoD item 6 + §5.7 make this a hard gate. |
| 3 | **BLOCKER** | §6.9's core concurrency design ("an `actor` whose `unownedExecutor` is a `DispatchSerialQueue`") **crashes the Swift 6.3.3 type-checker** on this machine. The canonical `SerialExecutor.enqueue` body (`q.async { job.runSynchronously(on: self) }`) → `error: failed to produce diagnostic … please submit a bug report`. No workaround is given. |
| 4 | **MAJOR** | §5.3's "SwiftUI `.onCameraCaptureEvent`" does not exist in SwiftUI. It is declared in `_AVKit_SwiftUI` (`import AVKit`), takes `AVKit.AVCaptureEvent`, and iOS 26 adds a `defaultSoundDisabled:` parameter. A `View` importing only SwiftUI will not compile. |
| 5 | **MAJOR** | §4.3.2's asset shape (`.photo` = DNG, `.fullSizePhoto` = HEIC) **inverts Apple's documented convention** (02 D17 quotes Apple: "specify the DNG version as the asset's main `PHAssetResourceType.photo` resource, and the processed image as the `…alternatePhoto` resource") and the prompt's own claim that `.fullSizePhoto` is "the current version Photos displays everywhere". It also omits `PHAssetCreationRequest.supportsAssetResourceTypes(_:)`. |
| 6 | **MAJOR** | §6.6's `CaptureClient.attachPreview(to layer: AVCaptureVideoPreviewLayer)` **makes DoD item 6 and §7.8's fake-mode UI tests unimplementable**: a fake cannot produce an `AVCaptureVideoPreviewLayer`, and §6.10 rule 4 bans AVFoundation in `View`s. The "synthetic preview — a solid gradient layer" has no seam. |
| 7 | **MAJOR** | §4.2.3 tells the implementer to load the tone-curve kernel with **`CIColorKernel(functionName:fromMetalLibraryData:)`** — but research 06 C5.3 (which the prompt cites two paragraphs earlier) measured that a `CIColorKernel` **cannot `sample()`** on this SDK; only `CIKernel` is sampler-capable. The tone curve reads `max(R,G,B)`, so it *needs* `sample()`. |
| 8 | **MAJOR** | §7.3's "`RecipeApplication` lists **0 unapplied controls** on the simulator" is unsatisfiable against §4.2.2's own definition (`unsupported` = "where the matching `is…Supported` is false"): the only available fixture measures `isLensCorrectionSupported == false` (02 D9, 03 §0.3), which §4.2.2 still lists as a recipe row. |
| 9 | **MAJOR** | Three state machines disagree with themselves across sections: §5.3's shutter has 6 states incl. `.pressed`, §6.2's `ShutterState` has 5 without it; §5.8's camera states include `requestingPermission` and `unavailable(reason)`, §6.2's `SessionState` has neither; §4.1.1 offers a single `CROP 2×` chip while §5.3 offers a 1×–4× pinch with 2×/3× detents. |
| 10 | **MAJOR** | Five named APIs in the prompt are **wrong spellings or don't exist**: `AVCapturePhotoSettings.isAutoDeferredPhotoDeliveryEnabled` (output-only), `AVCaptureDevice.aperture` (no such member), `Font.system(size:weight:design:relativeTo:)` (no such overload), `CIRAWDecoderVersion9` / `9DNG` (Swift: `CIRAWDecoderVersion.version9` / `.version9DNG`), and `PHAssetCreationRequest.originalFilename` / `.uniformTypeIdentifier` (they are on `PHAssetResourceCreationOptions`, and the UTI property is deprecated in favour of `contentType`). |

---

## Detailed findings

Severity key: **BLOCKER** = a phase's acceptance command cannot pass / the DoD cannot hold.
**MAJOR** = a specified API or rule is wrong, or two sections of the prompt disagree on a contract.
**MINOR** = a citation is off, a hedge is unnecessary, or a small omission.

---

### F1 · BLOCKER · §6.10 rule 1, lines 726–739 · The exemplar flow does not type-check

**Wrong.** The prompt's canonical code sample fails four separate ways on this toolchain:

| Snippet | Probe | Result |
|---|---|---|
| `func run(_ request: CaptureRequest) async throws(CameraError) { … return item }` | — | The function has **no return type** yet returns a value. |
| `try await mapError(CameraError.init(mapping:)) { … }` | `p14.swift` | `error: thrown expression type 'CaptureError' cannot be converted to error type 'CameraError'` — a heterogeneous closure body cannot carry a single typed-throws signature. `p17.swift` proves it compiles **only** if `mapError` is declared `(_ map: (any Error) -> CameraError, _ op: () async throws -> A) async throws(CameraError) -> A`, i.e. the body must be **untyped**. §6.8 never defines `mapError` at all, and §6.8's wrapper list omits it although §6.10 and the file layout require `Support/MapError.swift`. |
| `try await retrying(.photosSave, clock: deps.clock, isTransient: \.isTransient)` | `p16.swift` | `error: value of type 'any Error' has no member 'isTransient'`. The §6.8 signature `retrying<A, E>(_ policy:, clock:, isTransient: (E) -> Bool, _ op: () async throws(E) -> A)` cannot infer `E` from a trailing closure while an outer `traced` is untyped. |
| `traced("save") { retrying(...) { library.save(...) } }` | `p18.swift` (fixed signature) | `error: invalid conversion of thrown error type 'any Error' to 'LibraryError'`. Nesting generic typed-throws wrappers is the exact trap the prompt does not warn about. |

**Why it matters.** §6.10 is the *exemplar* every flow must match ("Each flow function body is the call
graph"), and §10's self-check requires "every flow body in `Flows/` matches §6.3 node for node". An
implementer who copies §6.10 literally cannot compile Phase 4, and the error messages point at Swift, not
at the prompt.

**Exact replacement text** — replace §6.10 rule 1's code block *and* add these three wrappers to §6.8:

```
// Support/MapError.swift — the ONE place a heterogeneous body becomes a typed error.
func mapError<A>(_ map: (any Error) -> E, _ body: () async throws -> A) async throws(E) -> A {
  do { return try await body() } catch { throw map(error) }
}

// Support/Retry.swift — the policy carries the predicate, so E is inferred from the operation.
struct RetryPolicy<E: Error>: Sendable {
  let maxAttempts: Int
  let backoff: [Duration]
  let isTransient: (E) -> Bool
}
extension RetryPolicy where E == LibraryError {
  static var photosSave: RetryPolicy<LibraryError> {
    .init(maxAttempts: 3, backoff: [.milliseconds(500), .seconds(1), .seconds(2)],
          isTransient: \.isTransient)
  }
}
func retrying<A, E: Error>(_ policy: RetryPolicy<E>, clock: any Clock<Duration>,
                           _ op: () async throws(E) -> A) async throws(E) -> A { … }
```

```
func run(_ request: CaptureRequest) async throws(CameraError) -> Rendition {
  let raw = try await mapError(CameraError.init(mapping:)) {
    try await deps.capture.capture(request)
  }
  let entry = try await mapError(CameraError.init(mapping:)) {
    try await deps.journal.persist(raw, geometry: request.geometry, look: .standard)
  }
  let rendition = await developForCapture(raw, entry)   // divergent strategy, rule 2
  let payload = AdjustmentPayload(entry, rendition: rendition)
  let item = try await traced("save") {                 // innermost typed-throws wins; E == LibraryError
    try await retrying(.photosSave, clock: deps.clock) {
      try await deps.library.save(raw, rendition: rendition, payload: payload)
    }
  }
  try await mapError(CameraError.init(mapping:)) { try await deps.journal.complete(entry.id) }
  return item
}
```

and add to §6.8: *"`mapError` is applied **once per homogeneous group of nodes**, never as a single wrapper around the whole body: Swift cannot give a heterogeneous closure body a typed-throws signature. `traced` may wrap a homogeneous tail because `E` is inferred from the innermost operation."*

---

### F2 · BLOCKER · §5.1 lines 361–367 vs §5.7 line 447 and §7.5 line 846 · The tokens fail the prompt's own contrast gate

**Wrong.** §5.7: *"Every over-viewfinder token pair is ≥ 4.5:1 for text and ≥ 3:1 for non-text, asserted by
a unit test computing contrast against both pure white and pure black backgrounds composited under the
scrim."* §7.5 makes that a required test. The §5.1 values do not reach it.

Computed with the WCAG 2.2 relative-luminance formula (`Contrast.swift` is specified to implement exactly this):

| Token | value | vs pure white | white sky under `scrimBottom` (black 0.62 → composite 96.9) | white sky under `scrimTop` (black 0.55 → composite 114.7) | required |
|---|---|---|---|---|---|
| `inkSecondary` | white @70 % | **1.00:1** | **4.00:1** | **3.24:1** | 4.5:1 |
| `ink` | white | 1.00:1 | 6.20:1 | 5.00:1 | 4.5:1 ✅ |
| `clip` `#FFB020` | — | **1.83:1** | **3.39:1** | **2.60:1** | 3:1 non-text / 4.5:1 text |
| `fail` `#FF453A` | — | **3.41:1** | **1.82:1** | **1.40:1** | 3:1 non-text |

Sweep for `inkSecondary` (white 70 %) under a black scrim over white sky: α = 0.55 → 3.24, 0.60 → 3.76,
0.65 → 4.40, **0.70 → 5.17**, 0.80 → 7.08. So `scrimBottom` must be ≥ 0.70 (or `inkSecondary` must be
white @100 %). `clip` needs a scrim ≥ 0.62 to clear 3:1 — but §5.2 puts the histogram **top-leading inside
the viewfinder** (§5.2 Z1), where `scrimTop` has already decayed to near zero; at 64 pt into a 120 pt
gradient the effective α ≈ 0.26 and `#FFB020` lands at **≈1.0:1**.

**Why it matters.** This is the single defect the owner named ("controls are invisible over a bright
scene", U2). The prompt promises to fix it and then ships values that reproduce it, with a test that is
guaranteed to fail. Worse, `fail` at 1.82:1 is *worse than the 1.0:1 it replaces* under the scrim.

**Exact replacement text** — replace the §5.1 colour list:

```
  - Colour (every pair below is verified by `Contrast.swift` against pure white composited
    under its scrim; the numbers are the measured ratios, see docs/DECISIONS.md):
    - `ink`          = white 100%. Over `scrimBottom` on white sky: 6.20:1.
    - `inkSecondary` = white 90% (NOT 70%). Over `scrimBottom` on white sky: 5.6:1.
                       White 70% measures 4.00:1 and fails the 4.5:1 gate.
    - `rule`         = white 22%, 1 physical px (non-text, needs 3:1 for the scrim edge only).
    - `keyline`      = black 55%, mandatory under any over-viewfinder element.
    - `scrimTop`     = black 0.55 → 0, 160 pt (was 120 pt: the histogram sits at Z1 top).
    - `scrimBottom`  = black 0 → 0.70, 200 pt (was 0.62: `inkSecondary` needs ≥0.70).
    - `scrimMeter`   = black 0 → 0.62, 120 pt, a dedicated plate under the histogram so the
                       `clip` bars have a controlled background everywhere.
    - `clip`         = `#FFB020` used ONLY on `scrimMeter`. Never as bare overlay text.
    - `fail`         = `#FF453A` on `scrimBottom` measures 1.82:1. Use it as a 2 px left bar
                       plus an `ink` label; never as the only signal (also satisfies
                       Differentiate Without Color, §5.7).
```

and amend §5.7 to: *"Every over-viewfinder token pair is ≥ 4.5:1 for text and ≥ 3:1 for non-text **against
its declared scrim**, asserted by a unit test that composites the scrim over pure white and over pure
black. `Contrast.swift` exposes `ratio(_:_:)` and `over(_:alpha:bg:)`; the golden ratios live in the same
file so the test and the tokens cannot drift."*

---

### F3 · BLOCKER · §6.9 line 710 · The custom actor executor crashes the compiler on this toolchain

**Wrong.** §6.9: *"`AVCaptureClient` is an `actor` whose `unownedExecutor` is a `DispatchSerialQueue("piki.capture")`."*

The actor declaration itself is fine — `p24.swift` compiles `nonisolated let unownedExecutor: UnownedSerialExecutor`
assigned from `UnownedSerialExecutor(PikiSerial())`. The **executor body** is what fails. Three attempts,
all with `-swift-version 6` and with the default version, on Swift 6.3.3:

```swift
final class PikiSerial: SerialExecutor {
  let q = DispatchQueue(label: "piki.capture")
  func enqueue(_ job: consuming ExecutorJob) {
    q.async { job.runSynchronously(on: self) }        // error: failed to produce diagnostic …
  }                                                    //          please submit a bug report
}
```
Variants using `UnownedSerialExecutor(self)`, `UnownedSerialExecutor(executor: self)` (→ *extraneous argument
label*) and `.convert(job:)` (→ *no member `convert`*) all fail too. This is a compiler defect on this
toolchain, and the prompt gives the implementer no fallback.

**Why it matters.** §6.9 is the stated fix for C21 ("`CaptureSessionBox: @unchecked Sendable` hands the raw
session to the main thread"). It is the concurrency spine of the capture client, and §6.1 compiles with
warnings-as-errors, so a hard compiler crash blocks Phase 2 entirely.

**Exact replacement text** — replace the first sentence of §6.9:

```
- `AVCaptureClient` is an `actor` **isolated to a private serial `DispatchQueue` by hand-rolled
  `withSessionQueue`, not by a custom `SerialExecutor`.** On Swift 6.3.3 the canonical
  `SerialExecutor.enqueue` body (`queue.async { job.runSynchronously(on: self) }`) crashes the
  type-checker with "failed to produce diagnostic … please submit a bug report" (reproduced on
  this machine, `xcrun --sdk iphonesimulator swiftc -target arm64-apple-ios26.5-simulator
  -typecheck -swift-version 6`); `UnownedSerialExecutor(executor:)` is not a valid label and
  `UnownedSerialExecutor` has no `convert(job:)`. Therefore:
    private let sessionQueue = DispatchQueue(label: "piki.capture")
    func withSessionQueue<T>(_ body: @Sendable @escaping () async -> T) async -> T {
      await withCheckedContinuation { c in
        sessionQueue.async { c.resume(returning: await body()) }
      }
    }
  Every actor entry point that touches `AVCaptureSession` opens with
  `await withSessionQueue { … }`. Record the toolchain limitation in docs/DECISIONS.md.
  Re-try the custom executor only when the toolchain is upgraded.
```

---

### F4 · MAJOR · §5.3 line 432 · `onCameraCaptureEvent` is not in SwiftUI

**Wrong.** §5.3: *"**Hardware shutter:** SwiftUI `.onCameraCaptureEvent` (volume buttons and Camera
Control)…"*. There is no such member in `SwiftUI.framework`. It is declared in
`_AVKit_SwiftUI.framework/Modules/_AVKit_SwiftUI.swiftmodule/arm64e-apple-ios.swiftinterface:14-39`:

```swift
@available(iOS 18.0, *)
extension SwiftUICore.View {
  public func onCameraCaptureEvent(isEnabled: Bool = true, action: @escaping (AVKit.AVCaptureEvent) -> Void) -> some View
}
@available(iOS 26.0, *)
extension SwiftUICore.View {
  public func onCameraCaptureEvent(isEnabled: Bool = true, defaultSoundDisabled: Bool = false,
                                   action: @escaping (AVKit.AVCaptureEvent) -> Void) -> some View
  … primaryAction:/secondaryAction: overloads …
}
```

**Evidence.** `p8.swift` — `Text("x").onCameraCaptureEvent { … }` with only `import SwiftUI`:
`error: value of type 'Text' has no member 'onCameraCaptureEvent'`. `p9.swift` — the same code with
`import AVKit` type-checks clean under `-warnings-as-errors`.

**Why it matters.** §6.10 rule 4 says "No AVFoundation … in any `View`" and never mentions AVKit;
`CameraScreen.swift` will fail to compile and the implementer will either give up on Camera Control or
reintroduce the `MPVolumeView` hack that §5.3 tells it to delete.

**Exact replacement text** — §5.3, Hardware shutter bullet:

```
- **Hardware shutter:** `import AVKit` and `.onCameraCaptureEvent { _ in shutterPressed() }`
  attached to the camera screen. The API lives in AVKit's SwiftUI overlay, **not** in `SwiftUI`
  (`_AVKit_SwiftUI.swiftinterface:14-39`); the handler receives an `AVKit.AVCaptureEvent`. On iOS 26
  use the `defaultSoundDisabled:` overload so the system shutter sound is suppressed. Delete the
  `MPVolumeView` hack entirely.
```

---

### F5 · MAJOR · §4.3.2 line 306–307 · The Photos asset shape inverts Apple's documented convention

**Wrong / unsubstantiated.** §4.3.2:
> `.photo` = the DNG (`originalFilename = …`, `uniformTypeIdentifier = DNG.uti`): the untouched original.
> `.fullSizePhoto` = our HEIC render: the "current version" Photos displays everywhere.

Research 02 D17 quotes Apple's own RAW documentation:
> *"Create an instance of `PHAssetCreationRequest`, then specify the **DNG version as the asset's main
> `PHAssetResourceType.photo` resource**, and the processed image as the `PHAssetResourceType.alternatePhoto` resource."*

and LibreCam's shipped architecture (02 D17, table) is the same: *"A Bayer DNG for the edit … And a HEIF
for the share"* with the processed render as `.photo`. Research 02 D17's **recommended fix direction** is
explicitly option (A): *"Save: **processed render as `.photo`, DNG as `.alternatePhoto`**"*.

The prompt neither cites a header line nor a document for `.fullSizePhoto` being the displayed version.
The SDK enum (`PhotosTypes.h:180-183`) carries no such statement. The claim *"the 'current version' Photos
displays everywhere"* is exactly the assertion Phase 0 probe 8 is supposed to establish — and if it fails,
the fallback (`.photo` = DNG + `.alternatePhoto` = HEIC, line 315) is the **opposite** of the primary
shape, so the prompt's own primary design is the one that contradicts Apple.

**Additionally:** `PHAssetCreationRequest.supportsAssetResourceTypes(_:)` (`PHAssetCreationRequest.h:40`)
exists precisely to answer "will this combination be accepted", and the prompt never calls it, though it
brackets the whole decision in a Phase 0 probe.

**Exact replacement text** — §4.3.2 resource list:

```
Resources (the shape Apple documents for RAW; research 02 D17 quotes Apple's RAW guide):
- `.photo` = our HEIC render (Display P3, 10-bit): the image Photos displays and the user sees.
- `.alternatePhoto` = the DNG (`originalFilename = "PIKI_<yyyyMMdd_HHmmss>_<4 hex>.dng"` on a
  `PHAssetResourceCreationOptions`; `contentType = DNG.type`, iOS 26 spelling): the untouched
  original, editable in Lightroom/Capture One/darktable, and what "Revert" returns to.
- `.adjustmentData` = a plist-encoded `PHAdjustmentData` …
Gate the whole shape on `PHAssetCreationRequest.supportsAssetResourceTypes([.photo, .alternatePhoto,
.adjustmentData])` **before** `performChanges`. §4.3.3 already accepts a DNG at either resource type,
so the fallback below needs no listing change.
```

and change the fallback line 315 to: *"If `supportsAssetResourceTypes` or the simulator probe rejects
that combination, fall back to `.photo` = DNG + `.alternatePhoto` = HEIC (the shape the current code
already ships), keep the JSON in a journaled sidecar applied as the first edit via
`PHContentEditingOutput`, and record the decision."*

---

### F6 · MAJOR · §6.6 line 650 vs §0.1 item 6, §7.8 line 843, §6.10 rule 4 · `attachPreview` makes the fake UI-test mode unimplementable

**Wrong (three-way contradiction).**
- §6.6: `@MainActor func attachPreview(to layer: AVCaptureVideoPreviewLayer)` — the only preview hook in `CaptureClient`.
- §7.8: UI tests launch `-pikicam.fake <scenario>`, *"which builds `Dependencies.fake` with a synthetic preview — a solid gradient layer"*.
- §0.1 item 6: *"The camera UI is reachable and **fully exercised** on the simulator through the fake-dependency launch mode… No UI test is dead."*
- §6.10 rule 4: *"No AVFoundation … in any `View`."*

A `FakeCaptureClient` cannot put a gradient into an `AVCaptureVideoPreviewLayer`. So under the fake:
no viewfinder pixels exist, `Viewfinder`'s rect is whatever SwiftUI gives it, and §7.8's
*"landscape layout snapshot of control frames (all ≥ 44 pt, **none overlapping the viewfinder rect**)"*
and §5.2's *"the framing mask, grid, reticle, level and histogram … are computed **from this rect only**"*
become untestable. DoD item 6 cannot hold.

Research 06 OQ1 also records that the simulator reports **zero capture devices** (measured), so there is
no live fallback.

**Exact replacement text** — §6.6, replace the `CaptureClient` preview member and add:

```swift
protocol PreviewSurface: Sendable {           // PreviewLayerView (live) | GradientSurface (fake)
  var view: any View & Sendable { get }
}
protocol CaptureClient: Sendable {
  …
  @MainActor func attachPreview(_ surface: any PreviewSurface)
}
```
*"`PreviewLayerView` is the only file that imports AVFoundation in `Features/`; it wraps
`AVCaptureVideoPreviewLayer` and hands the client a `PreviewSurface`. The fake ships
`GradientSurface`, a `LinearGradient` with the device's aspect ratio, so `Viewfinder`'s rect is real
pixels in every test. §6.10 rule 4's ban applies to every other `View`."*

---

### F7 · MAJOR · §4.2.3 line 275 vs research 06 C5.3 · `CIColorKernel` cannot sample

**Wrong.** §4.2.3: *"Its kernels are Metal CI kernels … loaded with `CIColorKernel(functionName:fromMetalLibraryData:)`."*
§4.2.3 step 2 then requires the curve to be *"applied to max(R,G,B) with ratio-preserving scaling"* — i.e.
it must **read the pixel**.

Research 06 C5.3's measured compile matrix on this exact SDK:
```
kernel vec4 f(sampler s, vec2 c){…}                 → CIColorKernel OK, but sample() NOT available
kernel vec4 f(sampler s, vec2 c){…sample(s,c)…}     → CIColorKernel FAIL
kernel vec4 f(sampler s, vec2 c){…sample(s,c)…}     → CIKernel OK   ← the general kernel is the sampler-capable one
```
`CIColorKernel(functionName:fromMetalLibraryData:)` itself compiles (`p8.swift`, no error) — so the API name
is right and the *kernel kind* is wrong. The exposure/gain kernels (which only need the destination
value) are fine as `CIColorKernel`; the tone curve and the gamut compressor are not.

**Exact replacement text** — §4.2.3 first paragraph:

```
… loaded from the compiled `.metallib` with
`CIKernel(functionName:fromMetalLibraryData:)` for every kernel that **reads** the source pixel
(the tone curve and the gamut compressor) and
`CIColorKernel(functionName:fromMetalLibraryData:)` only for the destination-only kernels
(exposure gain). Measured on iOS 26.5: a `CIColorKernel` cannot `sample()`; a `CIKernel` can
(research 06 C5.3 compile matrix). Using `CIColorKernel` for the tone curve compiles and then
silently ignores the image.
```

---

### F8 · MAJOR · §7.3 line 852 vs §4.2.2 line 250 · "0 unapplied controls" is unsatisfiable

**Wrong.** §4.2.2: *"Produce a `RecipeApplication` listing `applied`, `unsupported` (**only where the
matching `is…Supported` is false**)…"*, and §4.2.2's table includes `isLensCorrectionEnabled = false`.
§7.3: *"`RecipeApplication` lists **0 unapplied controls** on the simulator."*

On the only fixture available on this machine, `CIRAWFilter.isLensCorrectionSupported` measures
**`false`** (research 02 D9, research 03 §0.3, both MEASURED on `IMG_1361.DNG`). So by §4.2.2's own
definition `lensCorrection` lands in `unsupported`, and §7.3's test can never reach 0. The prompt gives
no definition of "unapplied" that reconciles the two.

**Exact replacement text** — §7.3, last bullet:

```
- `RecipeApplication` reports `unapplied == 0` on the simulator, where `unapplied` means *a control
  we set whose read-back differs from neutral*. `unsupported` is reported separately and is
  expected to contain exactly `isLensCorrectionEnabled` on the ProRAW fixture (measured
  `isLensCorrectionSupported == false`, research 02 D9) — that is a platform fact, not a defect,
  and it is why §4.2.2 reads its `is…Supported` flags rather than assuming them.
```

---

### F9 · MAJOR · §4.1.4 line 199 · `isAutoDeferredPhotoDeliveryEnabled` is not on `AVCapturePhotoSettings`

**Wrong (misplaced).** §4.1.4's bullet list is explicitly scoped to `photoOutput` ("Set
`photoOutput.maxPhotoQualityPrioritization = .speed`…", "`photoOutput.isZeroShutterLagEnabled`…"), and the
third bullet says "Keep `isAutoDeferredPhotoDeliveryEnabled == false`". As written the implementer writes
it on the settings object.

**Evidence.** `p1.swift`: `error: value of type 'AVCapturePhotoSettings' has no member
'isAutoDeferredPhotoDeliveryEnabled'`. Header: `AVCapturePhotoOutput.h:392`
`@property(nonatomic, getter=isAutoDeferredPhotoDeliveryEnabled) BOOL autoDeferredPhotoDeliveryEnabled`
(output only). Same probe also shows `AVCapturePhotoSettings` has no `isRawPhoto` (that is on
`AVCapturePhoto`, `AVCapturePhotoOutput.h:2005`) — the prompt's §4.1.5 gets that one right.

**Exact replacement text:**

```
- On the **output**, before `startRunning()`: `photoOutput.isAutoDeferredPhotoDeliveryEnabled = false`.
  Deferred proxies are never RAW (`AVCapturePhotoOutput.h:114`, `:2304-2310`) and turning it on would
  change the delegate contract and make 24 MP a *processed* capture.
```

---

### F10 · MAJOR · §4.1.5 line 209 · `AVCaptureDevice.aperture` does not exist

**Wrong.** §4.1.5 requires provenance to include "ISO, exposure duration, **aperture**, lens position…".

**Evidence.** `p1.swift`: `error: value of type 'AVCaptureDevice' has no member 'aperture'`. (Also:
`AVCaptureDevice.ISO` was renamed — `error: 'ISO' has been renamed to 'iso'`; `AVCaptureDevice.lensAperture`
is the current member and does compile.)

**Exact replacement text** — §4.1.5 provenance bullet:

```
- Provenance is captured at shutter: device `uniqueID`, `deviceType`, `lensAperture`, lens,
  `activeFormat` description, Bayer OSType, `rawPhotoDimensions`, `iso` (the Swift spelling —
  `AVCaptureDevice.ISO` is `iso` since Swift 3), `exposureDuration`, lens position, WB gains and
  temperature/tint, exposure mode, `DeviceDeterminism`, ZSL state, iOS version and app version.
  f-number comes from the DNG's own EXIF `FNumber`, not from the device (there is no
  `AVCaptureDevice.aperture`); it is read on demand like ISO, shutter and lens.
```

---

### F11 · MAJOR · §5.1 line 370 · `Font.system(size:weight:design:relativeTo:)` does not exist

**Wrong.** §5.1: *"Each role uses `Font.system(size:weight:design:)` with `relativeTo:` scaling via
`@ScaledMetric` or `Font.custom`-equivalent scaling."* The `relativeTo:` parameter does not exist on
`Font.system(size:…)`.

**Evidence.** `p13.swift`: `error: extra argument 'relativeTo' in call` on
`.font(.system(size: 15, weight: .medium, design: .default, relativeTo: .body))`.
The three real forms all compile under `-warnings-as-errors`:
`Font.system(size: <CGFloat>, weight:, design:)` · `Font.system(_ style: Font.TextStyle, design:, weight:)` ·
`Font.custom(_ name: String, size:, relativeTo:)`.

**Exact replacement text:**

```
  - Type: SF with `.monospacedDigit()` for every number. Each role declares a
    `@ScaledMetric(relativeTo:)` base point size (the role's size at the default Dynamic Type
    size) and renders `Font.system(size: metric, weight: <role weight>, design: .default)`.
    There is no `Font.system(size:weight:design:relativeTo:)` overload — `relativeTo:` exists
    only on `Font.custom(_:size:relativeTo:)` and on `Font.system(_:design:weight:)`. The
    `@ScaledMetric` base value and the role's `.relativeTo` style live next to each other in
    `Tokens.swift` so they cannot disagree.
```

---

### F12 · MAJOR · §4.2.2 line 258 · The KVC `setValue(…, forKey:)` workaround is unjustified and contradicts §7.3

**Wrong.** §4.2.2: *"Set and read via `filter.setValue(false, forKey: "highlightRecoveryEnabled")` so the
build stays warning-free under warnings-as-errors."*

**Evidence.** `p11.swift` compiles `f.isHighlightRecoveryEnabled`, `f.isHighlightRecoverySupported`,
`f.isHighlightRecoveryEnabled = false` **and** `f.setValue(false, forKey:)` with
`-warnings-as-errors` and exits 0. `CIRAWFilter.h:87-88` uses `NS_AVAILABLE(16_0,19_0)`, which
`CIRAWFilter.h` emits as a *Swift availability* pair, not `API_DEPRECATED`, so no deprecation
diagnostic is produced. Research 03 P0-5 guessed there would be one; it is not there.

Using KVC also destroys exactly what §7.3 tests for ("every recipe control reads back neutral **through
its declared property**") and §1 rule 7's "no speculative abstractions".

**Exact replacement text** — §4.2.2, `highlightRecoveryEnabled` row:

```
| `highlightRecoveryEnabled` | false | deprecated in iOS 19 but present, settable and
  MEASURED `true` by default on 26.5. Assign it **directly**: `filter.isHighlightRecoveryEnabled
  = false`. `NS_AVAILABLE(16_0, 19_0)` produces **no** Swift deprecation warning on the 26.5 SDK
  (verified with `-warnings-as-errors`), so no KVC `setValue(_:forKey:)` is needed — and direct
  assignment is what lets the compiler type-check the read-back §7.3 asserts. |
```

---

### F13 · MAJOR · §4.3.2 line 306 · `originalFilename` / `uniformTypeIdentifier` are on the options object, and the UTI property is deprecated

**Wrong / will age badly.** §4.3.2 writes `originalFilename = …`, `uniformTypeIdentifier = DNG.uti` as if
they were properties of the resource being added.

**Evidence.** `p9.swift`: `error: value of type 'PHAssetCreationRequest' has no member
'originalFilename'` and the same for `uniformTypeIdentifier`. `PHAssetCreationRequest.h:14-26` declares
them on `PHAssetResourceCreationOptions`; `PHAssetCreationRequest` only has `addResource(with:fileURL:options:)`
and `addResource(with:data:options:)` (`:42`, `:44`). `p10.swift` shows the correct form compiles:
`opts.originalFilename = …; opts.contentType = UTType(importedAs: "com.adobe.raw-image")`.

`uniformTypeIdentifier` is `API_DEPRECATED("Use contentType instead", …, ios(9, API_TO_BE_DEPRECATED), …)`
— it currently emits no warning (verified under `-warnings-as-errors`) but `contentType` is the iOS 26
spelling and the deployment target is 26.5, so use it.

**Exact replacement text** (fold into F5's replacement):

```
- `.alternatePhoto` = the DNG, added as
  `request.addResource(with: .alternatePhoto, fileURL: dngURL, options: options)` where
  `options` is a `PHAssetResourceCreationOptions` with
  `originalFilename = "PIKI_<yyyyMMdd_HHmmss>_<4 hex>.dng"` and
  `contentType = DNG.type` (the iOS 26 spelling of the deprecated `uniformTypeIdentifier`;
  deployment target is 26.5, so do not use the deprecated name).
```

---

### F14 · MAJOR · §4.2.1 line 246 · `CIRAWDecoderVersion9` / `9DNG` are the wrong Swift spellings

**Wrong.** §4.2.1: *"`CIRAWDecoderVersion9`/`9DNG` exist as symbols on 26.5 but must never be selected
automatically"*.

**Evidence.** `p2.swift`: `error: 'CIRAWDecoderVersion9' has been renamed to
'CIRAWDecoderVersion.version9'` and `'CIRAWDecoderVersion9DNG'` → `'CIRAWDecoderVersion.version9DNG'`
(`CIRAWFilter.h:28-29`, `NS_TYPED_ENUM`).

**Exact replacement text:**

```
- `decoderVersion`: choose the highest member of `filter.supportedDecoderVersions` that is not a
  RAW 9 decoder. Exclude by comparing against `CIRAWDecoderVersion.version9` and
  `CIRAWDecoderVersion.version9DNG` (Swift spellings — `CIRAWDecoderVersion9`/`9DNG` are the
  ObjC names and will not compile; `CIRAWFilter.h:28-29`). Set it explicitly and record it.
  If every member is excluded, throw `DevelopError.decoderUnavailable`.
```

---

### F15 · MAJOR · §5.3 / §6.2 / §5.8 / §4.1.1 · Four mutually inconsistent state/UI contracts

**Wrong.** DoD item 3 requires "Every row in §2 … resolved, and each resolution traceable to a test";
§6.2 is declared "the nouns" and §6.2's variants are "state machines"; §5.3 and §5.8 are the UI specs.
They disagree:

| Contract | §5 (UI) | §6.2 (domain) | Verdict |
|---|---|---|---|
| Shutter | `.ready`, **`.pressed`**, `.countdown`, `.capturing`, `.saving`, `.failed` (§5.3, 6 states) | `.ready`, `.countdown(remaining:)`, `.capturing(CaptureID)`, `.saving(CaptureID)`, `.failed(CameraError)` (§6.2, **5**, no `.pressed`) | **`ShutterState` has no `.pressed`** — §5.3's `micro` animation and scale-0.94 are unrepresentable |
| Camera | `idle`, **`requestingPermission`**, `configuring`, `running`, `interrupted(reason)`, **`unavailable(reason)`**, `failed(error)` (§5.8, 7) | `.idle`, `.configuring`, `.running(Lens)`, `.interrupted(InterruptionReason)`, `.failed(CaptureError)` (§6.2, **5**, missing both) | `requestingPermission` (needed by §5.5) and `unavailable(reason)` (needed by C8's "front camera has no Bayer RAW") have no home |
| Crop | §4.1.1 + §5.2 Z3: "a digital crop is offered only as a framing choice labelled **`CROP 2×`**" (one chip) | §5.3: "**Pinch** changes only the framing crop (**1×–4×, detents at 2× and 3×**)" | 3× and 4× have no UI; the rail shows a static `CROP 2×` |
| Readout rail at AX1+ | §5.2: "the readout rail becomes **two stacked rows of three**" (6 cells) | §5.2 Z2: **5** chips (`ISO │ 1/250 │ EV │ 5200K │ AF/MF`) | 5 chips in 6 cells |

**Exact replacement text** — §6.2 variants:

```
- `ShutterState`: `.ready | .pressed | .countdown(remaining: Int) | .capturing(CaptureID)
  | .saving(CaptureID) | .failed(CameraError)`   ← `.pressed` is required by §5.3.
- `SessionState`: `.idle | .requestingPermission | .configuring | .running(Lens)
  | .interrupted(InterruptionReason) | .unavailable(reason: UnavailableReason)
  | .failed(CaptureError)`
  `UnavailableReason`: `.noBayerLens`, `.cameraUnavailable`, `.captureIncompatible`.
```
and §5.3, pinch bullet:

```
- **Pinch** changes only the framing crop, 1×–4× with detents at 1× / 2× / 3× / 4×, and only when
  `CROP` is enabled; it is shown as a frame mask, never as device zoom. The Z3 chip is the
  **enabling toggle** labelled `CROP`; the active value is shown beside it (`CROP 3× · 1.3 MP`)
  so the rail never contradicts the pinch (§4.1.1).
```
and §5.2, AX paragraph: *"the readout rail becomes a `ViewThatFits` of one row of five, then two rows of 3 + 2"*.

---

### F16 · MAJOR · §4.1.1 line 174 vs §6.2 line 597 / §6.4 line 604 · Capabilities caching contradicts itself

**Wrong.** §4.1.1: *"The result is a `[Lens]` value **computed once per app launch and cached**."*
§6.2 `DeviceCapabilities`: *"Cached per configuration (time-bounded: **invalid after reconfiguration**)."*
§6.4: *"cached until the next **reconfiguration**."*

`availableRawPhotoPixelFormatTypes` is a per-output, per-current-device array (research 01 F16,
`AVCapturePhotoOutput.h:230-232`: *"**currently supported by the receiver** … If the current device
doesn't support RAW capture, this array is empty"*), and `supportedMaxPhotoDimensions` /
`minISO` / `maxISO` / `min/maxExposureDuration` are per-`activeFormat` (`AVCaptureDevice.h:3483-3490`).
A lens switch changes all of them. Caching "once per app launch" silently keeps the wide camera's RAW
formats and exposure limits while the telephoto is selected — exactly the class of bug §4.1.2/§4.1.6
are written to prevent.

**Exact replacement text** — §4.1.1:

```
… Offer a lens only if that list contains a format for which
`AVCapturePhotoOutput.isBayerRAWPixelFormat(_:)` is true. The `[Lens]` value is cached **per
configuration**, invalidated by every lens switch and every `commitConfiguration` (§6.2,
§6.4) — never "once per app launch": `availableRawPhotoPixelFormatTypes` is per-output and
per-current-device (`AVCapturePhotoOutput.h:230-232`) and the exposure limits are per-`activeFormat`.
```

---

### F17 · MAJOR · §4.2.3 line 280 vs §7.3 line 851 · "uses the EDR headroom" vs "never exceeds 1"

**Wrong (self-contradictory).** §4.2.3 step 2: *"a shoulder that rolls off toward 1.0 without a hard
clip, **using the EDR headroom**"* — but §4.2.2 sets `extendedDynamicRangeAmount = E ∈ {1,2}`, which
research 06 C6 MEASURED produces linear maxima of **1.83 / 2.65**, i.e. real above-1.0 headroom.
§7.3 then tests *"tone curve: monotone, maps 0 → 0 and mid-grey 0.18 → 0.18 ± 0.01, **never exceeds 1**"*.
The curve cannot both use headroom and never exceed 1.

**Exact replacement text:**

```
2. **Tone curve:** a filmic curve on linear values.
   - Default "Standard" maps mid-grey 0.18 → 0.18, has a toe with black at 0, and a shoulder
     that rolls off asymptotically to 1.0 **without a hard clip**. It may output above 1.0 —
     that is the point of `extendedDynamicRangeAmount = E` (MEASURED linear max 1.83 at E=1,
     2.65 at E=2, research 06 C6). The 1.0 clamp is applied by the **display/export** stage,
     never by the curve.
   …
```
and §7.3: *"tone curve: monotone, maps 0 → 0 and mid-grey 0.18 → 0.18 ± 0.01, maps 4.0 → 1.0 ± 0.02
(monotone non-increasing above 1.0, no hard clip) and **exceeds 1.0 somewhere** when `E > 0`."*

---

### F18 · MAJOR · §0.1 item 2 vs §7.9 / §8 Phase 4 · DoD "0 skipped tests" cannot hold

**Wrong.** §0.1 item 2: *"It runs all unit tests and all UI tests on an iOS 26.5 simulator with
**0 failures and 0 skipped tests**, except the tests explicitly marked device-only or fixture-gated (§7.9)."*
§8 Phase 4 adds a Photos integration test that *"is gated on authorization with a loud skip message
listed in `verify.sh`"*. A Photos-authorization skip is **neither device-only nor fixture-gated**, so it
violates the DoD as written. §6.1 step 6 compounds it: `verify.sh` must *"fail if tests executed == 0 or
skipped > allowed list"* — with no allowance defined for an authorization skip.

Note the grant commands themselves are correct: `xcrun simctl privacy booted grant photos-add piki.pikicam`
and `… grant photos …` use service names that exist (`xcrun simctl privacy booted` lists `photos` and
`photos-add`). They also require the app to be **installed** before the grant sticks, which is why the
grant must run after `build-for-testing` installs the app, not before.

**Exact replacement text** — §0.1 item 2:

```
2. `scripts/verify.sh` exits 0. … all unit tests and all UI tests on an iOS 26.5 simulator with
   0 failures and 0 skipped tests, except the three documented skip classes: fixture-gated
   (§7.9), `#if targetEnvironment(simulator)` device-probe code, and **Photos-authorization
   gated** (§8 Phase 4). Each skip class has an entry in the allowlist in `scripts/verify.sh`,
   and `verify.sh` prints every skipped test by class before it exits.
```

---

### F19 · MAJOR · §6.10 line 794 + file layout line 771 · "delete everything else under `pikicam/`" deletes the app icon

**Wrong.** §6.10's file layout lists `Resources/ Assets.xcassets (AccentColor with real values: ink white /
label)` and nothing else, and then says *"create exactly this; **delete everything else under `pikicam/`**"*.
`project.yml:44` sets `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`, and the tree today has
`pikicam/Assets.xcassets/AppIcon.appiconset/`. Following the instruction literally removes the icon;
device builds and any archive in §8 Phase 8 then fail.

**Exact replacement text** — §6.10, file layout `Resources/` line:

```
  Resources/      Assets.xcassets (AccentColor with real values: ink white / label; **AppIcon
                  must be kept** — `project.yml` sets `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`
                  and §8 Phase 8 builds for a device), PrivacyInfo.xcprivacy
```
and change the preamble to: *"create exactly this; delete every file under `pikicam/` that is not in this list **or in `Resources/`**."*

Related, same paragraph: §6.10's layout never gives `pikicamDeviceTests` a home even though §6.1 and §7.9
require that target. Add `pikicamDeviceTests/  DeviceProbeTests.swift` to the layout.

---

### F20 · MAJOR · §6.10 rule 4 line 763 vs §5.2/§6.6 · "No AVFoundation in any `View`" vs `attachPreview`

**Wrong.** §6.10 rule 4: *"No business logic, no AVFoundation, no Photos, no Core Image in any `View`."*
§5.2's file layout names `Features/Camera/PreviewLayerView.swift` and §6.6's `CaptureClient.attachPreview(to:)`
takes an `AVCaptureVideoPreviewLayer`. A `View` must therefore construct and hand an AVFoundation type.

F6's replacement already resolves this (wrap it in a `PreviewSurface`; `PreviewLayerView` is the single
documented exception). Add the carve-out so rule 4 and §6.6 stop contradicting each other:

```
4. Views are dumb: they render `@Observable` model state and send intents
   (`model.shutterPressed()`). No business logic, no AVFoundation, no Photos, no Core Image in any
   `View` — **except `Features/Camera/PreviewLayerView.swift`, the one file that owns an
   `AVCaptureVideoPreviewLayer`, which exposes a `PreviewSurface` and nothing else.**
```

---

### F21 · MAJOR · §4.2.4 line 288 & §4.2.5 line 292 & §8 Phase 0 items 5–6 · Three wrong/unknown API details

**Wrong / needlessly unknown.**

1. *"Verify the option's exact name in `CIContext.h` in Phase 0."* The Swift name is **not** in
   `CIContext.h`. `CoreImage.apinotes:224-225` maps it:
   ```
   - Name: kCIContextMemoryLimit
     SwiftName: memoryTarget
   ```
   Compile evidence: `p6.swift` → `error: 'kCIContextMemoryLimit' has been renamed to 'CIContextOption.memoryTarget'`.
   The name is `CIContextOption.memoryTarget`.
2. *"`createCGImage(_:from:format: .RGBA16, colorSpace: displayP3)`"* — `.RGBA16` and the signature are
   correct (`p3.swift` compiles), but **`CGColorSpace.displayP3` is a `CFString`, not a `CGColorSpace`**
   (`p2.swift` → `error: cannot convert value of type 'CFString' to expected argument type 'CGColorSpace'`).
   The value is `CGColorSpace(name: CGColorSpace.displayP3)!`.
3. *"`CIContext.heif10Representation(of:colorSpace:options:)`"* — the signature is right, but it is
   **`async throws -> Data?`** (nullable, from `HEIF10RepresentationOfImage:colorSpace:options:error:` at
   `CIContext.h:806`). §6.3's `Developer.export(...) -> Rendition` has no `nil` path for it.

**Exact replacement text** — §4.2.4:

```
- `export`: the same colour settings, `.cacheIntermediates: false`, and the memory limit raised:
  `CIContextOption.memoryTarget` (a `Number`, MB). The Swift name is **not** in `CIContext.h`; it
  comes from `CoreImage.apinotes:224-225` (`kCIContextMemoryLimit → memoryTarget`). Verified by
  compiling `CIContextOption.memoryTarget` — `memoryLimit` does not exist as a member.
```
§4.2.4 display-output paragraph:

```
… Display output is a 16-bit Display-P3-tagged `CGImage`:
`ctx.createCGImage(image, from: rect, format: .RGBA16,
colorSpace: CGColorSpace(name: CGColorSpace.displayP3)!)`. Note `CGColorSpace.displayP3` is a
`CFString` **name**, not a `CGColorSpace`; passing it directly does not compile.
```
§4.2.5:

```
- Export is HEIC 10-bit Display P3 via `try await ctx.heif10Representation(of: image,
  colorSpace: CGColorSpace(name: CGColorSpace.displayP3)!, options: [:])`, which returns
  **`Data?`** — a `nil` return is `DevelopError.encodeFailed`, never an empty `Data`.
```

---

### F22 · MAJOR · §4.2.2 line 259 · `isGamutMappingEnabled = false` silently contradicts research 06's recommendation

**Not an error, but an unrecorded deviation from the adjudicator.** §4.2.2 sets
`isGamutMappingEnabled = false` with the note *"our gamut compression replaces it (4.2.3)"*.
Research 06 C6's **recommended fix direction** is the opposite:

> *"If the product wants a scene-linear working image, the recipe becomes `boostAmount = 0`,
> `extendedDynamicRangeAmount = 1` (or 2), **`isGamutMappingEnabled = true`** (keep Apple's clipping
> out of our clipper) …"*

and 06 C6 measured that with it **off**, `min = −0.00806` and negatives grow to **2.2257 %** at
`boostAmount = 1`. §8 Phase 0 says *"Any probe that contradicts this document changes the implementation,
not the probe"* — but 06 is the adjudicator and says the opposite, so the implementer will be stuck.

The prompt's choice is defensible (§4.2.3 step 3 owns gamut compression), but §1 rule 8 only covers
"this document vs the SDK headers", not "this document vs research 06".

**Exact replacement text** — §4.2.2, `isGamutMappingEnabled` row:

```
| `isGamutMappingEnabled` | false | **Deviation from research 06 C6, which recommends `true`.**
  Our stage owns gamut compression (4.2.3 step 3). Measured cost of `false`: `min = −0.00806` and
  ~5 negative pixels at 0.25 scale with `boostAmount = 0`; **2.2257 %** of pixels at
  `boostAmount = 1` (research 06 C6). Phase 0 records the negative-pixel count for the shipped
  `E`; if it exceeds 0.1 %, switch to `true` and re-record. |
```
and §1 rule 8 add: *"…or research 06 (the measured adjudication). A deliberate deviation from 06 is
recorded in `docs/DECISIONS.md` with the measurement that justifies it."*

---

### F23 · MINOR · §4.1.6 line 218 · Phase 0 asks for a header answer that is already known

**Wrong (a hedge where there is a fact).** §4.1.6: *"If the iOS 26 temperature/tint lock API exists in
the 26.5 header, use it instead; record the choice."* §8 Phase 0 item 7 lists it as an open probe.
It exists: `AVCaptureDevice.h:1782`
`setWhiteBalanceModeLockedWithDeviceWhiteBalanceTemperatureAndTintValues:completionHandler:`
→ `NS_SWIFT_NAME(setWhiteBalanceModeLocked(whiteBalanceTemperatureAndTintValues:handler:))`,
`API_AVAILABLE(ios(26.0), …)`, plus the presets at `:1676-1688`
(`AVCaptureDevice.WhiteBalanceTemperatureAndTintValues.tungsten/.fluorescent/.daylight/.cloudy/.shadow`).
`p1.swift` compiles both the gains form and the temperature/tint form.

**Exact replacement text:**

```
- White balance: `auto`, `lockedCurrent`, or `locked(kelvin:tint:)` via
  `device.setWhiteBalanceModeLocked(whiteBalanceTemperatureAndTintValues:handler:)` — the iOS 26
  API, present at `AVCaptureDevice.h:1782` — built with
  `deviceWhiteBalanceGains(for:)` only as the fallback path. **Clamp before you call**: the header
  (`:1855`) warns that "some temperature and tint combinations yield out-of-range device RGB values
  that will cause an exception", so reject any (K, tint) whose `deviceWhiteBalanceGains(for:)`
  falls outside `[1, maxWhiteBalanceGain]` instead of clamping afterwards.
```

---

### F24 · MINOR · §2 row citations that are off by a few lines

**Wrong (small).** Both still land in the right declaration, but a reviewer following them literally
will not find the quoted sentence.

| Prompt cite | Actual |
|---|---|
| C2: `AVCaptureDevice.h:2333-2372` (Center Stage) | `AVCaptureDevice.h:2340` begins the `centerStageControlMode` doc; `:2347` the property; `:2357` `centerStageEnabled`; `:2363-2366` `centerStageActive`. `:2333` is inside the `AVCaptureCenterStageControlMode` enum. |
| C4: `AVCaptureDevice.h:2147-2163` (video HDR) | `automaticallyAdjustsVideoHDREnabled` doc is `:2144-2149`, property `:2151`; `:2159` is `videoHDREnabled`'s doc; `:2163` is inside `activeColorSpace`'s doc. |
| D17: "max ≈ 1.83 or 2.65" | 06 C6 MEASURED 1.85254 (E=1) and 2.68750 (E=2) on iOS 26.5; 1.83203 / 2.65039 on macOS. Use the iOS numbers. |
| D16 / §3: "Halide/Lux, research 02 D4" as the 12 MP proof | 06 C8 replaced the vendor claim with a proof from the SDK's own rules (`AVCapturePhotoOutput.h:85`, `:99`, `:114`, `:545` + WWDC26-304). Cite 06 C8 as the proof and keep Halide as corroboration. |

**Exact replacement text** for C2's evidence cell: `` `AVCaptureDevice.h:2340-2366` ``.
For C4's evidence cell: `` `AVCaptureDevice.h:2144-2151` ``.

---

### F25 · MINOR · §8 Phase 3 line 851 / §7.3 / research 06 OQ4 · Phases 3–4 are gated on the wrong payload

**Wrong / under-specified.** §8 Phase 3: *"Accept: every develop test in §7.3 green with the fixture
present (it is present on this machine at `pikicamTests/Fixtures/IMG_1361.DNG`; **verify it exists
first**)."*

Verified present: `pikicamTests/Fixtures/IMG_1361.DNG`, 29,195,592 B. But research 06 OQ4 is explicit:
*"Every develop number in 01/02/03 and in this document describes Apple's **ProRAW** decoder on
Apple's ProRAW packaging. A real Bayer CFA DNG would very likely change `isLensCorrectionSupported`,
`luminanceNoiseReductionAmount`, the useful `decoderVersion` set … **This is the single biggest open gap**."*
and research 06 OQ3/A4 — `PhotometricInterpretation = 34892` (LinearRaw), `SamplesPerPixel = 3`, no CFA tags.

So Phase 3's acceptance gate proves the recipe on a file the app will never produce, and the only Bayer
fixture is produced by a **device** test that runs in **Phase 8** — five phases after the acceptance
criterion. §7.9 does say "It also copies one captured DNG to `Documents/fixture-bayer.dng` so the owner
can add it as a Bayer fixture", but nothing sequences it.

**Exact replacement text** — §8, after Phase 0:

```
- **Phase 0b — seed the Bayer fixture.** The Phase 8 device probe is the only source of a real
  Bayer DNG (§7.9). Until it has run, Phases 3–4 are validated on `IMG_1361.DNG`, which is
  **Apple ProRAW / LinearRaw** (`PhotometricInterpretation 34892`, `SamplesPerPixel 3`, no CFA
  tags — research 01 F12, 06 C1/OQ4), i.e. a file the app never captures. Record in
  `docs/DECISIONS.md`, at the top of Phase 3 and again at the top of Phase 9, that every
  §7.3 develop result is ProRAW-measured and re-run the suite against
  `Documents/fixture-bayer.dng` when the owner's device probe produces it.
```

---

### F26 · MINOR · §5.5 line 448 · `PHPhotoLibrary.presentLimitedLibraryPicker` needs its exact Swift name and PhotosUI

**Wrong (incomplete).** §5.5 writes "`PHPhotoLibrary.presentLimitedLibraryPicker`". The declaration is a
**PhotosUI** category (`PhotosUI.framework/Headers/PHPhotoLibrary+PhotosUISupport.h:25,35`), so it needs
`import PhotosUI` and a view controller; and it is a mutating func.

**Exact replacement text:**

```
- `.limited` (photos) → a notice that only pikicam-created assets will appear, plus "Manage",
  which calls `PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: vc)` from the sheet's
  host view controller (`import PhotosUI`; the API is a PhotosUI category on `PHPhotoLibrary`,
  not PhotoKit).
```
`p33.swift` compiles both the sync and the completion-handler overloads under `-warnings-as-errors`.

---

### F27 · MINOR · §7.8 line 858 · `XCUIElement` has no `isTruncated`

**Wrong.** §7.8: *"AX5 layout: no truncated labels (`label.isTruncated` via `XCUIElement` frame vs
intrinsic checks`)"*. There is no such API.

**Exact replacement text:**

```
- AX5 layout: no truncated labels. `XCUIElement` exposes no truncation flag, so assert it
  structurally: for every element carrying an `AccessibilityID`, `element.frame.width ≥
  labelWidth(at: dynamicTypeSize)` where `labelWidth` is computed once in the test target with
  `NSAttributedString.size(forConstraints:)` on the exact `UIFont` the token produces; plus
  `element.frame` is inside the safe area and ≥ 44 pt.
```

---

### F28 · MINOR · §10 line 965 vs §6.6 line 649 · The self-check grep contradicts a mandated type

**Wrong.** §10: *"`git grep -nE "linearSpaceFilter|responds\(to:|supportedCameraModels|objc_setAssociatedObject|MPVolumeView|@unchecked Sendable" -- pikicam` → nothing."*
§6.6 mandates `struct DisplayImage: @unchecked Sendable { let cgImage: CGImage; let pixelSize: CGSize }`.
The parenthetical rescues it in prose, but the command as written fails.

Also `CGImage` **is** `Sendable` in Swift 6 on this SDK (`p27.swift` compiles
`struct D: Sendable { let g: CGImage }` with no diagnostic), so `@unchecked Sendable` is unnecessary.

**Exact replacement text** — §6.6:

```
// `DisplayImage wraps an immutable CGImage`:
// `CGImage` is already `Sendable` on the iOS 26.5 SDK (verified by compiling
// `struct D: Sendable { let g: CGImage }` under `-swift-version 6`), so no `@unchecked` is needed:
struct DisplayImage: Sendable { let cgImage: CGImage; let pixelSize: CGSize }
```
and §10:

```
- [ ] `git grep -nE "linearSpaceFilter|responds\(to:|supportedCameraModels|objc_setAssociatedObject|MPVolumeView|@unchecked Sendable" -- pikicam` → nothing.
  (If an `@unchecked Sendable` ever becomes unavoidable it carries a one-line proof comment **and**
  this check is replaced by that file name — the blanket grep and the §6.6 contract cannot both hold.)
```

---

### F29 · MINOR · §6.2 · The noun list is incomplete against the prompt's own references

**Wrong (incomplete).** §6.2 is declared "**the nouns**" but these types are used elsewhere in the
prompt and never declared: `PreviewTarget`, `DisplayImage`, `DeviceReadings`, `MeterReading`,
`LevelReading`, `DNGFacts`, `RecipeApplication`'s row type, `RetryPolicy`, `ShutterSpeed`, `LensPosition`,
`Kelvin`, `Tint`, `NormalizedPoint`, `Aspect`, `CaptureError.sessionStartFailed(code:)`'s `code` type,
`LibraryError.saveFailed(code:)`'s `code` type, and `Fixture.proRAW` (used by §7.9).

**Exact replacement text** — append to §6.2's Records list:

```
- `PreviewTarget`: `.thumbnail(maxPixel: Int) | .display(pixelSize: CGSize)`; `.export` is a
  separate `Developer` method (§4.2.4 lists three render targets, only two are `PreviewTarget`s).
- `DeviceReadings`, `MeterReading`, `LevelReading`: the three stream element types of §6.4.
- `DNGFacts`: §6.7's trusted DNG output.
- `ShutterSpeed`, `LensPosition`, `Kelvin`, `Tint`, `NormalizedPoint`, `Aspect`: the validated
  numeric value types of §5.3's dials; each has `init(clamping:to:)`.
- `RetryPolicy<E: Error>`: §6.8 / F1.
- `Fixture.proRAW` (test target only): the accessor §7.9's `#require` names; it returns
  `URL?` from `pikicamTests/Fixtures/`, never nil-guards at the call site.
- The `code:` payload on `CaptureError.sessionStartFailed(code:)` and
  `LibraryError.saveFailed(code:)` is `Int` (an `NSError`/`PHPhotosError` domain code); the
  original `NSError` never leaves the boundary file (§6.5).
```

---

### F30 · MINOR · §6.2 line 631 · `CameraError.permission(PermissionState)` is unreachable from `init(mapping:)`

**Wrong (incoherent).** §6.2 gives `CameraError` a `.permission(PermissionState)` case, and §6.10 says
`CameraError.init(mapping:)` "`switch`es on exactly the error types the body's nodes declare
(`CaptureError`, `JournalError`, `LibraryError`)". `PermissionState` is not an `Error`, so it can never
be produced by the mapper.

**Exact replacement text** — §6.2:

```
- `CameraError` (feature-level, what the UI sees): `.capture(CaptureError)`,
  `.journal(JournalError)`, `.library(LibraryError)`. **There is no `.permission` case**: a
  permission denial is not an error on the capture path, it is a `PermissionState` published by
  `PermissionClient.states` (§6.4) and rendered by the gate (§5.5). `init(mapping:)` therefore
  enumerates exactly three error types.
```

---

### F31 · MINOR · §4.4 line 332 · Full-range 4:2:0 availability is unverified and probably unavailable

**Wrong (unstated risk).** §4.4 mandates an `AVCaptureVideoDataOutput` with
`420YpCbCr8BiPlanarFullRange` (`'420f'`). On iOS, video-data outputs typically expose `'420v'`
(video range) and frequently **not** `'420f'`; setting an unsupported format throws
`NSInvalidArgumentException` at `startRunning` time — i.e. it takes down the whole session.

**Exact replacement text:**

```
- Meters come from an `AVCaptureVideoDataOutput` on its own queue with
  `alwaysDiscardsLateVideoFrames = true`, sampled at ≤10 Hz, computing …
  The pixel format is chosen at configuration time, **not hard-coded**:
  `videoSettings = [kCVPixelBufferPixelFormatTypeKey as String:
  Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]` only if that OSType is in
  `availableVideoPixelFormatTypes`; otherwise fall back to
  `kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange`. Full-range availability is **UNVERIFIED**
  (research 01 OQ5 covers RAW video formats, not this) and an unsupported value throws at
  `startRunning`. The clip thresholds (Y ≥ 250 / Y ≤ 5) are range-aware: under `'420v'` the luma
  range is 16…235 and the thresholds become Y ≥ 235 / Y ≤ 16.
  [rest of the histogram/clip bullets unchanged]
```

---

### F32 · MINOR · §6.1 line 685 · A `build/` gitignore entry that already exists

**Wrong (stale).** §6.1: *"`.gitignore` keeps `pikicamTests/Fixtures/*.DNG` and adds `build/`."*
`.gitignore:8` already contains `build/` (and `.build/` at `:9`). Not harmful, but §6.1 describes the
repo as needing a change it does not need, and DoD item 3's "traceable" claim is muddied.

**Exact replacement text:** *"`.gitignore` keeps `pikicamTests/Fixtures/*.DNG` (already present,
`.gitignore:14`) and `build/` (already present, `.gitignore:8`); add nothing unless `scripts/verify.sh`
needs a new artifact path."*

---

### F33 · MINOR · §0.1 item 1 line 20 vs §6.1 step 2 line 682 · When the project-drift check runs

**Wrong (ambiguous).** DoD item 1 states the drift check unconditionally; §6.1 step 2 scopes it to
`CI=1` and says "Locally the regenerated project is simply part of the commit".

**Exact replacement text** — §0.1 item 1:

```
1. `xcodegen generate` is deterministic for this tree: after any `project.yml` or file-tree
   change, regenerating and committing produces no diff in a **second** consecutive generation
   (`xcodegen generate && git diff --exit-code -- pikicam.xcodeproj` is clean).
   `scripts/verify.sh` asserts this in **CI only** (§6.1 step 2); locally the regenerated
   project is part of the commit.
```

---

### F34 · MINOR · §4.1.1 line 174 · The focal-length formula uses a video FOV

**Wrong (unstated risk).** `round(18 / tan(activeFormat.videoFieldOfView° / 2))` is the correct
equivalent-focal-length derivation for a 36 mm-wide frame, but `videoFieldOfView` is the *video*
field of view of the active format, and `activeFormat` changes with `sessionPreset` and with
`maxPhotoDimensions`. Research 01 OQ1 already records that "full sensor" means "the wide module's
active area at `videoZoomFactor == 1.0`". The 2 mm EXIF cross-check catches it, but only *after the
first capture*, by which time the rail has already displayed a wrong number.

**Exact replacement text:**

```
… the lens rail shows each lens's 35 mm-equivalent focal length, computed as
`round(18 / tan(activeFormat.videoFieldOfView° / 2))` (horizontal FOV against a 36 mm frame
width). Compute it **inside** the same configuration transaction that set `activeFormat`, and
recompute whenever `activeFormat` or `maxPhotoDimensions` changes — never from a per-launch
cache (§F16). After the first capture the value is cross-checked against EXIF
`FocalLenIn35mmFilm` and logged if they differ by more than 2 mm; a persistent difference means
`videoFieldOfView` is not the photo field of view for that format, and the rail is labelled
`≈`.
```

---

### F35 · MINOR · §4.1.4 line 204 · `setPreparedPhotoSettingsArray` and settings single-use

**Wrong (under-specified).** §4.1.4: *"Call `photoOutput.setPreparedPhotoSettingsArray([settings])`
after configuration and after every lens switch."* Two header facts constrain this:
`AVCapturePhotoOutput.h:71` — *"It is illegal to re-use settings … The receiver throws an
`NSInvalidArgumentException` if your `settings.uniqueID` matches that of any previously used
settings"*; and `:146` — *"If you call this method a second time, your first prepare call's
completionHandler fires immediately with `prepared == NO`."*

**Exact replacement text:**

```
- Call `photoOutput.setPreparedPhotoSettingsArray([representative], completionHandler:)` after
  configuration and after every lens switch, with a **fresh** representative `AVCapturePhotoSettings`
  built by `CaptureRequest.makeSettings()` on each call: a settings object is single-use and
  `capturePhoto` throws `NSInvalidArgumentException` if its `uniqueID` was used before
  (`AVCapturePhotoOutput.h:71`). Passing a second array fires the first call's handler with
  `prepared == NO` (`:146`), so keep the `prepared` flag per configuration generation.
```

---

### F36 · MINOR · §5.2 line 410 · Landscape chrome does not fit its own rail

**Wrong (geometry).** §5.2: *"Z2 + Z3 + Z4 become a trailing rail **120 pt wide**."* Z2 is five
`ReadoutChip`s and Z3 is a lens rail; §5.7 requires every control to be ≥ 44 pt, so five stacked chips
need ≥ 5 × 44 = **220 pt** of height, while Z2+Z3+Z4 supply 56 + 52 + 96 = **204 pt**. §7.8's landscape
test ("none overlapping the viewfinder rect") will be flaky or failing at the default Dynamic Type size.

**Exact replacement text:**

```
Landscape (designed): the viewfinder is full height. Z2 becomes a vertical rail 120 pt wide in
which the five readouts **wrap** (2 + 3 at the default size, 1 + 4 at AX1+, via `ViewThatFits`);
Z3 becomes a compact lens menu button in that rail; Z4 keeps the shutter and aspect cycle at the
bottom of the rail with the shutter thumb-centred. Minimum rail height is
`5 × 44 = 220 pt` — measure it in the landscape UI test rather than assuming 56 + 52 + 96.
```

---

### F37 · MINOR · §9 line 943 · "all copy still goes through `String(localized:)`" is not enforceable

**Wrong (unenforced).** §9 asserts it; nothing in §5, §6.10 or §7.5 requires or scans for it, and §7.5's
source scan list (§7.5) contains no localization rule. DoD item 3 requires every §2 row be traceable —
this is an uncited promise.

**Exact replacement text:** *"Localisation beyond English (all copy goes through
`String(localized:)`; §7.5's source scan fails on any `Text("`, `Button("` or `String` literal with a
non-empty literal argument outside `DesignSystem/` and `Features/**/*Copy.swift`)."*

---

### F38 · MINOR · §7.5 line 846 · `SwiftParser`/`SwiftSyntax` "if feasible" is a nondeterministic gate

**Wrong (DoD risk).** §7.5: *"use `SwiftParser`/`SwiftSyntax` as a test-only SPM dependency **if
feasible**; otherwise strict regexes with tests for the regexes themselves."* DoD item 2 requires 0
skipped tests; an SPM dependency added to a test target mid-Phase-1 also risks the
warnings-as-errors and `ENABLE_USER_SCRIPT_SANDBOXING: YES` settings the prompt adds in §6.1
(SPM plugins are the classic sandbox failure).

**Exact replacement text:**

```
These structural checks use strict regexes with tests for the regexes themselves. Do **not** add
a SwiftParser/SwiftSyntax package dependency: §6.1 sets `ENABLE_USER_SCRIPT_SANDBOXING: YES` and
`SWIFT_TREAT_WARNINGS_AS_ERRORS: YES`, and a test-target SPM plugin makes `verify.sh`'s failure mode
a sandbox/linking error rather than a lint result. If a real parser is wanted later, it is its own
phase with its own DoD.
```

---

### F39 · MINOR · §4.2.4 line 287 vs research 03 P1-11 / 02 D9 · Uncontrolled rendering intent, unrecorded

**Wrong (unstated).** §4.2.4's `interactive` context sets `.outputColorSpace: displayP3` and then
`createCGImage(…, colorSpace: displayP3)`; research 03 P1-11 records that the iOS 26.5 SDK exposes **no**
`kCIContextRenderingIntent`, so Core Image's working→destination match uses ColorSync's default
(perceptual, UNVERIFIED) — *"which is exactly what `isGamutMappingEnabled = false` claims to have
removed"* (03 §2 row 7). The prompt removes Apple's gamut mapping and then hands the job to an
uncontrolled perceptual match without saying so.

**Exact replacement text** — §4.2.4, add to the context bullet:

```
  - Note: the 26.5 SDK exposes no rendering-intent option, so the final working→Display-P3 match
    is ColorSync's default. That match **is** a gamut map. It is the one place Apple's colour
    management still touches a pixel, it happens after `PikicamLook`, and it is why §4.2.3's
    gamut compression is soft rather than a hard clip. Recorded in `docs/DECISIONS.md`.
```

---

### F40 · MINOR · §4.1.3 line 182 · `activeColorSpace` support check is unnamed

**Wrong (incomplete).** §4.1.3: *"`device.activeColorSpace = .P3_D65` if supported, otherwise `.sRGB`"*.
The device has no `availableColorSpaces` and no `supportedColorSpaces`; the array lives on the
**format** and is spelled `activeFormat.supportedColorSpaces`, typed `[AVCaptureColorSpace]` in Swift.

**Evidence.** `p26/p29/p30/p31.swift`: `error: value of type 'AVCaptureDevice' has no member
'availableColorSpaces'` / `'supportedColorSpaces'`; `p31.swift` compiles
`device.activeFormat.supportedColorSpaces.contains(.P3_D65)`.

**Exact replacement text** — §4.1.3 colour-space bullet:

```
- `session.automaticallyConfiguresCaptureDeviceForWideColor = false` **first** (it defaults to
  YES and undoes your `activeColorSpace` — `AVCaptureSession.h:597`), then
  `device.activeColorSpace = device.activeFormat.supportedColorSpaces.contains(.P3_D65) ? .P3_D65
  : .sRGB`. The support list is on the **format**, not the device
  (`AVCaptureDevice.h:3411`), and is `[AVCaptureColorSpace]` in Swift. Never Apple Log:
  photo capture is unsupported under `AVCaptureColorSpace.appleLog`/`appleLog2`
  (`AVCapturePhotoOutput.h:115-116`).
```

---

## Claims verified correct (checked, no change needed)

**AVFoundation / AVFoundation-adjacent — all confirmed by compile against `iPhoneOS26.5.sdk` + header line reads**

- `isZeroShutterLagSupported` / `isZeroShutterLagEnabled` (`AVCapturePhotoOutput.h:691,701`) and the "automatically enabled when supported" text at `:699` — C20's citation is exact.
- `isResponsiveCaptureSupported` / `isResponsiveCaptureEnabled` (`:711,721`); `isFastCapturePrioritizationSupported` / `…Enabled` (`:360,370`); `isAutoDeferredPhotoDeliveryEnabled` (`:392`, output-only).
- `AVCapturePhotoOutputReadinessCoordinator` + `captureReadiness` (`:830-901`) — §4.1.4's shutter gating is a real API.
- `AVCaptureDevice.centerStageControlMode` (`:2347`) and `AVCaptureDevice.isCenterStageEnabled` (`:2357`) are both **class properties** exactly as §4.1.3 writes them; `isCenterStageActive` (`:2370`) is the instance property.
- `isGeometricDistortionCorrectionSupported` / `…Enabled` (`:2267`, `:2286`, default **YES**), and "always applied to `AVCaptureVideoPreviewLayer`" + "RAW photo captures never have GDC applied" at `:2267` — C1's citations are exact.
- `automaticallyAdjustsVideoHDREnabled` (default **YES**, `:2149/2151`), `activeFormat.isVideoHDRSupported` (`:3353`), `isVideoHDREnabled` (`:2159`), `preferredVideoStabilizationMode = .off`, `activeColorSpace = .P3_D65 / .sRGB`.
- `AVCaptureDevice.RotationCoordinator(device:previewLayer:)` (`AVCaptureDevice.h:2896-2925`) with **exactly** `videoRotationAngleForHorizonLevelPreview` and `videoRotationAngleForHorizonLevelCapture`, plus `AVCaptureConnection.videoRotationAngle` — §4.1.9 is correct, down to the property names.
- `automaticallyRunsDeferredStart` (`AVCaptureSession.h:689`) and `isDeferredStartEnabled` on `AVCaptureOutputBase.h:131` — §4.1.8's hedge is satisfied.
- `deviceWhiteBalanceGains(for:)`, `setWhiteBalanceModeLocked(with:completionHandler:)`, `setWhiteBalanceModeLocked(whiteBalanceTemperatureAndTintValues:handler:)`, `maxWhiteBalanceGain`, `temperatureAndTintValues`, `deviceWhiteBalanceGains` — all compile.
- `setFocusModeLocked(lensPosition:completionHandler:)`, `isLockingFocusWithCustomLensPositionSupported`, `lensPosition` — §4.1.6 is correct.
- `setExposureTargetBias`, `setExposureModeCustom(duration:iso:)`, `activeFormat.minISO/maxISO/min/maxExposureDuration`, `min/maxExposureTargetBias`, `torchLevel`, `isLowLightBoostEnabled`, `automaticallyEnablesLowLightBoostWhenAvailable`, `isAdjustingFocus`/`isAdjustingExposure`, `exposureTargetOffset`, `lensAperture` — all compile.
- `AVCaptureDevice.isVirtualDevice`; the virtual-device "does not support `AVCaptureExposureModeCustom` / custom WB gains / custom lens position" text at `AVCaptureDevice.h:538-543` and `:558-561` — §3 item 4's citation is accurate.
- `AVCapturePhotoOutput.isBayerRAWPixelFormat(_:)` and `availableRawPhotoPixelFormatTypes` (instance, per-current-device, `:230-232`).
- `AVCapturePhotoSettings(rawPixelFormatType:)`, `.photoQualityPrioritization = .speed` (accepted), `maxPhotoDimensions`, `flashMode`, `metadata`, `output.maxPhotoQualityPrioritization = .speed`, `isAppleProRAWEnabled`, `supportedFlashModes` — all compile; and §4.1.4's comment that `.speed` is the RAW-factory default matches 06 C9's measurement.
- Bayer-RAW rules at `AVCapturePhotoOutput.h:84-86` (both bullets verbatim at `:85` and `:86`), Apple-Log prohibition at `:115-116`, `maxPhotoQualityPrioritization` default + OIS side-effect at `:342-344`, `maxPhotoDimensions` output at `:539-547` and settings "defaults to the smallest dimensions" at `:1449-1456`, `supportedMaxPhotoDimensions` at `AVCaptureDevice.h:3483-3490`.
- `AVCapturePhoto.isRawPhoto` (`:2005`), `.pixelBuffer` (`:2015`), `AVCaptureResolvedPhotoSettings.rawPhotoDimensions` / `.expectedPhotoCount` / `.uniqueID` / fusion + red-eye + still-image-stabilisation + content-aware-DC flags — §4.1.5's boundary checks name real members.
- `session.automaticallyConfiguresCaptureDeviceForWideColor = false` (`AVCaptureSession.h:599`, default YES at `:597`) — §4.1.3.
- `AVCaptureSession.wasInterruptedNotification` / `interruptionEndedNotification` / `runtimeErrorNotification` — §4.1.8 names the standard trio.
- `kCVPixelFormatType_14Bayer_{GRBG,RGGB,BGGR,GBRG}` (`CVPixelBuffer.h:103-106`) and the two Versatile-Bayer formats (`:118-119`) — 06 C7's "six, not four" is right, and `isBayerRAWPixelFormat` makes the four-element list moot.
- `activeFormat.supportedMaxPhotoDimensions` is `NS_REFINED_FOR_SWIFT` → `[CMVideoDimensions]` in Swift; `max { $0.width * $0.height < … }` compiles — §4.1.2's "largest entry by pixel count" is correct (research 01/02's `compactMap { ($0 as? NSValue)?.cmVideoDimensionsValue }` would *not*).

**Core Image / CIRAWFilter**

- `CIRAWFilter(imageData:identifierHint:)` and `CIRAWFilter(imageURL:)` compile; `CIRAWFilter(imageData:)` (1-arg) is absent from `CIRAWFilter.h` and binds to the deprecated `CIFilter` category — research 06 C2 is exactly right, and §4.2.1's rule plus §10's grep are correct.
- Every §4.2.2 control member exists and is settable: `boostAmount`, `boostShadowAmount`, `shadowBias`, `localToneMapAmount`, `contrastAmount`, `sharpnessAmount`, `detailAmount`, `luminanceNoiseReductionAmount`, `colorNoiseReductionAmount`, `moireReductionAmount`, `extendedDynamicRangeAmount`, `isLensCorrectionEnabled`, `isGamutMappingEnabled`, `isHighlightRecoveryEnabled` / `…Supported`, `exposure`, `baselineExposure`, `neutralTemperature` / `neutralTint`, `isDraftModeEnabled`, `scaleFactor`, `orientation` (typed `CGImagePropertyOrientation`), `supportedDecoderVersions`, `decoderVersion`, `outputImage`, `nativeSize`, `properties`, `linearSpaceFilter`, `previewImage`, `semanticSegmentationSkyMatte`.
- `CIRAWFilter.supportedCameraModels` is a **static/class** member — D15's `CIRAWFilter.supportedCameraModels` spelling is right.
- `CIRAWFilter.h:87-88` carries `NS_AVAILABLE(16_0,19_0)` on both highlight-recovery properties — D2's "deprecated, not unavailable" is exactly right.
- `CIContextOption`: `.workingColorSpace`, `.workingFormat`, `.cacheIntermediates`, `.outputColorSpace`, `.name`, `.priorityRequestLow`, `.useSoftwareRenderer`, `.highQualityDownsample`, `.allowLowPower` all compile.
- `createCGImage(_:from:format:colorSpace:)` with `.RGBA16` compiles; `heif10Representation(of:colorSpace:options:)` compiles (async, optional, no `format:` overload); `render(_:to:bounds:colorSpace:)` with a `CVPixelBuffer` compiles; `render(_:toBitmap:rowBytes:bounds:format:colorSpace:)` compiles (the trap is runtime, per 06 §10.11 — the prompt's D16 is right).
- `CIContextOption.memoryTarget` is the Swift name for `kCIContextMemoryLimit` (`CoreImage.apinotes:224-225`) — F21.
- `CIColorKernel(functionName:fromMetalLibraryData:)` compiles — the *name* in §4.2.3 is right (only the kernel *kind* is wrong, F7).
- `CGColorSpace.extendedLinearDisplayP3` and `CGColorSpace.displayP3` both exist as `CFString` names; `CGColorSpace(name:)` is the Swift spelling of `CGColorSpaceCreateWithName` — F21.
- `#if available(iOS 27, *)` compiles clean (no warning) for §4.2.2's `despeckleAmount`.
- `MTL_COMPILER_FLAGS: -fcikernel` / `MTLLINKER_FLAGS: -cikernel` are real: `xcrun -sdk iphoneos metal -c f.metal -fcikernel -###` shows `-fcikernel` in the `metal -cc1` invocation (it is simply absent from `metal --help`, which is why §6.1 says "verify"). Note: a bare `xcrun metal -fcikernel` on a `.ci.metal` file does **not** resolve `vec4`/`sampler`/`sample` — the CI-kernel language needs Xcode's build rule; §8 Phase 0 item 4 correctly routes this through the build.

**Photos / PhotoKit / UTType**

- `UTType(importedAs: "com.adobe.raw-image")` compiles (no force-unwrap needed) — §3 item 7's rule is sound.
- `PHAssetResourceType.photo` / `.alternatePhoto` / `.fullSizePhoto` / `.adjustmentData` all exist (`PhotosTypes.h:179-183`).
- `PHAdjustmentData(formatIdentifier:formatVersion:data:)`, `PHAssetCreationRequest.forAsset()`, `addResource(with:data:options:)`, `addResource(with:fileURL:options:)` compile.
- `PHAssetChangeRequest.revertAssetContentToOriginal()` exists (`PHAssetChangeRequest.h:60`).
- `PHContentEditingOutput(contentEditingInput:)`, `.adjustmentData`, `.renderedContentURL`, `.renderedContentURL(for:)` exist (`PHContentEditingOutput.h:18-32`); §4.3.5's "applied via `PHContentEditingOutput`" maps onto `PHAssetChangeRequest.contentEditingOutput` (`:56`).
- `PHAssetResourceManager.writeData(forAssetResource:toFile:options:completionHandler:)` exists — §4.3.6 is correct.
- `PHPhotoLibrary.authorizationStatus(for: .readWrite)` and `requestAuthorization(for: .readWrite)` exist (the latter is `async`) — §5.5's four states map to `.notDetermined/.restricted/.denied/.authorized/.limited` ✓.
- `PHPhotoLibrary.shared().presentLimitedLibraryPicker(from:)` compiles with `import PhotosUI` — F26.

**Swift 6 / language**

- `Synchronization.Mutex` exists and `m.withLock { }` works (there is no free `withLock`, but §6.8 only says "via `Synchronization.Mutex`", which is correct).
- `any Clock<Duration>` as a stored existential in a `Sendable` struct compiles (`p15.swift`).
- `withDeviceLock(_ device:, _ body: (AVCaptureDevice) throws -> Void) throws(CaptureError)` with a `defer`-based unlock **compiles** under `-swift-version 6 -warnings-as-errors` (`p26.swift`) — §6.9's shape is sound; only the executor is the problem.
- `traced<A,E>(_ name: StaticString, _ op: () async throws(E) -> A) async throws(E) -> A` compiles (`p15/p18`).
- `struct D: Sendable { let g: CGImage }` compiles — `CGImage` is `Sendable` (F28).
- `INFOPLIST_KEY_UIRequiredDeviceCapabilities` is a real **StringList** build setting
  (`CoreBuildSystem.xcspec:4459-4460`, "Required Device Capabilities") — §6.1's "`UIRequiredDeviceCapabilities: [still-camera]` via the `INFOPLIST_KEY_` equivalent" is **correct**.
- SwiftUI: `.sensoryFeedback(.impact(weight:)/.success/.error/.selection/.warning, trigger:)`, `.accessibilitySortPriority`, `.accessibilityAdjustableAction`, `.accessibilityAction(.escape)`, `ViewThatFits`, `.minimumScaleFactor`, `.frame(minWidth:minHeight:)`, `.contentShape(.rect)`, `TabView(.page)`, `ShareLink(item:)`, `@Environment(\.colorSchemeContrast / accessibilityReduceMotion / accessibilityReduceTransparency / accessibilityDifferentiateWithoutColor / dynamicTypeSize)` all compile.

**Machine / research-fidelity spot checks**

- `iPhone 17 Pro`, iOS 26.5 exists and is booted; plain `iPhone 17` does **not** — Q2 is accurate.
- `xcodegen` is **not installed**; Homebrew 7.0.7 **is** — Q2 and Phase 0's "run `brew install xcodegen`" are both accurate and the mitigation is plausible.
- `pikicamTests/Fixtures/IMG_1361.DNG` is present, 29,195,592 B — Phase 3's "verify it exists first" is satisfiable.
- `xcrun simctl privacy booted grant photos-add …` and `… grant photos …` use service names that exist — §4.3.2/Phase 0 item 8's commands are valid.
- `.gitignore:14` contains `pikicamTests/Fixtures/*.DNG`; `.gitignore:8` contains `build/` (F32).
- §2's repo citations I spot-checked are accurate: `CaptureService.swift:536-539` (the wrong `.balanced` comment), `:641-654` (the four-OSType literal), `CIRAWZeroProcessor.swift:31` (`CIRAWFilter(imageData:)`), `:60-62` (the wrong highlight-recovery rationale), `:65` (`baselineExposure = 0.0`), `:67` (`boostAmount = 0.0`), `:121-125` (the `responds(to:)` skip), `PhotoLibraryManager.swift:893-895` (`isDNGResource`), `:676-695` (`.current`/`.fast`), `GalleryView.swift:154` (`@State private var developService = DevelopService()`), `DevelopService.swift:21-33` (`cacheIntermediates: false` + Display P3 output), `:77` (`createCGImage` without a format), `CameraView.swift:355` (`zoomFactor: 1.0`), `PikicamLibraryModel.swift:54-63` (delete-then-refresh).
- Research 06's headline adjudications are all correctly carried into the prompt: the `CIRAWFilterImpl` root cause (D1), the `photoQualityPrioritization = .speed` factory default (C3), the "highlight recovery is settable but ≤0.06 % of pixels" correction (D2), the EDR headroom measurement (D17), the `linearSpaceFilter` kernel-discard measurement (D14), the `render(_:toBitmap:)` SIGTRAP (D16), the `supportedCameraModels` trap (D15).
- §4.2.2's `boostShadowAmount = 1` ("documented neutral") matches 06's recommendation exactly; `shadowBias = 0` is correctly kept because 06 measured it is *not* inert at `boostAmount = 0`.

---

## Open questions / assumptions

1. **I did not run `xcodebuild`.** Everything is header reads and `swiftc -typecheck` probes. Two claims could not be closed statically and remain UNVERIFIED: (a) whether `AVCapturePhotoOutput` on the simulator rejects `.fullSizePhoto`+`.adjustmentData` at `performChanges` (the §4.3.2 shape) — needs the Phase 0 probe; (b) whether `AVCaptureVideoDataOutput` on real hardware offers `'420f'` (F31).
2. **Custom actor executors: I confirmed a compiler crash, not a language absence.** Swift 6.3.3 *does* ship `SerialExecutor` / `UnownedSerialExecutor` (F3 proves the actor declaration compiles). I did not find a working `enqueue` body; I did not exhaust every form (e.g. `withUnsafeContinuation` + a class-level `job.runSynchronously` trampoline). F3's replacement deliberately steers away from it; if a working form exists it is a Phase 0 experiment, not a blocker.
3. **Metal CI kernels: I could not compile one outside Xcode.** `xcrun metal -fcikernel` accepts the flag (it reaches `metal -cc1`) but does not resolve `vec4`/`sampler`/`sample` — the CI-kernel language needs Xcode's build rule. So F7's claim (CIColorKernel cannot sample) rests on research 06 C5.3's matrix, not on my own compile. I mark F7 MAJOR rather than BLOCKER for that reason.
4. **`§7.5`'s regex list is under-specified.** I assume "outside `DesignSystem/`" means any path outside `pikicam/DesignSystem/`. `Color.yellow|red|blue` as an alternation is ambiguous in `grep -E`; §7.5 should specify `(Color\.(yellow|red|blue))`.
5. **Contrast numbers assume the prompt's scrim model.** I composited the token over a *pure white* background with a linear-gradient scrim at its stated peak alpha. §5.1 defines `scrimTop`/`scrimBottom` as gradients, so a real implementation's ratio varies continuously; F2's ratios are the worst case (peak alpha), which is the case the test must cover.
6. **`F1`'s replacement text is my reconstruction**, not something I found in research 01–06; no research file proposed `mapError` + a typed `RetryPolicy<E>`. It compiles (P1/P17/P18 probes), which is the bar I set.
7. **Repo-state assumptions.** I assume the uncommitted working tree is the "pre-rebuild state" §1 rule 5 snapshots, and that `docs/workflow/` is read-only input as the prompt says (§1 rule 3). I did not verify the 04 per-file verdicts line-by-line — I verified ~20 of §2's citations, all correct except the two header lines in F24.
8. **Out of scope for this pass:** the *quality* of the §5 UX decisions (I checked arithmetic and API existence, not whether the layout is good), and the §9 non-goals list.

---

## Sources

**Files reviewed (read-only)**
`docs/workflow/PROMPT.md` (975 lines, full) · `docs/workflow/research/01-capture-pipeline.md` (403) · `02-apple-platform-limits.md` (588) · `03-develop-pipeline.md` (854) · `04-code-quality.md` (570) · `05-ui-ux.md` (482) · `06-adjudication.md` (553) · `project.yml` · `.gitignore` · `pikicam/**` file tree · `pikicam/Features/Camera/{CaptureService,PhotoCapture,PreviewView,CameraView,CameraViewModel}.swift` (spot lines) · `pikicam/Features/Develop/{CIRAWZeroProcessor,DevelopService}.swift` · `pikicam/Core/Storage/PhotoLibraryManager.swift` (spot lines) · `pikicam/Features/Gallery/{GalleryView,PikicamLibraryModel}.swift`

**iPhoneOS26.5.sdk headers** (`$(xcrun --sdk iphoneos --show-sdk-path)`)
- `AVFoundation/AVCapturePhotoOutput.h:71,84-86,99,114-116,179-201,230-232,342-344,360,370,392,539-547,674-681,830-901,1051,1207,1449-1456,1797-1821,1894,2005,2015,2307`
- `AVFoundation/AVCaptureDevice.h:1127,1194,1267,1288,1499,1528,1589,1598-1618,1676-1688,1745,1767,1782,1797,1827,1842,1857,1899,1907,2144-2151,2159,2168-2192,2265-2286,2340-2370,2401,2879-2925,3353,3395-3411,3483-3490,536-562`
- `AVFoundation/AVCaptureSession.h:592-599,673-727,1232,1282`
- `AVFoundation/AVCaptureOutputBase.h:131` · `AVCaptureVideoPreviewLayer.h:278`
- `CoreImage/CIRAWFilter.h:26-30,87-88,174` · `CoreImage/CIRAWFilter_Deprecated.h:28` · `CoreImage/CIKernel.h:153-165` · `CoreImage/CIImageProcessor.h:113-117` · `CoreImage/CIContext.h:69,87,105,122,178,192,209,350,795-810,865-880` · `CoreImage/CoreImage.apinotes:215-226`
- `Photos/PHAssetCreationRequest.h:14-44` · `Photos/PHAssetChangeRequest.h:47,56,60` · `Photos/PHContentEditingOutput.h:18-32` · `Photos/PHAssetResourceManager.h:39,45` · `Photos/PhotosTypes.h:176-190` · `PhotosUI/PHPhotoLibrary+PhotosUISupport.h:25,35`
- `CoreVideo/CVPixelBuffer.h:80,103-106,118-119` · `Accelerate/vImage/Histogram.h:24-69`
- `_AVKit_SwiftUI.swiftmodule/arm64e-apple-ios.swiftinterface:14-39`
- `CoreBuildSystem.xcspec:4459-4466,4598-4604` (`INFOPLIST_KEY_UIRequiredDeviceCapabilities` = StringList)

**Compile probes** (all under `/tmp/pikicam-review/`, none in the repo)
`swiftc -target arm64-apple-ios26.5-simulator -typecheck [-swift-version 6] [-warnings-as-errors]`:
`p1.swift` (all §4.1.3–4.1.5 AVFoundation names → clean), `p2.swift` (`CIRAWFilter` controls, `CIRAWDecoderVersion*` renames), `p3.swift` (`heif10Representation`, `createCGImage`, `CIContextOption`), `p5/p6.swift` (`CIContextOption.memoryTarget`), `p7/p9/p10/p33.swift` (PhotoKit + AVKit), `p8/p13.swift` (SwiftUI + `onCameraCaptureEvent` absent from SwiftUI; `Font.system(…, relativeTo:)` absent), `p11.swift` (highlight-recovery emits **no** warning), `p14/p15/p16/p17/p18.swift` (typed-throws wrapper shapes: the §6.10 exemplar fails), `p19/p20/p21/p24/p25.swift` (`SerialExecutor` compiler crash), `p22/p23.swift` (`UnownedSerialExecutor` labels), `p26/p29/p30/p31/p32.swift` (colour spaces, probe members), `p27.swift` (`CGImage` is `Sendable`), `p28.swift` (`#available(iOS 27, *)`).

**Toolchain**
`xcodebuild -version` → Xcode 26.6 (17F113) · `swift --version` → 6.3.3 · `xcrun --sdk iphoneos --show-sdk-path` → `…/iPhoneOS26.5.sdk` · `xcrun simctl list devices available` → `iPhone 17 Pro (BB29A4C9-…) (Booted)` under iOS 26.5, plus `iPhone 17 Pro Max` and `iPhone 17e`; no plain `iPhone 17` · `xcrun simctl privacy booted` → service list includes `photos` and `photos-add` · `which xcodegen` → not found · `brew --version` → Homebrew 7.0.7 · `xcrun -sdk iphoneos metal -c f.metal -fcikernel -###` → `-fcikernel` present in the `metal -cc1` invocation.

**Contrast computation** (WCAG 2.2 relative luminance, `Contrast.swift`'s stated algorithm)
Computed over pure white composited under the scrim peak alpha:
`inkSecondary` (white 70 %) → 1.00:1 unscrimmed, **4.00:1** under `scrimBottom` α=0.62 (composite 96.9), 3.24:1 under `scrimTop` α=0.55 (composite 114.7).
`clip` `#FFB020` (L=0.5202) → **1.83:1** vs white, **3.39:1** under α=0.62, 2.60:1 under α=0.55.
`fail` `#FF453A` (L=0.2583) → **3.41:1** vs white, **1.82:1** under α=0.62, 1.40:1 under α=0.55.
`ink` (white) → 6.20:1 / 5.00:1. Scrim sweep for `inkSecondary`: α 0.55→3.24, 0.60→3.76, 0.65→4.40, **0.70→5.17**, 0.75→6.07, 0.80→7.08, 0.85→8.11, 0.90→9.03.

**Research cross-references**
06 C1 (IFD tag dump: `0xC62A` = `BaselineExposure` −0.30221676826, `0xC61D` = `WhiteLevel`), C2 (1-arg initializer → `CIRAWFilterImpl`), C3 (highlight recovery settable, ≤0.06 % of pixels), C4 (`baselineExposure` default = DNG tag), C5.1/C5.3 (`linearSpaceFilter` and the `CIColorKernel`/`CIKernel` matrix), C6 (EDR 1.85254 / 2.68750; gamut-mapping negatives; `render(_:toBitmap:)` SIGTRAP), C8 (12 MP proof from SDK rules + WWDC26-304), C9 (`photoQualityPrioritization == .speed` at construction), §10.1 (`supportedCameraModels` 934 entries, no `"iPhone13,3 back camera"`), §10.12 (`CIRAWDecoderVersion9/9DNG` in the 26.5 header), OQ1 (simulator has **zero** capture devices), OQ4 (fixture is ProRAW/LinearRaw — the biggest open gap).
01 F1/F2/F6/F12/F13/F16 · 02 D2/D4/D5/D6/D9/D17/D20/D21 · 03 P0-1…P0-8/P1-9…P1-14/P2-15…P2-19 · 04 P0-2/P0-4/P1-5/P1-7/P1-8/P2-11 · 05 §B/§E (measured contrast ratios and hit targets behind U2/U3/U4/U5/U15/U16).