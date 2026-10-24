# pikicam DESIGN — ADAPTIVITY AND ACCESSIBILITY

> **Scope:** the R-swaps, Dynamic Type, VoiceOver, contrast, RTL, orientation, haptics, and capture-flow accessibility for the Margiela surface over live camera imagery and the white-room gallery/viewer. Repo root `/Users/adrifadilah/Desktop/pikicam`. Source under `pikicam/`.
>
> **This spec REPLACES the prior `spec-adaptivity-a11y.md`.** It is expressed entirely on the canonical token scale (`.P.DESIGN.md` §0.5 #7 / §2.2). Every value carries a provenance tag.
>
> **Authority (R1):** the code is the only authority on what exists. `docs/`, this file, and every spec are non-authoritative about current behaviour. `file:line` for code; `spec:line` for the spec set; URL for web.
> **Provenance (R7):** `OBSERVED` (from code or a fetched source) · `DERIVED` (computed from observed values, e.g. WCAG ratios) · `PROPOSAL` (authored / owner-directed / implementer-pinned). A `PROPOSAL` is never presented as `OBSERVED`.
> **Owner rulings of 2026-10-01 outrank this file** (R4). Applied here: hybrid where Pole B lands **only on the gesture layer** (sewn tack, genuinely blank tag, no house name in any symbol name) and Pole A is kept on **content and surface**; the full provenance DATA sheet; the date header, DNG count readout, and index chip kept; volume-button capture kept with the system HUD accepted; **landscape**; iPad out of scope; the bypass expressed by **absence** on the camera chrome and **stated** on the viewer's per-image sheet; `baselineExposure` left at the decoder default (PROPOSAL).
> **Corrections applied from `VERIFICATION.md` §6:** #1 (fabricated token names / secondary provenance), #3 (IC ratio locked at 6.83:1; vestigial `#FFFFFF` row deleted), #4 (white-room dark ink supplied, §5), #5 (shape-deletion list completed), #6 (rule locations corrected), #7 (tracking given in pt), #8 (red-in-white-room evidence re-opened — red removed from the white room here), #9 (iPad stated out of scope), #10 (empty-state `0` mapped onto a token), #13 (vocabulary closed), #14 (shutter identifier resolved to `camera-shutter`), #15 (full DATA-sheet row set stated), #16 (vocabulary reclassified PROPOSAL), #17 (identifier-breakage claims corrected), #18 (`baselineExposure` per §5 of VERIFICATION).

---

## 0. The canonical scale — the only permitted tokens

Every type, ink, spacing, rule, and face value below is one of these. Anything in this spec that is not one of these is a **component size** (shutter, reticle, countdown square, thumbnail, slider height) and is marked PROPOSAL where it appears.

### 0.1 Type — six tokens, no others

| Token | Size / Weight | Tracking | Case | `relativeTo` |
|---|---|---|---|---|
| `display` | 96 Bold, tabular | 0 | numerals | `.largeTitle` |
| `title` | 17 Bold | `+40/1000em` = **0.68pt** | UPPERCASE | `.headline` |
| `body` | 14 Regular | 0 | sentence | `.body` |
| `label` | 13 Regular; **Bold when selected** | `+80/1000em` = **1.04pt** | UPPERCASE | `.callout` |
| `caption` | 11 Regular | `+80/1000em` = **0.88pt** | UPPERCASE | `.caption` |
| `tick` | 11 Regular, `monospacedDigit` | 0 | numerals + `X` `+` `−` `/3` | `.caption` |

Tracking pt values are `DERIVED` from the em values (§6 correction #7): the em→pt pairs live only in `spec-design-system-tokens.md:61-64`, not in `.P.DESIGN.md`.

**Face:** Courier New via `Font.custom(_:size:relativeTo:)`. The **two-arg** `Font.custom(_:size:)` is FORBIDDEN for UI text — it freezes under Dynamic Type. Fallback stack: `Courier New` → `Menlo` → `.system(design: .monospaced)`. **Sans is forbidden in chrome.** Italic forbidden; weights Regular/Bold only.

### 0.2 Ink — two rooms

**BLACK room** (camera chrome + permission interstitials):

| Token | Value | Provenance |
|---|---|---|
| `bg` | `#000000` | OBSERVED (`CameraView.swift:26`) |
| `ink` | `#FFFFFF` | OBSERVED |
| `secondary` | White 60% | PROPOSAL |
| `rule` | White 25% | OBSERVED (`CameraView.swift:389` `.white.opacity(0.25)`) |
| `wash` | Black 55% | OBSERVED (`CameraView.swift:384`) |
| `scrim` | Black 45% → 0%, 88pt | PROPOSAL — replaces per-control `black.opacity(0.45/0.5/0.6)` |
| `selectBg` / `selectInk` | `#FFFFFF` / `#000000` | PROPOSAL — inversion only |
| `fail` | `#EA0000` | OBSERVED house `--color-mm-base-red` — **failure only** |

**WHITE room** (gallery grid + viewer), *light appearance*:

| Token | Value | Provenance |
|---|---|---|
| `bg` | `#FCFCFC` | OBSERVED house token `--color-mm-base-neutral-100`'s sibling `--color-mm-base-off-white` |
| `ink` | `#000000` | OBSERVED |
| `secondary` | `#6C6C6C` | OBSERVED house token `--color-mm-base-neutral-500`; **5.12:1** on `#FCFCFC` DERIVED |
| `secondary-IC` | `#595959` | DERIVED **6.83:1** on `#FCFCFC` — the Increase Contrast step only |
| `rule` | `#000000` @ `1/displayScale` | PROPOSAL |
| `ruleSoft` | Black 10% | PROPOSAL — intra-grid gutters only |
| `selectBg` / `selectInk` | `#000000` / `#FFFFFF` | PROPOSAL — inversion only |
| `fail` | — | **NO RED IN THIS ROOM** (`.P.DESIGN` §0.5 #6). Error = `ink` + `ERROR —` prefix + Bold + a `1/displayScale` rule above. |

The two fabricated names `--color-mm-base-strong-grey` / `--color-mm-base-light-grey` are **deleted** (VERIFICATION §6 #1). The real names are `--color-mm-base-neutral-500` (`#6c6c6c`) and `--color-mm-base-neutral-100` (`#e5e5e5`).

**WHITE room — dark appearance:** supplied in §5 (correction #4).

### 0.3 Space, rule, radius

- **Space scale:** `2 / 4 / 8 / 12 / 16 / 20 / 24 / 32` only. No other *spacing/padding/gap* value may appear. Current `10/14/40` remap: `10→8`, `14→16`, `40→32`.
- **Rule:** `Rectangle().frame(height: 1 / displayScale)` via `@Environment(\.displayScale)`. **`Divider()` is FORBIDDEN** (no one-physical-pixel contract).
- **Radius:** `0` everywhere.

---

## 1. Dynamic Type

### 1.1 Every control maps onto one of the six tokens

| Control (current code) | Old size/face | Canonical token |
|---|---|---|
| HUD button caption (`CameraHUDButton.swift:23`, `.system(size: 11, weight: .medium, design: .rounded)`) | 11 rounded | `caption` |
| Zoom chip (`CameraView.swift:133`, 13 bold rounded) | 13 rounded | `label` |
| Aspect chip (`CameraView.swift:157`, 12 bold rounded) | 12 rounded | `label` |
| Zoom indicator (`ZoomIndicatorView.swift:10`, 15 medium rounded + `monospacedDigit`) | 15 rounded | `tick` (11 monospacedDigit) |
| Exposure value (`CameraView.swift:440`, 12 bold rounded) | 12 rounded | `tick` |
| Countdown numeral (`CameraView.swift:482`, 96 bold rounded) | 96 rounded | `display` (96 Bold tabular) |
| Gallery title (`GalleryView.swift:49` `"Library"`) | system title | `title` (→ `LIBRARY`) |
| Viewer title (`GalleryView.swift:194` `"DNG Viewer"`) | system title | `title` (→ `DNG VIEWER`) |
| Empty-state heading (`GalleryView.swift:99` `"No captures"`) | `ContentUnavailableView` | `title` (→ `NO CAPTURES`) |
| **Empty-state `0` numeral** (`0 / NO CAPTURES`, new) | `DISPLAY-28` **deleted** | **`display`** — the numeral maps onto `display` (a numeral token), capped via `.dynamicTypeSize(...DynamicTypeSize.accessibility3)` (correction #10) — PROPOSAL |
| Error body (`CameraView.swift:233-239`) | `.caption` | `body` (14 Regular) |
| HUD status words (`FLASH`/`TIMER`/`4:3`) | — | `caption` |
| Date header (gallery section header, kept by owner) | — | `title` — PROPOSAL |
| DNG count readout `DNG 03 / 11` (kept by owner) | — | `caption` for `DNG`, `tick` for `03 / 11` |
| Index chip `01` (kept by owner) | — | `tick` |

Nothing is fixed-size: every token passes a `relativeTo:` value, so all sizes scale automatically.

### 1.2 Largest accessibility sizes (AX1–AX5)

- **Camera HUD row** (`CameraView.swift:247` region, `HStack(spacing: 20)`): wraps via `ViewThatFits(in: .horizontal)` — first choice one row; fallback `VStack(alignment: .trailing, spacing: 12)` pinned trailing (`12` on scale). Never truncate `FLASH / TIMER / GRID / 4:3`. Never shrink the hit area below §8.
- **Bottom dock** (`.padding(.horizontal, 20)` + `.padding(.bottom, 32)` at `CameraView.swift:217`): at `.accessibility1` and above the zoom chips move into a `ScrollView(.horizontal)` strip with the same 44pt targets; the shutter stays centred (80pt, PROPOSAL); the thumbnail stays fixed (component size, PROPOSAL).
- **Exposure slider** (`.frame(height: 220)` + `.padding(.trailing, 14)` + `.padding(.bottom, 120)` at `CameraView.swift:48-49`): height becomes `min(220pt, 0.5 × safeHeight)`; the value bubble (`CameraView.swift:442` region, `.padding(6) + .offset(y: -30)`) flips below the thumb when within 32pt of the top safe edge. Insets map onto the space scale: `trailing 14 → 16`.
- **Gallery grid** (`GalleryView.swift:106`, `GridItem(.adaptive(minimum: 100), spacing: 2)`): at AX3+ step to `minimum: 140`, fewer and larger cells, so the mono captions do not clip. Banner error text already clamps at `GalleryView.swift:125` `.lineLimit(2)`.

### 1.3 Fallback

- If `UIFont(name: "Courier New", size:)` returns nil, fall through to `Menlo` then `.system(design: .monospaced)`; layout is unchanged because both use the same `relativeTo` ramp.
- If text still overflows at AX5, truncate with `.lineLimit(1) + .truncationMode(.tail)` **on chips only** — never on error strings. Error text wraps to a max of 3 lines.

---

## 2. VoiceOver

### 2.1 One announcement pattern

`"{WORD}, button{, value}{, hint}"` — word, then `button`, then an optional value, then an optional hint. **The visible label IS the accessible label**; there is never a second name. Every tappable word is a real SwiftUI `Button` (a `Button` carries `.isButton` automatically). Custom tap views are forbidden except the countdown, which keeps `.accessibilityAddTraits(.isButton)` (`CameraView.swift:490`).

Values reuse the existing value contracts:

- `FLASH` → `value OFF / ON` (`CameraControls.swift:64-65` `"Off"/"On"` → `OFF/ON`).
- `TIMER` → `value OFF / 3S / 10S` (`CameraViewModel.swift:358-363` `"Off"/"3s"/"10s"`).
- `CAMERA` → `value BACK / FRONT` (`CameraControls.swift:26` `"Back"/"Front"`).
- exposure slider → `label "Exposure compensation"` + `value "{ExposureCompensation label}"`: `0, +1, −2, +2/3, −1/3, +1 2/3, −2 1/3`, with **U+2212 minus** (`CameraControls.swift:287` sign logic). Byte-exact; do not "fix".
- zoom indicator → `value "1.0X"` (POSIX `%.1fx`, `CameraControls.swift:97`).

Traits: `.isButton` on all word controls; `.isSelected` on the selected chip. Disabled-during-capture adds nothing spoken beyond `isEnabled false` and the dimmed token (§10); never announce the word "disabled".

### 2.2 Identifiers — the registry is the contract

The single source is `ControlIDRegistry` (`pikicam/Core/Design/ControlIDRegistry.swift`). A bare `accessibilityIdentifier("…")` literal that is not sourced from the registry is a `DesignViolation` (§8.1). **The shutter is resolved to one name: `camera-shutter`** (correction #14) for both the on-screen shutter and its tests. The identifier is assigned at the call site; today `ShutterButton.swift:33` carries only the label `Capture photo` and **no identifier** (VERIFICATION R3).

| Control | Registry identifier |
|---|---|
| Shutter | `camera-shutter` (label `SHOOT`; kept label-alias `Capture photo` for the existing test) |
| Library (dock) | `camera-library` |
| Zoom preset chip | `camera-zoom-preset-{1.0x\|2.0x\|5.0x}` |
| Aspect chip | `camera-aspect-{4x3\|16x9\|1x1}` |
| Zoom indicator | `camera-zoom` |
| Preview | `camera-preview` |
| Grid overlay | `camera-grid-overlay` |
| Aspect mask | `camera-aspect-mask` |
| Exposure slider | `camera-exposure` |
| Countdown | `camera-timer-countdown` |
| Grid / Flash / Timer / Flip | `camera-grid` / `camera-flash` / `camera-timer` / `camera-flip` |
| Cancel / Retry | `camera-cancel` / `camera-retry` |
| Gallery title / grid / loading / empty / error | `room-title` / `room-grid` / `room-loading` / `room-empty` / `room-error` |
| Gallery cell | `room-cell-{index}` |
| Gallery Shoot / Delete / Retry | `room-shoot` / `room-delete` / `room-retry` |
| Viewer back / delete / share / hide-show / DNG | `viewer-back` / `viewer-delete` / `viewer-share` / `viewer-hide-show` / `viewer-dng` |
| Viewer loading / failure / background | `viewer-loading` / `viewer-load-failure` / `viewer-background` |

**Corrected claims (VERIFICATION §6 #17, R1–R3).** The prior spec's identifier set was wrong about the current tree: `gallery-thumbnail` (`CameraView.swift:196`) and `gallery-latest-thumbnail` (`GalleryView.swift:28`) are **two different controls** (the registry collapses the library control to `camera-library` and removes the bar thumbnail per `.P.DESIGN` §0.5 #9); `app.activityIndicators.firstMatch` is **not** in the current tree (`SmokeLaunchTest.swift:305` is `app.activityIndicators["viewer-loading"]`); and the shutter has **no identifier at all** in code. The UI suite is **red** right now, mid-migration (VERIFICATION §4). Owner decision: leave it red and fix it in the wiring phase, where both sides are replaced at once.

### 2.3 Reading order

- **Camera** (top-to-bottom, trailing-to-leading inside the HUD to match the visual): 1) status words `DNG · FLASH OFF · TIMER OFF · 4:3` (non-interactive `.accessibilityElement(.text)`) — `DNG` carries the bypass by **absence**, no manifesto words; 2) `camera-grid`, `camera-flash`, `camera-timer`, `camera-flip`; 3) `camera-zoom` (status, not action); 4) zoom chips; 5) aspect strip; 6) `camera-exposure` (only when visible); 7) `camera-library`; 8) shutter `SHOOT`; 9) flip. Enforce with `.accessibilitySortPriority`. The preview is `accessibilityHidden(true)` except for its `camera-preview` tap-to-meter action.
- **Gallery:** 1) `LIBRARY` title (`room-title`); 2) date header; 3) DNG count readout; 4) grid `room-grid` → cells `room-cell-{index}` newest-first (test contract: `room-cell-0` is newest); 5) the index chip `01`. Bottom bar: `SHOOT · DELETE · RETRY` (words only; no thumbnail — `.P.DESIGN` §0.5 #9).
- **Viewer:** 1) `DNG VIEWER`; 2) the image (label `DNG photograph, framing {aspect} at {zoom}`); 3) index chip; 4) `DNG 03 / 11` count; 5) `HIDE`/`SHOW`; 6) `DELETE`; 7) `SHARE`; 8) `BACK`. The viewer's **per-image provenance sheet** is reached from the count readout and **states the bypass** (§2.5).
- **Permissions:** `title` first, `body` copy, then the word buttons.

