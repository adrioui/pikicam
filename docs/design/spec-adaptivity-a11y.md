# pikicam .P.DESIGN — ADAPTIVITY AND ACCESSIBILITY

> Scope: monochrome, hairline, icon-free, word-only Margiela surface over live camera imagery + white-room gallery. Every code fact below traces to the verified inventory file:line. Every convention fact traces to a verified URL. Where the bundle is silent or refuted, this spec says so and makes a buildable SwiftUI iOS 26 choice with no third-party dependencies. Repo root `/Users/adrifadilah/Desktop/pikicam`. Source under `pikicam/`.

## 0. What the code is today (baseline to adapt)

- Camera root is fullscreen black: `pikicam/Features/Camera/CameraView.swift:26` `Color.black.ignoresSafeArea()`.
- Current camera type is rounded, not mono: `pikicam/Features/Camera/CameraView.swift:133` `.font(.system(size: 13, weight: .bold, design: .rounded))` (zoom chip); `:157` `.system(size: 12, weight: .bold, design: .rounded)` (aspect strip); `:440` `.system(size: 12, weight: .bold, design: .rounded)` (exposure bubble); `:482` `.system(size: 96, weight: .bold, design: .rounded)` (countdown); `pikicam/Features/Camera/CameraHUDButton.swift:18` `.system(size: 17, weight: .medium)` + `:23` `.system(size: 11, weight: .medium, design: .rounded)`; `pikicam/Features/Camera/ZoomIndicatorView.swift:10` `.system(size: 15, weight: .medium, design: .rounded) + .monospacedDigit()`.
- Current selected state is yellow-on-black, not inversion: `pikicam/Features/Camera/CameraView.swift:136` `Color.black : Color.white`; `:142` `Color.yellow : Color.black.opacity(0.5)`; `:161` `.yellow : .black.opacity(0.5)`; `:441` `.foregroundStyle(.yellow)` (exposure value); `:192` `.foregroundStyle(.yellow)` (gallery badge).
- Gallery forces dark: `pikicam/Features/Gallery/GalleryView.swift:69` `.preferredColorScheme(.dark)`; app forces dark: `pikicam/App/PikicamApp.swift:24` `.preferredColorScheme(.dark)`. Permissions screens inherit dark only.
- Grid geometry today: `pikicam/Features/Gallery/GalleryView.swift:106` `GridItem(.adaptive(minimum: 100), spacing: 2), spacing: 2`; cell `pikicam/Features/Gallery/GalleryView.swift:113` `.aspectRatio(1, contentMode: .fit)`; outer `pikicam/Features/Gallery/GalleryView.swift:118` `.padding(2)`.
- Shutter geometry today: `pikicam/Features/Camera/Views/ShutterButton.swift:17` `.frame(width: 80, height: 80) lineWidth 4` + `:22` `.frame(width: 64, height: 64) / veil 56x56` + `:16` `.strokeBorder(.white, lineWidth: 4)` + `:21` `.fill(.white)` + `:25-27` `.fill(.black)` + `.opacity(isCapturing ? 0.3 : 0)`.
- No haptic literals exist in the inventoried camera/gallery/test files. No `UIFeedbackGenerator` / `.sensoryFeedback` token was inventoried. Statement: code today has zero designed haptics.
- No explicit animation/duration literals exist in `GalleryView.swift` except system default: `pikicam/Features/Gallery/GalleryView.swift:56` `.fullScreenCover(isPresented:) — system default, no duration`.
- Camera animations that do exist: `pikicam/Features/Camera/CameraView.swift:96` `withAnimation(.easeInOut(duration: 0.2))` (slider show); `:100` `withAnimation(.easeInOut(duration: 0.25))` (slider hide); `pikicam/Features/Camera/Views/ShutterButton.swift:42` `.animation(.easeInOut(duration: 0.15), value: isPressed) scale 0.9->1.0` + `:32` `Button + .buttonStyle(.shutter) + .disabled(isCapturing)`.
- No focus reticle exists: tap-to-focus produces zero visual marker in bridge files; only EV slider appears (`CameraView.swift:79-82` tap calls `presentExposureSlider() + setFocusAndExposure`). This is a missing state the design must add.

Convention authorities this section may cite (verified fetches, not paraphrase-as-quote):

