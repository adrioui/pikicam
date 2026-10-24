# 06 — Adjudication: settling the contradictions between research reports 01 / 02 / 03

**Repo:** `/Users/adrifadilah/Desktop/pikicam` (branch `main`, working tree untouched)
**Date:** 2026-10-03
**Method:** byte-level TIFF/DNG IFD parse of the repo's own fixture; compiled-and-run probes on the **iOS 26.5 simulator** (iPhone 17 Pro, `BB29A4C9-…`) **and macOS 26.3.1**; direct reads of the shipping `iPhoneOS26.5.sdk` headers; Apple documentation + the WWDC26-304 transcript.
**Outputs:** every probe, binary and raw log lives in `/tmp/pikicam-adjudicate/` (nothing was written into the repo except this file). A copy of the fixture was made at `/tmp/pikicam-adjudicate/IMG_1361.DNG` (sha256 `e91e77a4533ed7cce551d83330676ea5c47dd5e55fb38adda7819366afdbdfc2`, 29 195 592 B) before any read.

**Status vocabulary:** `MEASURED` = I ran it here; `HEADER` = normative SDK text; `SPEC` = Adobe DNG Specification 1.4; `SOURCED` = external doc; `UNVERIFIED` = cannot be settled without hardware.

---

## Summary — top 10 findings

| # | Sev | Verdict | Finding |
|---|-----|---------|---------|
| 1 | **P0** | **03 right, both others incomplete** | The develop pipeline really is a total no-op — but **not** because of the simulator. `CIRAWFilter(imageData:)` does not call *any* `CIRAWFilter` initializer: Swift resolves it to the **deprecated `+[CIFilter filterWithImageData:options:]` category at `CIRAWFilter_Deprecated.h:28`**, returning a `CIRAWFilterImpl` whose isa chain is `CIRAWFilterImpl → CIFilter → NSObject` (it is **not** a `CIRAWFilter` at all). Reproduced identically on **iOS 26.5 simulator and macOS** → it is a compile-time overload-resolution accident that will bite on device too. |
| 2 | **P0** | **01+02 right, 03 wrong** | The fixture **does** contain `ColorMatrix1` (0xC621), `ColorMatrix2` (0xC622), `CalibrationIlluminant1/2` (0xC65A/0xC65B), `WhiteLevel` (0xC61D = 65535,65535,65535) and `BaselineExposure` (0xC62A = −0.30221677), all in **IFD0**. 03's byte-scan missed IFD0 entirely and mis-labelled two tags (`0xC61D` is *WhiteLevel*, not *AsShotNeutral*; `0xC62A` is *BaselineExposure*, not *ShadowScale*). |
| 3 | **P0** | **02 right, 01 and 03 wrong** | `highlightRecoveryEnabled` **is** settable and does **not** change the picture: on Apple defaults only **344–447 of 762 048 pixels differ (0.045–0.059 %)**, max channel delta **2–5/255**. 02's "p99.9 208→189" and 03's "Apple highlight recovery is applied to every frame" were an artefact of 02 confounding highlight-recovery with the `baselineExposure` change. |
| 4 | **P0** | **all three partly wrong; new fact** | You **can** get above-1.0 (scene-linear-with-headroom) data out of `CIRAWFilter` — via `extendedDynamicRangeAmount`. MEASURED, rendering into a `64RGBAHalf` + `extendedLinearSRGB` buffer: EDR 0 → max **1.0137** (6 px > 1.0), EDR 1 → **1.832** (0.148 %), EDR 2 → **2.650** (0.282 %). 02's "EDR is not a linearisation lever, max stays 0.571/0.579/0.586" is **refuted**. What remains true is that the `CIImage`'s `colorSpace` tag is always `kCGColorSpaceDisplayP3` — the tag lies, the pixels do not. |
| 5 | **P0** | **02 right on 2 of 3; 03 wrong** | `linearSpaceFilter` **does fire** on iOS 26.5 (MEASURED, −1 EV ≈ halves the linear signal) and its input is **demosaiced 3-channel linear RGB at full native size with an untagged colour space** (`comps=3`, `name=nil`). But: a `CIFilter` **subclass** works *only if it is KVC-compliant for `inputImage`*, only *built-in filter graphs* survive, and **any `CIColorKernel`/`CIKernel` you put inside it either makes `CIRAWFilter.outputImage` return `nil`, or is silently discarded.** 03's target architecture (Stage 3 = custom kernels in `linearSpaceFilter`) **does not work as described**. |
| 6 | **P0** | **02 right, 01 and 03 wrong** | `AVCapturePhotoSettings(rawPixelFormatType:)` returns `photoQualityPrioritization == .speed` (rawValue **1**) **at construction**, on iOS 26.5. Setting `.speed` explicitly is **accepted**; only `.quality` throws `NSInvalidArgumentException "Unsupported when capturing RAW"`. 01 F3 and the repo's own comment (`CaptureService.swift:537-539`) are wrong that the default is `.balanced`. |
| 7 | **P1** | **documented-fact vs vendor-claim separated** | **>12 MP Bayer RAW is impossible by Apple's own documented rules**, independent of any vendor claim: Bayer RAW mandates `.speed` (`AVCapturePhotoOutput.h:85`), 48 MP requires `balanced`/`quality`, and 18/24 MP are *multi-frame fused* and `quality`-only, plus 24 MP is deferred-delivery-only (`:114`, `:545`) — all per WWDC26-304. Halide's "we do not get 48 raw sensor data from iOS" is a **vendor statement consistent with, but not the proof**. |
| 8 | **P1** | **reconcilable, not a contradiction** | C7: the SDK is normative that iOS Bayer **photo** RAW arrives as `kCVPixelFormatType_14Bayer_*` = *"Bayer 14-bit Little-Endian, **packed in 16-bits**"* (`CVPixelBuffer.h:103-106`). The "12-bit" claim is about **BitsPerSample inside the DNG**, and the "WhiteLevel 4095 ⇒ 12-bit" heuristic is **wrong on Apple's own files** (this fixture is `BitsPerSample=12` with `WhiteLevel=65535`). Also: the fixture is **ProRAW/LinearRaw, not Bayer** — it is *not* evidence about Bayer depth at all. |
| 9 | **P1** | **03 right about one, wrong about another** | `identifierHint` value is **irrelevant**: `nil`, `""`, `"com.adobe.raw-image"`, `UTType.rawImage.identifier` and even a deliberately wrong `"public.jpeg"` all produce a real `CIRAWFilter` with **byte-identical** render statistics on both platforms. But 03's `CIFilter.customImage()`/`CIImageProcessorKernel(source:)` API survey is wrong on one point: **`CIImageProcessorKernel(source:)` does not exist** — you must subclass it (`CIImageProcessor.h:113-117`). |
| 10 | **P1** | **new, not in any report** | `CIRAWFilter.supportedCameraModels` has 934–939 entries but **does not contain `"iPhone13,3 back camera"`** — and the filter renders that very file perfectly. 03's P1-14 recommendation to "gate on `supportedCameraModels`" would **reject a valid iPhone 12 Pro DNG**. |

---

## Detailed findings

### C1 — Fixture tag dump · **P0** · **VERDICT: 01 and 02 are right; 03 is wrong**

**Evidence (byte-level, authoritative).** `/tmp/pikicam-adjudicate/dngdump.py` parses IFD0 + all chained IFDs + `SubIFDs` + `ExifIFD` + `GPSIFD` recursively. Reproduce:

```bash
cd /tmp/pikicam-adjudicate
cp /Users/adrifadilah/Desktop/pikicam/pikicamTests/Fixtures/IMG_1361.DNG .
python3 dngdump.py IMG_1361.DNG | tee dngdump.txt      # full dump + whole-file entry scan
python3 absent.py                                        # presence/absence proof + LUT analysis
```

The file is big-endian TIFF (`MM\0*`, offset 18), **89 distinct tags over 106 IFD entries across 5 IFDs**.

**Complete, correctly-labelled dump** (full version: `/tmp/pikicam-adjudicate/dngdump_clean.txt`):

