# pikicam GALLERY + VIEWER — WHITE ROOM SPECIFICATION (canonical re-expression)

**Room:** WHITE. **Surfaces:** Gallery grid + FullScreenViewer only. Camera screen out of scope (its chrome obeys its own section; the one cross-reference — the volume HUD — is dispositioned in §9).

**Owner rulings in force (2026-10-01, interview).** These OUTRANK `.P.DESIGN.md` and the earlier gallery spec:
1. Direction is HYBRID and asymmetric. **Pole B is taken ONLY on the gesture layer** — the sewn tack replaces the underline; the header tag is genuinely blank; **no house name appears in any symbol name.** Pole A is kept on **content and surface**.
2. The doc's §0.4/§0.6 **content deletions are REJECTED.** The viewer `DATA` sheet is the **FULL provenance sheet** (FILE / BYTES / SENSOR / BAYER / EXPOSURE + the recipe list) — not stripped to raw DNG tags. Gallery and viewer keep **all three** of: the date header, the DNG count readout, and the index chip.
3. Volume-button capture is kept; the **system volume HUD is accepted, not suppressed.**
4. Orientation: **landscape is designed. iPad is OUT of scope.**
5. The bypass is expressed by **absence** on the camera chrome (no manifesto strip) and **stated** on the viewer's per-image sheet.
6. `baselineExposure` is **not** overridden without cause — leave the decoder's file-derived default, flag it **PROPOSAL** (see §5.4).

**Provenance discipline (R7).** Every surviving value below carries one tag:
- **OBSERVED** — read from the code (the only authority, R1) or from an independently verified source.
- **DERIVED** — computed from OBSERVED values (contrast ratios, pt tracking).
- **PROPOSAL** — a pikicam choice, implementer- or owner-pinned; never to be read as a fact. A PROPOSAL is never presented as OBSERVED.

**Authority order:** code (R1) > owner rulings > `.P.DESIGN.md` canonical scale > this file. Where the earlier gallery spec's value is not on the canonical scale it is re-expressed as a map onto it, and the map is stated.

---

## §0 — What exists today (OBSERVED — code authority, not proposal)

Every line below was opened and read. These are the facts this spec replaces. Nothing further down describes current behavior unless labelled TODAY.

### 0.1 Gallery (`pikicam/Features/Gallery/GalleryView.swift`)