### 2.4 Closed vocabulary (PROPOSAL — VERIFICATION §6 #16)

`SHOOT`, `CANCEL`, `GRID ON|OFF`, `FLASH OFF|ON`, `TIMER OFF|3S|10S`, `4:3|16:9|1:1`, `1.0X|2.0X|5.0X`, `LIBRARY`, `DELETE`, `SHARE`, `HIDE|SHOW`, `CAMERA BACK|FRONT`, `RETRY`, `BACK`, `DNG`, `ERROR —`, `FOCUS RESET`, `SAVING…`, `0 / NO CAPTURES`. Every word differs in case or wording from the strings in code today (`"Library"`, `"Retry"`, `"Back to Camera"`, `"DNG Viewer"`); the set is therefore a PROPOSAL, not a description of code. Nothing outside this set renders.

### 2.5 The viewer per-image sheet — the one place the bypass is stated

Per the owner ruling, the bypass is **absent** on the camera chrome (no manifesto strip) and **stated** on the viewer's per-image sheet. The sheet is the **FULL provenance sheet** (owner rejected the strip-to-raw-DNG-tags ruling):

- `FILE pikicam-<uuid>.dng` · `BYTES: 24 117 888` · `SENSOR: 4000×3000 FULL-SENSOR RETAINED` · `BAYER: 14-BIT RGGB` · `EXPOSURE: 1/120 · f/1.9 · ISO 64` · the recipe list.
- Rows set in `caption` (labels) + `tick` (values) inside the white room.
- The recipe list is the 15-entry neutral list from `CIRAWZeroProcessor.swift:63-81` plus the 4 retained conversion stages (`:8-13`). **`baselineExposure` is left at the decoder default** (do not zero a file-derived default without cause) — the sheet therefore lists `baselineExposure` as *decoder default*, not `0.0`, and this is a PROPOSAL pending the two-step measurement (VERIFICATION §5). The stale header comment at `CIRAWZeroProcessor.swift:4-17`, which claims only 4 stages run while the recipe zeroes `baselineExposure`, must be corrected regardless of the verdict (R3).
- Volume-button divergence (`no burst · single exposure · ProRAW off`) is stated here too, so the sheet is the single honest record.

