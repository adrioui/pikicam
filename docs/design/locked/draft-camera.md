# P.DESIGN — CAMERA SCREEN (pikicam) — LOCKED-READY SPEC

> **Status:** rewrite of `docs/design/spec-camera-screen-spec.md` against the owner rulings (2026-10-01) and every correction in `docs/design/VERIFICATION.md` §6 that touches this file. Supersedes the prior camera spec. Subordinate to `.P.DESIGN.md` §0.5 rulings; the code is the only authority on what exists (R1).

## 0. Authority, provenance, and what is NOT claimed

- **R1 — the code is the only authority.** Code cited below was opened with Read. Every `file:line` carries quoted source. Docs, comments, ADRs, and this file are non-authoritative about behavior.
- **R7 — every surviving value is tagged** `[OBSERVED]` (from code or a fetched source), `[DERIVED]` (computed from observed values, e.g. a WCAG ratio), or `[PROPOSAL]` (authored, owner-approved direction, implementer-pinned). A PROPOSAL is never presented as OBSERVED.
- **Canonical scale (the only permitted tokens).** This screen may use only the six type tokens, the BLACK-room ink table (§2.2), the space scale `2/4/8/12/16/20/24/32`, `Rectangle().frame(height: 1/displayScale)` rules, radius 0, and Courier New via the `relativeTo` overload. Any prior value not on the scale is re-expressed as a map onto it (§2.5).
- **Owner rulings in force for this screen:**
  - **HYBRID, asymmetric.** Pole B (anonymity) applies to the **gesture layer only** — sewn tack instead of underline; a genuinely blank tag; **no house name in any symbol name**. Pole A (baseline) applies to **content and surface**. Content deletions the doc proposed are **rejected**.
  - **Orientation: DESIGN LANDSCAPE.** Portrait is supported by the same stack (below); **iPad is explicitly OUT OF SCOPE.**
  - **The bypass is expressed by ABSENCE on the camera chrome** — no manifesto strip, no enhancement words. The `DNG` mark is the only claim on this screen. The bypass is **STATED** on the viewer's per-image sheet (out of scope here; `spec-gallery-viewer-spec.md`).
  - **Volume-button capture stays, and the system volume HUD is ACCEPTED** (not suppressed). Q4 resolved.
  - **Error banner renders INSIDE the `isConfigured` gate** (§4.1/§5.4).
  - **`baselineExposure`:** do not override a file-derived decoder default without cause — leave the decoder default; the existing `= 0.0` is a PROPOSAL-to-remove, per `VERIFICATION.md` §5.
