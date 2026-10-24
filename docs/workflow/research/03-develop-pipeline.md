# 03 — Develop Pipeline Audit (our own RAW processing code)

**Scope:** `pikicam/Features/Develop/**` plus every renderer/encoder/viewer that consumes it.
**Date:** 2026-10-02 · **Tree:** `main` @ `e5e976a` + the uncommitted working tree.
**Method:** every file read in full; `git diff` of the uncommitted area read in full; the
repo's own DNG fixture parsed byte-level; the iOS 26.5 SDK headers read directly; four
standalone probe binaries compiled for `arm64-apple-ios26.5-simulator` and run under
`simctl spawn` on an iPhone 17 Pro simulator; and `xcodebuild test` run against the repo's
own develop tests.

> **Everything marked MEASURED below was produced by running code on this machine during this
> audit. Everything else is cited to a file:line or a URL. Nothing is guessed.**

---

## Summary — top 10 findings

1. **P0 — The develop pipeline has never once applied its own recipe. It ships Apple's full
   computational RAW look and calls it "zero-process."** `CIRAWFilter(imageData:)` — the
   1-argument Swift convenience initializer used at
   `pikicam/Features/Develop/CIRAWZeroProcessor.swift:31` — returns a **stub** object whose
   class is `CIRAWFilterImpl`, which implements **none** of the documented properties.
   MEASURED (iOS 26.5 simulator, this repo's own `IMG_1361.DNG`):
   `CIRAWFilter(imageData:)` → class `CIRAWFilterImpl`, `responds(to: setBaselineExposure:)` =
   `false`, `responds(to: orientation)` = `false`.
   `CIRAWFilter(imageData:identifierHint:)` — *even with `identifierHint: nil`* — and
   `CIRAWFilter(imageURL:)` → class `CIRAWFilter`, **85 methods**, every setter present.
   The stub's render is byte-statistically **identical** to Apple's untouched default
   (avgR 119.95 / 9702 clipped / 23590 black, both). One-line root cause; the entire product
   claim hangs on it.
2. **P0 — There is no output encoder anywhere.** No JPEG, HEIC, PNG, TIFF or DNG writer
   exists in the repo (`grep` for `heifRepresentation|jpegRepresentation|pngRepresentation|
   writeJPEG|UIImageWriteToSavedPhotosAlbum` → nothing). `DNGDisplayRendition` is documented as
   "never encoded" (`pikicam/Features/Develop/RAWProcessor.swift:27-29`,
   `DevelopService.swift:12-14`). The pipeline's product cannot leave the app.
3. **P0 — The gallery grid shows Apple's rendering of the DNG, not ours.**
   `PhotoLibraryManager.swift:680` requests `version = .current` and `:682` `resizeMode = .fast`
   from `PHImageManager`, so every grid cell and the camera thumbnail is rendered by **Photos**,
   with Photos' processing. The viewer shows "zero-process". Two surfaces, two different looks.
4. **P0 — There is no tone curve.** The recipe sets `boostAmount = 0`, which Apple documents as
   *"A value of 0 indicates no global tone curve, i.e. linear response"* — and nothing replaces
   it. MEASURED render through the app's own Display-P3 `CIContext`: zero recipe avgR **102.37**,
   min 5, max 255, 11 clipped pixels vs Apple's default avgR **119.95**, min 0, 9702 clipped,
   23590 crushed black. The delivered image is flat and milky. This is the single biggest cause
   of the "disgusting" look, and it is a *design* defect, not a bug.
5. **P0 — Highlight recovery is left ON, and the code comment's reason for leaving it on is
   factually wrong.** `CIRAWZeroProcessor.swift:60-62` excludes it because
   `NS_AVAILABLE(16_0, 19_0)` means "unavailable". `NS_AVAILABLE(a, b)` means *deprecated in b* —
   the property still exists, still compiles, is still settable, and MEASURED
   `isHighlightRecoverySupported = true`, `isHighlightRecoveryEnabled = true`. Apple's highlight
   reconstruction is applied to every frame and the code asserts it cannot be turned off.
6. **P0 — `baselineExposure = 0.0` is a hidden +0.302 EV exposure edit, not a neutralisation.**
   MEASURED default for this fixture: `baselineExposure = **-0.3022**` (it equals the DNG's own
   IFD0 tag `0xC62A`, SRATIONAL `-324502784/1073741824`). Forcing `0.0` therefore brightens every
   frame by 0.302 EV relative to the DNG's radiometric truth. The recipe is not neutral; it is an
   undeclared develop edit wearing a "zero" label.
7. **P0 — The develop test suite is red, and the one develop test that passes, passes
   vacuously.** `xcodebuild test` on this machine: `testZeroRecipeReachesEveryControlOnARealFilter`
   emits 15 `XCTAssertTrue failed — CIRAWFilter does not respond to setX:` messages and then
   **crashes the test host** with `-[CIRAWFilterImpl baselineExposure]: unrecognized selector sent
   to instance` (`** TEST FAILED **`). `testZeroDevelopProducesViewableJPEGFromRealDNG` **passes
   in 2.215 s** while the recipe applies literally nothing, because it only asserts extent > 1000
   and average luminance > 5.
8. **P0 — `decoderVersion` is unpinned, so the look silently drifts with OS updates — and on
   RAW 9 three of the recipe's entries become no-ops.** Apple (WWDC26-305): RAW 9 fuses demosaic
   and denoise into one ANE/Core-ML pass, and in RAW 9 `colorNoiseReductionAmount`, `detailAmount`
   and `moireReductionAmount` *"no longer take effect"*. MEASURED on 26.5: `decoderVersion`
   defaults to `8.dng`, `supportedDecoderVersions = [6.dng, 7.dng, 8.dng]`.
9. **P1 — Zero of our own code runs anywhere in the pipeline.** `CIRAWFilter.linearSpaceFilter`
   — the one Apple-sanctioned hook for *"an optional filter you can apply to the RAW image while
   it's in linear space"* — is never set. There is no `CIKernel`, `CIColorKernel`,
   `CIImageProcessorKernel`, `CIFilter` chain or LUT of ours anywhere in the repo. The product
   goal "camera → our own code → bypass Apple's look" is currently "camera → Apple → bypass".
10. **P1 — Display rendering is misconfigured for its own job.** `CIContext` is built **on the
    main thread inside a SwiftUI `@State` initializer** (`GalleryView.swift:154`), once per
    viewer presentation, with `cacheIntermediates: false` — the exact configuration Apple's own
    guidance says to use for *batch export*, and warns causes *"stutter or crash"* if mixed up.
    Working color space is left at Core Image's default `extendedLinearSRGB`, output is SDR
    Display P3, format is 8-bit, and the render is full sensor resolution for a screen that shows
    at most ~1200 pt.

**Bonus, and it matters for the next work order:** the untracked `docs/prompt-next.md` §0.1
concludes the root cause is *"the iOS Simulator's `CIRAWFilterImpl` … does not implement
`setBaselineExposure:`"* and prescribes a Phase-0 device enumeration of runtime methods. **That
diagnosis is wrong** — `CIRAWFilterImpl` is not a runtime limitation, it is what the 1-arg
initializer returns. Phase 0 as written would burn a device cycle proving nothing.

---

## 0. What the processor actually does, step by step

### 0.1 The complete production call graph

```
CaptureService.capturePhoto(aspectRatio:orientation:)      CaptureService.swift:497
  AVCapturePhotoSettings(rawPixelFormatType: <14-bit Bayer>)         :536
  photoOutput.isAppleProRAWEnabled = false                 CaptureService.swift:676
  → CapturedDNG(data:, capturedAt:, orientation:, aspectRatio:, zoomFactor:)   :603
  → PhotoLibraryManager.save → one PHAsset, one `.photo` DNG resource
  → PikicamCapture

FullScreenViewer .task(id: capture.id)                    GalleryView.swift:229
  library.loadOriginalDNG(for:)  → PhotoKit resource read  :234
  developService.render(dngData:aspectRatio:zoomFactor:)    :235
      processor.develop(dngData:)                           DevelopService.swift:62
          CIRAWFilter(imageData: dngData)      ← ***STUB***  CIRAWZeroProcessor.swift:31
          applyZeroRecipe(filter)  → 15 × responds(to:) probe → ALL FALSE → 0 applied
          filter.outputImage                                 CIRAWZeroProcessor.swift:37
      ciImage.cropped(to: PrintCrop.rect(in: extent, zoomFactor:, aspect:))  :66-68
      ciContext.createCGImage(framed, from: framed.extent)   :77
      DNGDisplayRendition(ciImage:, cgImage:)                :70
  UIImage(cgImage: rendition.cgImage) → Image.resizable().scaledToFit()  GalleryView.swift:165-168, 240

Gallery grid + camera thumbnail (a completely different renderer)
  library.loadThumbnail → PhotoLibraryManager.requestThumbnail
      PHImageRequestOptions{ version: .current, resizeMode: .fast }  PhotoLibraryManager.swift:680-682
      PHImageManager.requestImage → Photos' own RAW rendering
```

### 0.2 What actually happens inside `develop`

1. `CIRAWFilter(imageData:)` — 1-arg Swift convenience init → **`CIRAWFilterImpl` stub**.
2. `applyZeroRecipe(filter)` iterates the 15-entry `recipe`, derives
   `set<Name>:` from the string, calls `filter.responds(to:)`, and **returns early for all 15**
   (MEASURED: all 15 `false` on this runtime).
3. `filter.outputImage` returns Apple's full default render (MEASURED identical statistics to an
   untouched filter).

