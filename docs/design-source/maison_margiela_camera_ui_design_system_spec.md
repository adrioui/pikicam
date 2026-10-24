# MAISON MARGIELA NATIVE CAMERA (MM-NC/01)
## DESIGN SYSTEM SPECIFICATION & ARCHITECTURAL BLUEPRINT
**Document ID:** `SPEC-MM-NC-2025-V1`  
**Classification:** ARCHIVAL INTERFACE SPECIFICATION / NATIVE CAMERA SUBSYSTEM  
**Atelier:** Optical Laboratory & Software Division, Paris 11ᵉ Arrondissement  
**Target Architecture:** Apple iOS (AVFoundation, CoreHaptics, Metal Shading Language, SwiftUI)

---

## 1. PHILOSOPHICAL FOUNDATIONS & DESIGN THESIS

The Maison Margiela Native Camera UI rejects conventional consumer digital photography aesthetics (glossy skeuomorphism, dynamic colorful accents, soft spring physics). Instead, it operationalizes Margiela’s fundamental house philosophies:

1. **L’Anonymat & L’Effacement (Anonymity & Erasure):** The disappearance of standard digital branding. Brand presence is communicated strictly through structural construction (the 4 white basting tacks, raw garment labeling nomenclature, numeric taxonomy).
2. **La Déconstruction & Le Décorticage (Deconstruction & Exposing Structure):** Turning the camera software inside-out. Layout boundaries, optical telemetry matrices, raw register addresses, sensor pipeline stages, and thread-stitch anchor coordinates are operational graphic elements.
3. **Le Bianchetto & La Peinture Écaillée (White Paint & Patina):** Layered monochromatic tonalities—gesso white layered over raw, unbleached textile surfaces that degrade, crack, and show exposure under mechanical friction.
4. **Précision Mécanique (Anti-Elasticity):** Total rejection of organic bouncy easing (`cubic-bezier` rubber-banding). Mechanical state changes operate with instantaneous detent clicks, linear steppers, and dry physical snaps modeled on spring-leaf shutters and needle-eye thread pulls.

---

## 2. DESIGN TOKENS & SYSTEM PRIMITIVES

### 2.1 Monochrome Chromatic Architecture

All colors exist on an uncalibrated optical spectrum between raw textile cotton and dense carbon strike ribbon ink.

| Token Identifier | Display Name | Hex Code | OKLCH Value | Semantic Role & Subsystem Usage |
| :--- | :--- | :--- | :--- | :--- |
| `--mm-color-gesso-pure` | **Gesso Pure (100 Blanc)** | `#FFFFFF` | `oklch(1.000 0.000 0.0)` | Viewfinder basting reticle, active line circling, primary shutter button surface, peak focus assist highlights. |
| `--mm-color-bleached-muslin`| **Bleached Muslin** | `#F4F3EF` | `oklch(0.962 0.005 85.0)` | Primary monospaced telemetry text, active exposure readings, primary care-label typography. |
| `--mm-color-raw-calico` | **Raw Calico (Toile Crue)** | `#D6D3CB` | `oklch(0.852 0.009 82.5)` | Secondary telemetry, inactive numeric line glyphs, grid division rules, tick markings. |
| `--mm-color-thread-ash` | **Thread Ash (Cendre)** | `#888681` | `oklch(0.605 0.006 78.0)` | Care-label subheaders, optical metadata brackets, muted disabled states, tertiary frame borders. |
| `--mm-color-carbon-matrix` | **Carbon Strike Ink** | `#262524` | `oklch(0.245 0.004 65.0)` | Container borders, inset calibration tracks, card divider rules, secondary pill surfaces. |
| `--mm-color-photometric-low`| **Photometric Low-Bed** | `#141312` | `oklch(0.165 0.003 55.0)` | Upper header chrome, bottom control console tray, active lens selector pill background. |
| `--mm-color-photometric-deep`| **Photometric Black** | `#080808` | `oklch(0.105 0.001 40.0)` | Root canvas background, optical sensor letterbox frames, blackout shutter transition curtain. |