VoiceOver reads the sheet top-to-bottom, one row per element, label then value.

### 2.6 Custom actions — no gesture is the only path

| Gesture-only today | Button/slider equivalent (ships here) |
|---|---|
| Tap-to-meter (`CameraView.swift:79` `onTap(point)`), zero reticle today | Adds a visible reticle (§3) **and** a `FOCUS RESET` button (resets to centre `(0.5, 0.5)`) |
| EV vertical drag (`CameraView.swift:430` `DragGesture(minimumDistance: 0)`) | Keeps the slider and adds `− / +` stepper words (1/3 EV, same `ExposureCompensation` model, `minThird -9 / maxThird 9`, `CameraControls.swift:250-251`) |
| Pinch zoom (`CameraView.swift:58` `.gesture(pinchGesture)`) | Zoom chips `1.0X/2.0X/5.0X` (`CameraControls.swift:222-227`) + stepper; chips are the accessible path |
| Countdown tap-cancel (`CameraView.swift:488` `.onTapGesture`) | The countdown is a `Button` with hint `Cancels the timer`; the shutter during countdown also cancels and announces `Timer cancelled` |
| Viewer single-tap chrome toggle (`GalleryView.swift:183`, with first-tap swallow `hasConsumedOpeningTap`) | The `HIDE`/`SHOW` word (`viewer-hide-show`) — the current hidden state has zero visible affordance; the fix keeps a 44pt `SHOW` word visible at all sizes |
| Double-tap / pinch / swipe in the viewer | None today (`GalleryView.swift:141-248` is tap-toggle only). This spec adds `Zoom 1x/2x`, `Previous/Next`, `BACK` as words **if** those gestures are added later; until then the viewer is fit-only and this spec says so |