- Text labels must accompany ambiguous icons and stay visible: `https://www.nngroup.com/articles/icon-usability/` — verified sentences include always-visible labels, do-not-rely-on-hover, zero-discovery failure for obscure symbols.
- Contrast thresholds: `https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html` — verified `at least 4.5:1` normal, `at least 3:1` large at `18pt or 14pt bold`; `https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html` — verified `at least 3:1 against adjacent color(s)`.
- Courier New ships on iOS: `https://developer.apple.com/fonts/system-fonts/` — verified `Courier New / Version 5.00.2x / iOS system font`.
- Halide gestures/marketing: `https://halide.cam` — verified `swiping up and down for exposure, and left and right for focus`, `Halide turns your iPhone into a traditional camera`.
- Blackmagic state color: `https://www.blackmagicdesign.com/products/blackmagiccamera` — verified `When recording, the button and timecode at the top of the screen turn red` + HUD hidden by vertical swipe.
- What is NOT citable: Apple HIG Layout / Accessibility / Materials / Dark-Mode / Divider / safeAreaInsets / accessibilityAddTraits / SF Symbols catalog / support-guide IDs / margiela.com CSS tokens / iOS 26 mode-selector position / shutter pt tokens / exposure `-2..+2 EV` range / reticle dwell / viewer gesture sentences — all returned 404, title-only, or NOT FOUND in verification. This spec marks every such value as DESIGN CHOICE, not convention.

---

## 1. Dynamic Type

### Mechanism

1. **Typeface mapping.** Ship two roles with zero dependencies:
   - Body/controls: `Font.custom("Courier New", size: X, relativeTo: Y)` with runtime fallback to `.system(size: X, design: .monospaced, weight: W, relativeTo: Y)` if `UIFont(name:"Courier New", size:)` returns nil. Courier New availability is verified at `https://developer.apple.com/fonts/system-fonts/`. Never use the two-arg `Font.custom(_:size:)` for UI text — it freezes size (model-knowledge, Apple doc page title-only so cited as platform best practice, not verbatim quote).
   - Display/labels (section headers only): `.system(design: .default)` sans. Do not ship licensed Recast/Helvetica Now files.
2. **Scale table (default Dynamic Type = Large).** All sizes are the `size:` passed with `relativeTo`, so they scale automatically:
   - HUD word: `custom("Courier New", size: 13, relativeTo: .caption)` tracking +40 (0.52pt at 13pt). Replaces `CameraHUDButton.swift:23` 11pt rounded.
   - Chip word: `custom("Courier New", size: 13, relativeTo: .caption)` weight medium-equivalent (Courier New has no medium file; simulate with `.fontWeight(.regular)` + `.foregroundStyle` contrast, never faux-bold synthesis above 15pt).
   - Status/exposure readout: `custom("Courier New", size: 12, relativeTo: .caption)` + `.monospacedDigit()`.
   - Countdown: `custom("Courier New", size: 96, relativeTo: .largeTitle)` — replaces `CameraView.swift:482` rounded 96pt. Cap rendered size at 120pt via `.dynamicTypeSize(...DynamicTypeSize.accessibility3)` + `.minimumScaleFactor(0.6)` so `10` (two glyphs) does not shift the disc (existing bug: `CameraView.swift:480-486` disc is content-sized, `10` renders wider than `3..1`).
   - Gallery title `Library` (`GalleryView.swift:49` `"Library"`), viewer title `DNG Viewer` (`GalleryView.swift:194` `"DNG Viewer"`), empty `No captures` (`GalleryView.swift:99` `"No captures" / "Capture a photo to begin."`): `custom("Courier New", size: 17, relativeTo: .body)` tracking +80, uppercase.
3. **Largest accessibility sizes (AX1–AX5 / XXXL).**
   - Camera HUD row (`CameraView.swift:247` `HStack(spacing: 20)`) wraps: `ViewThatFits(in: .horizontal)` — first choice single row; fallback `VStack(alignment: .trailing, spacing: 12)` pinned trailing. Never truncate `FLASH / TIMER / GRID`. Never shrink hit area below §8.
   - Bottom dock (`CameraView.swift:217` `.padding(.horizontal, 20) + .padding(.bottom, 32)`): at `.accessibility1` and above, zoom chips (`CameraView.swift:127` `HStack(spacing: 12)`) move from above-dock to a horizontally scrollable strip (`ScrollView(.horizontal)`) with same 44pt targets; shutter stays centered 80pt; thumbnail 60×58 (`CameraView.swift:180` `.frame(width: 60, height: 58)`) stays fixed.
   - Exposure slider (`CameraView.swift:48` `.frame(height: 220) + .padding(.trailing, 14) + .padding(.bottom, 120)`): height becomes `min(220, geometry.size.height * 0.32)`; value bubble (`CameraView.swift:442` `.padding(6) + .offset(y: -30)`) flips below thumb when within 40pt of top safe area.
   - Gallery grid: `GridItem(.adaptive(minimum: 100), spacing: 2)` (`GalleryView.swift:106`) adapts to `minimum: 140` at AX3+ (fewer, larger cells) so mono captions (if added) do not clip. Banner error text already clamps: `GalleryView.swift:125` `.lineLimit(2)`.

