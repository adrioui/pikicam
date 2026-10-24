# 05 — UI/UX audit of pikicam, and what the UI/UX should be instead

**Type:** RESEARCH. Not authority, not a spec — evidence and a target proposal.
**Repo:** `/Users/adrifadilah/Desktop/pikicam` @ `e5e976a` + uncommitted working tree (uncommitted work is *judged*, not preserved).
**Date:** 2026-10-02. **Build verified:** `xcodebuild -project pikicam.xcodeproj -scheme pikicam -derivedDataPath /tmp/pikicam-dd-r5 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` → `** BUILD SUCCEEDED **`.
**Design lint measured:** `xcodebuild test -only-testing:pikicamTests/DesignLintTests` → `Executed 26 tests, with 6 failures` and **777 design violations**.

Every code claim carries `file:line` and was read in this turn. External claims carry a URL. Anything I could not verify is marked **UNVERIFIED**.

---

## Summary — top 10 findings

1. **P0 — The app has essentially no camera.** For a product whose entire premise is "least-processed sensor data, developed by us", there is **no ISO, no shutter speed, no white balance, no manual focus, no focus peaking, no histogram, no clipping/zebra, no focus reticle, no AE/AF lock, no level/horizon, no lens (tele/ultra-wide) selection, no in-app image review.** The only exposure control is a ±3 EV bias on Apple's own auto-exposure (`CameraView.swift:41-52`, `CameraControls.swift:247-296`). Every competitor in §Benchmark ships ISO + shutter + WB as first-class. This is not a styling problem; the product does not exist at the UI layer.

2. **P0 — White-on-white: several controls are literally invisible against a bright scene.** `CameraHUDButton`'s caption text has **no backing at all** (`CameraHUDButton.swift:22-24`: `.foregroundStyle(.white.opacity(0.85))` is a sibling of the 44×44 circle, not inside it). White @85% over a white sky frame computes to **≈1.1:1 contrast**. The shutter is a pure white disc with no keyline (`ShutterButton.swift:16-22`) → invisible on snow/sky. The aperture-mask border is `.white.opacity(0.25)` 1pt (`CameraView.swift:389`) → invisible. The zoom/aspect chips are white on `black.opacity(0.5)` (`CameraView.swift:142,161`), which over a white sky composites to `#7F7F7F` → **3.98:1**, failing WCAG AA 4.5:1. This violates WCAG 2.2 SC 1.4.3 (https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html).

3. **P0 — Zero accessibility conformance, measured by grep, not opinion.** Across all of `pikicam/`: **0** uses of `relativeTo` / `dynamicTypeSize` / `minimumScaleFactor`, **9** hard-coded `.font(.system(size:))` calls (`RootView.swift:64,93`; `CameraHUDButton.swift:18,23`; `CameraView.swift:133,157,440,482`; `ZoomIndicatorView.swift:10`); **0** haptics; **0** `accessibilityReduceMotion` / `colorSchemeContrast` / `reduceTransparency` / `legibilityWeight`; **0** `minWidth`/`minHeight`; **0** `safeAreaInset` / `safeAreaPadding` / `safeAreaLayoutGuide`; **0** `accessibilityAdjustableAction` / `accessibilityAction` / `accessibilityHidden` / `accessibilitySortPriority`. Screenshot `03-permissions-dynamic-type-ax5.png` shows the consequence: at AX5 the marketing claim *"No AI. No computation. Just light."* is truncated away entirely behind an ellipsis.

4. **P0 — The layout lies about what will be captured.** The aspect-ratio aperture mask is computed over the **full physical screen** (`CameraView.swift:34-38` `.ignoresSafeArea()` → `FramingOverlays` → `PrintCrop.rect(in: bounds)`), but the chrome (chips + aspect strip + dock + zoom indicator) is drawn **on top of the lower ~190 pt of that same aperture** (`CameraView.swift:123-230`). On a 402×874 pt device at 16:9 the aperture is y∈[80, 794]; the chrome covers y∈[688, 874]. **~26 % of the "chosen" frame is behind the controls**, and the develop-time `PrintCrop` (`CameraControls.swift:180-186`) will crop exactly that aperture. Separately, at zoom ≥ 1 the capture silently reverts to 1× and crops (`CaptureService.swift:518-531`, referenced by `docs/prompt-next.md:519-530`) — so the `2.0x` chip promises detail the file does not contain, with a visible FOV snap and no explanation.

5. **P1 — There is no feedback during capture, and the only "progress" indicator is a greyed shutter.** `CameraViewModel.Phase` (`.idle/.countdown/.capturing/.savingDNG`, `CameraViewModel.swift:20-29`) drives exactly one visual change: `ShutterButton.isCapturing` → `.disabled` + 30 % veil (`ShutterButton.swift:24-31`). No word, no progress, no blackout, no thumbnail change. Apple Camera and Halide both give an unmistakable shutter-press confirmation. Here a user pressing the shutter sees a ~1–3 s pause and can only guess.

6. **P1 — Orientation is enabled and completely unhandled.** `project.yml:53` declares `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone: "Portrait LandscapeLeft LandscapeRight"`. The layout is a single portrait `VStack` with `Spacer()`s (`CameraView.swift:106-231`); the preview layer rotation is a **hard-coded `90`** default that is never overridden (`CameraPreview.swift:16`, and `CameraView.swift:77-83` never passes `rotationAngle`); the HUD cluster is `.padding(.trailing, 20).padding(.top, 8)` (`CameraView.swift:274-275`), which collides with the relocated Dynamic Island in landscape. Rotating the phone produces an undesigned, partially sideways screen.

7. **P1 — The "design system" is a lint allowlist for files that do not exist.** `pikicam/Core/Design/` contains **two** files totalling 212 lines: `Room.swift` (an `enum { black, white }` + an `EnvironmentKey`) and `ControlIDRegistry.swift` (a string registry). The five files the lint's own allowlist names as the token layer — `ChromeInk.swift`, `ChromeType.swift`, `ChromeRule.swift`, `Tack.swift`, `WordControl.swift` (`DesignLintTests.swift:222-229`) — **do not exist**. `ControlIDRegistry` is referenced by **no view**. There is no color token, no type token, no spacing token, no control component.

8. **P1 — The design lint is broken in three separate ways and is measuring noise.** Measured run: **777 violations across 51 source lines**, and **6 of its own 26 tests fail**. Specifically: (a) the 44 pt checker can never succeed — `TapTarget.declaredMinimums` matches the regex but then `Double(":44")` → `nil`, so **every** hit is reported as `tapTargetBelow44 — 0.0pt` (the `min 44` assertion cannot ever be evaluated); (b) `testSFSymbolIsAViolation` fails because the symbol parser keeps the trailing paren (`iconInChrome — Image(systemName: "camera.aperture)")`); (c) `RoomCoverage` reports every one of the six declared screens as missing `.environment(\.room, …)`, because no view uses it. The CI comment claims "63 distinct violations"; the measured number is **777**.

9. **P1 — The design documentation is ~7 000 lines of prose describing a ~500-line SwiftUI app, and it contradicts itself on the things that matter.** `docs/.P.DESIGN.md` (767 lines) + five specs (1 024 lines) + three locked drafts (1 100 lines) + `VERIFICATION.md` + research artifacts. It carries **four mutually exclusive type scales** (resolved by fiat in `.P.DESIGN.md §0.5 #7`), a shutter shape that is circle in one spec and square in another, "words only / no icons anywhere" *versus* a product whose only affordances are icons, a white gallery that the code renders black, a "closed vocabulary" that its own verifier found to be open in three places (`VERIFICATION.md §3 #13`), a completeness gate that is **unsatisfiable** (`VERIFICATION.md §3 #11`), and two **fabricated** stylesheet token names (`VERIFICATION.md §3 #1`). It is a prompt for an agent, not a design.

10. **P1 — Latency and honesty are absent at the moment they matter most.** Saving a ~25 MB DNG to Photos goes through `libraryModel.save(dng)` (`CameraViewModel.swift:285`) with no timeout, no progress, and — if the app backgrounds during `savingDNG` — the result is silently dropped by the generation guard (`CameraViewModel.swift:146, 332-339`). The volume-button shutter is **dead at volume 0 and 1** (`VolumeButtonCaptureView.swift:59-63` guards on a non-zero delta that cannot occur at the rails) and fires the system volume HUD over the viewfinder (`VolumeButtonCaptureView.swift:9-11`). Nothing tells the user any of this.

---

## Screenshots — what actually renders

Built and installed on the iPhone 17 Pro simulator (iOS 26.5), granted `camera` / `photos` / `photos-add` via `xcrun simctl privacy`. Stored in `docs/workflow/research/screens/`.

| File | What it shows | Verdict |
|---|---|---|
| `01-launch-permissions.png` | `PermissionsView` at default content size | The whole onboarding surface: 72 pt SF Symbol in **system blue** (the `AccentColor` asset is empty — `pikicam/Assets.xcassets/AccentColor.colorset/Contents.json` has one universal entry and **zero colour values**), `.largeTitle.bold()` title, `.borderedProminent` Continue. Zero design language, zero token usage, and the one screen every user sees first is the stock iOS template. |
| `03-permissions-dynamic-type-ax5.png` | Same screen at **AX5** (`xcrun simctl ui booted content_size accessibility-extra-extra-extra-large`) | **The product's own claim is destroyed.** The body text becomes *"Honest photographs, one Bayer exposure at a time…"* — the second sentence *"No AI. No computation. Just light."* is truncated behind an ellipsis and never readable. The 72 pt glyph does not scale at all (`.font(.system(size: 72))`, `RootView.swift:64`), so it is now visually orphaned under 53 pt text. This is what "no Dynamic Type support" looks like, captured. |