---

### 2.2 Typographic System & Monospaced Cadence

Typography is anchored to the mechanical pitch of vintage mid-century manual typewriters (Olympia Splendid 33 / IBM Selectric Pica 10). Variable width fonts are forbidden; every glyph occupies an unyielding, predictable pitch box.

*   **Primary Typeface Family:** `Space Mono` / `Margiela Pica Monospace` (Fallback: `Courier Prime`, `SF Mono`, `monospace`).
*   **Kerning Policy:** Disabled (`font-kerning: none`). Spacing is governed exclusively by character cell stepping and explicit letter-spacing tracking units.
*   **Case Policy:** Strict uppercase (`text-transform: uppercase`) for all telemetry, labels, and metadata. Numbers are tabular lining figures (`font-variant-numeric: tabular-nums`).

```css
/* Typography Token Scale */
:root {
  /* Type Pitch Hierarchy */
  --mm-type-display-size:      18px;
  --mm-type-display-line:      22px;
  --mm-type-display-tracking:  0.18em;  /* Numeric Line Matrix */

  --mm-type-headline-size:     13px;
  --mm-type-headline-line:     16px;
  --mm-type-headline-tracking:  0.14em;  /* Section & Mode Headers */

  --mm-type-telemetry-size:    11px;
  --mm-type-telemetry-line:    14px;
  --mm-type-telemetry-tracking: 0.12em;  /* Exposure & Sensor Values */

  --mm-type-micro-size:        9px;
  --mm-type-micro-line:        12px;
  --mm-type-micro-tracking:    0.16em;  /* Care-Label & Serial Stamps */

  --mm-type-nano-size:         7.5px;
  --mm-type-nano-line:         9px;
  --mm-type-nano-tracking:     0.20em;  /* Optical Lab Coordinate Grids */

  /* Weight Matrix */
  --mm-weight-regular:         400;
  --mm-weight-bold:            700;
}
```

---

### 2.3 Spatial Grid: The Character-Unit & 4pt Care-Label System

The spatial engine rejects fluid percentage padding. It is governed by a **4pt / 8pt tactile baseline grid** locked to character-cell intervals ($W_{char} \times H_{baseline}$):

*   **Base Grid Unit ($U$):** `4px`
*   **Micro Cadence ($1U$):** `4px` (Border offsets, tick mark padding, stitch offset)
*   **Cell Cadence ($2U$):** `8px` (Internal chip padding, telemetry gap intervals)
*   **Standard Gutter ($4U$):** `16px` (Viewfinder margin, care-label horizontal inset)
*   **Structural Section ($6U$):** `24px` (Between optical matrix and tactile slider)
*   **Tray Offset ($8U$):** `32px` (Bottom console tray clearance)

---

## 3. COMPONENT ANATOMY & SEMIOTICS

### 3.1 Viewfinder Reticle: The Four Basting Tacks (*Les Quatre Points Blancs*)

Replacing standard iOS autofocus yellow brackets, the subject is framed by Margiela’s exterior basting tack stitches. In physical garments, these stitches tack the blank white label to the interior while revealing four horizontal/diagonal white threads on the exterior.

```
       [Top-Left Stitch]                      [Top-Right Stitch]
       ───┬────────────────────────────────────────────────┬───
          │                                                │
          │             +-------------------+              │
          │             | (0) SILHOUETTE    |              │
          │             +-------------------+              │
          │                      ·                         │
          │                  [Center]                      │
          │                                                │
       ───┴────────────────────────────────────────────────┴───
       [Bottom-Left Stitch]                [Bottom-Right Stitch]
```

#### Detailed Stitch Geometry:
1. **Stitch Dimensions:**
   *   Length ($L$): `20px` (Horizontal leg)
   *   Drop Return ($D$): `6px` (Vertical structural anchor leg, mimicking needle-entry point)
   *   Stroke Width ($W_s$): `1.75px` (Solid unantialiased `#FFFFFF`)
   *   Corner Inset Clearance: `28px` from active subject bounding box.
