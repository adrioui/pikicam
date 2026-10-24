# pikicam — CALIBRATION (Phase A)

Instrument: iPhone 12 mini (iPhone13,1), iOS 26.6.2, rear wide camera (f/1.6) unless
stated. Every number below states its method. Tier: **0** — no ColorChecker 24 was
photographed (owner-physical item, see `docs/DEVICE-CHECKLIST.md`). Tier 1 requires
the owner's chart shot; the probe capture path already supports it.

## Sensor identity (measured from the device's own DNG, `fixture-bayer-rich.dng`)

| Quantity | Value | Method |
|---|---|---|
| Bayer format | `'rgg4'` (14-bit Bayer, 16-bit LE container), `AVCapturePhotoOutput.isBayerRAWPixelFormat` true | probe `deviceDiscovery` (§0 JSON) |
| RAW dimensions | 4032 × 3024 (12.2 MP) | probe `captureSeries`, all 26 captures |
| PhotometricInterpretation | 32803 (CFA), CFARepeatPatternDim [2,2], CFAPattern RGGB | `exiftool` on captured DNG; `dng_validate` clean |
| Stored depth | `BitsPerSample 16`, `WhiteLevel 4095` (12-bit codes), `BlackLevel 528` (all planes) | `exiftool`; confirms research 06 C7: depth comes from BitsPerSample+levels, never from the OSType name |
| UniqueCameraModel | `iPhone13,1 back camera` | `exiftool` |
| AsShotNeutral (indoor scene) | (0.4999, 1.0, 0.4142) | `exiftool`; plausible tungsten-leaning daylight mix; exact neutrality proof is a Tier-0 pending item |
| ISO range (wide, active format) | 33 … 3168 | probe `deviceDiscovery` (`activeFormat.minISO/maxISO`) |
| Exposure range (wide) | 14 µs … max (>1/30 s available) | probe `deviceDiscovery` |

## EDR headroom of the CIRAWFilter output (measured)

Method: probe `edrHeadroom` — `CIRAWFilter` with `boostAmount 0`, rendered into
`kCVPixelFormatType_64RGBAHalf` with `CGColorSpace(name: .extendedLinearDisplayP3)`,
0.25 scale, half-floats decoded in software; max/mean over all RGB samples.

| `extendedDynamicRangeAmount` | ProRAW fixture max linear | mean | pixels > 1.0 |
|---|---|---|---|
| 0 | 1.000 | 0.314 | 0 |
| 1 | 1.331 | 0.287 | 1948 |
| 2 | 1.563 | 0.256 | 2324 |

The `outputImage.colorSpace` tag is Display P3 at every setting (the tag lies about
values; the pixels do not — research 06 C6 mechanism confirmed on device, magnitudes
are file-dependent). The dark-scene Bayer capture showed no samples above 1.0 at any
EDR — a bright-scene Bayer recapture (owner-physical) completes the Bayer-side
headroom measurement. Phase A's E choice therefore defaults to **1** pending that
measurement, with the <1 % mean-difference rule to be re-run on the bright fixture.

## Capture determinism (measured, §7.3 readback)

From probe `captureSeries.determinism`: wide-color auto-config off, active color
space P3_D65 (rawValue 1), GDC off (supported on ultra-wide only), Center Stage
control mode `.user` (class-level API; set to `.app` produced no exception and no
change), video HDR off, low-light boost off (setting it throws `NSInvalidArgumentException`
on this device — unsupported), zoom 1.0, maxPhotoDimensions 4032×3024.

## Pending (owner-physical; procedure ready)

These numbers require the device unlocked, camera-up, facing a scene for ~3 minutes
(the two automated sessions captured black frames — the phone lay face-down; frames
were noise around black level 528, discarded):

1. **PTC / read noise / full well / linear range** — `scripts/calibrate.py` over the
   flat series (`fixtures/device/flat_*.dng`); the probe capture + analysis pipeline
   is committed and runs end-to-end.
2. **Shutter-tag accuracy** — same series; tagged `ExposureTime` vs requested ladder
   (14 µs / 186 µs / 2496 µs / 33.3 ms at 6 ISO steps).
3. **WB neutrality** — grey/white patch under D65-ish light; after our pipeline with
   as-shot WB, Δa*/Δb* ≈ 0 within a measured band.
4. **Colour fidelity Tier 1** — ColorChecker 24 via the probe; `scripts/colorcheck.py`
   (Phase 3) computes ΔE2000 per patch vs BabelColor; median ΔE ≤ 8 bar.

## Fixture register (SHA256, `fixtures/device/`)

- 24 flat-series DNGs + `fixture-bayer-rich.dng` — see `fixtures/device/SHA256SUMS.txt`
  (files git-ignored per v2 §4.3; hashes + probe JSON committed).
- Adversarial/foreign input: `pikicamTests/Fixtures/IMG_1361.DNG`
  (sha256 `e91e77a4533ed7cce551d83330676ea5c47dd5e55fb38adda7819366afdbdfc2`,
  Apple ProRAW/LinearRaw — must be REJECTED by `PhotoBoundary`).
- Synthetic parser fixture: `scripts/make-synthetic-bayer.py` → 64×48 RGGB 16-bit
  DNG, `dng_validate` clean ("Validation complete", zero warnings) and rawpy-decodable.

## Oracle chain

`dng_validate` (DNG SDK 1.7.0.0, DECISIONS D3) → `exiftool` (tag readback vs spec
tables) → LibRaw via rawpy (decode statistics) — in that authority order.