Always-visible words, never hover/long-press reveal: `https://www.nngroup.com/articles/icon-usability/` — *"Icon labels should be visible at all times, without any interaction from the user."*

---

## 3. Contrast over the LIVE PREVIEW (black room)

Bare white words over an unpredictable photograph cannot meet any ratio. **Do not ship bare overlay text.** Every over-preview word resolves through one boundary type, `LegibilitySurface`.

### 3.1 The treatment

- **HUD + chips + dock** sit on one bottom-anchored strip, not scattered pills: full-width strip in `wash` (Black 55%, OBSERVED `CameraView.swift:384`) behind the zoom chips / aspect strip / dock, height = content + 16pt, extended into `safeAreaInset(bottom)`. Top edge bounded by a `rule` (White 25%, OBSERVED `CameraView.swift:389`) — `1/displayScale`.
- **Top status words** (`DNG · FLASH · TIMER · 4:3`) sit on the `scrim` (Black 45% → 0%, 88pt, PROPOSAL), behind the status bar and HUD cluster.
- **Selected chip** = true inversion inside the strip: `selectBg` `#FFFFFF` fill + `selectInk` `#000000` text. The yellow fills at `CameraView.swift:142/161` are DELETED — yellow is reserved for nothing on camera.

### 3.2 Ratios the treatment must meet

