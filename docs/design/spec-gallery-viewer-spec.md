# pikicam GALLERY + VIEWER — WHITE ROOM SPECIFICATION

Owner ruling: gallery and viewer are a WHITE ROOM. Words only. NO ICONS ANYWHERE. This inverts current code (black room, `NavigationStack` chrome, SF Symbols, `ContentUnavailableView`, `ultraThinMaterial`).

This section covers Gallery grid + FullScreenViewer only. Camera screen is out of scope.

## 0. What exists today (code authority, not proposal)

Quoted verbatim from inventory; every line verified by read:

- `pikicam/Features/Gallery/GalleryView.swift:14` `Color.black.ignoresSafeArea()` — gallery background fill.
- `pikicam/Features/Gallery/GalleryView.swift:163` `Color.black.ignoresSafeArea()` — viewer background fill.
- `pikicam/Features/Gallery/GalleryView.swift:69` `.preferredColorScheme(.dark)` — surface is always dark, no light treatment.
- `pikicam/Features/Gallery/GalleryView.swift:49` `"Library"` — navigation title.
- `pikicam/Features/Gallery/GalleryView.swift:50` `.navigationBarTitleDisplayMode(.inline)` — title display mode.
- `pikicam/Features/Gallery/GalleryView.swift:18` + `:31` `ToolbarItem(placement: .bottomBar)` x2 — two bottom-bar items: thumbnail slot then trash/camera row.
- `pikicam/Features/Gallery/GalleryView.swift:25` `.frame(width: 60, height: 50)` — toolbar latest-thumbnail size.
- `pikicam/Features/Gallery/GalleryView.swift:26` `RoundedRectangle(cornerRadius: 4)` — thumbnail clip.
- `pikicam/Features/Gallery/GalleryView.swift:32` `HStack(spacing: 16)` — trash/camera row gap.
- `pikicam/Features/Gallery/GalleryView.swift:36` `Image(systemName: "trash")` — gallery toolbar delete.
- `pikicam/Features/Gallery/GalleryView.swift:37` `.foregroundStyle(.red)` — trash glyph tint.
- `pikicam/Features/Gallery/GalleryView.swift:39` `.disabled(library.selectedCapture == nil)` — trash disabled with no selection.
- `pikicam/Features/Gallery/GalleryView.swift:42` `Image(systemName: "camera")` — toolbar back-to-camera.
- `pikicam/Features/Gallery/GalleryView.swift:43` `.foregroundStyle(.yellow)` — camera glyph tint.
- `pikicam/Features/Gallery/GalleryView.swift:106` `GridItem(.adaptive(minimum: 100), spacing: 2), spacing: 2` — grid geometry, 2pt gaps both axes.
- `pikicam/Features/Gallery/GalleryView.swift:113` `.aspectRatio(1, contentMode: .fit)` — square cells.
- `pikicam/Features/Gallery/GalleryView.swift:118` `.padding(2)` — grid outer inset.
- `pikicam/Features/Gallery/GalleryView.swift:260` `.scaledToFill()` (`:259` `.resizable()` + `:260` `.scaledToFill()`) — thumbnail fill, crops.
- `pikicam/Features/Gallery/GalleryView.swift:263` `.fill(Color.gray.opacity(0.3))` — thumbnail placeholder / stuck failure fill.
- `pikicam/Features/Gallery/GalleryView.swift:124` `.font(.caption)` — only explicit font in either file; banner error text.
- `pikicam/Features/Gallery/GalleryView.swift:77` `.tint(.yellow)` — loading spinner tint.
- `pikicam/Features/Gallery/GalleryView.swift:86` `.tint(.yellow)` on full-error `ContentUnavailableView` — untokenized in first pass, verified by grep.
- `pikicam/Features/Gallery/GalleryView.swift:100` `.tint(.yellow)` on empty state — same.
- `pikicam/Features/Gallery/GalleryView.swift:83` `systemImage: "exclamationmark.triangle"` — full load-failure illustration.
- `pikicam/Features/Gallery/GalleryView.swift:82` `"Unable to load library"` — full failure title.
- `pikicam/Features/Gallery/GalleryView.swift:89` `"Retry"` — retry buttons.
- `pikicam/Features/Gallery/GalleryView.swift:92` `.buttonStyle(.borderedProminent)` — full-error Retry style.
- `pikicam/Features/Gallery/GalleryView.swift:99` `"No captures" / "Capture a photo to begin."` — empty-state title/body with `systemImage: "photo.fill"`.
- `pikicam/Features/Gallery/GalleryView.swift:131` `.background(.ultraThinMaterial)` — stale-grid banner material.
- `pikicam/Features/Gallery/GalleryView.swift:132` `RoundedRectangle(cornerRadius: 8)` — banner clip.
- `pikicam/Features/Gallery/GalleryView.swift:125` `.lineLimit(2)` — banner truncation.
- `pikicam/Features/Gallery/GalleryView.swift:122` `HStack(spacing: 12)` + `:126` `Spacer()` + `:130` `.padding(8)` + `:133` `.padding()` outer — banner layout.
- `pikicam/Features/Gallery/GalleryView.swift:194` `"DNG Viewer"` — viewer top-bar title, default font.
- `pikicam/Features/Gallery/GalleryView.swift:197` `Image(systemName: chromeHidden ? "eye.slash" : "eye")` — chrome toggle.
- `pikicam/Features/Gallery/GalleryView.swift:201` `Image(systemName: "trash")` — viewer delete (no `foregroundStyle`, system default).
- `pikicam/Features/Gallery/GalleryView.swift:208` `"Back to Camera"` — viewer bottom action.
- `pikicam/Features/Gallery/GalleryView.swift:196-209` viewer eye/trash/back carry no `foregroundStyle`/`tint`/`buttonStyle` — system default on black, vs gallery red/yellow.
- `pikicam/Features/Gallery/GalleryView.swift:191-212` viewer chrome `VStack` has no background scrim/material — default text directly over image.
- `pikicam/Features/Gallery/GalleryView.swift:167` `.scaledToFit()` (`:166` `.resizable()` + `:167` `.scaledToFit()` + `:168` `.ignoresSafeArea()`) — viewer image fits container, letterboxes on aspect mismatch.
- `pikicam/Features/Gallery/GalleryView.swift:181` `Color.clear` + `:182` `.contentShape(Rectangle())` — transparent tap-catcher.
- `pikicam/Features/Gallery/GalleryView.swift:183` `.onTapGesture` body `:184-188` `chromeHidden.toggle()` — background tap toggles chrome, except first tap after appear swallowed by `hasConsumedOpeningTap` guard.
- `pikicam/Features/Gallery/GalleryView.swift:144` `chromeHidden=false` + `:159` `hasConsumedOpeningTap=false` — initial values.
- `pikicam/Features/Gallery/GalleryView.swift:51` `"Delete capture?"` + `:52` `"Delete"` + `:53` `"Cancel"` — gallery `confirmationDialog`; `:33` `Button(role: .destructive)`, `:52` `Button("Delete", role: .destructive)`, `:53` `Button("Cancel", role: .cancel)`.
- `pikicam/Features/Gallery/GalleryView.swift:216-228` viewer uses `.alert` while gallery uses `.confirmationDialog` — presentation difference never tokenized.
- `pikicam/Features/Gallery/GalleryView.swift:227` `"This removes the DNG from Pikicam."` — viewer delete message.
- `pikicam/Features/Gallery/GalleryView.swift:171` `"Unable to load DNG"` + `:173` `"This capture could not be developed."` fallback + `:175` `.tint(.yellow)` — viewer develop failure, `exclamationmark.triangle`, no Retry, no dismiss control (stuck state).
- `pikicam/Features/Gallery/GalleryView.swift:178` `ProgressView().tint(.yellow)` — viewer loading.
- `pikicam/Features/Gallery/GalleryView.swift:229` `.task(id: capture.id)` — reset `image=nil, loadFailed=false`, inputs `capture.aspectRatio / capture.zoomFactor`.
- `pikicam/Features/Gallery/GalleryView.swift:56` `.fullScreenCover(isPresented: $viewerPresented)` — system default transition, no duration; body renders nothing when `selectedCapture==nil` (empty-cover hole); system swipe-to-dismiss bypasses `onBackToCamera`.
- `pikicam/Features/Gallery/PikicamLibraryModel.swift:74` `CGSize(width: 300, height: 300)` — PhotoKit thumbnail pixel size, not layout pt.
- `pikicam/Features/Gallery/PikicamLibraryModel.swift:9-12` `captures=[]`, `selectedCapture=nil`, `isLoading=false`, `error=nil` — initial values.
- `pikicam/Features/Gallery/GalleryView.swift:19,107` ordering assumption behind `library.captures.first` (most-recent-first unspecced) and `ForEach id: \.element.id.uuid` vs assetID churn — unlisted.