- **Refuted substrate, not carried:** the ten Apple camera-layout URLs, the "CourierNewRecast 500 is shippable" claim, `006FE6`, `mm-btn-glyph-blink 0.6s`, and every authored `250ms/240ms/1s` motion value are REFUTED and appear nowhere below. Two stylesheet token names in `.P.DESIGN.md` are **fabricated**; the real names are `--color-mm-base-neutral-500` (`#6c6c6c`) and `--color-mm-base-neutral-100` (`#e5e5e5`) — `--color-mm-base-strong-grey` and `--color-mm-base-light-grey` **do not exist** (`VERIFICATION.md` §3 #1). This screen is a BLACK room and uses neither grey as a chrome value.

## 1. Conventional control set (hands-on norm; NOT Apple-quoted)

Because the Apple-layout bundle was refuted, the positions below are stated as the conventional norm to map against, without claiming any Apple page says it verbatim:

1. Full-bleed live viewfinder; dock left-to-right = gallery thumbnail, central shutter, flip-camera; zoom presets and the aspect strip directly above the dock; flash, timer, and grid in a top bar.
2. Tap preview = focus + meter at the tapped point with a transient reticle; press-and-hold ≈1s = AE/AF lock; vertical drag = exposure trim.
3. Shutter is the single large thumb-zone target; secondary controls lock during capture; save confirmation is by thumbnail update, not a progress bar.
4. Denied/restricted camera = the permission surface with a Settings remedy path; restricted copy never promises a Settings fix.
5. **Pro pole** [OBSERVED, marketing only, not a normative gesture spec]: Halide `https://halide.cam` markets `swiping up and down for exposure, and left and right for focus`; Blackmagic `https://www.blackmagicdesign.com/products/blackmagiccamera` states `When recording, the button and timecode at the top of the screen turn red`. **Pikicam deliberately inverts the Blackmagic rule:** red is reserved for failure only, never for a normal stills state.

Margiela wins every styling conflict (owner ruling #4); convention governs only position and gesture meaning.

## 2. Canonical tokens used on this screen

### 2.1 Type — the six canonical tokens [PROPOSAL = the mapping; token values are canonical]

Face: **Courier New** reached via `Font.custom(_:size:relativeTo:)`. The two-arg overload is **FORBIDDEN** — it freezes under Dynamic Type. Fallback stack `Courier New → Menlo → .system(design: .monospaced)` is defensive only [OBSERVED: Courier New is an iOS system font, `https://developer.apple.com/fonts/system-fonts/` → `Courier New / Version 5.00.2x / iOS system font`]. **No sans in chrome** — there is no second face, and there are no headings on the camera screen.

| Canonical token | Size/Weight | Tracking (em → pt) | Case | `relativeTo` | Used on this screen for |
|---|---|---|---|---|---|
| `display` | 96 Bold | 0 | tabular | `.largeTitle` | self-timer countdown numeral only |
| `title` | 17 Bold | +40/1000em ≈ **0.68pt** | UPPERCASE | `.headline` | **not used on the camera screen** (screen titles are `LIBRARY`, permission titles — gallery/permissions) |
| `body` | 14 Regular | 0 | sentence | `.body` | error bodies, camera-unavailable reason text |
| `label` | 13 Regular; **Bold when selected** | +80/1000em ≈ **1.04pt** | UPPERCASE | `.callout` | **every** word-control: `GRID`, `FLASH`, `TIMER`, `4:3`/`16:9`/`1:1`, zoom chips, `CAMERA FRONT|BACK`, `LIBRARY`, `RETRY`, `DISMISS`, `OPEN SETTINGS`, `SHARE`, `HIDE|SHOW`, `+`/`−` steppers |
| `caption` | 11 Regular | +80/1000em ≈ **0.88pt** | UPPERCASE | `.caption` | non-tappable status: `DNG` mark, `OFF`/`ON`, `TAP TO CANCEL`, `SAVING` |
| `tick` | 11 Regular, `monospacedDigit` | 0 | numerals + `X` `+` `−` `/3` | `.caption` | zoom live readout `1.0X`, EV readout `+1 2/3` |

**Pt tracking** [DERIVED from the em values at the token sizes]: `title` 0.68pt / `label` 1.04pt / `caption` 0.88pt. The deliverable `.tracking(...)` takes pt; the em values alone are insufficient (`VERIFICATION.md` #7).

Contract, not style:
- **U+2212 minus**, not hyphen, for negative EV; the byte-exact labels `0, +1, −2, +2/3, −1/3, +1 2/3, −2 1/3` are asserted and must not be "fixed" [OBSERVED `CameraControls.swift:287-295`].
- Zoom keeps the POSIX format `String(format: "%.1fx", locale: en_US_POSIX, factor)` [OBSERVED `CameraControls.swift:96-97`].
- `.monospacedDigit()` on zoom/EV so `1.0X → 2.5X` does not reflow. No italic. No weight other than Regular/Bold.

**Prior scale, deleted and mapped (ruling §0.5 #7):** `T-HUD caption 11 → caption 11`; `T-chip 12 → label 13`; `T-zoom 13 → label 13` (chips) and `tick 11` (readout); `T-readout 15 → tick 11` [OBSERVED source `ZoomIndicatorView.swift:10` is 15pt, re-mapped to `tick` 11 by ruling]; `T-error 12 → body 14`; `T-countdown 96 → display 96 Bold tabular`. The prior "T-countdown Regular, commerce-banner voice" argument is **overruled** — Bold matches the house request (`global.css` asks 500; the shipped Recast face is 400 — the synthesis gap is documented in **`fonts.css`**, not `global.css`, per `VERIFICATION.md` #2).

### 2.2 Ink — BLACK room (the camera screen's only room)

| Token | Value | Provenance |
|---|---|---|
| `bg` | `#000000` | [OBSERVED] `CameraView.swift:26` `Color.black.ignoresSafeArea()` |
| `ink` | `#FFFFFF` | [PROPOSAL] canonical black-room ink |
| `secondary` | `White 60%` (≈`#999999`) — contrast **7.37:1** on `bg` | [PROPOSAL]; ratio [DERIVED] WCAG, passes 4.5:1 |
| `rule` | `White 25%` | [OBSERVED] `CameraView.swift:389` `.stroke(.white.opacity(0.25), …)` |
| `wash` | `Black 55%` | [OBSERVED] `CameraView.swift:384` `Rectangle().fill(Color.black.opacity(0.55))` |
| `scrim` | `Black 45% → 0%`, 88pt tall | [PROPOSAL] one localized layer replacing per-control `black.opacity(0.45/0.5)` pills |
| `selectBg` / `selectInk` | `#FFFFFF` / `#000000` | [PROPOSAL] inversion only |
| `fail` | `#EA0000` — contrast **4.50:1** on `bg` | [OBSERVED] house token `--color-mm-base-red`; ratio [DERIVED]; **failure only** |

Rules that are contract:
- The house `--color-mm-base-neutral-500` (`#6c6c6c`) and `--color-mm-base-neutral-100` (`#e5e5e5`) are the WHITE-room greys and are **not** used on this black-room screen. (Recorded here so the correct names propagate; the `.P.DESIGN.md` names `--color-mm-base-strong-grey` / `--color-mm-base-light-grey` are fabricated — `VERIFICATION.md` #1.)
- **Selection is never a colour fill.** The current `.yellow` chips [OBSERVED `CameraView.swift:142,161`, `ZoomIndicatorView` none, `CameraView.swift:192`] and `.red` error text [OBSERVED `CameraView.swift:236`] are replaced: selection = `selectInk` on `selectBg` block **+ sewn tack**; never a tint wash.
- **`fail` (#EA0000) is reserved exclusively for genuine failure/interruption** on this screen — the error banner and interruption — never for the shutter or a normal state. This is the deliberate inversion of the verified Blackmagic red-recording convention.
- No gradients except the localized preview scrim. No blur/material anywhere (`ultraThinMaterial` gone). No shadows.

### 2.3 Shape, line, motion

- **Radius 0 everywhere on chrome.** No capsules, no circles, no rounded rectangles anywhere in camera chrome.
- **Hairlines:** `Rectangle().frame(height: 1/displayScale)` via `@Environment(\.displayScale)`. **`Divider()` is FORBIDDEN** — no one-physical-pixel contract. Under Increase Contrast, rules step to 2pt solid and `secondary` steps to `ink`.

**Complete shape-deletion list** [OBSERVED; `VERIFICATION.md` #5 completes this — the prior list was incomplete]:
- `Capsule()` — `CameraView.swift:144` (zoom chip), `CameraView.swift:162` (aspect chip), **`CameraView.swift:417` (EV track)**, **`CameraView.swift:444` (EV value bubble)**, **`ZoomIndicatorView.swift:15` (`.background(…, in: Capsule())`)**.
- `Circle()` — `CameraHUDButton.swift:21` (HUD disc), **`CameraView.swift:423` (EV tick)**, `CameraView.swift:486` (countdown disc, deleted with the disc), `ShutterButton.swift:15,20,24` (shutter circles — replaced by squares, §4.2).
- `RoundedRectangle` — `CameraView.swift:178` (cornerRadius 8, thumbnail plate), `CameraView.swift:321` (cornerRadius 6, thumbnail clip), `GalleryView.swift:26` (cornerRadius 4), `GalleryView.swift:132` (cornerRadius 8).

All of the above are replaced by 0-radius rectangles.

**Motion** [OBSERVED values, ruling §0.5 #8]: fades only. Slider appear `.easeInOut(duration: 0.2)` [OBSERVED `CameraView.swift:96`], disappear `.easeInOut(duration: 0.25)` [OBSERVED `CameraView.swift:100`], shutter press `.easeInOut(duration: 0.15)` [OBSERVED `ShutterButton.swift:42`], EV auto-dismiss 2500ms [OBSERVED `CameraView.swift:98`]. **Under Reduce Motion every duration is 0** — state changes apply instantly. **Forbidden:** springs, slides, blinks, shimmer, skeletons, bounce, rubber-band, countdown tick animation.

### 2.4 Hit targets, safe area, RTL, sizes

- Every tappable word is a real SwiftUI `Button` (carries `.isButton`) with `.frame(minWidth: 44, minHeight: 44)` + `.contentShape(Rectangle())`. Visible glyph is `label` 13pt or `caption` 11pt. [OBSERVED pattern: the 44×44 HUD target at `CameraHUDButton.swift:20`.]
- Dock lives inside `safeAreaInset(bottom)`; only backgrounds extend behind the home-indicator zone. No hard-coded 34pt spacer. Current `.padding(.bottom, 32)` [OBSERVED `CameraView.swift:218`] becomes `padding(.bottom, max(8, safeAreaBottom))` with background extended via `ignoresSafeArea(.container, edges: .bottom)`.
- Leading/trailing only; test `ar` + `.rightToLeft`; clock/timer numerals and the preview itself never mirror.
- Verify at the smallest iPhone in landscape (**667×375**) and the largest (**956×440**). XXXL Dynamic Type must wrap/truncate, never overflow.

### 2.5 The space scale, and what is exempt

- **Spacing (padding, gaps, margins) uses only `2/4/8/12/16/20/24/32`.** Prior paddings remap: `10 → 8`, `14 → 16`, `40 → 32`.
- **Margins** re-expressed onto the scale: smallest width → **16**, largest width → **20**. (`.P.DESIGN.md` §2.6 lists `18` for the mid range; `18` is **not** on the mandated scale, so it is re-expressed to **16**. Flagged in §8.)
- **Exempt from the spacing scale** — element sizes and bar metrics are geometry, not spacing, and are governed by owner rulings and the house metric: shutter 80×80 outer / 64×64 inner (§4.2, owner-ruled); EV track **220pt** height + **40pt** column (§4.8, owner-ruled); top bar and dock bar heights (§3). These are tagged individually.

## 3. Layout map — LANDSCAPE (designed) + portrait (supported)

**iPad is OUT OF SCOPE** (owner ruling). Only iPhone widths are designed. Landscape is the designed orientation; portrait is supported by the same top-to-bottom stack with the same chrome and only the bar heights and control rows re-flowing.

```
667pt LANDSCAPE (smallest; logical pt; safe-area insets read at runtime)
+---------------------------------------------------------------------------+
| [status bar — system]                                                       |
| TOP BAR 44pt [PROPOSAL]: [DNG]  ·  [GRID OFF][FLASH OFF][TIMER OFF][4:3]    |
| rule 1px ink                                                                |
|                                                                             |
|   P R E V I E W  (full-bleed, aspect-fill)                                  |
|   + reticle 72pt square @ tap point (NEW, §4.9)                             |
|   + AE/AF LOCK tab under reticle (NEW, §4.10)                               |
|   + grid thirds (on) / aperture bands (16:9, 1:1)                           |
|   + countdown 96 display, SQUARE, centered (timer running only)             |
|                                                                             |
| rule 1px ink                                                                |
| CONTROL ROW [PROPOSAL]: [1.0X][2.0X][5.0X]  readout 1.0X  |  [4:3][16:9][1:1] |
| DOCK 64pt [PROPOSAL]: [LIBRARY]        (SHUTTER 80sq)        [CAMERA BACK]   |
| rule 1px ink                                                                |
| ERROR SLOT (caption, inline; inside isConfigured; NOT under home indicator) |
+---------------------------------------------------------------------------+

956pt LANDSCAPE — same stack; differences only:
- TOP BAR spreads full width; `DNG` pinned leading, the four words pinned trailing.
- CONTROL ROW centers zoom chips left-of-center and aspect chips right-of-center, 16pt gap.
- DOCK: LIBRARY leading, shutter centered, CAMERA trailing; margins 20pt.
- Countdown square identical 96 display (does not grow with width).
```

**Bar metrics:** top bar 44pt landscape / 60pt portrait; dock 64pt landscape / 88pt portrait [PROPOSAL for landscape; portrait 60/88 are the house metrics carried from `.P.DESIGN.md` §2.6]. These are element metrics, exempt from the space scale (§2.5), and must be revalidated against the runtime safe area.

## 4. Element specifications

### 4.1 Status bar (top; replaces the HUD-cluster styling, keeps its position)

- **Position:** full-width row, top bar height (§3), `padding(.leading, 20)`, `padding(.trailing, 20)`, `padding(.top, max(8, safeAreaTop))`. Left: `DNG` word-mark (non-interactive, `caption`, `secondary`). Right group: `GRID OFF|ON`, `FLASH OFF|ON`, `TIMER OFF|3S|10S`, `RATIO 4:3|16:9|1:1` as bare `label` word-buttons.
- **Selection:** the active value is Bold `selectInk` on `selectBg` + sewn tack (never `.underline`, never a colour fill).
- **Every state,** all rendered inside the `isConfigured` gate, which already wraps the cluster [OBSERVED `CameraView.swift:107` `if viewModel.isConfigured { HUDCluster }`]:
  - When `flashAvailable == false` the FLASH word remains a disabled placeholder `FLASH:—` in `secondary`, **slot HELD** — this fixes the live defect where `if flashAvailable` [OBSERVED `CameraView.swift:256`] makes the control vanish and the row reflow.
  - During `countdown/capturing/savingDNG` all status words render `secondary` with `.disabled(phase != .idle)` so VoiceOver announces dimmed (the model already no-ops every control unless idle [OBSERVED `CameraViewModel.swift:160,175,188,205,210,217,230`]).
- **Flash = torch pulse, not a system flash** [OBSERVED rationale, retained verbatim in intent]: pikicam captures pure Bayer RAW single exposures, which cannot use `AVCapturePhotoSettings.flashMode`; the honest RAW-compatible equivalent is the **torch**, fired as a shutter-time pulse and turned back off immediately [OBSERVED `CameraControls.swift:35-39`; `CaptureService.swift:541-556` `shouldPulseTorch = flashMode == .on && device.hasTorch`]. Labels `OFF`/`ON` are `caption` status.
- Margiela justification: words replace icons per the always-visible-label rule [OBSERVED `https://www.nngroup.com/articles/icon-usability/` → `Icon labels should be visible at all times, without any interaction from the user`]; inversion + tack replaces yellow-fill selection, so meaning survives Increase Contrast.

### 4.2 Shutter (bottom-center; the only large target) — SHUTTER OVERRULE APPLIED

- **Shape/shade OVERRULED by ruling §0.5 #1 and owner ruling #6.** The prior spec's "flat white disc, 2pt ring, shape stays circular" is **deleted**.
  - Outer: **square hairline ring 80×80**, **1pt** `ink` stroke, **sharp corners**, radius 0, flat, no gloss.
  - Inner: **64×64 square fill** in `ink`.
  - Press: inner scales **×0.9** [OBSERVED timing `ShutterButton.swift:41-42` `.scaleEffect(configuration.isPressed ? 0.9 : 1.0)` + `.animation(.easeInOut(duration: 0.15))`].
  - Capturing: inner at **30% opacity** [OBSERVED `ShutterButton.swift:27` `.opacity(isCapturing ? 0.3 : 0)`], square form.
  - The 80/64 sizes are the owner-ruled numbers [OBSERVED source sizes `ShutterButton.swift:16-22`; shape is the PROPOSAL].
- **States:** idle = square `ink` ring + inner fill; pressed = inner ×0.9; `capturing/savingDNG` = inner at 30% + `.disabled(isCapturing)` [OBSERVED `ShutterButton.swift:31`] AND the honest phase label under the dock (§4.12). During `countdown` the shutter acts as cancel [OBSERVED `CameraViewModel.swift:251-253` `case .countdown: cancelCapture()`]: the inner fill shows a 1pt `ink` square STOP mark (0-radius) + `CANCEL` `caption` word beneath.
- **Accessibility:** keep `.accessibilityLabel("Capture photo")` [OBSERVED `ShutterButton.swift:33`]; add **`.accessibilityIdentifier("camera-shutter")`** — this is the one control with **no identifier today** [OBSERVED `VERIFICATION.md` §8 "No identifier at all — the shutter"]. Identifier is `camera-shutter` (single name — `VERIFICATION.md` #14 resolves the three-way divergence `camera-shutter`/`shutter`/`gallery-shutter`); the view must actually emit it. Phase-appropriate hint `Cancels the timer` during countdown.

### 4.3 Gallery thumbnail (bottom-left, dock)

- **Geometry:** 0-radius square plate 60×58, 1pt `ink` border. Plate/empty/loading boxes currently `RoundedRectangle(8)` [OBSERVED `CameraView.swift:178`] / `Color.gray.opacity(0.4)` [OBSERVED `:185`] / `RoundedRectangle(6)` clip [OBSERVED `:321`] — all radius 0 now.
- **Badge:** the `photo.on.rectangle` yellow caption [OBSERVED `CameraView.swift:190-193`] is **deleted**. Pole B applies here (critic §9.2): the Tabi-split mark is deleted. Replace with a `caption` capture-index numeral (e.g. `03`) in the corner — identity is the sewn blank tag's world, not a graphic.
- **Loading** = hairline skeleton (no shimmer). **Failure** = `!` mono mark + a tappable `RETRY` word — fixes today's failure-is-indistinguishable-from-empty where `image = nil` persists silently [OBSERVED `CameraView.swift:331-333`].
- **Behavior:** tap opens gallery [OBSERVED `CameraView.swift:174-176`]; identifier `gallery-thumbnail` [OBSERVED `CameraView.swift:196`]. During capture the thumbnail shows the committing frame at 50% with the `caption` word `SAVING` (optimistic but labeled; never `SAVED` until `phase` returns idle after save).

### 4.4 Flip control (bottom-right, dock)

- **Keep WHERE** (dock right, 44×44) and the SF Symbol? **No — words only** (owner ruling #8, ruling §0.5 #8). The `arrow.triangle.2.circlepath.camera` glyph [OBSERVED `CameraView.swift:210`] is deleted; the control becomes the `label` word pair **`CAMERA FRONT|BACK`** (value from `CameraPosition.label` [OBSERVED `CameraControls.swift:26` `"Back" / "Front"`], upper-cased to `BACK`/`FRONT` [PROPOSAL]).
- Flip resets zoom to 1.0 and exposure to `.zero` [OBSERVED `CameraViewModel.swift:163-167`]; spec a 0.2s fade + transient `caption` confirmation line `FRONT · 1.0X · EV 0` (fixes the silent reset).

### 4.5 Zoom presets + live readout (above the dock / control row)

- **Presets:** factors from `ZoomPresets.factors(in:)` = lower bound + 2×/5× when contained [OBSERVED `CameraControls.swift:222-227`]; a front camera's fixed-1× range yields a single chip. Labels POSIX `%.1fx` [OBSERVED `CameraControls.swift:96-97`]. Current chips are 13pt bold rounded on capsule with a yellow fill [OBSERVED `CameraView.swift:127-146`].
- **Restyle:** `label` 13pt mono word-chips, 0-radius, 1pt `ink` border; selected = `selectInk` on `selectBg` + sewn tack; unselected = `ink` on the scrim. Spacing 12 kept as 12 (scale-valid); `padding(.bottom, 10)` → **8** (scale). Identifiers `zoom-preset-*` retained.
- **Live readout (NEW persistent):** the zoom value [OBSERVED source `ZoomIndicatorView.swift:10` 15pt rounded white on a black-0.45 capsule] becomes **`tick` 11pt mono tabular** `ink`, always shown, updating continuously during pinch [OBSERVED `CameraView.swift:287-305` `MagnificationGesture` driving `ZoomMath.factor(base:magnification:range:)`], snapping the chip highlight to the nearest preset within 0.01 [OBSERVED `CameraControls.swift:231-233`]. Pinch-at-limit = 3 short haptic ticks + readout flashes `LIMIT 1.0X/5.0X` (fixes the silent clamp).

### 4.6 Aspect strip

- **Current:** `HStack(spacing: 16)` centered [OBSERVED `CameraView.swift:152`], 12pt bold rounded white on a capsule with a `.yellow` selected fill [OBSERVED `:157-162`], insets horizontal 40 + bottom 8 [OBSERVED `:168-169`], ids `mode-*` [OBSERVED `:164`], labels `4:3/16:9/1:1` [OBSERVED `CameraControls.swift:152-157`].
- **Restyle** identically to the zoom chips: `label` word-chips, 0-radius, sewn-tack selection. Insets horizontal **32** (scale), bottom **8**.
- DNG stays full-sensor; aspect is a view-time crop [OBSERVED `CameraControls.swift:122-124`]; the aperture mask (§4.11) is the visual contract.

### 4.7 Self-timer countdown

- **Current:** 96pt bold rounded white on a black-0.6 circle with tap-to-cancel [OBSERVED `CameraView.swift:481-489`], tick 1s [OBSERVED `CameraViewModel.swift:318` `Task.sleep(for: .seconds(1))`], labels `Off/3s/10s` [OBSERVED `CameraViewModel.swift:358-363`].
- **Spec (ruling §0.5 #2): 96 `display` Bold tabular, square, NO disc.** `lineLimit(1)` + `minimumScaleFactor(0.6)`; `contentShape(Rectangle())` sized to the visible numeral; a `caption` line `TIMER 3S · TAP TO CANCEL` beneath.
  - The black-0.6 disc [OBSERVED `CameraView.swift:485-486`] is **deleted** (radius 0). The numeral sits on the scrim (§2.2) for legibility over the preview.
  - Fix the width shift between `10` and single digits by fixing the numeral's field to the max width (measure `10` once) so there is no mid-countdown resize.
  - The doc comment at `CameraView.swift:474-475` claims *"tapping anywhere on the screen cancels"* — **the comment is false**; the hit area is the padded disc [OBSERVED `CameraView.swift:487`]. Fix the comment; specify the disc/numeral + explicit `CANCEL` word (never claim fullscreen cancel). R3 defect.

### 4.8 Exposure slider

- **Keep geometry/gesture/timings** (owner ruling, `VERIFICATION.md`, and `.P.DESIGN.md` §3): **220pt track height** [OBSERVED `CameraView.swift:48`], **40pt column** [OBSERVED `CameraView.swift:437`], `DragGesture(minimumDistance: 0)` [OBSERVED `:430`], 5pt track [OBSERVED `:419`], ticks 7pt zero / 4pt else [OBSERVED `:424`], range −3…+3 [OBSERVED `:409-411`], labels with U+2212 [OBSERVED `CameraControls.swift:287-295`], auto-dismiss 2500ms with 0.2/0.25 fades [OBSERVED `CameraView.swift:96,98,100`], a11y label/value present [OBSERVED `:449-451`]. Model snaps to 1/3 stops clamped to device bias [OBSERVED `CameraViewModel.swift:229-237`; `CameraControls.swift:250-257`].
- **Restyle:** the 5pt `Capsule()` track → 5pt **0-radius** track (radius 0 with a 1pt `ink` outline); the tick `Circle()`s → 0-radius 1pt `ink` tick rects (7pt zero / 4pt else); the yellow 12pt rounded value bubble on a black-0.55 capsule [OBSERVED `:439-445`] → **`tick` 11pt mono `selectInk` on `selectBg`, 0-radius**. Yellow removed.
- **Add `+` / `−` stepper words** (`label`) as the accessible equivalent — **no gesture may be the only path**. This preserves the 220pt/40pt geometry (owner ruling) and adds the stepper (owner ruling).
- **Add** a tick highlight at the committed stop + min/max stopper treatment + a haptic per 1/3 stop (fixes today's no-highlight/no-haptic/no-stopper drag). Readout in `+1 2/3` format; returns to 0 only via explicit reset, never silently on reticle dismiss.

### 4.9 Tap-to-focus reticle (MISSING — new)

- **Gap:** tap-to-meter sets focus + exposure at the same normalized point [OBSERVED `CameraViewModel.swift:214-223`; `CaptureService.swift:384-405` gating `isFocusPointOfInterestSupported/isExposurePointOfInterestSupported`, `lockForConfiguration`, same-point AF+AE] but renders zero marker — only the EV slider appears.
- **Spec:** 72pt **0-radius square** outline [element size; PROPOSAL], 1.5pt `ink` stroke + 1pt `ink` outer keyline (legible on any scene), centered exactly at the tap point. Appears 0.15s fade, holds while the slider is visible, dismisses on next tap / mode change / capture. **Unsupported hardware surfaces the typed `This camera does not support tap-to-focus/exposure.`** [OBSERVED `CaptureService.swift:762-763`] inline (§4.1/§5.4), never silent.

### 4.10 AE/AF lock indicator (MISSING — new)

- **Spec:** press-and-hold ≈1s at the reticle enters lock; a persistent `label` tab `AE/AF LOCK` pinned 8pt below the reticle until a second tap unlocks; exposure drag remains live while locked. Lock persists across capture; clears on lens switch. Conventional affordance kept (hold-to-lock position/gesture), styling fully on the canonical scale.

### 4.11 Grid, aspect mask

- **Grid:** thirds only, fractions `[1/3, 2/3]` [OBSERVED `CameraControls.swift:107` `static let lineFractions: [CGFloat] = [1.0 / 3.0, 2.0 / 3.0]`], 0.7pt white 0.6 [OBSERVED `GridOverlayView.swift:37` `.stroke(.white.opacity(0.6), lineWidth: 0.7)`], clipped to the aperture, non-interactive [OBSERVED `:39-41`], id `grid-overlay`. Toggle states fill vs outline [OBSERVED `CameraView.swift:250`]. **Restyle** lines to `1/displayScale` `ink` at 70%; keep the clipping rule (grid never enters the masked bands).
- **Mask:** 16:9/1:1 bands `wash` (Black 55%) + 1pt `rule` aperture border [OBSERVED `CameraView.swift:384,389`]; 4:3 = `Color.clear` [OBSERVED `:394`]. Restyle border to 1pt `ink` solid; bands unchanged (contrast necessity). Identifier `aspect-overlay` [OBSERVED `:392`].
- **Rule locations on this screen** (`VERIFICATION.md` #6 — the "exactly four" claim is dropped): below the top bar; above the bottom dock; **above the error banner**; the grid/blank-tag border. No boxes around buttons; no card outlines.

### 4.12 Capture status, honest capture, and the bypass by absence

- **The bypass is expressed by ABSENCE (owner ruling, hybrid §0.5 #12).** The 40pt zero-process/manifesto strip of the prior spec (`ZERO PROCESSING AT CAPTURE — NO ENHANCEMENTS ADDED`, `CONVERSION ALWAYS ON: DEMOSAIC · BLACK LEVEL · COLOR MATRIX · AsShotNeutral WB`) is **DELETED**. The `DNG` word-mark in the status bar is the only claim on the camera chrome — non-interactive, `caption`. **No enhancement words render anywhere on this screen.** The bypass is **STATED** on the viewer's per-image sheet (full provenance sheet; `spec-gallery-viewer-spec.md`).
  - Rationale [OBSERVED]: capture is pure Bayer [OBSERVED `CaptureService.swift:536` `AVCapturePhotoSettings(rawPixelFormatType: bayerFormat)`; `CaptureService.swift:679` `photoOutput.isAppleProRAWEnabled = false` with comment `Disable Apple ProRAW to get pure Bayer`]; develop is `CIRAWFilter(imageData:)` [OBSERVED `CIRAWZeroProcessor.swift:31`] with the enhancement list neutralized [OBSERVED `:63-81`] while demosaic / black-level / color-matrix / AsShotNeutral WB are deliberately retained [OBSERVED `:8-13`]. **The screen never says `NO PROCESSING`, `PURE SENSOR`, or `UNTOUCHED`** — those words are banned (§7).
- **`baselineExposure` (VERIFICATION §5, owner ruling).** The recipe currently sets `filter.baselineExposure = 0.0` [OBSERVED `CIRAWZeroProcessor.swift:65`]. Per Apple, the default "varies with camera settings" and `0` denotes "linear response" — so `= 0.0` is an **active override**, not a no-op, and it is currently unjustified. **Ruling: do not override a file-derived decoder default without cause — leave the decoder default; treat removing `baselineExposure` from the neutralize list as a PROPOSAL to be confirmed by measurement, not assumed.**
  - **R3 defect regardless:** the header comment `CIRAWZeroProcessor.swift:4-17` states only demosaic / black-level / color-matrix / WB run, while the recipe **also** zeroes `baselineExposure`. The comment overstates its own case and must be corrected either way.
- **Honest capture behaviors to surface, not hide:** zoom>1 captures at 1× internally with a 250ms settle then restores [OBSERVED `CaptureService.swift:518-531`]. Spec a transient `caption` line `FRAMING 2.0X · CAPTURING AT 1X` so the visible FOV snap is explained [PROPOSAL — this is behavior explanation, not a bypass manifesto; owner may delete it].
- **Phase machine:** exactly four states — `idle/countdown/capturing/savingDNG` [OBSERVED `CameraViewModel.swift:20-29`]; a second press during `countdown` cancels and never duplicates [OBSERVED `CameraViewModel.swift:250-266`]. The shutter reflects each phase (§4.2). No fifth state is invented.

## 5. Missing-piece resolutions (all must ship)

1. **Reticle / AE-lock:** §4.9–§4.10.
2. **Honest capturing/saving:** phase-reflecting shutter (§4.2) + thumbnail `SAVING` (§4.3); no fifth state invented (phase enum is exactly four).
3. **Camera-unavailable:** fullscreen `body` on `ink` panel (not bare `Color.black` [OBSERVED `CameraView.swift:26,87`]) with a `title` **`CAMERA UNAVAILABLE`**, the typed reason as `body` (`No back wide camera is available.` / `No Bayer RAW format is available on this camera.` / `Camera and photo library access are required.` [OBSERVED `CaptureService.swift:738,746`; `CameraViewModel.swift:383`]), and one `RETRY` + one `OPEN SETTINGS` `label` word-button. **Restricted vs denied copy distinguished** — restricted cannot be fixed in Settings and must not promise it [OBSERVED gap `CameraViewModel.swift:101`].
4. **Error banner:** inline slot above the dock inside the `isConfigured` gate (**never under the home indicator**), `body` `ink` text + `!` mark + a `DISMISS` `label` word; a `1/displayScale` rule above it. Auto-clears on next idle shutter [OBSERVED `CameraViewModel.swift:255` `error = nil`] AND on manual dismiss. `fail` (#EA0000) is reserved for this banner and for interruption only — **and only after** the black-room rule is honoured (this is a black room, so red is permitted here; the WHITE room forbids it — §2.2).
5. **Zoom readout:** always-visible `tick` readout (§4.5).
6. **HUD availability:** disabled placeholders hold layout (§4.1); nothing vanishes.

## 6. Motion, accessibility, dark mode

- **Motion:** countdown ticks swap instantly (no animation); slider fades 0.2 in / 0.25 out; shutter 0.15; overlays `.transition(.opacity)` [OBSERVED `CameraView.swift:51`]. **Under Reduce Motion, all durations are 0.**
- **Every gesture has a button equivalent:** zoom chips, the EV `+`/`−` steppers, the on-screen shutter, `DISMISS`(back) equivalents. No gesture is the only path (NN/g + WCAG basis above; the per-gesture iOS VoiceOver matrix is unconfirmed — the equivalents are a design decision).
- **Contrast:** every over-preview word resolves through the scrim (§2.2) — never bare on the preview. BLACK-room demands: `ink` on `bg` 21:1; `secondary` (White 60%) 7.37:1 [DERIVED]; `fail` (#EA0000) 4.50:1 [DERIVED]. Increase Contrast: rules step to 2pt solid, `secondary` steps to `ink`. White-room pairs (4.5:1 normal / 3:1 large) are the gallery/viewer spec's concern.
- **Dark mode:** the camera screen is the black room in both appearances. Delete the `preferredColorScheme(.dark)` forcing gallery dark (that is a gallery concern) — not on this screen. Hard-coded `.white/.black` outside the token layer is forbidden.
- **Title token** on permission surfaces is `title` (17 Bold uppercase) — the permission surfaces drop from `.largeTitle.bold()` [OBSERVED `RootView.swift:68`] (out of scope here, noted for consistency).

## 7. Closed vocabulary and copy allow-list (camera screen)

**Closed set — nothing outside it renders. Tagged [PROPOSAL] (`VERIFICATION.md` #16: every word differs in case or wording from the strings that exist in code today, so this is a PROPOSAL, not a description).**

`DNG · GRID ON|OFF · FLASH OFF|ON · TIMER OFF|3S|10S · 4:3|16:9|1:1 · 1.0X|2.0X|5.0X · CANCEL · CAMERA FRONT|BACK · LIBRARY · SHARE · HIDE|SHOW · DELETE · RETRY · DISMISS · OPEN SETTINGS · BACK`

**Critically, the set is now genuinely closed (`VERIFICATION.md` #13):** it adds the three families the prior set omitted but the app renders — **`SHARE`**, **`HIDE|SHOW`**, and **`CAMERA FRONT|BACK`**. `SHARE` and `HIDE|SHOW` are the viewer's surfaces; they are enumerated here so the closed set does not misstate the app's vocabulary.

**Banned words (do not render anywhere on the camera screen):** `filter`, `enhance`, `HDR`, `style`, `ProRAW` (as pikicam output), `NO PROCESSING`, `PURE SENSOR`, `UNTOUCHED`, `pure sensor dump`, `unconverted pixels`, and every manifesto phrase (`ZERO PROCESSING AT CAPTURE`, `NO ENHANCEMENTS ADDED`, `CONVERSION ALWAYS ON`).

Current code strings the vocabulary replaces (for the implementation diff) [OBSERVED]: `Flash Off`/`On` [`CameraControls.swift:64-65`]; `Timer Off`/`3s`/`10s` [`CameraViewModel.swift:358-363`]; zoom `%.1fx` [`CameraControls.swift:97`]; `Library` [`GalleryView.swift:49`]; `Retry` [`GalleryView.swift:89`]; `Back to Camera` [`GalleryView.swift:208`]; `DNG Viewer` [`GalleryView.swift:194`].

## 8. Corrections applied (VERIFICATION.md §6 → this file)

| # | Correction | Where applied |
|---|---|---|
| 1 | Real house token names | §0, §2.2 (fabricated names struck; `--color-mm-base-neutral-500`/`-100` used) |
| 2 | `@font-face` weight-400 evidence belongs to `fonts.css` | §2.1 |
| 3 | `#595959` ratio = **6.83:1** | §6 (white-room note; state it once, correctly) |
| 5 | Complete shape-deletion list | §2.3 (added `CameraView:417,444,423`; `ZoomIndicatorView:15`) |
| 6 | Rule locations (drop "exactly four") | §4.11 |
| 7 | Tracking in pt as well as em | §2.1 |
| 8 | `#EA0000` reserved; red-in-white-room resolved | §2.2, §5.4 |
| 9 | iPad out of scope (stated) | §0, §3 |
| 13 | Close the vocabulary: add `SHARE`, `HIDE\|SHOW`, `CAMERA FRONT\|BACK` | §7 |
| 14 | Shutter identifier resolved to **`camera-shutter`** | §4.2 |
| 16 | Vocabulary reclassified **PROPOSAL** | §7 |
| — | Shutter overrule, countdown, EV stepper, error-gate, landscape, bypass-by-absence | §0, §3, §4.2, §4.7, §4.8, §4.12, §5.4 |

**Exempt sizes (not spacing tokens):** shutter 80×80/64×64 (owner), EV 220pt/40pt (owner), bar heights 44/60 and dock 64/88 (metrics).

