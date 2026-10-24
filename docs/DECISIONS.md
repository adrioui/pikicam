# pikicam — DECISIONS

Decision log for the v2 rebuild (`docs/PROMPT-v2.md`). One entry per load-bearing
decision, discrepancy, or recorded deviation. Newest at the bottom of each section.

## Claims-under-test ledger (v2 §1)

Each row: the corpus claim → the probe that re-establishes it on the iPhone 12 mini
(iOS 26.6.2) → status. `proven | refuted | amended`. Statuses are filled from
`Probes/pikicamProbes` runs; raw JSON results are attached to each probe commit.

| # | Claim (source) | Probe | Status |
|---|---|---|---|
| L1 | `CIRAWFilter(imageData:)` 1-arg binds to deprecated `CIFilter` category → stub (research 06 C2) | AST-dump typecheck + runtime class print in probe app | **proven** — runtime class `CIRAWFilterImpl`, not a `CIRAWFilter`, responds to none of the modern setters (`setBoostAmount:`, `setDecoderVersion:`, `setIsHighlightRecoveryEnabled:` all absent) |
| L2 | `CIRAWFilter(imageData:identifierHint:)` returns real class; §8.2 controls assign+read back (research 06 C2) | per-control assign/readback loop, dumped as JSON | **proven** — real `CIRAWFilter` (4032×3024, output non-nil); all 14 §8.2 controls assigned and read back at their neutral values on both the ProRAW fixture and the device-captured Bayer fixture; `isHighlightRecoveryEnabled` settable; `baselineExposure` default = DNG tag (−0.30221677); `supportedDecoderVersions` = [6.dng, 7.dng, 8.dng] |
| L3 | RAW settings default `photoQualityPrioritization = .speed`; `.quality` throws; `.balanced` accepted (research 06 C9) | settings-object print + exception trap | **amended** — default `.speed` confirmed (rawValue 1); `.quality` throws `NSInvalidArgumentException "Unsupported when capturing RAW"`; `.balanced` **also throws on device** (research 06 measured it accepted on the iOS 26.5 simulator — device truth differs) |
| L4 | RAW settings `maxPhotoDimensions` reads (0,0) until set (research 06 C8) | print on device | **proven** — default reads 0×0; output after attach reports 4032×3024 |
| L5 | EDR headroom: `extendedDynamicRangeAmount` 1→≈1.85, 2→≈2.69 linear (research 06 C6) | `64RGBAHalf` CVPixelBuffer readback on device A14 | **amended** — mechanism proven (EDR is a real linearisation lever; `outputImage` tag always Display P3 while values carry headroom), magnitudes differ on device: ProRAW fixture max = 1.00 / 1.33 / 1.56 at EDR 0/1/2 (simulator-era numbers came from that file on that runtime); the dark-scene Bayer capture shows no >1.0 pixels at any EDR — headroom measurement needs a bright scene (Phase A) |
| L6 | `render(_:toBitmap:.RGBAh)` into malloc traps at full size (research 06 C6) | trap probe (run last) | **refuted on device** — the full-size `.RGBAh` `render(toBitmap:)` completed without trapping on the 12 mini (iOS 26.6.2); research 06's trap was measured on macOS 26.3.1. The app still uses the CVPixelBuffer route (spec-mandated), so behaviour is unchanged |
| L7 | `heif10Representation` async; `CIContextOption.memoryTarget` exists (research 07) | compile probe | **amended** — async ✓, `memoryTarget` ✓, but the method returns non-optional `Data` and throws (never returns nil) on this SDK |
| L8 | `AVCaptureClient` actor on `DispatchSerialQueue` executor compiles Swift 6 complete strict concurrency (v1 §6.9) | compile probe + runtime actor in probe app | **proven** — `DispatchSerialQueue.asUnownedSerialExecutor()` compiles and runs (probe actor + fixture-capture agent both use it) |
| L9 | PhotoKit resource shapes A/B/C behaviour (v1 §4.3.2) | device Photos library probe | **pending retry** — `supportsAssetResourceTypes` true for all four resource types, but asset creation failed with `PHPhotosErrorDomain 3300` while the Photos permission dialog was unanswered during the console-run pass; re-running under the UI-test harness which taps the dialog |
| L10 | Simulator-era unknowns: Bayer formats per lens, `supportedMaxPhotoDimensions`, GDC support, Center Stage support, ZSL default, flash+RAW legality, HLG 10-bit video formats, `AVAssetWriter` acceptance | device probe app JSON dump | **proven (device facts)** — Bayer RAW format is `'rgg4'` on both rear lenses (ultra-wide `:5`, wide `:0`) and `'bgg4'` on the front (`:1`); no telephoto device exists; RAW max = 4032×3024; GDC supported on ultra-wide only; Center Stage control mode reads `.user` and stays there; low-light boost **not supported** (and setting it throws `NSInvalidArgumentException` — crash source fixed in probe); ZSL default is **on** (must be explicitly disabled); flash+RAW **legal** (capture with `flashMode = .on` succeeded, `isRawPhoto` true, flash fired); HDR-capable video formats exist at 1080p30/60 and 4K30/60 on the wide camera; `AVAssetWriter` accepts `proRes422HQ`; HLG transfer-function key present |
| L11 | `onCameraCaptureEvent` (AVKit), `RotationCoordinator`, readiness coordinator, deferred start, WB temperature/tint lock (research 07) | compile+run probes | **amended at build** — all five exist; `onCameraCaptureEvent` has no `escapeBehavior:` overload; readiness coordinator is delegate-based with its own `captureReadiness`; no `videoRotationAngleForPortraitCapture`; `automaticallyRunsDeferredStart` exists on `AVCaptureSession` |
| L12 | Tone-curve / gamut reference behaviour (darktable filmic) | render fixture through `darktable-cli` neutral pipeline | **blocked** (D2: darktable unavailable on host) — RawTherapee CLI is the substitute reference renderer |

