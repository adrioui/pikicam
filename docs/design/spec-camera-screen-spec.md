# P.DESIGN — CAMERA SCREEN (pikicam)

## 0. Authority and what is NOT claimed

- Code cited below was opened with the Read tool in this turn. Every `file:line` carries quoted source text. Files not opened in this turn are not cited as authority, even where the inventory mentions them. Where the inventory is the only source for a value, it is labeled `inventory-only, unverified in this turn` and is not used as a lock-in token.
- Convention citations: the verification verdicts refuted all ten Apple camera-layout URLs in the `camera-conventions-apple` bundle (support-guide pages returned index-only/404 content; `https://support.apple.com/en-us/108760` returned an Apple Watch battery article; `https://www.apple.com/os/ios/` returned iOS 27 Siri-mode text; the newsroom/macrumor/shutter/zoom/flash/exposure/focus/grid/permission claims carry invented quotes). **Therefore this spec cites zero Apple-layout sentences as Apple-quoted fact.** Conventional WHERE/WHAT below is stated as hands-on norm and labeled as such; the only convention claims carried as verified quotes are:
  - Halide gestures/marketing: `https://halide.cam` — verified strings `swiping up and down for exposure, and left and right for focus`, `Halide turns your iPhone into a traditional camera` (homepage marketing only, not a normative gesture spec; manual-mode mapping differs).
  - Blackmagic state color/HUD: `https://www.blackmagicdesign.com/products/blackmagiccamera` — verified `When recording, the button and timecode at the top of the screen turn red`, HUD parameters lens/frame-rate/shutter-angle/ISO/WB/histogram/audio, swipe up/down to show/hide HUD.
  - NN/g icon usability: `https://www.nngroup.com/articles/icon-usability/` — always-visible text labels alongside ambiguous icons; do not rely on hover (paraphrase; iOS has no hover, so labels stay visible).
  - WCAG 1.4.3/1.4.11: `https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html` (`at least 4.5:1` normal, `at least 3:1` large at 18pt or 14pt bold), `https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html` (`at least 3:1 against adjacent color(s)`).
  - MDN forced-colors: `https://developer.mozilla.org/en-US/docs/Web/CSS/@media/forced-colors` — web-CSS Windows mechanism only; it does **not** prove iOS behavior. iOS equivalents to spec against are Increase Contrast, Reduce Transparency, Bold Text, Invert Colors. The bundle's iOS extrapolation is analogy, not verified iOS behavior.
  - Margiela web tokens (verified excerpts from `https://www.maisonmargiela.com/on/demandware.static/Sites-MargielaGLOBAL-Site/-/default/v1790833881632/css/global.css`): `--color-mm-base-off-white: #fcfcfc`, neutrals `#404040/#6c6c6c` + `#cccccc/#e5e5e5`, alpha `#0000001a`, `--mm-border-primary: var(--color-mm-base-black)`, accents `--color-mm-base-red: #ea0000`, dark-red `#bf1d1d`, green `#40aa75`, yellow `#ffaa01`, `--bs-gutter-x: 1.5rem`, `--mm-header-height: 60px`, `--mm-banner-height: 40px` (same lines also declare `--mm6-header-height: 40px` / `--mm6-banner-height: 40px`, omitted by the bundle); `.mm-txt-default` Courier 14px/18px requesting `font-weight:500` while the shipped Recast files declare `font-weight: 400` only (synthesis gap); `.mm-txt-replica-title` Helvetica bold 16px/20px `letter-spacing:.16px` uppercase; `.mm-txt-replica-display` 28px/36px `ls .28px`; `.mm6-txt-default` 13px/16px `letter-spacing:-0.13px`; utilities `.rounded-0{border-radius:0 !important}` and `.text-decoration-underline{text-decoration:underline !important}`. NOT verified: `#006FE6` focus blue (not found; only verified blue is MM6 `#007ED2`), `mm-btn-glyph-blink .6s`, `250ms opacity` transitions, `transition:none`, `25/50/75vw` sheets, `.mm-sheet__body` padding, literal `border:1px solid var(--mm-border-primary)` shorthand — all downgraded to UNVERIFIED, not OBSERVED-certain. Price/PDP/nav/Bootstrap/locale/newsletter tokens are commerce-only and out of scope for the camera screen.
  - iOS platform facts: Courier New is an iOS system font — `https://developer.apple.com/fonts/system-fonts/` lists `Courier New / Version 5.00.2x / iOS system font` (plus Bold/Italic/Bold Italic). The `available-fonts`, `safeAreaInsets`, HIG accessibility/materials/dark-mode, `layoutDirection`, `Divider`, `iphone-16/specs`, support `122266` citations are title-only/404/wrong-page and are not quoted as verbatim.