2. **Dynamic Behavior & States:**
   *   **Idle / Searching:** Stitches pulsate with an un-eased square-wave rhythm (opacity toggles between `100%` and `35%` at `1.2Hz`).
   *   **Focus Lock / Confirmed:** Immediate snap (0ms latency); stitch stroke brightens to `#FFFFFF` with instantaneous tactile pulse.
   *   **Subject Classification Tag:** Directly above top stitch bracket, monospaced tag displays archival designation: `(0) SILHOUETTE · ARTISANAL`, `(11) MATIÈRE · CUIR`, or `(3) ATMOSPHERE · BRUME`.
   *   **Manual Exposure Detent:** Integrated vertical scrub bar at right boundary of reticle with tick-mark scale (`-2.0 EV` to `+2.0 EV`), step increment `0.1 EV`.

---

### 3.2 The 0–23 Numeric Line Designation System (Filter / Mode Engine)

Margiela categorizes every collection by circled numbers (0 to 23). In the camera UI, this matrix replaces standard consumer camera preset filters.

```
+-------------------------------------------------------------------------+
| NUMERIC DESIGNATION                                    [COLLECTION SS25]|
|                                                                         |
|    ( 0 )    1     3     4    (10)   11    14    22                      |
|   [Artisanal]                 [Mens]                                    |
+-------------------------------------------------------------------------+
```

#### System Mapping:
*   **Line 0:** *Artisanal (Haute Couture)* — Highest optical resolution, raw uncompressed DNG capture, manual tone curve extraction.
*   **Line 1:** *Collection Femme* — Soft architectural contrast, desaturated skin tonal response.
*   **Line 3:** *Fragrance & Atmospheric* — Vaporous grain integration, halation around high-light sources, diffuse aperture roll-off.
*   **Line 4:** *Gard-Robe (Wardrobe)* — Neutral balanced colorimetric accuracy, standard daylight white balance.
*   **Line 10:** *Collection Homme* — Hard structural shadows, sharpened textural grain, high micro-contrast.
*   **Line 11:** *Accessories & Objects* — Macro lens locking, optical depth mapping, extreme edge definition.
*   **Line 14:** *Wardrobe Fundamentals* — High-contrast monochrome black & white (Ilford HP5 Plus emulsion emulation).
*   **Line 22:** *Footwear / Tabi Telemetry* — Low-angle horizon gyroscope lock, ground-plane perspective correction.

#### Graphic Presentation:
*   **Inactive Digits:** Color `#888681`, tracking `0.18em`, font size `14px`.
*   **Active Digit Circling:** Hand-stamped circle representation (`border: 1.5px solid #FFFFFF; border-radius: 9999px; width: 28px; height: 28px; padding: 2px`).
*   **Interaction:** Linear horizontal carousel scroll with single-character snapping; active item locks dead-center.

---

### 3.3 Care-Label Nomenclature & Optical Telemetry Band

Running along the base of the live viewfinder is the **Care-Label Specimen Strip**, formatting capture telemetry exactly as a Margiela garment care and composition tag:

```
+-------------------------------------------------------------------------+
| MODÈLE: S50AM0510                       OPTICAL LAB PARIS 11e           |
| TISSU: 100% VISUAL SPECTRUM / DRY EXPOSURE       [AUTONOMOUS CAPTURE]   |
+-------------------------------------------------------------------------+
| [24MM] · 48MP PRO-RAW · F/1.78 · 1/250s · ISO 64 · 5500K · REC.2020     |
+-------------------------------------------------------------------------+
```

*   **Primary Brackets:** Every numeric value is framed by square typewriter brackets `[ ... ]`.
*   **Optical Formula:** Telemetry displays true focal length (`13mm`, `24mm`, `48mm`, `77mm`), current f-stop, mechanical shutter duration in fractions of seconds (`1/8000s` to `1s`), ISO sensitivity, and Kelvin temperature.
*   **Border Separation:** Border lines are `1px solid #262524` with zero rounded corners (`border-radius: 0px`).