```
=== IFD IFD0 @offset 18 (endian >), 31 entries, next=none ===
 0x00FE NewSubfileType               LONG   (4) count=1    = 1
 0x0100 ImageWidth                   LONG   (4) count=1    = 4032
 0x0101 ImageLength                  LONG   (4) count=1    = 3024
 0x0102 BitsPerSample                SHORT  (3) count=3    = [8, 8, 8]
 0x0103 Compression                  SHORT  (3) count=1    = 7  (JPEG/new-style)
 0x0106 PhotometricInterpretation    SHORT  (3) count=1    = 6  (YCbCr)
 0x010F Make                         ASCII  (2) count=6    = "Apple"
 0x0110 Model                        ASCII  (2) count=14   = "iPhone 12 Pro"
 0x0111 StripOffsets                 LONG   (4) count=1    = 64104
 0x0112 Orientation                  SHORT  (3) count=1    = 6
 0x0115 SamplesPerPixel              SHORT  (3) count=1    = 3
 0x0116 RowsPerStrip                 LONG   (4) count=1    = 3024
 0x0117 StripByteCounts              LONG   (4) count=1    = 5364435
 0x0131 Software                     ASCII  (2) count=5    = "14.3"
 0x0132 DateTime                     ASCII  (2) count=20   = "2020:12:29 14:24:45"
 0x014A SubIFDs                      LONG   (4) count=2    = [4906, 63282]
  === IFD IFD0/SubIFD[0] @offset 4906  (18 entries) — the RAW plane ===
   0x00FE NewSubfileType             LONG  (4) count=1     = 0
   0x0100 ImageWidth                LONG  (4) count=1     = 4032
   0x0101 ImageLength               LONG  (4) count=1     = 3024
   0x0102 BitsPerSample             SHORT (3) count=3     = [12, 12, 12]
   0x0103 Compression               SHORT (3) count=1     = 7
   0x0106 PhotometricInterpretation SHORT (3) count=1     = 34892  (LinearRaw)
   0x0115 SamplesPerPixel           SHORT (3) count=1     = 3
   0x011C PlanarConfiguration       SHORT (3) count=1     = 1
   0x0142 TileWidth                 LONG  (4) count=1     = 504
   0x0143 TileLength                LONG  (4) count=1     = 378
   0x0144 TileOffsets               LONG  (4) count=64    = [... 28825851 ...]
   0x0145 TileByteCounts            LONG  (4) count=64    = [... 369741 ...]
   0xC618 LinearizationTable        SHORT (3) count=4096  = [0,40,80,... 65535]   (monotonic)
   0xC61A BlackLevel                SHORT (3) count=3     = [0, 0, 0]
   0xC61D WhiteLevel                SHORT (3) count=3     = [65535, 65535, 65535]
   0xC761 NoiseProfile              DOUBLE(12) count=2    = [3e-05, 3e-08]
   0xC7A6 <APPLE PRIVATE>           LONG  (4) count=1     = 1
   0xCD2D <APPLE PRIVATE>           UNDEF (7) count=49408 = <49408-byte Apple blob>
  === IFD IFD0/SubIFD[1] @offset 63282 (12 entries) — embedded auxiliary matte ===
   0x00FE NewSubfileType            LONG  (4) count=1     = 65540
   0x0100 ImageWidth                LONG  (4) count=1     = 2016
   0x0101 ImageLength               LONG  (4) count=1     = 1512
   0x0102 BitsPerSample             SHORT (3) count=1     = 8
   0x0103 Compression               SHORT (3) count=1     = 34892
   0x0106 PhotometricInterpretation SHORT (3) count=1     = 52527
   0x0111 StripOffsets              LONG  (4) count=1     = 5428540
   0x0115 SamplesPerPixel           SHORT (3) count=1     = 1
   0x0116 RowsPerStrip              LONG  (4) count=1     = 1512
   0x0117 StripByteCounts           LONG  (4) count=1     = 146585
   0x02BC XMP                       BYTE  (1) count=623    = "<x:xmpmeta…"
   0xCD2E <APPLE PRIVATE>           ASCII (2) count=46    = "urn:com:apple:photo:2020:aux:semanticskymatte"
  === IFD IFD0/ExifIFD @offset 2770 (31 entries) — key ones ===
   0x829A ExposureTime   RATIONAL = 0.0001799856011519   (≈1/5556 s)
   0x829D FNumber       RATIONAL = 1.6
   0x8827 ISOSpeedRatings  SHORT = 32
   0x920A FocalLength   RATIONAL = 4.2
   0x927C MakerNote     UNDEFINED count=1268
   0xA002 PixelXDimension LONG = 4032 ; 0xA003 PixelYDimension LONG = 3024
   0xA405 FocalLengthIn35mmFilm SHORT = 26
   0xA432 LensSpecification RATIONAL = [1.54, 6.0, 1.6, 2.4]
   0xA434 LensModel     ASCII = "iPhone 12 Pro back triple camera 4.2mm f/1.6"
  === IFD IFD0/GPSIFD @offset 4630 (14 entries) — standard GPS tags, uninteresting ===
  0xC612 DNGVersion             BYTE  (1) count=4   = [1, 4, 0, 0]
  0xC613 DNGBackwardVersion     BYTE  (1) count=4   = [1, 3, 0, 0]
  0xC614 UniqueCameraModel      ASCII (2) count=23  = "iPhone13,3 back camera"
  0xC621 ColorMatrix1           SRATIONAL(10) count=9 = [1.2271626, -0.5454787, -0.2612877,
                                                          -0.4546857, 1.5177797, -0.0426504,
                                                          -0.0409380, 0.1636143, 0.5913458]
  0xC622 ColorMatrix2           SRATIONAL(10) count=9 = [0.9145434, -0.3222275, -0.1262249,
                                                          -0.4288680, 1.3095410,  0.0946757,
                                                          -0.1062919, 0.2350455, 0.4307328]
  0xC628 AsShotNeutral          RATIONAL (5) count=3 = [0.4489751, 1.0, 0.5408689]
  0xC62A BaselineExposure       SRATIONAL(10) count=1 = -0.3022167682647705
  0xC62C BaselineSharpness      RATIONAL (5) count=1 = 1.5
  0xC65A CalibrationIlluminant1 SHORT (3) count=1   = 17   (Standard light A)
  0xC65B CalibrationIlluminant2 SHORT (3) count=1   = 21   (D65)
  0xC6F7 <APPLE PRIVATE>        RATIONAL (5) count=1 = 0.949999988079071
  0xC6F8 <APPLE PRIVATE>        ASCII (2) count=29    = "Apple Embedded Color Profile"
  0xC6FC <APPLE PRIVATE>        FLOAT  (11) count=514  = [0,0,0.00390625, 1.8897e-05, …, 1.0]  (257 x/y pairs = a tone curve in a PRIVATE tag)
```

**Which public colour-calibration tags really exist** (authoritative: parsed IFD entries, not a byte grep):

| Tag | Name (DNG 1.4) | Present? |
|---|---|---|
| 0xC612 / 0xC613 / 0xC614 | DNGVersion / DNGBackwardVersion / UniqueCameraModel | ✅ |
| 0xC618 | LinearizationTable (4096) | ✅ (raw SubIFD) |
| 0xC61A | BlackLevel | ✅ `[0,0,0]` |
| **0xC61D** | **WhiteLevel** | ✅ `[65535,65535,65535]` |
| 0xC621 / 0xC622 | ColorMatrix1 / ColorMatrix2 | ✅ both |
| **0xC628** | **AsShotNeutral** | ✅ `(0.44898, 1, 0.54087)` |
| **0xC62A** | **BaselineExposure** | ✅ `−0.30221677` |
| 0xC62C | BaselineSharpness | ✅ `1.5` |
| 0xC65A / 0xC65B | CalibrationIlluminant1 / 2 | ✅ `17 / 21` |
| 0xC761 | NoiseProfile | ✅ `(3e-05, 3e-08)` |
| 0xC616 CFAPlaneColor, 0xC617 CFALayout, 0x828D CFARepeatPatternDim, 0x828E CFAPattern | CFA geometry | ❌ absent (expected: LinearRaw) |
| 0xC619 BlackLevelRepeatDim, 0xC61B/1C BlackLevelDeltaH/V, 0xC61E DefaultScale, 0xC61F/20 DefaultCropOrigin/Size | | ❌ |
| 0xC623/0xC624 CameraCalibration1/2, 0xC625/26 ReductionMatrix1/2, 0xC7D1/0xC7D2 ForwardMatrix1/2, 0xC629 AsShotWhiteXY, 0xC627 AnalogBalance, 0xC62D BayerGreenSplit, 0xC62E LinearResponseLimit, 0xC62B BaselineNoise, 0xC630 LensInfo, 0xC633 ShadowScale, 0xC68D ActiveArea, 0xC68E MaskedAreas, 0xC68F AsShotICCProfile, 0xC6A2 NoiseReductionApplied, 0xC6A5 ProfileToneCurve, 0xC680 OriginalRawFileName, 0xC634 DNGPrivateData | | ❌ **all absent** |

**Normative spec citations** (from the extracted Adobe DNG Specification 1.4, `/tmp/pikicam-adjudicate/dng_spec_1_4.txt`, PDF from `https://www.kronometric.org/phot/processing/DNG/dng_spec_1.4.0.0.pdf`):
- `WhiteLevel` — *"Tag 50717 (C61D.H)"*, Default *(2^BitsPerSample)−1*.
- `ColorMatrix1` — *"Tag 50721 (C621.H) … Type SRATIONAL, Count ColorPlanes * 3"* → count 9 for 3 planes, exactly what the fixture has.
- `ColorMatrix2` — *"Tag 50722 (C622.H)"*.
- `CalibrationIlluminant1/2` — *"Tag 50778 (C65A.H)"* / *"50779 (C65B.H)"*.
- `AsShotNeutral` — *"Tag 50728 (C628.H) … Usage IFD 0"*; *"The inclusion of this tag precludes the inclusion of the AsShotWhiteXY tag."*
- `BaselineExposure` — *"Tag 50730 (C62A.H) … Usage IFD 0"*; *"specifies by how much (in EV units) to move the zero point."*
- `ShadowScale` — *"Tag 50739 (C633.H) … Default 1.0"*, used by Camera Raw for the Shadows slider. **Absent here.**

