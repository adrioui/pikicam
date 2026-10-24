# pikicam DESIGN SYSTEM SPECIFICATION — Token Layer (`.P.DESIGN`)

## 0. Authority, status, and what this spec replaces

### 0.1 Code is the only authority on what exists

This spec REPLACES current code. It does not describe it.

Current camera surface, verified by Read:

- Root is `Color.black.ignoresSafeArea()` — `pikicam/Features/Camera/CameraView.swift:26` (`Color.black.ignoresSafeArea()`).
- Zoom chips are `Capsule()` pills with yellow selected fill — `pikicam/Features/Camera/CameraView.swift:144` (`.clipShape(Capsule())`), `pikicam/Features/Camera/CameraView.swift:142` (`Color.yellow : Color.black.opacity(0.5)`), type `pikicam/Features/Camera/CameraView.swift:133` (`.font(.system(size: 13, weight: .bold, design: .rounded))`).
- Aspect strip is the same capsule/yellow pattern — `pikicam/Features/Camera/CameraView.swift:162` (`.clipShape(Capsule())`), `pikicam/Features/Camera/CameraView.swift:161` (`.yellow : .black.opacity(0.5)`), type `pikicam/Features/Camera/CameraView.swift:157` (`.font(.system(size: 12, weight: .bold, design: .rounded))`).
- Thumbnail plate is rounded — `pikicam/Features/Camera/CameraView.swift:178` (`RoundedRectangle(cornerRadius: 8)`), `60x58` at `pikicam/Features/Camera/CameraView.swift:180` (`.frame(width: 60, height: 58)`); loaded clip is `pikicam/Features/Camera/CameraView.swift:321` (`RoundedRectangle(cornerRadius: 6)`).
- HUD buttons are white glyph on translucent black circle with rounded caption — `pikicam/Features/Camera/CameraHUDButton.swift:21` (`.background(.black.opacity(0.45), in: Circle())`), `pikicam/Features/Camera/CameraHUDButton.swift:18` (`.font(.system(size: 17, weight: .medium))`), `pikicam/Features/Camera/CameraHUDButton.swift:23` (`.font(.system(size: 11, weight: .medium, design: .rounded))`).
- Shutter is circles: outer `pikicam/Features/Camera/Views/ShutterButton.swift:16` (`.strokeBorder(.white, lineWidth: 4)`), `pikicam/Features/Camera/Views/ShutterButton.swift:17` (`.frame(width: 80, height: 80)`); inner `pikicam/Features/Camera/Views/ShutterButton.swift:21` (`.fill(.white)`), `pikicam/Features/Camera/Views/ShutterButton.swift:22` (`.frame(width: 64, height: 64)`); capturing veil `pikicam/Features/Camera/Views/ShutterButton.swift:27` (`.opacity(isCapturing ? 0.3 : 0)`).
- Grid is `pikicam/Features/Camera/GridOverlayView.swift:37` (`.stroke(.white.opacity(0.6), lineWidth: 0.7)`); thirds fractions are `pikicam/Features/Camera/CameraControls.swift:107` (`static let lineFractions: [CGFloat] = [1.0 / 3.0, 2.0 / 3.0]`).
- Aperture mask is `pikicam/Features/Camera/CameraView.swift:384` (`Color.black.opacity(0.55)` bands) with `pikicam/Features/Camera/CameraView.swift:389` (`.stroke(.white.opacity(0.25), lineWidth: 1)`); 4:3 branch is `pikicam/Features/Camera/CameraView.swift:394` (`Color.clear`).
- Exposure slider is `220pt` track at `pikicam/Features/Camera/CameraView.swift:48` (`.frame(height: 220)`), `5pt` capsule at `pikicam/Features/Camera/CameraView.swift:419` (`.frame(width: 5)`), dots `pikicam/Features/Camera/CameraView.swift:424` (`.frame(width: stop == 0 ? 7 : 4, height: stop == 0 ? 7 : 4)`), value bubble `pikicam/Features/Camera/CameraView.swift:440` (`.font(.system(size: 12, weight: .bold, design: .rounded))`) in `pikicam/Features/Camera/CameraView.swift:441` (`.foregroundStyle(.yellow))` on `pikicam/Features/Camera/CameraView.swift:443` (`.black.opacity(0.55)`).
- Countdown is `pikicam/Features/Camera/CameraView.swift:482` (`.font(.system(size: 96, weight: .bold, design: .rounded))`), `pikicam/Features/Camera/CameraView.swift:483` (`.foregroundStyle(.white)`), on `pikicam/Features/Camera/CameraView.swift:485` (`.black.opacity(0.6)`) clipped at `pikicam/Features/Camera/CameraView.swift:486` (`.clipShape(Circle())`).
- Gallery is currently a BLACK room: `pikicam/Features/Gallery/GalleryView.swift:14` (`Color.black.ignoresSafeArea()`), forced dark at `pikicam/Features/Gallery/GalleryView.swift:69` (`.preferredColorScheme(.dark)`), grid `pikicam/Features/Gallery/GalleryView.swift:106` (`GridItem(.adaptive(minimum: 100), spacing: 2)], spacing: 2)`), cells `pikicam/Features/Gallery/GalleryView.swift:113` (`.aspectRatio(1, contentMode: .fit)`), toolbar accents `pikicam/Features/Gallery/GalleryView.swift:37` (`.foregroundStyle(.red)`) and `pikicam/Features/Gallery/GalleryView.swift:43` (`.foregroundStyle(.yellow)`), banner `pikicam/Features/Gallery/GalleryView.swift:131` (`.background(.ultraThinMaterial)`) clipped at `pikicam/Features/Gallery/GalleryView.swift:132` (`RoundedRectangle(cornerRadius: 8)`).
- Viewer is currently black with icon chrome: `pikicam/Features/Gallery/GalleryView.swift:163` (`Color.black.ignoresSafeArea()`), title `pikicam/Features/Gallery/GalleryView.swift:194` (`"DNG Viewer"`), icons `pikicam/Features/Gallery/GalleryView.swift:197` (`chromeHidden ? "eye.slash" : "eye"`) and `pikicam/Features/Gallery/GalleryView.swift:201` (`"trash"`), action `pikicam/Features/Gallery/GalleryView.swift:208` (`"Back to Camera"`).
- Permissions interstitials are the only non-camera/gallery surface: `pikicam/App/RootView.swift:62` (`VStack(spacing: 24)`), hero `pikicam/App/RootView.swift:63` (`Image(systemName: "camera.aperture")`) at `pikicam/App/RootView.swift:64` (`.font(.system(size: 72))`), title `pikicam/App/RootView.swift:67` (`"Welcome to pikicam"`) in `pikicam/App/RootView.swift:68` (`.font(.largeTitle.bold())`), subtitle `pikicam/App/RootView.swift:70` (`"Honest photographs, one Bayer exposure at a time.\nNo AI. No computation. Just light."`), buttons `pikicam/App/RootView.swift:81` (`.buttonStyle(.borderedProminent)`) + `pikicam/App/RootView.swift:82` (`.controlSize(.large)`); denied copy at `pikicam/App/RootView.swift:96` (`"Permissions Required"`) and `pikicam/App/RootView.swift:99` (`"pikicam needs camera and photo library access to function.\nPlease grant these permissions in Settings."`).

All yellow/red/capsule/circle/rounded/ultraThinMaterial/icon instances above are ORDERED REMOVED by this spec. Nothing below inherits them.

### 0.2 Product facts this spec may rely on (verified)

- Zero-process is the only recipe — `pikicam/Features/Develop/CIRAWZeroProcessor.swift:19` (`Zero-process is the only recipe; there are no development modes.`), implemented as `CIRAWFilter(imageData:)` at `pikicam/Features/Develop/CIRAWZeroProcessor.swift:31` (`guard let filter = CIRAWFilter(imageData: dngData) else`), with the 15-entry neutral list at `pikicam/Features/Develop/CIRAWZeroProcessor.swift:63-81` (entries `baselineExposure/exposure/boostAmount/boostShadowAmount/shadowBias/localToneMapAmount/luminanceNoiseReductionAmount/colorNoiseReductionAmount/sharpnessAmount/detailAmount/moireReductionAmount/contrastAmount/extendedDynamicRangeAmount/lensCorrectionEnabled/gamutMappingEnabled`), deliberately retaining `pikicam/Features/Develop/CIRAWZeroProcessor.swift:8-13` (`Bayer demosaic / Black-level subtraction (from DNG tags) / Camera color matrix (from DNG tags) / White balance (from AsShotNeutral)`).
- Capture is single-phase: `pikicam/Features/Camera/CameraViewModel.swift:10-12` (`The camera has one mutually exclusive phase — idle, countdown, capturing, or savingDNG`), enum at `pikicam/Features/Camera/CameraViewModel.swift:20-29` (`case idle / case countdown / case capturing / case savingDNG`).
- Auth gate is camera-authorized plus Photos authorized-or-limited: `pikicam/Features/Camera/CameraViewModel.swift:48-51` (`cameraAuthStatus == .authorized && (photoAuthStatus == .authorized || photoAuthStatus == .limited)`).
- Flash is torch-pulse, not system flash: `pikicam/Features/Camera/CameraControls.swift:35-39` (`Pikicam captures pure Bayer RAW single exposures, which cannot use AVCapturePhotoSettings.flashMode … The honest RAW-compatible equivalent is the torch, used as a shutter-time pulse`); labels are `pikicam/Features/Camera/CameraControls.swift:64-65` (`"Off" / "On"`); position labels are `pikicam/Features/Camera/CameraControls.swift:26` (`"Back" / "Front"`); zoom label format is `pikicam/Features/Camera/CameraControls.swift:97` (`String(format: "%.1fx", locale: en_US_POSIX, factor)` e.g. `1.0x`).
- Owner rulings (input, not code): gallery AND viewer are a WHITE room; camera viewport stays black; shutter is a square hairline ring at 1pt with sharp corners; no rounding broadly; NO ICONS ANYWHERE, words only.

### 0.3 Research status: what is verified, what is not

- VERIFIED: Courier New is an iOS system font — https://developer.apple.com/fonts/system-fonts/ (returns `Courier New / Version 5.00.2x / iOS system font`). This grounds §1.
- VERIFIED: WCAG AA thresholds are 4.5:1 normal, 3:1 large, large = at least 18pt or 14pt bold — https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html. This grounds §2 contrast math. Hexes `#595959`/`#767676` in §2 are AUTHOR DERIVATIONS to meet those ratios, not WCAG quotes.
- VERIFIED: icon labels must stay visible at all times; do not rely on hover — https://www.nngroup.com/articles/icon-usability/ (returns `Icon labels should be visible at all times, without any interaction from the user`). Supports §7 word-always-visible rule.
- VERIFIED: `Font.custom(_:size:relativeTo:)` doc page exists but fetched title-only in this session — https://developer.apple.com/documentation/swiftui/font/custom%28_%3Asize%3Arelativeto%3A%29. The `relativeTo` = Dynamic Type scaling vs two-arg = fixed distinction is API behavior used in §1; no verbatim quote is claimed.
- REFUTED / UNVERIFIED — do not cite as authority: exact margiela.com hexes (`#FCFCFC/#F5F4F0/#E5E5E5/#6C6C6C`), `CourierNewRecast 500`, `006FE6` focus blue, `mm-btn-glyph-blink 0.6s`, `250ms/240ms/1s` motion values, Apple pt/type/color tokens for shutter/thumbnail/chips, support-article URL/quote pairings for tap/AE-AF/exposure/zoom/permissions, SF Symbols page as a per-symbol catalog. Where the bundle was silent or refuted, this spec MARKS values as PROPOSAL (owner-approved direction, implementer-pinned) rather than inventing provenance.
- Apple publishes no pt/type/color tokens for Camera chrome (bundle admits; no working Apple layout URL). Every pt below is therefore a PIKICAM PROPOSAL, buildable in SwiftUI on iOS 26 with no third-party dependencies, not an Apple parity claim.

---

## 1. TYPE

### 1.1 Typeface decision

- PRIMARY AND ONLY CHROME FACE: Courier New. Reach via `Font.custom("Courier New", size: X, relativeTo: Y)`. No bundling step. Rationale: only mono verified on the iOS system-fonts list — https://developer.apple.com/fonts/system-fonts/.
- FALLBACK STACK (in order): Courier New → Menlo → `.system(design: .monospaced)`. Never name `SF Mono` by string. Never ship a licensed Recast/Helvetica Now file. (Helvetica Now / CourierNewRecast are web-licensed families; they cannot ship under the no-third-party constraint.)
- SANS: forbidden in chrome. There is no second face. The earlier research note mapping display to Helvetica is REJECTED for pikicam: it describes commerce banners, not camera controls, and would read as shouting in a viewfinder.
- RTS: `Font.custom("Courier New", size:, relativeTo:)` MUST use the `relativeTo` overload for every UI string (map below). The two-arg overload is FORBIDDEN for UI text because it freezes under Dynamic Type.
- Fallback runtime check: if `UIFont(name: "Courier New", size:) == nil`, fall through the stack above. Courier New ships per the system-fonts page, so this path is defensive only.

### 1.2 Scale (pt = SwiftUI pt at default Dynamic Type; all scale via `relativeTo`)

| Token | Size / Weight | Tracking | Case | `relativeTo` | Use |
|---|---|---|---|---|---|
| `type-display` | 96, Bold | 0 | tabular numerals only | `.largeTitle` | Self-timer countdown numeral only. Replaces `pikicam/Features/Camera/CameraView.swift:482` (same 96 size, face changes rounded→Courier New Bold). |
| `type-title` | 17, Bold | +40/1000em (≈0.68pt at 17pt) | UPPERCASE | `.headline` | Section titles: `LIBRARY`, `DNG VIEWER`, permission titles. Replaces `pikicam/App/RootView.swift:68` (`.largeTitle.bold()`) — permissions titles drop to 17pt uppercase. |
| `type-body` | 14, Regular | 0 | Sentence case | `.body` | Explanatory copy only (permission subtitles, error bodies, delete messages). Keeps `pikicam/App/RootView.swift:71` (`.font(.body)`) size class, face changes to Courier New. |
| `type-label` | 13, Regular; Bold when selected | +80/1000em (≈1.04pt at 13pt) | UPPERCASE | `.callout` | ALL word-controls: `SHOOT, CANCEL, GRID, FLASH, TIMER, CAMERA, 4:3, 16:9, 1:1, 1.0X, BACK, LIBRARY, DELETE, RETRY`. Replaces `pikicam/Features/Camera/CameraView.swift:133` (13 bold rounded) and `CameraHUDButton` `pikicam/Features/Camera/CameraHUDButton.swift:23` (11 rounded). |
| `type-caption` | 11, Regular | +80/1000em (≈0.88pt at 11pt) | UPPERCASE | `.caption` | Readouts that are not taps: `DNG` word-mark, `OFF/ON` values when shown as status, exposure value when not interactive. |
| `type-tick` | 11, Regular, monospacedDigit | 0 | numerals + `X`, `+`, `−` (U+2212), `/3` | `.caption` | Numeric readouts: zoom `1.0X`, EV `+1 2/3`, countdown is NOT tick (display). Keeps POSIX `%.1fx` contract from `pikicam/Features/Camera/CameraControls.swift:97`. |

Notes:

- U+2212 minus for EV negatives is retained (byte-exact contract in tests); labels stay `0, +1, −2, +2/3, −1/3, +1 2/3, −2 1/3` spelled with U+2212.
- Countdown uses tabular figures; zoom/EV use `.monospacedDigit()` so `1.0X→2.5X` does not reflow.
- Permission hero `72pt` symbol at `pikicam/App/RootView.swift:64` is DELETED with all icons (§7); its space becomes the four-stitch tag (§2.5) set in `type-caption`.
- No italic anywhere. No weight other than Regular/Bold.

### 1.3 Exact Font API calls

- `Font.custom("Courier New", size: 96, relativeTo: .largeTitle).weight(.bold)` — countdown.
- `Font.custom("Courier New", size: 17, relativeTo: .headline).weight(.bold).tracking(0.68)` + `.textCase(.uppercase)` — titles.
- `Font.custom("Courier New", size: 14, relativeTo: .body)` — body.
- `Font.custom("Courier New", size: 13, relativeTo: .callout).tracking(1.04)` + `.textCase(.uppercase)` — controls; add `.weight(.bold)` when selected.
- `Font.custom("Courier New", size: 11, relativeTo: .caption).tracking(0.88)` + `.textCase(.uppercase)` — captions; numeric variant adds `.monospacedDigit()` and drops tracking to 0.

---

## 2. INK (two rooms)

### 2.1 Room assignment (owner-ruled)

- BLACK ROOM: camera viewport + all camera chrome + permission interstitials (camera context). Base is `pikicam/Features/Camera/CameraView.swift:26` retained.
- WHITE ROOM: gallery grid + full-screen viewer. This INVERTS current code (`pikicam/Features/Gallery/GalleryView.swift:14` black, `pikicam/Features/Gallery/GalleryView.swift:69` forced `.dark`): both become white-room with an explicit dark-appearance pair (§2.4).

### 2.2 Token table (name + value; no other color may appear)

BLACK ROOM (camera):

- `ink-black-bg` `#000000` — preview base, retained.
- `ink-black-ink` `#FFFFFF` — primary words.
- `ink-black-secondary` `White 60%` (`#FFFFFF @60%`) — status values (`OFF`, `1.0X` when unselected-readable, `DNG` mark).
- `ink-black-rule` `White 25%` (`#FFFFFF @25%`) — hairlines; equals current aperture border `pikicam/Features/Camera/CameraView.swift:389` (`.white.opacity(0.25)`), now the universal black-room rule.
- `ink-black-wash` `Black 55%` (`#000000 @55%`) — aperture mask bands; retained value from `pikicam/Features/Camera/CameraView.swift:384`.
- `ink-black-scrim` `Black 45%→0%` gradient, 88pt tall — legibility scrim behind top/bottom chrome over preview (localized, not fullscreen). Replaces per-control `black.opacity(0.45/0.5/0.6)` pills (`CameraHUDButton` `pikicam/Features/Camera/CameraHUDButton.swift:21`, `CameraView` `pikicam/Features/Camera/CameraView.swift:142`, countdown `pikicam/Features/Camera/CameraView.swift:485`) with ONE scrim layer + bare words.
- Selection WITHOUT accent: `ink-black-select-bg` `#FFFFFF`, `ink-black-select-ink` `#000000` — inversion only. Yellow (`Color.yellow` at `CameraView.swift:142,161`, `CameraHUDButton` n/a, `GalleryView.swift:43`) is DELETED. No yellow, no red for state.

WHITE ROOM (gallery + viewer):

- `ink-white-bg` `#FFFFFF`
- `ink-white-ink` `#000000`
- `ink-white-secondary` `#595959` — DERIVED to pass 4.5:1 on white per https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html. Not a house-observed hex.
- `ink-white-rule` `#000000` at 1px for primary divisions; `ink-white-rule-soft` `Black 10%` for intra-grid gutters.
- `ink-white-select-bg` `#000000`, `ink-white-select-ink` `#FFFFFF` — inversion only.
- Thumbnails: full-color photography. Chrome stays monochrome; photography carries color (observed luxury-pole pattern, not a hex claim).

### 2.3 Selection without an accent colour

- Selected = inverted block + underline + Bold. Unselected = plain Regular, no fill, no underline.
- Camera chips: selected = `ink-black-select-bg` with `ink-black-select-ink` text, `type-label` Bold; unselected = transparent, `ink-black-ink` Regular. (Replaces yellow/black capsule at `CameraView.swift:142`.)
- Gallery cell selected (multi-delete future; single-select now): 2px inset inversion frame (black 2px inner stroke on white room) + `type-caption` `SELECTED` tag under cell. Never a tint wash.
- Non-color cue is MANDATORY (underline/weight/numbering) so meaning survives Increase Contrast / Bold Text. Do not rely on inversion alone.

### 2.4 Dark appearance + contrast

- Ship explicit dark-appearance pairs: white room in dark = bg `#000000`, ink `#FFFFFF`, rules `White 25%` (`#333333` equivalent avoided as hard-code; use semantic token switch on `colorScheme`). Never hard-code `.white/.black` outside tokens or dark mode renders black-on-black.
- Gallery body text MUST meet 4.5:1 normal / 3:1 large (18pt or 14pt bold) per https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html. `#595959` on `#FFFFFF` is the darkest permitted secondary; `#767676` floor applies only to ≥18pt words.
- Overlay words NEVER sit bare on preview. Each gets the localized scrim (§2.2) or, when Reduce Transparency is on, an opaque backing bar (`Black 100%` strip, 44pt, behind the word row). Test on white-sky, black-night, busy-texture frames; verify with Accessibility Inspector, not eyeballing.
- Error/failure red is reserved EXCLUSIVELY for failure: `ink-fail` `#EA0000` on white, `#FF453A` on black (system red dark-side). Never for shutter, never for normal state. Current `pikicam/Features/Camera/CameraView.swift:236` (`.foregroundStyle(.red)`) placement is retained as failure-only; style becomes `type-body` + `ink-fail`, left-aligned, with `RETRY` word (§7).

### 2.5 House-mark (the only graphic)

- Blank tag: `64×20pt` white rectangle (black room) / black rectangle (white room), no wordmark, held by four `8×2pt` ticks. Render as `Rectangle` + four `Rectangle` ticks; no image asset. This is the permission-screen hero replacing `camera.aperture 72pt` at `pikicam/App/RootView.swift:63-64`, and the gallery navigation-title accessory replacing `"Library"`-only at `pikicam/Features/Gallery/GalleryView.swift:49`.
- Collective voice: `DEVELOPED COLLECTIVELY` in `type-caption`, no names, no avatars, no bylines. Permission subtitle keeps `pikicam/App/RootView.swift:70` sentence; append second line `DEVELOPED COLLECTIVELY`.
- Numbers as modes: circled line numbers in `type-tick` 17pt for aspect/mode rows (`0` capture, `1` gallery, `22` export preset future). Circle is a 1px ring, not a fill; active number inverts. Line-number taxonomy beyond 0/1/22 is retailer lore — do not print other numbers as house fact.

---

## 3. RULE (hairline system)

- WIDTH: exactly `1 / displayScale` pt via `@Environment(\.displayScale)` (`1pt @1x, 0.5pt @2x, 0.333pt @3x`). Implement as `Rectangle().frame(height: 1/displayScale)`. `Divider()` is FORBIDDEN (no one-physical-pixel contract).
- COLOUR: white room `ink-white-rule` (`#000000`) for section divisions, `ink-white-rule-soft` (`Black 10%`) for grid gutters; black room `ink-black-rule` (`White 25%`). Grid overlay keeps `0.7pt` ONLY as the live-framing exception at `pikicam/Features/Camera/GridOverlayView.swift:37` — new static chrome uses `1/displayScale`.
- WHERE: (a) below top bar (60pt bar, §5), (b) above bottom dock, (c) between viewer image and metadata row, (d) around the blank tag (tag border itself is the rule). Nowhere else. No boxes around buttons. No card outlines.
- UNDER INCREASE CONTRAST: rules step to `2px` solid (`ink-white-ink` on white / `ink-black-ink` on black); secondary text steps to primary ink. Never leave rules/secondary unchanged.
- BLACK vs WHITE: same width, mirrored color token; black-room rules sit ON the scrim, never bare on bright preview.

---

## 4. SHAPE

- PHILOSOPHY: no rounding. Radius `0` everywhere except the single deprecated countdown disc, which becomes a square.
- SHUTTER (owner-ruled): square hairline ring, `80×80pt` outer, `1pt` stroke (`ink-black-ink`), inner `64×64pt` square fill (`ink-black-ink`), sharp corners, flat, no gloss. Press = inner square scales `0.9` (keeps current `pikicam/Features/Camera/Views/ShutterButton.swift:41` `scaleEffect 0.9` timing `pikicam/Features/Camera/Views/ShutterButton.swift:42` `0.15` — duration retained, shape replaced). Capturing = inner square at `30%` opacity (retains `pikicam/Features/Camera/Views/ShutterButton.swift:27` value, square form). This REPLACES outer `Circle().strokeBorder(.white, 4)` + inner `Circle().fill(.white)` + `56` veil circles.
- SURVIVING RADII: none. `Capsule()` at `CameraView.swift:144,162`, `Circle()` at `CameraHUDButton.swift:21`, `RoundedRectangle(8)` at `CameraView.swift:178`, `RoundedRectangle(6)` at `CameraView.swift:321`, `RoundedRectangle(4)` at `GalleryView.swift:26`, `RoundedRectangle(8)` at `GalleryView.swift:132`, countdown `Circle()` at `CameraView.swift:486` — ALL DELETED (radius 0).
- AFFORDANCE REPLACEMENT: what radius used to signal (tappability, selectedness) is now carried by (1) underline on selected/active word, (2) inversion block, (3) `44pt` hit padding (§7). Shape never signals alone.
- GRID THUMBNAILS: square cells, `0` radius, `2pt` gutters retained from `pikicam/Features/Gallery/GalleryView.swift:106`. Toolbar thumbnail `60×50` at `pikicam/Features/Gallery/GalleryView.swift:25` becomes square `44×44` crop (no `RoundedRectangle(4)`).

---

## 5. SPACE

- BASE SCALE (pt): `2 / 4 / 8 / 12 / 16 / 20 / 24 / 32`. No other spacing value may appear. (Current `10/14/40` paddings at `CameraView.swift:138,49,168` are remapped into this scale: `10→8`, `14→16`, `40→32` + safe-area.)
- TOP BAR: `60pt` tall (starting metric from commerce header token; revalidate against safe area). Houses `DNG` mark left, `FLASH / TIMER / 4:3` words right, 1px rule below.
- BOTTOM DOCK: `88pt` tall above safe area; background transparent over scrim; insets `16pt` horizontal / `8pt` bottom on `375pt`-wide (SE) and `20pt` / `12pt` on `440pt`-wide (Pro Max). Dock order retained (thumbnail left / shutter center / flip right) with icon→word swap.
- MARGINS: `375×667pt` (SE, smallest) `16pt`; `393–430pt` (standard) `18pt`; `440×956pt` (Pro Max, largest) `20pt`. Point sizes are widely published device metrics used as test matrix only — not claimed from any Apple marketing URL (no citable Apple pt source exists).
- GRID: `2pt` gutters both axes (retained `GalleryView.swift:106`), `2pt` outer inset (retained `GalleryView.swift:118`), adaptive `100pt` minimum columns retained.
- COUNTDOWN: centered square `168×168pt` (96pt glyph + 24pt padding retained from `CameraView.swift:484`), square not circle.

---

## 6. MOTION

Status: durations below are PIKICAM PROPOSALS. Commerce `250ms/240ms/0.6s/1s` values in research are UNVERIFIED (fetches returned NOT FOUND) and are not cited.

- ALLOWED: opacity fades only. Slider appear `pikicam/Features/Camera/CameraView.swift:96` (`.easeInOut 0.2`) / disappear `pikicam/Features/Camera/CameraView.swift:100` (`.easeInOut 0.25`) collapse to ONE rule: `.opacity` + `.easeOut(duration: 0.2)` both ways. Shutter press keeps `.easeInOut(duration: 0.15)` from `ShutterButton.swift:42`. EV auto-dismiss keeps `2500ms` from `CameraView.swift:98` (`Task.sleep 2500ms`).
- FORBIDDEN: springs, slides, blinks, shimmer, skeleton shimmer, bounce, rubber-band constants, countdown tick animation (instant number swap retained). Blinking record/state glyphs are REJECTED (photosensitive + conflicts with torch-pulse semantics).
- REDUCE MOTION ON: all fades become instant (duration 0); state changes (selected/inverted/underlined, aperture mask, grid on/off) apply with no transition; countdown numerals swap with no animation. Motion is never required to operate the interface.
- Countdown tap-to-cancel hit area keeps `pikicam/Features/Camera/CameraView.swift:487` (`.contentShape(Rectangle())`) + `pikicam/Features/Camera/CameraView.swift:489-491` (`isButton` + `Cancels the timer`); shape becomes square.

---

## 7. CONTROL (word-only; NO ICONS ANYWHERE)

### 7.1 Vocabulary swap (1:1, words replace symbols; symbols never render)

- `SHOOT` replaces shutter (was circles); `CANCEL` replaces countdown tap (was number-only); `GRID ON/OFF`, `FLASH OFF/ON`, `TIMER OFF/3S/10S`, `CAMERA BACK/FRONT`, `4:3/16:9/1:1`, `1.0X/2.0X/5.0X`, `LIBRARY`, `VIEW`, `DELETE`, `RETRY`, `BACK TO CAMERA`, `DNG` (non-interactive mark). This deletes `photo.on.rectangle` (`CameraView.swift:190`), `arrow.triangle.2.circlepath.camera` (`CameraView.swift:210`), `square.grid.3x3[.fill]` (`CameraView.swift:250`), `timer/Timer.circle.fill` (`CameraView.swift:267`), `bolt.slash/bolt.fill` (`CameraView.swift:281-282`), `camera.aperture` (`RootView.swift:63`), `exclamationmark.triangle[.fill]` (`RootView.swift:92`, `GalleryView.swift:83`), `trash/camera/eye[.slash]/photo.fill` (`GalleryView.swift:36,42,197,201,99`).
- Labels stay visible at ALL times per https://www.nngroup.com/articles/icon-usability/. Never hover/long-press to reveal. Obscure words fail like obscure icons — test `DEVELOP` vs numeric codes before adding either.
- Disclosure uses `+/-` text glyphs, not chevrons.

### 7.2 States (both rooms; concrete)

BLACK ROOM (example `FLASH`):

- Rest: `type-label` Regular, `ink-black-ink`, no fill, no underline, on scrim.
- Pressed: `opacity 0.6` while pressed + `scale 1.0` (no shrink except shutter `0.9`); instant restore on release.
- Selected/On: `type-label` Bold, `ink-black-select-ink` on `ink-black-select-bg` block + underline `1/displayScale`.
- Disabled (phase ≠ idle, flash unavailable): `ink-black-secondary`, no fill, no underline; layout slot HELD (fixes current reflow where `CameraView.swift:256` `if flashAvailable` vanishes — replace with disabled placeholder).

WHITE ROOM (example `DELETE`):

- Rest: `type-label` Regular, `ink-white-ink`, no fill.
- Pressed: `opacity 0.6`.
- Selected: Bold + `ink-white-select-ink` on `ink-white-select-bg` + underline.
- Disabled (e.g. trash with no selection, cf. `GalleryView.swift:39` `.disabled(selectedCapture == nil)`): `ink-white-secondary`, same slot, no fill.

### 7.3 44pt target with 11–13pt glyphs

- Every word-control is a real SwiftUI `Button` (carries `.isButton`; triggers VoiceOver label+button). Custom tap views are FORBIDDEN; where one survives (countdown), it keeps `.accessibilityAddTraits(.isButton)` per `CameraView.swift:490`.
- Visible glyph `11–13pt`; hit area padded to `min 44×44pt` via `.frame(minWidth: 44, minHeight: 44)` + `.contentShape(Rectangle())`. Hairline rule itself is never the hit area. (Retains the `44×44` HUD hit pattern at `CameraHUDButton.swift:20` while deleting its circle.)
- EV slider keeps `40pt` column (`CameraView.swift:437`), `220pt` height (`CameraView.swift:48`), `DragGesture(minimumDistance: 0)` (`CameraView.swift:430`); add `+/-` stepper buttons (`type-label`) as the accessible equivalent. Pinch keeps chips + stepper; volume shutter keeps on-screen `SHOOT`; viewer keeps `BACK TO CAMERA` + prev/next words (prev/next are currently missing — added here).

---

## 8. DELIVERY — one layer views opt into (lint-enforced)

### 8.1 API surface (SwiftUI, iOS 26, zero dependencies)

```swift
enum Room { case black, white }
enum InkToken { case bg, ink, secondary, rule, ruleSoft, wash, selectBg, selectInk, fail }
enum TypeToken { case display, title, body, label, caption, tick }

struct MargielaTheme: EnvironmentKey { var room: Room }
extension EnvironmentValues { var margielaRoom: Room }

struct MargielaType: ViewModifier {
  let token: TypeToken; let selected: Bool = false
  func body(content: Content) -> some View {
    content.font(MargielaFont.font(for: token, selected: selected))
      .tracking(MargielaFont.tracking(for: token))
      .textCase(MargielaFont.textCase(for: token))
      .foregroundStyle(MargielaInk.color(.ink, in: room))
  }
}
struct MargielaRule: View { let tone: RuleTone /* primary|soft */; var body: some View {
  Rectangle().frame(height: 1 / displayScale) /* displayScale from @Environment */
}}
struct WordControl: View {
  let word: String; let selected: Bool; let disabled: Bool; let action: () -> Void
  var body: some View { Button(action: action) { Text(word)
    .modifier(MargielaType(token: .label, selected: selected))
    .underline(selected)
    .padding(.horizontal, 12).padding(.vertical, 6)
    .background(selected ? selectBg : .clear) /* radius 0 */
    .frame(minWidth: 44, minHeight: 44) }
    .contentShape(Rectangle()).disabled(disabled) }
}
```

### 8.2 Enforcement (lint test to be written in `.P.IMPLEMENTATION`)

A view CANNOT accidentally violate the system because:

1. Raw `.font(.system(design: .rounded))`, `Capsule()`, `Circle()` (decorative), `RoundedRectangle`, `.yellow`, `.red` (outside fail), `Image(systemName:)` in chrome, `Divider()`, two-arg `Font.custom` without `relativeTo`, and hard-coded `.white/.black` outside `MargielaInk` are all lint FAILURES (allowlist: photography `Image(uiImage:)`, scrim gradients, four-stitch tag rects).
2. Every tappable word must be `WordControl` or `Button` + `MargielaType(.label)` + `min 44×44` + underline-on-selected; the lint asserts `accessibilityIdentifier` + `accessibilityLabel/Value` presence (current gaps: shutter has label at `ShutterButton.swift:33` but no identifier; viewer spinners lack identifiers).
3. Every screen snapshot test renders both rooms + Increase Contrast + Reduce Transparency + Reduce Motion + XXXL Dynamic Type at `375pt` and `440pt` widths; white-room asserts ≥4.5:1 / ≥3:1-large per https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html.

### 8.3 What `.P.IMPLEMENTATION` must do (out of scope here, flagged)

Migrate: shutter circles→square ring; capsules→bare words + inversion; yellow/red washes→inversion + `ink-fail`-only; black gallery/viewer→white room + dark pairs; icons→words; `ultraThinMaterial` banner (`GalleryView.swift:131`)→hairline + words; flash-vanish reflow (`CameraView.swift:256`)→disabled placeholder; add prev/next words, EV stepper, scrim layer, tag mark, and the lint test above.

Files: `/Users/adrifadilah/Desktop/pikicam/pikicam/Features/Camera/Views/ShutterButton.swift`, `/Users/adrifadilah/Desktop/pikicam/pikicam/Features/Camera/CameraView.swift`, `/Users/adrifadilah/Desktop/pikicam/pikicam/Features/Camera/CameraHUDButton.swift`, `/Users/adrifadilah/Desktop/pikicam/pikicam/Features/Camera/ZoomIndicatorView.swift`, `/Users/adrifadilah/Desktop/pikicam/pikicam/Features/Camera/GridOverlayView.swift`, `/Users/adrifadilah/Desktop/pikicam/pikicam/Features/Camera/CameraControls.swift`, `/Users/adrifadilah/Desktop/pikicam/pikicam/Features/Camera/CameraViewModel.swift`, `/Users/adrifadilah/Desktop/pikicam/pikicam/Features/Develop/CIRAWZeroProcessor.swift`, `/Users/adrifadilah/Desktop/pikicam/pikicam/Features/Gallery/GalleryView.swift`, `/Users/adrifadilah/Desktop/pikicam/pikicam/App/RootView.swift`.