Net: **step 2 is a no-op in every environment measured so far**, and the class comment at
`CIRAWZeroProcessor.swift:15-17` (*"Every subjective enhancement `CIRAWFilter` declares is
explicitly neutralized"*) is false on its face.

### 0.3 The full `CIRAWFilter` control set vs what the recipe does

Source of truth for the control list is the shipped header, read directly:
`iPhoneOS26.5.sdk/System/Library/Frameworks/CoreImage.framework/Headers/CIRAWFilter.h`.
"Measured default" is this machine, iOS 26.5 simulator, `IMG_1361.DNG`, iPhone 12 Pro,
`decoderVersion = 8.dng`.

| Control (ObjC name) | Header default | **MEASURED default** | Recipe action | Neutral? |
|---|---|---|---|---|
| `baselineExposure` | "can vary based on the image" | **-0.3022** | `= 0.0` | ❌ **+0.302 EV edit** |
| `exposure` | `0` | `0.0` | `= 0.0` | ✅ |
| `boostAmount` | `1` (full global tone curve) | `1.0` | `= 0.0` | ⚠️ removes the curve; nothing replaces it |
| `boostShadowAmount` | `1` (no effect when boost = 0) | `0.9` | `= 0.0` | ✅ (vacuous while boost = 0) |
| `shadowBias` | "can vary based on the image" | `0.0` | `= 0.0` | ✅ (this DNG only) |
| `localToneMapAmount` | "will vary per image" | **1.0** | `= 0.0` | ✅ |
| `luminanceNoiseReductionAmount` | "will vary per image" | `0.0` | `= 0.0` | ✅ (this DNG only) |
| `colorNoiseReductionAmount` | "will vary per image" | **0.5** | `= 0.0` | ✅ |
| `sharpnessAmount` | "will vary per image" | **1.0** | `= 0.0` | ✅ |
| `detailAmount` | "will vary per image" | `0.5` | `= 0.0` | ✅ |
| `moireReductionAmount` | "will vary per image" | `0.0` | `= 0.0` | ✅ (this DNG only) |
| `contrastAmount` | "will vary per image" | `0.1` | `= 0.0` | ✅ |
| `extendedDynamicRangeAmount` | `0` | `0.0` | `= 0.0` | ✅ (no EDR headroom — a choice, not a neutralisation) |
| `lensCorrectionEnabled` | "can vary based on the image" | `isLensCorrectionSupported = **false**`, `enabled = false` | `= false` | ✅ vacuous on this DNG |
| `gamutMappingEnabled` | **`true`** | `true` | `= false` | ✅ (but see P1: Core Image re-maps anyway) |
| **`highlightRecoveryEnabled`** | **`true`** | `supported = true`, **`enabled = true`** | ❌ **not in recipe** | ❌ **Apple look ON** |
| **`decoderVersion`** | newest available | **`8.dng`** | ❌ **not in recipe** | ❌ **unpinned** |
| `despeckleAmount` | (iOS 27+ only) | n/a on 26.5 | ❌ not in recipe | ❌ future regression |
| `orientation` | file's EXIF | `6` | not set | ✅ *by luck* (see P1) |
| `scaleFactor` | `1` (full size) | `1.0` | not set | ❌ full-res decode for a thumbnail-sized view |
| `isDraftModeEnabled` | `NO` | `false` | not set | ✅ |
| `neutralChromaticity` / `neutralTemperature` / `neutralTint` / `neutralLocation` | as-shot | `5201.3 K` / `+6.4` / — | not set | ✅ correct; ❌ but no user WB control at all |
| **`linearSpaceFilter`** | `nil` | `nil` | ❌ **never set** | ❌ **no app-authored code in the pipeline** |
| `previewImage`, `portraitEffectsMatte`, `semanticSegmentation*Matte` | auxiliary | present in this DNG (sky matte at IFD 63282, `urn:com:apple:photo:2020:aux:semanticskymatte`) | never read | ❌ unused capability |
| `properties` | dict | has `{DNG} {Exif} {ExifAux} {GPS} {MakerApple} {TIFF}` keys | **never read** | ❌ no metadata for our own pipeline |

**Counts: 15 controls listed, 13 genuinely neutralised on this DNG, 1 applied wrongly
(`baselineExposure`), 1 never applied (`highlightRecoveryEnabled`), 3 not in the recipe at all
(`decoderVersion`, `despeckleAmount`, `linearSpaceFilter`).**

---

## 1. The target pipeline (stated precisely, so it can be diffed against the code)

This is what "camera → our own code → bypass the iPhone's post-processing" *has* to mean on
iOS. Five stages; every stage names who owns the pixels.

**Stage 0 — Capture (already correct; do not touch).** `AVCapturePhotoSettings(rawPixelFormatType:)`
with a pure 14-bit Bayer format, `isAppleProRAWEnabled = false`, at 1×, full sensor, no processed
print. One `.photo` DNG resource. Keep it.

**Stage 1 — Front end (Apple, but pinned and measured).**
- `CIRAWFilter(imageData: dngData, identifierHint: UTType.rawImage.identifier)` — **never** the
  1-arg init.
- **Pin `decoderVersion`** to a chosen member of `filter.supportedDecoderVersions`, chosen for the
  device/OS at runtime, and *record the choice* on the capture so a later OS update cannot change
  the look of an old photo silently. (RAW 9 must be an explicit opt-in: it fuses denoise into
  demosaic, which is un-zeroable via the knobs.)
- **Set `orientation` explicitly** — from the DNG's own EXIF tag, or `.up` and rotate ourselves.
  Do not rely on an undocumented default.
- **Set `scaleFactor`** per use: ~0.2 for interactive preview, 1.0 for export.
- Read every control's default before neutralising and return a `RecipeApplication` value that
  says which controls were applied, which were unreachable, and which runtime defaults differed
  from neutral. This is the type that makes the promise falsifiable.

**Stage 2 — Apple's radiometric core (not defeatable; disclose, do not pretend).** Linearisation
table (DNG `0xC618`, 4096 entries) + black level (`0xC61A` = 0,0,0), Bayer demosaic, camera colour
matrix, white balance from `AsShotNeutral` (`0xC61D` = 1,1,1 → 5201.3 K / +6.4 tint), highlight
recovery (attempt to disable; if the runtime refuses, say so in the UI).
**Architectural fact that constrains everything downstream:** MEASURED — the fixture DNG contains
**no `ColorMatrix1/2`, no `CameraCalibration1/2`, no `ForwardMatrix1/2`, no `OpcodeList1/2/3`,
no `ReductionMatrix1/2`, no `WhiteLevel`, no `BaselineExposure`, and no `AnalogBalance`** anywhere
in its TIFF structure (byte-scan of all five IFDs plus a whole-file tag sweep). Apple's
calibration lives in the private `0xCD2D` blob / maker notes. **The camera→XYZ matrix is not
obtainable from public DNG tags on iPhone**, so Stage 2 cannot be replaced — it can only be
front-ended and then extended. State that honestly; it is the strongest argument for the
`linearSpaceFilter` architecture below.

**Stage 3 — OUR CODE.** Everything from here is ours. Implement as a `CIFilter` chain (a
`CIFilter` subclass, or a built-in chain; `CIFilter.customImage()` does **not** exist in the
iOS 26.5 SDK — verified by `swiftc -typecheck`) handed to `CIRAWFilter.linearSpaceFilter`, which
runs while the image is still linear, ahead of Apple's (now zeroed) tone curve. Inside it, in
order:
1. **Exposure** — user-controlled EV, our number, our curve. This *replaces* the silently deleted
   `baselineExposure` gain with an explicit, visible one.
2. **White balance** — from DNG metadata plus a user Kelvin/tint, applied as an explicit 3×3
   `CIColorMatrix` in a *named* working space.
3. **Working space** — scene-linear wide gamut (`extendedLinearDisplayP3` or linear Rec.2020),
   `workingFormat: .RGBAh`.
4. **Black/white point normalisation** from the DNG's own linearisation table and black level.
5. **Our tone curve** — a parametric filmic/Reinhard/Hable curve, or a `CIColorCube` LUT.
   *Non-negotiable* (see finding #4). User-adjustable: exposure, contrast, highlight/shadow.
6. **Our gamut handling.** With `isGamutMappingEnabled = false` in the filter, out-of-gamut values
   clip; therefore we own the gamut compression ourselves.
7. **Our noise/sharpening**, default **off** (honest zero), opt-in. Implement in
   `CIImageProcessorKernel` (exists on iOS 26.5 — verified) or `CIColorKernel`/`CIKernel`, not
   via `CIRAWFilter`'s knobs, because RAW 9 makes those no-ops. The DNG even carries a
   `NoiseProfile` tag (`0xC761`, 2 doubles, MEASURED) to drive it.
8. **Output encode** — working space → output space → HEIC 10-bit Display P3 via
   `CIContext.heifRepresentation(of:format:colorSpace:options:)` (verified present on iOS 26.5)
   or 16-bit TIFF for archival.

**Stage 4 — Output.**
- *Preview*: render at display scale only. One app-wide `CIContext` (or Apple's documented
  one-per-view pattern), `cacheIntermediates: true` for interactive work, rendered into a
  Metal-backed view.
- *Export*: `cacheIntermediates: false` **plus `CIContextOption.memoryTarget` raised** (verified
  present; renamed from `kCIContextMemoryLimit`), `CIRenderDestination` (verified present on
  26.5, `init(mtlTexture:commandBuffer:)`) for tiled low-memory output, and
  `heifRepresentation`/`jpegRepresentation` instead of allocating one full bitmap.
- *Thumbnails*: rendered by **us** at cell size through the same pipeline, cached. Never
  `PHImageManager`.
- *Persistence*: store our develop recipe per capture so "our look" is reproducible and re-editable.

**Stage 5 — Honesty surface.** A `DevelopRecipe` + `RecipeApplication` pair that the UI can
display ("ZERO-PROCESS · 13/15 NEUTRALISED · HIGHLIGHT RECOVERY ON (DEVICE)") and that the test
suite asserts against, so the product claim is machine-checked rather than asserted in a comment.

---

## 2. Every place Apple's look is re-introduced

| # | Location | What leaks back in | Severity |
|---|---|---|---|
| 1 | `CIRAWZeroProcessor.swift:31` | 1-arg init → stub → **the entire recipe is skipped** | **P0** |
| 2 | `CIRAWZeroProcessor.swift:60-62` | `highlightRecoveryEnabled` left `true` (measured), on a false "unavailable" rationale | **P0** |
| 3 | `CIRAWZeroProcessor.swift:56-62` | `decoderVersion` unpinned → decoder drift per OS; RAW 9 fuses denoise and voids 3 recipe entries | **P0** |
| 4 | `CIRAWZeroProcessor.swift:65` | `baselineExposure = 0.0` overrides a measured `-0.3022` → **+0.302 EV**, our own edit | **P0** |
| 5 | `CIRAWZeroProcessor.swift:67` + no replacement anywhere | Apple's global tone curve removed, **nothing put back** → flat linear-response image | **P0** |
| 6 | `PhotoLibraryManager.swift:680,682` | `PHImageManager` `.current` / `.fast` → Photos' own RAW render in the grid and the camera thumbnail | **P0** |
| 7 | `DevelopService.swift:28` | Core Image matches working→destination automatically; with no rendering-intent option exposed, that match is a perceptual gamut map — exactly what `isGamutMappingEnabled = false` claims to have removed | P1 |
| 8 | `DevelopService.swift:77` | `createCGImage` → 8-bit RGBA8 sRGB-transfer quantisation of scene-referred data → shadow banding, hard clip | P1 |
| 9 | `CIRAWZeroProcessor.swift:77` + `DevelopService.swift:23` | `extendedDynamicRangeAmount = 0` and an SDR Display P3 output space → EDR/HDR is structurally impossible | P1 |
| 10 | `DevelopService.swift:25-32` (no `scaleFactor`, full-extent render) | Apple's full-resolution decode path for a screen-sized view; on 48 MP sensors this is a memory cliff | P1 |
| 11 | `CIRAWZeroProcessor.swift:78` | `lensCorrectionEnabled = false` discards Apple's optical correction on DNGs that carry distortion params (this fixture: `isLensCorrectionSupported = false`, so vacuous — but a choice, not an accident, on others) | P2 |
| 12 | `CaptureService.swift:676` (`isAppleProRAWEnabled = false`) + `CIRAWFilter` itself | Turning ProRAW off removes Apple's *computational* fusion but not the **demosaic-level processing inside `CIRAWFilter`** — the demosaic, colour matrix, local tone map defaults (`localToneMapAmount = 1.0` measured) and chroma NR (`0.5` measured) are the Apple look | P1 |
| 13 | nowhere | `linearSpaceFilter` never set → zero app-authored pixels anywhere in the graph | P1 |
| 14 | `RAWProcessor.swift:30-36` | `DNGDisplayRendition` carries no EXIF, no develop metadata, no recipe; nothing survives the render | P2 |

---

## 3. Detailed findings

### P0-1 — The wrong initializer makes the entire recipe unreachable

**Evidence**
- `pikicam/Features/Develop/CIRAWZeroProcessor.swift:31` — `CIRAWFilter(imageData: dngData)`
  (1-argument form).
- `pikicam/Features/Develop/CIRAWZeroProcessor.swift:124` — `guard filter.responds(to: setter) else { return }`.
- MEASURED (`/tmp/pikiprobe/cmp.swift`, `arm64-apple-ios26.5-simulator`, iPhone 17 Pro sim):

```
A) CIRAWFilter(imageData:)                    class=CIRAWFilterImpl responds orientation=false responds setBaselineExposure=false
B) CIRAWFilter(imageData:identifierHint:)     class=CIRAWFilter      responds orientation=true  responds setBaselineExposure=true
C) CIRAWFilter(imageData:identifierHint:nil)  class=CIRAWFilter      responds orientation=true  responds setBaselineExposure=true
D) CIRAWFilter(imageURL:)                     class=CIRAWFilter      responds orientation=true  responds setBaselineExposure=true
```

  MEASURED: the real filter exposes **85 instance methods**, including `setBaselineExposure:`,
  `setBoostAmount:`, `setLensCorrectionEnabled:`, `setGamutMappingEnabled:`,
  `setHighlightRecoveryEnabled:`, `setDecoderVersion:`, `setLinearSpaceFilter:`, `orientation`.
- MEASURED: applying the 15-entry recipe to the **real** filter reads back
  `baseline=0 exposure=0 boost=0 boostShadow=0 shadowBias=0 ltm=0 lnr=0 cnr=0 sharp=0 detail=0
  moire=0 contrast=0 edr=0 lens=0 gamut=0` — **the recipe works** once the initializer is right.
- MEASURED: the stub renders the same image as an untouched filter
  (avgR 119.95 / clipped 9702 / black 23590 for both).

**Why it matters** — the product's headline claim ("bypass the iPhone's post-processing") is
false today, on every environment measured. The user receives Apple's full tone curve, Apple's
local tone mapping, Apple's sharpening at maximum, Apple's chroma noise reduction at half, Apple's
gamut mapping, and Apple's highlight recovery.

**Fix direction** — `CIRAWFilter(imageData: dngData, identifierHint: UTType.rawImage.identifier)`
(one line). Then delete the `responds(to:)` silent-skip path: with a working filter every control
is reachable, so an unreachable control is a *typed error*, not a `return`. Add a device-run
regression test that asserts all 15 read back at neutral.

---

### P0-2 — There is no output encoder; the pipeline's product cannot leave the app

**Evidence** — `grep -rn "heifRepresentation|jpegRepresentation|pngRepresentation|tiffRepresentation|writeJPEG|writeHEIF|UIImageWriteToSavedPhotosAlbum|UIActivityViewController|ShareLink" pikicam/` returns **only** `PhotoLibraryManager.swift` PhotoKit calls. `RAWProcessor.swift:27-29`: *"It is never encoded to JPEG, written to disk, or persisted anywhere."* `DevelopService.swift:12-14`: *"Nothing here is persisted: no JPEG is encoded and no file is written."* `ControlIDRegistry.swift:62` registers `viewerShare` — a control ID with **no view behind it**.

**Why it matters** — "develop it with our own code" is meaningless if the developed image is only ever a `UIImage` in a view that cannot zoom. There is no save, no share, no archive, no re-edit. The pipeline has no terminal stage.

**Fix direction** — add `DevelopService.export(...) -> Data` writing HEIC 10-bit via
`CIContext.heifRepresentation(of:format:colorSpace:options:)` (verified available on iOS 26.5),
with `cacheIntermediates: false` + `.memoryTarget` raised per Apple's batch-export guidance, and
`CIRenderDestination` for tiled output. Keep the DNG asset untouched; persist our recipe beside it.

---

### P0-3 — The gallery and the camera thumbnail are rendered by Photos, not by us

**Evidence** — `PhotoLibraryManager.swift:680` `options.version = .current`,
`:682` `options.resizeMode = .fast`, `:695` `PHImageManager.default().requestImage(...)`.
The only pikicam asset resource is a DNG (`isDNGResource`, `:806-808`), so `.current` means
*"Photos, render this RAW for me"*. Consumed by `GalleryView.AsyncThumbnail` (`:249-272`),
`GalleryView` toolbar thumbnail (`:19-27`), and `CameraView.ThumbnailImage` (`:286-322`).
MEASURED — for a `.photo`-only DNG asset, `PHImageManager` must invoke Photos' RAW renderer;
there is no pre-rendered alternative in the asset.

**Why it matters** — the grid is the surface the user scans. It shows Apple's look; the viewer
shows "zero-process". Two different pictures of the same library, and the more prominent one is
the Apple one. (`.fast` additionally requests Photos' *fast/degraded* path, so the grid is not
even Apple's best output.)

**Fix direction** — develop through our own pipeline at cell size (≈ 300 px, `scaleFactor ≈
0.08`) and cache the result keyed by `CaptureID`. Replace `requestThumbnail` with a
`DevelopService.thumbnail(...)` call. This is also the cheap way to get an interactive develop
preview later.

---

### P0-4 — No tone curve anywhere: the image is deliberately flat

**Evidence** — `CIRAWZeroProcessor.swift:67` `boostAmount = 0.0`. Header:
*"A value of 0 indicates no global tone curve, i.e. linear response. A value of 1 indicates full
global tone curve. The default value is 1."* MEASURED render statistics through the app's exact
context configuration (`outputColorSpace: Display P3`, `cacheIntermediates: false`):

| recipe | avg R | min | max | clipped 255 | crushed 0 |
|---|---|---|---|---|---|
| **zero recipe** | **102.37** | **5** | 255 | **11** | **0** |
| `boostAmount = 0` only | 134.96 | 0 | 255 | 9456 | 815 |
| Apple default (all knobs untouched) | 119.95 | 0 | 255 | 9702 | 23590 |

  MEASURED — the zero output's `CIImage.colorSpace` is still `kCGColorSpaceDisplayP3` (not
  extended-linear) and the CGImage is 8 bpc / 32 bpp, so what `boostAmount = 0` actually
  produces is a **low-contrast, lifted-black, clipped-highlight image encoded straight to 8-bit
  Display P3** — not a usable photograph.

**Why it matters** — this, more than any bug, is the "disgusting" the owner is describing. 0
crushed pixels out of 12.2 M means no blacks at all; 11 clipped pixels means highlights are being
held by an 8-bit ceiling rather than a curve. There is no user control to compensate — the viewer
has no exposure, contrast, curve or colour UI.

**Fix direction** — the zero recipe should **not** mean "linear forever". Make tone mapping a
first-class, user-visible part of *our* pipeline (Stage 3.5 in §1): a parametric curve with a
neutral default that still produces a photograph, plus explicit exposure/contrast/highlight/
shadow controls in the viewer. "Zero process" should mean *"Apple's decisions are not applied"*,
not *"no display transform exists"*.

---

### P0-5 — Highlight recovery is applied, and the exclusion rationale is false

**Evidence**
- `CIRAWZeroProcessor.swift:60-62`: *"`highlightRecoveryEnabled` — deprecated as of iOS 19
  (`NS_AVAILABLE(16_0, 19_0)`); referencing it emits a deprecation warning, and Apple no longer
  treats it as a supported control."*
- SDK header (`CIRAWFilter.h`):
  `@property(readonly, getter= isHighlightRecoverySupported) BOOL highlightRecoverySupported NS_AVAILABLE(16_0,19_0);`
  `@property(readwrite, getter= isHighlightRecoveryEnabled) BOOL highlightRecoveryEnabled NS_AVAILABLE(16_0,19_0);`
  and the doc comment above it: *"A boolean value to control if highlight recovery is enabled or
  not. **The default value is true.**"*
- `NS_AVAILABLE(introduced, deprecated)` — two arguments mean *deprecated*, not *unavailable*.
- MEASURED on iOS 26.5: `isHighlightRecoverySupported = true`, `isHighlightRecoveryEnabled = true`,
  and `setHighlightRecoveryEnabled:` **exists** in the runtime method list. A
  `swiftc -typecheck` of `f.isHighlightRecoveryEnabled` against the 26.5 SDK compiles clean.

**Why it matters** — highlight recovery reconstructs clipped highlight detail using Apple's
model. It is unambiguously part of "Apple's post-processing" and it is running. The comment
documents a false belief, which means the next engineer will also believe it.

**Fix direction** — add `("highlightRecoveryEnabled", { $0.isHighlightRecoveryEnabled = false })`
to the recipe (suppress with `@available(iOS, deprecated: 19)` if the warning matters), verify the
read-back, and if a runtime refuses, surface it in a `RecipeApplication` shown in the UI rather
than in a comment.

---

### P0-6 — `baselineExposure = 0.0` is a measured +0.302 EV develop edit

**Evidence**
- `CIRAWZeroProcessor.swift:65` `("baselineExposure", { $0.baselineExposure = 0.0 })`.
- SDK header: *"A value for baseline exposure applied to the image. **Default value can vary
  based on the image.**"* — deliberately contrasted with `exposure`'s *"Default value is 0."*
- MEASURED on the repo's own fixture: **default `baselineExposure = -0.3022`**.
- Byte-parse of `pikicamTests/Fixtures/IMG_1361.DNG` IFD0: tag `0xC62A` (`ShadowScale`),
  type SRATIONAL, cnt 1, numerator `-324502784`, denominator `1073741824` → **-0.30221676826**.
  So `CIRAWFilter.baselineExposure` is seeded from the DNG's own tag.

**Why it matters** — the recipe's entire premise is that it only *removes* Apple decisions.
`baselineExposure = 0.0` instead applies a **0.302 EV brighter** transform to every frame. It is
a radiometric edit — exactly the class of edit the recipe claims not to make — and it is
invisible because nothing records it. Note this is the one place where the prior work order's
recommendation (remove the entry) and mine (keep 0 but *disclose and expose it as a user
exposure control*) differ; both agree it must not stay an invisible side effect. Given the
product is "our own code", the better answer is to **delete the CIRAWFilter entry entirely and
implement exposure ourselves in Stage 3**, where it is a visible slider instead of a hidden
0.302 EV.

---

### P0-7 — The develop test suite is red, and the passing test proves nothing

**Evidence** (`xcodebuild test -destination 'platform=iOS Simulator,id=<iPhone 17 Pro>'`,
run during this audit):

```
Test Case '...testZeroDevelopProducesViewableJPEGFromRealDNG' passed (2.215 seconds).
Test Case '...testZeroRecipeReachesEveryControlOnARealFilter' started.
  PikicamPipelineTests.swift:555: XCTAssertTrue failed - CIRAWFilter does not respond to
      setBaselineExposure: - the recipe entry 'baselineExposure' would be skipped in silence.
  … (15 such failures, one per recipe entry) …
  <unknown>:0: -[CIRAWFilterImpl baselineExposure]: unrecognized selector sent to instance
  *** Terminating app due to uncaught exception 'NSInvalidArgumentException' …
** TEST FAILED **
```

- `testZeroDevelopProducesViewableJPEGFromRealDNG` (`PikicamPipelineTests.swift:38-66`) asserts
  only `extent.width/height > 1000` and `averageLuminance > 5.0`. Apple's *full default render*
  satisfies both — and it is exactly what the app renders, because the recipe is a no-op. The
  test passes on the failure it is supposed to catch.
- `testZeroRecipeReachesEveryControlOnARealFilter` (`:541-590`) reads
  `filter.baselineExposure` etc. **unguarded** — the same `responds(to:)` hazard that
  `apply()` guards against on the write path kills the process on the read path.
- `testZeroRecipeEnumeratesEveryEnhancementControl` (`:492-539`) compares the recipe against a
  **second hard-coded literal** in the test file. It cannot detect a new Apple control; it only
  detects drift between two copies of the same list. It will also fail spuriously when
  `despeckleAmount` ships (iOS 27) unless updated.
- `renderIntoBitmap` (`:427-436`) builds its own bare `CIContext()` — default `outputColorSpace`
  is **sRGB**, not the Display P3 the app uses — so the luminance assertion measures a different
  pipeline than production.
- `PikicamPipelineTests.swift:11` header comment claims the suite produces "a viewable JPEG";
  nothing in the suite encodes a JPEG.
- The genuinely useful develop test is `testZeroDevelopAppliesFramingCropInDevelopedSpace`
  (`:74-107`) — it does verify that the developed extent is upright, which is a real contract.

**Why it matters** — the only guarantee the product makes is unasserted, and the suite that
pretends to assert it currently crashes the host.

**Fix direction** — (a) delete `responds(to:)` from `apply()`; (b) make the recipe test read
every control back **inside a `responds(to:)` guard**, failing (not crashing) when a control is
unreachable; (c) replace the two hard-coded lists with one list and an SDK-derived enumeration;
(d) add a *pixel* assertion that distinguishes our output from Apple's — the measured delta
(clipped 9702 → 11, black 23590 → 0) is a usable fingerprint; (e) render through the *production*
context configuration in tests.

---

### P0-8 — `decoderVersion` is unpinned; RAW 9 voids three recipe entries

**Evidence** — `CIRAWZeroProcessor.swift:59` excludes `decoderVersion` from the recipe with the
rationale *"the demosaic/decoder algorithm, not a post-filter"*. MEASURED default:
`decoderVersion = 8.dng`, `supportedDecoderVersions = [6.dng, 7.dng, 8.dng]`.
WWDC26-305 (Apple, "Enhance RAW image processing with Core Image"):
> "RAW 9 solves this by combining demosaicing and denoising into one tile-based Core ML model that
> runs on the Apple Neural Engine."
> "Parameters that no longer take effect in RAW 9: `colorNoiseReductionAmount` — The Core ML model
> automatically handles color noise reduction. `detailAmount` — No longer needed. `moireReductionAmount` — No longer needed."
> "RAW 9 is not enabled automatically… `decoderVersion` does not default to version9."

  Also from that session: RAW 9 decoders require a downloadable model via
  `CIRAWFilter.downloadResources` — which **does not exist** in the iOS 26.5 SDK (verified by
  `swiftc -typecheck`), so it is an iOS 27 concern, and iOS 27 also adds
  `despeckleAmount`/`isDespeckleSupported` (also verified absent on 26.5).

**Why it matters** — two distinct failures. (1) If a future OS makes RAW 9 the newest available
decoder, the *same stored DNG* re-develops differently with no code change, and three of the
recipe's entries become **no-ops that cannot be neutralized** — Apple's denoise is fused into the
demosaic. The zero promise would be silently unachievable. (2) The exclusion rationale is wrong on
its own terms: the decoder version decides the *defaults* the recipe has to fight, so it is
first-order, not a "post-filter".

**Fix direction** — pin `decoderVersion` to a chosen member of `supportedDecoderVersions` and
record it on the capture. Add `despeckleAmount` to the recipe behind
`if #available(iOS 27, *)`. Make the recipe-coverage test enumerate the *real* header at build time
rather than a duplicated literal.

---

### P1-9 — Zero app-authored code runs in the pipeline

**Evidence** — `linearSpaceFilter` appears only in `CIRAWZeroProcessor.swift:59`'s exclusion list
and nowhere in the code. `grep` for `CIKernel|CIColorKernel|CIImageProcessorKernel|CIColorCube|
CIColorMatrix|CIToneCurve` across `pikicam/` → **no hits**.
Header: *"An optional CIFilter to be applied to the RAW image while it is in linear space."*
`CIFilter.customImage()` does **not** exist in the iOS 26.5 SDK (verified by `swiftc -typecheck`);
`CIImageProcessorKernel` **does** (verified). `CIRenderDestination` **does**
(`init(mtlTexture:commandBuffer:)`, verified).

**Why it matters** — this is the product. Everything currently in the pipeline is Apple's; the
app contributes a crop and a color-space tag.

**Fix direction** — build the Stage-3 chain and hand it to `linearSpaceFilter` (a `CIFilter`
subclass whose `outputImage` applies a `CIColorKernel`/`CIKernel`/`CIImageProcessorKernel` to the
input it is given). Verify on device that the injected filter actually runs — the API is old and
its behaviour on current iOS is **UNVERIFIED**.

---

### P1-10 — `CIContext` is built on the main thread, per viewer, with the export configuration

**Evidence** — `DevelopService.swift:25-32` calls `MTLCreateSystemDefaultDevice()` and
`CIContext(mtlDevice:options:)` inside `init`. `GalleryView.swift:154`
`@State private var developService = DevelopService()` — SwiftUI `@State` initializers run on the
main actor, so a Metal context is created on the main thread every time the full-screen viewer is
presented. MEASURED at runtime with the same options: `workingColorSpace =
kCGColorSpaceExtendedLinearSRGB` (Core Image's default, per `CIContext.h`: *"The default working
space is the extended sRGB color space with linear gamma"*), `outputColorSpace` = our Display P3.
WWDC26-305 guidance: interactive editing wants `scaleFactor` downsampling, **one `CIContext` per
view**, **`cacheIntermediates` enabled**, and a Metal-backed view; batch export wants
`cacheIntermediates: false` + `memoryTarget` 512–1024 MB + `heifRepresentation`/`jpegRepresentation`,
and *"Mix these configurations up and your app will either stutter or crash."*

**Why it matters** — the app uses the *export* configuration for *interactive* rendering, which
is the configuration Apple names as the crash/stutter one, and it rebuilds it on the main thread
every time the viewer opens.

**Fix direction** — one app-lifetime `DevelopService` (not `@State`), created lazily off the main
thread; `cacheIntermediates: true` for the interactive path and a separate
`cacheIntermediates: false` + `.memoryTarget` context for export; explicit `workingColorSpace` and
`workingFormat`.

---

### P1-11 — Working/output color space and bit depth are the pipeline's weakest link

**Evidence** — `DevelopService.swift:23` sets only `outputColorSpace` (SDR Display P3,
`CGColorSpace.displayP3`, i.e. the sRGB-transfer P3, not `extendedLinearDisplayP3`). `CIContext.h`:
*". . . All input images are color matched from the input's color space to the working space. All
renders are color matched from the working space to the destination's color space."* The iOS 26.5
SDK exposes **no** `kCIContextRenderingIntent`, so the intent is ColorSync's default (perceptual —
UNVERIFIED but consistent with the platform default). `createCGImage` (`:77`) takes no `format:`
argument, so it is `RGBA8`. MEASURED: `bpc = 8`, `bpp = 32`, `cs = kCGColorSpaceDisplayP3`.

**Why it matters** — three separate leaks:
1. `isGamutMappingEnabled = false` (`:79` of the processor) removes Apple's gamut mapping, and then
   Core Image performs **its own** working→destination color match, which *is* a gamut map.
   Disabling the knob did not remove gamut mapping; it removed Apple's instance of it.
2. 8-bit quantisation of a scene-referred image produces visible banding in shadows and a hard
   ceiling at 255 (`clipped 255` pixels in the measured stats).
3. With SDR Display P3 output and `extendedDynamicRangeAmount = 0`, EDR/HDR is impossible on a
   device that supports it.

**Fix direction** — declare an explicit working space, do the display transform in *our* filter
(where the gamut policy is ours), render at `.RGBAh` internally, and only then let Core Image
convert to the output space. If EDR is wanted, use `extendedDynamicRangeAmount > 0` +
`extendedLinearDisplayP3` + a Metal-backed view, and say so in the design.

---

### P1-12 — Full-resolution render for a screen-sized view, no cancellation, no cache

**Evidence** — `DevelopService.swift:66-69`: crop, then `createCGImage(framed, from: framed.extent)`.
No `scaleFactor`, no `byTiling`, no `transform`, no target size. `DNGDisplayRendition`
(`RAWProcessor.swift:30-36`) holds **both** the `CIImage` graph and the full-res `CGImage`; the
graph retains the `CIRAWFilter`, which retains the `imageData` property (present in the 85-method
list) — i.e. the whole DNG. `GalleryView.swift:240` copies the CGImage into `@State image` for the
life of the presentation; `:165-168` renders it `.scaledToFit()` with no zoom.
`render` contains no `Task.checkCancellation()`, and `createCGImage` is synchronous, so
`.task(id:)` cancellation at `GalleryView.swift:229` cannot interrupt an in-flight render. Because
`DevelopService` is an actor, N rapid selections queue N full decodes serially.

MEASURED: the fixture is a 29,195,592-byte DNG; its zero-render `CGImage` is 3024×4032×4 B
≈ 48.8 MB, held together with the 29 MB source `Data`. A 48 MP sensor (8064×6048) would make the
bitmap ≈ 195 MB.

**Why it matters** — memory pressure and jank on exactly the devices the product targets, plus a
viewer with a multi-second, uncancellable, uncached spinner per selection.

**Fix direction** — pass a target pixel size into `render`; use `CIRAWFilter.scaleFactor` and/or
`CIImage.transformed(by:)` with `.highQualityDownsample` for the preview path; a
`CIContextOption.priorityRequestLow` render for offscreen work; check cancellation between stages;
an LRU cache keyed by `CaptureID` + target size; keep the DNG on disk and hold only the
`CGImage`/`CIImage` slice the view needs.

---

### P1-13 — Orientation is correct only by undocumented default, and the code's own provenance is dead

**Evidence**
- `DevelopService.swift:45-50` asserts CIRAWFilter bakes the EXIF orientation in, "verified
  empirically". MEASURED on iOS 26.5: fixture `Orientation = 6`, `nativeSize = 4032×3024`,
  `filter.orientation = 6`, `outputImage.extent = (0,0, 3024, 4032)`, output
  `properties["Orientation"] = 1`. **Confirmed on the simulator; device behaviour UNVERIFIED.**
- `filter.orientation` is never *set* anywhere in the repo — it depends entirely on the default
  being the file's tag.
- `CaptureOrientation` (`DevelopService.swift:91-104`) is captured at shutter press
  (`CameraViewModel.swift:281`), persisted (`PhotoLibraryManager.swift:14,98,914`), and **never
  read by any develop code** (`grep -rn orientation pikicam/` shows zero reads in `Develop/`).

**Why it matters** — a rendering-correctness contract resting on an undocumented default, with
the app's own authoritative orientation sample sitting unused next to it. If a future OS changes
the default, every landscape capture silently displays rotated and nothing detects it.

**Fix direction** — set `filter.orientation` explicitly from the DNG's EXIF tag (read via
`filter.properties`), assert it in a test across a portrait and a landscape fixture, and either
consume `CaptureOrientation` as a cross-check or delete it.

---

### P1-14 — Error handling cannot distinguish the failures that matter

**Evidence** — `DevelopError` has two cases (`RAWProcessor.swift:41-42`):
`filterCreationFailed` and `renderingFailed`, with generic copy. `CIRAWFilter` returns `nil` for
at least four distinct causes: unsupported camera model (`CIRAWFilter.supportedCameraModels`),
undecodable data, out of memory, and invalid `decoderVersion` (header: *"otherwise a nil output
image will be generated"*). The app never consults `supportedCameraModels` or
`supportedDecoderVersions`, never records which decoder it used, and offers no retry: the viewer
renders `ContentUnavailableView("Unable to load DNG", …)` with **no dismiss and no retry**
(`GalleryView.swift:169-176`), and the gallery cell stays an indistinguishable gray rectangle
(`:266`). `develop` also discards `filter.properties`, so the app cannot even show ISO or shutter.

**Why it matters** — "this photo can never be opened, and you cannot get out of this screen" is
a data-loss-shaped dead end. The design spec itself flags this (`docs/design/spec-gallery-viewer-spec.md:56`:
*"no Retry, no dismiss control (stuck state)"*).

**Fix direction** — typed cases (`unsupportedCamera`, `undecodable`, `decoderMismatch`,
`outOfMemory`), gate on `supportedCameraModels`, record the decoder version on the capture, add
retry + dismiss, and surface `filter.properties` (ISO, exposure, F-number, `NoiseProfile`,
`BlackLevel`) in a metadata sheet — which is also the raw material Stage 3 needs.

---

### P2-15..19 — Smaller items

| # | Finding | Evidence | Fix direction |
|---|---|---|---|
| P2-15 | `render`'s `zoomFactor` is unvalidated at the develop boundary (`develop` with `.nan` silently yields the 1× frame; `PrintCrop.zoomRect`'s `guard zoomFactor > 1.0` is false for NaN). `CapturedDNG` validates it, `DevelopService` does not. | `DevelopService.swift:60,67`; `CameraControls.swift:196` | add `DevelopError.invalidZoomFactor` and guard, matching the `CapturedDNG` convention |
| P2-16 | `PrintCrop.rect` returns fractional rects; `cropped(to:)` is not `.integral`-normalised, so the rendered pixel size can drift from the framing. | `CameraControls.swift:174-201`; `DevelopService.swift:66` | normalise to integral bounds before cropping |
| P2-17 | No `autoreleasepool` around a full-resolution RAW decode + render. | `DevelopService.swift:62-70` | wrap the render |
| P2-18 | `DNGDisplayRendition` duplicates memory (graph + bitmap + retained DNG) and carries no metadata, no recipe, no decoder version. | `RAWProcessor.swift:30-36` | one representation; attach a `DevelopRecipe`/`RecipeApplication` |
| P2-19 | Thumbnail `resizeMode = .fast` asks Photos for its degraded path, so even the Apple look shown in the grid is Photos' *worst* render. | `PhotoLibraryManager.swift:682` | moot once P0-3 is fixed |

---

## 4. `git diff` analysis — uncommitted changes in the Develop area

`git status`: `M pikicam/Features/Develop/CIRAWZeroProcessor.swift`,
`M pikicamTests/PikicamPipelineTests.swift` (plus camera/storage/UI files outside this topic).
`git diff HEAD --stat` for the Develop area: `CIRAWZeroProcessor.swift | 118 ++--`.

**What changed**
- `applyZeroRecipe(_:)` rewritten from ten inline `apply(filter, "name") { … }` calls to a
  data-driven `static var recipe: [(objcProperty: String, neutralize: (CIRAWFilter) -> Void)]`
  with **15** entries. Five are new: `boostShadowAmount`, `colorNoiseReductionAmount`,
  `detailAmount`, `moireReductionAmount`, `extendedDynamicRangeAmount`. Of those, four carry
  **non-neutral measured defaults** (`boostShadowAmount = 0.9`, `colorNoiseReductionAmount = 0.5`,
  `detailAmount = 0.5`; `moireReductionAmount = 0.0` on this fixture, `extendedDynamicRangeAmount`
  is already 0). So the uncommitted change is a genuine improvement to the *list*.
- The two flags' probe strings corrected from `isLensCorrectionEnabled` / `isGamutMappingEnabled` to
  `lensCorrectionEnabled` / `gamutMappingEnabled`, because the header declares
  `@property(readwrite, getter= isLensCorrectionEnabled) BOOL lensCorrectionEnabled`, so the real
  setter is `setLensCorrectionEnabled:`. Also a genuine fix — `setIsLensCorrectionEnabled:` is
  implemented by nothing.
- `applyZeroRecipe` promoted from `private` to internal so tests can apply it to a filter they
  hold.
- Two new tests: `testZeroRecipeEnumeratesEveryEnhancementControl` and
  `testZeroRecipeReachesEveryControlOnARealFilter`.

**Net effect on the develop pipeline: none, and one regression.**
- Every one of the 15 additions still goes through the same `responds(to:)` gate at
  `CIRAWZeroProcessor.swift:124`, which MEASURED returns `false` for all 15 on iOS 26.5. The list
  got longer; the behaviour did not change: the recipe remains inert.
- The change did **not** touch `CIRAWFilter(imageData:)` at line 31 — the actual root cause.
- `testZeroRecipeReachesEveryControlOnARealFilter` reads properties back unguarded and
  **crashes the test host** (measured). So the uncommitted work turns a green-ish suite red.
  `xcodebuild test` on this machine reports `** TEST FAILED **` for
  `PikicamPipelineTests.testZeroRecipeReachesEveryControlOnARealFilter`.

**`docs/prompt-next.md` is untracked and will feed the next prompt — its §0.1 must be corrected.**
It states that the simulator's `CIRAWFilterImpl` *"does not implement `setBaselineExposure:`"* and
that *"the correct fix is to set via the `input*` key path"* / to *"enumerate the runtime methods
of a `CIRAWFilter` on physical hardware"*. MEASURED refutation: the `input*` key path throws
`this class is not key value coding compliant for the key inputBaselineExposure` (and the same for
all 22 `input*` keys tried) while the **stub** is in play, and the **real** filter does not need it
at all — one initializer change makes all 15 setters reachable. Phase 0 as written will consume a
device cycle to confirm that the real device's real filter already works.

---

## 5. Open questions / assumptions

1. **Device vs simulator.** All runtime measurements are from the **iOS 26.5 simulator**
   (`arm64-apple-ios26.5-simulator`, iPhone 17 Pro, Xcode 26.6). The stub-vs-real initializer
   split is an iOS-version behaviour; it is very likely identical on device (same
   `CIRAWFilterImpl` class name, same runtime) but that is **UNVERIFIED**. Everything marked
   MEASURED should be re-run once on hardware before the implementation prompt is trusted
   end-to-end. The single-line initializer change is safe regardless.
2. **`CIRAWFilter.linearSpaceFilter` on current iOS — UNVERIFIED.** The header still declares it,
   but reports of the older `input*` API being ignored on newer iOS are common. Before designing
   Stage 3 around it, prove on device that an injected filter actually runs and can observe the
   image's color space / dynamic range at that point.
3. **What exactly does `boostAmount = 0` change?** MEASURED: the output's `CIImage.colorSpace`
   stays `kCGColorSpaceDisplayP3` and the CGImage is 8-bit; statistics move (avgR 120 → 102 with
   the full recipe; → 135 with boost alone). The precise transform is not documented and was not
   derived here. If the product wants a *linear working space*, it must create one explicitly.
4. **Core Image's working→destination rendering intent — UNVERIFIED.** There is no
   `kCIContextRenderingIntent` in the iOS 26.5 headers, so the intent is ColorSync's platform
   default; the specific value was not measured.
5. **`baselineExposure` policy.** The prior work order recommends *removing* the recipe entry; I
   recommend *removing it and re-implementing exposure as a visible user control*. If the owner
   wants neither, the +0.302 EV must at minimum be disclosed in the UI copy. This is an owner
   decision, not a unilateral one.
6. **`baselineExposure`'s source.** It matches the DNG's `0xC62A` (`ShadowScale`) value exactly for
   this fixture. Whether that is always true, and how it behaves for other iPhone models, is
   **UNVERIFIED**.
7. **Target pipeline assumes Stage 2 is unavoidable.** Verified for the fixture: no public colour
   matrix / white level / baseline exposure in the DNG. If a decision is made to ship per-model
   calibration tables instead, that changes the architecture substantially.
8. **What "our own look" should *be*.** A zero-linear image is not a photograph (P0-4). The target
   needs a designed default curve and a designed set of user controls. That is a product/design
   decision this audit cannot make; it should be an explicit deliverable of the implementation
   prompt.
9. **Scope note.** This audit covers the develop/render/encode path only. The UI/UX of the camera
   and gallery is another work stream; findings here about flatness, missing zoom, and Apple's
   thumbnails are the develop-pipeline causes of what that work stream will see.
10. **Repo hygiene observed but out of scope:** `pikicamTests/Fixtures/*.DNG` is git-ignored, so a
    fresh clone skips every develop test (`PikicamPipelineTests.swift:40,76,543`) — CI on another
    machine would report *green* while asserting nothing.

---

## 6. Sources

**Repository (file:line, this tree)**
- `pikicam/Features/Develop/CIRAWZeroProcessor.swift:31` (1-arg `CIRAWFilter(imageData:)`),
  `:56-62` (exclusions incl. the wrong `highlightRecoveryEnabled` rationale), `:63-81` (the
  15-entry recipe), `:65` (`baselineExposure = 0.0`), `:67` (`boostAmount = 0.0`), `:77`
  (`extendedDynamicRangeAmount = 0.0`), `:79` (`gamutMappingEnabled = false`), `:95-99`
  (`applyZeroRecipe`), `:121-125` (the silent `responds(to:)` skip)
- `pikicam/Features/Develop/DevelopService.swift:15` (actor), `:21-33` (`init`: Metal +
  `CIContext` with `cacheIntermediates: false`, `outputColorSpace: Display P3`), `:45-50`
  (orientation claim), `:57-71` (`render`), `:62` (`develop`), `:66-68` (`cropped(to:)`),
  `:77` (`createCGImage`, 8-bit), `:86-104` (`CaptureOrientation`, unused by develop)
- `pikicam/Features/Develop/RAWProcessor.swift:14-21` (`RAWProcessor`), `:25-36`
  (`DNGDisplayRendition`), `:38-52` (`DevelopError`, 2 cases)
- `pikicam/Features/Gallery/GalleryView.swift:154` (`@State private var developService =
  DevelopService()`), `:165-168` (`.scaledToFit()`, no zoom), `:169-176` (stuck failure state),
  `:229-246` (`.task(id:)` develop), `:249-272` (`AsyncThumbnail` → Photos)
- `pikicam/Core/Storage/PhotoLibraryManager.swift:665-683` (`requestThumbnail`,
  `version = .current`, `resizeMode = .fast`), `:695` (`PHImageManager.requestImage`), `:14,98,914`
  (`CaptureOrientation` persisted), `:806-808` (`isDNGResource`)
- `pikicam/Features/Camera/CaptureService.swift:497` (`capturePhoto`), `:536`
  (`AVCapturePhotoSettings(rawPixelFormatType:)`), `:676` (`isAppleProRAWEnabled = false`),
  `:638-648` (Bayer allowlist)
- `pikicam/Features/Camera/CameraControls.swift:125-165` (`AspectRatio`), `:172-201` (`PrintCrop`)
- `pikicam/Core/Design/ControlIDRegistry.swift:62` (`viewerShare` registered, no view)
- `pikicamTests/PikicamPipelineTests.swift:11` (false "viewable JPEG" comment), `:38-66` (vacuous
  develop test), `:74-107` (the one meaningful crop/orientation test), `:427-436` (test's own
  bare `CIContext()`), `:492-539` (duplicate-list test), `:541-590` (the test that crashes)
- `pikicamTests/Fixtures/IMG_1361.DNG` — parsed byte-level (see §7)
- `docs/prompt-next.md` §0.1 (untracked; diagnosis refuted in §4)
- `docs/design/spec-gallery-viewer-spec.md:56` (stuck-state gap), `:230-232` (the develop
  disclosure copy, incl. `TONE MAP (CORE PIPELINE, NOT DEFEATABLE)` — which P0-4 refutes:
  `boostAmount` *is* the global tone curve control)

**Apple SDK headers read directly on this machine**
`/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.5.sdk/System/Library/Frameworks/CoreImage.framework/Headers/`
- `CIRAWFilter.h` — full control set, documented defaults, `NS_AVAILABLE(16_0,19_0)` on
  highlight recovery, `linearSpaceFilter`
- `CIRAWFilter_Deprecated.h` — the `kCIInput*` key set and their documented defaults
- `CIContext.h` — `kCIContextOutputColorSpace` ("default output space is sRGB"),
  `kCIContextWorkingColorSpace` ("default working space is the extended sRGB color space with
  linear gamma"), `kCIContextWorkingFormat` (default `RGBAh`), `kCIContextCacheIntermediates`,
  `kCIContextMemoryLimit`, `writeJPEGRepresentationOfImage:` / `writeHEIFRepresentationOfImage:`
- `CIRenderDestination.h` — `initWithMTLTexture:commandBuffer:`

**External**
- Apple, *Enhance RAW image processing with Core Image* (WWDC26 session 305) —
  https://developer.apple.com/videos/play/wwdc2026/305/ ; transcript digest:
  https://wwdc-quick-look.swiftgg.team/en/articles/wwdc2026-305/ — RAW 9 = fused demosaic+denoise
  on ANE; `colorNoiseReductionAmount` / `detailAmount` / `moireReductionAmount` have no effect in
  RAW 9; RAW 9 not auto-enabled; interactive vs export `CIContext` configuration;
  `memoryLimit` guidance; `CIImageProcessorKernel` tiling and temporary buffers
- Apple, *CIRAWFilter* — https://developer.apple.com/documentation/coreimage/cirawfilter and
  https://docs.developer.apple.com/tutorials/data/documentation/coreimage/cirawfilter.md —
  full property list incl. `despeckleAmount`, `downloadResources`,
  `supportedCameraModels(for:)`
- Apple, *boostAmount* — https://docs.developer.apple.com/tutorials/data/documentation/coreimage/cirawfilter/boostamount.md —
  "A value of 0 indicates no global tone curve (linear response) … The default value is 1."
- Apple, *decoderVersion* — https://developer.apple.com/documentation/coreimage/cirawfilter/decoderversion
- Apple, *linearSpaceFilter* — https://developer.apple.com/documentation/coreimage/cirawfilter/linearspacefilter
- Apple Developer Forums, *CIRAWFilter decoderVersion scope* — https://developer.apple.com/forums/thread/834485
- PetaPixel, *Apple's RAW Processing Is Finally Evolving After a Decade* (2026-06-10) —
  https://petapixel.com/2026/06/10/apples-raw-processing-is-finally-evolving-after-a-decade-and-its-a-big-deal/
- Apple's custom-`CIFilter` route — https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/CoreImaging/ci_custom_filters/ci_custom_filters.html

---

## 7. Reproduction — how the MEASURED results were obtained

```bash
# SDK control inventory
grep -n "@property" $SDK/System/Library/Frameworks/CoreImage.framework/Headers/CIRAWFilter.h

# API-presence checks (proves which symbols exist on iOS 26.5)
xcrun -sdk iphonesimulator swiftc -target arm64-apple-ios26.5-simulator -typecheck probe.swift
#   -> CIRAWFilter.despeckleAmount / .downloadResources: NOT FOUND
#   -> CIContextOption.memoryTarget: FOUND (renamed from kCIContextMemoryLimit)
#   -> CIContext.heifRepresentation / jpegRepresentation / pngRepresentation / tiffRepresentation: FOUND
#   -> CIFilter.customImage(): NOT FOUND   |   CIImageProcessorKernel: FOUND
#   -> CIRenderDestination.init(mtlTexture:commandBuffer:): FOUND

# Runtime behaviour (arm64 simulator binary, run under simctl spawn on iPhone 17 Pro)
#   /tmp/pikiprobe/cmp.swift    -> initializer A/B/C/D class comparison + defaults table
#   /tmp/pikiprobe/hint.m       -> full default table, recipe read-back, ZERO/APPLE render stats
#   /tmp/pikiprobe/initcheck.m  -> ObjC cross-check of all initializers
#   /tmp/pikiprobe/ciprobe.swift-> responds() matrix for every recipe entry

# The repo's own develop tests
xcodebuild test -project pikicam.xcodeproj -scheme pikicam \
  -destination 'platform=iOS Simulator,id=BB29A4C9-8EA3-4BB1-99CC-1A3ED2AF5C6B' \
  -derivedDataPath /tmp/pikidd \
  -only-testing:pikicamTests/PikicamPipelineTests/testZeroDevelopProducesViewableJPEGFromRealDNG \
  -only-testing:pikicamTests/PikicamPipelineTests/testZeroRecipeReachesEveryControlOnARealFilter
#   -> first PASSES (2.215s, vacuously), second FAILS 15 assertions then CRASHES the host

# DNG fixture tag dump (TIFF/IFD parse of pikicamTests/Fixtures/IMG_1361.DNG)
#   IFD0: Orientation=6, DNGVersion=1.4.0.0, 0xC62A(ShadowScale)= -324502784/1073741824 = -0.30221677
#         0xC6FC(ProfileToneCurve)=257 pts, ProfileName="Apple Embedded Color Profile"
#   RAW SubIFD @4906: 0xC618 LinearizationTable (4096 SHORT), 0xC61A BlackLevel=(0,0,0),
#                     0xC61D AsShotNeutral=(65535,65535,65535), 0xC761 NoiseProfile (2 doubles),
#                     0xCD2D private (49408 B)
#   ABSENT everywhere: ColorMatrix1/2, CameraCalibration1/2, ForwardMatrix1/2, OpcodeList1/2/3,
#                     ReductionMatrix1/2, WhiteLevel, BaselineExposure, DefaultScale, AnalogBalance
```

**No file in the repository was created, modified, deleted, stashed or reverted by this audit.**
All probe artifacts live in `/tmp/pikiprobe` and `/tmp/pikidd`; the only file written inside the
repo is this report.