**Verdict on each disputed label**

| 03 claim | Verdict |
|---|---|
| "NO `ColorMatrix1/2` … anywhere in its TIFF structure" | **FALSE** — both present in IFD0 as SRATIONAL×9. |
| "NO `WhiteLevel`" | **FALSE** — 0xC61D present, `[65535,65535,65535]`. |
| "NO `BaselineExposure`" | **FALSE** — 0xC62A present, `−0.30221676826…`. |
| `0xC62A` is `ShadowScale` | **FALSE** — 0xC62A is `BaselineExposure`; `ShadowScale` is 0xC633 and absent. |
| `0xC61D` is `AsShotNeutral = (65535,65535,65535)` | **FALSE** — 0xC61D is `WhiteLevel`. (03 had the *value* right and the *name* wrong.) |
| `0xC6FC` is `ProfileToneCurve` | **FALSE** — `ProfileToneCurve` is 0xC6A5 and absent; 0xC6FC is an Apple-private tag that happens to hold 257 (x,y) pairs. |
| `0xC761` is an Apple private tag (01 also said this) | **FALSE** — 0xC761 is the public `NoiseProfile` (50769+92 = 0xC761). 02 got this right. |
| "byte-scan of all five IFDs plus a whole-file tag sweep" | **SUSPECT** — a correct sweep (mine) finds all 13 DNG tags above. 03's scan evidently never read IFD0's entry array. |

**How 03's `{DNG}` numbers and mine coexist.** ImageIO's `{DNG}` dictionary (via `CIRAWFilter.properties`, MEASURED both platforms) contains 16 keys including `NoiseReductionApplied = 0.95` and `DefaultBlackRender = 1`, **neither of which exists in any IFD**. They come out of Apple's private `0xCD2D` blob. So 02's D13 list is right about the *dictionary*, and 03's list is right about the *TIFF*, and both are wrong about each other. The dictionary is the useful one for a renderer; the IFD is the auditable one.

**Also confirmed:** the fixture is **Apple ProRAW / "Linear DNG"**, not Bayer — `PhotometricInterpretation = 34892` (LinearRaw), `SamplesPerPixel = 3` (3× the pixel count), `BitsPerSample = 12`, tiled 64×(504×378), no CFA tags, plus an embedded `urn:com:apple:photo:2020:aux:semanticskymatte`. 01 F12 and 02 D1 are right; this is *not* the payload the app captures.

**Recommended fix direction.** Treat `CIRAWFilter.properties["{DNG}"]` as the runtime metadata source and a small hand-written IFD parser as the *auditable* source; write a test that asserts the presence of `ColorMatrix1/2`, `CalibrationIlluminant1/2`, `AsShotNeutral`, `BaselineExposure`, `WhiteLevel`, `BlackLevel`, `LinearizationTable` by **tag id**, not by name, so a label error cannot pass.

---

### C2 — `CIRAWFilter` initializers · **P0** · **VERDICT: 03 right; the root cause is different (and worse) than 03 says; 02's measurements are valid but were taken with a different initializer**

**The root cause — a compile-time overload, not a runtime limitation.**

```bash
cd /tmp/pikicam-adjudicate
cat > t1.swift <<'EOF'
import Foundation; import CoreImage
func f(_ d: Data) { let a = CIRAWFilter(imageData: d); print(a as Any) }
EOF
xcrun --sdk iphonesimulator swiftc -target arm64-apple-ios26.5-simulator -typecheck t1.swift   # compiles, exit 0
xcrun --sdk iphonesimulator swiftc -target arm64-apple-ios26.5-simulator -typecheck -dump-ast t1.swift \
  | grep -o 'decl="[^"]*imageData[^"]*"'
```

AST output (single occurrence), i.e. the declaration `CIRAWFilter(imageData:)` binds to:

```
decl="CoreImage.(file).CIFilter extension.init(imageData:options:)
      @.../CoreImage.framework/Headers/CIRAWFilter_Deprecated.h:28:1"
```

`CIRAWFilter_Deprecated.h:28` is the **pre-iOS-12 category on `CIFilter`**:

```objc
@interface CIFilter (CIRAWFilter)
+ (CIFilter *)filterWithImageData:(NSData *)data options:(NSDictionary<CIRAWFilterOption, id> *)options
   API_DEPRECATED("Use new CIRAWFilter class instead.", macos(10.5,…), ios(10.0,…));
```

It returns `CIFilter *` (not `instancetype`), so Swift happily lets you spell it `CIRAWFilter(imageData:)`, statically typing the result `CIRAWFilter?` — but the object is the legacy `CIRAWFilterImpl`, whose superclass is `CIFilter`, **not** `CIRAWFilter`. `CIRAWFilter.h` itself declares **only** `+filterWithImageURL:`, `+filterWithImageData:identifierHint:`, `+filterWithCVPixelBuffer:properties:` — there is no 1-argument `CIRAWFilter` initializer at all.

**Runtime matrix — MEASURED on both platforms, byte-identical:**

```bash
cd /tmp/pikicam-adjudicate
xcrun swiftc -O probe.swift -o probe_mac && ./probe_mac IMG_1361.DNG            # macOS 26.3.1
xcrun --sdk iphonesimulator swiftc -target arm64-apple-ios26.5-simulator -O probe.swift -o probe_ios
xcrun simctl spawn BB29A4C9-8EA3-4BB1-99CC-1A3ED2AF5C6B ./probe_ios IMG_1361.DNG   # iOS 26.5 sim
```

