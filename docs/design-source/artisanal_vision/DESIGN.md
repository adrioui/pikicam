---
name: Artisanal Vision
colors:
  surface: '#131313'
  surface-dim: '#131313'
  surface-bright: '#3a3939'
  surface-container-lowest: '#0e0e0e'
  surface-container-low: '#1c1b1b'
  surface-container: '#201f1f'
  surface-container-high: '#2a2a2a'
  surface-container-highest: '#353534'
  on-surface: '#e5e2e1'
  on-surface-variant: '#c5c7c2'
  inverse-surface: '#e5e2e1'
  inverse-on-surface: '#313030'
  outline: '#8e918d'
  outline-variant: '#444844'
  surface-tint: '#c7c6c4'
  primary: '#ffffff'
  on-primary: '#2f312f'
  primary-container: '#e3e2df'
  on-primary-container: '#646562'
  inverse-primary: '#5e5f5c'
  secondary: '#c6c6c7'
  on-secondary: '#2f3131'
  secondary-container: '#454747'
  on-secondary-container: '#b4b5b5'
  tertiary: '#ffffff'
  on-tertiary: '#2f3038'
  tertiary-container: '#e3e1ec'
  on-tertiary-container: '#63646c'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#e3e2df'
  primary-fixed-dim: '#c7c6c4'
  on-primary-fixed: '#1a1c1a'
  on-primary-fixed-variant: '#464745'
  secondary-fixed: '#e2e2e2'
  secondary-fixed-dim: '#c6c6c7'
  on-secondary-fixed: '#1a1c1c'
  on-secondary-fixed-variant: '#454747'
  tertiary-fixed: '#e3e1ec'
  tertiary-fixed-dim: '#c6c5cf'
  on-tertiary-fixed: '#1a1b22'
  on-tertiary-fixed-variant: '#46464e'
  background: '#131313'
  on-background: '#e5e2e1'
  surface-variant: '#353534'
typography:
  headline-lg:
    fontFamily: Space Mono
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 36px
    letterSpacing: -0.04em
  headline-lg-mobile:
    fontFamily: Space Mono
    fontSize: 26px
    fontWeight: '700'
    lineHeight: 30px
    letterSpacing: -0.03em
  headline-md:
    fontFamily: Space Mono
    fontSize: 20px
    fontWeight: '700'
    lineHeight: 24px
    letterSpacing: -0.02em
  body-lg:
    fontFamily: Space Mono
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 22px
    letterSpacing: 0.02em
  body-md:
    fontFamily: Space Mono
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
    letterSpacing: 0.01em
  label-lg:
    fontFamily: Geist
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.15em
  label-md:
    fontFamily: Space Mono
    fontSize: 11px
    fontWeight: '400'
    lineHeight: 14px
    letterSpacing: 0.08em
  label-sm:
    fontFamily: Space Mono
    fontSize: 9px
    fontWeight: '400'
    lineHeight: 12px
    letterSpacing: 0.18em
spacing:
  gutter: 0.75rem
  gutter-compact: 0.5rem
  margin: 1rem
  margin-safe: 1.25rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1rem
  space-xl: 1.5rem
---

## Brand & Style
The design system translates the conceptual luxury, radical deconstruction, and tactile anonymity of high fashion into an avant-garde native iOS camera experience. Rejecting decorative skeuomorphism and generic glass interfaces, the UI adopts a radical utilitarian minimalism where interface elements appear as physical garment tags, basting stitches, industrial production stamps, and raw textiles.

- **Brand Personality:** Hermetic, subversive, archival, and uncompromisingly precise.
- **Target Audience:** Creative directors, fashion archivists, avant-garde photographers, and aesthetic purists who demand professional optical utility wrapped in raw conceptual restraint.
- **Emotional Response:** Anonymized luxury, deliberate anti-ostentation, and mechanical tactile focus.
- **Design Movement:** Deconstructivist Brutalism fused with raw industrial utilitarianism. Elements celebrate exposed construction: tacking threads serve as viewfinders, garment care labels display capture telemetry, and raw canvas textures ground the camera controls.

## Colors
The palette is calibrated strictly around raw textiles, chalk markings, and darkroom darkness. Built for an immersive capture environment, the interface is predominantly dark mode to eliminate light bleed around the viewfinder while elevating stark chalk accents.

- **Primary (`#F8F7F4` - Raw Calico / Bleached Ecru):** Applied to active indicators, mode selectors, telemetry readouts, and tactile surfaces.
- **Secondary (`#FFFFFF` - Stark Chalk White):** Reserved for focal points, basting stitch reticles, active shutter surfaces, and circled matrix indicators.
- **Tertiary (`#71717A` - Muted Zinc):** Secondary technical readouts, grid lines, passive guides, and inactive numerical codes.
- **Neutral (`#0A0A0A` - Deep Void Black):** The infinite canvas background, optical masks, and negative viewport borders.
- **Supporting Neutral (`#1F1F1F` - Washed Slate Charcoal):** Grounding surfaces, care-tag label containers, exposed seams, and textured mechanical dials.

## Typography
Typographic execution combines monospaced typewriter precision (`Space Mono`) with Swiss neo-grotesque discipline (`Geist`). All interface readouts simulate the printed stamps of garment tags, serial numbers, and darkroom exposure sheets.

