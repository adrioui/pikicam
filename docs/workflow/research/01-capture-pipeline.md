# 01 — Capture pipeline audit: where Apple post-processing still leaks in

**Repo:** `/Users/adrifadilah/Desktop/pikicam` (branch `main`, HEAD `e5e976a`, uncommitted working tree preserved)
**Date:** 2026-10-02
**Scope:** end-to-end trace of `AVCaptureSession` → `AVCapturePhotoOutput` → `AVCapturePhotoSettings` → delegate → DNG bytes → PhotoKit, plus device/format-level settings, the preview path, and capture-time exposure/focus/WB/ISO controls.
**Method:** every Swift file in `pikicam/Features/Camera/`, `pikicam/Core/Storage/`, `pikicam/App/`, `pikicam/Features/Develop/`, `pikicam/Features/Gallery/` read in full; `git diff` reviewed; **the iOS 26.5 SDK headers on this machine were used as the primary source of truth** (`xcrun --sdk iphoneos --show-sdk-path` → `/Applications/Xcode.app/.../iPhoneOS26.5.sdk`), because Apple's DocC prose omits the normative validation rules that live in `AVCapturePhotoOutput.h`. The repo's own DNG fixture was parsed to see what Apple actually writes into an iPhone DNG.

Header citations below use `SDK:<file>:<line>` = path relative to
`/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.5.sdk/System/Library/Frameworks/`.

---

## Summary — top 10 findings

| # | Sev | Finding | Anchor |
|---|-----|---------|--------|
| 1 | **P0** | **Geometric Distortion Correction is ON by default where supported and is *always* applied to `AVCaptureVideoPreviewLayer`, but "RAW photo captures never have GDC applied".** The app never reads `isGeometricDistortionCorrectionSupported` nor sets `isGeometricDistortionCorrectionEnabled`. Result: the viewfinder is Apple-corrected/narrower-FOV while the saved DNG is uncorrected/wider-FOV — the single most visible "Apple is still in the loop" leak, and it breaks what-you-see-is-what-you-get. | `CaptureService.swift` (0 hits for `GeometricDistortionCorrection`); `SDK:AVFoundation/AVCaptureDevice.h:2267,2272-2286` |
| 2 | **P0** | **Center Stage is user-controllable from Control Center by default** (`centerStageControlMode` defaults to `.user`), and when active "the camera automatically adjusts to keep people optimally framed… The field of view may pan, tighten or widen as needed." Apple reframes the capture; the app cannot prevent it because it never takes app control. | `SDK:AVFoundation/AVCaptureDevice.h:2333-2372`; repo grep: 0 hits for `centerStage` |
| 3 | **P0** | **`photoQualityPrioritization` is left at the default `.balanced`, but Apple documents Bayer RAW requires `.speed`**, and `.balanced`-or-higher is the exact threshold at which "the receiver's ISO and exposureDuration values **may be overridden** when exposing the photo if the scene is dark enough to warrant some form of multi-image fusion." The code comment states the requirement backwards. | `CaptureService.swift:536-539`; `SDK:AVFoundation/AVCapturePhotoOutput.h:84-86`, `SDK:AVFoundation/AVCaptureDevice.h:1381` |
| 4 | **P0** | **The viewfinder is 100 % Apple's ISP output.** `AVCaptureVideoPreviewLayer` renders the device's demosaiced, tone-mapped, noise-reduced, (stabilized-or-not) video stream; there is no raw preview path in the app. `automaticallyAdjustsVideoHDREnabled` **defaults to YES**, so AVFoundation may engage EDR streaming, which literally "capture[s] an under-exposed frame and correctly exposed frame for each frame time" and combines them. | `PreviewView.swift:14-20,62-64`, `CameraPreview.swift:26`; `SDK:AVFoundation/AVCaptureDevice.h:2147-2151`, `SDK:AVFoundation/AVCaptureDevice.h:3349-3353` |
| 5 | **P1** | **Nothing at runtime proves the payload is Bayer RAW.** `resolvedSettings` is accepted and discarded; `photo.isRawPhoto` is never asserted; the pixel format of `photo.pixelBuffer` is never checked; `CapturedDNG.init` validates only "non-empty". Any future refactor adding `processedFormat` silently ships an Apple-processed image into a `.dng` resource. | `PhotoCapture.swift:101-103`, `CaptureService.swift:556-560`, `PhotoLibraryManager.swift:29-35` |
| 6 | **P1** | **RAW resolution is chosen by a default, not by the app.** `maxPhotoDimensions` is never set (settings-level default = *smallest* entry of `activeFormat.supportedMaxPhotoDimensions`), and `activeFormat` is never read anywhere in the repo. On formats with more than one supported max photo dimension the app silently gets the smallest. | `SDK:AVFoundation/AVCapturePhotoOutput.h:539-547,1449-1456`, `SDK:AVFoundation/AVCaptureDevice.h:3483-3490`; repo grep: 0 hits for `activeFormat`/`maxPhotoDimensions` |
| 7 | **P1** | **Framing zoom is a post-capture software crop and the framing overlays are frozen at 1×**, so the aperture mask/grid never follow the pinch and the develop-time crop is a centred `1/Z` rect rather than the rect the preview actually showed. | `CaptureService.swift:482-488,518-533`, `CameraView.swift:355`, `CameraControls.swift:198-215` |
| 8 | **P1** | **The front camera cannot produce Bayer RAW** (`availableRawPhotoPixelFormatTypes` is empty for it; ProRAW is the only RAW on the front), yet the flip control is a shipped feature. Every front capture fails with `noBayerFormatAvailable`, surfaced as a bare red text banner. | `CaptureService.swift:235,657-665`; Apple `availableRawPhotoPixelFormatTypes` docs; Apple iPhone user guide (ProRAW "is available on all cameras, including the front camera") |
| 9 | **P1** | **Zero manual controls.** No `.custom` exposure / ISO / shutter, no white-balance mode or gains (iOS 26 even adds Kelvin/tint presets + `setWhiteBalanceModeLocked(temperatureAndTintValues:)`), no focus lock. Apple's AEA and AWB algorithms are baked into every DNG (`AsShotNeutral`, `BaselineExposure`) and nothing in the capture path records or fights them. | repo grep: 0 hits for `whiteBalance`, `exposureDuration`, `.ISO`, `activeFormat` |
| 10 | **P1** | **The test fixture is not the payload the app produces.** `pikicamTests/Fixtures/IMG_1361.DNG` is an Apple **ProRAW / "Linear DNG"** (LinearRaw plane, no `CFAPattern`, private tag `0xC6F8 = "Apple Embedded Color Profile"`) and it even embeds an auxiliary **semantic segmentation matte** (`urn:com:apple:photo:2020:aux:semanticskymatte`) — i.e. the develop tests run against a Photonic-Engine-era artifact while the app captures 14-bit Bayer. | fixture IFD dump (this repo, `pikicamTests/Fixtures/IMG_1361.DNG`) |

Two further items that are *not* leaks but are load-bearing and must not be "cleaned up": Apple's documented Bayer-RAW rule that `videoZoomFactor` must be 1.0 (the app's capture-at-1× dance is mandatory), and the fact that **virtual devices explicitly do not support `AVCaptureExposureModeCustom`** — which is the only reason the current physical-wide-device selection makes manual exposure possible at all.

---

## Verified-correct (do not regress)

These are genuinely right today, with the exact evidence, so the rewrite preserves them:

1. **ProRAW is off.** `photoOutput.isAppleProRAWEnabled = false` (`CaptureService.swift:676-680`), set before `startRunning()`, which is what Apple requires (`SDK:AVFoundation/AVCapturePhotoOutput.h:193-202`). Because ProRAW formats are only *added* to `availableRawPhotoPixelFormatTypes` when this is YES, the list contains Bayer formats only.
2. **No processed companion image is produced anywhere.** Settings are created with `AVCapturePhotoSettings(rawPixelFormatType:)` (`CaptureService.swift:536`) — the RAW-only factory. `format`/`processedFormat`, `previewPhotoFormat`, `embeddedThumbnailPhotoFormat`, `rawEmbeddedThumbnailPhotoFormat` are never set. Therefore no JPEG/HEIC is generated by AVFoundation at all, and `photo.CGImageRepresentation` would return nil anyway ("RAW images always return a CGImageRepresentation of nil", `SDK:AVFoundation/AVCapturePhotoOutput.h:2226-2231`).
3. **Every other computational-photography switch is already at a safe default and is never enabled.** Per the SDK headers: `autoStillImageStabilizationEnabled` "Default is YES **unless you are capturing a Bayer RAW photo**" (`AVCapturePhotoOutput.h:1384-1394`); `autoRedEyeReductionEnabled` default YES "…or a RAW photo without a processed photo" (`:1340-1352`); `autoVirtualDeviceFusionEnabled` "Default is YES **unless you are capturing a RAW photo**" (`:1396-1404`); `autoContentAwareDistortionCorrectionEnabled` "Default is NO" (`:1643-1650`); `virtualDeviceConstituentPhotoDeliveryEnabled` "Default value is NO" (`:459-466`); `portraitEffectsMatteDeliveryEnabled`, `enabledSemanticSegmentationMatteTypes`, `depthDataDeliveryEnabled` default NO/empty. → **no Deep Fusion, no Smart HDR, no Night Mode fusion, no semantic rendering, no portrait mattes.** This is the core promise and it currently holds.
4. **Capture-at-1× is mandatory, not a hack.** `SDK:AVFoundation/AVCapturePhotoOutput.h:84-86`: "Bayer RAW rules … the videoZoomFactor of the source device and the videoScaleAndCropFactor of the photo output's video connection must both be 1.0."
5. **Video stabilization is off by default** (`preferredVideoStabilizationMode` "The default value is `AVCaptureVideoStabilizationModeOff`", `SDK:AVFoundation/AVCaptureSession.h:1232`), which is good for WYSIWYG (no EIS reframing) and avoids the documented "high resolution photos may be smaller by 10 or more percent" coupling (`AVCapturePhotoOutput.h:1442`).
6. **The PhotoKit save is genuinely DNG-only.** One `PHAssetCreationRequest.forAsset()` with one `addResource(with: .photo …)` and `uniformTypeIdentifier = com.adobe.raw-image` (`PhotoLibraryManager.swift:364-390`); `UTType(filenameExtension: "dng")` really is `com.adobe.raw-image` (Apple `UTTypeDNG` docs), so the UTI is right; the reconciler asserts a single DNG resource.
7. **The Bayer pixel-format allow-list is factually complete** for the formats CoreVideo defines (`SDK:CoreVideo/CVPixelBuffer.h:103-106` lists exactly `14Bayer_GRBG/RGGB/BGGR/GBRG`). It should still be replaced by Apple's classifier (finding 13), but nothing is missing today.

---

## Detailed findings

### F1 — P0 · Geometric Distortion Correction: the viewfinder is Apple-corrected, the DNG is not

**Evidence**
- `SDK:AVFoundation/AVCaptureDevice.h:2267` (on `geometricDistortionCorrectionSupported`): "When GDC is enabled on the AVCaptureDevice … the full viewable field of view is always represented with a videoZoomFactor of 1.0. Thus, when GDC is enabled, the AVCaptureDevice.activeFormat's field of view at videoZoomFactor = 1.0 will be different than when GDC is disabled … **Beware though that RAW photo captures never have GDC applied**, regardless of the value of AVCaptureDevice.geometricDistortionCorrectionEnabled."
- `SDK:AVFoundation/AVCaptureDevice.h:2272-2286` (on `geometricDistortionCorrectionEnabled`): "**Where supported, the default value is YES.**" and "It is always applied to `AVCaptureVideoPreviewLayer`."
- `SDK:AVFoundation/AVCaptureSession.h:1282`: "Starting in iOS 14.3, camera intrinsics are delivered with video buffers on which geometric distortion correction is applied."
- Repo: `grep -rn "GeometricDistortionCorrection" pikicam/` → **0 hits**. Nothing in `configureSessionIfNeeded` (`CaptureService.swift:104-149`) or `configureRAWOutput` (`:676-680`) touches it.

**Why it matters**
Two failures at once. (a) *Look*: the viewfinder shows a rectified, upscaled image; the developed DNG shows barrel/pincushion at the edges — the user composes against a picture that does not exist in the file. (b) *Framing*: the GDC-corrected FOV is **narrower** than the uncorrected one, so at the default 1× the user frames a tighter view than the sensor records; whatever is at the frame edge is silently outside the develop crop. `PrintCrop` (`CameraControls.swift:198-215`) is computed against the full developed extent and knows nothing about GDC. GDC is supported on the ultra-wide on Pro models and, per iOS 14.5+, on more configurations — and on a *physical wide* device today its support state is unknown and unpinned (UNVERIFIED per device).