All of the above is REPLACED by this spec. Nothing below describes current behavior unless labeled TODAY.

## 1. Design tokens (white room)

### 1.1 Palette — proposed, not measured on margiela.com

Verified site tokens (fetched `global.css`):

- `--color-mm-base-off-white: #fcfcfc`, `--color-mm-base-white: #ffffff`, neutrals `#cccccc/#e5e5e5`, `#404040/#6c6c6c`, alpha `#0000001a` as `--color-mm-base-black-alpha-10`, borders primary black / secondary black-alpha-10 / tertiary `#6c6c6c`, `--bs-gutter-x: 1.5rem`, MM6 dark `#151515`. Source: `https://www.maisonmargiela.com/on/demandware.static/Sites-MargielaGLOBAL-Site/-/default/v1790833881632/css/global.css`
- Accents on site (`--color-mm-base-red: #ea0000`, `#bf1d1d`, `#40aa75`, `#ffaa01`) exist but are REJECTED for gallery/viewer. White room is monochrome only.
- Focus blue `#006FE6` cited in research bundle: NOT FOUND in fetched `global.css`; only verified blue is MM6 `#007ED2`. Do not spec `#006FE6`.
- `margiela.com` ANONYMITY campaign title, exact computed CSS type/color/spacing, Instagram/newsletter design: UNVERIFIED (bundle open questions, fetch returned nav names only). Do not cite as authority.

Pikicam white-room mapping (SwiftUI, no dependencies, R6-passing):

- `BG`: `#FCFCFC` light / `#000000` dark. Semantic: `Color(uiColor: .systemBackground)`.
- `INK`: `#000000` light / `#FFFFFF` dark. Semantic: `Color(uiColor: .label)`.
- `SECONDARY`: `#6C6C6C` light / `#A8A8A8` dark. Normal text on `#FCFCFC` must meet WCAG AA: WebFetch `https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html` confirms `at least 4.5:1` normal, `at least 3:1` large-scale defined as `at least 18 point or 14 point bold`. Bundle hexes `#595959/#767676` are author calculations, not WCAG quotes — verify with Accessibility Inspector.
- `RULE`: 1px `BLACK` light (`#000000`) for structural dividers, `BLACK 10%` (`#0000001a` token above) for cell gutters; dark: `#333333` structural, `WHITE 15%` cell gutters. `HIG Materials` legibility/material quotes and `HIG Accessibility/Dark-Mode` quotes in bundle are UNVERIFIED (title-only fetches) — treat scrim/dark rules below as pikicam decisions, not Apple quotes.
- Selection: `INK` fill block + `BG` text (true inversion `#FFFFFF on #000000` / inverse in dark). Satisfies WCAG 1.4.11 `at least 3:1 against adjacent color(s)` per WebFetch `https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html`. Plus non-color cue (see §3): underline + `22`-style index prefix or `+`/`-` glyph. MDN `forced-colors` (`https://developer.mozilla.org/en-US/docs/Web/CSS/@media/forced-colors`) is a Windows-web mechanism, NOT iOS — do not cite for SwiftUI; iOS equivalents are Increase Contrast / Reduce Transparency / Bold Text / Invert Colors (bundle analogy flagged wrong-platform, directionally right).
- Error: NO RED in room. Error text is `INK` with prefix `ERROR —` + underline on the action word. Rationale: monochrome refusal set; red `#EA0000` exists on margiela.com but violates owner white-room rule.
- TODAY replaced: `Color.black` backgrounds (`GalleryView.swift:14,163`), `.yellow` (spinner `:77`, camera `:43`, badge), `.red` (trash `:37`, error text `CameraView.swift:236`), `gray.opacity(0.3)` placeholder (`:263`), `.ultraThinMaterial` (`:131`), `RoundedRectangle(cornerRadius: 4/8)` (`:26,:132`).