**What could not be captured, and why.** The camera, gallery, and viewer cannot be reached in this environment:

- The simulator has **no camera device**, so `CaptureService` throws `CaptureError.cameraUnavailable` (`No back wide camera is available.`).
- `RootView` gates on `didRequestPermissions`, which is only flipped by tapping *Continue* (`RootView.swift:16-22, 25-29`). The auto-skip path `.task { if viewModel.hasRequiredAuth { … } }` (`RootView.swift:31-35`) **did not fire** even with `kTCCServiceCamera|Photos|PhotosAdd = 2 (allowed)` verified in the simulator's `TCC.db` — so in practice, on the simulator, *every* launch stops on the welcome screen and the camera chrome cannot be photographed. **UNVERIFIED cause** (candidates: `PHPhotoLibrary.authorizationStatus(for: .readWrite)` returning `.notDetermined` on a simulator whose Photos daemon has never run, versus a `.task` timing race). **This is itself a finding** — see **D-14**.
- There is no tap injection available headlessly (`System Events` cannot see the Simulator window in this session; `xcrun simctl io` has no tap verb), and `pikicamUITests` **cannot be run**: the checked-in scheme (`pikicam.xcodeproj/xcshareddata/xcschemes/pikicam.xcscheme`, uncommitted-modified) lists only `pikicamTests.xctest`, so
  `xcodebuild test -only-testing:pikicamUITests/…` fails with *"Tests in the target “pikicamUITests” can’t be run because “pikicamUITests” isn’t a member of the specified test plan or scheme."* — **P0 for CI, see D-20.**
- Side effect of the same gap: `PikicamPipelineTests.testZeroRecipeReachesEveryControlOnARealFilter` **crashes the test host** on this SDK. Crash report `~/Library/Logs/DiagnosticReports/pikicam-2026-10-02-213234.ips`: `EXC_CRASH / SIGABRT`, `-[NSObject doesNotRecognizeSelector:]` at `PikicamPipelineTests.swift:566`, throwing out of the async test body. So the unit suite is also red — noted here only as evidence that "the tests are green" cannot be claimed anywhere.

---

## Detailed findings

Severity key: **P0** = ships a broken product / breaks an accessibility contract / lies to the user. **P1** = materially degrades the product or blocks the rewrite. **P2** = slop that must not survive the rewrite but does not break the product.

---

### A. Accessibility & platform conformance

#### D-01 · P0 · No Dynamic Type anywhere; the product claim is unreadable at AX sizes
**Evidence.** `grep -rn "relativeTo\|dynamicTypeSize\|DynamicTypeSize\|minimumScaleFactor" pikicam/` → **no matches**. Nine fixed sizes: `RootView.swift:64` and `:93` (`.font(.system(size: 72))`), `CameraHUDButton.swift:18` (`size: 17, weight: .medium`) and `:23` (`size: 11, weight: .medium, design: .rounded`), `CameraView.swift:133` (`size: 13, bold, rounded`), `:157` (`size: 12, bold, rounded`), `:440` (`size: 12, bold, rounded`), `:482` (`size: 96, bold, rounded`), `ZoomIndicatorView.swift:10` (`size: 15, medium, rounded`). Screenshot `03-permissions-dynamic-type-ax5.png` shows the body copy truncated. `.font(.body)` / `.caption` (which *do* scale) are used at `RootView.swift:71, 101` and `GalleryView.swift:124` — but those are the only scalable text in the app.
**Why it matters.** Apple HIG, Layout → Adaptability: *"Apps that don't respond to this setting can be difficult or impossible to use for people who rely on this feature"* (https://developer.apple.com/design/human-interface-guidelines/layout). The truncation in the screenshot is not cosmetic: at AX5 the only statement of what the product *is* becomes invisible.
**Fix direction.** Every text token goes through a `TypeScale` with `Font.system(size:relativeTo:)`. The countdown numeral gets `.minimumScaleFactor`; the viewfinder control rail gets a `ViewThatFits` compact variant; at `dynamicTypeSize >= .accessibility1` the app switches to a **compact-chrome** layout (see §Target UI, `T-9`).

#### D-02 · P0 · Contrast failures over the live preview — computed, not eyeballed
**Evidence + arithmetic** (WCAG 2.2 relative luminance, formula per https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html, threshold 4.5:1 normal / 3:1 large):

| Element | Code | Composited over a **pure white sky frame** | Ratio | Verdict |
|---|---|---|---|---|
| HUD button caption ("Grid"/"Flash"/"Timer"/"Camera") | `CameraHUDButton.swift:22-24` `.white.opacity(0.85)`, **no background** (the `black.opacity(0.45)` circle is on the sibling `Image`, `:19-21`) | text `#EEEEEE` on `#FFFFFF` | **≈1.10 : 1** | **FAIL — invisible** |
| Shutter disc | `ShutterButton.swift:16-22` white ring 4 pt + white fill 64 | `#FFFFFF` on `#FFFFFF` | **1.00 : 1** | **FAIL — invisible** |
| Aperture-mask border | `CameraView.swift:389` `.white.opacity(0.25)`, 1 pt | `#BFBFBF` on `#FFFFFF` | **1.63 : 1** | **FAIL** |
| Zoom / aspect chip (unselected) | `CameraView.swift:142,161` white on `black.opacity(0.5)` | `#FFFFFF` on `#7F7F7F` | **3.98 : 1** | **FAIL (< 4.5)** |
| EV value bubble | `CameraView.swift:439-445` yellow on `black.opacity(0.55)` | `#FFFF00` on `#737373` | **4.43 : 1** | **FAIL (12 pt bold is not "large")** |
| Zoom indicator capsule | `ZoomIndicatorView.swift:12-15` white on `black.opacity(0.45)` | `#FFFFFF` on `#8C8C8C` | **4.68 : 1** | pass, marginal |
| Countdown numeral | `CameraView.swift:482-486` white on `black.opacity(0.6)` | `#FFFFFF` on `#666666` | **5.74 : 1** | pass |
| Viewer chrome over a raw photo | `GalleryView.swift:191-212` default label colour, **no scrim** | indeterminate | — | **FAIL — unbounded** |
| Gallery error banner | `GalleryView.swift:121-135` `.ultraThinMaterial` + `.font(.caption)` | indeterminate | — | **FAIL — unbounded** |

**Why it matters.** This is the defining difference between a camera app and a picture of a camera app: the viewfinder is *adversarial content*. Every pro camera solves it with an **adaptive scrim + keyline**, not per-control opacities.
**Fix direction.** One `ScrimLayer` (see `T-4`) that always paints behind chrome, and a mandatory **dark keyline** (1–1.5 pt, `black @ 55 %` under `white`) on any element that must survive an arbitrary frame — including the shutter and the focus reticle.

#### D-03 · P0 · Hit targets below the platform minimum, with no 44 pt contract
**Evidence.** `grep -rn "minWidth\|minHeight" pikicam/` → **no matches** anywhere. Measured geometry: zoom chips are `13 pt` text + `.padding(.horizontal, 10).padding(.vertical, 6)` (`CameraView.swift:133-139`) ≈ **29 pt tall**; aspect chips `12 pt` + `12/6` padding (`CameraView.swift:157-160`) ≈ **28 pt**; the EV slider column is `.frame(width: 40)` (`CameraView.swift:437`); the gallery toolbar buttons are bare `Image(systemName:)` with **no frame at all** (`GalleryView.swift:36, 42`) and the viewer's eye/trash are bare glyphs (`GalleryView.swift:197, 201`) ≈ **17–22 pt**. `CameraHUDButton.swift:19-20` does apply a 44×44 frame — but only to the `Image`, while the `VStack`'s `Text` caption extends the button's own hit area asymmetrically.
Apple's platform minimum is 44 pt (HIG Layout / Accessibility; corroborated by WCAG 2.2 SC 2.5.5 "Target Size (Minimum)" at 24×24 CSS px — https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html — where Apple's 44 pt is the stricter, correct figure for touch).
**Why it matters.** A missed tap on a 28 pt chip lands on the preview → silently triggers tap-to-meter and re-opens the EV slider. That is a *wrong-photo* failure mode, not a nuisance.
**Fix direction.** A single `HitTarget` modifier (`.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())`) applied by construction, plus a lint that **fails** when a tappable control lacks it.

#### D-04 · P0 · VoiceOver: the camera is unusable and the viewer has a dead end
**Evidence.**
- **Gallery:** `grep -c accessibilityLabel pikicam/Features/Gallery/GalleryView.swift` → **0**. Every grid cell is `Button { AsyncThumbnail }` whose label is an `Image(uiImage:)` or a grey `Rectangle` (`GalleryView.swift:108-115`). VoiceOver announces "Button, image" per cell, with no index, no date, no count — although `PikicamCapture` already carries `capturedAt`, `aspectRatio`, `zoomFactor` (`PhotoLibraryManager.swift:98-110`).
- **Controls announce state, never action:** `CameraHUDButton.swift:27-29` sets `.accessibilityLabel(label)` + `.accessibilityValue(value)`. Flip announces *"Camera, Back"* — the destination action is never spoken.
- **Zoom indicator has a value with no label:** `ZoomIndicatorView.swift:16-17` sets identifier + value only; VoiceOver says a bare `"1.0x"`.
- **EV slider is not adjustable:** `CameraView.swift:448-451` sets label + value + `accessibilityElement(children: .ignore)`, but there is **no** `accessibilityAdjustableAction` and no `.isAdjustable` trait. VoiceOver users cannot change exposure at all.
- **Viewer dead end (verified):** `GalleryView.swift:181-190` is `Color.clear.contentShape(Rectangle()).onTapGesture{…}` with only an `.accessibilityIdentifier` — an identifier does not make a `Color` focusable. The only exits (`viewer-chrome-toggle` `:199`, `viewer-back` `:210`) live inside `if !chromeHidden` (`:191`). Activating "hide chrome" therefore removes the *only* reachable exits.