**Recommended fix direction**
At configuration time, under the existing `lockForConfiguration()`, do:
```
if device.isGeometricDistortionCorrectionSupported {
    device.isGeometricDistortionCorrectionEnabled = false   // preview must equal RAW
}
```
and expose `isGeometricDistortionCorrectionSupported` in a capabilities probe used by the UI. If the product later *wants* a corrected preview, the honest inverse is to keep GDC off in the preview and apply our own lens correction at develop time (from the DNG's own distortion metadata or a calibrated model) — never to let the preview disagree with the file.

---

### F2 — P0 · Center Stage: Apple can reframe the capture and the app has no defence

**Evidence**
- `SDK:AVFoundation/AVCaptureDevice.h:2333-2337`: `AVCaptureCenterStageControlModeUser = 0` is the default.
- `:2345` (on `centerStageControlMode`): "When set to the default value of `AVCaptureCenterStageControlModeUser`, `centerStageEnabled` may not be set programmatically and **throws an `NSInvalidArgumentException`**. In User mode, the feature may only be set by the user in Control Center."
- `:2360-2372` (on `centerStageActive`): "When active, the camera automatically adjusts to keep people optimally framed within the field of view. **The field of view may pan, tighten or widen as needed.**" Plus restrictions on `min/maxAvailableVideoZoomFactor` and frame-rate ranges.
- Repo: `grep -rn -i "centerstage" pikicam/` → **0 hits**.

**Why it matters**
A user who flips the Control Center "Center Stage" toggle gets captures whose framing was chosen by Apple — panned, tightened or widened — with no indication in the app and nothing in the saved metadata. For a product whose entire claim is "no Apple processing", this is a silent reframing of the photograph. It also invalidates every framing assumption in the app (the 1× framing baseline, `PrintCrop`, the tap-to-meter point mapping, the aperture mask). Whether the still or only the video stream is reframed on current hardware is **UNVERIFIED** — the header documents device-level FOV/zoom-range effects, not a photo-specific carve-out; treat it as affecting the capture until a device probe proves otherwise.

**Recommended fix direction**
Take exclusive app control at session configuration, before `startRunning()`:
```
AVCaptureDevice.centerStageControlMode = .app     // class property
AVCaptureDevice.centerStageEnabled = false
```
then KVO/assert `device.isCenterStageActive == false` at shutter time and surface it in the capture provenance. Also record `minAvailableVideoZoomFactor/maxAvailableVideoZoomFactor` per configuration (they are restricted while Center Stage is active) so the UI cannot publish a zoom the device will not honour. If Control-Center user control is a product requirement, use `.cooperative` and *observe* `centerStageEnabled`, showing an explicit "Center Stage is reframing your photos" state.

---

### F3 — P0 · `photoQualityPrioritization` is left on Apple's non-RAW default; `.speed` is the documented requirement

**Evidence**
- `SDK:AVFoundation/AVCapturePhotoOutput.h:84-86` ("Bayer RAW rules"): "**photoQualityPrioritization must be set to `AVCapturePhotoQualityPrioritizationSpeed`** (deprecated `autoStillImageStabilizationEnabled` must be set to `NO`)."
- `SDK:AVFoundation/AVCaptureDevice.h:1381` (`exposureMode` discussion): "When using AVCapturePhotoOutput and capturing photos with `AVCapturePhotoSettings`' `photoQualityPrioritization` property set to `AVCapturePhotoQualityPrioritizationBalanced` **or higher**, the receiver's ISO and exposureDuration values **may be overridden when exposing the photo** if the scene is dark enough to warrant some form of multi-image fusion to improve quality. To ensure that the receiver's ISO and exposureDuration values are honored … you must set … `AVCapturePhotoQualityPrioritizationSpeed`."
- Default is Balanced (`AVCapturePhotoOutput.h:1207`, `:1375-1382`).
- Repo: `CaptureService.swift:536-539` — comment reads *"Never set `photoQualityPrioritization` on RAW captures: AVFoundation raises NSInvalidArgumentException ("Unsupported when capturing RAW") at capture time. The default (.balanced) is used."*

**Why it matters**
The code's stated reason is the opposite of Apple's requirement. Today the app survives only because Apple's runtime validation appears to reject `.quality` (owner-observed on-device crash log) and accept `.balanced` — i.e. it is relying on an accident of validation thresholds while sitting one notch above the mandated value. The consequence of being wrong is precisely the product's worst failure mode: in a dark scene the DNG contains an exposure Apple chose, not the one the app metered and displays. The app currently has no way to detect it: it never reads `device.ISO`, `device.exposureDuration`, or `resolvedSettings`.

**Recommended fix direction**
Set it explicitly and make the intent checkable:
```
var settings = AVCapturePhotoSettings(rawPixelFormatType: bayerFormat)
settings.photoQualityPrioritization = .speed          // mandated for Bayer RAW
```
and at shutter time snapshot `device.ISO`, `device.exposureDuration`, `device.aperture` (and `photo.metadata`'s EXIF dict) into a provenance struct persisted alongside the capture. Add a device-only test that captures a dim scene and asserts the DNG's own `BaselineExposure`/`ExposureTime`/`ISOSpeedRatings` tags match the snapshot — that is the only way to prove no fusion override happened.

---

### F4 — P0 · The preview is Apple's entire ISP pipeline, and EDR streaming may be auto-enabled on top

**Evidence**
- `PreviewView.swift:14-20,58-64`: the view's `layerClass` is `AVCaptureVideoPreviewLayer`, `videoGravity = .resizeAspectFill`; its doc comment *advertises* "automatic HDR tone-mapping and support for iOS 26 Deferred Start" as a feature.
- No `AVCaptureVideoDataOutput` anywhere in the repo (`grep "VideoDataOutput" → 0`), so no raw frames ever reach our code.
- `SDK:AVFoundation/AVCaptureDevice.h:2147-2151` (`automaticallyAdjustsVideoHDREnabled`): "**This property defaults to YES.** When `automaticallyAdjustsVideoHDREnabled`, the AVCaptureDevice turns videoHDR on automatically if it's a good fit for the activeFormat."
- `SDK:AVFoundation/AVCaptureDevice.h:3349-3353` (`isVideoHDRSupported`): "the device streams at twice the published frame rate, **capturing an under-exposed frame and correctly exposed frame for each frame time** … Portions of the under-exposed frame are combined with the correctly exposed frame to recover detail in darker areas."
- `SDK:AVFoundation/AVCaptureSession.h:1232`: video stabilization defaults to `Off` (so the preview *is* un-stabilized while the still carries OIS — a second WYSIWYG mismatch, in the motion domain).
- Repo: `grep "deferredStart"` → **0 hits**, so the doc comment's "iOS 26 Deferred Start" claim is code-vs-doc drift.

**Why it matters**
The viewfinder shows demosaiced, noise-reduced, sharpened, tone-mapped, geometrically-corrected (F1), possibly-HDR-fused frames from Apple's ISP. The saved DNG does not. Every "WYSIWYG" statement in the product is therefore false by construction, and the owner cannot show a side-by-side of "what I saw" vs "what I got" without it being a lie. Apple's EDR default is the sharpest example: the streaming pipeline may be *combining two exposures* behind the user's eyes.

**Recommended fix direction** (pick deliberately, and record the choice)
1. *Minimum, ship-blocking:* pin the device so the preview is at least deterministic and honest —
   `device.automaticallyAdjustsVideoHDREnabled = false`; `device.videoHDREnabled = false` if the format supports it;
   force `connection.preferredVideoStabilizationMode = .off` on the preview connection; log `device.isVideoFrameDurationLocked`, `device.activeFormat.videoFieldOfView`, `device.isCenterStageActive`, `device.isLowLightBoostEnabled`, `device.isGeometricDistortionCorrectionEnabled` into the capture record. Say plainly in the UI/README that the viewfinder is Apple's ISP rendering.
2. *The real fix:* an optional **RAW preview path** — `AVCaptureVideoDataOutput` whose `availableVideoPixelFormatTypes` contains a 14-bit Bayer format (runtime check; device support is **UNVERIFIED**), demosaiced by our own Metal kernel with the same geometry as `DevelopService`, drawn through `CAMetalLayer`. This is the only construction in which "what you see is what you get" is literally true. Ship it behind a setting; it will be lower resolution and slower, which is a fair trade for this product.
3. Use iOS 26 deferred start (`AVCaptureSession.automaticallyRunsDeferredStart`, `AVCaptureOutput.deferredStartEnabled`, `runDeferredStartWhenNeeded()`, `SDK:AVFoundation/AVCaptureSession.h:671-727`) to show the first preview frame immediately while the photo pipeline spins up — and to fix the cold-start RAW latency in F19.

---

### F5 — P1 · Nothing proves the captured bytes are Bayer RAW

**Evidence**
- `PhotoCapture.swift:99-103`: the `didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings` parameter is accepted and **never read** (repo grep: 1 hit, the declaration).
- `CaptureService.swift:556-560`: `guard let fileData = photo.fileDataRepresentation()` — no `photo.isRawPhoto` check, no `CVPixelBufferGetPixelFormatType(photo.pixelBuffer)` check.
- `PhotoLibraryManager.swift:29-35`: `CapturedDNG.init` guards only `!data.isEmpty` and the zoom range.
- Available in the SDK for exactly this purpose: `AVCapturePhoto.isRawPhoto` (`SDK:AVFoundation/AVCapturePhotoOutput.h` — "Returns YES if this photo is a RAW image"), `AVCapturePhoto.pixelBuffer` (Bayer RAW such as `bgg4` presents pixel data there), `AVCaptureResolvedPhotoSettings.rawPhotoDimensions`, `.virtualDeviceFusionEnabled`, `.contentAwareDistortionCorrectionEnabled`, `.redEyeReductionEnabled`, `.isStillImageStabilizationEnabled`, `.photoProcessingTimeRange`.

**Why it matters**
The product's contract ("exactly one unchanged full-sensor Bayer DNG") is currently enforced only by the *absence* of code. It has no positive assertion anywhere — not in production, not in tests. A one-line future edit (`settings.format = [AVVideoCodecKey: AVVideoCodecType.jpeg]`, or a helper that centralizes settings construction) silently produces an Apple-processed JPEG, writes it into a resource named `pikicam-<uuid>.dng` with the DNG UTI, and every existing test still passes: the storage test only checks resource type/UTI/filename (`PikicamPipelineTests.swift:150-166`), and the pipeline tests assert `width > 1000` (`PikicamPipelineTests.swift:59-63`).

**Recommended fix direction**
Introduce one `CaptureRequest` type that owns settings construction *and* validation, and make acceptance criteria explicit at the boundary:
- at construction: `AVCapturePhotoOutput.isBayerRAWPixelFormat(format)` must be true (see F13);
- on delivery: `photo.isRawPhoto == true`, and if `photo.pixelBuffer` is non-nil its pixel format must equal the requested `rawPixelFormatType`;
- on `didFinishCaptureFor`: assert `resolvedSettings.rawPhotoDimensions != .zero`, `!resolvedSettings.virtualDeviceFusionEnabled`, `!resolvedSettings.contentAwareDistortionCorrectionEnabled`, `!resolvedSettings.isStillImageStabilizationEnabled`, `!resolvedSettings.isRedEyeReductionEnabled`, and `expectedPhotoCount == 1`;
- on bytes: `CapturedDNG.init` should verify the TIFF/DNG magic (`II*\0`/`MM\0*`) and the presence of `DNGVersion` + a `CFAPattern` (or at minimum a Bayer `PhotometricInterpretation`), replacing the empty-data-only check. Also reject an embedded preview that is not ours (see F14).

---

### F6 — P1 · `maxPhotoDimensions` / `activeFormat`: RAW resolution is a default, not a decision

**Evidence**
- `SDK:AVFoundation/AVCapturePhotoOutput.h:1449-1456` (settings): "The dimensions set must match one of the dimensions returned by `AVCaptureDeviceFormat.supportedMaxPhotoDimensions` … **This property defaults to the smallest dimensions returned by `AVCaptureDeviceFormat.supportedMaxPhotoDimensions`.**"
- `SDK:AVFoundation/AVCapturePhotoOutput.h:539-547` (output-level): "Set this property to enable requesting of images up to as large as the specified dimensions … **Note: When supported, the 24MP setting (5712, 4284) is only serviced as 24MP when opted-in to `autoDeferredPhotoDeliveryEnabled`.**"
- `SDK:AVFoundation/AVCapturePhotoOutput.h:113-114`: "The maxPhotoDimensions setting for 24MP (5712, 4284), when supported, is only serviced as 24MP via deferred photo delivery." (Deferred proxies are never RAW: `SDK:AVFoundation/AVCapturePhotoOutput.h:2304-2310` — `rawPhoto` "Always NO, as deferred processing isn't available for raw photos.")
- `SDK:AVFoundation/AVCaptureDevice.h:3483-3490` (`supportedMaxPhotoDimensions`).
- Repo: `grep "activeFormat\|maxPhotoDimensions\|supportedMaxPhotoDimensions"` → **0 hits**. `session.sessionPreset = .photo` (`CaptureService.swift:117`) is the only format-selection knob, and it is never revisited.

**Why it matters**
Today's DNGs happen to be full-resolution because most formats expose exactly one supported max photo dimension. Where they do not (24 MP-class formats, 48 MP sensors, any future format), the documented default picks the *smallest* — a silent resolution loss on a product whose whole pitch is maximum unprocessed data. And nothing in the codebase can answer "what format produced this DNG": the app never reads `activeFormat`, never reads `resolvedSettings.rawPhotoDimensions`, and only discovers dimensions indirectly from the Photos asset (`PhotoLibraryManager.swift:395-410`). Note also `autoDeferredPhotoDeliveryEnabled` must stay **NO** (default) — turning it on would make the callback deliver a proxy instead of the photo and would change the delegate contract.

**Recommended fix direction**
Before `startRunning()`, and again after any configuration change:
```
let dims = device.activeFormat.supportedMaxPhotoDimensions.compactMap { ($0 as? NSValue)?.cmVideoDimensionsValue }
photoOutput.maxPhotoDimensions = dims.max(by: pixelCount)   // triggers pipeline reconfig; set early
```
and per capture `settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions`; persist `resolvedSettings.rawPhotoDimensions`, `activeFormat.formatDescription`, and the device's `uniqueID`/model in the capture index. Log them once per configuration so a device probe can confirm what the app is really getting.

---

### F7 — P1 · Zoom is a post-capture software crop; framing overlays never follow it

**Evidence**
- `CaptureService.swift:479-488` (doc): capture must run at 1×; `:518-533` implements "remember zoom → set 1.0 → 250 ms settle → capture → restore".
- `CameraControls.swift:198-215` (`PrintCrop.zoomRect`): a *centred* `1/zoomFactor` rect of the aspect rect, clamped to the extent.
- `CameraView.swift:355`: `PrintCrop.rect(in: bounds, zoomFactor: 1.0, aspect: aspectRatio)` — the aperture/grid are always computed at 1×.
- `PreviewView.swift:62-63` / `CameraPreview.swift:26`: preview is `.resizeAspectFill`, so the visible window is itself a further crop of the preview stream.
- `SDK:AVFoundation/AVCaptureDevice.h:1917-1929` (`videoZoomFactor`): "Applies a centered crop for all image outputs, scaling as necessary to maintain output dimensions." and `SDK:AVFoundation/AVCaptureDevice.h:3448`: beyond *native* zoom factors (and always when depth is enabled) "all zoom factors … result in digital upscaling".

**Why it matters**
The crop the user gets is computed by a centred-rect formula, not by the geometry the preview actually showed. It is *approximately* right (AVF's zoom is also a centred crop), but it is wrong whenever: GDC is on (F1), Center Stage reframed (F2), the preview is `resizeAspectFill` and the visible window is not the full stream, or the user framed near an edge. Meanwhile the on-screen mask and grid are frozen at 1×, so at 3× the user composes inside a band that is not the band they get. Compounding it: `videoZoomFactor` is a *digital* crop, so a 5× preset on the physical wide camera is an upscale of the 1× stream — the preview is blurrier than the file, and the "framing zoom" in the index is not an optical fact.

**Recommended fix direction**
Derive the print crop from the same coordinate system the preview uses instead of a centred-rect approximation: at shutter, ask the preview layer for the *visible* sensor rect —
`previewLayer.captureDeviceRectConverted(fromLayerPoint:)` at the two aperture corners — normalise by the zoom factor (the AVF crop is centred and scales by 1/Z), convert to the RAW plane using `resolvedSettings.rawPhotoDimensions` and the DNG's `ActiveArea`/`DefaultCropOrigin`+`DefaultCropSize` tags if present — and store that rect in the index as explicit crop geometry instead of `zoomFactor`. Feed the *same* rect back into the live aperture mask so framing overlays and output agree by construction. Offer real lenses too (`.builtInTelephotoCamera`, `.builtInUltraWideCamera`) as discrete stops; keep the digital crop as an explicit, labelled software step.

---

### F8 — P1 · The front camera cannot deliver Bayer RAW; the flip control is a dead end

**Evidence**
- Apple docs, `availableRawPhotoPixelFormatTypes`: "**If the current device doesn't support RAW capture, this array is empty.**" (It is also an *instance* property that reflects the current device, see F16.)
- `SDK:AVFoundation/AVCapturePhotoOutput.h:194-201`: ProRAW photos "will be demosaiced and partially processed … and allow capturing RAW photos in modes where there is no traditional sensor/Bayer RAW available."
- Apple iPhone user guide (iOS 26): "Apple ProRAW is available on all cameras, **including the front camera**." → the front's only RAW is the computationally processed one.
- Community corroboration: Stack Overflow 47330323 ("Here are three things that will cause the `availableRawPhotoPixelFormatTypes` array to be empty: … You are using the front camera."), 75912737 ("it can only output ProRaw not BayerRaw" on iPhone 14 Pro front).
- Repo: `CaptureService.swift:235` + `:657-665` — `toggleCamera()` runs the same `.builtInWideAngleCamera` discovery for `.front`, so the front device is added; `CaptureService.swift:507-509` then throws `noBayerFormatAvailable` ("No Bayer RAW format is available on this camera."). `README.md:32` lists "Front/back camera switching" as a feature.

**Why it matters**
Every front-camera shot fails, always, and the only feedback is `CameraView.swift:236-241` — a red `Text(error.localizedDescription)` pinned at the bottom of the viewfinder with no affordance and no prevention. A camera app that ships a control which cannot do its one job is worse than one without the control.

**Recommended fix direction**
Make RAW capability a first-class, per-device, observable property: `CaptureCapabilities { supportsBayerRAW, maxPhotoDimensions, supportedFlashModes, gdcSupported, zoomRange, lensFocalLengths }` recomputed after every configuration change. Gate the shutter (`disabled` + an explanatory state) when `supportsBayerRAW == false`, and gate the flip control to devices that can RAW — i.e. in practice, drop the front camera for v1 and say so in the product copy rather than shipping a promise the sensor cannot keep. (Note: keeping the *physical* wide device is deliberate — see F10.)

---

### F9 — P1 · No manual exposure, ISO, white balance or focus lock at all

**Evidence** — repo-wide greps return **0 hits** for `whiteBalance`, `exposureDuration`, `.ISO`, `activeFormat`, `automaticallyAdjustsFocus`, `sensorOrientation`, `lensStabilization`.
- Only exposure control implemented: `exposureTargetBias` via `setExposureTargetBias` (`CaptureService.swift:430-441`), a ±3 EV steering of Apple's AEA — Apple's AE algorithm still chooses the ISO/shutter pair.
- No `whiteBalanceMode` / `setWhiteBalanceModeLocked(withDeviceWhiteBalanceGains:)` (`SDK:AVFoundation/AVCaptureDevice.h:1715-1727,1745,1785`), no `focusModeLocked(lensPosition:)` (`SDK:AVFoundation/AVCaptureDevice.h:1120-1127`).
- iOS 26 additions the app (deployment target 26.5) does not use: `setWhiteBalanceModeLocked(whiteBalanceTemperatureAndTintValues:)` plus the tungsten/fluorescent/daylight/cloudy presets (`SDK:AVFoundation/AVCaptureDevice.h:1676-1690,1782`), `focusRectOfInterest` / `exposureRectOfInterest` with `defaultRectForFocusPointOfInterest:` (`:1162-1185`, `:1406-1427`) — rect metering instead of the single point the app uses (`CaptureService.swift:384-403`).
- Everything Apple computes here is *persisted into the file*: the fixture DNG carries `AsShotNeutral`, `AsShotWhiteXY`, `BaselineExposure ≈ −0.302 EV`, `ColorMatrix1/2`, `CalibrationIlluminant1/2`, `BaselineSharpness = 1.5` (fixture IFD dump).

**Why it matters**
Automatic white balance and automatic exposure are computational decisions, and for a "we develop it ourselves" camera they are decisions the *user* should be making, not Apple. Today the user cannot: there is no ISO readout, no shutter readout, no Kelvin/tint control, no focus lock — a camera app cannot even *display* the parameters of the photograph it just took. It also makes the provenance claim untestable: without `device.ISO`/`exposureDuration`/WB gains at shutter, nothing can verify what the DNG actually contains (which is what F3 needs).

**Recommended fix direction**
Add a **manual mode** built on `AVCaptureExposureMode.custom` with `setExposureModeCustom(duration:iso:)`, clamped to `activeFormat.min/maxISO` and `min/maxExposureDuration`; a WB control using the iOS 26 temperature/tint lock with an AWB-snapshot "lock current" action; focus lock via `focusModeLocked(lensPosition:)` guarded by `isLockingFocusWithCustomLensPositionSupported`. Persist ISO, shutter, aperture, WB gains, focal length, lens stabilization status (`AVCapturePhoto.lensStabilizationStatus`) into the index and show them in the gallery — this is also the cheapest possible "proof of honesty" UI. **Critical coupling:** virtual devices explicitly do *not* support `AVCaptureExposureModeCustom` or custom WB gains (`SDK:AVFoundation/AVCaptureDevice.h:540-545` DualCamera doc, `:556-561` TripleCamera doc: "A device of this type does not support the following features: `AVCaptureExposureModeCustom` and manual exposure bracketing … Locking auto white balance with device white balance gains other than `AVCaptureWhiteBalanceGainsCurrent`"), and "exposure duration, ISO, aperture, white balance gains, or lens position may change when the device switches from one camera to the other". So `selectCamera` returning the **physical** wide device (`CaptureService.swift:657-665`) is a prerequisite for manual control, not an oversight — document that at the function so a future "simplification" to a virtual device does not silently delete the whole manual mode.

---

### F10 — P1 · The viewfinder/print mismatch has a second, structural cause: no capture-time exposure metadata

Covered with F3/F9 from the AVFoundation side. The storage-side consequence: `PikicamCapture` (`PhotoLibraryManager.swift:84-101`) carries only `orientation`, `aspectRatio`, `zoomFactor` — no ISO, shutter, lens, WB, or resolved dimensions — and `IndexRecord` (`PhotoLibraryManager.swift:907-921`) persists the same three. Recommendation: extend both (bump `indexFileVersion`, which the loader already validates at `PhotoLibraryManager.swift:844-847`) with a `CaptureProvenance` struct populated from `photo.metadata` (ImageIO dictionary, which Apple populates with `kCGImagePropertyExifDictionary` — ISO, exposure time, lens model, focal length — see `SDK:AVFoundation/AVCapturePhotoOutput.h` `metadata` docs) plus `resolvedSettings` and the device snapshot. This is the single change that makes the zero-process claim auditable after the fact.

---

### F11 — P1 · Gallery thumbnails are Apple's develop; the viewer is ours

**Evidence** — `PhotoLibraryManager.swift:676-684`: `options.version = .current`, `deliveryMode = .opportunistic`, `resizeMode = .fast`, `isNetworkAccessAllowed = true`; target size 300×300 (`PikicamLibraryModel.swift:74`). The viewer's image is `DevelopService.render(...)` (`GalleryView.swift:214-222`).

**Why it matters**
The grid shows Photos' own raw conversion (Apple's default raw develop, which is *not* the zero recipe) while the viewer shows the zero-process develop. Same file, two looks; the user has no way to tell which one is "the photograph". For this product that is a credibility bug, not a polish bug.

**Recommended fix direction**
Render grid thumbnails through the same `DevelopService`/`CIRAWZeroProcessor` (develop once at ~256–512 px, cache in the index directory keyed by capture id), falling back to PhotoKit only while the cache is cold, and label the fallback if it is ever visible. If a fast path is needed, request `settings.previewPhotoFormat` at capture time (`SDK:AVFoundation/AVCapturePhotoOutput.h:1592-1600`) — for a RAW-only capture that yields a **RAW** preview buffer (not a processed one), so it must be demosaiced by us, never handed to `UIImage`.

---

### F12 — P1 · The develop/test fixture is Apple ProRAW with an embedded semantic matte — the payload the app never produces

**Evidence** — parsing `pikicamTests/Fixtures/IMG_1361.DNG` (an iPhone 12 Pro file, `Software 14.3`, `UniqueCameraModel "iPhone13,3 back camera"`):
- IFD0: `ImageWidth 4032 × ImageLength 3024`, `Orientation = 6`, `ColorMatrix1/2`, `AsShotNeutral`, `BaselineExposure`, `BaselineSharpness (0xC62C) = 1.5`, and Apple private tags `0xC6F8 = "Apple Embedded Color Profile"`, `0xC6F7`, `0xC6FC`, `0xC761`, `0xC7A6`, `0xCD2D`.
- SubIFD0 (raw plane): `SamplesPerPixel 3`, `PhotometricInterpretation 34892 (LinearRaw)`, `BitsPerSample 12`, **no `CFAPattern`/`CFARepeatPatternDim`**, `BlackLevel 0`, `WhiteLevel 65535`.
- SubIFD1: an embedded 2016×1512 8-bit preview whose XMP contains `<apdi:AuxiliaryImageType>urn:com:apple:photo:2020:aux:semanticskymatte</apdi:AuxiliaryImageType>` and a `semanticSegmentationMatteVersion` — an Apple **semantic-rendering matte** baked into the file.

That structure (LinearRaw plane, 12-bit, no CFA, Apple private color tags, embedded auxiliary image) is Apple's **"Linear DNG" = ProRAW** layout, not Bayer: `SDK:AVFoundation/AVCapturePhotoOutput.h:194-201` ("When writing an Apple ProRAW buffer to a DNG file, the resulting file is known as 'Linear DNG'").

**Why it matters**
Three consequences. (a) `testZeroDevelopProducesViewableJPEGFromRealDNG` and `testZeroDevelopAppliesFramingCropInDevelopedSpace` (`PikicamPipelineTests.swift:38-104`) validate a payload shape the app never captures — different pixel layout, different CFA handling, different available `CIRAWFilter` controls. (b) `Orientation = 6` in this file is the empirical basis for `DevelopService`'s "CIRAWFilter bakes the EXIF orientation" claim (`DevelopService.swift:47-53`, `PikicamPipelineTests.swift:74-77`); that claim is being validated against ProRAW, and the Bayer DNG the app writes has not been checked for it. (c) The fixture is a vivid demonstration of what we are avoiding: Apple will happily embed **semantic-rendering** artifacts and its own color profile inside a DNG. The app's current settings (verified in "Verified-correct" §3) keep those out — but only as long as nobody adds `enabledSemanticSegmentationMatteTypes` or turns ProRAW on.

**Recommended fix direction**
Add a real **Bayer fixture** captured by the app itself on device (a documented, opt-in probe test that saves one capture into `pikicamTests/Fixtures/`), and make the develop tests run against it: assert `CFAPattern` present, `PhotometricInterpretation = 32803 (CFA)`, `BitsPerSample = 14`, no Apple private tags, no embedded auxiliary sub-image. Keep the ProRAW fixture around as a *negative* case — it is the reference for "what Apple-processed RAW looks like".

---

### F13 — P1 · Hand-rolled Bayer format list instead of Apple's classifier

**Evidence** — `CaptureService.swift:641-654` matches four literal OSTypes; the same SDK ships `+[AVCapturePhotoOutput isBayerRAWPixelFormat:]` and `+[AVCapturePhotoOutput isAppleProRAWPixelFormat:]` (`SDK:AVFoundation/AVCapturePhotoOutput.h:206-222`, iOS 14.3+). The list is currently correct (F7/"Verified-correct" §7) but it is a private reimplementation of a public API that Apple keeps in sync with the hardware.

**Why it matters** — any new Bayer flavour (or a device that reports an ordering not in the list) silently falls through to `noBayerFormatAvailable`, or worse: a non-Bayer format that is not ProRAW gets captured and treated as Bayer.

**Recommended fix direction** — `photoOutput.availableRawPhotoPixelFormatTypes.first { AVCapturePhotoOutput.isBayerRAWPixelFormat($0) }`, and log the whole list once per configuration for diagnostics. Keep the literal list only as a fallback for < iOS 14.3 (irrelevant at deployment target 26.5, so delete it).

---

### F14 — P2 · No embedded DNG thumbnail, and no choice made about one

**Evidence** — `settings.embeddedThumbnailPhotoFormat` / `rawEmbeddedThumbnailPhotoFormat` are never set (`grep` → 0 hits). `SDK:AVFoundation/AVCapturePhotoOutput.h:1638-1641`: "A dictionary of AVVideoSettings keys specifying a thumbnail (usually smaller) version of the RAW photo to be **embedded in that image's DNG**". The app's DNGs therefore contain no preview (the repo fixture — an Apple-written file — has one, which is why the fixture shows two sub-IFDs).

**Why it matters** — without an embedded preview, Files/Quick Look/AirDrop targets and most third-party viewers show a blank or an Apple-generated rendition; the app's own grid must develop or ask Photos (F11). It also means a `.dng` that leaves pikicam is less legible than one that leaves the Camera app.

**Recommended fix direction** — decide explicitly and write the decision down: (a) embed a small Apple-encoded JPEG preview (≈256 px, `rawEmbeddedThumbnailPhotoFormat`) purely for external compatibility, or (b) keep the DNG pure and document that. Option (a) costs one processed artifact *inside* the file — acceptable if the product says so; option (b) is stricter. Either way, add a device probe asserting the DNG's sub-image list matches the declared policy.

---

### F15 — P2 · Torch "flash": no settle, and it lights the whole exposure

**Evidence** — `CaptureService.swift:543-556`: `applyTorchMode(.on, …)` immediately followed by `photoOutput.capturePhoto(with: settings)`, while the zoom path in the same function gets an explicit `try await Task.sleep(nanoseconds: 250_000_000)` (`CaptureService.swift:526-533`) for exactly the analogous reason. The rationale is documented at `CameraControls.swift:39-46`.

**Why it matters** — an LED torch ramps over tens of ms, so the exposure can begin mid-ramp (the 250 ms settle exists for the same class of problem); and unlike a xenon flash, a torch is *on* for the entire exposure, so moving subjects smear and the AE meters to the torch.

**Recommended fix direction** — (1) insert a settle after torch-on, or ramp with `setTorchModeOn(level:)` and wait for `torchLevel`; (2) probe whether a real flash is legal with RAW-only settings — Apple's validation rules constrain `flashMode` only via "The specified flashMode must be present in the receiver's `-supportedFlashModes` array" (`SDK:AVFoundation/AVCapturePhotoOutput.h:106-107`, `supportedFlashModes` at `:489-496` is documented per "current capture session configuration" with **no** RAW exclusion), and red-eye reduction is already auto-disabled for RAW. If `supportedFlashModes.contains(.on)` and a RAW capture succeeds with it, the honest flash is the xenon flash firing at the end of the exposure, not a torch. **UNVERIFIED — must be tested on device.**

---

### F16 — P2 · Code comments that contradict the SDK (three of them)

1. `CaptureService.swift:618-622`: "`AVCapturePhotoOutput.availableRawPhotoPixelFormatTypes` is the **static output-wide list** …". It is an **instance** property that tracks the current configuration: "An array of RAW `CVPixelBufferPixelFormatTypeKey` values that are **currently supported by the receiver** … **If the current device doesn't support RAW capture, this array is empty.**" (`SDK:AVFoundation/AVCapturePhotoOutput.h:230-232`). So the method name is right and the read is fresh after `commitConfiguration`; the comment is what is wrong. (This also retires the previously "refuted" claim in `docs/prompt-next.md:1691-1699` — for the *wrong* reason: the read is per-device, so the front-camera case is handled, and `CIRAWProbe` ordering is not an issue.)
2. `CaptureService.swift:668-673`: the `configureRAWOutput` doc calls it "`maxPhotoQualityPrioritization`" while setting `isAppleProRAWEnabled`; and its second paragraph inverts Apple's rule (see F3).
3. `PreviewView.swift:14-15`: claims "support for iOS 26 Deferred Start" — no such API is used (`grep deferredStart` → 0).

**Why it matters** — the implementation prompt will be written against these comments. Each one points the reader at the wrong model of the API.

---

### F17 — P2 · `setExposureBias` holds the configuration lock across an unbounded `await`

**Evidence** — `CaptureService.swift:428-443`: `try device.lockForConfiguration(); defer { device.unlockForConfiguration() }` then `await withCheckedContinuation { device.setExposureTargetBias(…) { _ in continuation.resume() } }`. The completion fires on an arbitrary queue and the code ignores its `CMTime`.

**Why it matters** — if the completion never arrives (thermal pause, camera in use by another client, media-services reset), the device stays locked and **every subsequent capture-path lock (`applyVideoZoomFactor`, `applyTorchMode`, `setFocusAndExposure`) blocks** — a dead shutter with no error. It also blocks the actor's serial executor, so `handleSessionInterruptionEnded` cannot run.

**Recommended fix direction** — set `exposureTargetBias` without holding the lock across the wait (the setter is async by design), or bound the wait with a timeout + explicit unlock recovery; add a device test that drives EV while interrupting the session.

---

### F18 — P2 · Two sources of truth for orientation; neither is checked against the other

**Evidence** — the app samples `UIDevice.current.orientation` at shutter (`CameraViewModel.swift:281-283`) and persists it (`CapturedDNG.orientation` → `IndexRecord.orientation`), but **develop never reads it** (`DevelopService.swift:47-53` explicitly relies on `CIRAWFilter` baking the DNG's EXIF orientation, which in practice means AVFoundation's tag: the fixture shows `Orientation = 6`). Meanwhile the *preview* rotation is a hard-coded `90°` that nothing overrides (`CameraPreview.swift:16`, `:27`, `:35`; `CameraView.swift:70-79` never passes `rotationAngle`), so in landscape the viewfinder is misoriented while the provenance says otherwise.

**Why it matters** — three independent rotation decisions (AVF's EXIF tag, our provenance field, the preview layer's `videoRotationAngle`) with no invariant tying them together; the app supports landscape orientations (`project.yml:47`).

**Recommended fix direction** — make AVF's tag the single source of truth for display (read `photo.metadata[kCGImagePropertyOrientation]` at capture, persist it, and drop `UIDevice.current.orientation` or make it a cross-check), drive `videoRotationAngle` from the interface orientation + camera position, and assert in a device test that a landscape-held capture develops upright.

---

### F19 — P2 · Cold-start and first-shot latency: blocking `startRunning`, no settings pre-preparation, no deferred start

**Evidence** — `CaptureService.swift:166` and `:206` call `startRunning()` synchronously on the actor's serial executor; `setPreparedPhotoSettingsArray` is never used (0 hits) although Apple documents that "Some types of photo capture, such as bracketed captures and **RAW captures**, require the receiver to allocate additional buffers … capture requests may execute slowly as additional resources are allocated just-in-time" (`SDK:AVFoundation/AVCapturePhotoOutput.h:126-141`); iOS 26 deferred start (`SDK:AVFoundation/AVCaptureSession.h:671-727`) is unused.

**Recommended fix direction** — call `setPreparedPhotoSettingsArray([AVCapturePhotoSettings(rawPixelFormatType: bayer)], completionHandler:)` before `startRunning()`; enable deferred start so the preview paints before the photo pipeline spins up; move `startRunning`/`stopRunning` off the actor's serial executor so lifecycle notifications and the shutter are never queued behind a ~1 s hardware call.

---

### F20 — P2 · Storage robustness at the DNG boundary

- `PhotoLibraryManager.swift:217`: `UTType(filenameExtension: "dng") ?? UTType("com.adobe.raw-image")!` — the fallback force-unwraps a failable initializer. `UTType.dng` is the documented constant (`com.adobe.raw-image`); use it directly.
- `PhotoLibraryManager.swift:893-895`: `isDNGResource` requires an *exact* UTI string match on `com.adobe.raw-image`. If a Photos build normalizes the stored resource's UTI (or a future iOS tags it `public.camera-raw-image`), **every capture silently disappears from the gallery** — the failure mode is "user's photos vanished", the worst possible one for this product. Accept a small set (`com.adobe.raw-image`, `public.camera-raw-image`) and/or fall back to the filename extension.
- `PhotoCapture.swift:143-153`: the delegate is kept alive with `objc_setAssociatedObject(output, selfPtr, …)` keyed by the delegate's own address and cleared with `.OBJC_ASSOCIATION_ASSIGN`; address reuse across allocations makes this a latent hazard, and the 15 s timeout (`:34`) discards a photo that may still land (the DNG bytes are lost and the zoom restore is skipped). Prefer a retained delegate reference held by `CaptureService` for the duration of the capture, and on timeout keep the device-state restore even though the photo is dropped.
- `PhotoLibraryManager.swift:290-292` never sets `PHAssetChangeRequest.creationDate`, so the Photos timeline shows save time; set it from `capturedAt` (the app's own ordering already uses `capturedAt`, `PhotoLibraryManager.swift:494-499`).

---

### F21 — P2 · Metadata: no GPS, no copyright, no caption, and no `ActiveArea` awareness

`settings.metadata` is never set (`SDK:AVFoundation/AVCapturePhotoOutput.h` `metadata`: "AVCapturePhotoOutput inserts a base set of metadata … You may specify metadata keys and values that should be written to each photo"), so the DNG carries only Apple's base set — no user attribution, no GPS, no caption, no explicit "made with pikicam". Separately, `PrintCrop` assumes the whole developed extent is the usable sensor area; real DNGs may carry `ActiveArea` (0xC68D) and `DefaultCropOrigin`/`DefaultCropSize` (0xC61F/0xC620) which would silently shift every crop. Recommended: attach metadata at settings construction (and verify on device that it lands in the DNG, since RAW metadata flattening is Apple-controlled), and read `ActiveArea` from the DNG before computing any crop.

---

### F22 — P2 · Develop-side boundary note (for the capture→develop handoff only)

Not this topic's subject, but it is the boundary the capture path hands off to, and two facts here are load-bearing for capture decisions:
- `DevelopService.swift:23-31` renders through a `CIContext` with `outputColorSpace = CGColorSpace.displayP3` and hands the UI a bare `CGImage` with **no ICC profile attached** (`DNGDisplayRendition`), so the on-screen look is untagged and will differ from the same develop saved or shared elsewhere. Decide: tag with the DNG's `AsShotICCProfile`/`DNGProfile`, or render into sRGB and say so.
- `CIRAWFilter.h:75-160` documents that several "neutral" values are not neutral by default — `baselineExposure` "Default value can vary based on the image", `shadowBias` "can vary", `boostAmount` default **1** (a full global tone curve), `luminanceNoiseReductionAmount`/`colorNoiseReductionAmount`/`sharpnessAmount`/`detailAmount`/`moireReductionAmount`/`localToneMapAmount` "**Default value will vary per image**", `isGamutMappingEnabled` default **true**, `isHighlightRecoveryEnabled` default **true**. The current recipe (`CIRAWZeroProcessor.swift:60-76`) sets fifteen of them and deliberately leaves `decoderVersion` unpinned. Two capture-relevant consequences: (i) the DNG's own `BaselineExposure` (−0.302 EV in the fixture) is discarded by forcing 0 — decide and document; (ii) `decoderVersion` unpinned means the *same* DNG develops differently across iOS releases, so a capture/provenance record should store the iOS version and `CIRAWFilter.decoderVersion` used.

---

## Open questions / assumptions

1. **Which physical lens is the "1×"?** `selectCamera` returns the first `.builtInWideAngleCamera` at `.back`. On Pro models that is the 24/48 MP wide module; its *active area* may be smaller than the sensor's full 4:3 extent because the module shares the sensor. Nothing in the app measures this. **Assumption recorded:** "full sensor" in the code/README means "the wide module's active area at `videoZoomFactor == 1.0`", not the physical sensor. Needs a device probe that records `activeFormat` + the DNG's dimensions/ActiveArea on at least two devices.
2. **Does GDC apply to the physical wide camera on any shipping iPhone, and does Center Stage affect stills as well as the stream?** Both are documented only at the device/stream level. Needs an on-device A/B capture probe (see the recommended probe below).
3. **Is `photoQualityPrioritization = .balanced` actually accepted for Bayer RAW on current iOS 26.5, and does any fusion override actually reach a Bayer RAW?** The header mandates `.speed`; the owner observed only `.quality` throwing. I could not resolve this without hardware. The fix (set `.speed`) is safe either way.
4. **Is `settings.flashMode = .on` legal for a RAW-only capture?** Apple's validation rules contain no RAW exclusion for flash, but this is untested (F15). If it works, the torch-as-flash design should be replaced.
5. **Can `AVCaptureVideoDataOutput` deliver 14-bit Bayer on any shipping iPhone?** Assumed possible on at least some devices based on community RAW-preview projects (e.g. `adwirth/CamProc`, `scodes73/rawPipeline`); **UNVERIFIED**. Must be probed with `videoOutput.availableVideoPixelFormatTypes` before committing to a raw-preview roadmap.
6. **Fixture provenance.** `IMG_1361.DNG` is an Apple-written iPhone 12 Pro file (ProRAW/Linear DNG), not a pikicam capture — it was clearly obtained externally, but nothing in the repo records where it came from. Assumption: it is used purely as a develop input.
7. **Scope call recorded:** I treat the *absence* of a device-level control (WB, ISO, GDC, Center Stage, video HDR) as a finding even though each is a "feature", because the product goal is explicitly "camera → our own code → bypass the iPhone's post-processing", and each of these defaults is Apple deciding something about the image.
8. **Prior art in the repo:** `docs/prompt-next.md` contains earlier findings on the develop recipe, the torch settle, and gallery refresh races. I did not re-litigate them except where they intersect the capture path (F12 fixture fidelity, F15 torch settle, F5 fixture-based assertions).

### Suggested device probe (single test, high value)

One opt-in, device-only XCTest that, for each of `.back` and `.front` and with the app's exact settings, records: `device.uniqueID`, `device.deviceType`, `device.isVirtualDevice`, `device.constituentDevices`, `isGeometricDistortionCorrectionSupported/Enabled`, `isCenterStageActive`, `isLowLightBoostSupported/Enabled`, `isVideoHDREnabled`, `automaticallyAdjustsVideoHDREnabled`, `whiteBalanceMode`, `ISO`, `exposureDuration`, `activeFormat.formatDescription`, `activeFormat.supportedMaxPhotoDimensions`, `photoOutput.availableRawPhotoPixelFormatTypes`, `photoOutput.supportedFlashModes`, then captures once and dumps `resolvedSettings` + `photo.metadata` EXIF + the DNG's own IFD0/ActiveArea tags. Every P0/P1 in this document becomes a fact instead of a hypothesis with one run of that test. It should write a JSON artifact (not assertions) so it can be committed as a device matrix.

---

## Sources

**Local SDK headers (iOS 26.5, normative — highest authority used here)**
- `System/Library/Frameworks/AVFoundation.framework/Headers/AVCapturePhotoOutput.h` — validation rules 73-118; `availableRawPhotoPixelFormatTypes` 230-232; `isBayerRAWPixelFormat:`/`isAppleProRAWPixelFormat:` 206-222; `appleProRAWEnabled` 193-202; `virtualDeviceConstituentPhotoDeliveryEnabled` 459-466; `supportedFlashModes` 489-496; `maxPhotoDimensions` (output) 539-547, (settings) 1449-1456; `autoDeferredPhotoDelivery*` 373-392; `rawEmbeddedThumbnailPhotoFormat` 1638-1641; `autoContentAwareDistortionCorrectionEnabled` 1643-1650; `AVCapturePhotoSettings` 1192-1456 (`photoQualityPrioritization` default 1207/1375-1382, `autoRedEyeReductionEnabled` 1340-1352, `autoStillImageStabilizationEnabled` 1384-1394, `autoVirtualDeviceFusionEnabled` 1396-1404); `AVCapturePhoto` 2200-2240 (`isRawPhoto`, `pixelBuffer`, `metadata`, `CGImageRepresentation`); `AVCaptureResolvedPhotoSettings` 1790-1960; `AVCaptureDeferredPhotoProxy.rawPhoto` 2304-2310; `AVCapturePhotoOutput.h` deprecation note re GDC + high-res photo size 1442-1444.
- `…/AVFoundation.framework/Headers/AVCaptureDevice.h` — device types 492-568; `lockFocusWithCustomLensPositionSupported` 1120-1127; iOS 26 `focusRectOfInterest`/`defaultRectForFocusPointOfInterest:` 1162-1185; `lockFocus` custom lens position 1120-1127; `exposureMode` custom-vs-fusion 1356-1381; iOS 26 `exposureRectOfInterest` 1406-1427; WB 1630-1790 incl. iOS 26 `setWhiteBalanceModeLocked(whiteBalanceTemperatureAndTintValues:)` 1782 and presets 1676-1690; `videoZoomFactor` 1917-1929; low light boost 1879-1910 (default **NO**); `automaticallyAdjustsVideoHDREnabled` 2147-2151 (default **YES**); `videoHDREnabled` 2153-2163; `activeColorSpace` 2163-2190; GDC 2258-2286 (default **YES**, **never applied to RAW**, **always applied to `AVCaptureVideoPreviewLayer`**); Center Stage 2329-2380 (default **user**); `virtualDevice*` 712-785; `supportedMaxPhotoDimensions` 3483-3490; `isVideoHDRSupported`/EDR 3349-3353.
- `…/AVFoundation.framework/Headers/AVCaptureSession.h` — deferred start 671-727; `videoScaleAndCropFactor` 1213-1222; `preferredVideoStabilizationMode` default **Off** 1226-1234; camera intrinsics + GDC 1276-1284; `.photo` preset note ("video is captured at preview resolution", `AVCaptureDevice.h:3472-3478`).
- `…/AVFoundation.framework/Headers/AVCaptureVideoPreviewLayer.h` 26-60 (preview layer = session video output).
- `…/CoreVideo.framework/Headers/CVPixelBuffer.h:103-106` (the four 14-bit Bayer OSTypes), `:118-119` (ProRes Versatile Bayer), `:252-261`.
- `…/CoreImage.framework/Headers/CIRAWFilter.h:30-175` (all control defaults; `baselineExposure` "can vary"; boost 1; NR/sharpness/detail/moiré/LTM "vary per image"; gamut map + highlight recovery default **true**; `orientation`; `properties`).

**Apple documentation (docc JSON, fetched)**
- https://developer.apple.com/documentation/avfoundation/avcapturephotosettings/rawphotopixelformattype — "When capturing RAW images, the following requirements apply…"
- https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/availablerawphotopixelformattypes-5fatm — "**If the current device doesn't support RAW capture, this array is empty.**" / "Read this property only after adding the photo capture output to an `AVCaptureSession` containing a video source."
- https://developer.apple.com/documentation/avfoundation/avcapturephotosettings/maxphotodimensions — "defaults to the smallest dimensions returned by `supportedMaxPhotoDimensions`"
- https://developer.apple.com/documentation/avfoundation/avcapturephotosettings/photoqualityprioritization — default Balanced
- https://developer.apple.com/documentation/uniformtypeidentifiers/uttypedng — `UTTypeDNG` = `com.adobe.raw-image`
- https://developer.apple.com/documentation/avfoundation/avcapturephotooutput, /avcapturephoto, /avcapturedevice

**Apple user documentation**
- iPhone User Guide (iOS 26), "Take Apple ProRAW photos with your iPhone camera" — "Apple ProRAW is available on all cameras, **including the front camera**": https://support.apple.com/en-gb/guide/iphone/iphae1e882a3/26/ios/26
- Apple Support, "About Apple ProRAW" (ProRAW = standard RAW + iPhone image processing): https://support.apple.com/en-sg/119916

**Community (secondary, used only for front-camera RAW behaviour)**
- Stack Overflow 47330323 — "`availableRawPhotoPixelFormatTypes` is empty on iPhone 7+ and iOS 11" (three causes: not yet added to a session, dual-camera input, **front camera**): https://stackoverflow.com/questions/47330323
- Stack Overflow 75912737 — front camera "can only output ProRaw not BayerRaw": https://stackoverflow.com/questions/75912737
- Stack Overflow 69966928 — RAW formats empty on an iPhone 11 Pro wide camera (context: which device/format pair is queried): https://stackoverflow.com/questions/69966928
- Reference implementations of raw video pipelines (for the F4 raw-preview direction): https://github.com/adwirth/CamProc , https://github.com/scodes73/rawPipeline

**Repository evidence**
- `pikicam/Features/Camera/CaptureService.swift`, `PhotoCapture.swift`, `CameraViewModel.swift`, `CameraControls.swift`, `CameraView.swift`, `CameraPreview.swift`, `PreviewView.swift`, `GridOverlayView.swift`, `ZoomIndicatorView.swift`, `VolumeButtonCaptureView.swift`, `Views/ShutterButton.swift` (all read in full).
- `pikicam/Core/Storage/PhotoLibraryManager.swift`, `pikicam/Features/Gallery/{GalleryView,PikicamLibraryModel}.swift`, `pikicam/App/{PikicamApp,RootView}.swift`, `pikicam/Core/Design/{Room,ControlIDRegistry}.swift`, `pikicam/Features/Develop/{DevelopService,RAWProcessor,CIRAWZeroProcessor}.swift`, `project.yml`, `README.md`.
- Tests: `pikicamTests/{PikicamPipelineTests,CameraControlTests,DesignLintTests}.swift`, `pikicamUITests/SmokeLaunchTest.swift`.
- `git diff` of the in-progress working tree (RawRecipe rewrite, capture lifecycle observers, `CapturedDNG` validation, PhotoKit reconciliation changes) — reviewed; no capture-pipeline processing gap is introduced or fixed by those uncommitted edits.
- Fixture forensics: TIFF/DNG IFD parse of `pikicamTests/Fixtures/IMG_1361.DNG` (IFD0 + both SubIFDs + embedded XMP), run locally with `struct.unpack`.