- Current-app facts below come from files read this turn: `pikicam/Features/Camera/CameraView.swift` (lines cited 26–492), `pikicam/Features/Camera/Views/ShutterButton.swift:15-42`, `pikicam/Features/Camera/CameraHUDButton.swift:16-29`, `pikicam/Features/Camera/GridOverlayView.swift:21-41`, `pikicam/Features/Camera/ZoomIndicatorView.swift:9-17`, `pikicam/Features/Camera/CameraViewModel.swift:10-51, 159-266, 308-384`, `pikicam/Features/Camera/CameraControls.swift:23-295`, `pikicam/Features/Camera/CaptureService.swift:369-376, 518-556, 679, 739-765`, `pikicam/Features/Develop/CIRAWZeroProcessor.swift:8-81`. No other repo file is cited.

## 1. Conventional control set (hands-on norm; NOT Apple-quoted)

Because the bundle's Apple quotes were refuted, the following is stated as the conventional norm to map against, without claiming any Apple page says it verbatim:

1. Full-bleed live viewfinder; bottom dock left-to-right = gallery thumbnail, central shutter, flip-camera; zoom preset chips directly above the dock; aspect/mode/secondary toggles (flash, timer, grid, aspect 4:3/16:9/Square, level) in a top bar or swipe-up tray, never in the thumb dock.
2. Tap preview = focus + meter at the same point with a transient reticle; press-and-hold = AE/AF lock with persistent indicator; vertical drag at the reticle = exposure trim.
3. Shutter is the single large thumb-zone target; secondary controls lock during capture; save confirmation is via thumbnail update, not a progress bar (hands-on norm).
4. Denied/restricted camera = black preview or Camera Unavailable with a Settings remedy path (no verbatim Apple string is carried; the cited support URL was the wrong article).
5. Pro pole (verified): Halide homepage `https://halide.cam` markets `Halide turns your iPhone into a traditional camera` with swipe exposure/focus; Blackmagic `https://www.blackmagicdesign.com/products/blackmagiccamera` turns `the button and timecode at the top of the screen turn red` while recording with a swipe-hidden HUD. Pikicam deliberately inverts the Blackmagic rule (see §7): red is reserved for failure, never for a normal stills state.

What pikicam keeps (affordance WHERE/WHAT) vs what it restyles (Margiela surface) is specified per element in §3–§6. Margiela wins every styling conflict per owner ruling; convention governs only position and gesture meaning.

## 2. Design tokens (locked)

### 2.1 Type
- Mono stack only for camera chrome: `Font.custom("Courier New", size: X, relativeTo: .body)` with runtime fallback to `.system(size: X, design: .monospaced)` if `UIFont(name: "Courier New", size:)` returns nil. Courier New is a real iOS system font (`https://developer.apple.com/fonts/system-fonts/`). Rationale: observed house body is a 400-weight Courier recast at 14px/18px (class requests 500 but files ship 400 — synthesis gap — so spec iOS Regular/Medium explicitly, never `weight .bold` on mono to fake the web 500).
- All chrome labels uppercase, tracking: HUD captions `+80`, word-chips `+60`, readout numerals `0` with `.monospacedDigit()`.
- Scale (fixed spec; every usage passes `relativeTo` so Dynamic Type scales; two-arg fixed overload forbidden):
  - T-HUD caption 11pt Regular; T-chip 12pt Regular; T-zoom 13pt Regular; T-readout 15pt Regular; T-error 12pt Regular; T-countdown 96pt Regular tabular (countdown only; not bold — web bold display is commerce-banner voice, wrong in a viewfinder).