**Fix direction.** Every control gets `label` = what it *does*, `value` = current state, `hint` = what happens. Every adjustable surface gets `accessibilityAdjustableAction`. The viewer chrome-toggle gets `.accessibilityAction(.escape)`. Cell labels: `"Capture 3 of 41, captured 30 September 2026 at 14:22, 4:3 at 1.0×"`.

#### D-05 · P1 · Zero haptics on a shutter
**Evidence.** `grep -rn "sensoryFeedback\|UIFeedbackGenerator\|impactOccurred\|UIImpactFeedback" pikicam/` → **no matches**.
**Why it matters.** On a phone camera the shutter haptic *is* the confirmation that the press registered. Apple's Camera app fires one on every capture; every pro camera app uses detents on every dial stop. Its absence here is the single most "uncanny-valley" thing about the current feel, and it is invisible in screenshots.
**Fix direction.** `.sensoryFeedback` at five points: shutter press (`.impact(weight: .medium)`), capture committed (`.success`), capture failed (`.error`), every dial/stepper detent (`.selection`), clipping crossing into warning (`.warning`). All honour the system haptics switch automatically.

#### D-06 · P1 · Reduce Motion / Increase Contrast / Reduce Transparency / Differentiate-Without-Color are all unhandled
**Evidence.** `grep -rn "accessibilityReduceMotion\|colorSchemeContrast\|reduceTransparency\|legibilityWeight\|accessibilityDifferentiateWithoutColor" pikicam/` → **no matches**.
**Why it matters.** The app uses `withAnimation(.easeInOut)` unconditionally (`CameraView.swift:96, 100`), `.ultraThinMaterial` unconditionally (`GalleryView.swift:131`), and `Color.yellow`/`Color.red` as the *only* selected/failure signals (`CameraView.swift:142, 161, 192, 441`; `GalleryView.swift:37, 43`). A user running Reduce Motion gets motion they asked not to have; a user running Differentiate Without Color cannot distinguish a selected chip from an unselected one, because yellow-vs-grey is the entire difference.
**Fix direction.** All three switches become token inputs (`T-2`), and every selected/selected-on state carries a **second, non-colour cue** (weight + a filled/outlined geometry change).

#### D-07 · P1 · The app hard-forces dark appearance
**Evidence.** `PikicamApp.swift:24` `.preferredColorScheme(.dark)` at the `WindowGroup`, and again `GalleryView.swift:69`.
**Why it matters.** It overrides a system-level accessibility preference with no recourse, and it makes the *gallery* dark — which, for a photography browser, is a defensible choice but not a defensible *root-level* one.
**Fix direction.** Remove both. Let the camera room be dark by construction (it already is — `Color.black.ignoresSafeArea()`, `CameraView.swift:26`) and let the gallery/viewer follow the system, with a token pair for each appearance. If a neutral surround is wanted for judging photographs, ship it as a **user setting** ("Neutral surround: on/off"), not a hard override.

---

### B. Camera screen — component-by-component

#### D-08 · P0 · The control surface of a "pro RAW camera" is five toggles and a zoom chip row
Present controls, exhaustively: grid toggle, torch "flash" cycle, self-timer cycle (`CameraView.swift:246-277`); zoom preset chips 1×/2×/5× (`:127-149`); aspect chips 4:3 / 16:9 / 1:1 (`:152-169`); a ±3 EV bias slider that only appears for 2.5 s after a tap (`:41-52, 89-102`); tap-to-meter (`:80-83`); pinch zoom (`:285-305`); volume-button shutter (`:221-226`); flip camera (`:209-215`).
**Absent:** ISO, shutter speed, white balance, focus mode/ring, focus peaking, focus loupe, histogram, highlight-clipping meter, false colour, level/horizon, AE/AF lock, focus/exposure reticle, lens (ultra-wide/tele) selection, in-app last-frame review, bracketing, long-exposure, RAW/process indicator per shot, frame-accurate shutter feedback.
**Why it matters.** See §Benchmark: Halide, Kino, Obscura, Leica LUX and Adobe Project Indigo all expose ISO + shutter speed + WB; Halide and Kino add focus peaking and a waveform/histogram; Obscura and Kino add manual focus. Apple is *adding* histograms, waveforms, focus peaking and manual focus in iOS 27 (secondary reporting, **UNVERIFIED** — see Sources). A RAW tool whose exposure is entirely delegated to Apple's AE is a JPEG camera with a `.dng` extension.
**Fix direction.** Build the manual control rail (see §Target UI, `C-3`) and make it a first-class, reachable, non-gesture-only surface.

#### D-09 · P0 · The zoom chip promises detail the capture does not contain
**Evidence.** Zoom chips select `viewModel.setZoom(preset)` (`CameraView.swift:130`) which sets `AVCaptureDevice.videoZoomFactor`; the developed output is cropped to that framing (`CameraControls.swift:180-186`, `PrintCrop`). But `CaptureService` captures at **1×** when zoom > 1 and restores afterwards (documented at `docs/prompt-next.md:519-530`, referencing `CaptureService.swift:518-531`), with a deliberate `250 ms` settle. So `2.0x` is a **crop of a 12 MP frame, not a 24 MP frame**.
**Why it matters.** The chip is labelled `2.0x` and reads as "more detail". It delivers "same detail, fewer pixels, then a visible FOV snap at the moment of capture". This is the product's core promise — least-processed, full-resolution sensor data — being quietly broken by the framing UX.
**Fix direction.** Either (a) capture at the actual zoom by switching `activeFormat` to the matching virtual/physical device, or (b) be explicit: label digital crops as such (`2.0× CROP`), surface the snap as a **transient state word** (`CAPTURING AT 1× · RESTORING`), and — crucially — **never label a crop as a magnification**.

#### D-10 · P1 · Tap-to-meter has no reticle, and the EV slider can vanish mid-drag
**Evidence.** `CameraView.swift:80-83`: a tap calls `presentExposureSlider()` **and** `setFocusAndExposure(at:)`. `setFocusAndExposure` draws nothing (`CameraViewModel.swift:214-223` → `CaptureService.setFocusAndExposure` sets `focusPointOfInterest`/`exposurePointOfInterest` and nothing else). The only feedback is a 2.5 s timer-backed EV slider (`CameraView.swift:96-101`).
**Why it matters.** A photographer who taps to focus and sees *an exposure slider* will reasonably conclude either that the app ignored the tap or that the app does not understand focus. And the auto-dismiss (`Task.sleep(for: .milliseconds(2500))`, `:98`) will fire **during a slow deliberate drag**, committing a half-dragged value.
**Fix direction.** A reticle at the tap point with a focus-distance readout, an AE/AF-lock badge, and the slider dismissal gated on "not currently dragging" rather than a wall-clock timer.

#### D-11 · P1 · The shutter is not a state machine
**Evidence.** `ShutterButton.swift:24-31`: a black circle at 30 % opacity plus `.disabled`. During `.countdown`, `CameraViewModel.capture()` routes a shutter press to `cancelCapture()` (`CameraViewModel.swift:251-253`) — so **the shutter silently cancels the timer with no affordance**. The countdown itself (`CameraView.swift:476-492`) is a 96 pt numeral on a black-0.6 disc whose doc comment claims *"tapping anywhere on the screen cancels"* (`:474-475`) while the hit area is only the padded disc (`:487`).
**Why it matters.** "Press again to cancel" is a real camera convention (Blackmagic-style stop marks) but it must be *shown*. Right now a user arms a 10 s timer, presses at t=5 s expecting "fire now", and the capture dies silently.
**Fix direction.** Four distinct shutter presentations — ready / pressed / countdown-cancel (a `⏹` stop mark + `CANCEL` label) / in-flight (a ring progress + a one-frame blackout). Fix the comment or the behaviour; today both are wrong.

#### D-12 · P1 · Volume-button shutter is a trap
**Evidence.** `VolumeButtonCaptureView.swift:59-63` fires only when `abs(current - lastVolume) > 0.001`; `AVAudioSession.outputVolume` saturates at 0.0 and 1.0, so **volume-down at min and volume-up at max do nothing** — no capture, no feedback. The file's own header (`:9-11`) states the system volume HUD is **not** suppressed and the volume audibly changes. There is a 0.6 s debounce (`:53`) but no rail handling.
**Fix direction.** Two choices, both defensible: (a) **delete volume capture** — it is a niche convenience that costs a hidden `MPVolumeView`, a side effect on system volume, and a broken edge case; or (b) re-centre the slider to 0.5 on appear and after each trigger, and suppress the HUD by presenting the `MPVolumeView` on-screen-but-transparent. **My call: (a), delete it.** The on-screen shutter plus the Action Button / Camera Control is enough, and removing it removes a whole class of failure. If kept, it must be re-implemented with rail handling and a settings toggle.