### Fallback

- If `UIFont(name:)` returns nil (future iOS removes Courier New): fall through to `.system(design: .monospaced)` automatically; layout unchanged because both use same `relativeTo` ramp.
- If text still overflows at AX5: truncate with `.lineLimit(1) + .truncationMode(.tail)` on chips only, never on error strings (`CameraView.swift:234` `Text(error.localizedDescription)` must wrap to 3 lines max, never truncate to one).

## 2. VoiceOver

### How a word-only control is announced

- Every tappable word is a real SwiftUI `Button`. Native Button carries button semantics automatically (platform behavior; cited Apple doc page returned title-only, so stated as engineering fact, not verbatim quote).
- Announcement pattern: `"{WORD}, button{, value}{, hint}"`. Example: `FLASH, button, Off`. Values reuse existing value contracts: `CameraView.swift:252` `value On / Off`; `:268` `value {selfTimer.label}` (`Off/3s/10s` at `CameraViewModel.swift:360-362` `"Off"/"3s"/"10s"`); `:211` `value Back / Front` (`CameraControls.swift:26` `"Back" / "Front"`); exposure slider `CameraView.swift:449` `label "Exposure compensation"` + `value "{ExposureCompensation label e.g. 0, +1 2/3, -2/3}"` with U+2212 minus (`CameraControls.swift:287` sign logic).
- Traits: `.isButton` on all word controls (countdown already has it: `CameraView.swift:476-491` `.accessibilityAddTraits(.isButton) + .accessibilityHint("Cancels the timer")` — keep). Selected chip adds `.isSelected`. Disabled-during-capture adds nothing spoken beyond dimmed + `isEnabled false` (see §10); do not announce "disabled" in label.
- Identifiers (do not rename — test contract): `preview-pinch-area` (`CameraView.swift:85`), `zoom-preset-{label}` (`:146`), `mode-{rawValue}` (`:164`), `gallery-thumbnail` (`:196`), `grid-toggle` (`:252`), `flash-toggle` (`:259`), `self-timer-toggle` (`:268`), `front-camera-toggle` (`:211`), `aspect-overlay` (`:392`), `exposure-slider` (`:449`), `self-timer-countdown` (`:489`), shutter label `Capture photo` (`Views/ShutterButton.swift:33` + test `SmokeLaunchTest.swift:124`), `zoom-indicator` (`ZoomIndicatorView.swift:16` value `e.g. 1.0x`), `grid-overlay` (`GridOverlayView.swift:41`), `library-grid` + `gallery-cell-\(index)` + `viewer-background`/`viewer-chrome-toggle`/`viewer-delete`/`viewer-back` (`GalleryView.swift:115/:120/:190/:199/:203/:210`). Gap to fix: shutter has label but NO identifier (`Views/ShutterButton.swift:31-33`); add `gallery-shutter` identifier without changing label `Capture photo` (test asserts label at `SmokeLaunchTest.swift:124`).

### Reading order