- Headings are the only permitted sans usage; there are no headings on the camera screen, so no sans appears here.

### 2.2 Color (semantic pairs; never hard-coded `.white`/`.black`)
- `ink`: light `#000000`, dark `#FFFFFF`.
- `paper`: light `#FCFCFC` (observed `--color-mm-base-off-white: #fcfcfc`), dark `#000000`.
- `hairline`: light `#000000` at 100% for primary rules, `#0000001a`-equivalent `Color.black.opacity(0.10)` for secondary (both observed token forms); dark `#FFFFFF`, secondary `Color.white.opacity(0.14)`.
- `secondary-text`: `#6C6C6C` light (observed `--color-mm-base-neutral-500: #6c6c6c`), `#A6A6A6` dark (derived for 4.5:1; verify with Accessibility Inspector, not eyeballing).
- `veil` (over preview only): `Color.black.opacity(0.55)` bands, `Color.black.opacity(0.45)` pills, `Color.black.opacity(0.60)` countdown disc — retained from current code because pure `#000`-on-preview fails contrast; Increase-Contrast variant steps rules to 2pt solid and secondary text to `ink`.
- `failure`: `#EA0000` light / `#FF5A52` dark (observed `--color-mm-base-red: #ea0000`; dark value derived for contrast on black). Reserved exclusively for failure/interruption (deliberate inversion of the verified Blackmagic `button and timecode ... turn red` recording convention, which does not apply to a stills-only app).
- `success/working`: no green/yellow. Current code's `.yellow` selected states (`CameraView.swift:142` `Color.yellow`, `CameraView.swift:161` `.yellow`, `CameraView.swift:192` `.foregroundStyle(.yellow)`, `CameraView.swift:441` `.foregroundStyle(.yellow)`) and `.red` error text (`CameraView.swift:236` `.foregroundStyle(.red)`) are replaced: selection = inversion (`paper` on `ink`) + underline, never color fill.
- No gradients except the localized preview scrim (opaque-to-transparent black, 44–88pt tall per overlay zone); no blur/material anywhere (`ultraThinMaterial` gone); no shadows.

### 2.3 Shape, line, motion
- Corner radius 0 everywhere on chrome (observed `.rounded-0{border-radius:0 !important}`); capsules in current code (`CameraView.swift:144` `.clipShape(Capsule())`, `CameraView.swift:162` `.clipShape(Capsule())`, `CameraView.swift:417` `Capsule()`, `CameraView.swift:486` `.clipShape(Circle())`, `CameraHUDButton.swift:21` `.background(.black.opacity(0.45), in: Circle())`, `ZoomIndicatorView.swift:15` `in: Capsule()`) are all replaced by 0-radius rectangles.
- Hairlines: `Rectangle().frame(height: 1/displayScale)` via `@Environment(\.displayScale)`, never `Divider` (no documented one-pixel contract). Exposed 1pt construction seams divide viewfinder/controls/filmstrip (`#000000` / white-translucent over preview).
- Motion: fades only — appear `.easeInOut(duration: 0.2)` (current code `CameraView.swift:96` `withAnimation(.easeInOut(duration: 0.2))`), disappear `.easeInOut(duration: 0.25)` (`CameraView.swift:100`), shutter press `scaleEffect 0.9` over `.easeInOut(duration: 0.15)` (`Views/ShutterButton.swift:41-42` `.scaleEffect(configuration.isPressed ? 0.9 : 1.0)` + `.animation(.easeInOut(duration: 0.15), value: configuration.isPressed)`). No spring, no decorative blink (step-end blinks conflict with recording-indicator convention and motion sensitivity — not ported). Reduce Motion = instant state change; Reduce Transparency = opaque scrims only.