#### D-13 · P1 · The aperture mask is computed over the wrong rectangle
See Summary item 4. **Evidence.** `CameraView.swift:34-38` applies `FramingOverlays` with `.ignoresSafeArea()`; `FramingOverlays` (`:348-370`) builds `PrintCrop.rect(in: bounds, zoomFactor: 1.0, aspect: aspectRatio)` from the **full** `GeometryReader`; the chrome (`CameraView.swift:123-230`) is drawn over the bottom of that same rect. On a 402×874 pt device: aperture y ∈ [80, 794]; chrome starts at y ≈ 688.
**Why it matters.** Two failures at once: (a) the dimmed "bands" promise to protect the frame edges but a quarter of the frame is *inside the controls*; (b) the develop-time crop (`PrintCrop`, `CameraControls.swift:180-186`) is applied to the DNG using the same numbers, so **what gets cropped is not what the user framed**.
**Fix direction.** Compute the aperture from the **chrome-free rect** (viewfinder inset between the top bar and the control rail), and pass that exact rect into both the overlay and the develop-time crop so the two are provably the same value.

#### D-14 · P1 · Permission gate: two prompts, no explanation, wrong recovery, and it strands the user
**Evidence.** `RootView.swift:16-29` shows one `Continue`; `:75-80` fires `requestAllPermissions()` which awaits camera **then** photos (`CameraViewModel.swift:118-122`) with no intermediate UI. `CameraViewModel.swift:101-102` explicitly comments *"`.restricted` (parental controls) must not be collapsed into a user denial"* — yet `RootView.swift:20-21` renders the **same** `PermissionsDeniedView` with an **"Open Settings"** button for every non-authorized state, including `.restricted`, where Settings cannot help.
Observed on the simulator: with camera+photos+photos-add all granted in `TCC.db`, the auto-skip `.task { if viewModel.hasRequiredAuth { didRequestPermissions = true } }` (`RootView.swift:31-35`) **did not advance the UI**, so the app sat on the welcome screen across four cold launches (cause **UNVERIFIED** — see Screenshots). Whatever the cause, the practical result is that `hasRequiredAuth` gating is not a reliable predicate for "can we start".
**Why it matters.** Permissions are the highest-stakes UI in the app: a wrong state here means the camera never opens, with no recourse but reinstall.
**Fix direction.** Per-permission states (`.notDetermined / .granted / .denied / .restricted / .limited`) surfaced individually, each with its own correct remedy; a "limited" notice that tells the user their captures may be hidden; no dead "Open Settings" for `.restricted`; and a `CameraAvailability` state (`.idle / .requesting / .ready / .interrupted / .unavailable(reason) / .failed(error)`) that the UI renders as a first-class screen rather than a bare black frame with a red caption.

#### D-15 · P1 · Error surfaces are unspeakable and undismissable
**Evidence.** `CameraView.swift:233-239`: `Text(error.localizedDescription)` in `.caption` `.foregroundStyle(.red)`, rendered **after** the dock with no bottom padding — i.e. at the very bottom edge, under/near the home indicator — and **outside** the `viewModel.isConfigured` gate, so it can paint over a viewfinder that has not configured. It is cleared only by the next shutter press (`CameraViewModel.swift:255`).
Gallery: two different presentations for the same destructive action — `confirmationDialog` (`GalleryView.swift:51-53`) for the grid, `.alert` (`:216-228`) for the viewer. The viewer's develop failure (`:169-176`) is a terminal `ContentUnavailableView` with **no Retry and no Dismiss**. Two different surfaces both claim `.accessibilityIdentifier("gallery-error")` and `("gallery-retry")` (`:87, :134` and `:95, :128`) → ambiguous queries.
**Why it matters.** An error a user cannot read, cannot dismiss, and that changes behaviour on an unrelated later action is worse than no error.
**Fix direction.** One `ErrorSurface` component: readable reason, a primary action (`RETRY` / `OPEN SETTINGS`), a secondary (`DISMISS`), placed inside the safe area, and cleared by an explicit action as well as by the next capture.

#### D-16 · P1 · The last-frame thumbnail is stale, ambiguous, and lies about saving
**Evidence.** `CameraView.swift:180-183` renders `library.captures.first`, **not** the capture that just completed; `ThumbnailImage` (`:309-336`) swallows load errors to `nil` (`:330-333`) so *failure* renders identically to *empty*. There is no in-flight state during `.savingDNG`. The badge is a yellow `photo.on.rectangle` caption (`:190-193`).
**Why it matters.** After a 1–3 s capture-and-save the user looks at the one element that says "it worked" and sees the *previous* photo. That is the definition of untrustworthy feedback.
**Fix direction.** Drive the thumbnail from a `CameraSessionState.lastCapture` published at shutter press; show an explicit optimistic frame + `SAVING` state; distinguish `loading / loaded / failed(RETRY)`.

---

### C. Gallery & viewer

#### D-17 · P0 · The viewer has no legibility strategy and two ~20 pt buttons
**Evidence.** `GalleryView.swift:191-212` is a bare `VStack` of `Text("DNG Viewer")` (`:194`, default font, left-aligned behind a `Spacer()`) and two bare `Image(systemName:)` buttons (`:197` eye/eye.slash, `:201` trash) with **no frame, no contentShape, no scrim, no tint** — drawn directly over the photograph (`:166-168`, `scaledToFit().ignoresSafeArea()`). `CameraHUDButton.swift:18-20` shows what the same team knew to do elsewhere: a 44×44 frame.
Also `hasConsumedOpeningTap` (`:159, 183-188`) swallows the first tap after presentation — a documented-but-unexplained hack that exists purely because the tap-catcher sits under the button that opened it.
**Fix direction.** Opaque bars (not floating glyphs), 44 pt targets, tabular numeric readouts, no first-tap swallow (use a tap target that is not under the presentation point).

#### D-18 · P1 · Grid: unlabelled, unselectable, position-identified, and the wrong back affordance
**Evidence.** `GalleryView.swift:106-118`: `GridItem(.adaptive(minimum: 100), spacing: 2)` with 2 pt gutters and a 2 pt inset — cells are ~100–130 px of noise-dense thumbnails separated by 2 px, on black. Cells are identified by `gallery-cell-\(index)` (`:115`) while `PhotoLibraryManager.swift:57-58` documents that selection and paging are by `CaptureID`. The "back to camera" affordance is a yellow `Image(systemName: "camera")` on the **trailing** side of a toolbar (`:42-45`), which is not an iOS convention for "leave this screen"; there is no `dismiss` affordance in the navigation bar. The toolbar holds a 60×50 thumbnail (`:25-26`, `RoundedRectangle(4)`) that duplicates grid cell 0 — which is separately requested from PhotoKit, with `isNetworkAccessAllowed = true`.
**Fix direction.** 3 columns portrait / 5 landscape, 2 pt gutters (keep), cells identified by `CaptureID` with an index *alias*, a leading `Done`/chevron-back, and an `NSCache`-backed thumbnail layer with `isNetworkAccessAllowed = false` for grid tiles.

#### D-19 · P1 · Deleting from the viewer blanks the screen
**Evidence.** The cover's content is gated on `library.selectedCapture` (`GalleryView.swift:56-68`), but `PikicamLibraryModel.deleteSelected()` sets `selectedCapture = nil` **before** awaiting `refresh()` (`PikicamLibraryModel.swift:54-63`), and only then does the viewer set `isPresented = false` (`GalleryView.swift:219-222`). For the duration of the Photos round-trip the user stares at an **empty full-screen cover** — no image, no chrome, no exit.
**Fix direction.** Hold the presented capture in the viewer's own state; dismiss first, then delete; surface delete failure *inside* the viewer.

#### D-20 · P1 · The gallery has no settings, no share, no import, no way to reach anything else
**Evidence.** `GalleryView.swift:17-47` has exactly two toolbar items. There is **no** `ShareLink` anywhere in `pikicam/` (grep: none) — a pro RAW tool that cannot export the DNG is a viewer, not a tool. There is no Settings screen at all: every control is a HUD cycle with no persistent, discoverable home.
**Fix direction.** `SHARE` (exports the **original untouched DNG**, per the product claim) and a `Settings` entry point (grid style, level unit, clipping threshold, calibration target, haptics, volume-shutter on/off).

---

### D. The in-progress design system, lint, and CI

#### D-21 · P0 · The design system is two enum-shaped files and five files that do not exist
**Evidence.** `ls pikicam/Core/Design/` → `ControlIDRegistry.swift` (180 lines), `Room.swift` (32 lines). `Room.swift` defines `enum Room { case black, white }` + an `EnvironmentKey` + an `EnvironmentValues` extension. `ControlIDRegistry.swift` defines `struct ControlID` + a string registry of 28 identifiers.
The lint's allowlist (`DesignLintTests.swift:222-229`) names six files as "the token layer":
`pikicam/Core/Design/{ChromeInk,ChromeType,ChromeRule,Tack,WordControl}.swift` (+ `Room.swift`). **Five of the six do not exist.** There is no colour resolution, no type resolution, no spacing scale, no control component, no `Tack`, no `WordControl`.
`grep -rn "ControlIDRegistry" pikicam/` outside `Core/Design/` and `pikicamTests/` → **no matches**. No view consumes it.
**Verdict.** There is no design system. There is a *proposed* one (in the `DesignViolation` enum and the `.P.DESIGN` doc) and a *lint* that asserts the proposal. The 212 lines that do exist are inert.
**Fix direction.** Either build the four/five real files or delete the registry and the lint. **Recommendation: build a minimal, real token layer** — but 4 files, not 12, and no `Tack`.