- Camera screen (top-to-bottom, trailing-to-leading within HUD to match visual): 1) status words `DNG · FLASH Off · TIMER Off · 4:3` (new DNG word-mark, non-interactive `accessibilityElement(.text)`), 2) `grid-toggle`, `flash-toggle`, `self-timer-toggle`, `front-camera-toggle`, 3) `zoom-indicator` (status, not action), 4) zoom chips, 5) aspect strip, 6) `exposure-slider` (only when visible), 7) `gallery-thumbnail`, 8) shutter `Capture photo`, 9) flip. Enforce with `.accessibilitySortPriority` on HUD cluster vs dock; preview itself is `accessibilityHidden(true)` except `preview-pinch-area` actions.
- Gallery: 1) `Library` title, 2) grid `library-grid` → cells `gallery-cell-N` in newest-first order (test contract `SmokeLaunchTest.swift:291` `gallery-cell-0` = newest), 3) bottom bar `gallery-latest-thumbnail`, trash (`GalleryView.swift:37` `.foregroundStyle(.red)` + `:39` `.disabled(library.selectedCapture == nil)`), camera (`:43` `.foregroundStyle(.yellow)`). Viewer: 1) `DNG Viewer`, 2) image (label `"DNG photograph, framing {aspect} at {zoom}"`), 3) eye toggle, 4) delete, 5) `Back to Camera` (`GalleryView.swift:208` `"Back to Camera"`).

### Custom actions (no gesture may be the only path)

| Gesture-only today | Button/slider equivalent (ships in this spec) |
|---|---|
| Tap-to-meter (`CameraView.swift:79` `onTap(point)`) with zero reticle | Add visible reticle (see §3) + `Focus reset` Button in HUD (label `FOCUS RESET`, resets to center `(0.5,0.5)`) |
| EV vertical drag (`CameraView.swift:430` `DragGesture(minimumDistance: 0)`) | Keep slider + add `− / +` stepper (1/3 EV steps, same `ExposureCompensation` model `minThird -9/maxThird 9` at `CameraControls.swift:250-251`) reachable by swipe navigation |
| Pinch zoom (`CameraView.swift:58` `.gesture(pinchGesture)`; `VolumeButtonCaptureView` excluded) | Zoom chips `1.0x/2.0x/5.0x` (`CameraControls.swift:222-227` presets) + stepper; chips are the accessible path |
| Countdown tap-cancel (`CameraView.swift:488` `.onTapGesture(perform: onCancel)`, comment claims fullscreen but hit area is only padded disc `:480-488`) | Countdown is a Button with hint `Cancels the timer`; shutter during countdown also cancels (`CameraViewModel.swift:251-253` second-press cancels) and announces `Timer cancelled` |
| Viewer single-tap chrome toggle (`GalleryView.swift:183` `.onTapGesture { chromeHidden.toggle() }` with first-tap swallow `hasConsumedOpeningTap`) | Eye button (`GalleryView.swift:197` `eye.slash/eye`) + `Done`-equivalent `Back to Camera`; never leave hidden-chrome as the only exit (current hidden state has zero visible affordance — flag as defect, fix by keeping a 44pt `SHOW` word visible at AX sizes) |
| Double-tap/pinch/swipe in viewer | Viewer today has none of these (`GalleryView.swift:141-248` tap-toggle only); this spec does NOT add them silently — if added later, each gets a button: `Zoom 1x/2x`, `Previous/Next`, `Done`. Until then, viewer is fit-only and spec says so |

NN/g basis for always-visible words (no hover/long-press reveal): `https://www.nngroup.com/articles/icon-usability/`.

## 3. Contrast over LIVE PREVIEW (hard requirement)

### Mechanism: rule-bounded strip + scrim, never bare words

Bare white words over an unpredictable photograph cannot meet any ratio. Do not ship bare overlay text.

- **HUD + chips + dock words** sit on a single bottom-anchored treatment, not scattered pills:
  - Full-width strip behind zoom chips / aspect strip / dock: `Color.black.opacity(0.55)` (same value family as existing `CameraView.swift:384` `Color.black.opacity(0.55)` mask bands, `:443` `.black.opacity(0.55)` bubble, `:485` `.black.opacity(0.6)` countdown disc), height = content + 16pt, extended into `safeAreaInset(bottom)` background. Top edge bounded by a 1pt rule `Color.white.opacity(0.25)` — same token as existing aperture border `CameraView.swift:389` `.white.opacity(0.25), lineWidth: 1`.
  - Top status words (`DNG · FLASH · TIMER · 4:3`) sit on a top gradient scrim `Color.black.opacity(0.55) → .clear`, `~88pt` tall, behind status bar + HUD cluster (existing HUD disc `CameraHUDButton.swift:21` `.black.opacity(0.45)` 44×44 is retained underneath for extra lift).
  - This satisfies the platform legibility pattern (material-or-gradient behind text over imagery) as engineering practice; the HIG Materials URL returned title-only so no verbatim quote is claimed.