### 2.4 Hit targets, safe area, RTL, sizes
- Every tappable word is a real SwiftUI `Button` (automatic `.isButton` semantics) with `.frame(minWidth: 44, minHeight: 44)` + `.contentShape(Rectangle())`; visible glyph may be 11–13pt. Current HUD already sizes the disc `CameraHUDButton.swift:20` `.frame(width: 44, height: 44)`.
- Dock lives inside `safeAreaInset(bottom)`; only backgrounds extend behind the home-indicator zone. No hard-coded 34pt spacer. Current `.padding(.bottom, 32)` (`CameraView.swift:218`) becomes `padding(.bottom, max(8, safeAreaBottom))` with background extended via `ignoresSafeArea(.container, edges: .bottom)`.
- Leading/trailing only; test `ar` + `.rightToLeft`; clock/timer numerals and the preview itself never mirror.
- Verify at 375pt (SE, smallest) and 440pt (16 Pro Max, largest) widths; XXXL Dynamic Type must wrap/truncate, never overflow. Deployment floor and per-device Island/home depths are not Apple-cited in this turn — read `safeAreaInsets` at runtime.

## 3. Layout map (conventional position → Margiela surface)

```
375pt PORTRAIT (logical pt; safe-area top/bottom observed at runtime)
+---------------------------------------------------+
| STATUS 60pt: [DNG]   [FLASH:OFF] [TIMER:OFF] [3:2..|  top safe-area +8
| hairline 1px ink                                      |
|                                                     |
|   P R E V I E W  (full-bleed, aspect-fill)          |
|   + reticle 72pt square @ tap point (NEW)           |
|   + AE/AF LOCK tab under reticle (NEW)              |
|   + grid thirds (on) / aperture bands (16:9,1:1)    |
|   + countdown disc center (timer running only)      |
|                                                     |
| hairline 1px ink                                      |
| ZERO-PROCESS STRIP 40pt: NO ENHANCEMENTS ········  |
|   CONVERSION: DEMOSAIC/BLACK-LEVEL/MATRIX/AsShotNeutral (8pt wrap or •••)|
| hairline 1px ink                                      |
| ZOOM ROW: [1.0x] [2.0x] [5.0x] + live readout      |
| ASPECT ROW: [4:3] [16:9] [1:1]  (word chips)        |
| DOCK 92pt: [thumb 60x58]   (SHUTTER 80)   [FLIP]   |
| ERROR SLOT 20pt (inline, dismissible; NOT under    |
|   home indicator)                                   |
+---------------------------------------------------+

440pt PORTRAIT — same stack; differences only:
- STATUS row spreads to full width; groups pinned leading/trailing 20pt.
- ZOOM + ASPECT rows center as one 2-line block, 16pt inter-row gap.
- DOCK: thumb x=20, shutter centered, flip trailing 20; 44pt min targets unchanged.
- Countdown disc identical 96pt (does not grow with width).
```

## 4. Element specifications