---

### 3.4 Tactile Calibration Dial & Archival Roll Inspection

1. **Manual Tactile Calibration Scrub Bar:**
   *   Horizontal milled ruler with high/low tick marks at `2px` intervals.
   *   Central illuminated white cursor indicator (`2px` width, `18px` height).
   *   Scrubbing updates real-time shutter and aperture calibration with haptic detent feedback.
2. **Raw Emulsion Toggle Cards:**
   *   Modular split-cards: `N° 01 / CALICO RAW GRAIN` and `N° 02 / BASTING EDGE STITCH DETECT`.
   *   Contain discrete mechanical slide switches that click between binary positions (0 / 1) with no intermediate tweening.
3. **Archive Roll Deck (#0084):**
   *   Thumbnail framed as an unwashed cotton patch with raw fraying thread edges.
   *   Displays archival catalog record: `PARIS 11e ARR · 14.8 MB · DNG`.
   *   CTA action: `INSPECT ↗` in micro-type `10px`.

---

### 3.5 Shutter Actuator: The Blank Gesso Disc

The primary shutter button is an unbranded, solid white disc representing Margiela's blank white gesso canvas:

*   **Outer Retaining Ring:** `72px` diameter, `1.5px` border `#888681`, `4px` padding.
*   **Inner Actuation Disc:** `60px` diameter, solid fill `#FFFFFF`.
*   **Pressed State:** Scale down to `0.94` with instantaneous snap (0ms transition duration), fill shifts to `#F4F3EF`.
*   **Flanking Controls:**
    *   Left: Film Roll Archive Icon (`22px` square frame with stitched corners).
    *   Right: Camera Inversion / Lens Reversal (`22px` mechanical lens-swap glyph).

---

## 4. MATERIALITY, SHADERS & INTERACTION DYNAMICS

### 4.1 Physicality & Material Treatments

1. **Calico Alpha Texture Overlay (CSS / Metal Shading):**
   *   A microscopic texture overlay reproducing unbleached cotton weave grain is applied over non-viewfinder panels with `mix-blend-mode: multiply` at `3.5%` opacity.
2. **Bianchetto Shutter Wash:**
   *   When the shutter is actuated, the screen does not flash black or synthetic white.
   *   A single frame of simulated wet gesso white wash (`#FFFFFF` at `95%` opacity) is painted over the frame, immediately clearing in `40ms` to simulate the slap of a physical SLR mirror.
3. **Typewriter Ribbon Strike Imperfection:**
   *   All monospaced glyphs are rendered with a subtle strike-pressure filter (`filter: drop-shadow(0 0 0.25px rgba(255,255,255,0.4))`) preventing sterile vector sharpness and replicating carbon ink transfer.

---

### 4.2 Interaction Mechanics & Haptic Engineering

The system forbids all standard iOS spring-bounce curves (`easeOutElastic`, `spring(damping: 0.7)`). Every interaction is modeled on vintage metal lathe tooling, industrial clickwheels, and mechanical lever trips.

#### Motion Timing Curves:
*   **Mechanical Click (Tab Switch, Mode Toggle):** `transition: transform 0ms, opacity 0ms;` (Zero animation; absolute instantaneous state change).
*   **Drawer Extension (Calibration Dial Reveal):** `cubic-bezier(0.0, 0.0, 0.2, 1.0)` (Linear decrescendo, duration `120ms`).
*   **Viewfinder Focus Snap:** `duration: 60ms; curve: linear;`.

#### CoreHaptics Architecture (.ahap Specification):

```json
{
  "Pattern": [
    {
      "Event": {
        "Time": 0.0,
        "EventType": "HapticTransient",
        "EventParameters": [
          { "ParameterID": "HapticIntensity", "ParameterValue": 0.95 },
          { "ParameterID": "HapticSharpness", "ParameterValue": 0.85 }
        ]
      }
    },
    {
      "Event": {
        "Time": 0.012,
        "EventType": "AudioCustom",
        "EventWaveformPath": "mechanical_leaf_shutter_snap.wav",
        "EventParameters": [
          { "ParameterID": "AudioVolume", "ParameterValue": 0.70 }
        ]
      }
    }
  ]
}
```

*   **Numeric Matrix Scrolling:** Ultra-light, crisp transient pulses (`Intensity: 0.35, Sharpness: 1.0`) on each character tick.
*   **Manual Dial Detent:** Dense, heavy metallic click (`Intensity: 0.8, Sharpness: 0.6`) when passing integer f-stops or optical lens focal transitions (`13mm` $\rightarrow$ `24mm` $\rightarrow$ `48mm` $\rightarrow$ `77mm`).
*   **Shutter Release Actuation:** Dual-stage haptic event: Stage 1 (half-press focus lock: low tension hum), Stage 2 (full trip: high-intensity mechanical leaf snap).

---

### 4.3 Error States, Lens Transitions & Environmental Adaptation

1. **Low-Light / Starvation Telemetry:**
   *   When lux falls below `1.0`, telemetry replaces the standard night mode banner with: `[ EXPOSURE WARNING : SENSOR FLUX LOW · BASTING ASSIST ENGAGED ]`.
   *   Reticle stitch brightness ramps to `100% Gesso Pure` with inverted carbon edge outlines for high contrast against pitch black.
2. **Thermal & Memory Buffer Throttling:**
   *   If raw buffer backlog exceeds 8 frames, the care-label tag replaces model serial with: `TISSU: THERMAL REGISTRATION ACTIVE · WRITE CYCLE RETARDED`.
3. **Lens Switching Transition:**
   *   Zero smooth cross-fading between physical camera sensors (Ultra-Wide, Wide, Telephoto). The interface renders a discrete `1-frame` carbon blanking interval (`#080808` curtain for `16.6ms`), mimicking the physical turret lens rotation of early cinéma vérité cameras.

---

## 5. SWIFTUI COMPONENT SPECIFICATION STUB

For engineering implementation, UI elements must conform to strict design system structures:

```swift
import SwiftUI
import CoreHaptics

public struct MargielaDesignTokens {
    public static let gessoPure = Color(red: 1.0, green: 1.0, blue: 1.0)
    public static let bleachedMuslin = Color(red: 0.96, green: 0.95, blue: 0.94)
    public static let rawCalico = Color(red: 0.84, green: 0.83, blue: 0.80)
    public static let threadAsh = Color(red: 0.53, green: 0.52, blue: 0.51)
    public static let carbonMatrix = Color(red: 0.15, green: 0.14, blue: 0.14)
    public static let photometricDeep = Color(red: 0.03, green: 0.03, blue: 0.03)
    
    public static let typewriterFont = Font.custom("SpaceMono-Regular", size: 11)
    public static let typewriterMicro = Font.custom("SpaceMono-Regular", size: 8.5)
}

public struct BastingStitchReticle: View {
    public let label: String
    public let evCorrection: Double
    
    public var body: some View {
        ZStack {
            // Top Left Stitch
            Path { path in
                path.move(to: CGPoint(x: 0, y: 6))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 20, y: 0))
            }
            .stroke(MargielaDesignTokens.gessoPure, lineWidth: 1.75)
            
            // Reticle Subject Classification Stamp
            Text(label.uppercased())
                .font(MargielaDesignTokens.typewriterMicro)
                .tracking(1.4)
                .foregroundColor(MargielaDesignTokens.gessoPure)
                .padding(.horizontal, 4)
                .background(MargielaDesignTokens.photometricDeep)
                .offset(y: -18)
        }
    }
}
```

---
*Authenticité certifiée. Maison Margiela Software Studio, Paris.*