### 1.2 Type — word-only, two roles

Verified site type (fetched `global.css` + `fonts.css`):

- `.mm-txt-default{font-family:"CourierNewRecast","Courier New",Courier,monospace;` + `font-weight:500;font-size:14px;line-height:18px;text-transform:none}` — body mono 14/18. But `@font-face` files declare `font-weight: 400` only (`font-family: 'CourierNewRecast';` + `src: url('./CourierNewRecast/CourierRecast_W_Md.woff2')` + `font-weight: 400;`). Site requests 500, ships 400. Do not spec 500 as shipped truth.
- `.mm-txt-replica-title{font-family:"HelveticaNowProText",Helvetica,Arial,sans-serif;` + `font-weight:700;font-style:normal;font-size:16px;line-height:20px;letter-spacing:.16px;text-transform:uppercase}` — display sans 16/20.
- `.mm-txt-replica-display` 28/36 `ls .28px` uppercase; `.mm6-txt-default{` `font-weight:400;font-style:normal;font-size:13px;line-height:16px;` `letter-spacing:-0.13px;text-transform:none}` — verified, note class name is `mm6-txt-default`.
- Family count: 3 names / 5 blocks (`CourierNewRecast` + `CourierNewRecastItalic` + `HelveticaNowProText`), not "exactly two".
- Motion/controls quotes (`mm-btn-glyph-blink .6s`, `opacity 250ms`, `blink 1s`, `transition:none`, `border:1px solid var(--mm-border-primary)`, sheet `0 18px 18px`, `25/50/75vw`) were NOT FOUND in fetched excerpts — UNVERIFIED, do not spec durations from them.
- iOS font availability: WebFetch `https://developer.apple.com/fonts/system-fonts/` confirms `Courier New / Version 5.00.2x / iOS system font`. `https://developer.apple.com/documentation/uikit/available-fonts` returns 404 — do not cite. `Font.custom relativeTo`, HIG `44x44`, safe-area, `.isButton`, HIG Accessibility/Materials/Dark-Mode/RTL, device pt sizes, iOS 26 support list, `Divider` contract, `sf-symbols` catalog: all UNVERIFIED or wrong-URL in bundle (title-only or 404). Substance (relativeTo scaling, 44pt minimum, safe-area dock, Button semantics, scrim need, semantic colors, `1/displayScale` hairline) is true model-knowledge and R6-buildable; present as pikicam decisions, not Apple quotes.

Pikicam spec (all `Font.custom("Courier New", size:, relativeTo:)`, fallback `.system(design: .monospaced)` if `UIFont(name:)` nil; display role = `.system(design: .default)` sans, never a shipped Recast/Helvetica file):

| Role | SwiftUI | Tracking | Use |
|---|---|---|---|
| `ROOM/MONO-17` | `custom("Courier New",17,relativeTo:.body)` medium-equivalent | `+40/1000em` (`.tracking(0.68)`) | Top-bar words `LIBRARY / SHOOT / DELETE / SHARE` |
| `ROOM/MONO-14` | `custom("Courier New",14,relativeTo:.body)` | `+80/1000em` (`.tracking(1.12)`) | Section headers, viewer metadata keys |
| `ROOM/MONO-13` | `custom("Courier New",13,relativeTo:.footnote)` | `+40/1000em` | Grid date headers, viewer metadata values, empty/error body |
| `ROOM/MONO-12` | `custom("Courier New",12,relativeTo:.caption)` | `+80/1000em` | Buttons `RETRY / CANCEL / BACK`, banner text |
| `ROOM/MONO-11` | `custom("Courier New",11,relativeTo:.caption2)` | `+40/1000em` | Badges `DNG`, `22 REPLICA`-style numerals |
| `ROOM/DISPLAY-28` | `.system(size:28,weight:.bold)` uppercase | `+10/1000em` (`.tracking(0.28)`) | Empty-state numeral only (`0`), never in-camera shouting |
| `ROOM/NUMERAL` | mono + `.monospacedDigit()` | tabular | Countdown, zoom `1.0x`, EV `+1 2/3` |

TODAY replaced: `.font(.caption)` only explicit font (`GalleryView.swift:124`); viewer `"DNG Viewer"` default font (`:194`).

WCAG/NN/g constraints (verified):