- Normal words (`label` 13 / `caption` 11): **4.5:1** white text vs the scrim-backed composite, measured with Accessibility Inspector on three reference frames: white-sky, black-night, busy-texture. Per `https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html` — *"at least 4.5:1"* normal, *"at least 3:1"* at *"18pt or 14pt bold"*.
- Large words (`display` 96 Bold): **3:1** minimum (OBSERVED: `CameraView.swift:483` `.white` on `:485` `.black.opacity(0.6)` passes; keep).
- Non-text indicators (reticle, grid, aperture border, selected-chip fill): **3:1 against adjacent colors** per `https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html`.

### 3.3 Reticle (new — fixes the missing focus state)

- 72pt square outline (component size PROPOSAL — Apple documents no pt size). Stroke = `rule` weight (`1/displayScale`) in `ink`; a `wash` (Black 55%) outer border band 4pt (on scale); two stacked strokes, no blur material.
- No word on the reticle (the vocabulary is closed). The accessible path is the `FOCUS RESET` button (§2.6).
- Auto-dismisses on next tap / mode change / capture; never persists as state.

### 3.4 Exposure slider

- Track keeps `wash` (Black 55%, from `CameraView.swift:418` `.black.opacity(0.45)`) at 5pt (component, PROPOSAL); tick dots `:423` `Color.white.opacity(0.75)` raised to `0.9` inside the scrim (PROPOSAL).
- Value text `:441` `.foregroundStyle(.yellow)` → `ink` (`#FFFFFF`) on a `wash` bubble (`:443`). Bubble text = `tick` (11 monospacedDigit). Yellow-on-translucent fails 4.5:1 on bright frames.

### 3.5 Fallback

- If the inspector still fails on a frame (pure-white snow at max brightness): the strip/wash opacity steps to `0.75` under Increase Contrast (§6). No per-frame luminance sampling ships in v1 (no luminance-meter dependency).
- **Reduce Transparency ON:** replace the gradient with a solid `Black 100%` top bar 88pt and a solid bottom strip (§6).

---

## 4. Contrast in the WHITE ROOM — light appearance (gallery / viewer / permissions)