| Initializer | runtime class | isa chain | missing selectors (of 41 probed) | render (0.25 scale, P3, 8-bit) |
|---|---|---|---|---|
| **A** `CIRAWFilter(imageData:)` *(repo, `CIRAWZeroProcessor.swift:31`)* | **`CIRAWFilterImpl`** | `CIRAWFilterImpl → CIFilter → NSObject` | **34** — every `set*`, every getter, `orientation`, `scaleFactor`, `previewImage`, `semanticSegmentationSkyMatte`, `decoderVersion`, `linearSpaceFilter` | (renders via the legacy path; identical to Apple's defaults — see below) |
| B `CIRAWFilter(imageData:identifierHint: nil)` | `CIRAWFilter` | `CIRAWFilter → CIFilter → NSObject` | 3 — and all three are non-existent spellings in my probe list (`highlightRecoveryEnabled` vs `isHighlightRecoveryEnabled`, `inputImage`, `value`) ⇒ **every real setter present** | macOS `meanR=123.24 clip255=3 crush0=0` · iOS `meanR=121.29 clip255=129 crush0=194` |
| C `…identifierHint: ""` | `CIRAWFilter` | same | 3 (same) | **byte-identical to B** |
| D `…identifierHint: "com.adobe.raw-image"` | `CIRAWFilter` | same | 3 | **byte-identical to B** |
| E `…identifierHint: UTType.rawImage.identifier` | `CIRAWFilter` | same | 3 | **byte-identical to B** |
| F `…identifierHint: "public.jpeg"` *(deliberately wrong)* | `CIRAWFilter` | same | 3 | **byte-identical to B** |
| G `CIRAWFilter(imageURL:)` | `CIRAWFilter` | same | 3 | **byte-identical to B** |

- **iOS 26.5 simulator result: `UTType.rawImage.identifier` = `public.camera-raw-image`** (not `public.raw-image`). `UTType(filenameExtension:"dng")!` = `com.adobe.raw-image`. Same on macOS.
- **`identifierHint` value does not matter** — not nil, not empty, not the right UTI, not even a wrong UTI. Core Image sniffs the payload. (UNVERIFIED: whether the hint matters for an ambiguous/corrupt payload.)
- The **real** filter exposes **85 own-instance methods**; the legacy stub exposes **116**, including the whole legacy key API: `setInputEV:`, `setInputBaselineExposure:`, `setInputBoost:`, `setInputBoostShadowAmount:`, `setInputLocalToneMapAmount:`, `setInputLuminanceNoiseReductionAmount:`, `setInputColorNoiseReductionAmount:`, `setInputMoireAmount:`, `setInputNoiseReductionSharpnessAmount:`, `setInputDisableGamutMap:`, `setInputDisableHighlightRecovery:`, `setInputEnableEDRMode:`, `setInputLinearSpaceFilter:`, and the `defaultInput*` accessors.

**Two corrections to 03 and to `docs/prompt-next.md`.**

1. 03 says *"the simulator's `CIRAWFilterImpl` … does not implement `setBaselineExposure:`"* and that *"Phase 0 as written would burn a device cycle proving nothing."* The first half is right; the conclusion is wrong because the cause is **the overload resolution in our own source**, which is identical on device and simulator (both compile against the same header). One-line source fix, zero device cycles. 03's own later text reaches the right conclusion ("that diagnosis is wrong"); the top-level framing does not.
2. `docs/prompt-next.md` §0.1 (quoted by 03) prescribes *"set via the `input*` key path"*. **Refuted as a fix**: the `input*` key path is the *legacy* API of the stub class, and it cannot express most of the modern controls (`highlightRecoveryEnabled`, `decoderVersion`, `linearSpaceFilter`, `scaleFactor` are absent). Worse, the exception backtrace proves the modern engine *is* the legacy class:

```
*** Terminating app due to uncaught exception of 'NSUnknownKeyException', reason:
  '[<CIConstantColorGenerator …> setValue:forUndefinedKey:]: this class is not key value coding
   compliant for the key inputImage.'
  …
  5  CoreImage  -[CIFilter setValue:forKey:]
  6  CoreImage  -[CIRAWFilterImpl(Private) outputImage]
```

`CIRAWFilterImpl` is not a broken stub — it is the internal engine that `CIRAWFilter` wraps, and it is what pushes the linear image into your `linearSpaceFilter`.

**Why it matters.** The product's headline claim is false today on **every** platform, from a single line of source. `applyZeroRecipe`'s `responds(to:)` gate (`CIRAWZeroProcessor.swift:124`) converts a fatal API misuse into silent success.

**Recommended fix direction.** `CIRAWFilter(imageData: dngData, identifierHint: UTType.rawImage.identifier)` (any of B–G is equivalent; the hint is documentation). Then **delete the `responds(to:)` skip** — an unreachable control becomes a typed error, not a `return`. Add a build-time guard: a lint/test that fails if `CIRAWFilter(` is constructed without `identifierHint:`. Add `XCTAssertTrue(type(of: filter) == CIRAWFilter.self)` to the test suite — it catches this whole class of bug in one line.

---

### C3 — `highlightRecoveryEnabled` · **P0** · **VERDICT: it is settable (03 right); 02 and 03 are both wrong that it changes the picture**

**Evidence — MEASURED on both platforms, pixel-exact diffs (not percentiles):**

```bash
# in probe.swift, section "C3 - highlightRecoveryEnabled"; diffCount() compares full RGBA8 buffers
diffCount(bitmap(hrOn), bitmap(hrOff))
```

| Comparison | iOS 26.5 sim | macOS 26.3.1 |
|---|---|---|
| Apple defaults, HR **on** vs **off** | **344 / 762 048 px differ (0.0451 %)**, max channel delta **4**, mean delta 0.00048/255 | **447 px (0.0587 %)**, max delta **5**, mean 0.00062 |
| Zero recipe, HR on vs off | **272 px (0.0357 %)**, max delta **2**, mean 0.00036 | **289 px (0.0379 %)**, max delta **2**, mean 0.00039 |
| Read-back after `isHighlightRecoveryEnabled = false` | `false` ✅ | `false` ✅ |
| `isHighlightRecoverySupported` | `true` | `true` |

So:
- 03's core factual point is right — `NS_AVAILABLE(16_0, 19_0)` means *deprecated in iOS 19*, not *unavailable*; the property exists, compiles, is settable, and the repo's comment at `CIRAWZeroProcessor.swift:60-62` states a false belief. **Keep the recipe entry.**
- **02's and 03's impact claims are wrong.** 02 D10 wrote *"Apple's highlight recovery is still compressing highlights in B: p99.9 208→189"*. That comparison was `recipe` (baseline=0) vs `recipe + HR-off + **baselineExposure kept**` — **confounded**. Isolate HR alone and the difference is ≤ 0.06 % of pixels at ≤ 5/255. 03's *"Apple highlight reconstruction is applied to every frame"* is likewise false at any useful magnitude.
- Note the semantic: with `boostAmount = 0` there is almost nothing above ~1.0 for highlight recovery to reconstruct, so a near-zero effect is *expected*. Do **not** read this as "highlight recovery is harmless in general".

**Recommended fix direction.** Add `("highlightRecoveryEnabled", { $0.isHighlightRecoveryEnabled = false })` to the recipe (suppress the iOS-19 deprecation warning), correct the comment at `CIRAWZeroProcessor.swift:60-62`, and **do not** justify it with a pixel claim in the docs — justify it with "Apple's enhancement must not be on, even if its effect on this image is ≤ 0.06 % of pixels".

---

### C4 — `baselineExposure` · **P0** · **VERDICT: confirmed on both platforms — the real filter's default *is* the DNG tag**

| Measurement | iOS 26.5 sim | macOS 26.3.1 |
|---|---|---|
| fresh filter `baselineExposure` | **−0.30221677** | **−0.30221677** |
| DNG tag `0xC62A BaselineExposure` (SRATIONAL −324502784 / 1073741824) | −0.3022167682647705 | same |
| delta | **0.0** | **0.0** |

Pixel effect of forcing `0.0` (all else zeroed, HR off; render = full frame at 0.25 scale, Display P3, 8-bit):

| `baselineExposure` | iOS sim `meanR` | iOS `clip255` | macOS `meanR` | macOS `clip255` |
|---|---|---|---|---|
| **0.0** (repo recipe) | **102.56** | 11 | **102.91** | 9 |
| **−0.30221677** (DNG value) | **92.81** | 0 | **93.13** | 0 |
| **+0.5** | 120.64 | 4767 | 121.05 | 4644 |

Exact pixel diff: **761 798 / 762 048 px (99.9672 %)**, max channel delta 26 (iOS). So the recipe's `("baselineExposure", { $0.baselineExposure = 0.0 })` is a real, unconditional **≈ +0.30 EV brightening** of every develop. All three reports were right that this happens; the exact 0.30-stop figure is a *linear-domain* statement (display-referred ratio is only ≈ 1.105× because Apple's transfer function sits between).

Note also that 02's suggestion (`boostShadowAmount = 1.0` is the documented neutral, `0.0` is not) is confirmed against the header, and I additionally MEASURED that `boostShadowAmount` is **completely inert while `boostAmount == 0`** (identical linear stats for 0.0 / 0.5 / 1.0), while `shadowBias` is **not** inert (mean 0.19736 → 0.19696 at +0.5, one negative pixel).

**Recommended fix direction.** Delete `baselineExposure` from the recipe (leave it at the DNG value) *and* make exposure an explicit, visible, recorded develop control in our own stage. If the owner instead wants the recipe to stay literally "all zeros", it must at minimum be disclosed as "+0.302 EV" in the UI and in the recipe doc comment.

---

### C5 — `linearSpaceFilter` · **P0** · **VERDICT: 02 is right that it fires on real 3-channel linear RGB; 02 is wrong that `exposure` is equivalent; and a new hard fact kills 03's Stage-3 plan**

**C5.1 — it fires, on both platforms** (MEASURED; render stats identical in structure on iOS 26.5 sim and macOS):

| `linearSpaceFilter` | iOS 26.5 sim `meanR` | macOS `meanR` |
|---|---|---|
| none | 121.29 | 123.24 |
| `CIExposureAdjust` −1 EV | **78.41** | **80.28** |
| `CIExposureAdjust` −2 EV | 46.77 | 48.14 |
| `CIColorMatrix` R-only | (115.64, **0.75**, **0.10**) | (117.71, **0.77**, **0.10**) |
| `CIColorMatrix` B-only | (5.82, 5.82, **104.11**) | (6.08, 6.08, **105.51**) |
| `CIColorCube` identity 2³ | **all-zero (black)** | **all-zero (black)** |

- **Channel isolation works ⇒ the hook operates on demosaiced 3-channel RGB, not on a CFA mosaic.** 02 correct.
- `CIExposureCube`-as-LUT **destroys the image** (renders pure black) — new fact, not in any report.
- **02's "`filter.exposure = -1.0` is byte-identical to `linearSpaceFilter = CIExposureAdjust(-1EV)`" is REFUTED.** iOS: 87.37 vs 78.41; exact diff between the two renders: **761 318 px (99.9042 %) differ, mean 10.1/255**. macOS: 88.81 vs 80.28, 761 796 px. `exposure` is applied at a *different point* in Apple's chain. Do not treat them as interchangeable in the UI.

**C5.2 — what colour space / primaries is the input in, and can it exceed 1.0?**

Probe `LinearSubclassFilter` (a KVC-compliant `CIFilter` subclass) prints what Core Image hands it:

```
PROBE  linearSpaceFilter received: extent=(0.0, 0.0, 4032.0, 3024.0)
       colorSpace=other(name=nil comps=3)  class=CIImage
```