- **Contrast requirement the treatment must meet:**
  - Normal words (13pt HUD, 12–13pt chips): **4.5:1** white text vs the scrim-backed composite, measured with Accessibility Inspector on three reference frames: white-sky, black-night, busy-texture. Per `https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html` (`at least 4.5:1` / `at least 3:1` at `18pt or 14pt bold`).
  - Large words (countdown 96pt): **3:1** minimum (`CameraView.swift:483` `.foregroundStyle(.white)` on `:485` `.black.opacity(0.6)` passes; keep).
  - Non-text indicators (reticle, grid, aperture border, selected-chip fill): **3:1 against adjacent colors** per `https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html`.
- **Reticle (new, fixes missing state):** 72pt square outline (design choice — Apple documents no pt size; bundle admits this), `Color.white` 1.5pt stroke + `Color.black.opacity(0.55)` 4pt outer glow (two stacked strokes, no blur material), plus `SUN −/+` word to its trailing side in 12pt mono. Auto-dismisses on next tap / mode change / capture; never persists as state. Selected-state chip uses true inversion inside the strip: `Color.white` fill + `Color.black` text (passes 3:1 state cue; yellow `Color.yellow` current chips at `CameraView.swift:142/:161` are removed in Margiela skin — yellow reserved for nothing on camera).
- **Exposure slider:** track `CameraView.swift:418` `Color.black.opacity(0.45)` 5pt capsule retained; tick dots `:423` `Color.white.opacity(0.75)` raised to `0.9` inside scrim; value text `:441` `.foregroundStyle(.yellow)` changed to `.white` on `:443` `.black.opacity(0.55)` bubble (yellow-on-translucent fails 4.5:1 on bright frames). Bubble text 12pt mono bold + `.monospacedDigit()`.

### Fallback

- If inspector still fails on a frame (e.g. pure-white snow at max brightness): strip opacity steps to `0.75` automatically under Increase Contrast (see §4); no per-frame dynamic sampling ships in v1 (no luminance-meter dependency).
- `Reduce Transparency` ON: replace gradient with solid `Color.black.opacity(0.85)` top bar 88pt + solid bottom strip (see §4).

## 4. Contrast in the WHITE ROOM (gallery/permissions)

- **Text colors:** background `Color.white`, ink `Color.black`, secondary `Color(hex: 0x595959)` minimum for 4.5:1 on white (author calculation from WCAG ratio, not a WCAG quote — verify with inspector). Large 18pt+ words may use `#767676` for 3:1 (same caveat). Hairlines `Color(hex: 0xE5E5E5)` 1/displayScale (see §8 device notes for `1/displayScale` technique; Divider has no documented 1px contract — stated as engineering inference, not Apple quote).
- **Hairline survival:** 1px `#E5E5E5` rules on white pass non-text 3:1 only as boundaries, not as text. Rules are never the sole state cue: selected row = `Color.black` fill + `Color.white` text (inversion) + underline, never gray-on-gray. Basis: NN/g + WCAG non-text 3:1 URLs above.
- **Increase Contrast ON** (`@Environment(\.colorSchemeContrast)`): rules step `1px #E5E5E5 → 2px Color.black` (light) / `Color.white` (dark); secondary text steps to `Color.black`/`Color.white`; chip unselected fill steps from `.black.opacity(0.5)` to solid with white 2pt outline. Exact 2px value is a design choice — no Apple source mandates it (bundle invention flagged; kept as explicit choice, tested on-device).
- **Reduce Transparency ON:** replace every `.ultraThinMaterial` (gallery banner `GalleryView.swift:131` `.background(.ultraThinMaterial)` + `:132` `RoundedRectangle(cornerRadius: 8)` → square `cornerRadius: 0` in Margiela skin) with opaque `Color.white` (gallery) / `Color.black` (camera strip) + 1pt rule. Camera HUD discs (`.black.opacity(0.45)`) become opaque `.black`.
- Current forced-dark gap: gallery/viewer have NO light treatment (`GalleryView.swift:69` force-dark). White-room spec ships a real light appearance (above) alongside dark; do not keep force-dark once this section lands (see §6).

## 5. Reduce Motion