#### D-22 · P0 · The lint reports 777 violations, 6 of its 26 tests fail, and two of its rules are provably broken
**Evidence (measured).** `xcodebuild test -only-testing:pikicamTests/DesignLintTests` →
`Executed 26 tests, with 6 failures`, failure message `777 design violation(s)`.

| Rule | Count |
|---|---|
| `forbiddenColor` | 343 |
| `missingIdentifier` | 153 |
| `rawRoundedType` | 105 |
| `capsuleOrCircleShape` | 105 |
| `iconInChrome` | 56 |
| `tapTargetBelow44` | 15 |

Only **51 unique source lines** are implicated. Failing tests:
- `testSFSymbolIsAViolation` — the symbol extractor keeps the trailing paren. Log: `iconInChrome — Image(systemName: "camera.aperture)")`. Bug at `DesignLintTests.swift:283-289`.
- `testTapTargetMinimumIsEnforced` and `testTapTargetRequiresBothAxes` — `TapTarget.declaredMinimums` matches `minWidth\s*:\s*(\d+)` but then does `Double(text[r].dropFirst(key.count).trimmingCharacters(in: .whitespaces))`, i.e. it parses the **whole match minus the key**, which yields `":44"`, not `"44"`. `Double(":44")` is `nil`, so `values` is always empty and **every** hit is emitted as `tapTargetBelow44 — 0.0pt`. The 44 pt rule therefore **cannot ever be satisfied or correctly violated**. Bug at `DesignLintTests.swift:397-419`.
- `RoomCoverage` reports all six declared screens (`RootView`, `PermissionsView`, `PermissionsDeniedView`, `CameraView`, `GalleryView`, `FullScreenViewer`) as missing `.environment(\.room, …)`, because no view uses it.

Additional rule-quality problems: `ForbiddenPattern.violations` fires `rawRoundedType` **twice** on any line containing `design: .rounded` (once for the literal, once for the generic `.system(` check) — inflating counts; the `capsuleOrCircleShape` loop calls `LintAllowlist.isAllowedShape("Rectangle", …)` **regardless of which shape matched** (`DesignLintTests.swift:294-301`), so the allowlist is consulted with the wrong argument; and `isAllowedShape` returns `false` for `Rectangle` outside three non-existent files, meaning every `Rectangle()` in the app is a violation by a rule nobody wrote.
`.github/workflows/design.yml:9-11` claims *"the lint runs 26 tests and reports 63 distinct violations"* — **measured: 777**. The CI comment is wrong by more than an order of magnitude.
**Fix direction.** Delete the regex lint. Replace it with (a) a **compile-time** contract (the token layer is the only way to get a `Color`/`Font`, enforced by making raw literals unavailable via an opaque `Palette` type), (b) a **runtime** accessibility snapshot suite (contrast + AX5 + Reduce Motion × rooms), and (c) a handful of SwiftLint-style structural rules that are actually about defects (no `.font(.system(size:` without `relativeTo`; no `Image(systemName:` without an adjacent `accessibilityLabel`; no `Button` without a 44 pt frame). A lint that cannot parse is worse than no lint.

#### D-23 · P1 · `verify-design.sh` mutates tracked files and double-runs xcodegen
**Evidence.** `scripts/verify-design.sh:27-28` runs `xcodegen generate`, then `:31-38` fails if `git diff --quiet -- pikicam.xcodeproj/project.pbxproj` reports drift. CI runs `xcodegen generate` **again** at `.github/workflows/design.yml:32`. The script checks only the **pbxproj**, not the **scheme** — and the scheme is precisely where the current drift lives (D-24). `DESTINATION` defaults to `name=iPhone 17` (`:47`) which does exist here, but the workflow hard-codes `runs-on: macos-15` while the deployment target is iOS 26.5 — a runner/Xcode mismatch waiting to happen.
**Fix direction.** One script. It generates, diffs **project + scheme + scheme-management**, runs the build and the tests, and reports. Nothing else.

#### D-24 · P1 · The scheme no longer contains the UI test target, so the UI suite is dead
**Evidence.** `grep BuildableName pikicam.xcodeproj/xcshareddata/xcschemes/pikicam.xcscheme` → only `pikicamTests.xctest` under `TestAction`. `xcodebuild test -only-testing:pikicamUITests/SmokeLaunchTest/testLaunchAndCameraUnavailableErrorShown` → `error: Failed to build project pikicam with scheme pikicam.: Tests in the target "pikicamUITests" can’t be run because "pikicamUITests" isn’t a member of the specified test plan or scheme.` Yet `project.yml:86-99` declares both targets under `schemes.pikicam.test.targets`. **Regenerating the project from `project.yml` would restore it** — which is precisely what `verify-design.sh` claims to guard and does not.
**Why it matters.** 812 lines of UI walkthrough — the only test that would have caught the permission-gate, gallery, and viewer defects above — have been silently not running.
**Fix direction.** Regenerate; make the drift check cover the scheme; make "UI tests executed > 0" an explicit gate exactly as `verify-design.sh:59-66` already does for the design lint.

#### D-25 · P1 · The UI-test contract has already been broken on purpose, in one direction only
**Evidence.** `docs/design/VERIFICATION.md §4` records six identifier expectations in `SmokeLaunchTest.swift` that the views do not render (`camera-shutter` vs no identifier at all; `camera-library` vs `gallery-thumbnail`; `room-shoot` vs `gallery-camera`; `viewer-hide-show` vs `viewer-chrome-toggle`; `LIBRARY` vs `"Library"`; `0 / NO CAPTURES` vs `"No captures"`). The tests were rewritten to the new design; the views were not. I re-verified the view side and it is unchanged: `GalleryView.swift:45` `gallery-camera`, `:49` `"Library"`, `:99` `"No captures"`, `:199` `viewer-chrome-toggle`; `CameraView.swift:196` `gallery-thumbnail`; `ShutterButton.swift:31-33` label only, **no identifier**.
**Fix direction.** The rewrite replaces both sides simultaneously. Do not "make the tests pass" by renaming identifiers in the views to match an unreleased design; define the identifier contract once and let both the views and the tests read it.

---

### E. Design documents — judgement

`docs/.P.DESIGN.md` (767 lines), `docs/design/spec-*.md` (1 024), `docs/design/locked/draft-*.md` (1 100), `docs/design/VERIFICATION.md` (213), `docs/design/research/*` (821), `docs/prompt-next.md` (1 844). **~5 800 lines of design prose for ~1 900 lines of SwiftUI.** Judge from first principles:

**What earns its place (keep the *knowledge*, not the prose):**
- The observation that the code is the only authority, and that doc/code mismatch is itself a defect (`.P.DESIGN.md §0.1 R1/R3`). Correct and rare.
- The provenance discipline `OBSERVED / DERIVED / PROPOSAL` (`§0.1 R7`). Correct and cheap.
- The 37-state matrix (`docs/design/spec-state-matrix.md`). The *inventory* of unhandled states is real and matches what I found independently (interruption, restricted, limited-grant, storage-full, thermal, rotation-mid-capture).
- The identifier registry idea (`ControlIDRegistry.swift`) — as a concept, with the house-name and 28-entry word-list removed.
- The correctness findings in `VERIFICATION.md §3` — e.g. the completeness gate being **unsatisfiable** (§3 #11), the **fabricated** `--color-mm-base-strong-grey` / `--color-mm-base-light-grey` token names (§3 #1), the "closed vocabulary" that is not closed (§3 #13). These are good, and they are arguments for *less* design prose, not more.

**What does not earn its place (delete):**
- **The Margiela premise, wholesale.** "No icons anywhere, words only" is the central ruling (`.P.DESIGN.md §0.3 #8`). It is self-defeating for a camera: the shutter, the grid, the focus reticle, the histogram, the level, the lens selector — none of these have a good word. Halide, Apple, Kino, Obscura, Leica LUX, Indigo all use icons or dials. The repo's own embedded critic already reached this ("Tracked-out uppercase words are not anonymity — *it is a shouting foreman*", `§9.3d`). Words-only also means the 11 pt Courier captions that D-02 shows are **invisible over a bright sky** — the aesthetic rule *causes* the accessibility failure.
- **The `Tack` (hand-sewn basting stitch) motif** (`§9.5`). It costs a `Canvas` per selected control, is deliberately non-deterministic per launch (which makes snapshot testing impossible — the doc itself requires determinism, `§9.5`, and then adds a per-launch seed), and buys nothing a photographer cares about. It is cosplay.
- **The "blank tag" mark** (`§2.8`). Replaces the app icon with a blank rectangle.
- **The 6-token Courier-New scale as a *type system*.** Courier New is verified as an iOS system font, but at 11–13 pt over a photograph it has low stroke contrast and a small x-height; SF (the platform face, with `.monospacedDigit()` for every numeric) is the correct choice for a readout-heavy UI and is what every benchmark uses. If the owner wants a mono *voice*, use `Font.system(design: .monospaced)` — same skeleton, 2× the legibility. One token swap if the owner disagrees.
- **The 37-state completeness gate as written.** `VERIFICATION.md §3 #11` proves it is unsatisfiable; the fix is a state table with a real hit-area column, not more prose.
- **`DesignLintTests.swift`'s `Tack` allowlist and its house-name-derived rules.** The lint encodes a taste as a build failure. A build failure should encode a defect.
- **Four mutually exclusive type scales** (`.P.DESIGN.md §0.5 #7` admits this), the white-vs-black gallery contradiction, the portrait-vs-landscape contradiction, the shutter circle-vs-square contradiction.

**Net recommendation:** delete `docs/design/**` and `docs/.P.DESIGN.md` after extracting (a) the state inventory, (b) the identifier contract, (c) the identifier/test divergence list, and (d) the `baselineExposure` measurement recipe into the new implementation prompt. Keep `docs/prompt-next.md`'s findings appendix — it is the highest-signal document in the repo (real defects, real `file:line`, adversarial-vote annotated, and it honestly separates refuted from confirmed findings).

---

## What an excellent pro RAW camera UI should be

### Benchmark — what the good ones actually do

**Halide** (Lux Optics) — the closest product analogue, and the one that proves the concept is sellable.
- Layout, per their own tutorial: *"the ⓵ Viewfinder"*, *"the ⓶ Quickbar, where controls like the grid, capture formats, timer, and Halide settings live. It can be expanded and collapsed by swiping on it"*, and *"tap on the preview in the bottom-left corner to view the image and its corresponding metadata"* — https://luxoptics.zendesk.com/hc/en-us/articles/360001184131-An-Introduction-to-Halide
- Mode is visible as a **triangle at the top**: *"If you don't see controls to change exposure settings, you're probably in ‘Automatic’ mode. You can tell by the triangle on the top of the screen. Tap on the triangle and a panel will slide out, allowing you to enter manual mode."* — https://luxoptics.zendesk.com/hc/en-us/articles/360001012911-How-do-I-change-shutter-speed-ISO-or-aperture
- **Manual mode re-purposes the existing readout rather than adding a panel:** *"the top-right EV readout has changed to measure shutter speed. Adjusting shutter speed is now done by vertical swipes. Changing your ISO is as simple as swiping horizontally in the viewfinder."* — https://luxoptics.zendesk.com/hc/en-us/articles/360051436072-Fully-Manual
- **Focus is a dial, not a gesture:** swipe right to enter manual focus; *"You'll be presented with a dial that functions like a manual focus ring on a real camera lens."* Two aids: a **Focus Loupe** (magnifies the centre) and **Focus Peaking** (colours sharp edges) with *"Intelligent Activation"* — peaking only renders *"when you adjust focus, so you can see what your shot looks like without all that… green stuff."* — https://luxoptics.zendesk.com/hc/en-us/articles/360051909451-Manual-Focus
- **Histogram is a quickbar toggle, lives top-left, and cycles display mode:** *"The histogram will appear in the top left corner… tap the histogram icon again to make the histogram larger. Tapping it again will turn it off."* and *"You can also tap the histogram itself… to change its display mode. There's a luminance histogram…, a color histogram and an RGB waveform display."* — https://luxoptics.zendesk.com/hc/en-us/articles/360051435832-The-Histogram
- **White balance is a quickbar menu with presets** (AWB + named presets). — https://luxoptics.zendesk.com/hc/en-us/articles/360051909851-White-Balance
- **Process is a per-shot choice in the format picker**, and Process Zero pairs one JPEG/HEIC with one RAW: *"Process Zero, labeled 'RAW', will grab a 'regular' (JPG or HEIC) image as well as a RAW image. Don't worry, you don't get two shots: the RAW image will be stored together with the Process Zero shot."* — https://luxoptics.zendesk.com/hc/en-us/articles/360051909471-Choose-your-Process-and-shooting-in-RAW
- Marketing framing of the gesture model: *"Gestures are modeled after the intuitive manipulation of dials: swiping up and down for exposure, and left and right for focus."* — https://halide.cam/
- **Process Zero's product argument is the one pikicam should adopt verbatim in spirit:** *"the whole job of the algorithm is to take nine photos at different shutter speeds and pick the best of the bunch"* — i.e. **a multi-frame pipeline makes true shutter-speed control impossible**. That is the honest technical justification for a single-exposure RAW app, and it belongs in the app's own words somewhere other than a 72 pt icon. — https://www.lux.camera/introducing-process-zero-for-iphone/

**Kino** (Lux Optics, video) — *"a full manual mode, focus peaking, color waveform, audio meters"* — https://apps.apple.com/ph/app/kino-pro-video-camera/id6472380172

**Apple Camera** — ProRAW is a *Settings → Camera → Formats* choice with a `RAW` toggle in the capture UI (https://support.apple.com/en-in/guide/iphone/iphae1e882a3/ios). Secondary reporting says iOS 27 beta adds *exposure histograms, waveforms, manual focus, focus peaking* and a customisable control row at the top of the viewfinder ("Essentials" + an Edit button) — **UNVERIFIED, vendor/third-party reporting only** (https://www.megamobilecontent.com/news/2026/09/09/ios-27-camera-histograms-focus-peaking-variable-aperture/, https://www.macrumors.com/how-to/ios-set-up-controls-camera-app/). **The lesson stands regardless: Apple is moving toward exactly the controls pikicam lacks.**

**Leica LUX** — *"removes all other distractions"*, full manual exposure/focus/WB, plus a physical LUX Grip that maps app functions onto real controls (https://leica-camera.com/en-int/photography/leica-apps/leica-lux, https://www.snapsbyfox.com/blog/leica-lux-app-lux-grip-overview-settings).

**Obscura** — praised for *"its intuitive design"* and *"Its minimal interface stays out of the way"* (https://www.macstories.net/reviews/obscura-2-review-an-approachable-manual-camera-app-with-tasteful-filters/); ships manual ISO, 12-bit RAW, hardware-accelerated focus peaking (https://frameandfocal.com/camera-reviews/obscura-3-camera-app-is-a-major-update-with-new-modes-and-design).

**Adobe Project Indigo** — *"full manual controls, a more natural (‘SLR-like’) look, and the highest image quality that computational photography can provide — in both JPEG and raw formats"* (https://research.adobe.com/articles/indigo/indigo.html). Its differentiator is a **coaching layer over the viewfinder**, which is the closest thing to "teach while you shoot".

**Distilled rules — every one of these is satisfied by at least three of the seven, or by the platform:**
1. **The viewfinder is the product.** Chrome is a frame around it, never a curtain over it.
2. **Exposure parameters are values, not gestures.** ISO / shutter / WB are readable at a glance, always, and changeable three ways (tap, drag, stepper).
3. **Manual is a state you can see**, entered deliberately, never an accident of a swipe.
4. **The meter is the safety equipment**: histogram or waveform, clipping indicator, focus peaking.
5. **One place for everything**: a quick bar that expands, so the chrome count on the default screen stays low.
6. **Your last frame is the next thing you look at.**
7. **The app says what it did**, in numbers a photographer can act on.

---

## Target UI spec

### Principles

- **P-1 — The UI's job is to expose the decisions Apple would otherwise make, and to make their consequences legible.** Every control that exists must change a file we can point at.
- **P-2 — The preview is adversarial content.** Any overlay must be legible on a white sky and a black night. One adaptive scrim, one keyline rule. No per-control opacity guessing.
- **P-3 — No gesture is ever the only path.** Every dial has a stepper; every swipe has a button; every auto-dismiss has a persistent state.
- **P-4 — Motion is feedback, never decoration.** Suppressible to zero under Reduce Motion. Motion never carries information alone.
- **P-5 — Touch is a first-class output.** The shutter must be felt.
- **P-6 — One-handed.** Every control in the bottom 55 % of the screen; nothing essential top-leading.
- **P-7 — Monochrome chrome, colour photography.** Keep this — it is correct for a photo tool and it is what Apple's own apps do. Drop "no icons" and "radius 0": they destroy affordance and cause the D-02 contrast failures.

### Screens

| # | Screen | Purpose |
|---|---|---|
| `S0` | **Permissions** | Per-permission state + correct remedy. Not a marketing splash. |
| `S1` | **Camera** | The product. Portrait and landscape layouts from one layout description. |
| `S2` | **Quick settings** | Expandable sheet from the bottom: grid, aspect, timer, torch, clipping, peaking, level, lens, front/back. |
| `S3` | **Manual panel** | Swipe-in from the trailing edge: ISO, shutter speed, WB, focus. Values + steppers + dial. |
| `S4` | **Library** | Newest-first grid, multi-select, share, delete. |
| `S5` | **Viewer** | Full-bleed image, hideable chrome, provenance sheet, share original, zoom, page. |
| `S6` | **Settings** | Everything persistent that has no home on the camera screen. |

### `S1` Camera — layout zones (portrait; 402 × 874 pt reference)

```
┌─ safe-area top (Dynamic Island / notch) ────────────────────┐
│ Z0  TOP BAR  44pt + 24pt scrim                              │
│     leading : capture badge  [RAW·1×·AUTO]   (tap → S2/S3)  │
│     trailing: ⚡  ⏱  ▦  ⤢   44×44 each, holds slot          │
├────────────────────────────────────────────────────────────┤
│ Z1  VIEWFINDER  — the ONLY full-bleed element              │
│     ┌ Z1a HISTOGRAM + CLIPPING (top-leading, inside safe)  │
│     │       96×44, 1px rule, pure meter, no chrome         │
│     │ Z1b LEVEL / HORIZON (centre-top, 1px)                │
│     │ Z1c FOCUS RETICLE + AE/AF LOCK badge (tap point)     │
│     │ Z1d GRID thirds  |  Z1e ZEBRAS at ≥98% luma          │
│     │ Z1f APERTURE MASK — computed from the RECT BELOW,    │
│     │       never from the full screen (fixes D-13)         │
│     └──── Z1g SAFE FRAME 402 × (874−44−24−196) ────────┐   │
├─────────────────────────────────────────────────────────┤   │
│ Z2  CONTROL RAIL  56pt + 24pt scrim                      │   │
│     ISO 64 │ 1/250 │ EV +0.3 │ AWB 5200K │ AF/MF 2.4m    │   │
│     5 readouts, tabular, 44pt tall, tap → S3             │   │
├─────────────────────────────────────────────────────────┤   │
│ Z3  ACTION RAIL  64pt                                      │   │
│     lens 0.5× 1× 2× 3× 5×   (chips, crop labelled)        │   │
├─────────────────────────────────────────────────────────┤   │
│ Z4  DOCK  96pt  (inside `safeAreaInset(.bottom)`)         │   │
│     leading  LIBRARY thumbnail 64×64                      │   │
│     centre   SHUTTER  ⌀88 outer / ⌀72 inner               │   │
│     trailing FLIP  44×44                                  │   │
├────────────────────────────────────────────────────────────┤
```

**Landscape** (designed, not tolerated — `project.yml:53` already enables it): viewfinder full-bleed; **Z0** collapses to a single trailing cluster; **Z2 + Z3 + Z4** become a **right rail 120 pt wide** (readouts stacked, shutter at the bottom of the rail, thumb-reachable); the preview's `videoRotationAngle` is driven from the interface orientation (`CameraPreview.swift:16` stops being a hard-coded `90`).

### Controls — states

| Control | States | Feedback |
|---|---|---|
| **Shutter** `⌀88/⌀72` | ready · pressed (×0.94, 90 ms) · countdown (stop mark + `CANCEL`, tap cancels) · in-flight (progress ring, 1-frame black flash, button disabled) · failed (2 × `.error` haptic, ring turns `--fail`) | `.impact(.medium)` on press; `.success` on commit; `.error` on failure |
| **Focus reticle** `52 × 52` | absent · focusing (breathing) · locked (filled corner marks + `AE/AF LOCK` chip) · unsupported (dashed + hint) | `.selection` on lock toggle; persists across capture; clears on lens flip |
| **Histogram** `96 × 44` | off · luminance · RGB-parade · (tap cycles) | clipping turns the corresponding edge `--clip` (amber) and fires `.warning` once per transition |
| **Zebras** | off · `≥98 %` · `≥100 %` | drawn at 45° over clipped pixels only |
| **Level** | off · live | 1 px line, ±2° dead zone, turns `--warn` outside |
| **Manual rail** | `AUTO` / `MANUAL`; each of ISO, shutter, WB, focus has `.automatic` / `.locked` / `.unavailable(reason)` | `.selection` per detent; unavailable shows the device's limit, never disappears |
| **Action rail (lens)** | selected chip carries **weight + fill** (never colour alone) | crop vs optical is explicit in the label |
| **Aspect** | `4:3 · 16:9 · 1:1` | mask + label agree with the develop crop because both read `frameRect` |
| **Timer** | off · 3 s · 10 s | anchored deadline (`ContinuousClock`), cancellation is explicit and visible |
| **Torch ("flash")** | off · on | fires as a shutter-time pulse; label says `TORCH`, not `FLASH`, because that is what it is |
| **Grid** | off · 3×3 · 4×4 | `▦` filled vs outlined |
| **Library thumb** | empty · loading · loaded · `SAVING` · failed | optimistic frame at press; `SAVING` until the DNG commits |
| **Error surface** | reason + `RETRY` + `DISMISS` | inside the safe area, cleared by action *or* by the next shutter |

### Interactions

| Gesture | Effect | Equivalent button |
|---|---|---|
| Tap preview | focus + meter at point, show reticle + rail | `AF` toggle in `S3` |
| Double-tap reticle | toggle AE/AF lock | `AE/AF LOCK` chip |
| Vertical drag in `S1` | exposure compensation (live) | steppers in the rail |
| Horizontal drag from trailing edge | open `S3` | `MANUAL` button in `Z0` |
| Pinch | zoom, with a detent haptic at each preset | lens chips in `Z3` |
| Drag on a dial in `S3` | continuous ISO / shutter / WB / focus | steppers beside every dial |
| Swipe up on `Z0` capture badge | open `S2` | `⚙` in `Z0` |
| Double-tap viewer | fit ⇄ 2.5× at point | `FIT` / `ZOOM` words |
| Swipe viewer | page prev/next | `‹` `›` words |
| Swipe down in viewer | dismiss | `Done` |

### Accessibility (non-negotiable)

1. Every control: `accessibilityLabel` = **the action**, `accessibilityValue` = the state, `accessibilityHint` = the consequence. (`D-04`)
2. Every adjustable surface: `accessibilityAdjustableAction` at the natural detent. (`D-04`)
3. Minimum 44 × 44 pt, 88 pt shutter, enforced by construction. (`D-03`)
4. Every text token uses `relativeTo:`; at `dynamicTypeSize >= .accessibility1` the app switches to **compact chrome** (rail collapses to two-line stacked; dock shrinks to the essentials) and never truncates meaning. (`D-01`)
5. Contrast: every over-preview element resolves through `ScrimLayer` and carries a keyline; all pairs asserted against the WCAG formula in a unit test, not by eye. (`D-02`)
6. Reduce Motion → every duration `0`. Increase Contrast → hairlines 2 pt, secondary → primary ink. Reduce Transparency → scrims become opaque bars. Differentiate Without Color → selection keeps a geometry cue. (`D-06`)
7. VoiceOver rotor custom actions on `S1` and `S5`; `.accessibilityAction(.escape)` in the viewer; **the hidden-chrome state must never remove the only exit**. (`D-04`)
8. `accessibilitySortPriority` fixes a sane reading order (status → meters → dock).

### Minimal design token set

Justified from first principles: a camera needs **few** tokens because the preview supplies all the colour.

**`T-1` Colour — monochrome chrome + two reserved signals**
```
ink        #FFFFFF   over preview / #0A0A0A on paper      — primary
inkSecond  #FFFFFF @ 70% over scrim / #5C5C5C on paper    — 5.0:1 minimum, computed
rule       #FFFFFF @ 22% over preview / #D8D8D8 on paper   — 1 physical px
keyline    #000000 @ 55%                                — mandatory under any element over preview
scrimTop   #000000 0.55 → 0.0, 120 pt, localised           — the ONLY overlay scrim
scrimBottom#000000 0.0  → 0.62, 200 pt, localised
select     ink inverted block + Bold weight + 1 px outline — selection is never colour alone
clip       #FFB020                                          — highlight clipping ONLY
fail       #FF453A                                          — failure ONLY
```
*Justification.* One scrim layer replaces every `black.opacity(0.45/0.5/0.55/0.6)` in the current code and fixes D-02 by construction. `clip` and `fail` are the only colours, and they are reserved — never for selection, never for a chip. This is the one place where a design rule should be a *lint failure*: using `clip`/`fail` for anything but clipping/failure.

**`T-2` Appearance inputs** — `colorScheme`, `colorSchemeContrast`, `accessibilityReduceMotion`, `accessibilityReduceTransparency`, `accessibilityDifferentiateWithoutColor`, `displayScale`, `dynamicTypeSize`. Tokens are functions of these; no hard-coded literals outside the token file.

**`T-3` Type — 5 roles, SF with tabular digits**
```
readout   .system(size: 15, weight: .medium, design: .monospacedDigit())  relativeTo: .subheadline  ISO/shutter/EV/WB/focus values
label     .system(size: 13, weight: .medium)                            relativeTo: .callout      control labels
caption   .system(size: 11, weight: .regular)                            relativeTo: .caption      status, badges
title     .system(size: 17, weight: .semibold)                           relativeTo: .headline     screen titles
body      .system(size: 15)                                              relativeTo: .body         explanations, errors
```
*Justification.* Every numeric is tabular so it does not reflow during a dial drag. All five scale. SF is used over Courier New because it has ~20 % more x-height and markedly better stroke contrast at 11–13 pt over a photograph — the D-02 failure is *caused* by low-contrast small type. If the owner wants a mono voice, swap `design: .monospaced` in and change nothing else.

**`T-4` Spacing — `2 / 4 / 8 / 12 / 16 / 24 / 40`** plus two geometry constants (not spacing): `shutterOuter 88`, `shutterInner 72`, `barTop 44`, `barRail 56`, `barAction 64`, `dock 96`. All bottom placement goes through `safeAreaInset(.bottom)`; **zero hard-coded bottom padding**.

**`T-5` Radius — `10` for interactive controls (`Rectangle().cornerRadius(10, style: .continuous)`), `4` for chips, `0` for rules and data.** The shutter stays circular. *Justification.* The current "radius 0 everywhere" rule (`.P.DESIGN.md §2.5`) makes chips read as colour swatches rather than buttons, and combined with white-on-white it is part of why the chrome is invisible (D-02). A control needs a recognisable silhouette. Radius is a control affordance, not a personality.

**`T-6` Motion — three durations and one curve**
```
micro   90 ms  .snappy   — press, detent, chip selection
panel  200 ms  .easeOut  — reticle, slider, meter appear
sheet  320 ms  .snappy   — S2/S3/S5 presentation, viewer chrome
```
Reduce Motion → all `0`. No springs on state changes, no blinking anything, no shimmer, no parallax, no skeleton. *Justification.* Camera chrome must be instant; the only thing allowed to animate is the presentation of a panel.

**`T-7` Haptics — five, all via `.sensoryFeedback`:** shutter press `.impact(.medium)`, capture committed `.success`, capture failed `.error`, detent `.selection`, clipping `.warning` (once per transition).

---

## Open questions / assumptions

1. **ASSUMPTION — the manual-control decision (D-08).** I am asserting that a RAW camera app must expose ISO / shutter speed / WB. If the owner intends a fully automatic "point and shoot that happens to save a DNG", then D-08 is not a gap and the UI spec should be reduced to Halide's *Automatic*-mode equivalent. **This is the single decision that most changes the resulting app.** The evidence strongly favours manual control — the product is defined by *not letting the phone decide*, and without manual exposure the phone is still deciding everything.
2. **ASSUMPTION — digital zoom honesty (D-09).** I assume capturing at true optical/virtual zoom rather than a 1× crop is in scope. If the hardware cannot deliver it for a chosen lens, the UI must label crops as crops.
3. **ASSUMPTION — icons are allowed (D-21 critique).** The owner previously ruled "NO ICONS ANYWHERE". I have judged that ruling from first principles to be incompatible with a camera UI and with the accessibility contract, and my spec uses SF Symbols. **If the owner reinstates the icons ban, the spec still works — every icon has a text label next to it — but the affordance cost is real and D-02 gets worse, not better.**
4. **UNVERIFIED — iOS 27 Camera features.** All iOS 27 histogram/waveform/peaking/manual-focus claims come from secondary reporting, not Apple. The repo targets iOS 26.5. Treat as directional.
5. **UNVERIFIED — Apple shutter / dock / bar dimensions.** Apple publishes no pt values for Camera chrome; every size in `§Target UI` is a proposal justified against thumb reach and the 44 pt floor, not against an Apple figure.
6. **UNVERIFIED — the simulator permission auto-skip failure (D-14).** The observable fact is solid (TCC granted, UI did not advance, four launches). The cause is not established. It should be diagnosed on device before the permission flow is rewritten.
7. **ASSUMPTION — orientation.** I assume landscape is kept (it is already enabled in `project.yml:53`) and designed. If the owner prefers portrait-lock, that is a one-line `project.yml` change and removes D-06 entirely.
8. **ASSUMPTION — volume-button capture is deleted (D-12).** If kept, it needs rail handling and HUD suppression; the spec's `Z4` does not include it.
9. **NOT ASSESSED — the develop pipeline and capture pipeline.** Those are `docs/workflow/research/01-capture-pipeline.md` and `03-develop-pipeline.md`. Where I touch them (D-09, D-13) it is only through their UI-visible consequences.
10. **Scope note.** The design lint was measured but **not fixed**. It reports 777 violations; the target UI deliberately violates most of those rules (icons, radius, raw colours outside a non-existent token layer). The lint must be replaced, not satisfied.

---

## Sources

**In-repo (read in full this turn)**
`pikicam/App/PikicamApp.swift`, `pikicam/App/RootView.swift`, `pikicam/Features/Camera/{CameraView,CameraControls,CameraViewModel,CameraPreview,PreviewView,CameraHUDButton,ZoomIndicatorView,GridOverlayView,VolumeButtonCaptureView}.swift`, `pikicam/Features/Camera/Views/ShutterButton.swift`, `pikicam/Features/Gallery/{GalleryView,PikicamLibraryModel}.swift`, `pikicam/Core/Design/{Room,ControlIDRegistry}.swift`, `pikicamTests/DesignLintTests.swift`, `pikicamUITests/SmokeLaunchTest.swift`, `pikicam/Assets.xcassets/AccentColor.colorset/Contents.json`, `project.yml`, `scripts/verify-design.sh`, `.github/workflows/design.yml`, `README.md`, `docs/workflow/briefs/*`, `docs/.P.DESIGN.md`, `docs/prompt-next.md`, `docs/design/spec-{camera-screen-spec,design-system-tokens,gallery-viewer-spec,state-matrix,adaptivity-a11y}.md`, `docs/design/VERIFICATION.md`, `docs/design/locked/draft-camera.md`, `docs/design/locked/draft-gallery.md`.

**Measured locally**
- `xcodebuild … -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` → `** BUILD SUCCEEDED **`
- `xcodebuild test -only-testing:pikicamTests/DesignLintTests` → `Executed 26 tests, with 6 failures`, `777 design violation(s)`
- `grep` counts: hard-coded fonts `9`; `relativeTo|dynamicTypeSize|minimumScaleFactor` `0`; haptics `0`; reduce-motion/contrast/transparency env reads `0`; `minWidth|minHeight` `0`; `safeAreaInset|safeAreaPadding|safeAreaLayoutGuide` `0`; `accessibilityAdjustableAction|accessibilityAction|accessibilityHidden|accessibilitySortPriority` `0`; `accessibilityLabel` in `GalleryView.swift` `0`
- Screenshots: `docs/workflow/research/screens/01-launch-permissions.png`, `…/03-permissions-dynamic-type-ax5.png` (AX5 via `xcrun simctl ui booted content_size accessibility-extra-extra-extra-large`)
- Simulator TCC: `kTCCServiceCamera|kTCCServicePhotos|kTCCServicePhotosAdd = 2` for `piki.pikicam`
- Crash: `~/Library/Logs/DiagnosticReports/pikicam-2026-10-02-213234.ips` (`PikicamPipelineTests.swift:566`, `doesNotRecognizeSelector:`)

**External**
- Halide / Lux Optics support: [Introduction to Halide (layout)](https://luxoptics.zendesk.com/hc/en-us/articles/360001184131-An-Introduction-to-Halide) · [How do I change shutter speed, ISO, or aperture?](https://luxoptics.zendesk.com/hc/en-us/articles/360001012911-How-do-I-change-shutter-speed-ISO-or-aperture) · [Fully Manual](https://luxoptics.zendesk.com/hc/en-us/articles/360051436072-Fully-Manual) · [Manual Focus](https://luxoptics.zendesk.com/hc/en-us/articles/360051909451-Manual-Focus) · [Choose your Process and shooting in RAW](https://luxoptics.zendesk.com/hc/en-us/articles/360051909471-Choose-your-Process-and-shooting-in-RAW) · [The Histogram](https://luxoptics.zendesk.com/hc/en-us/articles/360051435832-The-Histogram) · [White Balance](https://luxoptics.zendesk.com/hc/en-us/articles/360051909851-White-Balance) · [Level Shots](https://luxoptics.zendesk.com/hc/en-us/articles/360051909571-Level-Shots) · [Action Button Triggers](https://luxoptics.zendesk.com/hc/en-us/articles/20056919567757-Halide-Action-Button-Triggers) · [The Halide Manual index](https://luxoptics.zendesk.com/hc/en-us/sections/360000282831-The-Halide-Manual)
- [Process Zero: The Anti-Intelligent Camera — Lux](https://www.lux.camera/introducing-process-zero-for-iphone/) · [Halide homepage](https://halide.cam/) · [Kino on the App Store](https://apps.apple.com/ph/app/kino-pro-video-camera/id6472380172)
- Apple: [Camera](https://halide.cam/) n/a → [ProRAW on iPhone](https://support.apple.com/en-in/guide/iphone/iphae1e882a3/ios) · [HIG Layout](https://developer.apple.com/design/human-interface-guidelines/layout) · [HIG Accessible appearance](https://developer.apple.com/documentation/swiftui/accessible-appearance) · [SensoryFeedback](https://developer.apple.com/documentation/swiftui/sensoryfeedback) · [accessibilityReduceMotion](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion)
- [Leica LUX](https://leica-camera.com/en-int/photography/leica-apps/leica-lux) · [LUX Grip overview](https://www.snapsbyfox.com/blog/leica-lux-app-lux-grip-overview-settings)
- [Obscura 2 review — MacStories](https://www.macstories.net/reviews/obscura-2-review-an-approachable-manual-camera-app-with-tasteful-filters/) · [Obscura 3 review — Frame and Focal](https://frameandfocal.com/camera-reviews/obscura-3-camera-app-is-a-major-update-with-new-modes-and-design) · [Obscura](https://www.obscura.app/obscura/)
- [Adobe Project Indigo — research.adobe.com](https://research.adobe.com/articles/indigo/indigo.html) · [Project Indigo FAQ](https://helpx.adobe.com/project-indigo/get-started/faq.html)
- Standards: [WCAG 2.2 SC 1.4.3 Contrast (Minimum)](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html) · [WCAG 2.2 SC 1.4.11 Non-text Contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html) · [WCAG 2.2 SC 2.5.5 Target Size (Minimum)](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html)
- **UNVERIFIED (secondary reporting only)** — iOS 27 Camera: [iOS 27 Adds Histograms and Focus Peaking](https://www.megamobilecontent.com/news/2026/09/09/ios-27-camera-histograms-focus-peaking-variable-aperture/) · [Customize Controls in the Camera App — MacRumors](https://www.macrumors.com/how-to/ios-set-up-controls-camera-app/)
