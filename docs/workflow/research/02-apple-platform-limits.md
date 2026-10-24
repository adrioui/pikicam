# 02 — Apple Platform Limits: how far can you actually bypass iPhone post-processing?

**Scope:** external research on the real, current limits (Xcode 26.6 / iPhoneOS 26.5 SDK, iOS 18/26 era, current iPhone hardware) of bypassing Apple's image pipeline on iPhone.
**Method:** local SDK headers read in full (authoritative), plus empirical experiments run against the repo's own DNG fixture, plus Apple documentation, WWDC sessions, DNG spec, and third-party writeups.
**Status of every claim:** `VERIFIED` (read from the shipping SDK header or measured on this machine), `MEASURED` (I ran it), `SOURCED` (external doc/quoted), `UNVERIFIED` (plausible, needs on-device confirmation).

---

## Summary — the top 10 findings

1. **`CIRAWFilter` can never give you a scene-linear, scene-referred image.** Even with *every* subjective control zeroed, its `outputImage` is tagged **Display P3** and display-encoded. MEASURED: with the full zero recipe, the linearized max luminance is **0.571** — no pixel anywhere reaches 1.0. "Zero-process" ≠ "our code". The only supported interception point is `linearSpaceFilter`, and MEASURED: it is an **insert** hook on the already-demosaiced linear RGB image, not an output tap.

2. **pikicam's zero recipe is not actually neutral in two places.** `highlightRecoveryEnabled` defaults to **`true`** and the recipe never touches it (CIRAWZeroProcessor.swift:60), and `baselineExposure` defaults to **the DNG's own `BaselineExposure` tag** (measured −0.302 EV on the fixture) but the recipe forces it to `0.0` (CIRAWZeroProcessor.swift:65). MEASURED combined effect vs a corrected recipe: the current output is **0.30 stops hotter** *and* still has Apple's highlight compression (p99.9 208→189, max 244→226).

3. **Bayer RAW is a hard-constrained mode and pikicam's comment about it is inverted.** Apple's capture rules state that for Bayer RAW, `photoQualityPrioritization` **must be `.speed`** and `videoZoomFactor` **and** `videoScaleAndCropFactor` must both be `1.0`. The code deliberately leaves the prioritization at its `.balanced` default because "setting it raises NSInvalidArgumentException" (CaptureService.swift:537). The app is running on an undocumented implementation detail.

4. **You can bypass Apple's demosaic entirely — by not using the DNG.** `AVCapturePhoto.pixelBuffer` for a Bayer RAW capture is the real 14-bit CFA mosaic (`'bgg4'` = `kCVPixelFormatType_14Bayer_BGGR` etc.). That buffer plus the `OSType` you passed in is the complete input to your own demosaic. The DNG is Apple's *packaging* of the same data.

5. **48 MP Bayer RAW does not exist on iOS.** Halide/Lux states it explicitly: *"We sadly cannot take 48 megapixel Process Zero photos due to system limitations… Both of these limitations are because we do not get 48 raw sensor data from iOS."* Bayer RAW is therefore a **12 MP, 1×, wide-camera-only** mode. That is the real ceiling of the whole thesis, and it is a product-shaping constraint, not a bug.

6. **Apple's DNGs store the raw data in a non-linear space.** The fixture's raw IFD carries `LinearizationTable` (tag 50712/0xC618, 4096 entries): DNG spec — *"maps stored values into linear values… typically used to increase compression ratios by storing the raw data in a non-linear, more visually uniform space."* MEASURED: the table is ≈gamma, saturating at input ≈1454 → output 65535, and `WhiteLevel = 65535` while `BitsPerSample = 12`. Any custom demosaic **must** apply this table or your image will be wrong.

7. **Photos renders the DNG itself when the DNG is the only resource — so your gallery shows Apple's look, not yours.** `PhotoLibraryManager` saves the DNG as the sole `.photo` resource (PhotoLibraryManager.swift:373) and fetches thumbnails with `version = .current` (PhotoLibraryManager.swift:680), which is Photos' own RAW rendering. Halide's manual documents the exact failure mode and the fix (pair a processed render with the RAW).

8. **The repo's test fixture is an Apple ProRAW DNG, not Bayer RAW.** MEASURED: raw IFD `PhotometricInterpretation = 34892` (**LinearRaw** = "CFA data that has already been de-mosaiced", per the DNG spec), `WhiteLevel 65535`, `NoiseReductionApplied = 0.95`, `BaselineSharpness = 1.5`, `DefaultBlackRender = 1`, embedded semantic sky matte. So every develop test in the repo runs against the *processed* format, and the CFA/demosaic code path is untested.

9. **Lens distortion correction data is unreachable in a single-lens RAW app.** MEASURED: `CIRAWFilter.isLensCorrectionSupported == false` on the fixture (no lens coefficients in the DNG). The only API that delivers them (`AVCameraCalibrationData`) requires **≥2 constituent devices** *and* GDC off *and* content-aware DC off (AVCapturePhotoOutput.h:484) — i.e. the multi-camera path, which itself changes the capture. So **you must ship your own lens calibration table.**

10. **The preview cannot be made to match your develop, and there is no knob for it.** Apple documents no preview-processing controls; `AVCaptureVideoPreviewLayer` renders the ISP's display-referred stream. Structurally, preview is a *different* pipeline than a 12 MP Bayer still. The honest resolution (used by Halide, LibreCam, and pikicam itself) is: live preview is the ISP's, and the **post-capture review must be rendered by your own develop code** — which is the only place the user can actually judge the shot.

---

## Detailed findings

### A. Bayer RAW vs Apple ProRAW — what each actually contains

#### D1 — P0 — "Bayer RAW" on iOS is a single, unprocessed, 1×, 12-bit CFA exposure; ProRAW is a fused, demosaiced, processed composite

**Evidence (VERIFIED, SDK):** `AVCapturePhotoOutput.appleProRAWEnabled` doc, AVCapturePhotoOutput.h:198–202:

> "Compared to photos taken with a Bayer RAW format, these photos will be demosaiced and partially processed. They are still scene-referred, and allow capturing RAW photos in modes where there is no traditional sensor/Bayer RAW available. Examples are any modes that rely on fusion of multiple captures. … When writing an Apple ProRAW buffer to a DNG file, the resulting file is known as **'Linear DNG'**."

**SOURCED:** Halide/Lux, *The Process Zero Manual* — ProRAW "is actually not technically a raw file… it is already a result of many combined images"; Bayer RAW retains "the actual data your camera sensor saw… a spreadsheet with values for the little photo sites on your sensor". Bayer RAW has been available to third‑party apps since iOS 10 (iPhone 6s) and on non‑Pro iPhones since; ProRAW is Pro‑only.

**Bayer Cam documentation (SOURCED)**, the cleanest external statement of the processing split:
- Bayer RAW = data straight from the sensor chip, pre-demosaic; demosaicking, geometric correction, white balance, denoising, sharpening are all still *yours* to do.
- "Every iPhone device to this day shoots **12-bit** Bayer RAW files… verify via `WhiteLevel`: 4095 = 12-bit, 1023 = 10-bit."
- Apple ProRAW is "a processed format… decisions about its rendering (demosaicking, denoising) baked into the file itself, which cannot be undone"; it is "a composite from multiple exposures"; it "include[s] depth/semantic maps in their data, and make[s] use of them for processing."