| Motion today | Reduce Motion ON replacement |
|---|---|
| Slider fade `CameraView.swift:51` `.transition(.opacity)` + `:96/:100` 0.2/0.25s ease | Instant appear/disappear, no fade (`.transition(.identity)`) |
| Shutter press `Views/ShutterButton.swift:42` 0.15s scale 0.9 | No scale; state change only (veil opacity instant). Basis for scale value: file line, not convention |
| Countdown tick (`CameraViewModel.swift:318` `.seconds(1)` loop, instant number swaps, no tick animation) | Keep instant swaps (already motion-safe); add spoken `3, 2, 1` via `accessibilityAnnouncement` instead of visual pulse |
| Live scale readout during pinch (no magnifier today: `CameraView.swift:286` no-feedback pinch) | No animated magnifier; `zoom-indicator` text (`ZoomIndicatorView.swift:13` `.padding(.horizontal, 10) + .padding(.vertical, 4)` capsule) updates discretely to nearest 0.1x, no spring |
| Gallery cover (system `fullScreenCover`, no duration) | Respect system Reduce Motion (sheet becomes fade/cut); add no custom slide |
| Blinking record/state glyph (web blink 0.6s/1s cited in research but UNVERIFIED in fetched CSS — downgraded) | Forbidden in app regardless: no decorative blink; recording-adjacent states use static word + numeric readout |

Honest-motion rule: motion must never be required to operate the interface (platform best practice; cited HIG page title-only, stated as practice not quote).

## 6. Dark mode: what the white room means

**Decision: honour both appearances; the white room is the light appearance, not the only appearance.**

- The design is defined as white-room (white bg, black text, hairlines). Dark appearance is its exact inverse: bg `Color.black`, text `Color.white`, rules `Color(white: 0.2)` (`#333333` family), secondary `Color(white: 0.7)`.
- Implement with semantic colors (`Color(uiColor: .systemBackground)` / `.label` / `.secondaryLabel`) or asset-catalog light/dark variants. Never hard-code `.white`/`.black` for text surfaces (hard-coded colors break dark mode — platform fact, cited HIG page title-only so stated without verbatim quote).
- **Justification:** camera preview is inherently dark (`CameraView.swift:26` black base; aperture masks `CameraView.swift:384/:386` black 0.55); forcing white chrome over it at night fails contrast and battery. Gallery DNGs are viewed on black today (`GalleryView.swift:14` `Color.black.ignoresSafeArea()`, viewer `:163` same). A white-only app would render black-on-black the moment iOS darkens the system.
- **Code conflict to resolve:** today the app forces dark twice (`PikicamApp.swift:24`, `GalleryView.swift:69`). Keeping both forces after this spec ships reintroduces the white-room failure (permissions `Welcome to pikicam` at `RootView.swift:67` + `Honest photographs…` at `:70` would never show light). Remove both `preferredColorScheme(.dark)` lines when the semantic palette lands; keep dark-tuned camera strip (§3) in both appearances (camera strip stays black-translucent even in light mode — viewfinder legibility overrides room color).
- Red reserved: error text `CameraView.swift:236` `.foregroundStyle(.red)` + gallery trash `:37` `.foregroundStyle(.red)` stay red in both modes. Never use red for normal shutter (deliberate inversion of Blackmagic `red = normal recording` at `https://www.blackmagicdesign.com/products/blackmagiccamera` — pikicam is stills-only; red means failure/interruption only).

## 7. RTL

- All rules/stacks/paddings use `.leading`/`.trailing`, `Alignment.leading`, never `.left`/`.right` or fixed x-offsets. Bottom dock order mirrors automatically under `.rightToLeft` (thumbnail ↔ flip swap sides — correct).
- Do NOT mirror: camera preview layer itself, clock/timer numerals (`3s/10s`), exposure fractions (`+1 2/3` with U+2212 minus), zoom factors (`1.0x` POSIX at `CameraControls.swift:96-97` `String(format: "%.1fx", locale: en_US_POSIX…)`), DNG filename (`pikicam-\(uuid).dng` at `PhotoLibraryManager.swift:886` per test contract `pikicam-\(capture.id.uuid.uuidString).dng`).
- What breaks in a rule-and-word system: left-aligned exposure stack traces, `−/+` stepper order, underline-selected tab order. Fix: stepper uses `HStack` with automatic mirroring (minus stays leading in LTR, trailing in RTL — operation unchanged); numeric readouts keep `.monospacedDigit()` + `.environment(\.layoutDirection, .leftToRight)` override on the readout alone.
- Test with Locale `ar` + `layoutDirection .rightToLeft`; CJK/Arabic fallback inside Courier New is undocumented — needs device test (bundle open question stands). Fallback: system mono handles shaping; word labels are short uppercase nouns (`GRID/FLASH/TIMER`), never sentences, so shaping risk is minimal.