- **Text colours:** `bg #FCFCFC`, `ink #000000`, `secondary #6C6C6C` (OBSERVED house token, **5.12:1** DERIVED on `#FCFCFC`). The Increase Contrast step is `secondary-IC #595959` (**6.83:1** DERIVED) — locked at 6.83 in every location (correction #3; the prior "6.82" and the vestigial `#6C6C6C` on `#FFFFFF` = 5.25:1 row are deleted).
- **Hairlines:** `rule` `#000000` at `1/displayScale`; `ruleSoft` Black 10% for intra-grid gutters. `#E5E5E5` on `#FCFCFC` is 1.23:1 — **rule-soft only, never text** (DERIVED).
- **Rule locations (correction #6 — the "exactly four" claim is dropped):** below the top bar; above the bottom dock; between the viewer image and its metadata row; the blank tag's own border; **above the error banner**; **the grid-banner border**. Six, stated, not four.
- **Hairline survival:** a `1/displayScale` rule is a boundary, never a text substitute. A rule is never the sole state cue.
- **Increase Contrast ON:** rules step to 2px solid; `secondary` → `secondary-IC` (`#595959`), and at maximum contrast → `ink`. Exact 2px is a PROPOSAL (no Apple source mandates it).
- **Reduce Transparency ON:** every `.ultraThinMaterial` (gallery banner `GalleryView.swift:131` `.background(.ultraThinMaterial)`, `:132` `RoundedRectangle(cornerRadius: 8)` → radius 0) is replaced with opaque `bg #FCFCFC` + a `rule`.
- **Selection:** inversion block (`selectBg #000000` / `selectInk #FFFFFF`) + the **sewn tack** (Pole B) + Bold — **never** an underline, never a tint wash. The non-colour cue is mandatory so meaning survives Increase Contrast and Differentiate Without Color.
- **Errors:** NO RED in this room. `ink` + `ERROR —` prefix + Bold + a `1/displayScale` rule above.
- **Forced dark removed:** both `preferredColorScheme(.dark)` calls (`PikicamApp.swift:24`, `GalleryView.swift:69`) are deleted (`.P.DESIGN` §6). Keeping them reintroduces the white-room failure — `Welcome to pikicam` (`RootView.swift:67`) and `Honest photographs…` (`:70`) would never show light.
- **Red reserved (black room only):** camera error `CameraView.swift:236` `.foregroundStyle(.red)` stays `fail` `#EA0000`; the gallery/viewer trash is **not** red in the white room (correction #8 — the prior spec cited `spec-a11y:131`, which keeps red in both modes, the opposite of the ruling).

---

## 5. WHITE room — DARK appearance (supplied; correction #4)

`.P.DESIGN` §2.1 promises the white room ships an explicit dark-appearance pair, but §2.3's white-room table has no dark column and the two sources **disagree** (`spec-camera-screen-spec.md:41` says `#A6A6A6`; `spec-gallery-viewer-spec.md:81` says `#A8A8A8`). The un-supplied pair is supplied here.

### 5.1 Chosen pair

**Chosen dark-appearance `secondary` = `#A8A8A8`. Everything in this table is PROPOSAL** (no house token exists for a dark grey; the two sources disagree; neither is fetch-verified).

| Token | Value | Ratio on `#000000` | Provenance |
|---|---|---|---|
| `bg` | `#000000` | — | PROPOSAL (polarity inversion of `#FCFCFC`) |
| `ink` | `#FFFFFF` | 21:1 DERIVED | PROPOSAL |
| `secondary` | **`#A8A8A8`** | **8.83:1** DERIVED | PROPOSAL |
| `secondary-IC` | `#BBBBBB` | 10.94:1 DERIVED | PROPOSAL |
| `rule` | White 25% @ `1/displayScale` | — | PROPOSAL (black-bg rule token) |
| `ruleSoft` | White 10% | — | PROPOSAL |
| `selectBg` / `selectInk` | `#FFFFFF` / `#000000` | — | PROPOSAL |
| `fail` | — | — | **NO RED** — the room's identity is white regardless of appearance, so the error treatment is `ink` + `ERROR —` + Bold + a rule above |

### 5.2 Justification (why `#A8A8A8` over `#A6A6A6`)

1. **Owning source.** `#A8A8A8` comes from `spec-gallery-viewer-spec.md:81`, the spec that owns the white room; `#A6A6A6` comes from `spec-camera-screen-spec.md:41`, the spec that owns the *black* room. A white-room secondary ink is more authoritative from the white-room spec.
2. **Headroom.** `#A8A8A8` gives the higher DERIVED contrast (8.83:1 vs `#A6A6A6`'s 8.63:1 on `#000000`), leaving more room above the 4.5:1 floor.
3. **IC direction is preserved.** The increase-contrast step must move *toward* the room's ink. Light room: `#6C6C6C` → `#595959` (darker). Dark room: `#A8A8A8` → `#BBBBBB` (brighter, the +19 sRGB-channel mirror of the light room's −19 step).
4. **Rejected alternative recorded** for audit: `#A6A6A6` (spec-camera:41). `§6.6`'s `Color(white: 0.7)` (`#B3B3B3`) is also rejected — a third value, not one of the two competing sources.
5. **Rule values.** The rule token is `White 25%` (the canonical black-bg rule), superseding `§6.6`'s `#333333` (≈ White 20%), which is not on the canonical scale.

**Why this is a PROPOSAL, not OBSERVED:** no `--color-mm-base-*` token matches either grey; the two in-repo sources contradict each other; no fetch-verified house value exists. Per R7 a contested authored value is a PROPOSAL.

---

## 6. Reduce Motion, Increase Contrast, Reduce Transparency

| Pressure | OFF (default) | ON |
|---|---|---|
| **Reduce Motion** — slider fade `CameraView.swift:96/:100` 0.2/0.25s | `easeInOut` 0.2 in / 0.25 out | `.transition(.identity)` — instant |
| **Reduce Motion** — shutter press `ShutterButton.swift:42` 0.15s ×0.9 | `easeInOut(0.15)`, scale 0.9 | no scale; veil opacity instant |
| **Reduce Motion** — countdown tick (`CameraViewModel.swift:318` 1s loop) | instant number swaps, no tick animation | keep instant swaps; announce `3, 2, 1` via `accessibilityAnnouncement` instead of a visual pulse |
| **Reduce Motion** — live zoom readout | `camera-zoom` updates discretely to the nearest 0.1X, no spring | same; no animated magnifier |
| **Reduce Motion** — gallery cover (system `fullScreenCover`) | system default | respect system; add no custom slide |
| **Reduce Motion** — live zoom readout | see above | see above |
| **Increase Contrast** — rules | `1/displayScale` in `rule` | step to 2px solid in `ink` |
| **Increase Contrast** — secondary text | `secondary` | `secondary-IC` (`#595959` light / `#BBBBBB` dark) |
| **Reduce Transparency** — over-preview backing | `scrim` gradient (Black 45% → 0%, 88pt) | solid `Black 100%` bar 88pt + solid bottom strip |
| **Reduce Transparency** — white-room banner | `.ultraThinMaterial` | opaque `bg` + a `rule` |
| **Reduce Transparency** — camera HUD discs (`.black.opacity(0.45)`, `CameraHUDButton.swift:21`) | as-is | become opaque `Black 100%` |

Blinking record/state glyphs are forbidden regardless of setting — photosensitive risk, and they collide with the torch-pulse semantics. **Honest-motion rule:** motion is never required to operate the interface.

---

## 7. RTL

- All rules/stacks/paddings use `.leading`/`.trailing`, `Alignment.leading`, never `.left`/`.right` or fixed x-offsets. The bottom dock mirrors automatically under `.rightToLeft`.
- **Do NOT mirror:** the camera preview layer; clock/timer numerals (`3s/10s`); exposure fractions (`+1 2/3`, U+2212 minus); zoom factors (`1.0x`, POSIX at `CameraControls.swift:96-97`); the DNG filename (`pikicam-<uuid>.dng`, `PhotoLibraryManager.swift:886`).
- **Fixes:** the `− / +` stepper uses automatic mirroring (minus stays leading in LTR, trailing in RTL); numeric readouts keep `.monospacedDigit()` + `.environment(\.layoutDirection, .leftToRight)` on the readout alone.
- Guarded test: Locale `ar` + `layoutDirection .rightToLeft`. Courier New CJK/Arabic shaping is undocumented — needs a device test (open question stands). Fallback: the system mono handles shaping; word labels are short uppercase nouns, never sentences.

---

## 8. Orientation (LANDSCAPE) and device classes

**Owner ruling: DESIGN LANDSCAPE.** iPhone is designed in landscape; **iPad is explicitly OUT of scope** (stated, per correction #9). Portrait is no longer the designed orientation.

### 8.1 Landscape layout deltas (PROPOSAL — component geometry, not space/type tokens)

- **Top bar** 60pt (OBSERVED house `--mm-header-height: 60px`) spans the landscape width: `DNG` mark leading / `FLASH` `TIMER` `4:3` words trailing, `rule` below.
- **Bottom dock** 88pt (PROPOSAL) above the safe area: `LIBRARY` leading / shutter centred / `CAMERA BACK|FRONT` trailing.
- **Safe-area edge is now the leading/trailing edge, not the top.** The HUD cluster's fixed `top-8 / trailing-20` (`CameraView.swift:274-275`) gains `+ safeAreaInsets` on the edge it hugs (leading or trailing in landscape); the current Dynamic-Island overlap is an unlisted defect fixed here.
- **Exposure slider** anchors to the trailing rail: `trailing 16`, vertically centred, height `min(220pt, 0.6 × safeHeight)` (PROPOSAL).
- **Vertical budget:** top bar 60 + dock 88 = 148pt of a ~393pt landscape height. Every vertical layout must fit within `safeHeight − 148`.

### 8.2 Device classes (PROVISIONAL test matrix, not Apple-quoted)

> The prior spec's point-size citations (`375×667 SE`, `440×956 Pro Max`, iOS 26 floor) were dead or wrong URLs (VERIFICATION §6). All sizes below are a **PROVISIONAL** test matrix, not Apple fact. The iPhone 17 Pro simulator target has no inventory data.

| Class | Landscape canvas (provisional) | Type/layout delta |
|---|---|---|
| Smallest supported (SE 2nd/3rd gen) | ~667×375pt @2x | HUD words `caption` (11); chips scroll horizontally; dock insets `horizontal 16 / bottom 24`; countdown capped (see below) |
| Baseline (iPhone 16 / 17 Pro, simulator target) | measure on the iOS 26 simulator before lock | Spec default: HUD `caption`, chips `label`, countdown `display` 96, shutter 80/64 (PROPOSAL), dock `20/32` |
| Largest (iPhone 16 Pro Max) | ~956×440pt @3x (provisional) | HUD `caption`; grid `minimum: 140`; countdown uncapped to 120pt |

- **Countdown** (`display` 96 Bold tabular, square): `lineLimit(1) + minimumScaleFactor(0.6)`; the disc is deleted (radius 0). Cap at 120pt so the two-glyph `10` does not shift the square (existing defect: `CameraView.swift:480-486` is content-sized).
- **Hairlines:** `Rectangle().frame(height: 1/displayScale)` (1pt @1x, 0.5 @2x, ~0.33 @3x). `Divider()` has no documented 1px contract.
- **Space in landscape:** all margins/paddings from `2/4/8/12/16/20/24/32`. Never hard-code a 34pt spacer or a fixed bottom offset.
- **Icons never render.** The replaced-icon reasoning set (`camera*`, `photo*`, `rectangle.stack`, `eye*`, `trash`) is deleted; words replace every symbol. `SHOOT` replaces the shutter glyph, `LIBRARY` the grid/library glyph.

---

## 9. Haptics

No haptics ship today (no `UIFeedbackGenerator` / `.sensoryFeedback` in the inventoried files). Add these, all SwiftUI-native, no dependencies:

- Shutter press → `.sensoryFeedback(.impact(weight: .medium), trigger: phase)` on entering `.capturing`; pairs with the press scale (`ShutterButton.swift:42`) and the capturing veil (`:25-27`).
- Countdown tick → `.sensoryFeedback(.selection, trigger: selfTimerRemaining)` each 1s tick (`CameraViewModel.swift:318`).
- Capture success (phase returns idle after `libraryModel.save`) → `.sensoryFeedback(.success, trigger: savedCaptureID)`; failure → `.sensoryFeedback(.error, trigger: error)`. Never show `saved` until phase is idle (journaled save contract at `PhotoLibraryManager.swift:287-359`).
- EV snap on drag release → `.sensoryFeedback(.increase/.decrease, trigger: exposureThirds)`; clamped at the limit → `.sensoryFeedback(.warning, …)`.
- Pinch clamped at `zoomRange` limit → one light impact per limit-hit (fixes the silent-limit defect).

Respect the system Haptics toggle: `sensoryFeedback` honours it automatically; add **no** custom `UIFeedbackGenerator` bypass.

---

## 10. Capture flow, volume-button accessibility, and disabled-state truth

### 10.1 Phases

Phases (`CameraViewModel.swift:20-29`): `idle / countdown / capturing / savingDNG`. Auth gate (`:48-51`): `cameraAuthStatus == .authorized && (photoAuthStatus == .authorized || .limited)`.

- **idle** — white shutter enabled, all word controls enabled.
- **countdown** — `display` numeral + `CANCEL` word (Button, hint `Cancels the timer`); a second shutter press cancels (`CameraViewModel.swift:251-266`). Under Reduce Motion numbers swap instantly.
- **capturing** — shutter veil (inner at 30%, keep `ShutterButton.swift:27`) + `.disabled(isCapturing)` (`:31`). Every other control currently no-ops via `guard phase == .idle` **but still renders fully enabled** — a flagged defect. **Fix:** apply `.disabled(phase != .idle) + .opacity(phase != .idle ? 0.4 : 1)` to every non-shutter control; VoiceOver then reports dimmed correctly.
- **savingDNG** — thumbnail-area `SAVING…` in `caption` + disabled shutter; completion re-enables. Under Reduce Motion `SAVING…` is static (no spinner rotation).
- **Watchdog:** `PhotoCapture.swift:34` `.seconds(15)` timeout → `The photo capture did not complete in time.` (`CaptureService.swift:755`). The 250ms 1x-settle FOV snap (`CaptureService.swift:530`) stays even under Reduce Motion (honesty over smoothness) and is labelled `FRAMING 1X` for its 250ms.

### 10.2 Volume-button shutter (kept; system HUD accepted)

- **Owner ruling: keep volume-button capture and accept the system volume HUD (do not suppress it).** The host is a hidden zero-frame view (`VolumeButtonCaptureView.swift:18` `view.frame = .zero`, `:19` `isHidden = true`); debounce 0.6s (`:53`); delta `> 0.001` (`:62`); retry `asyncAfter(+0.1)` ×10 (`:35`). The system volume HUD and the audible volume change are **not** suppressed (`:9-11`) — accepted, not hidden.
- **Accessibility status:** the volume buttons are **not** the accessible path. The on-screen `SHOOT` (`camera-shutter`) + the countdown-cancel Button + full keyboard/switch-control operability of every word Button is the accessible path.
- iOS `Settings → Camera → Use Volume Up for Burst` remaps Volume-Up-hold to burst; pikicam's 0.6s throttle diverges — pikicam never bursts (DNG-only single exposure; `isAppleProRAWEnabled = false` at `CaptureService.swift:679`). The divergence is stated on the viewer per-image sheet (§2.5), not on the camera chrome.
- Volume-hold beyond 0.6s is silently swallowed (no burst indicator, by design, asserted by tests).

---

## 11. Snapshot-test dimensions — the four R-swaps

The design is proven by swapping the environment, not by mocking the world. **The four R-swaps are snapshot-test dimensions:** Increase Contrast, Reduce Transparency, Reduce Motion, and both colour schemes (light/dark) — plus the room and Dynamic Type.

Every screen snapshot renders the cross-product:

`{ Room.black, Room.white } × { IncreaseContrast off/on } × { ReduceTransparency off/on } × { ReduceMotion off/on } × { colorScheme light/dark } × { DynamicTypeSize .large, .accessibility5 }` at **375pt and 440pt landscape widths**.

Assertions:

- White-room snapshots assert ≥4.5:1 (normal) / ≥3:1 (large) against the **resolved** background, in both colour schemes, using the §5 dark ink in dark and §4 light ink in light.
- No hard-coded colour survives a room swap; no layout clips at 375pt or 440pt under `.accessibility5`.
- Red appears only under `fail` in the black room; a white-room error snapshot must contain **no** red.

---

## 12. Open / must-measure before lock (bundle gaps, not spec)

1. On-device pt/type/colour tokens for shutter/thumbnail/chips on an iOS 26 release build (Apple publishes none).
2. The white-room dark secondary ink §5 — PROPOSAL; confirm against a designer/owner review (the sources disagree).
3. AE/AF lock persistence; exposure auto-dismiss seconds (code today 2500ms at `CameraView.swift:98`; convention undocumented).
4. Courier New CJK/Arabic fallback; SE-4th-gen / 16e landscape point sizes; runtime `safeAreaInsets` depths (not spec constants).
5. `CIRAWFilter` neutral tone-map disclosure + DNG preview-payload shape + P3/gamma badge (needs `CIRAWZeroProcessor.swift:63-81` recipe pin against the iOS 26 SDK + a sample DNG dump).
6. `baselineExposure` — the two-step measurement (correspondence + classification) in VERIFICATION §5 to settle whether the decoder default or `0.0` is correct.
7. The state-matrix completeness gate (VERIFICATION §6 #11) is **out of this target** and still unsatisfiable: `spec-state-matrix.md` has no hit-area column, so no state can satisfy the six-field criterion. DESIGN-LOCK must add a hit-area column or change the criterion before the gate can terminate honestly.