**Processing breakdown (deduced from Apple's own docs + Bayer Cam):**

| Stage | Bayer RAW (iOS) | Apple ProRAW (iOS) |
|---|---|---|
| Multi-frame fusion (Deep Fusion / Photonic Engine / Smart HDR) | **No** — `photoQualityPrioritization` forced to `.speed`, single exposure | **Yes**, by design ("applies many of the multi-image fusion techniques previously unavailable to RAW workflows") |
| Demosaic | **No** — you get the CFA | **Yes**, irreversible |
| Noise reduction | **No** (unless Apple's sensor read does it) | **Yes**, partially, and recorded in the DNG (`NoiseReductionApplied`) |
| Semantic rendering / segmentation | **No** | **Yes** — depth + skin/hair/sky/glasses/teeth mattes drive the processing |
| White balance | **Metadata only** (`AsShotNeutral`) | Metadata + applied in the "Linear DNG" matrix chain |
| Tone map | **No** — you choose | **No** (that is the point of scene-referred linear DNG), but demosaic/NR/fusion choices are baked |
| Optical image stabilization | Uses OIS (motion is physically corrected) | Same |
| Content-aware distortion correction | **No** | **Auto-disabled** ("`autoContentAwareDistortionCorrectionEnabled` will automatically be disabled") |
| Red-eye reduction / portrait matte / semantic mattes | N/A | **Auto-disabled / cleared** for ProRAW captures |

**Why it matters:** the product thesis ("capture the least-processed sensor data iOS exposes") is *only* achievable on the Bayer RAW path. The ProRAW path is a different product (Apple's processing, non-destructively re-editable). Any UI that offers "RAW" without distinguishing these is lying.

**Fix direction:** make the format model explicit in code and UI: `SensorRAW` (Bayer, 12 MP, 1×, our develop) vs `AppleProRAW` (fused, Apple develop) — and if ProRAW is offered at all, say so in the UI label.

#### D2 — P0 — Bayer RAW capture is gated by a hard rule set, and pikicam satisfies it only by accident

**Evidence (VERIFIED, SDK), `-[AVCapturePhotoOutput capturePhotoWithSettings:delegate:]` "RAW rules", AVCapturePhotoOutput.h:80–96 (RAW rules):**

> Common RAW rules:
> - If `rawPhotoPixelFormatType` is non-zero, it must be present in the receiver's `availableRawPhotoPixelFormatTypes`.
> - … your delegate must respond to `captureOutput:didFinishProcessingRawPhotoSampleBuffer:…`
> - If `rawPhotoPixelFormatType` is non-zero, `constantColorEnabled` must be set to NO.
> …
> **Bayer RAW rules** (`isBayerRAWPixelFormat:` returns yes):
> - **`photoQualityPrioritization` must be set to `AVCapturePhotoQualityPrioritizationSpeed`** (deprecated `autoStillImageStabilizationEnabled` must be set to NO).
> - **the `videoZoomFactor` of the source device and the `videoScaleAndCropFactor` of the photo output's video connection must both be 1.0.** Ensure no zoom is applied before requesting a RAW capture, and don't change the zoom during RAW capture.

**Repo's current behaviour (file:line):**
- CaptureService.swift:537–539 — *"Never set `photoQualityPrioritization` on RAW captures: AVFoundation raises NSInvalidArgumentException ('Unsupported when capturing RAW') at capture time. The default (.balanced) is used."*
- CaptureService.swift:671–675 — *"maxPhotoQualityPrioritization is deliberately left at its default: setting it to .quality makes capturePhotoWithSettings: raise an NSInvalidArgumentException."*
- CaptureService.swift:517–530 — resets `videoZoomFactor` to 1.0 and sleeps 250 ms, but **never checks/resets `videoScaleAndCropFactor`** on any connection.
- CaptureService.swift:273 — on camera switch, zoom is set to 1.0.

**Two problems:**
1. The documented default (`photoQualityPrioritization` default is `.balanced`, AVCapturePhotoOutput.h:1374–1382) **violates** the Bayer-RAW rule. The app therefore depends on `+photoSettingsWithRawPixelFormatType:` silently forcing `.speed`. That is undocumented and can change. It must be set explicitly.
2. `maxPhotoQualityPrioritization` defaults to `.balanced` when attached to a session (AVCapturePhotoOutput.h:342–344). Requesting `.speed` is legal against a `.balanced` cap (you may select a lower level), so the correct fix is: leave the output cap alone or set it to `.speed`, and **explicitly** set `settings.photoQualityPrioritization = .speed`.
3. `videoScaleAndCropFactor` is never touched anywhere in the repo (verified: zero occurrences). It must be `1.0` on the photo output's video connection.

**Corroborating external evidence (SOURCED):** the exception message is widely reported verbatim — `* -[AVCapturePhotoOutput capturePhotoWithSettings:delegate:] When specifying Bayer raw capture, the videoZoomFactor of the video device must be set to 1.0` (StackOverflow 68389472; the same message is what produced the repo's 1×-only design). `photoQualityPrioritization` interacts with exposure too: `exposureMode`/`setExposureModeCustom` doc, AVCaptureDevice.h:1379 — *"the photoQualityPrioritization property of AVCapturePhotoSettings defaults to Balanced, which allows photo capture to temporarily override the capture device's ISO and exposureDuration values if the scene is dark enough to warrant some form of multi-image fusion."*

**Why it matters:** this is the difference between "we chose single-exposure" and "the platform chose it for us by accident". If the implicit default ever changes, the app silently starts getting fusion — the exact failure the product exists to avoid. And `videoScaleAndCropFactor` is a live crash risk if the crop geometry is ever non-identity.

**Fix direction:** build one explicit `RAWCapturePolicy` that (a) asserts `photoOutput.availableRawPhotoPixelFormatTypes` contains a Bayer format before configuring, (b) sets `settings.photoQualityPrioritization = .speed`, (c) forces both `device.videoZoomFactor == 1.0` **and** `photoOutputConnection(s).videoScaleAndCropFactor == 1.0` immediately before capture and asserts them, (d) logs/asserts `resolvedSettings` after capture (`AVCaptureResolvedPhotoSettings` reports what actually happened), and (e) removes the 250 ms sleep in favour of waiting for a KVO/delegated signal that the format settled.

#### D3 — P1 — Virtual (dual/triple) devices are a different capture path; constituent delivery is the only route to calibration data and it is mutually exclusive with a clean single-lens RAW mode

**Evidence (VERIFIED, SDK):**
- `virtualDeviceFusionSupported` (AVCapturePhotoOutput.h:426) / `autoVirtualDeviceFusionEnabled` (AVCapturePhotoOutput.h:1402–1404): *"Default is YES unless you are capturing a RAW photo (RAW photos may not be processed by definition)."*
- `autoStillImageStabilizationEnabled` (AVCapturePhotoOutput.h:1388–1390): *"Default is YES unless you are capturing a **Bayer** RAW photo."*
- Virtual devices: `AVCaptureDeviceTypeBuiltInDualCamera` / `DualWideCamera` / `TripleCamera` are the virtual types; `.builtInWideAngleCamera`, `.builtInTelephotoCamera`, `.builtInUltraWideCamera` are the **physical** types (AVCaptureDevice.h:493–562). For a virtual device *"one of the constituent video devices is selected as the primary constituent device. For an AVCaptureSession, the primary constituent device produces for all outputs"* (AVCaptureDevice.h:715).
- `cameraCalibrationDataDeliverySupported` (AVCapturePhotoOutput.h:484): *"Camera calibration data delivery (intrinsics, extrinsics, lens distortion characteristics, etc.) is only supported if `virtualDeviceConstituentPhotoDeliveryEnabled` is YES **and** `contentAwareDistortionCorrectionEnabled` is NO **and** the source device's `geometricDistortionCorrectionEnabled` property is set to NO."* And `cameraCalibrationDataDeliveryEnabled` requires *"2 or more devices are selected for virtual device constituent photo delivery"* (AVCapturePhotoOutput.h:1496).
- `maxPhotoQualityPrioritization` default is `.speed` on an `AVCaptureMultiCamSession`, `.balanced` on a plain session (AVCapturePhotoOutput.h:342–344).

**Repo (file:line):** `selectCamera(at:)` uses `deviceTypes: [.builtInWideAngleCamera]` (CaptureService.swift:659) — i.e. always the physical wide camera.

**Implications:**
- The app can **never switch to tele or ultra-wide**. Any "lens" UI would be a digital crop of the wide sensor.
- `cameraCalibrationDataDeliveryEnabled` is effectively unreachable (needs ≥2 constituent devices) ⇒ no `AVCameraCalibrationData` ⇒ **no lens distortion coefficients**. Consistent with MEASURED `isLensCorrectionSupported == false`.
- On a virtual device, `.photo` + multi-camera makes the primary constituent produce for all outputs; combined with the 1× RAW rule this gets subtle fast. **Recommendation:** stay on physical devices (as today), and say so in the product.

**UNVERIFIED:** whether `AVCapturePhotoOutput` on a virtual device even offers Bayer formats in `availableRawPhotoPixelFormatTypes` — enumerate it on device before designing any multi-camera RAW mode.

#### D4 — P1 — 48 MP Bayer RAW does not exist; Bayer RAW is capped at 12 MP

**Evidence (SOURCED, from the vendor who filed the request with Apple):** Halide/Lux Process Zero manual:

> "You can also choose advanced capture settings, like adjusting your resolution from 12 to 48 megapixels on newer iPhones for HEIC and ProRAW captures with regular iPhone processing. **We sadly cannot take 48 megapixel Process Zero photos due to system limitations.** … Process Zero cannot use a few computational nice things. For instance, on iPhone 14 Pro and 15/15 Pro, it does not have a '2×' lens. It can also not take 24 or 48 megapixel photos. **Both of these limitations are because we do not get 48 raw sensor data from iOS. We've filed a request with Apple for this**…"

**Supporting SDK facts (VERIFIED):**
- `AVCapturePhotoSettings.maxPhotoDimensions` "defaults to the smallest dimensions returned by `AVCaptureDeviceFormat.supportedMaxPhotoDimensions`" (AVCapturePhotoOutput.h:1454) — the repo never sets it (verified: no occurrences), so the app always requests the *smallest* supported size.
- `AVCapturePhotoOutput.maxPhotoDimensions` doc, AVCapturePhotoOutput.h:543–545: *"Note: When supported, the 24MP setting (5712, 4284) is only serviced as 24MP when opted-in to `autoDeferredPhotoDeliveryEnabled`."* And AVCapturePhotoOutput.h:114: *"The maxPhotoDimensions setting for 24MP (5712, 4284), when supported, is only serviced as 24MP via deferred photo delivery."*
- Deferred photo delivery is inherently **processed**: `didFinishCapturingDeferredPhotoProxy:` delivers *"a lightweight photo representation… that can later be processed to completion"* and `AVCaptureDeferredPhotoProxy.fileDataRepresentation` *"may be used with `PHAssetCreation` to eventually produce the final, processed photo"* (AVCapturePhotoOutput.h:1060–1063). So the only route to 24 MP is a route that gives you Apple's processed output. **You cannot have 24 MP Bayer RAW.**
- WWDC26 session 304 (SOURCED): *"48MP capture uses a full-resolution frame from the Quad sensor… 48MP capture is available with balanced or quality prioritization because it is a single-frame capture. … 18MP and 24MP multi-frame fused captures require quality prioritization."* — note 24 MP is explicitly **multi-frame fused**, i.e. not raw.
- Bayer Cam (SOURCED): Bayer RAW is **12-bit**; `WhiteLevel == 4095` is the tell.

**Why it matters:** on a 48 MP iPhone, the honest RAW product is a **12 MP, 1×, 24 mm-equivalent** product. That is not a defect — it is the classic "DSLR at base ISO" look, and it is what makes "no fusion" possible at all (multi-frame requires ≥2 exposures at different exposures/times). But the UI must stop implying otherwise, and any "2×/3×" framing must be a declared crop of the 12 MP frame, not a zoom.

**UNVERIFIED / to test on device:** whether `availableRawPhotoPixelFormatTypes` + `supportedMaxPhotoDimensions` ever offers a Bayer format above 12 MP on iOS 26 hardware. Test: build a `AVCapturePhotoSettings(rawPixelFormatType: <bayer>, processedFormat: nil)`, set `maxPhotoDimensions` to each value in `activeFormat.supportedMaxPhotoDimensions`, and record `resolvedSettings.rawPhotoDimensions`.

#### D5 — P1 — `maxPhotoQualityPrioritization` is a processing switch, not a speed switch — set it deliberately and never above `.speed`

**Evidence (VERIFIED, SDK):**
- `maxPhotoQualityPrioritization` (AVCapturePhotoOutput.h:342–344): *"Setting the maxPhotoQualityPrioritization to `.quality` will turn on optical image stabilization if the `isHighPhotoQualitySupported` of the source device's `activeFormat` is true."* And: *"Changing the maxPhotoQualityPrioritization while the session is running can result in a lengthy rebuild of the session in which video preview is disrupted."*
- `highPhotoQualitySupported` (AVCaptureDevice.h:3372–3375): formats that support it *"produce higher image quality when selecting .balanced or .quality … compared to .speed."*
- `photoQualityPrioritization` (AVCapturePhotoOutput.h:1374–1382): the output *"is capable of applying a variety of techniques to improve photo quality (reduce noise, preserve detail in low light, freeze motion, etc.), depending on the source device's activeFormat."*

**Design rule:** the highest-prioritization cap the app is willing to offer defines its promise. If `.quality` is ever exposed, OIS + long-exposure multi-frame become reachable and the "no fusion" claim is void.

#### D6 — P2 — Deferred delivery, responsive capture, zero shutter lag, constant color: what they mean for RAW

**Evidence (VERIFIED, SDK), all on `AVCapturePhotoOutput`:**

| Knob | Availability | RAW impact |
|---|---|---|
| `isZeroShutterLagEnabled` | iOS 17+ | *"For apps linked on or after iOS 17 zero shutter lag is automatically enabled when supported."* Works with `.balanced`/`.quality`; *"isn't available when using manual exposure or bracketed capture."* A **rolling-shutter temporal buffer** is not a computational fusion, but it does mean the delivered frame can predate the button press and can come from a burst already in flight. Decide whether that breaks "one exposure". |
| `isResponsiveCaptureEnabled` | iOS 17+ | Adds buffering so the next capture can start while the previous is processing. Purely a scheduling change; *"Processed photos continue to be delivered in the order they were captured."* But: *"When requesting uncompressed output using kCVPixelBufferPixelFormatTypeKey… overlap between capture and processing is disabled"* — relevant if you ever request an uncompressed `format`. |
| `autoDeferredPhotoDeliveryEnabled` | iOS 17+, **iOS only** | Delivers a *processed* proxy (`AVCaptureDeferredPhotoProxy`). **Not a RAW path.** Also the only way to service 24 MP (see D4). |
| `fastCapturePrioritizationEnabled` | iOS 17+ | *"automatically reduce capture quality from the selected AVCapturePhotoQualityPrioritization when needed to keep up with rapid capture requests."* Only meaningful with `.balanced`/`.quality`; with `.speed` it is a no-op. |
| `isAutoContentAwareDistortionCorrectionEnabled` (settings) / `isContentAwareDistortionCorrectionEnabled` (output) | iOS 14.1+ | Settings default **NO**. Output default **NO**. *"Photos may or may not benefit from distortion correction… warping… may result in a small change in field of view compared to what you see in the AVCaptureVideoPreviewLayer."* → keep off; it would introduce a content-dependent geometry change. |
| `isAutoStillImageStabilizationEnabled` (settings) | deprecated iOS 13 | Default YES **except** for Bayer RAW — already off for us by platform. |
| `autoVirtualDeviceFusionEnabled` (settings) | iOS 13+ | Default YES **except** RAW. |
| `constantColorEnabled` / `constantColorSupported` | iOS 18+ | Requires the flash to fire and only works with `flashMode` `.auto`/`.on`; **an exception is thrown if `rawPhotoPixelFormatType` is non-zero** (AVCapturePhotoOutput.h:86). Not available to a RAW pipeline at all. |
| `cameraSensorOrientationCompensationEnabled` | **iOS 26, new** | *"compensation is never applied to Bayer RAW or Apple ProRaw captures"* (AVCapturePhotoOutput.h:800–804) — confirms RAW buffers are always delivered in sensor orientation and the app owns rotation. |
| Colour space | iOS 17/26 | *"Photo capture is **not supported** when AVCaptureDevice has selected `AVCaptureColorSpace_AppleLog` or `AVCaptureColorSpace_AppleLog2` as color space."* (AVCapturePhotoOutput.h:115–116) A real crash/hang trap if the app ever exposes a log colour space. |
| `setPreparedPhotoSettingsArray(_:)` | iOS 11+ | Pure latency optimisation — *"Some types of photo capture, such as bracketed captures and RAW captures, require the receiver to allocate additional buffers."* Use it; it replaces the repo's 250 ms sleep with something deterministic. |

**Design rule:** treat `maxPhotoQualityPrioritization` as a *product setting*, not a tuning knob. One session cap (`.speed` or `.balanced`), set before `startRunning()`, asserted in code, with per-shot `photoQualityPrioritization = .speed` for RAW and never higher. Add `.quality` only behind an explicit, labelled "long exposure / multi-frame" mode — because at `.quality` the promise "no fusion" is void by construction.

---

### B. `AVCaptureDevice` settings that touch the RAW

#### D7 — P1 — GDC (geometric distortion correction) never touches a Bayer RAW; disabling it only desynchronises the preview

**Evidence (VERIFIED, SDK), `geometricDistortionCorrectionSupported`, AVCaptureDevice.h:2267:**

> "GDC lessens the fisheye effect at the outer edge of the frame at the cost of losing a small amount of vertical and horizontal field of view. … **Beware though that RAW photo captures never have GDC applied, regardless of the value of `AVCaptureDevice.geometricDistortionCorrectionEnabled`.**"

And the ProRes-RAW branch (AVCaptureDevice.h:2279): *"In the case of ProRes RAW, when GDC is enabled, GDC is applied to your outputs in different ways: always to `AVCaptureVideoPreviewLayer`; to `AVCaptureVideoDataOutput` only if `deliversPreviewSizedOutputBuffers` is YES; never to `AVCaptureMovieFileOutput`. When GDC is enabled, `AVCaptureVideoDataOutput` buffers contain **GDC metadata attachments**."*

**Consequences for the product:**
- The preview's FOV depends on `geometricDistortionCorrectionEnabled`; the RAW's FOV does not. **Any change to GDC silently creates a preview↔capture framing mismatch.** The repo never touches GDC (verified: zero occurrences), so the default (`YES`) is in force and the mismatch already exists — the preview is GDC-corrected, the DNG is not.
- If you ever want corrected RAW, you must either apply your own lens warp (needs coefficients you don't have — see D9) or capture **ProRes RAW** and read the GDC metadata attachment.

#### D8 — P2 — Everything else on `AVCaptureDevice` is preview/video-side and does not enter the Bayer RAW

**Evidence (VERIFIED, SDK), verified individually:**
- `videoHDREnabled` / `automaticallyAdjustsVideoHDREnabled` (AVCaptureDevice.h:2149–2163): *"the device streams at twice the published frame rate, capturing an under-exposed frame and correctly exposed frame for each frame time… Portions of the under-exposed frame are combined with the correctly exposed frame to recover detail in darker areas"* — that is fusion, but it is **video** fusion in the ISP. Not present in a `.speed` single-exposure still.
- `globalToneMappingEnabled` (AVCaptureDevice.h:1598–1618): default NO; *"Normally the active camera uses adaptive, local tone curves…"*; *"The receiver's globalToneMappingEnabled resets to its default value of NO"* under several conditions. This is a **display/preview** control.
- `lowLightBoostEnabled` (AVCaptureDevice.h:1892–1907): *"The default value is NO"*; *"the receiver switches at its discretion to a special boost mode under low light… The switch between normal operation and low light boost mode may drop one or more video frames."* Video-side.
- `centerStageControlMode` / `centerStageEnabled` / `centerStageActive` (AVCaptureDevice.h:2340–2373): class-level Control-Center-controlled feature; *"If `geometricDistortionCorrectionSupported` is YES, `geometricDistortionCorrectionEnabled` must also be YES, or Center Stage is deactivated."* Center Stage reframes the sensor — for a Bayer RAW app this is a silent geometry change the user can toggle from Control Center. **Mitigation:** `AVCaptureDevice.centerStageControlMode = .app` and `centerStageEnabled = false`, so the app owns it, or leave it user-controllable and accept the geometry change. Currently the app does nothing (it uses the physical wide camera, which is unaffected — UNVERIFIED for iOS 26 + Center Stage front camera, which is a *virtual* device).
- `preferredVideoStabilizationMode` (AVCaptureSession.h:1225): *"only applicable to `AVCaptureConnection` instances involving video."* For ProRes RAW it instead generates stabilisation metadata. Not a still-RAW knob.
- `activeColorSpace` (AVCaptureDevice.h:2185–2192): *"Changing the receiver's activeColorSpace while the session is running requires a disruptive reconfiguration… unfulfilled photo requests will be aborted; video preview will temporarily freeze."* Plus Apple Log disables photo capture entirely (D6).

**Net:** the only device-level state that matters to a clean Bayer RAW still is `activeColorSpace` (keep `sRGB`/`P3_D65`), `centerStage*` (own it or ignore it), and OIS (which is physical, not computational).

**Fix direction:** do not touch `videoHDREnabled` / `globalToneMappingEnabled` / `lowLightBoostEnabled` for RAW capture — they are preview/video controls and adding them to a RAW app creates coupling with nothing. Take `activeColorSpace` ownership (`AVCaptureSession.automaticallyConfiguresCaptureDeviceForWideColor = false`, then set it once) so the RAW colour path is deterministic. Decide `centerStageControlMode` explicitly: `.app` + `centerStageEnabled = false` if the RAW framing must be invariant; leave `.user` only if you are willing to have Control Center change your sensor geometry. Assert `activeColorSpace != .appleLog` in the capture precondition check.

---

### C. Developing the RAW yourself

#### D9 — P0 — `CIRAWFilter` output is display-referred and Display-P3-tagged; there is no scene-linear output mode

**Evidence (MEASURED).** I instantiated `CIRAWFilter` on the repo's fixture (`pikicamTests/Fixtures/IMG_1361.DNG`, copied to `/tmp`, unmodified), applied the *full* zero recipe, and rendered the output into an **extended-linear** float target:

```
A. CIRAWFilter untouched defaults:        colorSpace = Display P3
B. pikicam recipe (as coded):            colorSpace = Display P3
C. recipe + highlightRecovery off + baselineExposure kept: colorSpace = Display P3

linear-domain stats (recipe, baseline kept):
   meanRGB = (0.0581, 0.0550, 0.0547)
   Y p0.001=0.00433 p0.5=0.04595 p0.99=0.28037 p0.999=0.42993 max=0.57144
   >1.0: 0.00%   <0: 0.02%   NaN: 0
```

Two conclusions:
1. **`outputImage` is always tagged `Display P3`.** Even with every knob at zero, Core Image sees a display-referred image. You cannot obtain a scene-linear `CIImage` from `CIRAWFilter`.
2. **`extendedDynamicRangeAmount` is not a linearisation lever.** Sweeping it produced: `EDR=0 → max 0.57144`, `EDR=1 → max 0.57888`, `EDR=2 → max 0.58634`. No pixel ever exceeds 1.0, and the value stays display-encoded. The repo's `extendedDynamicRangeAmount = 0.0` (CIRAWZeroProcessor.swift:77) is correct-but-irrelevant.

**Side effects of the zeroing, measured:** with `isGamutMappingEnabled = false`, **0.02 % of pixels go negative** (out-of-gamut colours are no longer compressed). That is a real artefact of "zeroing" — it trades Apple's gamut compression for your own clipping.

**Also MEASURED — `decoderVersion` is not free.** `supportedDecoderVersions` on the fixture = `[6.dng, 7.dng, 8.dng]`, default `8.dng`. Rendered pixel statistics were identical across 6/7/8 **under the zero recipe**, but the output colour space tag changed: `6.dng` → **Adobe RGB (1998)**, `7.dng`/`8.dng` → Display P3. So pinning `decoderVersion` also pins a gamut decision. The repo deliberately leaves `decoderVersion` alone (CIRAWZeroProcessor.swift:59) — defensible, but it should be a documented decision, and the render context must not assume Display P3.

**Why it matters:** "zero-process" as currently implemented means "Apple's demosaic, Apple's black level, Apple's colour matrix, Apple's white balance, Apple's display transform, and zero of Apple's *subjective* knobs". That is a defensible product, but it is **not** "our own code develops the sensor data", and the marketing copy should not say otherwise. Adobe's Project Indigo post says the same thing from the other side: *"the pixels read from a digital sensor must be processed to create a recognizable image… Based on our conversations with photographers, what they really want is not zero-process but a more natural look."*

**Fix direction:** split the concept in the code and UI:
- `SensorDevelop` (ours): demosaic + WB + matrix + our tone curve, from `photo.pixelBuffer`.
- `AppleDevelop` (Apple's): current `CIRAWFilter` recipe, used only as a *fallback/comparison* renderer for formats we cannot own (ProRAW) or for a "what Apple would do" A/B.
Never let the two share a label.

#### D10 — P0 — The zero recipe misses `highlightRecoveryEnabled` and overrides `baselineExposure`; measured: 0.30 stops hot with Apple's highlight compression still active

**Evidence — the properties and their real defaults.** Header values (VERIFIED, `CIRAWFilter.h`) plus **MEASURED** defaults on a freshly-constructed filter for the fixture:

| Property | Documented default | **MEASURED default** | Neutral value | pikicam sets |
|---|---|---|---|---|
| `exposure` | 0 | 0.0 | 0 | 0.0 ✅ |
| `baselineExposure` | *"Default value can vary based on the image"* | **−0.30221677** (= DNG `BaselineExposure`) | **leave at DNG value** | **0.0** ❌ |
| `shadowBias` | varies | 0.0 | 0 | 0.0 ✅ |
| `boostAmount` | 1 | **1.0** | 0 | 0.0 ✅ |
| `boostShadowAmount` | 1 | **0.9** | 1 (= neutral) | 0.0 ⚠️ see note |
| `isHighlightRecoveryEnabled` | **true** (iOS 16+) | **true** | false | **not set at all** ❌ |
| `isGamutMappingEnabled` | true | true | true (or own clip) | false ⚠️ (causes negatives) |
| `isLensCorrectionEnabled` | varies | false (`isLensCorrectionSupported` = **false**) | — | false ✅ |
| `luminanceNoiseReductionAmount` | varies | 0.0 | 0 | 0.0 ✅ |
| `colorNoiseReductionAmount` | varies | **0.5** | 0 | 0.0 ✅ |
| `sharpnessAmount` | varies | **1.0** | 0 | 0.0 ✅ |
| `contrastAmount` | varies | **0.1** | 0 | 0.0 ✅ |
| `detailAmount` | varies | **0.5** | 0 | 0.0 ✅ |
| `moireReductionAmount` | varies | 0.0 | 0 | 0.0 ✅ |
| `localToneMapAmount` | varies | **1.0** | 0 | 0.0 ✅ |
| `extendedDynamicRangeAmount` | 0 | 0.0 | 0 | 0.0 ✅ |
| `neutralTemperature` / `neutralTint` | from `AsShotNeutral` | **5201.2573 / 6.358185** | leave | left ✅ |
| `neutralChromaticity` | query only | (0.33989, 0.35140) | leave | left ✅ |
| `decoderVersion` | newest available | **8.dng** (supported: 6/7/8) | pinned | left ✅ |
| `scaleFactor` | 1.0 | 1.0 | 1.0 | not set |
| `isDraftModeEnabled` | NO | false | false | not set ✅ |
| `linearSpaceFilter` | nil | nil | nil | not set |
| `orientation` | from EXIF | **6** | — | not set (applied) ✅ |

**Note on `boostShadowAmount`:** the header says *"A value less than 1 will darken the shadows… This has no effect if the boostAmount is 0."* Since the recipe sets `boostAmount = 0`, `boostShadowAmount = 0.0` is harmless but semantically wrong (0.0 is not the documented neutral, 1 is). Prefer `1.0` so the value is meaningful if `boostAmount` ever becomes non-zero.

**Note on `isHighlightRecoveryEnabled`:** the header declares it `NS_AVAILABLE(16_0, 19_0)` — i.e. **removed/deprecated in iOS 19**. The repo skips it as "deprecated as of iOS 19" (CIRAWZeroProcessor.swift:60). But it is **still present and still returns `true`** on the current runtime. Skipping it because it is deprecated means Apple highlight compression keeps running forever, with no deprecation warning, because the SDK will keep the symbol alive. **If the property exists and defaults to true, you must set it to false** — deprecation is not permission to leave an enhancement on.

**Measured impact (centre 50 % crop, Display P3, 8-bit):**

```
A. CIRAWFilter untouched defaults (Apple's look):
   meanRGB=(121.0, 131.3, 147.2)  luma p50=137 p90=201 p99=222 p99.9=247 max=253  pure-black=0.651%
B. pikicam CIRAWZeroProcessor recipe (as coded):
   meanRGB=(102.9, 110.4, 122.0)  luma p50=122 p90=166 p99=199 p99.9=208 max=244  pure-black=0.000%
C. recipe + highlightRecovery OFF + baselineExposure kept at DNG value:
   meanRGB=( 93.2,  99.9, 110.6)  luma p50=110 p90=151 p99=181 p99.9=189 max=226  pure-black=0.000%
```

- B vs C: mean drops by ~10.5/255 ⇒ **≈0.30 stops**, exactly the DNG's `BaselineExposure = −0.302217`. So forcing `baselineExposure = 0` makes the develop **systematically ~0.3 stops hot** versus the camera's own reference. The neutral value for `baselineExposure` is *"whatever the DNG says"*, i.e. **do not touch it**.
- B vs C at the top end: `p99.9` 208 → 189, `max` 244 → 226 ⇒ **Apple's highlight recovery is still compressing highlights in B.** The repo's claim of "the complete zero-process recipe: every enhancement control declared by the iOS SDK's CIRAWFilter.h" (CIRAWZeroProcessor.swift:60-63) is **false by one control**, and that one control is visible in the highlight roll-off.
- The `PikicamPipelineTests` assertion that the recipe "must neutralize every enhancement `CIRAWFilter` declares" (`pikicamTests/PikicamPipelineTests.swift:511`) is itself encoding the omission: `tests` line 523 forbids `temperature`, `tint`, `neutralTemperature`, `neutralTint`, `decoderVersion` — but nothing forbids `highlightRecoveryEnabled`.

**Fix direction:**
1. Remove `baselineExposure` from the recipe (leave the DNG's value).
2. Add `highlightRecoveryEnabled = false`, guarded by `#available` / `responds(to:)` — and change the test's forbidden list to *require* it.
3. Set `boostShadowAmount = 1.0` (documented neutral) rather than 0.0.
4. Record the recipe as a *versioned* struct with a golden-output hash test, so an SDK bump that changes a default is caught by a test rather than by a user noticing.

#### D11 — P0 — `linearSpaceFilter` is an insert hook on the already-demosaiced linear image — the only supported way to affect Apple's linear stage, and not a tap

**Evidence (VERIFIED, header):** *"`linearSpaceFilter` — An optional CIFilter to be applied to the RAW image **while it is in linear space**."* (CIRAWFilter.h)

**Evidence (MEASURED):**
1. *Is it post-demosaic RGB?* Installed `CIColorMatrix` that passes only R and zeroes G/B. Result: `meanRGB = (83.1, 12.2, 7.0)` — a strongly red image. If the hook ran on a CFA mosaic, channel isolation would be meaningless. It runs on a **demosaiced linear RGB image**. (The residual G/B ≈ 12/7 shows the later stages still mix channels — tone mapping and gamut mapping are downstream.)
2. *Does it actually fire?* `linearSpaceFilter = CIExposureAdjust(-1 EV)` gave `meanRGB = (65.9, 69.5, 75.3)` vs `(92.6, 97.4, 105.2)` unfiltered — exactly −1 stop.
3. *Where does `exposure` sit?* `filter.exposure = -1.0` produced **byte-identical** results to `linearSpaceFilter = CIExposureAdjust(-1 EV)` (`(65.9, 69.5, 75.3)` both). So the public `exposure` property *is* the linear-stage exposure — it is not a display-space knob. Useful: it means `exposure` is a legitimate, honest control even in a "no processing" renderer.

**So the pipeline shape is:**

```
DNG ─► black level (DNG tags) ─► LinearizationTable ─► [DRAW/black-noise handling]
    ─► white balance (AsShotNeutral) ─► DEMOSAIC (Apple) ─► linear RGB
    ─► ★ linearSpaceFilter  ← you can insert here, you cannot read out here
    ─► local tone map (localToneMapAmount) ─► global tone curve (boostAmount/boostShadowAmount/shadowBias)
    ─► highlight recovery ─► noise reduction ─► detail/sharpen/contrast/moiré
    ─► lens correction (unsupported here) ─► colour matrix ─► gamut map ─► Display P3 transfer
```

**What this rules out:** you cannot replace Apple's demosaic through `CIRAWFilter`; you cannot read a scene-linear image out of it; you cannot bypass the tone-curve stage.
**What it enables:** a *hook* for a custom linear operation — e.g. installing your own noise model, a linear sharpening kernel, a highlight-recovery curve, or (see D14) a side-effecting kernel. This is the correct place to put "our science" if you stay on Apple's demosaic.

**Fix direction:** design the develop API around this boundary. `SensorDevelop` should accept *either* an owned raw frame (`photo.pixelBuffer` + CFA layout + metadata — the real path) *or*, as a fallback, a DNG (`CIRAWFilter`). If you stay on Apple's demosaic, the only honest place to inject your science is `linearSpaceFilter`, and it must be treated as post-demosaic linear RGB — so put WB-adjusted, matrix-ready operations there (e.g. `CIColorMatrix` for your colour transform, a custom `CIColorKernel` for your noise model or highlight curve), and keep the `CIRAWFilter` subjective knobs at their documented neutrals rather than at zero.

**UNVERIFIED / research item:** whether a custom `CIColorKernel` built from Metal source can be used as a *side-effecting tap* inside `linearSpaceFilter` (writing the linear image to a Metal buffer via a device pointer, or via a `CIContext` render of the kernel's own `inputImage`). If it works, you get a legal-ish escape hatch to a linear intermediate. Treat as a hack; do not ship it without measuring.

#### D12 — P0 — To bypass Apple's demosaic, use `AVCapturePhoto.pixelBuffer`, not the DNG

**Evidence (VERIFIED, SDK), `AVCapturePhoto.pixelBuffer`, AVCapturePhotoOutput.h:2011–2015:**

> "For uncompressed or RAW captures, this property offers access to the pixel data. … **Bayer RAW captures, such as `'bgg4'`**, or Apple ProRAW captures, such as `'l64r'`, present pixel data as a `CVPixelBuffer`. … Compressed captures, such as `'jpeg'`, return nil."

`'bgg4'` is the fourcc for `kCVPixelFormatType_14Bayer_BGGR`. The four Bayer formats the repo already whitelists (CaptureService.swift:636–646) are the four the platform can deliver.

**This is the single most important architectural fact in this document.** The Bayer mosaic, at 14-bit, is handed to the app directly. A true bypass pipeline is:

```
AVCapturePhotoSettings(rawPixelFormatType: kCVPixelFormatType_14Bayer_RGGB)
  → AVCapturePhoto.pixelBuffer            // 14-bit CFA mosaic, your CFA layout
  + OSType you passed in                  // the CFA pattern — YOU must remember it
  + photo.metadata (exif: ISO, exposure, …)
  + AVCameraCalibrationData (if obtainable — see D9/D3)
  → our demosaic (Metal)
  → our WB + colour matrix (from DNG tags, see D13)
  → our tone curve, NR, sharpening
  → our render

in parallel: photo.fileDataRepresentation() → DNG for the archive / our own re-write
```

**Why the DNG is not enough:** MEASURED, the fixture's DNG is `PhotometricInterpretation 34892` (LinearRaw) — 3 full-resolution components of `uint16` per tile, `SOF3` lossless JPEG, 64 tiles of 504×378, i.e. 3× more samples than the image has pixels. A custom demosaic that reads `photo.pixelBuffer` gets a real 1-sample-per-pixel mosaic; one that reads only the DNG depends on Apple's packaging (and, for ProRAW, on data that is already demosaiced and irrecoverably processed).

**Supporting (SOURCED):** Adobe Project Indigo — *"our DNG provides a benefit that most raw images do not – the aligning and merging of multiple frames… **They are also stored before demosaicking, i.e. 1 color per pixel instead of 3**, so they are smaller than Apple's ProRAW files with no loss in quality."* A single iOS RAW capture gives you exactly this; Indigo then merges several of them into its own DNG.

**Fix direction:** introduce a `RawFrame` value type carrying `{cfaLayout, pixelBuffer (or its bytes), metadata, iso, exposureTime, lensPoseIfAny}`, produced in `PhotoCapture` and consumed by both the renderer and the DNG archiver. Do not let the renderer take `Data` (a DNG) as its only input.

#### D13 — P1 — DNG tags you can rely on for a self-develop, and the ones you must add yourself

**Evidence (MEASURED) — `{DNG}` dictionary as surfaced by ImageIO/CIRAWFilter for the fixture, plus raw TIFF tag sweep of every IFD:**

Present (usable for your own develop):
- `ColorMatrix1` = `[1.227163, −0.545479, −0.261288; −0.454686, 1.517780, −0.042650; −0.040938, 0.163614, 0.591346]`
- `ColorMatrix2` = `[0.914543, −0.322228, −0.126225; −0.428868, 1.309541, 0.094676; −0.106292, 0.235046, 0.430733]`
- `CalibrationIlluminant1` = 17 (Standard light A), `CalibrationIlluminant2` = 21 (D65)
- `AsShotNeutral` = `(0.448975, 1.0, 0.540869)`
- `BaselineExposure` = −0.302217 EV; `BaselineSharpness` = 1.5
- `BlackLevel` = `(0, 0, 0)`; `WhiteLevel` = `(65535, 65535, 65535)`
- `NoiseProfile` = `(3e-05, 3e-08)`; `NoiseReductionApplied` = 0.95 (ProRAW-only hint — ignore for Bayer)
- `DefaultBlackRender` = 1; `UniqueCameraModel` = `iPhone13,3 back camera`; `DNGVersion` = (1,4)
- Raw IFD also carries `LinearizationTable` (50712/0xC618, 4096 SHORTs) — see D14.

**Absent** (MEASURED — full tag sweep of IFD0 + both SubIFDs; total tag set is exactly 41 tags):
- `CFAPattern`, `CFARepeatPatternDim`, `CFAPlaneColor`, `CFALayout` — **absent in this file** (expected: it is LinearRaw/ProRAW). The DNG spec requires `CFARepeatPatternDim` + `CFAPattern` when `PhotometricInterpretation = 32803` (CFA), so a genuine Bayer capture **should** carry them. **UNVERIFIED on device** — capture one and check. If Apple omits them (as this file suggests Apple is not exhaustive), you must persist the `OSType` you requested and stamp it into your own archival DNG.
- `ForwardMatrix1/2`, `CalibrationMatrix`, `AnalogBalance`, `BayerGreenSplit`, `LinearResponseLimit`, `ActiveArea`, `MaskedAreas`, `OriginalRawFileName`, `DefaultCropOrigin/Size`, `CameraCalibration1/2`, `LensInfo` — all absent. So there is **no** ForwardMatrix path; use `ColorMatrix1/2` interpolated by `AsShotNeutral` between `CalibrationIlluminant1` and `CalibrationIlluminant2` (the standard DNG colour model), exactly as Adobe documents and as `colour-hdri`'s `dng.py` implements.
- `LensInfo` / any distortion coefficients — absent ⇒ confirms D9: **you must ship your own lens calibration table** (per `UniqueCameraModel` + focal length). This is unavoidable and is a real, shippable engineering task.

**Fix direction:** write a small `DNGMetadata` reader (a TIFF/IFD parser is ~300 lines; `imagecodecs`/libtiff equivalents exist) that extracts exactly the tags above, and a writer that emits a *spec-clean CFA DNG* with `CFAPattern`/`CFAPlaneColor`/`CFALayout`/`ActiveArea`/`BlackLevel`/`WhiteLevel`/`AsShotNeutral`/`ColorMatrix1/2`/`CalibrationIlluminant1/2`/`UniqueCameraModel`/`OriginalRawFileName`, so your archives open correctly in Lightroom/Capture One/darktable. Adobe's DNG SDK (1.7) or LibRaw can write this for you; the licence terms of the DNG SDK need checking before adoption (Adobe's own licence notice is the binding document).

#### D14 — P0 — The raw samples are gamma-encoded: apply `LinearizationTable`, and do not trust `WhiteLevel` naively

**Evidence (VERIFIED, DNG spec 1.4, p. 25 & 28):**
- *LinearizationTable (50712 / 0xC618): "describes a lookup table that maps stored values into linear values. This tag is typically used to increase compression ratios by **storing the raw data in a non-linear, more visually uniform space** with fewer total encoding levels."*
- *WhiteLevel (50717 / 0xC61D): "specifies the fully saturated encoding level… **The default value for this tag is (2 ** BitsPerSample) − 1** for unsigned integer images."*

**MEASURED on the fixture:**
```
LinearizationTable: 4096 entries, monotonically non-decreasing
  in=0 → 0      in=1 → 40     in=2 → 80     …  in=9  → 361
  in=64 → 2564  in=256 → 10295  in=512 → 20830  in=1024 → 43583
  in=1200 → 52196  in≈1454 → 65535 (clamped; 2642 of 4096 entries are exactly 65535)
BlackLevel = (0,0,0)      WhiteLevel = (65535,65535,65535)      BitsPerSample = 12
Decoded tile statistics (lossless-JPEG SOF3, 12-bit precision):
  plane means 211 / 548 / 379 ; observed code range ≈ 57 … 849 on a bright ISO-32 frame
```

**Reading:** the stored 12-bit codes are a non-linear (≈gamma) encoding; the table maps them into the 16-bit linear domain implied by `WhiteLevel = 65535`. If you demosaic the *stored* values directly and then apply `ColorMatrix`, you will apply the colour matrix to gamma-encoded data — wrong hue and wrong noise structure.

**Also note:** `BlackLevel = (0,0,0)` means the sensor black offset has **already been subtracted** by the ISP; do not subtract anything again.

**Fix direction:** in your own demosaic/linearise stage, (1) skip black subtraction, (2) apply `LinearizationTable` as a 4096-entry LUT (or the analytic equivalent), (3) only then apply `ColorMatrix`/WB. Add a unit test that the linearised histogram is roughly log-distributed, plus a rendered-gradient test that proves the transform is monotone and 1:1 at both ends.

#### D15 — P1 — A genuinely custom demosaic on iOS is buildable; here are the realistic options

**Evidence (SOURCED):**
- **LibRaw** — "a library for reading RAW files… extracts RAW data (pixel values), metadata necessary for processing RAW (geometry, CFA/Bayer pattern, black level, white balance, etc.)"; GPL/LGPL ⇒ **copyleft — check before shipping**. Integrates RawSpeed and the Adobe DNG SDK.
- **RawSpeed** (darktable) — "supplies unmodified RAW data, optionally scaled to 16-bit or normalized to 0→1 float. Supplies CFA layout for all known cameras. **It does not do demosaicing or colour management.**" Permissive (Apache-2/GPL dual, darktable ships GPL) — verify per-file licence.
- **Adobe DNG SDK 1.7** — read *and write* DNG, includes `dng-validate`. Licence is Adobe's "DNG License Agreement"; note the community reports (Adobe Community thread 182173) that the licence terms for the current build are unclear — **do not adopt without legal review**.
- **colour-hdri** — a clean, documented reference implementation of the DNG colour model (dual-illuminant matrix interpolation, `ForwardMatrix` fallback rules) — use as the algorithm spec, port the ~200 lines you need.
- `JonahZeng/dngparser` — a libtiff-free C++ TIFF/DNG parser with a **16-bit-Huffman lossless-JPEG (SOF3) decoder built specifically for Apple ProRAW tiles** — a practical reference for the Apple tile format. Its README distinguishes *"uncompressed CFA Bayer (DJI)"* from *"LJPEG-compressed tiled LinearRaw (Apple)"*, corroborating that Apple's own DNGs are LinearRaw.
- Metal compute-kernel demosaic on iOS is routine; `adwirth/CamProc` is a small, readable example of `AVCapturePhotoOutput` + `CVPixelBuffer` → custom bilinear debayer in a Metal compute shader → `CVMetalTextureCache` display.

**Recommended shape (fits this product):**
1. **CFA ingest:** `photo.pixelBuffer` (14-bit Bayer) as the fast path; DNG re-read (own TIFF + SOF3 decoder, or a vendored RawSpeed/LibRaw-class library) as the *import/archival* path.
2. **Linearise:** `LinearizationTable` + `BlackLevel` (D14).
3. **Demosaic:** own Metal kernel — start with bilinear/hamel, graduate to a directional (e.g. 5×5 Hamilton–Adams / Malvar) or a small CNN if you want to beat Apple's. Quality will not match Apple's demosaic on day one; that is fine and is the honest differentiator.
4. **Colour:** `AsShotNeutral` → interpolate `ColorMatrix1`/`ColorMatrix2` by `CalibrationIlluminant1/2` → camera→XYZ, then XYZ→your working space. Optionally a DCP profile per `UniqueCameraModel`.
5. **Look:** your tone curve, your NR, your sharpening — this is where the product wins.
6. **Archive:** write your own CFA DNG (CFA tags included) so the RAW outlives the app.

**Cost warning:** steps 3–6 are a multi-month effort with real colour-science risk. The pragmatic V1 is steps 1, 2, 4, 5 with **Apple's** demosaic (`CIRAWFilter` via `linearSpaceFilter` for WB/matrix) and step 6 deferred — then swap the demosaic behind an interface.

#### D16 — P2 — `CIRAWFilter` auxiliary images and properties worth knowing

**Evidence (VERIFIED header + MEASURED):**
- `previewImage` — **non-nil on the fixture** (an embedded 2016×1512 JPEG, `urn:com:apple:photo:2020:aux:semanticskymatte` sibling in a second SubIFD). Useful as an instant scrub preview, *but it is Apple's rendering*, so it must never be mistaken for the develop output.
- `portraitEffectsMatte`, `semanticSegmentation{Skin,Hair,Glasses,Sky,Teeth}Matte` — `portraitEffectsMatte` nil, **`semanticSegmentationSkyMatte` non-nil** on the fixture. Proof that Apple's semantic models still run and are still embedded even in files that look "raw". For a Bayer capture these are not requested and will be nil.
- `nativeSize` — full unscaled size, unaffected by `orientation`/`scaleFactor` (measured 4032×3024 for a file whose output is 3024×4032 because `orientation` defaults to 6 and **is applied**). The repo relies on this behaviour (DevelopService.swift:44-50) — correct, and now empirically confirmed.
- `scaleFactor` (0…1, default 1) and `isDraftModeEnabled` (default NO) — the intended latency lever for interactive preview renders of the develop pipeline. MEASURED: on the fixture, toggling `draftModeEnabled` changed nothing at `scaleFactor = 1`; use it with `scaleFactor < 1`.
- `properties` — *"a dictionary with the same contents as `CGImageSourceCopyProperties`"*: the canonical, supported way to read the `{DNG}` dictionary for your develop. Use it instead of hand-parsing TIFF where possible.

**Fix direction:** use `properties["{DNG}"]` as the metadata source of truth in `RAWProcessor` (it already carries `ColorMatrix1/2`, `CalibrationIlluminant1/2`, `AsShotNeutral`, `BaselineExposure`, `BlackLevel`, `WhiteLevel`, `NoiseProfile`, `ProfileName`, `UniqueCameraModel`) and only fall back to a hand-written TIFF parser for the tags ImageIO hides (`LinearizationTable`, the CFA tags). Keep `previewImage` strictly for scrub/placeholder rendering, and never let it reach the develop path. Drive gallery/importer thumbnails with `scaleFactor ≈ 0.25` + `isDraftModeEnabled = true` instead of downscaling a full develop.

---

### D. Saving, Photos, and what the user sees

#### D17 — P0 — A DNG-only `.photo` asset makes Photos (and `PHImageManager`) render Apple's look; the gallery therefore disagrees with the viewer

**Evidence (VERIFIED, SDK):** Apple's RAW doc — *"create a single Photos asset that associates the RAW or Apple ProRAW data with the processed data. Create an instance of `PHAssetCreationRequest`, then specify the **DNG version as the asset's main `PHAssetResourceType.photo` resource**, and the processed image as the `PHAssetResourceType.alternatePhoto` resource."*

**Evidence (SOURCED, the counter-convention for plain Bayer):** `PHAssetResourceType.alternatePhoto` documentation — *"For example, a photo asset imported from an external camera may contain both a JPEG file (the primary form of the asset) and a RAW file (the alternate photo)."* And Halide/Lux's Process Zero manual, describing the exact symptom pikicam will hit:

> "**My photo is looking different in Photos than in Halide. Is it supposed to be that way?** … You should verify that 'Save HEIC (or JPG) with RAW' is enabled here. If it is, Photos will show the Process Zero shot Halide created alongside the raw data. **If it isn't, Photos will process the raw data itself, which usually isn't great.**"

**Repo (file:line):**
- `performDNGSave` adds exactly one resource: `request.addResource(with: .photo, data: data, options: options)` with `uniformTypeIdentifier = dng` (PhotoLibraryManager.swift:372–373).
- `requestThumbnail` uses `options.version = .current` with the comment *"`current` returns the rendered, displayable version"* (PhotoLibraryManager.swift:680–682) — i.e. **Photos'** rendering of the DNG.
- `isDNGResource` matches only `resource.type == .photo` (PhotoLibraryManager.swift:894) — adding an alternate resource will break this predicate unless it is widened.

**Consequences, concretely:**
1. `GalleryView` thumbnails are produced by Apple's RAW renderer (`boostAmount 1`, `localToneMapAmount 1`, `sharpnessAmount 1`, `colorNoiseReductionAmount 0.5`, `contrastAmount 0.1`, `detailAmount 0.5` — all MEASURED as the CIRAWFilter defaults). The full-screen viewer uses the zero recipe. **The same capture looks like two different photographs in the same app.**
2. Photos, iCloud, AirDrop, and any third-party reader show Apple's look. Your product's differentiator is invisible outside the app.
3. `PHImageManager` on a DNG-only asset is also the slowest, least controllable path (it must render the RAW every time, and with `isNetworkAccessAllowed = true` on an iCloud asset, on demand).

**Fix direction — two coherent options; pick one and be consistent:**
- **(A) "Our look is the product."** Render the DNG with your own develop *in your own renderer* and cache the bitmap (JPEG/HEIF, Display-P3) app-side. Save: **processed render as `.photo`, DNG as `.alternatePhoto`.** Now Photos shows your look, the DNG is still there for Lightroom/ProRAW-capable editors, and the gallery can use its own cache instead of `PHImageManager`. (This is exactly LibreCam's stated design: *"A Bayer DNG for the edit: the true sensor readout, no fusion, no noise reduction, no tone mapping. And a HEIF for the share: one frame, developed by the hardware ISP."*)
- **(B) "The DNG is the product."** Keep the DNG-only asset, but **stop using `PHImageManager` for anything user-visible** — render every thumbnail from your own develop, cache it, and only fall back to `PHImageManager` for the fallback/original path. Accept that Photos shows Apple's rendering and say so in the UI.

Whichever is chosen: widen `isDNGResource` to accept `.alternatePhoto` and to not depend on `type == .photo`.

#### D18 — P1 — Metadata, UTI, and resource plumbing

**Evidence (VERIFIED, SDK / repo):**
- `AVCapturePhotoSettings.metadata` (AVCapturePhotoOutput.h:1546–1548): *"Valid metadata keys are found in `<ImageIO/CGImageProperties.h>`… `AVCapturePhotoOutput` **inserts a base set of metadata into each photo** it captures, such as `kCGImagePropertyOrientation`, `kCGImagePropertyExifDictionary`, and `kCGImagePropertyMakerAppleDictionary`. You may specify metadata keys and values… **If you've specified metadata that also appears in the base set, your value replaces the base value.**"* → You *can* inject your own maker-note/XMP fields (e.g. "pikicam develop settings") and override orientation/EXIF. This is the supported hook for round-tripping your own develop parameters with the file.
- `rawEmbeddedThumbnailPhotoFormat` (AVCapturePhotoOutput.h:1636–1638): *"a thumbnail … to be embedded in that image's DNG"* — you can put *your* thumbnail (not Apple's) inside the DNG. `availableRawEmbeddedThumbnailPhotoCodecTypes` tells you the codecs. On ProRAW, Apple's doc notes it *"supports capturing up to a full-resolution JPEG image to use as a thumbnail photo."*
- `photo.fileDataRepresentation(with:)` + `AVCapturePhotoFileDataRepresentationCustomizer` (Apple RAW doc): lets you pick ProRAW bit depth / compression. For Bayer RAW the relevant hook is `replacementRawCompressionSettings`/`replacementAppleProRAWCompressionSettings` — check which selectors your deployment target requires; the exact contract is: *"a custom object that conforms to the `AVCapturePhotoFileDataRepresentationCustomizer` protocol"*.
- `UTType(filenameExtension: "dng")` (PhotoLibraryManager.swift:217) is a reasonable primary choice, but `public.dng` / `com.adobe.raw-image` are the more canonical identifiers; prefer the **system-declared** DNG UTI and keep the `.dng` filename extension (you already do: `pikicam-<uuid>.dng`).
**Fix direction:** treat orientation as metadata, never as pixel work. Keep the RAW in sensor orientation, write `kCGImagePropertyOrientation` on save, and let the renderer honour `CIRAWFilter.orientation` (or your own transform) at display time. Round-trip your own develop parameters through `settings.metadata` (or a maker-note extension) so a DNG exported from the app re-opens with the same look.

- Orientation: `cameraSensorOrientationCompensationEnabled` (iOS 26) is *never applied to Bayer RAW*, so your RAW buffers keep sensor orientation and `photo.metadata`'s `kCGImagePropertyOrientation` is what tells consumers how to display it. MEASURED: `CIRAWFilter` honours it (`orientation` default = 6 ⇒ output extent 3024×4032 for a 4032×3024 sensor). Keep writing it; do not pre-rotate.

#### D19 — P2 — What the Photos app does when it *does* display a DNG

**Evidence (SOURCED):** the Photos/Mac behaviour is that a RAW+JPEG pair shows the JPEG by default with an editable "RAW as Original"/"RAW" toggle; editing the JPEG in Photos leaves the RAW untouched. When the RAW is the only resource, Photos renders it with its own engine (ImageIO → `CIRAWFilter` with Apple defaults). Community reports of "Photos changes the photo on opening it" for DNGs are the same phenomenon.

**Design implication:** a "view in Photos" affordance is a *loss of the product's thesis* unless the asset carries your render. Make the in-app viewer the primary surface and treat Photos as an archive.

**Fix direction:** ship an explicit "developed look" and mark the asset so the difference is legible — e.g. write the develop parameters into the DNG's metadata, and, if you adopt option (A) in D17, the Photos-visible render *is* your look so nothing is lost. Add a one-line explanation in the app's capture/settings UI ("Photos renders RAW itself; pikicam shows you our develop") so the discrepancy is never a bug report.

---

### E. Preview

#### D20 — P1 — There is no Apple-free preview; the honest architecture is "ISP preview + your own post-capture review"

**Evidence (VERIFIED, SDK):**
- `AVCaptureVideoPreviewLayer` is a `CALayer` whose only public surface is `session`, `connection`, `videoGravity`, `previewing`, `deferredStartSupported` (iOS 26). **No processing controls exist.** There is no `previewToneCurve`, no `previewSharpening`, nothing.
- The video stream itself comes from the ISP, which is exactly the thing you are bypassing. `videoHDREnabled` (AVCaptureDevice.h:2154): *"the device streams at twice the published frame rate, capturing an under-exposed frame and correctly exposed frame for each frame time… Portions of the under-exposed frame are combined with the correctly exposed frame to recover detail in darker areas"* — **video HDR is multi-frame fusion**, so leaving it on means the preview shows fused data.
- `globalToneMappingEnabled` (AVCaptureDevice.h:1598) is the preview/display tone-mapping control and defaults to **NO** on a device where the format supports it — i.e. the ISP is doing its *adaptive local* tone curves by default.

**Practical levers available today:**
- `automaticallyAdjustsVideoHDREnabled = false` + `videoHDREnabled = false` (if `activeFormat.isVideoHDRSupported`) → preview stops being a fused HDR stream. **This makes the preview structurally match a single-exposure still.** Costs dynamic range in the preview and may look worse than the Camera app.
- `activeColorSpace` — keep `P3_D65`/`sRGB`, never Apple Log (photo capture breaks).
- `AVCaptureVideoDataOutput` + own Metal render gives you *your* tone curve over the ISP's video frames — this is as close to a "raw preview" as iOS permits, and it is the only way to make live view and post-capture review share a look. The cost: you own the render loop, latency, rotation, mirroring, and CADisplayLink pacing.
- `AVCaptureVideoPreviewLayer.deferredStartSupported` (iOS 26) — for launch latency, not for look.

**Why a mismatch is unavoidable:** the preview is a **12 MP-binned 30/60 fps ISP stream** (already demosaiced, NR'd, tone-mapped, and possibly EDR-fused); the capture is a **12 MP Bayer mosaic with no processing**. They are different data. No amount of configuration makes them equal — only the post-capture review (rendered by your develop from the actual RAW) can be truthful.

**This is what the good apps do:** Halide's Process Zero manual says outright: *"My Process Zero image looks a lot darker or lighter than what I saw. Why is that? … Process Zero doesn't do this [HDR]. That means that sometimes, if you photograph someone up against a bright window, you will have to choose…"* — i.e. they accept the mismatch, document it, and fix it with an **Image Lab** that re-develops the RAW at a chosen exposure.

**Fix direction:**
1. Turn off video HDR so the preview is at least single-exposure.
2. Keep `AVCaptureVideoPreviewLayer` for the live view (battery/latency) — but render the **post-capture review with your develop code**, at full resolution, from the actual RAW, as the ground truth. (pikicam already does this — `DevelopService`; make it the *only* full-screen image path, and label it "develop preview", not "preview".)
3. Add a "re-develop from RAW" affordance (exposure/WB) like Halide's Image Lab, so the user can fix what the preview couldn't promise.
4. If/when latency allows, add a `AVCaptureVideoDataOutput` preview renderer that runs the *same* tone curve as the develop, and swap to it behind a setting.

**Metrics to instrument (so the mismatch is a known number, not a vibe):** capture the same static scene at 1× and compute ΔE2000 between (a) the preview frame and (b) your develop of the RAW, on a mid-grey chart and on a high-contrast scene. Publish the number in the UI ("preview ≈ our develop within ΔE x") so any future regression in this area is caught by a test, not by a user.

#### D21 — P2 — Preview/capture *geometry* mismatches to handle explicitly

**Evidence (VERIFIED):**
- `videoGravity = .resizeAspectFill` (PreviewView.swift:63) + GDC-on preview + RAW-off-GDC capture ⇒ FOV differs (D7). The repo's framing mask is a SwiftUI composition over the full-sensor feed — the correct shape — but the *preview* is GDC-corrected and narrower than the DNG's, so the mask does not correspond to the capture's FOV.
- `AVCaptureDevice.videoZoomFactor = 1.0` always represents "full viewable field of view" *with GDC applied* (AVCaptureDevice.h:2267). RAW requires zoom 1.0 *and* is never GDC-corrected ⇒ **the RAW is always slightly wider than the 1× preview.** Quantify it once per device and bake the correction into the crop maths, or disable GDC and accept a wider preview.
- `captureDevicePointConverted(fromLayerPoint:)` (CameraPreview.swift:66) is the correct tap-to-focus mapping and is unaffected by these issues.

---

### F. Reference implementations — what they actually do (and what is knowable)

| App | What is documented | Takeaway for pikicam |
|---|---|---|
| **Halide / Lux "Process Zero"** (lux.camera/process-zero-manual) | Single exposure; collects raw sensor data; Halide's *own* minimal process; *"no AI is involved at all, and instead of taking a spread of photos and combining them, it only takes one"*; **cannot** do 24/48 MP or 2× on 14 Pro/15 Pro because *"we do not get 48 raw sensor data from iOS"*; no Night mode, no Portrait; saves raw **and** the Process Zero render together; ships an **Image Lab** that re-develops the RAW at a different exposure | The canonical product shape: raw + own render + re-develop. Also the canonical admission of the 48 MP limit. |
| **LibreCam** (librecam.app) | *"A Bayer DNG for the edit: the true sensor readout, no fusion, no noise reduction, no tone mapping. And a HEIF for the share: one frame, developed by the hardware ISP."* | Exactly option (A) in D17: our render is the `.photo`, the Bayer DNG is the `.alternatePhoto`. |
| **Adobe Project Indigo** (research.adobe.com/articles/indigo) | Under-exposes harder, merges up to **32 frames**; its DNG is *"stored before demosaicking, i.e. 1 color per pixel instead of 3"*; its look is *mild* tone mapping + colour + sharpening with subtle semantic masks; *"what they really want is not zero-process but a more natural look"*; zero-shutter-lag with RAW **and** JPEG | The counter-example: even Adobe does not ship a zero-process look, and they get pre-demosaic DNGs by merging many single-exposure RAW frames themselves — which iOS *does* allow one at a time. That is the path to HDR-from-RAW (and to super-resolution) if you ever want it. |
| **Obscura / ProCamera / Manual / Kino / FiLMiC Pro** | All capture Bayer RAW via the same public API; `ProCamera`: *"RAW photos will be saved in the DNG file format and always makes use of the full sensor resolution (4:3)"*; **Digital Negative** is *"the first iOS application certified by Adobe to write true DNG files directly from iPhone camera sensors—without relying on Apple's ProRAW wrapper"* | No published internals; treat as existence proofs only. Do not assume any of them bypass the ISP beyond the Bayer path. |
| **Bayer Cam** (bayercam.com) | The best plain-language technical reference: 12-bit Bayer, `WhiteLevel 4095`, ProRAW is processed + fused + semantic, Bayer is not | Use as the customer-facing explanation of the trade-off. |
| **Adobe DNG SDK / LibRaw / RawSpeed / colour-hdri** | See D15 | The toolbox for the real bypass path. |
| **ProRes RAW (iOS 26, iPhone 17 Pro)** | `AVVideoCodecType.proResRAW` / `.proResRAWHQ` (`@"aprn"` / `@"aprh"`), iOS 26+ (VERIFIED in `AVVideoSettings.h:53-54`); Apple announces ProRes RAW capture in **Final Cut Camera 2.0** for iPhone 17 Pro/17 Pro Max (apple.com/newsroom); `AVCaptureVideoDataOutput` supports it: *"rotation is not supported for RAW buffers"*, `deliversPreviewSizedOutputBuffers` yields 4:2:2 proxy, **white balance must be locked** before writing, and GDC/stabilisation arrive as *metadata attachments* + raw WB factors and colour matrices (`AVMetadataQuickTimeMetadataKeyWhiteBalanceByCCT…`, `AVMetadataFormat.h:187-190`) | The newest surface where Apple explicitly ships *metadata instead of pixels* so you develop yourself. Video-shaped, but it is where the platform is heading, and it validates the architecture in D12: **take the raw + metadata, develop in your own code.** |

---

## Open questions / assumptions

**Assumptions I made (recorded deliberately, no human available):**
1. **A1.** "Current iOS" = the `iPhoneOS26.5.sdk` shipped with the installed Xcode 26.6, which is the toolchain this repo builds against (`project.yml` deploymentTarget `iOS 26.5`). All SDK citations are from that SDK.
2. **A2.** The CIRAWFilter experiments were run on **macOS** with the same `CoreImage` implementation (CIRAWFilter is `NS_CLASS_AVAILABLE(12_0, 15_0)`), because the repo's DNG fixture is readable there and `CIRAWFilter`'s decoding is platform-shared. Defaults were read off a freshly constructed filter on the real fixture. **Re-run on device before locking the recipe** — some properties are documented as "default will vary per image", and the device decoder set may differ (`supportedDecoderVersions` included 6/7/8.dng here).
3. **A3.** The fixture `pikicamTests/Fixtures/IMG_1361.DNG` was treated as read-only sample data (copied to `/tmp`; the repo working tree was not touched).
4. **A4.** "Bypass" is defined operationally as **the delivered DNG/pixel data is a single, un-fused, un-demosaiced sensor exposure**, and that **our code** produces every pixel the user sees. Anything short of that (Apple's demosaic, Apple's display transform, an ISP-fused preview) is labelled honestly as such.
5. **A5.** The deployment target is iPhone-only (per `project.yml`), iPhone 12 Pro-class hardware is assumed as the test floor (that is what the fixture is), and 48 MP quad-Bayer devices (iPhone 14 Pro and later) are the primary target class.

**Open questions that need on-device answers (each with the experiment):**
1. **OQ1 — Are the CFA tags present in a real Bayer DNG?** Capture with `AVCapturePhotoSettings(rawPixelFormatType: kCVPixelFormatType_14Bayer_RGGB)` and dump every IFD. Expect `PhotometricInterpretation = 32803` with `CFARepeatPatternDim`/`CFAPattern`/`CFAPlaneColor`/`CFALayout`. If they are absent, the app must persist the requested `OSType` itself and stamp it into its archival DNG. *(The ProRAW fixture has none, but that is expected for LinearRaw.)*
2. **OQ2 — What is `availableRawPhotoPixelFormatTypes` on a 48 MP device, and what is `rawPhotoDimensions` at each `maxPhotoDimensions`?** Enumerate; this settles whether any RAW path above 12 MP exists (D4).
3. **OQ3 — Does `+photoSettingsWithRawPixelFormatType:` really default `photoQualityPrioritization` to `.speed`, and does setting it explicitly to `.speed` work on iOS 26.5?** Print `settings.photoQualityPrioritization` immediately after construction and set it explicitly. Also re-test whether `maxPhotoQualityPrioritization = .quality` really throws (the repo claims a verified SIGABRT) — if it does not, `.quality` must never be exposed.
4. **OQ4 — Is `videoScaleAndCropFactor` ever non-identity in this app?** Grep/assert; it is currently never touched (D2) and is a hard Bayer-RAW precondition.
5. **OQ5 — On a virtual device, are Bayer formats offered at all?** Enumerate `availableRawPhotoPixelFormatTypes` with `.builtInTripleCamera` as the input. Determines whether any multi-camera RAW mode is even possible (D3).
6. **OQ6 — What is the exact GDC-induced FOV delta** between preview at zoom 1.0 and a RAW capture, per device? Measure by capturing a chart at zoom 1.0 and comparing `activeFormat.geometricDistortionCorrectedVideoFieldOfView` with the DNG extent (D7/D21).
7. **OQ7 — Which `CIRAWFilter` defaults differ on device?** Re-run the defaults dump on an iPhone for the same fixture; expect `boostShadowAmount`, `luminanceNoiseReductionAmount`, `sharpnessAmount`, `detailAmount`, `contrastAmount`, `baselineExposure`, and `supportedDecoderVersions` to be image/decoder-dependent (the header says so explicitly).
8. **OQ8 — What does `CIRAWFilter` do with a *real Bayer CFA* DNG?** All experiments here used a LinearRaw/ProRAW file. Behaviour of `isLensCorrectionSupported`, `luminanceNoiseReductionAmount`, and `decoderVersion` on a CFA DNG may differ; the "zero recipe" may not even be needed in the same way. This is the single biggest gap in the empirical work.
9. **OQ9 — Can a `CIColorKernel` (Metal source) used as `linearSpaceFilter` act as an output tap?** If yes, there is a legal-ish path to Apple's linear intermediate (D11). Prototype and measure before designing around it.
10. **OQ10 — Photos behaviour for a `.photo`-render + `.alternatePhoto`-DNG pair on iOS 26.5.** Save both ways, check what Photos shows, what the thumbnail shows, and what `PHImageManager` `.current` returns (D17). Then widen `isDNGResource` accordingly.
11. **OQ11 — Is `CIRAWFilter.previewImage` present on Bayer DNGs?** Measured non-nil on the ProRAW fixture; useful only if it also exists for CFA files (and remember: it is Apple's rendering).
12. **OQ12 — ProRes RAW reachability.** Which iPhones expose an `AVCaptureDeviceFormat` that supports ProRes RAW in `availableVideoCodecTypes` today (the news says iPhone 17 Pro / iOS 26; the SDK does not say). If more than one device qualifies, a "RAW video" mode is a legitimate future product line — and it is the strongest external validation of the take-raw-and-develop-it-yourself architecture.

---

## Sources

**Local SDK (authoritative; `/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk`)**
- `System/Library/Frameworks/AVFoundation.framework/Headers/AVCapturePhotoOutput.h` — RAW capture rules (L80–96), ProRAW/Bayer format docs (L180–232), `maxPhotoQualityPrioritization` (L344), fast-capture (L356–370), deferred delivery (L376–392), still-image stabilisation (L398–420), virtual-device fusion & constituent delivery (L422–480), **camera-calibration-data preconditions (L484)**, `maxPhotoDimensions` + the 24MP/deferred note (L536–547, L114, L545), live photo (L627–646), content-aware DC (L671–685), ZSL/responsive capture (L691–722), `captureReadiness` (L740–757), constant color (L775–790), **sensor-orientation compensation never applies to RAW (L804–813)**, delegate protocol (L976–1069), `AVCapturePhotoSettings` (L1192–1700) incl. `autoStillImageStabilizationEnabled` default for Bayer (L1390), `autoVirtualDeviceFusionEnabled` (L1402), `maxPhotoDimensions` default-to-smallest (L1454), `photoQualityPrioritization` default `.balanced` (L1382), `autoContentAwareDistortionCorrectionEnabled` default NO (L1648), `metadata` base-set override (L1548), `rawEmbeddedThumbnailPhotoFormat` (L1638), `AVCaptureResolvedPhotoSettings` (L1788–1970), `AVCapturePhoto.pixelBuffer` Bayer/ProRAW fourccs (L2013).
- `…/AVCaptureDevice.h` — `deviceType` constants incl. virtual vs physical (L493–574), virtual-device primary-constituent rule (L715, L765), `exposureMode`/`setExposureModeCustom` + `.balanced` override warning (L1379, L1526), `globalToneMappingEnabled` (L1598–1618), `lowLightBoost*` (L1882–1907), `videoHDREnabled` / EDR definition (L2149–2163), `AVCaptureColorSpace_AppleLog/2` + `activeColorSpace` (L2176–2192), **GDC never applied to RAW (L2267)** + ProRes-RAW GDC behaviour (L2279–2286), `centerStage*` (L2340–2401), `highPhotoQualitySupported` (L3372–3375), format HDR/stabilisation/center-stage support (L3336–3612).
- `…/AVCaptureSession.h` — `preferredVideoStabilizationMode` + ProRes RAW stabilisation metadata (L1225–1252), **`videoRotationAngle = 0` for ProRes RAW buffers (L1110)**, Apple Log photo-capture prohibition (`AVCapturePhotoOutput.h` L116).
- `…/AVCaptureVideoDataOutput.h` — ProRes RAW: locked-WB precondition (L196), `deliversPreviewSizedOutputBuffers` → 4:2:2 proxy (L264), iOS 26 `preservesDynamicHDRMetadata`.
- `…/AVVideoSettings.h` — `AVVideoCodecTypeAppleProResRAW` (`aprn`) / `…RAWHQ` (`aprh`), iOS 26 (L53–54).
- `…/AVMetadataFormat.h` L187–190, `…/AVMetadataIdentifiers.h` L173–176 — ProRes RAW raw-WB-factor and colour-matrix metadata.
- `…/AVCaptureSessionPreset.h` L24–31 — `.photo` preset.
- `…/AVCaptureVideoPreviewLayer.h` — full public surface (L33–265), `deferredStartSupported` (L265).
- `…/CoreImage.framework/Headers/CIRAWFilter.h` — every property and its documented default.
- `…/CoreImage.framework/Headers/CIRAWFilter_Deprecated.h` — the pre-iOS-15 key set (confirms `kCIInputBaselineExposureKey` *"A value of 0 indicates no baseline exposure, i.e. linear response. **Default varies from with camera settings**"* — i.e. 0 was never the neutral value).

**Adobe DNG Specification 1.4 (September 2012)** — `https://www.kronometric.org/phot/processing/DNG/dng_spec_1.4.0.0.pdf`: PhotometricInterpretation 32803 = CFA / 34892 = LinearRaw, *"It can also be used for CFA data that has already been de-mosaiced"*; CFA requires `CFARepeatPatternDim` + `CFAPattern`; `LinearizationTable` (50712/0xC618) *"maps stored values into linear values … storing the raw data in a non-linear, more visually uniform space"*; `WhiteLevel` default `(2**BitsPerSample)-1`; `NoiseReductionApplied`, `BaselineSharpness`, `ProfileToneCurve`, `AsShotProfileName` are standard tags.

**Apple documentation**
- Capturing photos in RAW and Apple ProRAW formats — `https://developer.apple.com/documentation/avfoundation/capturing-photos-in-raw-and-apple-proraw-formats`
- `AVCapturePhotoOutput`, `AVCapturePhotoSettings`, `maxPhotoQualityPrioritization`, `maxPhotoDimensions`, `isGlobalToneMappingEnabled`, `isVideoHDREnabled`, `CIRAWFilter` and all its properties, `PHAssetCreationRequest`, `PHAssetResourceType.alternatePhoto`, `DNG Image Properties` — `https://developer.apple.com/...`
- WWDC26 session 304, *Implement high resolution photo capture* — `https://developer.apple.com/videos/play/wwdc2026/304/` (digest: `https://wwdc.ai/2026/304`, `https://github.com/ivan-magda/wwdc26-notes/blob/main/sessions/304-implement-high-resolution-photo/digest.md`)
- Apple announces Final Cut Camera 2.0 (ProRes RAW, iPhone 17 Pro) — `https://www.apple.com/newsroom/2025/09/apple-announces-final-cut-camera-2-0/`
- Apple ProRes RAW support article — `https://support.apple.com/en-us/118584`
- About Apple ProRAW — `https://support.apple.com/en-us/119916`

**Third-party (vendor) documentation**
- Halide/Lux, *The Process Zero Manual* — `https://www.lux.camera/process-zero-manual/` (48 MP limitation, single exposure, raw+render pairing, Image Lab, Photos mismatch)
- Halide/Lux, *Introducing Process Zero* — `https://www.lux.camera/introducing-process-zero-for-iphone/`
- Bayer Cam, *Understanding Bayer RAW* — `https://bayercam.com/understanding-bayer-raw` (12-bit, `WhiteLevel 4095`, ProRAW is processed/fused/semantic); *App Fundamentals* — `https://bayercam.com/app-fundamentals`
- LibreCam — `https://librecam.app/` (Bayer DNG + ISP-developed HEIF architecture)
- Adobe Research, *Project Indigo* — `https://research.adobe.com/articles/indigo/indigo.html` (32-frame merge, pre-demosaic DNG, "not zero-process but a more natural look")
- ProCamera RAW capture — `https://www.procamera-app.com/en/raw-photos-ios/`
- Digital Negative (Adobe-certified DNG writer) — `https://frameandfocal.com/post-processing/digital-negative-app-lets-you-shoot-raw-photos-with-your-iphone`
- MacRumors / dpreview / Petapixel coverage of Process Zero, incl. the DNG-is-not-Linear-DNG confirmation — `https://www.dpreview.com/forums/threads/halide-can-now-strip-away-almost-all-the-iphones-processing.4842291/`, `https://www.dpreview.com/news/5101705770/halide-process-zero-ai-computational-photograpy-phones-raw/`

**Libraries**
- LibRaw — `https://www.libraw.org/docs`
- RawSpeed — `https://github.com/darktable-org/rawspeed`
- Adobe DNG SDK 1.7 — `https://helpx.adobe.com/security/products/dng-sdk.html`, `https://helpx.adobe.com/camera-raw/desktop/dng-and-file-formats/digital-negative.html`
- colour-hdri DNG colour model — `https://colour-hdri.readthedocs.io/en/develop/_modules/colour_hdri/models/dng.html`
- `adwirth/CamProc` (Metal debayer from `AVCapturePhotoOutput` pixel buffers) — `https://github.com/adwirth/CamProc`
- `JonahZeng/dngparser` (TIFF/DNG parser + SOF3 decoder for Apple ProRAW tiles) — `https://github.com/JonahZeng/dngparser`

**Repo evidence (read-only)**
- `pikicam/Features/Camera/CaptureService.swift:117,147,273,517–530,536–539,620–646,652–679`
- `pikicam/Features/Camera/PhotoCapture.swift:82–135`
- `pikicam/Features/Camera/PreviewView.swift:9–16,63`, `pikicam/Features/Camera/CameraPreview.swift:20–70`
- `pikicam/Features/Develop/CIRAWZeroProcessor.swift:33–45,57–80,90–105`
- `pikicam/Features/Develop/DevelopService.swift:23,44–50,77`
- `pikicam/Core/Storage/PhotoLibraryManager.swift:217,368–390,676–690,894`
- `pikicamTests/PikicamPipelineTests.swift:409–410,482–565` (fixture loader; the recipe-coverage assertions that encode the `highlightRecoveryEnabled` omission)
- `pikicamTests/Fixtures/IMG_1361.DNG` (analysed read-only)