- **3 components, RGB, full `nativeSize`, and an untagged (`name == nil`) colour space** — not sRGB, not Display P3, not `extendedLinearSRGB` as a tag. Any colour operation you perform there is operating on an *unnamed* space; the only anchors available are the DNG's `ColorMatrix1/2` + `AsShotNeutral`.
- Whether the *values* are scene-linear: the constant-ladder test could not be run, because custom kernels inside the hook are discarded (below). What can be stated: with the zero recipe the **downstream** output peaks at 1.0137 (≈6 px of 762 k above 1.0) at EDR 0, and reaches 1.83 / 2.65 at EDR 1 / 2 (C6). So the pipeline *as a whole* is not clamped at 1.0, but a scene-linear intermediate with usable headroom cannot be *extracted* through `linearSpaceFilter`.

**C5.3 — can a `CIFilter` subclass with a `CIColorKernel` be used there? MEASURED answer: only in a very restricted form.**

| Variant (installed as `linearSpaceFilter`) | iOS 26.5 sim | macOS 26.3.1 |
|---|---|---|
| (a) subclass returns `inputImage` unchanged | ✅ identical to no-filter | ✅ identical |
| (b) subclass returns `input.applyingFilter("CIExposureAdjust", −1EV)` | ✅ **78.41 — exactly** the plain-filter result | ✅ 80.28 — exactly |
| (c) subclass applies `CIColorKernel` → constant `2.0` | ❌ **`CIRAWFilter.outputImage` == nil** | ❌ nil |
| (d) subclass applies `CIKernel` passthrough `sample(smp,c)` | ❌ **nil** | ❌ nil |
| (e) subclass applies `CIKernel` gain ×0.5 | ❌ **nil** | ❌ nil |
| (f) `CIColorKernel` const **2.0** → then `applyingFilter` | ⚠️ renders **identical to no-filter** | ⚠️ identical |
| (f2) `CIColorKernel` const **0.0** (would be BLACK) → then `applyingFilter` | ⚠️ **identical to no-filter** | ⚠️ identical |
| (f3) `CIColorKernel` const **64.0** (would be blown) → then `applyingFilter` | ⚠️ **identical to no-filter** | ⚠️ identical |
| (g) `CIKernel` passthrough → then `applyingFilter` | ⚠️ identical (expected — identity) | ⚠️ identical |

f2/f3 are decisive: a kernel that should paint the frame **black** and a kernel that should paint it **64× over** both render as the untouched original. **The kernel result is silently discarded.** The only graph shape that survives is *built-in `CIFilter`s*.

Two further hard prerequisites discovered:

1. **A bare `CIFilter` subclass is not KVC-compliant and crashes the process**:
   ```
   *** Terminating app due to uncaught exception of 'NSUnknownKeyException', reason:
     '[<probe_mac.LinearSubclassFilter …> setValue:forUndefinedKey:]: this class is not key value
      coding-compliant for the key inputImage.'
   ```
   The subclass **must** declare `@objc dynamic var inputImage: CIImage?`.
2. **Kernel syntax on this SDK.** `__constant sampler` no longer exists. MEASURED compile matrix:
   ```
   kernel vec4 f(__constant sampler s, vec2 c){…}   → FAIL "unknown type name '__constant'"
   kernel vec4 f(sampler s, vec2 c){…}             → CIColorKernel OK, but sample() NOT available
   kernel vec4 f(sampler s, vec2 c){…sample(s,c)…} → CIColorKernel FAIL
   kernel vec4 f(sampler s, vec2 c){…sample(s,c)…} → CIKernel OK   ← the general kernel is the sampler-capable one
   kernel vec4 f(CIImage i, vec2 c){…}             → FAIL "unknown type name 'CIImage'"
   kernel vec4 flat(sampler …){…}                  → FAIL: `flat` is a reserved Metal keyword
   ```
   And `CIImageProcessorKernel(source:)` **does not exist** (`error: argument passed to call that takes no arguments`) — you must subclass it (`CIImageProcessor.h:113-117`). **03's claim that it "exists (verified)" is false.**

**Recommended fix direction.** Do not plan the develop pipeline as "our kernels inside `linearSpaceFilter`" — that path is measured to be broken. The two honest architectures are (i) keep the hook as a chain of **built-in `CIFilter`s only** (`CIColorMatrix` for WB/matrix, `CIExposureAdjust` for EV, `CIToneCurve`/`CIColorCube` for a look, `CIHighlightShadowAdjust`, `CINoiseReduction`, `CISharpenLuminance`) and be explicit in the docs that these are Apple's operators on Apple's pipeline, or (ii) take the mosaic yourself from `AVCapturePhoto.pixelBuffer` (02 D12) and own every operator. If (i), the implementation prompt must state the two hard constraints discovered here (KVC-compliant `inputImage`; built-in filters only) or the code will silently render Apple's untouched output.

---

### C6 — `CIRAWFilter` output · **P0** · **VERDICT: the *tag* is always Display P3 (02 right); but a scene-linear-with-headroom render IS obtainable, and 02's "EDR is not a linearisation lever" is refuted**

```bash
cd /tmp/pikicam-adjudicate
xcrun swiftc -O probe7.swift -o probe7_mac && ./probe7_mac IMG_1361.DNG
xcrun --sdk iphonesimulator swiftc -target arm64-apple-ios26.5-simulator -O probe7.swift -o probe7_ios
xcrun simctl spawn BB29A4C9-… ./probe7_ios IMG_1361.DNG
```

Recipe = repo's 15 entries + `highlightRecoveryEnabled = false`; render target = `CVPixelBuffer` (`kCVPixelFormatType_64RGBAHalf`) + `kCGColorSpaceExtendedLinearSRGB`, full frame at 0.25 scale (756×1008); half-floats decoded in software.

| Configuration | `outputImage.colorSpace` tag | iOS 26.5 sim LINEAR max | macOS 26.3.1 LINEAR max | pixels > 1.0 (iOS) |
|---|---|---|---|---|
| **EDR = 0** | `kCGColorSpaceDisplayP3` | **1.01758** | **1.01367** | **5 (0.0007 %)** |
| **EDR = 1** | `kCGColorSpaceDisplayP3` | **1.85254** | **1.83203** | **1155 (0.1516 %)** |
| **EDR = 2** | `kCGColorSpaceDisplayP3` | **2.68750** | **2.65039** | **2162 (0.2837 %)** |
| EDR 0 → `extendedLinearDisplayP3` target | (same tag) | 1.01562 | 1.01074 | 5 (0.0007 %) |
| EDR 0 → `extendedSRGB` target | (same tag) | 1.00684 | 1.00586 | 5 (0.0007 %) |
| *control*: `previewImage` → extendedLinear | `Display P3` | 1.04688 | 1.03223 | 1731 (0.2272 %) |

Conclusions:

1. **`outputImage.colorSpace` is `kCGColorSpaceDisplayP3` in every configuration tested** — with every knob zeroed, with HR on/off, and at every EDR level. 02's "the tag is a lie" framing is right; 03's "the zero output's `CIImage.colorSpace` is still `kCGColorSpaceDisplayP3`" agrees.
2. **You *can* render a scene-linear image with real headroom**: set `extendedDynamicRangeAmount = 1` or `2` and render into a `64RGBAHalf` + `extendedLinear*` destination. Max linear values of **1.83 / 2.65** are real and reproducible on both platforms. **02 D9's "extendedDynamicRangeAmount is not a linearisation lever … no pixel ever exceeds 1.0" is refuted.** (02's underlying measurement — `max = 0.571` — is a different sampling: centre crop, full resolution, and a different reading of the half-float buffer; those are *not* the same experiment.)
3. What `boostAmount = 0` does, measured: mean linear ≈ **0.198**, min **0.000**, i.e. a linear-response image lifted off black with a 1.0 ceiling. Not "milky" in linear terms — it is a *scene-referred* image with no tone curve, which is exactly what a develop pipeline should start from, and why 03's P0-4 ("flat and milky") is a correct complaint about the *8-bit Display-P3 delivery*, not about the data.
4. **Practical trap discovered (MEASURED):** `CIContext.render(_:toBitmap:…format: .RGBAh…)` into a **malloc'd** buffer **traps (SIGTRAP, signal 5)** on macOS 26.3.1 — the same render works at 8×8 but dies at full size. The working path is `CIContext.render(_:to: CVPixelBuffer, bounds:, colorSpace:)`. Any implementation that tries to read float pixels out of `CIRAWFilter` must use the `CVPixelBuffer` route or it will crash.
5. `isGamutMappingEnabled = false` does permit small negatives: **0 negatives at 0.25 scale on macOS**, `min = −0.00806` and 5 pixels > 1.0 on iOS; with gamut mapping **on**, `min = 0.00000` and max drops to 1.00098. So 02's mechanism claim is directionally right but its magnitude ("0.02 % of pixels") is ~30× larger than measured here; and with `boostAmount = 1` (Apple default) negatives jump to **2.2257 %** — that is where out-of-gamut clipping actually bites.