## 8. Device classes

> Bundle point-size citations (`375×667 SE`, `440×956 Pro Max`, iOS 26 floor `iPhone 11/SE 2nd gen`) cited dead/wrong URLs (`iphone-16/specs` shows only 6.1-inch; `support 122266` 404s). Treat all sizes below as PROVISIONAL test matrix, not Apple-quoted fact. iPhone 17 Pro simulator target has no inventory data — listed as unmeasured.

| Class | Logical canvas (provisional) | Type/layout delta |
|---|---|---|
| Smallest supported: iPhone SE 2nd/3rd gen | 375×667pt @2x | HUD words 12pt (down from 13pt); chips scroll horizontally; dock insets `.horizontal 16 / .bottom 24` (tighter than `CameraView.swift:217` 20/32); countdown 72pt max |
| Baseline: iPhone 16 / 17 Pro (simulator target) | ~393×852pt @3x (measure on iOS 26 simulator before lock) | Spec default: HUD 13pt, chips 13pt, countdown 96pt, shutter 80/64/56 (`ShutterButton.swift:17/:22`), thumbnail 60×58, dock 20/32 |
| Largest: iPhone 16 Pro Max | 440×956pt @3x (via 1320×2868 math — provisional) | HUD 14pt; grid `minimum: 120` (more columns); countdown 96pt uncapped to 120pt; exposure track 220pt full |