### SDK-surface facts already established at build time (iPhoneOS26.5.sdk)

These are compile-probe results — the compiler is the instrument; the build either
proves the symbol or it does not.

1. `CIRAWFilter.despeckleAmount` does **not exist** in this SDK (research 07 claimed
   iOS-27-gated presence). Refuted at L-row pending runtime confirmation.
2. `heif10Representation(of:colorSpace:options:)` returns non-optional `Data` and
   throws; the "returns `Data?`" shape in research 07 is wrong for this SDK.
3. `CIRAWFilter.supportedCameraModels` is a **class (static)** property, not an
   instance property.
4. Center Stage: `centerStageControlMode` and `centerStageEnabled`/`isCenterStageEnabled`
   are **class** properties on `AVCaptureDevice`; there is no per-device
   `isCenterStageAvailable` instance property.
5. Flash modes: `AVCaptureDevice.supportedFlashModes` is gone; the API is
   `AVCapturePhotoOutput.supportedFlashModes` (`[AVCaptureDevice.FlashMode]`).
6. `AVCaptureDevice.Format.videoSupportedFrameRateRanges` (not `videoFrameRateRanges`).
7. `AVCapturePhotoOutput` has `isContentAwareDistortionCorrectionSupported`; no
   instance `isAutoContentAwareDistortionCorrectionEnabled` / `isLensDistortionCorrectionSupported`.
8. `AVCaptureDevice.Format.supportedMaxPhotoDimensions` is Swift-refined to
   `[CMVideoDimensions]`.
9. `AVCapturePhotoOutputReadinessCoordinator` exists; it is delegate-based
   (`readinessCoordinator:captureReadinessDidChange:`), exposes its own
   `captureReadiness` and `startTrackingCaptureRequest(using:)`. The readiness
   enum is `AVCapturePhotoOutput.CaptureReadiness`.
10. `AVCaptureDevice.RotationCoordinator` has `videoRotationAngleForHorizonLevelPreview`
    / `...ForHorizonLevelCapture`; there is **no** `videoRotationAngleForPortraitCapture`.
11. SwiftUI `onCameraCaptureEvent` exists with the plain `{ (AVCaptureEvent) -> Void }`
    overload; **no** `escapeBehavior:` overload in this SDK.
12. `CIContextOption.memoryTarget` exists; `setExposureModeCustom` has an async
    overload — the completion-handler form is the synchronous one.
13. `CaptureOutcome`-level: `AVCaptureResolvedPhotoSettings` carries only
    `rawPhotoDimensions` / `expectedPhotoCount` / `isFlashEnabled` etc. — the
    `isAuto*` fusion/CADC/stabilization flags live on `AVCapturePhotoSettings`
    (pre-capture), not on resolved settings. v2 §7.4's "resolved settings …
    fusion/CADC/stabilization/red-eye all false" must therefore be asserted on the
    settings object; amended.
14. `extendedDynamicRangeAmount` is a `Float` property on `CIRAWFilter`.

## Recorded deviations (from v2)