**Recommended fix direction.** If the product wants a scene-linear working image, the recipe becomes `boostAmount = 0`, `extendedDynamicRangeAmount = 1` (or 2), `isGamutMappingEnabled = true` (keep Apple's clipping out of our clipper), and the render path becomes `CIContext.render(_:to: CVPixelBuffer(kCVPixelFormatType_64RGBAHalf), …, colorSpace: CGColorSpace(name: .extendedLinearDisplayP3)!)`. Ignore `outputImage.colorSpace` entirely. Note in the docs that with EDR = 0 the headroom is ~6 px, so EDR = 0 is not a usable working space.

---

### C7 — Bayer bit depth · **P1** · **VERDICT: not a contradiction once "container" is separated from "sample depth"; 02's vendor heuristic is wrong on Apple's own files; and the fixture is not Bayer**

**HEADER (normative):**

```
CVPixelBuffer.h:103  kCVPixelFormatType_14Bayer_GRBG = 'grb4'  /* Bayer 14-bit Little-Endian, packed in 16-bits … */
CVPixelBuffer.h:104  kCVPixelFormatType_14Bayer_RGGB = 'rgg4'  /* … */
CVPixelBuffer.h:105  kCVPixelFormatType_14Bayer_BGGR = 'bgg4'  /* … */
CVPixelBuffer.h:106  kCVPixelFormatType_14Bayer_GBRG = 'gbr4'  /* … */
CVPixelBuffer.h:118  kCVPixelFormatType_16VersatileBayer       = 'bp16' /* ProRes RAW sensels */
CVPixelBuffer.h:119  kCVPixelFormatType_96VersatileBayerPacked12 = 'btp2' /* Bayer 12-bit LE, packed 12 bpc in 96 bits — ProRes RAW */
```

- **01 is right**: the four formats iOS delivers for Bayer photo RAW are the `kCVPixelFormatType_14Bayer_*` family. The name says 14; the **container** is always **16-bit little-endian** (two unused high bits). `AVCapturePhoto.pixelBuffer` (`AVCapturePhotoOutput.h`) documents `'bgg4'` as the Bayer RAW pixel buffer.
- **02's "12-bit" is about a different object**: `BitsPerSample` inside the DNG file. And its vendor heuristic *"WhiteLevel 4095 = 12-bit"* is **wrong for Apple's files**: the DNG spec default is `WhiteLevel = (2^BitsPerSample) − 1` (**SPEC**), but this fixture has `BitsPerSample = 12` with `WhiteLevel = 65535` because `LinearizationTable` maps the 12-bit stored code into a 16-bit domain. Any self-develop that infers depth from `WhiteLevel` will be wrong on exactly the files it must handle.
- **Decisive caveat:** the fixture is `PhotometricInterpretation = 34892` (**LinearRaw**, ProRAW), `SamplesPerPixel = 3`, no CFA tags. It is **not Bayer**, so it is **not evidence about Bayer bit depth at all** — 02 used it that way implicitly. Bayer RAW bit depth on iOS 26.5 hardware is **UNVERIFIED** here; the only device-visible statement is the OSType name the app itself passes to `AVCapturePhotoSettings(rawPixelFormatType:)` (`'bgg4'` ⇒ "14-bit, 16-bit container").
- 01's "Verified-correct §7" is *nearly* right but incomplete: CoreVideo defines **six** Bayer-tagged formats, not four — `kCVPixelFormatType_16VersatileBayer` and `kCVPixelFormatType_96VersatileBayerPacked12` are Bayer too (ProRes RAW). They are not `isBayerRAWPixelFormat`, so the four-element allow-list is still correct *today*; but the fix is `AVCapturePhotoOutput.isBayerRAWPixelFormat` (both 01 F13 and 02 D2 say this, and it is right).

**Recommended fix direction.** In any self-develop, treat `rawPhotoPixelFormatType`'s OSType as the authoritative CFA layout + container width, take the effective sample depth from the DNG (`BitsPerSample` + `LinearizationTable` + `BlackLevel`/`WhiteLevel`), and never infer it from `WhiteLevel` alone.

---

### C8 — Is >12 MP Bayer RAW possible on iOS 26.5? · **P1** · **VERDICT: no — and this follows from Apple's *documented* rules, independent of any vendor claim**

**Documented facts (HEADER + WWDC26 transcript):**

- `AVCapturePhotoOutput.h:85` (Bayer RAW rules): *"photoQualityPrioritization must be set to `AVCapturePhotoQualityPrioritizationSpeed`."*
- `AVCapturePhotoOutput.h:99`: *"The photoQualityPrioritization you specify may not be a greater number than the photo output's maxPhotoQualityPrioritization."*
- `AVCapturePhotoOutput.h:114` / `:545`: *"the maxPhotoDimensions setting for 24MP (5712, 4284), when supported, is only serviced as 24MP via deferred photo delivery."* And `AVCaptureDeferredPhotoProxy.rawPhoto` *"Always NO, as deferred processing isn't available for raw photos."*
- WWDC26-304 transcript (`/tmp/pikicam-adjudicate/wwdc304.md`, fetched from the published transcript):
  - `10:56` — *"You can capture 12 megapixel across all three prioritization levels."*
  - `11:02` — *"48 megapixel images, because they're only a single frame as covered earlier, are available with **either balanced, or quality prioritization**."*
  - `11:12` — *"18 megapixel and 24 megapixel are **multi-frame fused** images and take longer to process that **only quality prioritization** allows."*
  - `02:56`–`03:24` — 24 MP is explicitly *"combined pixels on the Quad sensor → 12 MP multi-frame fused HDR → Photonic Engine combines that with a full-resolution 48MP image → 24MP"*, i.e. fusion.
- `AVCaptureDevice.h:3483-3490` `supportedMaxPhotoDimensions` is per-`AVCaptureDeviceFormat`, i.e. a **device** property.

**Deduction:** 48 MP needs `photoQualityPrioritization ≥ .balanced`; Bayer RAW *requires* `.speed`; therefore **48 MP Bayer RAW cannot be requested**. 24 MP needs `.quality` **and** deferred delivery, which is explicitly unavailable for RAW. Hence **Bayer RAW is a 12 MP, 1×, single-exposure mode.** 01 F6 and 02 D4's *conclusion* are correct.

**Vendor claim, kept separate:** Halide/Lux, *The Process Zero Manual* — *"We sadly cannot take 48 megapixel Process Zero photos due to system limitations … Both of these limitations are because we do not get 48 raw sensor data from iOS. We've filed a request with Apple."* This is a **vendor statement**, and it is *stronger* than the documented rule (it claims no 48 MP **sensor data** at all, whereas the documented rule only blocks it via prioritization). Both lead to the same product constraint; cite the SDK + WWDC as the proof and Halide only as corroboration.

**UNVERIFIED:** what `activeFormat.supportedMaxPhotoDimensions` actually enumerates on iOS 26.5 hardware, and whether `availableRawPhotoPixelFormatTypes` ever contains a Bayer format above 12 MP. The **iOS 26.5 simulator reports zero capture devices** (MEASURED):

```
AVCaptureDevice.DiscoverySession(… .builtInWideAngleCamera …).devices.count = 0
AVCapturePhotoOutput().availableRawPhotoPixelFormatTypes = []   (not attached to a session)
```

so C8/OQ2 **cannot** be closed without a device probe. One measured extra: a RAW settings object's `maxPhotoDimensions` reads **(0, 0)** — i.e. *unset*, not "the smallest of `supportedMaxPhotoDimensions`" as `AVCapturePhotoOutput.h:1454` claims for the general case. **The app must set it explicitly** (confirms 01 F6 / 02 D6).

---

### C9 — `photoQualityPrioritization` on a Bayer RAW settings object · **P0** · **VERDICT: 02 right; 01 F3 and the repo's code comment are wrong**

```bash
cd /tmp/pikicam-adjudicate
xcrun --sdk iphonesimulator swiftc -target arm64-apple-ios26.5-simulator -O probe_av.swift -o probe_av_ios
xcrun simctl spawn BB29A4C9-… ./probe_av_ios
xcrun simctl spawn BB29A4C9-… ./probe_av_ios --quality     # reproduces the ObjC exception
```

MEASURED on iOS 26.5 simulator:

```
AVCapturePhotoSettings(rawPixelFormatType: 'bgg4')
  photoQualityPrioritization = 1            // enum: Speed=1, Balanced=2, Quality=3  ⇒ .SPEED
  isAutoStillImageStabilizationEnabled           = false
  isAutoRedEyeReductionEnabled                   = false
  isAutoContentAwareDistortionCorrectionEnabled  = false
  isAutoVirtualDeviceFusionEnabled               = false
  maxPhotoDimensions                    = CMVideoDimensions(width: 0, height: 0)
  AVCapturePhotoOutput.isBayerRAWPixelFormat('bgg4')  = true
  AVCapturePhotoOutput.isAppleProRAWPixelFormat('bgg4') = false
  settings.photoQualityPrioritization = .speed    → ACCEPTED, readback 1
  settings.photoQualityPrioritization = .quality  → NSInvalidArgumentException:
        *** -[AVCapturePhotoSettings setPhotoQualityPrioritization:] Unsupported when capturing RAW
AVCapturePhotoOutput (detached): maxPhotoQualityPrioritization = 2 (Balanced), availableRawPhotoPixelFormatTypes = []
```

**Verdicts:**

- **02 right.** The RAW factory *does* default `photoQualityPrioritization` to `.speed` — and that default is now a **measured fact**, not the speculation 02 recorded as OQ3.
- **01 F3 wrong**, and so is the repo's own comment (`CaptureService.swift:537-539`: *"Never set `photoQualityPrioritization` on RAW captures … The default (.balanced) is used."*). Both halves are false: the default is `.speed`, and setting `.speed` is legal. The `.balanced` default in `AVCapturePhotoOutput.h:1207` and `:1380` describes a **default-constructed** `AVCapturePhotoSettings` (format = JPEG), not the RAW factory.
- **What actually throws** is `.quality` — and the header tells you why (`AVCapturePhotoOutput.h:85`) and what it costs (`:344`, *"Setting the maxPhotoQualityPrioritization to `.quality` will turn on optical image stabilization if `isHighPhotoQualitySupported` …"*).
- **Legality of `.speed`:** yes. `AVCapturePhotoOutput.h:99` forbids exceeding `maxPhotoQualityPrioritization`, whose default is `.balanced` (2) on a plain session (`:342`); `.speed` (1) is lower, so it is legal. Measured.
- **Bonus confirmation of 01's "Verified-correct §3":** all four `auto*` flags read **false** on a RAW settings object, exactly as 01 said. No fusion, no red-eye, no content-aware DC.

**Recommended fix direction.** Keep `.speed` implicit but make it **explicit and asserted** (`settings.photoQualityPrioritization = .speed`) so the guarantee is a line of code rather than a factory side-effect; never expose `.quality` (it voids the no-fusion claim *and* throws); never raise `maxPhotoQualityPrioritization` above `.speed`. Delete or rewrite the `CaptureService.swift:537-539` comment, which will otherwise be copied into the next implementation prompt as fact.

---

### C10 — Other contradictions and corrections found

| # | Sev | Claim under dispute | Verdict / evidence |
|---|-----|---------------------|-------------------|
| 10.1 | **P1** | 03 P1-14: *"gate on `CIRAWFilter.supportedCameraModels`"* | **REFUTED and harmful.** MEASURED: `supportedCameraModels.count` = **939** (macOS) / **934** (iOS 26.5 sim), and `contains("iPhone13,3 back camera")` = **false** on both — yet the filter decodes and renders that exact file perfectly. Gating on this list would reject a valid iPhone 12 Pro DNG. Fix: gate on `filter != nil` + `outputImage != nil` + `nativeSize != .zero` only. |
| 10.2 | **P1** | 03: *"`CIImageProcessorKernel` exists (verified)"* | **FALSE.** `xcrun swiftc -typecheck` → `error: argument passed to call that takes no arguments`. It is a **subclass-only** API: `CIImageProcessor.h:113-117` — *"Override this class method to implement your Core Image Processor Kernel subclass."* |
| 10.3 | **P1** | `docs/prompt-next.md` §0.1 (quoted by 03): *"the correct fix is to set via the `input*` key path"* | **REFUTED.** The `input*` keys belong to the legacy `CIRAWFilterImpl` (116 methods, all present) and cannot express `highlightRecoveryEnabled`, `decoderVersion`, `linearSpaceFilter`, `scaleFactor`. The exception backtrace shows `CIRAWFilterImpl(Private)` is the *internal engine* the modern class wraps. One initializer change is the whole fix. |
| 10.4 | **P2** | 02 D16 / 01 F12: fixture is "Apple ProRAW / Linear DNG with an embedded semantic matte" | **CONFIRMED** — `PhotometricInterpretation 34892`, `SamplesPerPixel 3`, `BitsPerSample 12`, SubIFD[1] with `urn:com:apple:photo:2020:aux:semanticskymatte`. Both right; the disagreement was only about *which tags exist* (C1). |
| 10.5 | **P2** | 02 D14: the `LinearizationTable` is *"≈gamma"* | **Direction right, shape wrong.** MEASURED: monotone non-decreasing, 4096 entries, saturates at **input 1454 → 65535** (2642 entries at 65535), fitted `out = 65535·(in/1454)^1.098` — i.e. mildly **super**-linear, exponent ≈ 1.05–1.10, not a 1/2.2-style gamma. The operational conclusion ("apply the table or your colour is wrong") is unchanged. |
| 10.6 | **P2** | 02 D9/D10 numbers vs 03 P0-4 numbers for "the same" zero recipe | **Not a contradiction — different experiments.** 02 measured a centre-50 % crop at full resolution; 03 and I measured the full frame at 0.25 scale; the decoder, OS and half-float read-back differ. Only *within-table* comparisons (same harness, one variable changed) are comparable. The implementation prompt must not treat 02's `meanR 102.9` and 03's `avgR 102.37` as conflicting evidence. |
| 10.7 | **P2** | 02 D10: *"`isGamutMappingEnabled = false` ⇒ 0.02 % of pixels go negative"* | **Mechanism right, magnitude ~30× too high.** MEASURED at 0.25 scale: 0 negatives on macOS, `min = −0.00806` (≈5 px) on iOS with EDR 0. Negatives only become material when `boostAmount = 1` (**2.2257 %**). Recast as: "gamut mapping off is not the problem; the tone curve is what pushes values negative." |
| 10.8 | **P2** | 01 "Verified-correct §7": the four-element Bayer list is *"factually complete for the formats CoreVideo defines"* | **Nearly right, imprecise.** CoreVideo defines **six** Bayer-tagged formats (`CVPixelBuffer.h:103-106, 118-119`); the extra two are ProRes-RAW "VersatileBayer". The list is correct *today* because those are not `isBayerRAWPixelFormat` — replace it with Apple's classifier as 01 F13 / 02 D2 both say. |
| 10.9 | **P2** | 03 recommends `UTType.rawImage.identifier` as the `identifierHint` | **Harmless but note the value**: on iOS 26.5 and macOS 26.3.1 it is **`public.camera-raw-image`**, not `public.raw-image`. And per C2 the hint has **zero** effect on the result, so the choice is documentation, not behaviour. |
| 10.10 | **P2** | 03 note 10: `pikicamTests/Fixtures/*.DNG` is git-ignored so CI skips the develop tests | **CONFIRMED.** `.gitignore:14`; `git check-ignore -v` matches; `git ls-files pikicamTests/Fixtures/` is empty. Real CI risk: a green run asserting nothing. |
| 10.11 | **P1** | Nobody reported this | **`CIContext.render(…format: .RGBAh…)` into a malloc'd buffer traps** (SIGTRAP) on macOS 26.3.1 at full size while an 8×8 region succeeds. Use `render(_:to: CVPixelBuffer, bounds:, colorSpace:)` with `kCVPixelFormatType_64RGBAHalf`. |
| 10.12 | **P2** | `CIRAWFilter.h:30-33` declares `CIRAWDecoderVersion9` / `CIRAWDecoderVersion9DNG` in the **iOS 26.5** SDK, yet this file's `supportedDecoderVersions` = `[6.dng, 7.dng, 8.dng]` | Confirms 03 P0-8's substance (the decoder is per-image and can drift) and shows the RAW-9 *symbols* already ship on 26.5 even though no downloaded decoder does. Pin and record the version; do not assume it is available. |

---

## Open questions / assumptions

1. **Device-only, cannot be closed here.** The iOS 26.5 **simulator has zero capture devices** (MEASURED), so: `availableRawPhotoPixelFormatTypes` per device, `supportedMaxPhotoDimensions`, `rawPhotoDimensions` at each setting, `photoQualityPrioritization` validation *at `capturePhoto` time*, `isBayerRAWPixelFormat` coverage, GDC/Center Stage behaviour, Bayer DNG bit depth, and `CIRAWFilter` behaviour on a real CFA DNG all remain **UNVERIFIED**. Everything in this document was therefore cross-checked on **two** platforms (iOS 26.5 simulator + macOS 26.3.1) to maximise the chance that device behaviour matches.
2. **Device vs simulator for the initializer bug — reasoned, not measured.** `CIRAWFilter(imageData:)` binds to a *header* declaration present in both SDKs, so the overload resolution is platform-independent by construction. I could not run on hardware; treat the *compile-time* binding as certain and the *runtime class on device* as very likely `CIRAWFilterImpl` (it is the same Core Image binary family).
3. **The stub's own render was not fully characterised.** I deliberately skipped KVC `outputImage` on `CIRAWFilterImpl` because it raised an ObjC exception in one configuration; 03's claim that the stub's output equals Apple's default render is plausible (it is the same engine) but I did not reproduce it byte-for-byte. The *fact that matters* — none of the 15 recipe setters are reachable on it — is fully measured.
4. **Fixture fidelity.** `IMG_1361.DNG` is an iPhone 12 Pro **ProRAW/LinearRaw** file (`Software 14.3`), not Bayer. Every develop number in 01/02/03 and in this document describes Apple's *ProRAW* decoder on Apple's *ProRAW* packaging. A real Bayer CFA DNG would very likely change `isLensCorrectionSupported`, `luminanceNoiseReductionAmount`, the useful `decoderVersion` set, and possibly whether `linearSpaceFilter` behaves the same. This is the single biggest open gap.
5. **Measurement configuration is recorded so results can be compared.** All render stats here: full frame, 0.25 scale, `CIContext(useSoftwareRenderer: true)` for 8-bit (deterministic) / default `CIContext` for the `CVPixelBuffer` float path, `Display P3` for 8-bit and `extendedLinearSRGB` + `64RGBAHalf` for linear, half-floats decoded in software. `metalOK = true` in both environments.
6. **`shadowBias` is not inert while `boostAmount == 0`** (MEASURED), contrary to a plausible reading of the header grouping. The recipe's `shadowBias = 0` is therefore a real (if tiny) edit; `boostShadowAmount = 0` is provably inert while `boostAmount == 0`.
7. **Recommended default for `boostShadowAmount`** if the recipe is kept: `1.0` (the documented neutral) rather than `0.0` — zero behavioural difference today, correct semantics if `boostAmount` ever becomes non-zero.
8. **Nothing in the repository was modified.** Probes, binaries, logs, the DNG copy, the DNG-spec PDF/text and the WWDC transcript all live under `/tmp/pikicam-adjudicate/`. The only file written inside the repo is this report.

---

## Sources

**Repository (read-only, this tree, `main` @ uncommitted working tree preserved)**
- `pikicam/Features/Develop/CIRAWZeroProcessor.swift:31` (`CIRAWFilter(imageData:)` — the stub), `:55-62` (wrong `highlightRecoveryEnabled` rationale), `:65` (`baselineExposure = 0.0`), `:67` (`boostAmount = 0.0`), `:124` (`responds(to:)` silent skip)
- `pikicam/Features/Camera/CaptureService.swift:536-539` (RAW settings + the wrong `photoQualityPrioritization` comment)
- `pikicam/Core/Storage/PhotoLibraryManager.swift:680,682` (`version = .current`, `resizeMode = .fast`)
- `pikicam/Features/Develop/DevelopService.swift:21-33` (`CIContext` with `cacheIntermediates: false`, Display P3 output)
- `.gitignore:14` (fixture exclusion), `pikicamTests/Fixtures/IMG_1361.DNG` (copied to `/tmp` before any read)

**Local SDK headers — `iPhoneOS26.5.sdk` (normative)**
- `CoreImage.framework/Headers/CIRAWFilter.h:24-41, 44-64, 66-92, 92-98, 100-161, 163-183, 187-191` (full property set; `NS_AVAILABLE(16_0, 19_0)` on highlight recovery at `:87-88`; `linearSpaceFilter` at `:174`; **no 1-arg initializer** — only `+filterWithImageURL:`, `+filterWithImageData:identifierHint:`, `+filterWithCVPixelBuffer:properties:`)
- `CoreImage.framework/Headers/CIRAWFilter_Deprecated.h:20-35` — **`CIFilter` category with `+filterWithImageData:options:` at line 28 = the binding used by `CIRAWFilter(imageData:)`**
- `CoreImage.framework/Headers/CoreImage.apinotes:1194-1210` (nullability notes for `filterWithImageData:options:`)
- `CoreImage.framework/Headers/CIKernel.h:153-165` (`CIColorKernel`), `CIImageProcessor.h:113-117` (subclass-only `CIImageProcessorKernel`)
- `AVFoundation.framework/Headers/AVCapturePhotoOutput.h:78-96` (Common + **Bayer RAW rules**), `:99` (prioritization cap rule), `:114` & `:545` (24MP deferred-only), `:331-335` (enum `Speed=1, Balanced=2, Quality=3`), `:342-344` (`maxPhotoQualityPrioritization` default + the OIS side-effect), `:1207` & `:1375-1382` (`.balanced` default for a *default-constructed* settings object), `:1454` (`maxPhotoDimensions` defaults to smallest), `:2011-2015` (`pixelBuffer` Bayer `'bgg4'`), `:2304-2310` (deferred proxy `rawPhoto` always NO)
- `AVFoundation.framework/Headers/AVCaptureDevice.h:3483-3490` (`supportedMaxPhotoDimensions`), `:2267-2286` (GDC never applied to RAW), `:2333-2372` (Center Stage), `:1381` (`.balanced`-or-higher may override ISO/exposure)
- `CoreVideo.framework/Headers/CVPixelBuffer.h:103-106, 118-119, 252-262`

**Adobe DNG Specification 1.4.0.0** (extracted text `/tmp/pikicam-adjudicate/dng_spec_1_4.txt` from `https://www.kronometric.org/phot/processing/DNG/dng_spec_1.4.0.0.pdf`)
- `WhiteLevel` = Tag 50717 (C61D.H), Default *(2^BitsPerSample) − 1* · `BlackLevel` = 50714 (C61A.H) · `LinearizationTable` = 50712 (C618.H) · `ColorMatrix1` = 50721 (C621.H) SRATIONAL × ColorPlanes*3 · `ColorMatrix2` = 50722 (C622.H) · `CalibrationIlluminant1/2` = 50778/50779 (C65A/C65B.H) · `AsShotNeutral` = 50728 (C628.H) · `BaselineExposure` = 50730 (C62A.H) · `ShadowScale` = 50739 (C633.H), Default 1.0 · `PhotometricInterpretation` 32803 = CFA, 34892 = LinearRaw

**Apple documentation / sessions**
- WWDC26 session 304, *Implement high resolution photo capture* — https://developer.apple.com/videos/play/wwdc2026/304/ ; transcript fetched to `/tmp/pikicam-adjudicate/wwdc304.md` from `https://raw.githubusercontent.com/pixelfolio/WWDC26-Transcripts/main/wwdc2026-304%20-%20Implement%20high%20resolution%20photo%20capture.md` — cited at `[00:02:56]`–`[00:03:24]` (24 MP = multi-frame fused) and `[00:10:56]`–`[00:11:22]` (12 MP at all prioritizations; 48 MP needs balanced/quality; 18/24 MP multi-frame and quality-only)
- `https://developer.apple.com/documentation/avfoundation/avcapturephotosettings/init(rawpixelformattype:)`, `/rawphotopixelformattype`, `/avcapturephotooutput/availablerawphotopixelformattypes`
- `https://developer.apple.com/documentation/coreimage/cirawfilter`, `/boostamount` (*"A value of 0 indicates no global tone curve (linear response) … The default value is 1."*), `/linearspacefilter` (*"An optional CIFilter to be applied to the RAW image while it is in linear space."*)

**Third-party (used only where labelled a vendor claim / corroboration)**
- Halide/Lux, *The Process Zero Manual* — https://www.lux.camera/process-zero-manual/ — 48 MP Process Zero impossible; *"we do not get 48 raw sensor data from iOS"* (**vendor claim**, consistent with but not the proof of the documented prioritization rule)
- Bayer Cam, *Understanding Bayer RAW* — https://bayercam.com/understanding-bayer-raw — "every iPhone … shoots 12-bit"; the `WhiteLevel 4095` heuristic (**refuted for Apple's own files by C7**)

**Probe artifacts (all under `/tmp/pikicam-adjudicate/`)**
`dngdump.py` / `dngdump.txt` / `dngdump_clean.txt` (full IFD dump + whole-file entry scan) · `absent.py` (presence/absence proof + LUT fit) · `dng_spec_1_4.pdf` / `.txt` · `wwdc304.md` · `t1.swift`/`t2.swift` (initializer binding + `-dump-ast` proof) · `k.swift`/`k2.swift` (kernel-syntax + API-presence matrix) · `probe.swift` (C2–C5b, compiles for both platforms) · `probe5/6/7.swift` (C6 float/linear path) · `probe8.swift` (recipe read-back, `boostShadowAmount`/`shadowBias` inertness, gamut mapping) · `probe_av.swift` (C9) · binaries `probe_mac`, `probe_ios`, `probe7_ios`, `probe8_mac`, `probe_av_ios`, `probe2..4_ios` · logs `mac_out.txt`, `ios_out.txt`, `ios7.txt`, `ios_av.txt`.