| Line | Today (OBSERVED) |
|---|---|
| `:14` | `Color.black.ignoresSafeArea()` — gallery background fill. |
| `:163` | `Color.black.ignoresSafeArea()` — viewer background fill. |
| `:69` | `.preferredColorScheme(.dark)` — surface forced dark; no light treatment. |
| `:49` | `"Library"` — navigation title. |
| `:50` | `.navigationBarTitleDisplayMode(.inline)`. |
| `:18`, `:31` | two `ToolbarItem(placement: .bottomBar)`. |
| `:25` | `.frame(width: 60, height: 50)` — toolbar latest-thumbnail size. |
| `:26` | `RoundedRectangle(cornerRadius: 4)` — thumbnail clip. |
| `:32` | `HStack(spacing: 16)` — trash/camera row gap. |
| `:36` | `Image(systemName: "trash")`. |
| `:37` | `.foregroundStyle(.red)` — trash glyph tint. |
| `:39` | `.disabled(library.selectedCapture == nil)`. |
| `:42` | `Image(systemName: "camera")`. |
| `:43` | `.foregroundStyle(.yellow)` — camera glyph tint. |
| `:106` | `GridItem(.adaptive(minimum: 100), spacing: 2), spacing: 2`. |
| `:113` | `.aspectRatio(1, contentMode: .fit)` — square cells. |
| `:118` | `.padding(2)` — grid outer inset. |
| `:259-260` | `.resizable()` + `.scaledToFill()` — thumbnail fill, crops. |
| `:263` | `.fill(Color.gray.opacity(0.3))` — placeholder / stuck-failure fill. |
| `:124` | `.font(.caption)` — the only explicit font in either file; banner error text. |
| `:77`, `:86`, `:93`, `:100` | `.tint(.yellow)` — spinner, full-error, empty state. |
| `:83` | `systemImage: "exclamationmark.triangle"` — full load-failure illustration. |
| `:82` | `"Unable to load library"` — full failure title. |
| `:89`, `:127` | `"Retry"` buttons. |
| `:92` | `.buttonStyle(.borderedProminent)` — full-error Retry style. |
| `:99` | `"No captures" / "Capture a photo to begin."` + `systemImage: "photo.fill"`. |
| `:131` | `.background(.ultraThinMaterial)` — stale-grid banner material. |
| `:132` | `RoundedRectangle(cornerRadius: 8)` — banner clip. |
| `:125` | `.lineLimit(2)` — banner truncation. |
| `:122`, `:126`, `:130`, `:133` | banner layout: `HStack(spacing: 12)` + `Spacer()` + `.padding(8)` + outer `.padding()`. |
| `:194` | `"DNG Viewer"` — viewer top-bar title, default font. |
| `:197` | `Image(systemName: chromeHidden ? "eye.slash" : "eye")` — chrome toggle. |
| `:201` | `Image(systemName: "trash")` — viewer delete, no `foregroundStyle`. |
| `:208` | `"Back to Camera"` — viewer bottom action. |
| `:191-212` | viewer chrome `VStack` has no scrim/material — default text over image. |
| `:144`, `:159` | `chromeHidden=false`; `hasConsumedOpeningTap=false`. |
| `:166-168` | `.resizable()` + `.scaledToFit()` + `.ignoresSafeArea()` — viewer letterboxes. |
| `:181-182` | `Color.clear` + `.contentShape(Rectangle())` — transparent tap-catcher. |
| `:183-188` | `.onTapGesture` toggles chrome, except the first tap after appear, swallowed by `hasConsumedOpeningTap`. |
| `:51-53` | gallery `confirmationDialog`: `"Delete capture?"`, `"Delete"` (destructive), `"Cancel"`. |
| `:216-228` | viewer uses `.alert` (vs the gallery's `.confirmationDialog`); `:227` message `"This removes the DNG from Pikicam."`. |
| `:171-175` | `"Unable to load DNG"` + `exclamationmark.triangle` + fallback `"This capture could not be developed."` + `.tint(.yellow)`; no Retry, no dismiss (stuck). |
| `:178` | `ProgressView().tint(.yellow)` — viewer loading. |
| `:229-245` | `.task(id: capture.id)` resets `image`/`loadFailed`; inputs `capture.aspectRatio` / `capture.zoomFactor`. |
| `:56-68` | `.fullScreenCover(isPresented:)`; body renders nothing when `selectedCapture==nil` (empty-cover hole); system swipe-to-dismiss bypasses `onBackToCamera`. |

### 0.2 Library model / storage (OBSERVED)

- `PikicamLibraryModel.swift:9-12` — `captures=[]`, `selectedCapture=nil`, `isLoading=false`, `error=nil`.
- `PikicamLibraryModel.swift:74` — `CGSize(width: 300, height: 300)` PhotoKit thumbnail pixel size (not layout pt).
- `GalleryView.swift:107` — grid `ForEach` id is `\.element.id.uuid` = `CaptureID.uuid`, generated once at save (`PhotoLibraryManager.swift:297`) and persisted, re-used on fetch (`:473`). **This id is STABLE and independent of `PHAsset` churn** — the earlier doc's "non-stable under assetID churn" claim is REFUTED (§6 correction 17). The value that does shift is the accessibility `index` inside `gallery-cell-\(index)` (`GalleryView.swift:115`).
- `PikicamLibraryModel.refresh()` (`:26-41`) writes only `isLoading` / `captures` / `error`. `selectedCapture` is assigned only in `select()` (`:51`) and `deleteSelected()` (`:58`). **`watchInvalidation` mutates the grid, not the selection** (earlier doc's "mutates grid and selection" is REFUTED).
- `PhotoLibraryManager.swift:221` — invalidation stream uses `.bufferingNewest(1)`; bursts coalesce.
- `PhotoLibraryManager.swift:817` — index store `pikicam-capture-index-v<version>.json`; `:885` `originalFilename(for:)`; `:886` crash-recovery key.

### 0.3 Develop pipeline (OBSERVED)

- `CIRAWZeroProcessor.swift:31` — `guard let filter = CIRAWFilter(imageData: dngData) else`.
- `CIRAWZeroProcessor.swift:8-13` — header comment claims only demosaic / black-level / color-matrix / AsShotNeutral WB run. **The comment overstates its own case:** the recipe (`:63-81`) *also* writes `baselineExposure = 0.0`. Corrected in §5.4 (correction 18).
- `CIRAWZeroProcessor.swift:63-81` — the 15-entry neutral list: `baselineExposure, exposure, boostAmount, boostShadowAmount, shadowBias, localToneMapAmount, luminanceNoiseReductionAmount, colorNoiseReductionAmount, sharpnessAmount, detailAmount, moireReductionAmount, contrastAmount, extendedDynamicRangeAmount, lensCorrectionEnabled, gamutMappingEnabled`.
- `DevelopService.swift:18,26,31` — the actor owns a Metal-backed `CIContext` (`private let ciContext: CIContext`). **The earlier doc's "`DevelopService` leaks on dismissal" is REFUTED:** it is `@State`-owned inside `FullScreenViewer` (`GalleryView.swift:154`) and released on dismissal. The **real** defect is that the default initializer rebuilds a Metal-backed `CIContext` on **every `FullScreenViewer` struct init**, i.e. on every re-evaluation of the cover body while presented.
- `DevelopService.swift:69` `renderBitmap`; output is a transient bitmap — no JPEG encoded, no file written (PROPOSAL-to-verify: re-confirm at wiring).

### 0.4 Testing state (OBSERVED — live repo, not design)

The UI suite is **red** and must be fixed during the wiring phase (owner decision 2026-10-01: leave it red, do not let it mask new failures). New ID/molecule expectations already in `SmokeLaunchTest.swift` vs what the view still renders today:

| Test expects | View still renders | Where |
|---|---|---|
| `navigationBars["LIBRARY"]` (`:220,447,633`) | `.navigationTitle("Library")` | `GalleryView.swift:49` |
| `staticTexts["0 / NO CAPTURES"]` (`:227,464`) | `"No captures"` | `GalleryView.swift:99` |
| `buttons["room-shoot"]` (`:233,247,472,491`) | `"gallery-camera"` | `GalleryView.swift:45` |
| `buttons["viewer-hide-show"]` (`:303`) | `"viewer-chrome-toggle"` | `GalleryView.swift:199` |
| `buttons["camera-library"]` (`:217,627`) | `"gallery-thumbnail"` | `CameraView.swift:196` |
| `buttons["camera-shutter"]` (`:121,124,527,530`) | label only — **no identifier** | `ShutterButton.swift:33` |

Still matching today: `library-grid` (`GalleryView.swift:120`), `gallery-cell-*` (`:115`), `viewer-loading` (`:179`), `viewer-delete` (`:203`), `viewer-back` (`:210`).

**Corrections to earlier breakage claims (correction 17):**
- **R1 REFUTED** — removing `gallery-latest-thumbnail` does **not** break `SmokeLaunchTest.swift:217`; that line is `app.buttons["camera-library"]`. `gallery-latest-thumbnail` is referenced **only** at `GalleryView.swift:28` — **no test references it.**
- **R2 REFUTED** — the current tree queries `app.activityIndicators["viewer-loading"]` (`SmokeLaunchTest.swift:305`), **not** `.firstMatch`.
- **R3 REFUTED** — `camera-shutter` is **not** assigned in code; it appears only in `ControlIDRegistry.swift:37`. The shutter exposes only `.accessibilityLabel("Capture photo")`. The tests query `camera-shutter`, so the assertion cannot pass until the view emits the identifier (§7).

`ControlIDRegistry.swift` is referenced by **no view** — it is the wiring-phase target.

---

## §1 — Tokens (canonical scale only)

**One scale or it is not a system.** The six canonical type tokens, the two-room ink tables, hairline rules, radius 0, and the 2/4/8/12/16/20/24/32 space scale are the ONLY permitted values. Any earlier gallery value outside them is re-expressed as a map onto them (map given inline). No hex appears outside §1.2. No type token outside §1.1.

### 1.1 Type — the canonical six, and the map onto them

**Face:** `Courier New` via `Font.custom(_:size:relativeTo:)`. The **two-arg overload is FORBIDDEN** for UI text (freezes under Dynamic Type). Fallback stack, in order: `Courier New` → `Menlo` → `.system(design: .monospaced)`. **No sans in chrome.** `Courier New` is an iOS system font — OBSERVED (`https://developer.apple.com/fonts/system-fonts/`).

The earlier gallery spec ran a seven-role scale (`MONO-17/14/13/12/11`, `DISPLAY-28`, `NUMERAL`). It is deleted and mapped by ROLE, not size, onto the canonical six:

| Canonical token | Size/Weight | Tracking (em → pt) | Case | `relativeTo` | OBSERVED use in this spec |
|---|---|---|---|---|---|
| `display` | 96 Bold, tabular | 0 | tabular | `.largeTitle` | the empty-state `0` numeral only |
| `title` | 17 Bold | +40/1000em → **0.68pt** @17 | UPPERCASE | `.headline` | screen/surface titles: `LIBRARY`, `NO CAPTURES`, error titles, `DATA` |
| `body` | 14 Regular | 0 | sentence | `.body` | explanatory copy: empty/error bodies, delete-confirmation body, DATA-sheet **values** |
| `label` | 13 Regular; Bold when selected | +80/1000em → **1.04pt** @13 | UPPERCASE | `.callout` | **every word-control**: `SHOOT BACK HIDE SHOW DELETE SHARE RETRY CANCEL DISMISS OPEN SETTINGS` |
| `caption` | 11 Regular | +80/1000em → **0.88pt** @11 | UPPERCASE | `.caption` | non-tappable readouts: date header, index chip, `DNG` mark, `SYNCING`, `LOADING`, `SELECTED`, `ERROR —` prefix, DATA-sheet keys |
| `tick` | 11 Regular, `monospacedDigit` | 0 | numerals + `X`/`+`/`−`/`/` | `.caption` | live numerals: viewer zoom `1.0x`, EV, DNG count `DNG 03 / 11` |

**Map (earlier token → canonical) — every value lands on one of the six:**
`MONO-17` → `title` (surface titles) / `label` (bar word-controls). · `MONO-14` → `body` (sheet values) / `caption` (uppercase readouts). · `MONO-13` → `caption` (readouts) / `label` (controls). · `MONO-12` → `label`. · `MONO-11` → `caption`. · `DISPLAY-28` → `display`. · `NUMERAL` → `tick`.

Tracking is given in **both** em and pt (correction 7): `title` +40/1000em = 0.68pt; `label` +80/1000em = 1.04pt; `caption` +80/1000em = 0.88pt. Apply with `.tracking(pt)`; the em figure is the source of truth.

Tracked-out uppercase is retained on CONTENT/SURFACE (Pole A). It is NOT the anonymity device — the tack is (Pole B, §3).

Notes that are contract, not style: U+2212 minus, not hyphen, for negative EV; the byte-exact EV labels `0, +1, −2, +2/3, −1/3, +1 2/3, −2 1/3` are asserted in `CameraControlTests` — do not "fix" them. No italic. No weight other than Regular/Bold. Viewer zoom keeps the POSIX label `String(format: "%.1fx", locale: en_US_POSIX, factor)` (`CameraControls.swift:97`).

### 1.2 Ink — WHITE room (with the dark-appearance pair, correction 4)

The earlier gallery spec gave `secondary` a dark value of `#A8A8A8` and the tokens spec `#A6A6A6`; **neither is canonical**, and correction 4 requires a supplied white-room dark pair. Ruling: the **white room's dark appearance IS the black-room ink set** — `bg #000000 / ink #FFFFFF / secondary White 60% / rule White 25%` (`spec-design-system-tokens.md:121`, `.P.DESIGN.md` §2.1). The invented `#A8A8A8` / `#A6A6A6` are DROPPED.

| Token | Light | Dark | Provenance |
|---|---|---|---|
| `bg` | `#FCFCFC` | `#000000` | **OBSERVED** house `--color-mm-base-off-white` (§0.5 #3, correction 3). **The earlier spec's `#FFFFFF` for light bg is REJECTED** — a vestigial row; its `#6C6C6C on #FFFFFF = 5.25:1` pairing is deleted (correction 16). |
| `ink` | `#000000` | `#FFFFFF` | — |
| `secondary` | `#6C6C6C` | `White 60%` | `#6C6C6C` **OBSERVED** house token — the real name is `--color-mm-base-neutral-500` (correction 1; the earlier `--color-mm-base-strong-grey` is FABRICATED). **5.12:1 on `#FCFCFC`** DERIVED (correction 3; §0.5 #4). |
| `secondary-IC` | `#595959` | `#FFFFFF` | **DERIVED 6.83:1** on `#FCFCFC` — the **Increase Contrast** step only (correction 3: locked at 6.83, not 6.82). |
| `rule` | `#000000` @ `1/displayScale` | `White 25%` | — |
| `ruleSoft` | `Black 10%` | `White 10%` | light **OBSERVED** house `--color-mm-base-black-alpha-10`; dark pair DERIVED mirror. **Intra-grid gutters only.** |
| `selectBg` / `selectInk` | `#000000` / `#FFFFFF` | `#FFFFFF` / `#000000` | inversion only |
| `fail` | — | — | **NO RED IN THIS ROOM** (§0.5 #6; correction 8). Error = `ink` + `ERROR —` + `weight(.bold)` + a `1/displayScale` rule above. The earlier spec's `#EA0000` error text is **OVERRULED.** |

**Contrast (DERIVED, WCAG 2.2):** normal `≥4.5:1`, large `≥3:1` (large = `≥18pt` or `≥14pt bold`); the four canonical ratios recompute exactly: **5.12** (`secondary`/`bg`) · **6.83** (`secondary-IC`/`bg`) · **5.25** (`#6C6C6C`/`#FFFFFF` — **vestigial, deleted**) · **1.23** (rule soft). Cite `https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html`.

**Source hygiene (OBSERVED, correction 1/2):** the verified stylesheet token is `--color-mm-base-off-white: #fcfcfc`; `#e5e5e5` is `--color-mm-base-neutral-100-alpha-60`; the dark neutral is `--color-mm-base-neutral-500: #6c6c6c`. `--color-mm-base-red: #ea0000`, `--mm-header-height: 60px`, `.rounded-0`, `.text-decoration-underline` all exist. The weight-400 `@font-face` for `CourierNewRecast` lives in **`fonts.css`**, not `global.css` (correction 2). `#006FE6` focus blue was **NOT FOUND** — do not spec it. The earlier spec's `--color-mm-base-strong-grey` / `--color-mm-base-light-grey` **do not exist** (correction 1).

**TODAY replaced:** `Color.black` (`GalleryView.swift:14,163`), `:69` forced `.dark` (deleted — honour both appearances), `.yellow` (`:77,86,93,100`, camera `:43`), `.red` (`:37`), `gray.opacity(0.3)` (`:263`), `.ultraThinMaterial` (`:131`), `RoundedRectangle(4/8)` (`:26,132`).

### 1.3 Rule

Hairline = `Rectangle().frame(height: 1/displayScale)` via `@Environment(\.displayScale)` (`1pt @1x / 0.5 @2x / 0.333 @3x`). **`Divider()` is FORBIDDEN** (no one-physical-pixel contract).

**Rule locations (correction 6 — the "exactly four places" claim is dropped):** (a) below the gallery top bar; (b) above the gallery bottom dock; (c) between the viewer image and its metadata row; (d) the tag's own frame; **(e) above the error banner** (per §0.5 #6); **(f) the stale-grid banner border** (§8.4). No boxes around buttons, no card outlines, no shadow, no blur/material anywhere.

Under **Increase Contrast**: rules step to 2px solid; `secondary` text steps to `secondary-IC`, then to `ink`.

### 1.4 Shape — radius 0 everywhere

No rounding. The canonical shape-deletion set (correction 5 — completed): `Capsule()` (`CameraView.swift:144,162`), `.clipShape(Capsule())` EV bubble (`CameraView.swift:444`), EV tick `Circle()` (`CameraView.swift:423`), EV track `Capsule()` (`CameraView.swift:417`), `.background(.black.opacity(0.45), in: Capsule())` (`ZoomIndicatorView.swift:15`), `Circle()` (`CameraHUDButton.swift:21`), `RoundedRectangle(8)` (`CameraView.swift:178`), `RoundedRectangle(6)` (`CameraView.swift:321`), `RoundedRectangle(4)` (`GalleryView.swift:26`), `RoundedRectangle(8)` (`GalleryView.swift:132`), countdown `Circle()` (`CameraView.swift:486`). Shape never signals alone — the **tack** (§3), the inversion block, and the 44pt target carry it.

### 1.5 Space

Scale `2 / 4 / 8 / 12 / 16 / 20 / 24 / 32` only (component geometry — 60pt top bar, 64/72pt docks, 44pt target, 64×20pt tag — is not spacing and is tagged inline). The earlier spec's **18pt margins are NOT in the scale** → re-expressed as **16pt** (≤430pt widths) / **20pt** (440pt). Current `10/14/40` remap `10→8`, `14→16`, `40→32`.

### 1.6 Motion

Fades only. Chrome `.transition(.opacity).animation(.easeOut(duration: 0.25))`; grid insert fade `0.2`. **Springs are FORBIDDEN** (canonical §2.7) — the earlier spec's swipe-dismiss `.interactiveSpring(response:0.32, damping:0.88)` and edge rubber-band are **replaced** by a fade plus a velocity/translation threshold (§4.2). No blink, no shimmer, no skeleton. Durations are pikicam PROPOSAL (site motion values UNVERIFIED). Under **Reduce Motion**: all durations `0`; motion is never required to operate the interface.

### 1.7 Hit areas and buttons

Every visible word is 11–17pt but its `Button` frame is `min 44×44pt` via `.frame(minWidth:44,minHeight:44) + .contentShape(Rectangle())`. The hairline is never the hit area. Every control is a real SwiftUI `Button` (carries `.isButton`). Icon-only buttons with no `accessibilityLabel` (`GalleryView.swift:190-199`) are deleted; every replacement word carries label = visible text.

### 1.8 RTL and device matrix

`.leading/.trailing` only; test `ar` + `.rightToLeft`; numerals unmirrored. Verify at `375×667pt` (SE) through `440×956pt` (Pro Max), with **landscape** as a first-class layout (owner ruling 4). iPad is **OUT OF SCOPE** (correction 9). Device pt sizes are a test matrix, not an Apple-quoted fact.

---

## §2 — Grid

### 2.1 Columns, gutter, inset

- **Columns:** iPhone **portrait 3 / landscape 5**, via `LazyVGrid(columns: [GridItem(.flexible(), spacing: 2) × N], spacing: 2)`. **NOT** `.adaptive(minimum: 100)` (TODAY `:106`). iPad values are **deleted** — out of scope (correction 9).
- **Accessibility escape hatch:** at `dynamicTypeSize >= .accessibility3`, step to `GridItem(.adaptive(minimum: 140), spacing: 2)` (canonical §0.5 #5).
- **Gutter** `2pt` both axes (`LazyVGrid(spacing: 2)`); **outer inset** `.padding(2)` (keep TODAY `:118`).
- **Cell:** square `aspectRatio(1, .fit)` (keep TODAY `:113`); image `.resizable().scaledToFill().clipped()` (TODAY `:259-260`). No rounding, no badge, no icon overlay.

### 2.2 Selection read (canonical tokens only)

The earlier spec's `INK veil opacity 0.12` and `2pt INK inner frame inset 4pt` introduced a non-canonical "veil". Re-expressed: **selected cell = inversion + `SELECTED` tag + tack.**
- Index chip inverts: `selectInk` (`#FFFFFF`) on `selectBg` (`#000000`) — the "inversion block".
- A `SELECTED` tag in `caption` (`secondary`) sits under the cell.
- The **tack** (§3) is sewn over the cell — the Pole-B non-color cue, mandatory.
- Never a tint wash, never gray-on-gray, never yellow.

Index chip is KEPT (owner ruling 2): `01` top-left in `caption` on a `BG` chip `20×16pt` (both values canonical).

### 2.3 Order and sectioning

- **Order:** newest first, top-left. `library.captures.first` is TODAY's assumption (`GalleryView.swift:19,107`) — **PROMOTED to contract:** the model sorts `creationDate` descending; document it; the test asserts `gallery-cell-0` = the just-captured DNG (`SmokeLaunchTest.swift:291`).
- **Sectioning:** one header per day: `TUESDAY 30 SEPTEMBER 2026 — 04` in `caption` (11pt, +80/1000em, UPPERCASE), `secondary`, leading-aligned, `16pt` margins, `12pt` above / `6pt` below, ruled by a `1px RULE` full-bleed under the header. No sticky headers v1 (plain `LazyVStack`). Timezone: device-local; midnight boundary.
- **The date header and its `— 04` day count are KEPT** (owner ruling 2).

### 2.4 Header treatment (room top bar)

`60pt` bar (OBSERVED house `--mm-header-height`, §0.5). Content: left `LIBRARY` (`title`, `ink`; the active root is marked by the **tack**, not an underline); center the **blank tag** — a `64×20pt` rectangle in the bar `bg`, **no wordmark, no border** (Pole B: the critic's "bordered chip" objection resolved), held by four `6×1.5pt` `ink` tack-stitches rotated ±4° and jittered per a deterministic identity table (§3); right `SHOOT` (`label`, word-control → camera). Below the bar: a `1px INK` rule, full-bleed. No `NavigationStack` title `"Library"` (`:49-50` deleted), no large title, no search, no edit pencil.

```
GRID — iPhone portrait, 3 col, white room
+--------------------------------------------------+
| LIBRARY           [ blank tag + 4 tacks ]    SHOOT |  60pt bar
+==================================================+  1px INK rule
| TUESDAY 30 SEPTEMBER 2026 — 04                    |  caption, secondary
|--------------------------------------------------|  1px RULE
| [img 01] [img    ] [img    ]                      |  2pt gutters
| [img   ] [img SEL:chip-inv + SELECTED + tack]     |
|                                                   |
| MONDAY 29 SEPTEMBER 2026 — 11                     |
|---------------------------------------------------|
| [img   ] [img    ] [img    ]                       |
+---------------------------------------------------+
| SHOOT          DELETE          SHARE             |  bottom word bar (§7)
+---------------------------------------------------+
```
`01` = index chip (KEPT). `SEL` = `SELECTED` tag + sewn tack.

### 2.5 Scroll and refresh

Vertical `ScrollView`; **no pull-to-refresh v1** (refresh is `.task { await library.refresh() }` at `:70` + init double-refresh + `watchInvalidation` stream with `.bufferingNewest(1)` at `PhotoLibraryManager.swift:221`). While populated, a refresh shows the word `SYNCING` top-right in `caption`, `secondary` until the stream settles — **never a spinner** (spinners deleted room-wide). `watchInvalidation` mutates the **grid only**, never the selection (correction 17, R5).

**Pinch on grid: RESERVED.** Years/Months/Days cycle omitted v1; must not collide if added later.

---

## §3 — Selection (single-select v1)

- **How:** tap toggles `library.select(capture)` (TODAY `:20,33,41,108`). Single-select (keep the `:39` `.disabled(selectedCapture == nil)` word-state). Tap again deselects. No long-press, no checkmark (no icons anywhere).
- **Read in the white room:** selected = inversion block (`selectBg`/`selectInk`) + `SELECTED` tag (`caption`, `secondary`) + **sewn tack**. Unselected = bare image. Never a tint wash.
- **The tack (Pole B, the one gesture-layer change).** Replace every `.underline(selected)` with `Tack(identity:)`: **four `6×1.5pt` rectangles** in the room `ink`, rotations drawn from a **fixed per-identity table** (NOT `Math.random()` — deterministic for snapshot tests), jittered, never pixel-snapped, drawn **over** the word and over the blank tag. The base `identity` is the control's `hashValue`; a per-launch seed varies it within the table so no two launches are identical. Cost: four `Rectangle`s or one `Canvas`. The tag's four stitches are the same primitive.
- **VoiceOver:** selected cell exposes `.accessibility(label: "Capture 3, Tuesday 30 September, selected")` + `.isSelected`; unselected omits `selected`. (TODAY zero `accessibilityLabel/Value/Hint/Traits` — gap closed.)
- **On tap (open):** the cell `Button` (select + `viewerPresented = true`; TODAY `:105`) opens the viewer at that capture. No double-tap in the grid.

---

## §4 — Viewer

### 4.1 Chrome show/hide

- **TODAY (replaced):** `Color.black` + `scaledToFit` (`:163,166-168`), header `"DNG Viewer"` (`:194`), eye `eye/eye.slash` (`:197`), trash default-tint (`:201`), `"Back to Camera"` (`:208`), tap-catcher `Color.clear + contentShape` (`:181-182`), `hasConsumedOpeningTap` dead-first-tap (`:183-188`), no scrim (`:191-212`).
- **SPEC:** background `bg` (`#FCFCFC`) full-bleed; image `scaledToFit` centered, letterbox = `bg` (no black bars). Chrome = two `bg` bars with `1px INK` rules, **not floating icons**:
  - **Top bar `60pt`:** left `BACK` (`label`, → grid); center `DNG 03 / 11` (`tick`, monospacedDigit so the index never reflows — the DNG count readout is KEPT, owner ruling 2); right `HIDE` / `SHOW` (`label`, replaces `eye/eye.slash`).
  - **Bottom bar `72pt`:** left `DELETE` (`label`); center metadata summary line (see §5, truncated to 1 line); right `SHARE` (`label`). Background extends into the home-indicator zone via `safeAreaInset(bottom)` — never a hard-coded 34pt.
- **Single tap** on the image toggles chrome with a `0.25s` opacity fade. **First tap works** — delete `hasConsumedOpeningTap` (holes at `:159,:183` closed).
- **Auto-hide: NONE.** Chrome stays until tapped (explicit choice, R5).
- **Bright-DNG readability:** the bars are opaque `bg`, never text-over-image (`:191-212` gap closed). The full-bleed hidden state shows the bare DNG on `bg` with zero chrome and a `44×44` invisible `SHOW` tap zone top-right (VoiceOver `SHOW CONTROLS`).

```
VIEWER — chrome visible, white room
+--------------------------------------------------+
| BACK            DNG 03 / 11                 HIDE |  60pt + 1px rule
+--------------------------------------------------+
|                                                  |
|                [ DNG scaledToFit ]               |
|                (letterbox = BG)                  |
|                                                  |
+--------------------------------------------------+
| DELETE     4000×3000 · DNG · 1.0x          SHARE |  72pt
+==================================================+
```

### 4.2 Dismiss, paging, zoom

- **Dismiss:** swipe-down on the image at fit-zoom dismisses to grid (velocity `> 800pt/s` or translation `> 120pt`); the transition is the §1.6 fade (**no spring** — canonical §2.7). `BACK` = same. The system `fullScreenCover` swipe (`:56`) is intercepted to reconcile gallery state (TODAY bypass gap closed). No nil-capture empty cover: gate `viewerPresented && selectedCapture != nil`.
- **Paging:** horizontal swipe at fit-zoom = prev/next (`TabView(.page)`-equivalent `DragGesture`); when zoomed `> 1.0x`, pan wins, paging disabled (bridge `UIScrollView` if gesture competition bites). Page indicator is words: `DNG 03 / 11` updates; no dots. (TODAY no paging at all — all new.)
- **Zoom:** double-tap toggles fit ↔ `2.0x` centered at the tap; pinch `MagnifyGesture` (iOS 17+ current; `MagnificationGesture` deprecated — OBSERVED `magnifygesture` page) continuous `1.0x–8.0x`; transient readout `2.4x` in `tick` top-center chip (`bg` + `1px INK` border, `44×24pt` — `28` is not canonical → `24`), dwell `1.0s` after release; pan when zoomed, clamped at edges (**no rubber-band** — forbidden). Preset chips are camera-screen only.
- **Zoom/pan accessibility:** `+` / `−` word steppers (`44×44`, `label`) + `FIT` word (double-tap equivalent) in a chrome-overflow row when zoomed; `BACK`, prev/next words always present.

---

## §5 — Metadata surface (FULL provenance sheet — owner ruling)

Location: viewer bottom-bar center line (1-line summary) + the `DATA` sheet (`.presentationDetents([.medium, .large])`, `16pt` margins, `1px INK` rules between rows, mono rows, no icons).

**Summary line (always visible):** `4000×3000 · DNG · 1.0x` (pixel dims · format · framing zoom). Truncates middle, never wraps. Dims OBSERVED (`CameraControlTests.swift:170`); format `DNG`; zoom `tick`.

### 5.1 The DATA sheet — complete residual row set (correction 15)

The earlier doc said the sheet was "stripped to raw DNG tags" and listed only DELETIONS. The owner REJECTED that. The locked sheet renders the **full** row set below. Keys are `caption` (`secondary`, UPPERCASE); values are `body` (sentence case, `ink`). This sheet is the **only** place the bypass is STATED (owner ruling 5).

| Row (key) | Value rendering | Provenance / citation |
|---|---|---|
| `FILE` | `pikicam-<uuid>.dng` | **OBSERVED** — `PikicamPipelineTests.swift:160` `pikicam-\(capture.id.uuid.uuidString).dng`; originalFilename key + crash-recovery key at `PhotoLibraryManager.swift:886`; index store `pikicam-capture-index-v<version>.json` at `:817`; UTI `com.adobe.raw-image` at `PikicamPipelineTests.swift:158` / `PhotoLibraryManager.swift:217`. |
| `BYTES` | `<count>` + `RESOURCE: SINGLE DNG` | format **OBSERVED** — single-resource save contract; probe variants `public.jpeg/jpg/dng` (`:287-309`) rejected. The number is a live readout (earlier spec's `24 117 888` is an EXAMPLE, not a constant). |
| `SENSOR` | `4000×3000 FULL-SENSOR RETAINED` | **OBSERVED** — `CameraControlTests.swift:170` (also `:151`) `CGRect(0,0,4000,3000)`; crop is view-time only. |
| `BAYER` | `14-BIT RGGB` | **OBSERVED** — allowlist `kCVPixelFormatType_14Bayer_RGGB/GRBG/GBRG/BGGR` (`CaptureService.swift:638-641`); `AVCapturePhotoSettings(rawPixelFormatType: bayerFormat)` (`:536`); `photoOutput.isAppleProRAWEnabled = false` (`:679`, pure-Bayer comment `:676-680`). |
| `PRORAW` | `OFF` | OBSERVED — support `HT211965` (DNG-based + computational). Not the dead `HT211131`; tone-map/NR specifics paraphrased from the iPhone 14 Pro newsroom, not quoted. |
| `EXPOSURE` | `1/120 · f/1.9 · ISO 64 · 0 EV` | device values (EXAMPLE); format OBSERVED — EV snapped to 1/3: `minThird = -9 / maxThird = 9` = `-3…+3 EV` (`CameraControls.swift:250-257`); label uses U+2212 minus (`:287-295`). |
| `FOCAL/ZOOM` | `1.0x CAPTURE · 2.0x FRAMING CROP AT VIEW` | OBSERVED — 1x-internal capture + 250ms settle (`CaptureService.swift:518-530`); restore-then-diverge via `currentVideoZoomFactor`. |
| `WHITE BALANCE` | `ASSHOTNEUTRAL RETAINED` + `MATRIX: CAMERA → STANDARD RETAINED` | OBSERVED — `CIRAWZeroProcessor.swift:8-13`. |
| `CONVERSION — ALWAYS ON` | `DEMOSAIC / BLACK-LEVEL (DNG TAGS) / COLOR MATRIX (DNG TAGS) / ASHOTNEUTRAL WB / TONE MAP (CORE PIPELINE, NOT DEFEATABLE) / DISPLAY P3 RENDER` | OBSERVED — retained by omission (`CIRAWZeroProcessor.swift:8-13`). Tone-map-in-neutral per Apple `cirawfilter` docs — disclosed, never implied zeroed. |
| `ENHANCEMENTS — ALL OFF` | the 15-entry zero recipe at `CIRAWZeroProcessor.swift:63-81`, each with its zero/false value; **`BASELINEEXPOSURE` moved out per §5.4** | OBSERVED — property names pinned by `PikicamPipelineTests.swift:493-509` + forbidden `temperature/tint/neutralTemperature/neutralTint/decoderVersion` at `:523`, tolerance `1e-4`. |
| `RENDER` | `TRANSIENT BITMAP ONLY — NO JPEG ENCODED, NO FILE WRITTEN` | OBSERVED — `DevelopService.swift` (`develop` / `renderBitmap`); in-memory-only. |
| `FRAMING` | `ASPECT 4:3 · CROP-ONLY-AT-VIEW` | OBSERVED — labels `4:3/16:9/1:1` (`CameraControls.swift:154-155`); ratio `4.0/3.0, 16.0/9.0, 1.0` (`:134-136`). |

**Copy rule:** say `BAYER DNG · PRORAW OFF`, never bare `RAW`; honest verbs `DEVELOP / CONVERT / RENDER`, never `SENSOR-DUMP` / `UNCONVERTED PIXELS` / unqualified `NO PROCESSING` (CIRAWFilter at neutral still converts).

### 5.2 ENHANCEMENTS row — the 15 entries (each `0.0` / `FALSE`)

`BASELINEEXPOSURE` (see §5.4) · `EXPOSURE` · `BOOST` · `BOOSTSHADOW` · `SHADOWBIAS` · `LOCALTONEMAP` · `LUMINANCENR` · `COLORNR` · `SHARPNESS` · `DETAIL` · `MOIRE` · `CONTRAST` · `EXTENDEDDR` · `LENSCORRECTION FALSE` · `GAMUTMAPPING FALSE`.

### 5.3 Provenance sheet as the bypass statement

The bypass is **absence** on camera chrome (no manifesto strip — owner ruling 5) and **stated** here, per image: `CONVERSION — ALWAYS ON` and `ENHANCEMENTS — ALL OFF`. Nothing else in the app prints enhancement words.

### 5.4 The `baselineExposure` line (PROPOSAL — do not present as OBSERVED)

VERIFICATION §5 adjudication: `NEEDS_MEASUREMENT`. The current `filter.baselineExposure = 0.0` (`CIRAWZeroProcessor.swift:65`) is an **active override**, not a no-op, whenever the decoder default is nonzero; Apple documents **no** mapping to the DNG `BaselineExposure` tag.

**Owner ruling 6 + best practice ⇒ PROPOSAL, to be confirmed by measurement:**
- **Remove `baselineExposure` from the neutralize list** so the decoder's file-derived default is respected (one-line change).
- Replace the "assert `== 0`" test (`PikicamPipelineTests.swift:494,566,580-585`) with a test asserting the property is **left untouched**.
- The DATA sheet's `ENHANCEMENTS` row therefore lists **14**, not 15, forced entries; `BASELINEEXPOSURE` is shown as **not forced** (decoder default).
- **R3 defect regardless of the verdict:** the `CIRAWZeroProcessor.swift:4-17` header comment claims only demosaic / black-level / color-matrix / WB run while the recipe also zeroes `baselineExposure` — **correct the comment either way.**

The measurement that settles it (device): (1) correspondence — `exiftool -BaselineExposure` vs `CIRAWFilter(imageData:).baselineExposure` unset; (2) classification — render twice (default vs `0.0`) and compute the per-pixel ratio: uniform scalar ≈ 2^EV ⇒ not a floor; spatially varying / channel-dependent / additive ⇒ radiometric floor ⇒ the file wins.

---

## §6 — Delete and share

- **Placement:** viewer bottom bar `DELETE` (left) / `SHARE` (right); grid bottom bar `DELETE` / `SHARE` + `SHOOT` (§7). No trash icon (`:36,:201` deleted), no share icon (no share path exists in code today).
- **Grid delete:** enabled only when selection is non-nil (keep `:39` logic; the word dims to `secondary` and shows no tack when disabled). Tap `DELETE` → `confirmationDialog` (keep the presentation split: gallery = dialog, viewer = alert, `:51-53` vs `:216-228`) with title `DELETE CAPTURE?` + body `THIS REMOVES THE DNG FROM PIKICAM.` (uppercase room copy; `:227`) + actions `DELETE` (`role: .destructive`, `ink`, tacked) / `CANCEL` (`role: .cancel`). No count in the title v1.
- **Viewer delete:** same copy as `.alert`; success dismisses the viewer; failure (`deleted=false`) surfaces the in-viewer error line `ERROR — COULD NOT DELETE.` + `RETRY` (`ink` + Bold + a rule above — **no red**, §1.2). (TODAY leaves the viewer open with `library.error` hidden behind the cover — gap closed.)
- **Share:** system `ShareLink` on the stored DNG bytes (original `fileDataRepresentation`, full-sensor — NOT the transient rendition; the embedded-preview leak question stays open). No `22 REPLICA` export preset, no JPEG option, no filter/enhance entry point anywhere.
- **Undo:** PhotoKit delete is destructive; confirm-first (no Recently-Deleted path in pikicam).

---

## §7 — Bottom bar + identifier fate

**TODAY (`:18,:31` two `ToolbarItem(.bottomBar)`, `60×50` thumb `:25`, `spacing 16` `:32`, `tint(.yellow)` `:77/:93`, `borderedProminent` `:92`):** REPLACED by one opaque `bg` bar, `64pt` tall + safe-area bottom, `1px INK` top rule, three word-controls in an `HStack` (`SHOOT` leading / `DELETE` center / `SHARE` trailing), each `label`, min `44×44`, `16pt` side margins:

```
+==================================================+  1px INK
| SHOOT                DELETE                SHARE |  64pt + safeArea
+--------------------------------------------------+
```

No thumbnail in the bar (the grid IS the thumbnails; TODAY `:25-26` deleted). No camera glyph (`:42-43` deleted). `DELETE` disabled = `secondary`, no tack; enabled = `ink`, tacked.

### 7.1 Identifier fate (corrected per §0.4; `ControlIDRegistry` is the target)

| TODAY identifier | Fate |
|---|---|
| `gallery-latest-thumbnail` (`:28`) | **REMOVED** (no bar thumb). **Correction 17 / R1: NO test references it** — the earlier "breaks `SmokeLaunchTest.swift:217`" claim is REFUTED. |
| `gallery-trash` (`:40`) | RENAMED → `room-delete`. |
| `gallery-camera` (`:45`) | RENAMED → `room-shoot`. |
| `gallery-loading` (`:78`) | RENAMED → `room-loading` (word `LOADING`, no spinner tint). |
| `gallery-error` (`:87,:134`) | KEPT name, white treatment. |
| `gallery-retry` (`:95,:128`) | KEPT name, `RETRY` word, no `borderedProminent`/yellow. |
| `gallery-empty` (`:101`) | KEPT name, new `0` numeral treatment. |
| `gallery-cell-\(index)` (`:115`) | KEPT. **R6: the `ForEach` id is stable `CaptureID.uuid`; only this accessibility `index` shifts under churn.** |
| `library-grid` (`:120`) | KEPT. |
| `viewer-load-failure` (`:176`) | KEPT. |
| `viewer-loading` (`:179`) | KEPT, word spinner. **R2: the live test query is `app.activityIndicators["viewer-loading"]`, not `.firstMatch`.** |
| `viewer-background` (`:190`) | KEPT (tap-catcher, now `bg`). |
| `viewer-chrome-toggle` (`:199`) | RENAMED → `viewer-hide-show` (word `HIDE`/`SHOW`). |
| `viewer-delete` (`:203`) | KEPT name, word `DELETE`. |
| `viewer-back` (`:210`) | KEPT name, word `BACK`. |
| **shutter** | **Correction 14 / R3: resolve to ONE name — `camera-shutter` — and the view MUST actually emit it** (today label-only, `ShutterButton.swift:33`). Tests already query `camera-shutter`. |
| `Continue`, `Capture photo`, `grid-toggle`, `grid-overlay`, `mode-*`, `aspect-overlay`, `flash-toggle`, `front-camera-toggle`, `zoom-indicator`, `preview-pinch-area`, `CameraView.swift:196 gallery-thumbnail`, `Cancel/Delete`, `OK/Allow` | Unchanged by this section except `Library` title → the `LIBRARY` bar word; `No captures` → `0 / NO CAPTURES` (§8.1). |

**Vocabulary closure (correction 13).** The closed set this section renders (and only this set): `SHOOT` · `BACK` · `HIDE` · `SHOW` · `DELETE` · `SHARE` · `RETRY` · `CANCEL` · `DISMISS` · `OPEN SETTINGS` · `SYNCING` · `LOADING` · `SELECTED` · `DNG` · plus the numeral readouts. The earlier doc's "closed set" omitted `SHARE`, `HIDE|SHOW`, and `CAMERA FRONT|BACK`; that gap is closed here (the first two are this section's; `CAMERA FRONT|BACK` belongs to the camera section). All vocabulary words differ in case/wording from today's strings ⇒ **PROPOSAL** (correction 16, R7), not OBSERVED.

---

## §8 — Empty and error states (white room, words only)

Replacements for the TODAY `ContentUnavailableView` + `photo.fill` / `exclamationmark.triangle` + yellow + `ultraThinMaterial`. **No red anywhere.** Error = `ink` + `ERROR —` + `weight(.bold)` + a `1/displayScale` rule above (§0.5 #6).

### 8.1 No captures yet (TODAY `:99`)

```
+--------------------------------------------------+
| LIBRARY           [ blank tag ]             SHOOT |
+==================================================+
|                                                   |
|                         0                         |  display (96 Bold, tabular)
|                                                   |
|                   NO CAPTURES                     |  title
|             POINT AND SHOOT TO BEGIN              |  caption, secondary
|                                                   |
|                      [ SHOOT ]                    |  label control, tacked
+--------------------------------------------------+
```

The numeral `0` maps onto the canonical **`display`** token (correction 10 / critic #10 — `DISPLAY-28` is deleted; the `0` was orphaned and is now a real token). Title `NO CAPTURES` (`title`); body `POINT AND SHOOT TO BEGIN` (`caption`, `secondary`); action `SHOOT` (`label`, exposed as `gallery-empty`'s CTA). No icon, no yellow, bg `bg`.

### 8.2 Loading (TODAY `:75` yellow `ProgressView`)

`LOADING` word only, `caption`, centered — **no spinner** (spinners deleted room-wide). Populated refresh: `SYNCING` top-right in `caption`, `secondary`, until the stream settles. No blink.

### 8.3 Load failure, empty + error (TODAY `:81-96`)

```
|                    1 — ERROR                     |  caption, ink, Bold
|--------------------------------------------------|  1px rule ABOVE (per §0.5 #6)
|               UNABLE TO LOAD LIBRARY             |  title
|         [dynamic reason, max 2 lines]            |  body
|                      RETRY                       |  label, tacked
```

The word `1 — ERROR` replaces `exclamationmark.triangle` + `.tint(.yellow)`. `RETRY` = `label` word on `bg` with a `1px INK` border, `12×8pt` padding (no `borderedProminent`). OS-interpolated strings (`PhotoLibraryManager` `:169-191`, `CaptureService` `:739-765`) clamp to 2 lines (`:125` kept); full text behind a `+`/`-` disclosure (word toggle, not a chevron).

### 8.4 Stale grid + non-blocking banner (TODAY `:121-133`)

Banner becomes a white card: `bg` + `1px INK` border (rule location (f), correction 6), `0` radius, `8pt` inner (`:130` kept), outer `.padding()` (`:133` kept), row `spacing 12` (`:122` kept) + `Spacer` (`:126` kept): `ERROR — <2-line reason>  RETRY`. No material, no gray.

### 8.5 File cannot be decoded (TODAY `:169-176`)

```
|                    2 — ERROR                     |  caption, ink, Bold
|--------------------------------------------------|  1px rule
|               UNABLE TO LOAD DNG                 |  title
|         [localized reason or fallback]            |  body
|   pikicam-<uuid>.dng · <bytes> BYTES             |  body
|               RETRY        DISMISS               |  label, tacked
```

`RETRY` re-runs `.task(id:)`; `DISMISS` returns to grid (closes TODAY's stuck hole). Never a black frame or silent skip; the thumbnail cell for this asset shows an `ERROR` word chip instead of eternal gray (TODAY `:263` — the gray-equals-loading ambiguity closed).

### 8.6 Permission revoked

```
|                    3 — ERROR                     |
|              LIBRARY ACCESS NEEDED               |  title
|   PIKICAM NEEDS PHOTO ACCESS TO SHOW CAPTURES    |  body
|                  OPEN SETTINGS                   |  label
```

Copy distinguishes `denied` (→ Settings deep-link `UIApplication.openSettingsURLString` at `RootView.swift:105-106`) vs `restricted` (no Settings CTA, text `UNAVAILABLE ON THIS DEVICE`) vs `limited` (picker-management CTA). Replaces the raw enum interpolation `"current status: \(authorization)"` (`PhotoLibraryManager.swift:169`). `.readWrite` at `:241/:246` enables the `.limited` path.

### 8.7 Library with only non-pikicam photos

The grid shows ONLY pikicam DNGs (`pikicam-*`, UTI `com.adobe.raw-image`). State = §8.1 plus a second line: `11 SYSTEM PHOTOS HIDDEN — PIKICAM SHOWS ONLY ITS OWN DNGS` (`caption`, `secondary`). No system-photo thumbnail, no import CTA.

### 8.8 Thumbnail loading / failure (TODAY `:256-266`)

Loading: cell `bg` + `1px RULE` inner frame + word `DNG` (`caption`, `secondary`) centered, no shimmer v1. Failure: same + `ERROR` (`caption`, `ink`, tacked) + tap retries that cell only.

---

## §9 — Out of scope / unresolved / unverified

- **iPad:** OUT OF SCOPE (owner ruling 4, correction 9). The earlier spec's "iPad 4 portrait / 6 landscape" is deleted and the resolution stated explicitly (it was silently dropped by §0.5 #5).
- **Camera screen:** out of scope here. The bypass is absence on camera chrome; the camera carries no manifesto strip. Volume-button capture is kept and the **system volume HUD is accepted, not suppressed** (owner ruling 3).
- **Must-measure (no interim value locked):** exact gutter pt on Apple Photos; chrome auto-hide duration; swipe-dismiss physics; verbatim iOS strings for Bayer-DNG / undecodable; `fileDataRepresentation` payload shape; on-sensor preprocessing; Display-P3/gamma exactness.
- **The `.P.*` storage schema** (filenames/directory/approval gate) is unconfirmed on disk; `docs/` holds unverified `prompt-next.md` (NOT citable, R7). `README.md` exists at repo root (assert existence, not authority).
- **Tack colour question (see §3):** the house tacks are four *white* stitches on white, barely visible. In the white room the tag is `bg`-coloured and the tacks must be `ink` to register; a genuine white-on-white tack is invisible on `#FCFCFC`. `ink` tacks chosen; the true-invisible variant is flagged as a possible owner reopen.
- **Completeness gate (correction 11):** `.P.DESIGN` §5's "every state specifies six fields" is UNSATISFIABLE — `spec-state-matrix.md` has no hit-area column. The locked gate must **add a hit-area field** (or the criterion changes), or DESIGN-LOCK cannot terminate.
- **State-spec citations (correction 12)** and the state matrix itself are not re-verified in this file.

---

## §10 — Buildability note (R6)

All constructs are stock SwiftUI on iOS 26, zero dependencies: `LazyVGrid` (+ `.flexible()` / `.adaptive(minimum:140)`), `Rectangle` hairlines, `Font.custom("Courier New", size:, relativeTo:)` + `.system(design: .monospaced)`, `.tracking(_:)`, `.monospacedDigit()`, `ShareLink`, `.presentationDetents`, `MagnifyGesture` / `onTapGesture(count:2)` / `DragGesture`, `safeAreaInset`, semantic `UIColor`, and the four-`Rectangle` `Tack`. No `Divider()`, no two-arg `Font.custom`, no `Capsule`/`Circle`/`RoundedRectangle`, no `Image(systemName:)` in chrome, no `.yellow`, no `.red`, no `Margiela*` symbol name (Pole B: `Room`, `ChromeType`, `ChromeInk`, `ChromeRule`, `Tack`, `WordControl`). Fixed-pt type uses `relativeTo` + Dynamic Type verification (XXXL overflow at 375pt) and 44pt hit areas. Snapshot matrix: both rooms × {default, Increase Contrast} × {default, Reduce Transparency} × {default, Reduce Motion} × {`.large`, `.accessibility5`} at 375pt and 440pt, portrait **and landscape**. White-room snapshots assert `≥4.5:1` / `≥3:1`-large.