- **Telemetric Readouts & Mode Indicators (`Space Mono`):** Used for shutter speed, aperture, ISO, and aspect ratio markers. Numerals are monospaced to prevent layout jitter during dynamic optical re-evaluations.
- **Labels & Care-Tag Metadata (`Geist`):** Set strictly in uppercase with wide tracking (`letterSpacing: 0.15em` to `0.18em`), mimicking textile production labels and fabric composition placards.
- **Hierarchy Rules:** Large numbers are prioritized only for active lens apertures or exposure compensations; surrounding labels maintain a quiet, microscopic presence (`label-sm`).

## Layout & Spacing
The layout adheres to a fixed-viewport paradigm aligned strictly to the physical hardware geometry of iOS devices, anchored by native safe areas.

- **Viewfinder & Masking:** The central optical area adapts to aspect ratios (1:1, 4:3, 16:9). Masked margins are blocked out in flat `#0A0A0A`, converting unused display space into utility ledges.
- **Vertical Tool Rails:** Top and bottom toolbars operate on an 8pt architectural rhythm, holding fixed margins (`margin-safe`) from the dynamic island and home indicator.
- **Information Distribution:** Critical optical metadata (EV, ISO, focal length) sits directly along the viewfinder boundary lines with minimal padding (`space-xs`), anchoring typography flush against screen edges.

## Elevation & Depth
Depth is created through tangible, tactile layering rather than synthetic software blurs or ambient dropshadows.

- **Flat Tonal Planes:** The interface rejects blur-based glassmorphism in favor of high-contrast opacity layering. Darkroom controls rest on solid `#1F1F1F` or translucent calibrated `#0A0A0A` tints (`alpha 0.85`).
- **Low-Contrast Seams & Ghost Outlines:** Borders are razor-thin (1px hairline) in `#71717A` at 30% opacity, evoking basting guides or tailor's chalk lines.
- **Negative Inset Depth:** Control surfaces (e.g., exposure dials, thumb recesses) use subtle inner strokes or reversed color-blocks to communicate physical mechanical depressing without simulated volumetric lighting.
- **Textile Grain:** Album previews and modal bottom sheets utilize an ultra-fine structural noise overlay representing raw bleached canvas (linen grain).

## Shapes
In tribute to raw pattern cuts, sample swatches, and industrial textile punches, the shape language is strictly **Sharp (Level 0)** for structural and framing elements, punctuated solely by perfect geometric circles for functional mechanical controls.

- **Containers & Framing:** Sharp, unrounded 90-degree corners. Basting stitches, viewfinder brackets, and care tags retain exact right angles.
- **Functional Exceptions (Mechanical Elements):** Shutter buttons, numerical mode matrix rings, and lens toggles use full 360-degree circular punch-outs, evoking clothing snaps, fabric rivets, and lens barrels.
- **Deconstructed Framing:** Framing indicators simulate rough-cut textile tags with notch cutouts or incomplete perimeter strokes.

## Components

### Viewfinder & 4-Stitch Focus Reticle
- **Autofocus Indicator:** A central box formed by four unattached white basting stitches (`#FFFFFF`, 2px stroke, 6px length) at the four corners. On touch focus, the stitches clamp inward with a crisp linear snap, accompanied by a subtle tactile haptic.
- **Framing Brackets:** Aspect ratio indicators (1:1, 4:3, 16:9) appear as hairline chalk dashes along the perimeter edges, labeled with monospaced metadata (`4:3 ARTISANAL`).

### Shutter Button
- **Structure:** A 72px dual-ring mechanical trigger. The outer ring is a 1.5px hairline in `#F8F7F4`. The inner disc is separated by a 4px void gap, rendered in `#FFFFFF` with a micro-groove tactile texture.
- **Interaction State:** When depressed, the inner disc expands flush to fill the gap while the outer ring collapses, triggering an immediate rigid haptic pop.

### Numbered Matrix Mode Carousel (0–23)
- **Visual Display:** Inspired by the iconic Maison Margiela numeric classification tag. A horizontal scroll of integers where active shooting modes correspond to archival categories:
  - `0`: Artisanal (Raw uncompressed RAW / manual shutter control)
  - `3`: Fragrance (Soft-focus diffusion / mist simulation)
  - `10`: Men’s (High-contrast monochrome / harsh grain)
  - `11`: Accessories (Macro / telephoto optical lock)
  - `14`: Replica (Archival film stock profiles)
  - `22`: Footwear (High-speed motion freeze)
- **Active State:** The active mode number is circumscribed by a hand-drawn-style, high-contrast white circle (`#FFFFFF`), while inactive numbers are muted zinc (`#71717A`).

### Exposure & Shutter Speed Scrubbers
- **Layout:** Positioned vertically alongside the right edge or as a calibrated arc around the shutter.
- **Indicator:** An austere single-pixel hairline scale with small hash marks every 1/3 stop. Current values appear as stamped monospaced text (`1/250s`, `f/1.8`, `ISO 64`) with absolute left-alignment.

### Care-Tag Album Preview
- **Presentation:** Located at the bottom left, the recent capture thumbnail is enclosed within a square calico patch (`#F8F7F4`), pinned by a single simulated diagonal corner thread.
- **Metadata Tag:** Tapping expands an archival modal resembling an internal garment care label: listing white balance, focal millimeter, time stamp, and location coordinates formatted like washing instructions (e.g., `100% OPTICAL GLASS / DRY EXPOSURE ONLY / MADE IN JPN`).