### 4.1 Status bar (top; replaces HUD-cluster styling, keeps its position)
- Position: full-width row, height 60pt (starting metric from observed `--mm-header-height: 60px`; revalidate against safe area), `padding(.leading, 20)`, `padding(.trailing, 20)`, `padding(.top, max(8, safeAreaTop))`. Left group: `DNG` word-mark (non-interactive text, T-chip, ink at 60%). Center/right group: `FLASH:OFF/ON`, `TIMER:OFF/3S/10S`, `RATIO 4:3/16:9/1:1` as bare mono `Button`s (underline on the active value only — observed `.text-decoration-underline` pattern). Current code positions the cluster `CameraView.swift:247` `HStack(spacing: 20)` with `CameraView.swift:274-275` `.padding(.trailing, 20)` + `.padding(.top, 8)` and glyph+caption `CameraHUDButton.swift:16` `VStack(spacing: 4)` — position kept, styling replaced: 17pt SF glyph on 44pt dim circle (`CameraHUDButton.swift:17-21` `.font(.system(size: 17, weight: .medium))` / `.frame(width: 44, height: 44)` / `.background(.black.opacity(0.45), in: Circle())`) + 11pt rounded caption (`CameraHUDButton.swift:23` `.font(.system(size: 11, weight: .medium, design: .rounded))`) become 11pt Courier word + value, 0-radius, veil pill only behind text over preview.
- Behavior every state: always rendered; when `flashAvailable == false` the FLASH word remains as disabled placeholder `FLASH:—` at 35% opacity (fixes current vanish-and-reflow at `CameraView.swift:256` `if viewModel.flashAvailable`); during `countdown/capturing/savingDNG` all status buttons render at 40% with `guard phase == .idle` no-op retained (`CameraViewModel.swift:160,175,188,205,210,217,230` — every control path returns unless idle), plus `.disabled(phase != .idle)` so VoiceOver announces dimmed (fixes today's fully-enabled look with silent no-op).
- Margiela justification: words replace icons per NN/g always-visible-label rule (`https://www.nngroup.com/articles/icon-usability/`); inversion + underline replaces yellow-fill selection (WCAG `3:1 against adjacent color(s)`, `https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html`) with a non-color cue so meaning survives Increase Contrast.

### 4.2 Shutter (bottom-center; the only large target)
- Size/shape: outer ring 80×80 stroke 4 (`Views/ShutterButton.swift:16-17` `Circle().strokeBorder(.white, lineWidth: 4)` + `.frame(width: 80, height: 80)`), inner fill 64×64 (`Views/ShutterButton.swift:20-22` `Circle().fill(.white)` + `.frame(width: 64, height: 64)`). Margiela restyle: flat white disc, 2pt ink ring, 0 gloss; shape stays circular (thumb affordance is conventional WHERE/WHAT, kept).
- States: idle = white disc; pressed = `scaleEffect 0.9` 0.15s (`Views/ShutterButton.swift:41-42`); `capturing/savingDNG` = 56×56 black veil 0.3 + `.disabled(isCapturing)` (`Views/ShutterButton.swift:24-27` `.fill(.black)` + `.frame(width: 56, height: 56)` + `.opacity(isCapturing ? 0.3 : 0)`; `Views/ShutterButton.swift:31` `.disabled(isCapturing)`) AND the honest phase label under the dock (§4.10). During `countdown` the shutter acts as cancel (`CameraViewModel.swift:251-253` `case .countdown: cancelCapture()`): disc shows a 2pt ink square STOP mark + `CANCEL` 11pt word beneath; second-press cancels (no restart ambiguity).
- Accessibility: `accessibilityLabel("Capture photo")` retained (`Views/ShutterButton.swift:33`); add `accessibilityIdentifier("shutter")` (the one control missing an identifier) and phase-appropriate hint (`Cancels the timer` during countdown).

### 4.3 Gallery thumbnail (bottom-left)
- Size/shape: plate 60×58 (`CameraView.swift:178-180` `RoundedRectangle(cornerRadius: 8)` + `.fill(Color.black.opacity(0.3))` + `.frame(width: 60, height: 58)`); empty box `Color.gray.opacity(0.4)` same frame (`CameraView.swift:184-186`); loaded image `.resizable()` + `.scaledToFill()` + `.frame(width: 60, height: 58)` + 6pt clip (`CameraView.swift:317-321`); loading/failure box `Color.gray.opacity(0.3)` (`CameraView.swift:323-325`). Restyle: 0-radius square 60×58, 1pt ink border; badge `photo.on.rectangle` yellow caption (`CameraView.swift:190-193` `Image(systemName: "photo.on.rectangle")` + `.font(.caption)` + `.foregroundStyle(.yellow)` + `.padding(2)`) replaced by Tabi-split mark: 2pt vertical split through thumbnail center (2D motif only, never a shoe) or circled capture index numeral in 11pt mono; loading = hairline skeleton (no shimmer); failure = `!` mono mark + tappable retry (fixes today's failure-indistinguishable-from-empty where `image = nil` persists silently).
- Behavior: tap opens gallery (`CameraView.swift:174-176`); identifier `gallery-thumbnail` (`CameraView.swift:196`). During capture phases thumbnail shows the committing frame at 50% with `SAVING` word (optimistic but labeled, never `saved` until `phase` returns idle after save).

### 4.4 Flip control (bottom-right)
- Current: `CameraHUDButton` with `arrow.triangle.2.circlepath.camera` (`CameraView.swift:209-215`), label `Camera` value `Back/Front` (`CameraControls.swift:23-28` `"Back" / "Front"`). Keep WHERE (dock right, 44×44) and SF Symbol (per-bundle rule: keep SF Symbols where iOS convention governs gesture affordance); restyle glyph to ink mono-weight on veil square, caption `CAMERA BACK/FRONT` 11pt. Flip resets zoom 1.0 + exposure `.zero` (`CameraViewModel.swift:163-167`); spec a 0.2s fade + transient `FRONT · 1.0x · EV 0` confirmation line (fixes silent reset).

### 4.5 Zoom presets + live readout (above dock)
- Current chips: `HStack(spacing: 12)` (`CameraView.swift:127`), 13pt bold rounded (`CameraView.swift:133` `.font(.system(size: 13, weight: .bold, design: .rounded))`), padding 10/6 capsule (`CameraView.swift:138-144`), selected black-on-yellow vs white on black 0.5 (`CameraView.swift:134-143`), bottom gap 10 (`CameraView.swift:149`), identifiers `zoom-preset-*` (`CameraView.swift:146`). Factors from `ZoomPresets.factors(in:)` = lower bound + 2×/5× when contained (`CameraControls.swift:222-227`); front fixed-1× yields a single chip. Labels POSIX `%.1fx` (`CameraControls.swift:96-97`).
- Restyle: 12pt Courier word-chips, 0-radius, 1pt ink border; selected = paper-on-ink + underline; unselected = ink on veil; spacing 12 kept; `padding(.bottom, 10)` kept. NEW live readout: persistent `ZoomIndicatorView` value (`ZoomIndicatorView.swift:9-17` 15pt rounded `.monospacedDigit()` white on black-0.45 capsule, padding 10/4) becomes 15pt mono ink tabular, shown always (not only above dock), updating continuously during pinch (`CameraView.swift:287-305` `MagnificationGesture` driving `ZoomMath.factor(base:magnification:range:)`), snapping highlight to nearest preset within 0.01 (`CameraControls.swift:231-233`). Pinch-at-limit = 3 short haptic ticks + readout flashes `LIMIT 1.0x/5.0x` (fixes silent clamp).

### 4.6 Aspect strip
- Current: `HStack(spacing: 16)` centered (`CameraView.swift:152`), 12pt bold rounded white (`CameraView.swift:157`), padding 12/6 capsule, yellow-selected (`CameraView.swift:159-162`), insets horizontal 40 + bottom 8 (`CameraView.swift:168-169`), ids `mode-*` (`CameraView.swift:164`), labels `4:3/16:9/1:1` (`CameraControls.swift:152-157`). Restyle identically to zoom chips (word-chips, underline-selected). DNG stays full-sensor; aspect is view-time crop (`CameraControls.swift:122-124`); mask (§4.9) is the visual contract.

### 4.7 Self-timer countdown
- Current: 96pt bold rounded white on black-0.6 circle (`CameraView.swift:481-486` `Text("\(remaining)")` + `.font(.system(size: 96, weight: .bold, design: .rounded))` + `.foregroundStyle(.white)` + `.padding(24)` + `.background(.black.opacity(0.6))` + `.clipShape(Circle())`), tap cancels (`CameraView.swift:488` `.onTapGesture(perform: onCancel)` calling `viewModel.capture()` at `CameraView.swift:116-120`), tick 1s sleep (`CameraViewModel.swift:318` `Task.sleep(for: .seconds(1))`), labels `Off/3s/10s` (`CameraViewModel.swift:358-363`). Spec: 96pt Courier Regular tabular white on 0.6 disc (size kept; weight de-bolded per §2.1), `TIMER 3S · TAP TO CANCEL` 11pt caption beneath, hit area = padded disc rect (code comment claims fullscreen cancel but hit area is only the disc — spec the disc + explicit CANCEL word, never claim fullscreen). Width shifts between `10` and single digits: fix disc to max-width (measure `10` once) so no mid-countdown resize.

### 4.8 Exposure slider
- Current: 220pt track (`CameraView.swift:48` `.frame(height: 220)` + trailing 14 / bottom 120), 5pt black-0.45 capsule (`CameraView.swift:417-420`), white 0.75 ticks 7pt zero / 4pt else (`CameraView.swift:422-424`), yellow 12pt bold bubble offset −30 (`CameraView.swift:439-445`), drag `minimumDistance 0` continuous then snap on release (`CameraView.swift:430-434`), range −3…+3 (`CameraView.swift:409-411`), labels `0/+1/−2/−1/3…` with U+2212 minus (`CameraControls.swift:287-295`), auto-dismiss 2500ms (`CameraView.swift:98` `Task.sleep(for: .milliseconds(2500))`) with 0.2/0.25 fades, accessibility label/value present (`CameraView.swift:449-451`). Model snaps to 1/3 stops clamped to device bias (`CameraViewModel.swift:229-237`; `CameraControls.swift:250-257` thirds −9…+9, step 1/3).
- Spec: keep geometry/gesture/timings; restyle bubble to paper-on-ink 12pt mono (yellow removed); add tick highlight at committed stop + min/max stopper treatment + haptic per 1/3 stop (fixes today's no-highlight/no-haptic/no-stopper drag). Value readout beside track in `+1 2/3` format; returns to 0 only via explicit reset, never silently on reticle dismiss.

### 4.9 Tap-to-focus reticle (MISSING — new)
- Gap: tap-to-meter sets focus+exposure at the same normalized point (`CameraViewModel.swift:214-223`; `CaptureService.swift:384-405` gating `isFocusPointOfInterestSupported/isExposurePointOfInterestSupported`, `lockForConfiguration`, same-point AF+AE) but renders zero marker — only the EV slider appears.
- Spec: 72pt 0-radius square outline, 1.5pt paper stroke + 1pt ink outer keyline (legible on any scene), centered exactly at tap point; appears 0.15s fade, holds while slider visible, dismisses on next tap/mode change/capture; unsupported hardware surfaces the typed `This camera does not support tap-to-focus/exposure.` (`CaptureService.swift:763`) inline (§4.11), never silent.

### 4.10 AE/AF lock indicator (MISSING — new)
- Spec: press-and-hold ~1s at the reticle enters lock; persistent tab `AE/AF LOCK` 11pt mono paper-on-ink pinned 8pt below reticle until second tap unlocks; exposure drag remains live while locked. Lock persists across capture, clears on lens switch. Conventional affordance kept (hold-to-lock position/gesture), styling fully Margiela.

### 4.11 Grid, aspect mask
- Grid: thirds only, fractions `[1/3, 2/3]` (`CameraControls.swift:107` `static let lineFractions: [CGFloat] = [1.0 / 3.0, 2.0 / 3.0]`), 0.7pt white 0.6 (`GridOverlayView.swift:37` `.stroke(.white.opacity(0.6), lineWidth: 0.7)`), clipped to aperture, non-interactive (`GridOverlayView.swift:39-41`), id `grid-overlay`. Toggle states fill vs outline (`CameraView.swift:250`). Restyle lines to 1/displayScale paper at 70%; keep clipping rule (grid never enters masked bands).
- Mask: 16:9/1:1 bands black 0.55 + 1pt white-0.25 aperture border (`CameraView.swift:384-389`); 4:3 `Color.clear` (`CameraView.swift:394`). Restyle border to 1pt paper solid; bands unchanged (contrast necessity). Identifier `aspect-overlay` (`CameraView.swift:392`).

### 4.12 Zero-process status surface (the feature, made honest)
- Honest-verb constraint from code: capture is pure Bayer (`CaptureService.swift:536` `AVCapturePhotoSettings(rawPixelFormatType: bayerFormat)`; `CaptureService.swift:679` `photoOutput.isAppleProRAWEnabled = false` with comment `Disable Apple ProRAW to get pure Bayer`); develop is `CIRAWFilter(imageData:)` (`CIRAWZeroProcessor.swift:31`) with 15 enhancements neutralized to 0.0/false (`CIRAWZeroProcessor.swift:63-81`) while demosaic, black-level subtraction, color matrix, and AsShotNeutral white balance are deliberately retained (`CIRAWZeroProcessor.swift:8-13`); `Zero-process is the only recipe; there are no development modes.` (`CIRAWZeroProcessor.swift:19`).
- Therefore the screen NEVER says `NO PROCESSING`, `PURE SENSOR`, `UNTOUCHED`, or `ProRAW/HDR`. The locked strip (40pt, §3) reads: line 1 `ZERO PROCESSING AT CAPTURE — NO ENHANCEMENTS ADDED`; line 2 `CONVERSION ALWAYS ON: DEMOSAIC · BLACK LEVEL · COLOR MATRIX · AsShotNeutral WB`. At shutter press the strip flashes `DEVELOPING: CONVERSION ONLY` during `capturing`, `WRITING DNG` during `savingDNG` (phase machine `idle/countdown/capturing/savingDNG`, `CameraViewModel.swift:20-29`; second press never duplicates, `CameraViewModel.swift:250-266`). `DNG` word-mark in the status bar is non-interactive (no RAW toggle exists by design; torch-pulse flash labeled `FLASH` word since system flash is unavailable in Bayer RAW — `CaptureService.swift:361-376` `RAW single exposures cannot use the processed-pipeline photo flash, so the torch pulse is the honest flash equivalent`).
- Capture-truth behaviors to surface, not hide: zoom>1 captures at 1× internally with 250ms settle then restores (`CaptureService.swift:518-531`); preview snaps FOV visibly — spec a `FRAMING 2.0x · CAPTURING AT 1x · RESTORING` transient line so the snap is explained, never mysterious.

## 5. Missing-piece resolutions (allmust-ship)
1. Reticle/AE-lock: §4.9–§4.10 above.
2. Honest capturing/saving: phase label + shutter STOP state + thumbnail `SAVING`; no fifth state invented (phase enum is exactly four, `CameraViewModel.swift:20-29`).
3. Camera-unavailable: fullscreen paper-on-ink panel (not bare `Color.black`, `CameraView.swift:26,87`) with `CAMERA UNAVAILABLE`, typed reason (`No back wide camera is available.` / `No Bayer RAW format is available on this camera.` / `Camera and photo library access are required.` — `CaptureService.swift:739,747`; `CameraViewModel.swift:383`), and one `RETRY` + one `OPEN SETTINGS` word-button; restricted vs denied copy distinguished (restricted cannot be fixed in Settings — bundle correctly flags the sameness gap).
4. Error banner: inline slot above dock (never under the home indicator), ink text + `!` mark + `DISMISS` word; auto-clears on next idle shutter (`CameraViewModel.swift:255` `error = nil`) AND on manual dismiss; red `#EA0000` reserved for this + interruption only.
5. Zoom readout: always-visible tabular readout (§4.5).
6. HUD availability: disabled placeholders hold layout (§4.1); nothing vanishes.

## 6. Motion, accessibility, dark mode
- Countdown ticks swap instantly (no animation); slider fades 0.2/0.25; shutter 0.15; overlays `.transition(.opacity)` (`CameraView.swift:51`).
- Every gesture has a button equivalent (zoom chips, EV slider committed value, on-screen shutter, Done/back equivalents); no gesture is the only path (NN/g + WCAG basis above; iOS per-gesture VoiceOver matrix is unconfirmed — spec equivalents as design decision).
- White-room gallery text targets 4.5:1 normal / 3:1 large (`https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html`); overlay words always carry veil/scrim — never bare on preview. Full dark-appearance pair via semantic colors; hard-coded `.white/.black` forbidden.

## 7. Copy allow-list (camera screen only)
`DNG · FLASH:OFF/ON · TIMER:OFF/3S/10S · RATIO 4:3/16:9/1:1 · ZERO PROCESSING AT CAPTURE · CONVERSION ALWAYS ON · NO ENHANCEMENTS ADDED · AE/AF LOCK · TAP TO CANCEL · SAVING · WRITING DNG · CAMERA UNAVAILABLE · RETRY · DISMISS`. Banned: filter, enhance, HDR, style, ProRAW (as pikicam output), NO PROCESSING, pure sensor dump, unconverted pixels.