- WebFetch `https://www.nngroup.com/articles/icon-usability/` confirms `a text label must be present alongside an icon`, `Icon labels should be visible at all times, without any interaction`, `Don't rely on hover to reveal text labels`, plus `Not a single test participant clicked this icon. Obscure icon = wasted feature.` Paraphrase-close, not character-exact — do not present as exact quotes. Translation: word labels always visible; iOS has no hover.
- Fashion poles (`jilsander.com`, `maisonmargiela.com`, `comme-des-garcons.com`, `phoebephilo.com`) all resolve to stark type-driven monochrome; Margiela collective sentence verbatim `We are a Parisian haute couture House founded on ideas of unconformity. We work as a collective.` Typeface/hex/divider specifics on those pages NOT verified — paraphrase only.
- Blank-tag / numbering / exposed-seam motifs (`https://en.wikipedia.org/wiki/Maison_Margiela`): `simple blank white labels with four white tacks`, `founded by Belgian designer Martin Margiela and Jenny Meirens in 1988` (Meirens-1988 contradicted by OTB/Vogue — downgrade to likely/disputed), `Distinct product ranges were given numbers as signifiers, in no particular chronological order` (0 artisanal, 10 Men's verified; 1/22/6 retailer-attested only), `intentionally exposed linings and seams`, Tabi `an interpretation of the traditional split Japanese tabi sock which separates the large toe`, `began handling all media via fax`. Founding/palette/campaign/typeface/numbering caveats per verdicts hold.

### 1.3 Rules, corners, motion

- Hairline: `Rectangle().frame(height: 1/displayScale)` via `@Environment(\.displayScale)`, exact colors §1.1. No `Divider` (no documented 1px contract — confirmed in negative: Divider doc fetch title-only). No `cornerRadius`: all `0` (`RoundedRectangle 4/8` at `:26,:132` deleted). No shadows, no blur/material anywhere in room.
- Motion: fade-only. Chrome `.transition(.opacity).animation(.easeOut(duration:0.25))`; grid insert fade 0.2s; no spring, no blink (step-end blinks conflict with record-indicator convention + photosensitivity — do not port). Durations are pikicam choices (site motion UNVERIFIED, see §1.2).
- Hit areas: every visible word may be 11–17pt but `Button` frame is min `44x44pt` via `.frame(minWidth:44,minHeight:44) + .contentShape(Rectangle())`. Hairline itself never the hit area. (44pt minimum is true longstanding HIG guidance; bundle URL unverifiable — spec as pikicam rule.)
- Buttons: real SwiftUI `Button` (`.isButton` automatic). Icon-only buttons with zero `accessibilityLabel/Hint` (`GalleryView.swift:190-199` viewer-background/chrome-toggle/delete/back) are deleted in this spec; every replacement word carries label = visible text.
- RTL: `.leading/.trailing` only; test `ar` + `.rightToLeft`; clock/timer numerals unmirrored. (Bundle quote unverifiable — rule stands as pikicam decision.)
- Sizes: verify at `375x667pt` (SE, smallest) through `440x956pt` (16 Pro Max, largest); floor iPhone 11 / SE 2nd gen. (Bundle cited wrong URLs — `iphone-16/specs` is standard 16 only; `support 122266` 404s. True sources per search: `support 121032/111846/121115`. Treat sizes as test matrix, not cited-page facts.)

## 2. Grid

### 2.1 Convention, then pikicam

Apple HIG grid-quote (`https://developer.apple.com/design/human-interface-guidelines/grids`), LazyVGrid nil-default quote, Photos pinch Years/Months/Days quote (`https://support.apple.com/search?...`), viewer chrome order, viewer gestures (`https://support.apple.com/guide/photos/welcome/ios`), TabView competition (`https://developer.apple.com/documentation/swiftui/tabview`), MagnifyGesture comparison, selection guidance, alerts guidance, ProRAW (`https://developer.apple.com/pro-raw/` 403), Adobe DNG (`https://helpx.adobe.com/camera-raw/digital-negative.html` 403/404): ALL REFUTED as cited — URLs 404/title-only/TOC-only or quotes invented. Substance partly true via other pages (pinch groupings, MagnifyGesture iOS17 vs deprecated MagnificationGesture, tap-to-show/hide, ProRAW DNG-based per `HT211965`, DNG container per spec) but NOT citable to bundle URLs. P.DESIGN must not quote them. What remains citable: `Toolbars` partial verbatim `Use a toolbar to provide contextual actions for the selected content` (singular; bundle added a second sentence that was not verified) from `https://developer.apple.com/design/human-interface-guidelines/toolbars`; `MagnifyGesture is the new name for MagnificationGesture, MagnificationGesture deprecated, iOS 17.0+ vs 13.0+` from `https://developer.apple.com/documentation/swiftui/magnifygesture`; CIRAWFilter neutral = demosaic/WB/matrix/tone-map before enhancements from `developer.apple.com/documentation/coreimage/cirawfilter` (swap-in source); ProRAW computational from `https://support.apple.com/en-us/HT211965` + tone-map/NR from iPhone 14 Pro newsroom (not dead `HT211131`); Halide Process Zero page `https://halide.cam/process-zero/` UNVERIFIED (404 on fetch) — do not quote; `https://halide.cam` homepage verified only for `Halide turns your iPhone into a traditional camera`, `swiping up and down for exposure, and left and right for focus` (marketing, conflicts with manual `vertical=shutter/horizontal=ISO` — do not norm from it), Blackmagic `https://www.blackmagicdesign.com/products/blackmagiccamera` verified for `When recording, the button and timecode at the top of the screen turn red` + HUD lens/frame-rate/shutter-angle/ISO/WB/histogram/audio + `swipe up or down` HUD toggle.

Hands-on norms (true but unsourced for R5 — pin as Margiela values below, do not claim Apple parity): square-cell recents grid, newest-first, date-sectioned, iPhone 3-col norm, tap toggles chrome, swipe-down dismiss, horizontal page, pinch/double-tap zoom, toolbar Share/Favorite/Info/Delete.

### 2.2 Grid spec

- Columns: iPhone portrait 3, iPhone landscape 5, iPad 4 portrait / 6 landscape. Implementation: `LazyVGrid(GridItem(.flexible(), spacing: GUTTER))`, NOT `.adaptive(minimum:100)` (TODAY `:106`). Gutter `GUTTER = 2pt` both axes (`LazyVGrid(spacing: 2)`); outer inset `.padding(2)` (keep TODAY `:118` value, change color context to white room). iPad values are pikicam choices — Apple publishes no fixed column/gutter (bundle correctly flags as needing device measurement).
- Cell: square `aspectRatio(1, .fit)` (keep TODAY `:113`), image `.resizable().scaledToFill().clipped()` (TODAY `:259-260`). No rounding, no badge, no icon overlay. Selected cell: full-bleed `INK` veil `opacity 0.12` + `2pt INK` inner frame inset 4pt + index word `01` top-left in `ROOM/MONO-11` on `BG` chip `20x16pt`. Non-color cue mandatory (underline under index + frame), never tint alone.
- Order: newest first, top-left. `library.captures.first` = newest is TODAY's assumption (`GalleryView.swift:19,107` unspecced) — PROMOTE to contract: model sorts `creationDate` descending; document it; test asserts `gallery-cell-0` = just-captured DNG (test contract `pikicamUITests/SmokeLaunchTest.swift:291`).
- Sectioning: date sections, one header per day: `TUESDAY 30 SEPTEMBER 2026 — 04` in `ROOM/MONO-13` uppercase, `SECONDARY`, leading-aligned, `18pt` margins (site margin token, revalidate against safe area), `12pt` above / `6pt` below, ruled by `1px RULE` full-bleed under header. No sticky headers v1 (plain `LazyVStack` sections). Timezone: device-local; midnight boundary.
- Header treatment (room top bar): `60pt` bar (`--mm-header-height: 60px` verified; paired `--mm6-header-height: 40px` omitted in bundle — include both contexts, use 60pt). Content: left `LIBRARY` (`ROOM/MONO-17`, `INK`, underlined = active root), center blank-tag mark `64x20pt` blank `BG` rectangle with `1pt INK` border + four `8x2pt INK` ticks (top edge, at 8/24/40/56pt), right `SHOOT` (word button → dismiss to camera). Below bar: `1px INK` rule full-bleed. No `NavigationStack` title `"Library"` (`:49-50` deleted), no large title, no search, no edit pencil.
- Scroll: vertical `ScrollView`, no pull-to-refresh v1 (refresh is `.task { await library.refresh() }` at `:70` + init double-refresh + `watchInvalidation` stream `PikicamLibraryModel.swift:15-22,43-47` with `.bufferingNewest(1)` at `PhotoLibraryManager.swift:221` — bursts coalesce; silent refresh while populated shows no spinner TODAY (`:75` gate `isLoading && captures empty`). Spec: while populated, refresh shows `SYNCING` word top-right in `ROOM/MONO-11 SECONDARY` until stream settles; never a spinner.
- Pinch on grid: RESERVED. Do not remap (Years/Months/Days cycle omitted v1; must not collide if added later).

```
GRID — iPhone portrait, 3 col, white room
+--------------------------------------------------+
| LIBRARY                  [__tag__]          SHOOT |  60pt bar
+==================================================+  1px INK rule
| TUESDAY 30 SEPTEMBER 2026 — 04                   |  MONO-13 SECONDARY
|--------------------------------------------------|  1px RULE
| [img 01 underline] [img      ] [img      ]       |  2pt gutters
| [img      ] [img      ] [img SEL:ink veil+frame] |
|                                                  |
| MONDAY 29 SEPTEMBER 2026 — 11                    |
|--------------------------------------------------|
| [img      ] [img      ] [img      ]               |
+--------------------------------------------------+
| SHOOT          DELETE          SHARE            |  bottom word bar (§7)
+--------------------------------------------------+
```

## 3. Selection

- How selected: tap cell toggles `library.select(capture)` (`GalleryView.swift:20,33,41,108` Button-taps have no gesture tokens in bundle — listed here). Single-select v1 (trash `.disabled(... == nil)` at `:39` preserved as word-state). Tap again deselects. No long-press, no checkmark icon (no icons anywhere).
- Read in white room: selected = `INK` veil + `2pt` frame + `01` index chip + underline. Unselected = bare image. Never gray-on-gray, never yellow (TODAY zoom-chip `Color.yellow`/black-text at `CameraView.swift:136,142,161` and spinner/tints deleted).
- VoiceOver: selected cell exposes `.accessibility(label: "Capture 3, Tuesday 30 September, selected")` + `.isSelected`; unselected omits `selected`. (TODAY zero `accessibilityLabel/Value/Hint/Traits` literals — gap closed.)
- On tap (open): cell `Button(select + viewerPresented = true)` (TODAY `:105`) opens viewer at that capture. No double-tap in grid.

## 4. Viewer

### 4.1 Chrome show/hide + auto-hide

- TODAY: `Color.black` + `scaledToFit` (`:163,:166-168`), header `"DNG Viewer"` (`:194`), eye `eye/eye.slash` (`:197`), trash default-tint (`:201`), `"Back to Camera"` (`:208`), tap-catcher `Color.clear + contentShape` (`:181-182`), toggle `:183-188` with `hasConsumedOpeningTap` dead-first-tap, no scrim (`:191-212`), `Spacer()`s at `:126,:195,:206` untokenized.
- SPEC: background `BG` (`#FCFCFC` light) full-bleed; image `scaledToFit` centered, letterbox = `BG` (no black bars — TODAY `:163-168` black letterbox deleted). Chrome = two white bars with `1px INK` rules, NOT floating icons:
  - Top bar `60pt`: left `BACK` (word, → grid), center `DNG 03 / 11` (`ROOM/MONO-14`), right `HIDE` / `SHOW` (word toggle, replaces `eye/eye.slash`).
  - Bottom bar `72pt` above safe area: left `DELETE`, center metadata line (see §5, truncated 1 line), right `SHARE`. Above-home-indicator zone: background extends, controls sit in `safeAreaInset(bottom)`, never hard-coded 34pt.
- Single tap on image toggles chrome with 0.25s opacity fade. FIRST TAP WORKS — delete `hasConsumedOpeningTap` dead-tap (`:159,:183` hole closed; test contract `SmokeLaunchTest.swift:327` "tap twice when needed" is edge behavior with no designed treatment — replaced by single-tap-always).
- Auto-hide: NONE. Chrome stays until tap. (No Apple doc value found — bundle open question stands. Explicit choice stated per R5.)
- Bright-DNG readability: chrome bars are opaque `BG`, never text-over-image (TODAY no-scrim `:191-212` gap closed). Full-bleed `HIDE` state shows bare DNG on `BG` with zero chrome and a `44x44` invisible `SHOW` tap zone top-right (VoiceOver rotor `SHOW CONTROLS`).

```
VIEWER — chrome visible, white room
+--------------------------------------------------+
| BACK            DNG 03 / 11                 HIDE |  60pt + 1px rule
+--------------------------------------------------+
|                                                  |
|                                                  |
|                [ DNG scaledToFit ]               |
|                (letterbox = BG)                  |
|                                                  |
+--------------------------------------------------+
| DELETE     4000x3000 · f/1.9 · 1/120 · ISO 64   SHARE | 72pt
+==================================================+
```

```
VIEWER — chrome hidden
+--------------------------------------------------+
|                                                  |
|                [ DNG full-bleed fit ]            |
|                                                  |
|                                       (SHOW 44)  |  invisible tap zone
+--------------------------------------------------+
```

### 4.2 Dismiss, paging, zoom

- Dismiss: swipe-down on image at fit-zoom dismisses to grid (velocity > 800pt/s or translation > 120pt, spring `.interactiveSpring(response:0.32, damping:0.88)`); `BACK` word = same; system `fullScreenCover` swipe (`:56`) is intercepted to call `onBackToCamera` so gallery state reconciles (TODAY bypass gap closed). No `nil-capture` empty cover (TODAY `:56-68` hole — gate `viewerPresented && selectedCapture != nil`).
- Paging: horizontal swipe at fit-zoom = prev/next with `TabView(.page)`-equivalent `DragGesture`; when zoomed `>1.0x`, pan wins, paging disabled (bridge `UIScrollView` if SwiftUI gesture competition bites — TODAY no paging at all: `FullScreenViewer` at `:141-248` implements only single-tap toggle, no double-tap/pinch/swipe — all below is new). Page indicator is words: `DNG 03 / 11` updates; no dots.
- Zoom: double-tap toggles fit ↔ 2.0x centered at tap (`onTapGesture(count:2)`); pinch `MagnifyGesture` (iOS 17+ current; `MagnificationGesture` older/deprecated — verified `magnifygesture` page) continuous `1.0x–8.0x`, transient readout `2.4x` in `ROOM/MONO-12` top-center chip (`BG` + `1px INK` border, `44x28pt`), dwell 1.0s after release; pan when zoomed, rubber-band at edges. Preset chips are camera-screen only, not viewer.
- Zoom/pan accessibility: `+` / `-` word steppers (`44x44`) + `FIT` word (double-tap equivalent) in chrome-overflow row when zoomed; `Done/Back`, prev/next words always present. (Bundle accessibility mapping correctly marked uncertain/inferred — spec as pikicam decision.)

## 5. Metadata surface (auditable zero-process)

Location: viewer bottom-bar center line (1-line summary) + `DATA` sheet (half-sheet `.presentationDetents([.medium,.large])`, `18pt` margins per sheet token, `1px INK` rules between rows, mono rows, no icons).

Summary line (always visible): `4000×3000 · DNG · 1.0x` (pixel dims · format · framing zoom). Truncates middle, never wraps.

`DATA` sheet rows (keys `ROOM/MONO-14 SECONDARY` uppercase, values `ROOM/MONO-13 INK`, sentence-case values):

- `FILE`: `pikicam-<uuid>.dng` (contract `pikicam-\(capture.id.uuid.uuidString).dng` at `PikicamPipelineTests.swift:160`; originalFilename key + crash-recovery key at `PhotoLibraryManager.swift:886`; index store `pikicam-capture-index-v<version>.json` at `:817`; UTI `com.adobe.raw-image` at `PikicamPipelineTests.swift:158` / `PhotoLibraryManager.swift:217` `UTType(filenameExtension: dng)`).
- `BYTES`: `24 117 888` + `RESOURCE: SINGLE DNG` (single-resource save contract; probe variants `public.jpeg/jpg/dng` at `:287-309` rejected).
- `SENSOR`: `4000×3000 FULL-SENSOR RETAINED` (PrintCrop fixture `CGRect(0,0,4000,3000)` at `CameraControlTests.swift:170`; crop is view-time only).
- `BAYER`: `14-BIT RGGB` (allowlist `kCVPixelFormatType_14Bayer_RGGB/GRBG/GBRG/BGGR` at `CaptureService.swift:638-641`; settings `AVCapturePhotoSettings(rawPixelFormatType: bayerFormat)` at `:536`; `photoOutput.isAppleProRAWEnabled = false` at `:679` with pure-Bayer comment `:676-680`).
- `PRORAW`: `OFF` (support `HT211965` DNG-based + computational; NOT dead `HT211131`; tone-map/NR specifics from iPhone 14 Pro newsroom, paraphrase not quote).
- `EXPOSURE`: `1/120 · f/1.9 · ISO 64 · 0 EV` (device values; EV snapped 1/3: `ExposureCompensation minThird -9/maxThird 9` = `-3…+3 EV` at `CameraControls.swift:250-257`; label uses `U+2212` minus, e.g. `−2/3`, `+1 2/3` at `CameraControls.swift:287-295`, byte-verified).
- `FOCAL/ZOOM`: `1.0x CAPTURE · 2.0x FRAMING CROP AT VIEW` (1x-internal capture + 250ms settle at `CaptureService.swift:518-530`; restore-then-diverge reconciled via `currentVideoZoomFactor`).
- `WHITE BALANCE`: `ASSHOTNEUTRAL RETAINED` + `MATRIX: CAMERA → STANDARD RETAINED`.
- `CONVERSION — ALWAYS ON` (retained by omission, `CIRAWZeroProcessor.swift:8-13`): `DEMOSAIC / BLACK-LEVEL (DNG TAGS) / COLOR MATRIX (DNG TAGS) / ASHOTNEUTRAL WB / TONE MAP (CORE PIPELINE, NOT DEFEATABLE) / DISPLAY P3 RENDER`. Tone-map-in-neutral per Apple `cirawfilter` docs — must be disclosed, never implied zeroed.
- `ENHANCEMENTS — ALL OFF` (15-entry zero recipe at `CIRAWZeroProcessor.swift:63-81`, init `CIRAWFilter(imageData:)` at `:31`; property names pinned by `PikicamPipelineTests.swift:493-509` + forbidden `temperature/tint/neutralTemperature/neutralTint/decoderVersion` at `:523`, tolerance `1e-4`): list each with value `0.0` / `FALSE`: `BASELINEEXPOSURE / EXPOSURE / BOOST / BOOSTSHADOW / SHADOWBIAS / LOCALTONEMAP / LUMINANCENR / COLORNR / SHARPNESS / DETAIL / MOIRE / CONTRAST / EXTENDEDDR / LENSCORRECTION FALSE / GAMUTMAPPING FALSE`.
- `RENDER`: `TRANSIENT BITMAP ONLY — NO JPEG ENCODED, NO FILE WRITTEN` (`DevelopService.swift:12-14`, `:62 develop`, `:69 renderBitmap`; `RAWProcessor.swift:27-29` in-memory-only).
- `FRAMING`: `ASPECT 4:3 · CROP-ONLY-AT-VIEW` (labels `4:3/16:9/1:1` at `CameraControls.swift:152-158`; ratio `4.0/3.0,16.0/9.0,1.0` at `:132-137`).
- Copy rule: say `BAYER DNG · PRORAW OFF`, never bare `RAW`; honest verbs `DEVELOP / CONVERT / RENDER`, never `SENSOR-DUMP` / `UNCONVERTED PIXELS` / unqualified `NO PROCESSING` (CIRAWFilter at neutral still converts — bundle caution holds; Adobe `helpx` URLs 403, Halide scope quote invented, Snapseed URL empty — do not cite them; cite Apple `cirawfilter` + code lines above).

## 6. Delete and share

- Placement: viewer bottom bar `DELETE` (left) / `SHARE` (right); grid bottom bar `DELETE` (center-left) / `SHARE` (center-right) + `SHOOT` (see §7). No trash icon (`:36,:201` deleted), no share-icon (new surface — share sheet does not exist in code today; no share path inventoried).
- Grid delete: enabled only when selection non-nil (keep `:39` logic, word dims to `SECONDARY` + no underline when disabled). Tap `DELETE` → `confirmationDialog` (keep presentation split: gallery = dialog, viewer = alert per `:51-53` vs `:216-228`) with title `DELETE CAPTURE?` + body `THIS REMOVES THE DNG FROM PIKICAM.` (`:227` sentence-case TODAY → uppercase room copy) + actions `DELETE` (`role: .destructive`, underlined, `INK`) / `CANCEL` (`role: .cancel`). No count in title v1 (single-select).
- Viewer delete: same copy as `.alert`; success dismisses viewer + grid reflects removal; failure (`deleted=false`) surfaces in-viewer `ERROR — COULD NOT DELETE. RETRY` (TODAY `:216-224` leaves viewer open with `library.error` hidden behind cover — gap closed).
- Share: system `ShareLink` on the stored DNG bytes (original `fileDataRepresentation`, full-sensor, NOT the transient rendition; embedded-preview leak question stays open per bundle). No `22 REPLICA` export preset, no JPEG option, no filter/enhance entry point anywhere.
- Undo: PhotoKit delete is destructive — confirm-first (no Recently-Deleted path in pikicam; HIG Undo-over-alert guidance unverified-title-only — decision: alert-first because no undo exists).

## 7. Bottom bar redesign + identifier fate

TODAY (`:18,:31` two `ToolbarItem(.bottomBar)`, `60x50` thumb `:25`, `spacing 16` `:32`, thumbnail + trash + camera overlapping home-indicator zone, asymmetric empty slot when `captures` empty (`:19` no placeholder), `tint(.yellow)` `:77/:93`, `borderedProminent` `:92`):

REPLACED by one opaque `BG` bar, `64pt` tall + safe-area bottom, `1px INK` top rule, three word buttons in `HStack` (`SHOOT` leading / `DELETE` center / `SHARE` trailing), each `ROOM/MONO-17`, min `44x44`, `.leading/.trailing` pinned, `18pt` side margins:

```
+==================================================+  1px INK
| SHOOT                DELETE                SHARE |  64pt + safeArea
+--------------------------------------------------+
```

No thumbnail in bar (grid IS the thumbnails; TODAY `:25-26` mini-thumb deleted). No camera glyph (`:42-43` deleted). `DELETE` disabled-state = `SECONDARY`, no underline; enabled = `INK` + underline.

Identifier fate (test contracts in `SmokeLaunchTest` + `CameraControlTests` break unless tests updated — flag explicitly):

| TODAY identifier | Fate |
|---|---|
| `gallery-latest-thumbnail` (`:28`) | REMOVED (no bar thumb). Tests tapping it (`SmokeLaunchTest.swift:217`) migrate to `room-shoot`. |
| `gallery-trash` (`:40`) | RENAMED → `room-delete`. |
| `gallery-camera` (`:45`) | RENAMED → `room-shoot`. |
| `gallery-loading` (`:78`) | RENAMED → `room-loading` (word `LOADING`, no spinner tint). |
| `gallery-error` (`:87,:134`) | KEPT name, new white treatment. |
| `gallery-retry` (`:95,:128`) | KEPT name, word `RETRY` underlined mono, no `borderedProminent`/yellow. |
| `gallery-empty` (`:101`) | KEPT name, new `0` numeral treatment. |
| `gallery-cell-\(index)` (`:115`) | KEPT. |
| `library-grid` (`:120`) | KEPT. |
| `viewer-load-failure` (`:176`) | KEPT. |
| `viewer-loading` (`:179`) | KEPT, word spinner. |
| `viewer-background` (`:190`) | KEPT (tap-catcher, now `BG`). |
| `viewer-chrome-toggle` (`:199`) | RENAMED → `viewer-hide-show` (word `HIDE/SHOW`). |
| `viewer-delete` (`:203`) | KEPT name, word `DELETE`. |
| `viewer-back` (`:210`) | KEPT name, word `BACK`. |
| `Continue`, `Capture photo`, `grid-toggle`, `grid-overlay`, `mode-*`, `aspect-overlay`, `flash-toggle`, `front-camera-toggle`, `zoom-indicator`, `preview-pinch-area`, `Library`, `No captures`, `Unable to load DNG`, `Cancel/Delete`, `OK/Allow` (test-contract surface) | Unchanged by this section except `Library` title → `LIBRARY` bar word; `No captures` → `0 / NO CAPTURES` (§8). |

## 8. Empty and error states (all white room, words only)

Convention strings for Bayer-DNG viewer / undecodable file on iOS: NOT in fetched docs (bundle open question stands — needs device test with pikicam-style DNG). Code TODAY: `ContentUnavailableView` + `photo.fill` / `exclamationmark.triangle` + yellow + `ultraThinMaterial` + warning-triangle yellow (`RootView.swift:92-94`). Both wrong for this design. Replacements:

### 8.1 No captures yet (TODAY `:99` `"No captures" / "Capture a photo to begin."` + `photo.fill` + yellow)

```
+--------------------------------------------------+
| LIBRARY                  [__tag__]          SHOOT |
+==================================================+
|                                                  |
|                                                  |
|                         0                        |  DISPLAY-28 INK
|                                                  |
|                   NO CAPTURES                    |  MONO-14 +80
|             POINT AND SHOOT TO BEGIN             |  MONO-13 SECONDARY
|                                                  |
|                      [ SHOOT ]                   |  underlined word btn
+--------------------------------------------------+
```

Spec: numeral `0` (`ROOM/DISPLAY-28`), title `NO CAPTURES`, body `POINT AND SHOOT TO BEGIN` (collective-voice, no avatar/byline — anonymity operational per fax/collective citations), action `SHOOT` (→ camera). No icon, no yellow, bg `BG`.

### 8.2 Loading (TODAY `:75` yellow `ProgressView` when empty; silent same-grid when populated)

```
| LIBRARY ...                                      |
+==================================================+
|                      LOADING                     |  MONO-14 + blink? NO blink
|                      (word only, no spinner)     |
```

Populated refresh: `SYNCING` top-right `MONO-11 SECONDARY` until `.task`/invalidation settles. No spinner anywhere (spinners deleted room-wide).

### 8.3 Load failure, empty + error (TODAY `:81-96` `"Unable to load library" + localizedDescription + borderedProminent yellow Retry`)

```
|                    1 — ERROR                     |
|               UNABLE TO LOAD LIBRARY             |
|         [dynamic reason, max 2 lines, MONO-13]    |
|                      RETRY                       |  underlined
```

Word `1 — ERROR` replaces `exclamationmark.triangle` (`:83`) + `.tint(.yellow)` (`:86`). `RETRY` = `ROOM/MONO-12` underlined `INK` on `BG` with `1px INK` border `12x8pt` padding (no `borderedProminent`). Dynamic OS-interpolated strings (`PhotoLibraryManager` `:169-191`, `CaptureService` `:739-765`, e.g. `"Photos rejected the DNG save: \(failure.message)"`) clamp to 2 lines (`:125` kept), full text in `DATA`-style detail disclosure (`+`/`-` word toggle, not chevron).

### 8.4 Stale grid + non-blocking banner (TODAY `:121-133` caption + Retry over `ultraThinMaterial` rounded-8)

Banner becomes white card: `BG` + `1px INK` border, `0` radius, `8pt` inner (`:130` kept), outer `.padding()` (`:133` kept), row `spacing 12` (`:122` kept) + `Spacer` (`:126` kept): `ERROR — <2-line reason>    RETRY`. No material, no gray.

### 8.5 File cannot be decoded (TODAY `:169-176` `"Unable to load DNG"` + triangle + fallback, no Retry, stuck)

```
|                    2 — ERROR                     |
|               UNABLE TO LOAD DNG                 |
|         [localized reason or fallback]            |
|   pikicam-<uuid>.dng · 24 117 888 BYTES          |
|               RETRY        DISMISS               |
```

`RETRY` re-runs `.task(id:)` develop; `DISMISS` returns to grid (closes TODAY's no-dismiss stuck hole). Never a black frame or silent skip; thumbnail cell for this asset shows `ERROR` word chip instead of eternal gray (`:263` gray-equals-loading hole closed; TODAY `:266` catch-sets-nil indistinguishable — replaced).

### 8.6 Permission revoked (library)

```
|                    3 — ERROR                     |
|              LIBRARY ACCESS NEEDED               |
|   PIKICAM NEEDS PHOTO ACCESS TO SHOW CAPTURES    |
|                  OPEN SETTINGS                   |
```

Copy distinguishes `denied` (→ Settings deep-link `UIApplication.openSettingsURLString` at `RootView.swift:105-106`) vs `restricted` (system prohibition — no Settings CTA, text `UNAVAILABLE ON THIS DEVICE`) vs `limited` (picker management CTA). TODAY `RootView` collapses all into one denial screen (bundle gap) and raw enum interpolation (`"current status: \(authorization)"` at `PhotoLibraryManager.swift:169` renders camelCase debug text — replaced by words above; `.readWrite` at `:241/:246` enables `.limited` path). No `camera.aperture 72pt` / `exclamationmark.triangle.fill` yellow (`RootView.swift:62-94` interstitials replaced if surfacing inside gallery).

### 8.7 Library with only non-pikicam photos

Pikicam grid shows ONLY pikicam DNGs (filename `pikicam-*`, UTI `com.adobe.raw-image`); non-pikicam assets never listed. State = same as §8.1 plus second line: `11 SYSTEM PHOTOS HIDDEN — PIKICAM SHOWS ONLY ITS OWN DNGS` (`MONO-11 SECONDARY`). No system-photo thumbnail, no import CTA.

### 8.8 Thumbnail loading / failure (TODAY `:256-266` flat gray, no shimmer/progress/skeleton; failure = eternal gray)

Loading: cell `BG` + `1px RULE` inner frame + word `DNG` (`MONO-11 SECONDARY`) centered, no shimmer v1 (size-stable: square cell already reserves space). Failure: same + `ERROR` (`MONO-11`, underlined) + tap retries that cell only.

## 9. Out-of-scope / unverified (do not spec from)

- Exact gutter pt / iPad columns on Apple Photos side, chrome auto-hide duration, swipe-dismiss physics (rubber-band/velocity/origin-rect), date-header treatment/sort on Apple's tail, verbatim iOS strings for Bayer-DNG/undecodable: bundle open questions, still missing — values above are pikicam choices.
- `fileDataRepresentation` payload shape (linear + embedded preview?), on-sensor preprocessing, non-defeatable CIRAW curve isolation, Display-P3/gamma badge exactness, reviewer pixel-diff protocol: bundle open questions, need sample-DNG dump + SDK pin (recipe already pinned by `PikicamPipelineTests` vs SDK).
- `.P.*` storage schema (filenames/directory/approval gate): user asked `.P.<DESIGN,IMPLEMENTATION,etc.>` — no directory/schema confirmed on disk (`docs/` holds only unverified `prompt-next.md`, NOT citable per R7; `README.md` exists at repo root but unopened per R1 — assert existence, not authority; no `AGENTS.md`/ADRs/design docs on disk).

## 10. Buildability note (R6)

All constructs: `LazyVGrid`, `Rectangle` hairlines, `Font.custom("Courier New")` + `.system` fallback, `.tracking()`, `.monospacedDigit()`, `ShareLink`, `.presentationDetents`, `MagnifyGesture`/`onTapGesture(count:2)`/`DragGesture`, `safeAreaInset`, semantic `UIColor` — SwiftUI iOS 26, zero dependencies. Fixed-pt type must use `relativeTo` + Dynamic Type verification (XXXL overflow at 375pt) and 44pt hit areas; viewfinder-overlay contrast rules from camera section do not transfer literally to white gallery (gallery ratios are static `4.5:1/3:1`, verified WCAG page above).