- Safe area: controls inside `safeAreaInset(bottom)` / `safeAreaLayoutGuide`; backgrounds extend behind home-indicator zone. Never hard-code 34pt spacer or fixed bottom offset (platform practice; cited UIKit page 404'd, stated without verbatim quote). HUD cluster fixed padding (`CameraView.swift:274-275` top-8/trailing-20) gains `+ safeAreaInsets.top` at runtime — current overlap with Dynamic Island is an unlisted defect, fixed here.
- Hairlines: `Rectangle().frame(height: 1/displayScale)` via `@Environment(\.displayScale)` (1pt @1x, 0.5pt @2x, ~0.33pt @3x), colors `#E5E5E5` light / `#333333` dark. `Divider()` has no documented 1px contract (confirmed in negative — doc page title-only).
- Replaced-icon reasoning set (never rendered): `camera, camera.viewfinder, camera.shutter.button, camera.aperture, photo/photo.fill, photo.stack, photos, rectangle.stack` — catalog page `https://developer.apple.com/sf-symbols/` lists no per-symbol names (verified generic only); word `SHOOT` replaces shutter, `STACK` replaces grid/library where words are needed.

## 9. Haptics (touch feedback in place of visual feedback)

No haptics ship today. Add these exact generators (all SwiftUI-native, no deps):

- Shutter press → `.sensoryFeedback(.impact(weight: .medium), trigger: phase)` on entering `.capturing`. Pairs with existing press scale (`ShutterButton.swift:42` 0.15s 0.9) and veil (`:25-27` black 0.3).
- Countdown tick → `.sensoryFeedback(.selection, trigger: selfTimerRemaining)` each 1s tick (`CameraViewModel.swift:318` `.seconds(1)`).
- Capture success (phase returns idle after `libraryModel.save`) → `.sensoryFeedback(.success, trigger: savedCaptureID)`. Failure → `.sensoryFeedback(.error, trigger: error)`. Never show `saved` until phase is idle (journaled save contract: pending-before, stored-only-after-success at `PhotoLibraryManager.swift:287-359` — verified).
- EV snap on drag release (snap to 1/3 stops: `CameraView.swift:430` drag commits snapped) → `.sensoryFeedback(.increase/decrease, trigger: exposureThirds)`; clamped-at-limit → `.sensoryFeedback(.warning, …)` (replaces today's silent clamp at `CameraView.swift:286` pinch / EV extremes).
- Pinch clamped at `zoomRange` limit → light impact once per limit-hit (fixes silent-limit defect).
- Respect system Haptics toggle: all feedback via `sensoryFeedback` honours it automatically; add no custom `UIFeedbackGenerator` bypass.

## 10. Reduce Motion + capture flow; volume-button shutter accessibility

- **Capture phases** (`CameraViewModel.swift:20-29` `idle/countdown/capturing/savingDNG`; `hasRequiredAuth` gate at `:48-51` `cameraAuthStatus == .authorized && (photoAuthStatus == .authorized || .limited)`):
  - `idle` = white shutter enabled, all word controls enabled.
  - `countdown` = numeric seconds + `Tap to cancel` word (Button, hint already `Cancels the timer`); second shutter press cancels (`CameraViewModel.swift:251-266` cancels on countdown, breaks on capturing/savingDNG — verified). Under Reduce Motion: numbers swap instantly, no scale/pulse; cancel is instant (`cancelCapture` at `:332-339`).
  - `capturing` = shutter dim veil + disabled (`Views/ShutterButton.swift:31` `.disabled(isCapturing)`); all HUD/chips/flip/grid/EV silently no-op via `guard phase == .idle` (`CameraViewModel.swift:160/:175/:188/:205/:211/:217/:230/:241` — verified) BUT render fully enabled (no `.disabled` except shutter — flagged defect). Fix: apply `.disabled(phase != .idle) + .opacity(phase != .idle ? 0.4 : 1)` to every non-shutter control; VoiceOver then reports dimmed correctly.
  - `savingDNG` = thumbnail-area spinner + disabled shutter; completion = re-enabled (`SmokeLaunchTest.swift:260` `isEnabled == true`, timeout 120s). Under Reduce Motion: spinner becomes static `SAVING…` word (no rotation).
  - Watchdog: `PhotoCapture.swift:34` `.seconds(15)` timeout → `The photo capture did not complete in time.` (`CaptureService.swift:755`); 1x-settle `CaptureService.swift:530` `250_000_000` (250ms) FOV snap at zoom>1 is visible snap with no explanation — under Reduce Motion keep the snap (honesty over smoothness) and label it `FRAMING 1X` during the 250ms.
- **Volume-button shutter:** hidden zero-frame host (`VolumeButtonCaptureView.swift:18` `view.frame = .zero` + `:19` `view.isHidden = true` + `:17` `showsVolumeSlider = false`); debounce `VolumeButtonCaptureView.swift:53` `minTriggerInterval = 0.6` (holding fires ONE capture, not burst); delta `VolumeButtonCaptureView.swift:62` `abs(current - lastVolume) > 0.001`; retry `VolumeButtonCaptureView.swift:35` `asyncAfter(+0.1)` ×10. Header states system volume HUD shows and volume audibly changes (`VolumeButtonCaptureView.swift:9-11`).
  - Accessibility status: volume buttons are NOT the accessible path. The on-screen shutter (`Capture photo` label) + countdown-cancel Button + full keyboard/switch-control operability of every word Button is the accessible path. iOS `Settings → Camera → Use Volume Up for Burst` remaps Volume-Up-hold to burst; pikicam's 0.6s throttle diverges from system burst when that setting is ON — spec states the divergence explicitly: pikicam never bursts (DNG-only single exposure; `isAppleProRAWEnabled = false` at `CaptureService.swift:679` with comment `Disable Apple ProRAW to get pure Bayer` at `:676-680`, verified). Surface the divergence in the DNG education sheet (tappable `DNG` word-mark → sheet: `Bayer DNG · ProRAW off · single exposure · no burst`).
  - Volume-hold beyond 0.6s is silently swallowed (no burst indicator — by design, stated here so tests assert it).

---

### Open / must-measure before lock (bundle gaps, not spec)

1. On-device pt/type/color tokens for shutter/thumbnail/chips on iOS 26 release build (Apple publishes none; bundle admits).
2. AE/AF LOCK persistence, exposure auto-dismiss seconds (code today `CameraView.swift:98` 2500ms; convention undocumented).
3. Gallery gutter/iPad columns, chrome auto-hide timer, swipe-dismiss physics, date headers/sort, verbatim Bayer-DNG viewer strings (no verified source).
4. `camera.shutter.button` / `camera.aperture` availability versions (catalog-app check needed).
5. Courier New CJK/Arabic fallback + SE-4th-gen/16e point sizes + Dynamic Island depths (runtime `safeAreaInsets`, not spec constants).
6. CIRAWFilter neutral tone-map disclosure + DNG preview-payload shape + P3/gamma badge (needs `CIRAWZeroProcessor.swift:63-81` recipe pin vs iOS 26 SDK + sample DNG dump).