| # | Decision | Why | What would change it |
|---|---|---|---|
| D1 | Probe (and later app) builds sign with Personal Team `V7BF8622ZR`, not the v2-mandated `GV4GK5XGN5` | The GV4GK5XGN5 signing identity exists in the keychain but no Apple ID account for that team is signed into Xcode on this Mac, so `-allowProvisioningUpdates` cannot mint profiles for it. The personal team provisions and installs on the connected 12 mini. | Owner signs into Xcode with the paid-team Apple ID → set `DEVELOPMENT_TEAM: GV4GK5XGN5` in `project.yml` (v2 §2 mandate stands once possible). |
| D2 | `darktable` is unavailable on this host (Homebrew cask disabled 2026-09-01, fails Gatekeeper). The §4.4 dual-oracle bracket is LibRaw (rawpy) + `rawtherapee-cli` until darktable returns. | Upstream cask state. | darktable cask re-enabled, or a manually installed darktable.app on PATH. |
| D3 | `dng_validate` oracle built from community mirror `emmcb/adobe-dng-sdk` (DNG SDK 1.7.0.0 + CMake). The official `github.com/adobe/dng_sdk` repository does not resolve. Build: `cmake -B build/host -DCMAKE_BUILD_TYPE=Release`, plus `target_link_libraries(dng-validate PRIVATE "-framework Foundation" "-framework CoreFoundation" "-framework Carbon")`. | Adobe hosts the SDK behind its own site; the mirror is the practical source. `dng_validate` passes on the ProRAW fixture (`Validation complete`). | None needed; binary lives at `/tmp/dng-sdk-cmake/build/host/dng-validate` (rebuild command recorded here). |
| D4 | `.agents/` is retained (v2 §14 delete-list wanted it gone) and the repo's `swift-coding-standards` skill is superseded by the owner-selected `twostraws/swift-agent-skills` set installed at `.agents/skills/`: `swiftui-pro`, `swift-concurrency-pro`, `swift-testing-pro`, `ios-accessibility`. | Owner instruction (2026-10-24): "No not that skill but these"; and "Take a really good care of the codebase." | Owner reverses the skill choice. |
| D5 | `muter` is not a Homebrew formula; built from source (`github.com/muter-mutation-testing/muter`, `swift build -c release`). | Upstream packaging. | None. |
| D6 | Code comments are omitted per owner instruction ("the code itself is the documentation"), superseding v2 §14's "non-obvious why with a source" comment policy, except where a contract (e.g. `@unchecked Sendable` proof) makes a one-line comment unavoidable. | Owner instruction (2026-10-24). | Owner reverses. |

| D7 | `piki.pikicam` and `piki.pikicamProbes` temporarily share bundle identifiers (app → `piki.pikicamProbes`, UI-test runner → `piki.pikicamProbesUITests`) so device builds can use the already-minted personal-team profiles | The Xcode account session for the Personal Team expired and cannot refresh headlessly ("No Accounts" from `xcodebuild -allowProvisioningUpdates`); the probe profiles are cached and still valid. The app installs over the probe app on the device while this holds. | Owner re-authenticates Xcode (Settings → Accounts) → revert both identifiers to `piki.pikicam` / `piki.pikicamUITests` in `project.yml`. |
| D8 | Periphery scope: the spec-mandated Phase 1 Domain vocabulary (§6.1) plus Fakes and not-yet-wired Support wrappers carry `// periphery:ignore` file markers and a `.periphery.yml` `report_exclude` | The vocabulary is built ahead of its Phase 2-4 consumers by design ("Domain shapes" is a Phase 1 deliverable); periphery guards dead code inside features as they land, with the scope shrinking each phase. `retain_assign_only_properties` matches the Dependencies-factory pattern v2 §6.5 prescribes. | Remove markers as consumers land; at DoD (§17) the app code must be warning-free with no markers left. |

## Tooling record (Phase 0 attestation)

| Tool | Version | Source |
|---|---|---|
| Xcode | 26.6 (17F113), iOS 26.5 SDK | system |
| xcodegen | installed via Homebrew | Homebrew |
| swiftlint | installed via Homebrew | Homebrew |
| periphery | installed via Homebrew | Homebrew |
| swift-format | installed via Homebrew | Homebrew |
| exiftool | 13.55 | Homebrew |
| ImageMagick (`magick`) | installed via Homebrew | Homebrew |
| ffmpeg/ffprobe | nix profile | system |
| ArgyllCMS (`icclu`) | 3.5.0 | Homebrew (`argyll-cms`) |
| rawtherapee-cli | installed via Homebrew cask | Homebrew |
| darktable-cli | **unavailable** (D2) | — |
| muter | built from source (D5) | github.com/muter-mutation-testing/muter |
| Python venv | `.venv/` with numpy, rawpy, imageio, colour-science, scikit-image | local |
| dng_validate | DNG SDK 1.7.0.0 (D3) | github.com/emmcb/adobe-dng-sdk |

Device: iPhone 12 mini (iPhone13,1), iOS 26.6.2, Developer Mode on, udid
`A1AA422E-FCD9-56CD-B667-51CCBB84E1B2`.

## Phase entries

(One entry per completed phase lands here; see §16 of PROMPT-v2.)
