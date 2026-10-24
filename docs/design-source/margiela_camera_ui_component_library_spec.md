# MAISON MARGIELA NATIVE CAMERA (MM-NC/01)
## COMPONENT LIBRARY ARCHITECTURE & SPECIFICATION CATALOGUE
**Catalogue ID:** `COMP-MM-NC-2025-V1`  
**Atelier:** Software Division & Optical Laboratory, Paris 11ᵉ  
**Design System Anchor:** `Artisanal Vision`  
**Framework Parity:** HTML/Tailwind CSS, React/TSX, SwiftUI (`AVFoundation`)

---

## 1. VIEWFINDER & OPTICAL OVERLAYS

### 1.1 The Four Basting Tacks Reticle (`<BastingStitchReticle />`)
Frames subjects using Margiela's exterior white garment tacks (*les quatre points blancs*).

* **Anatomy**:
  - 4 corner brackets: horizontal leg `20px`, vertical anchor return `6px`, stroke `1.75px #FFFFFF`.
  - Corner margin: `28px` inset from active subject bounds.
  - Classification Tag: centered above top stitch bar, monospaced uppercase in `8.5px` (`(0) SILHOUETTE · ARTISANAL`).
  - EV Compensation Detent: integrated vertical slider pinned to right axis (`-2.0` to `+2.0 EV`, `0.1` step).
  - Horizon Gyro Indicator: `4px` pip with degree readout (`● 0.0°`).

```tsx
// React / Tailwind Implementation
export const BastingStitchReticle = ({ label = "(0) SILHOUETTE · ARTISANAL", ev = "+0.3", angle = "0.0°" }) => (
  <div className="relative w-72 h-96 border border-transparent select-none">
    {/* Top Left */}
    <div className="absolute top-0 left-0 w-5 h-1.5 border-t-[1.75px] border-l-[1.75px] border-white" />
    {/* Top Right */}
    <div className="absolute top-0 right-0 w-5 h-1.5 border-t-[1.75px] border-r-[1.75px] border-white" />
    {/* Bottom Left */}
    <div className="absolute bottom-0 left-0 w-5 h-1.5 border-b-[1.75px] border-l-[1.75px] border-white" />
    {/* Bottom Right */}
    <div className="absolute bottom-0 right-0 w-5 h-1.5 border-b-[1.75px] border-r-[1.75px] border-white" />
    
    {/* Archival Classification Stamp */}
    <div className="absolute -top-3.5 left-1/2 -translate-x-1/2 bg-[#080808] px-2 py-0.5 border border-[#262524] text-[8.5px] font-mono tracking-[0.18em] text-white uppercase whitespace-nowrap">
      {label}
    </div>

    {/* Center Horizon Pips */}
    <div className="absolute inset-0 flex items-center justify-center">
      <div className="w-1.5 h-1.5 rounded-full bg-white/40" />
      <span className="absolute mt-6 text-[8px] font-mono tracking-widest text-[#D6D3CB] bg-[#080808]/80 px-1 border border-[#262524]">
        ● {angle}
      </span>
    </div>

    {/* Integrated EV Scrub Scale */}
    <div className="absolute -right-7 top-1/2 -translate-y-1/2 flex flex-col items-center gap-1.5 py-2 px-1 bg-[#080808]/90 border border-[#262524]">
      <span className="text-[7.5px] text-[#D6D3CB]">☼</span>
      <div className="w-[1.5px] h-14 bg-[#262524] relative">
        <div className="absolute top-3 left-1/2 -translate-x-1/2 w-2 h-2 rounded-full bg-white" />
      </div>
      <span className="text-[7px] font-mono text-white">{ev}</span>
    </div>
  </div>
);
```

---

## 2. TELEMETRY & CARE-TAG SPECIMENS

### 2.1 Archival Care-Label Telemetry Band (`<CareLabelStrip />`)
Translates camera EXIF/exposure status into Margiela's iconic inner garment composition tag.

* **Anatomy**:
  - Container: unrounded square borders (`border: 1px solid #262524`), background `#141312`.
  - Header Row: Model ID (`MODÈLE: S50AM0510`) + Workshop stamp (`OPTICAL LAB PARIS 11e`).
  - Specimen Row: Capture medium (`TISSU: 100% VISUAL SPECTRUM / DRY EXPOSURE [AUTONOMOUS]`).
  - EXIF Parameter Bracket: `[24MM] · 48MP PRO-RAW · F/1.78 · 1/250s · ISO 64 · 5500K · REC.2020`.

```tsx
export const CareLabelStrip = ({ 
  focal = "24MM", 
  res = "48MP PRO-RAW", 
  aperture = "F/1.78", 
  shutter = "1/250s", 
  iso = "ISO 64", 
  kelvin = "5500K" 
}) => (
  <div className="w-full bg-[#141312] border-t border-b border-[#262524] p-2.5 font-mono text-[9px] uppercase tracking-[0.14em]">
    <div className="flex justify-between text-[#888681] text-[8px] mb-1">
      <span>MODÈLE: S50AM0510</span>
      <span>OPTICAL LAB PARIS 11ᵉ</span>
    </div>
    <div className="text-[#D6D3CB] text-[8.5px] mb-1.5">
      TISSU: 100% VISUAL SPECTRUM / DRY EXPOSURE &nbsp;[AUTONOMOUS CAPTURE]
    </div>
    <div className="flex flex-wrap items-center gap-1.5 text-white font-bold text-[9px] tracking-wider pt-1 border-t border-[#262524]">
      <span className="text-[#F4F3EF]">[{focal}]</span>
      <span className="text-[#888681]">·</span>
      <span>{res}</span>
      <span className="text-[#888681]">·</span>
      <span>{aperture}</span>
      <span className="text-[#888681]">·</span>
      <span>{shutter}</span>
      <span className="text-[#888681]">·</span>
      <span>{iso}</span>
      <span className="text-[#888681]">·</span>
      <span className="text-[#D6D3CB]">{kelvin}</span>
    </div>
  </div>
);
```

---

## 3. MODE & FILTER ENGINES

### 3.1 The 0–23 Numeric Line Matrix Selector (`<NumericLineMatrix />`)
Replaces conventional photo filters with Maison Margiela’s numerical line classification taxonomy.

* **Lines**:
  - `( 0 )` Artisanal / Raw DNG tone curve
  - `1` Collection Femme / Desaturated skin contrast
  - `3` Fragrance / Atmospheric grain & halation
  - `4` Garde-Robe / Balanced daylight standard
  - `10` Homme / Micro-contrast & sharp carbon shadows
  - `11` Accessoires / Macro lens locking & edge depth
  - `14` Vestiaire Fundamentals / High-contrast Ilford HP5 monochrome
  - `22` Chaussures / Tabi low-angle horizon gyro
* **Interaction**:
  - Circling style: hand-stamped unantialiased circular border (`1.5px solid #FFFFFF`, diameter `28px`).
  - Active transition: 0ms instantaneous mechanical snap.

```tsx
export const NumericLineMatrix = ({ activeLine = 0, onSelect = (line: number) => {} }) => {
  const lines = [0, 1, 3, 4, 10, 11, 14, 22];
  return (
    <div className="w-full bg-[#080808] px-3 py-2 border-b border-[#262524] select-none font-mono">
      <div className="flex justify-between items-center text-[7.5px] text-[#888681] tracking-[0.2em] mb-2 uppercase">
        <span>NUMERIC DESIGNATION</span>
        <span>[COLLECTION SS25]</span>
      </div>
      <div className="flex items-center justify-between gap-1 overflow-x-auto no-scrollbar py-1">
        {lines.map((num) => {
          const isActive = num === activeLine;
          return (
            <button
              key={num}
              onClick={() => onSelect(num)}
              className={`w-7 h-7 flex items-center justify-center text-[12px] font-mono tracking-widest transition-none cursor-pointer ${
                isActive 
                  ? 'border-[1.5px] border-white rounded-full text-white font-bold bg-[#141312]' 
                  : 'text-[#888681] hover:text-[#D6D3CB]'
              }`}
            >
              {num}
            </button>
          );
        })}
      </div>
    </div>
  );
};
```

---

## 4. CALIBRATION & HARDWARE ACTUATORS

### 4.1 Tactile Calibration Milled Scrub Bar (`<TactileCalibrationDial />`)
A precision-milled physical ruler simulation for shutter, aperture, and ISO micro-stepping.

* **Anatomy**:
  - 21 discrete tick marks (major at 5-interval, minor at 1-interval).
  - High-intensity central cursor (`2px × 18px` solid white `#FFFFFF`).
  - Header: label with current calibrated value readout (`1/250s · f/1.8`).

```tsx
export const TactileCalibrationDial = ({ valueReadout = "1/250s · f/1.8" }) => (
  <div className="w-full bg-[#141312] border border-[#262524] p-3 font-mono">
    <div className="flex justify-between items-center text-[8.5px] uppercase tracking-widest text-[#D6D3CB] mb-2.5">
      <span className="flex items-center gap-1.5 text-white">
        <span className="w-2.5 h-2.5 border border-[#888681] flex items-center justify-center text-[6px]">⚙</span>
        MANUAL TACTILE CALIBRATION
      </span>
      <span className="text-white font-bold">{valueReadout}</span>
    </div>
    
    {/* Milled Ruler Track */}
    <div className="relative h-6 flex items-center justify-between px-2 bg-[#0e0e0e] border border-[#262524]">
      {Array.from({ length: 19 }).map((_, i) => (
        <div 
          key={i} 
          className={`w-[1px] ${i % 3 === 0 ? 'h-3.5 bg-[#888681]' : 'h-1.5 bg-[#262524]'}`} 
        />
      ))}
      {/* Central Illuminated Needle */}
      <div className="absolute left-1/2 -translate-x-1/2 w-[2px] h-5 bg-white shadow-[0_0_4px_rgba(255,255,255,0.6)]" />
    </div>
  </div>
);
```

### 4.2 Raw Emulsion Toggle Cards (`<EmulsionToggleCard />`)
Binary mechanical micro-switches for tactile camera processing parameters.

```tsx
export const EmulsionToggleCard = ({ 
  number = "N° 01", 
  title = "CALICO RAW GRAIN", 
  meta = "+1.2 EV", 
  active = true 
}) => (
  <div className="flex-1 bg-[#141312] border border-[#262524] p-2.5 font-mono select-none">
    <div className="flex justify-between items-center text-[7.5px] text-[#888681] tracking-[0.16em] mb-1">
      <span>{number} / {title}</span>
      <span className={`w-2 h-2 rounded-full ${active ? 'bg-white' : 'border border-[#888681]'}`} />
    </div>
    <div className="text-[8.5px] text-white tracking-widest uppercase mb-2">
      {meta}
    </div>
    <div className="w-full h-1 bg-[#262524] relative">
      <div className={`h-full bg-white transition-none ${active ? 'w-3/4' : 'w-1/4'}`} />
    </div>
  </div>
);
```

---

## 5. SHUTTER & ARCHIVE CONSOLE

### 5.1 The Blank Gesso Shutter Button (`<GessoShutterActuator />`)
An unbranded, solid white disc embodying Margiela’s blank white gesso canvas with zero digital branding.

* **States**:
  - Rest: Outer ring diameter `72px`, stroke `1.5px #888681`, inner disc `60px #FFFFFF`.
  - Half-Press: Inner disc shifts to `#F4F3EF`, haptic tension hum.
  - Full Trip: Scale `0.94` instantaneous (0ms transition duration), simulated wet gesso mirror slap.

```tsx
export const GessoShutterActuator = ({ onRelease = () => {} }) => (
  <div className="flex items-center justify-between w-full max-w-[340px] px-4 font-mono select-none">
    {/* Archive Roll Specimen Thumbnail */}
    <button className="w-11 h-11 border border-[#888681] p-0.5 bg-[#141312] relative group">
      <div className="w-full h-full bg-[#262524] flex items-center justify-center text-[8px] text-[#D6D3CB]">
        #0084
      </div>
      {/* 4 Corner Tack Marks on Archive Thumbnail */}
      <div className="absolute top-0.5 left-0.5 w-1 h-0.5 bg-white" />
      <div className="absolute top-0.5 right-0.5 w-1 h-0.5 bg-white" />
      <div className="absolute bottom-0.5 left-0.5 w-1 h-0.5 bg-white" />
      <div className="absolute bottom-0.5 right-0.5 w-1 h-0.5 bg-white" />
    </button>

    {/* Primary Shutter Actuator */}
    <button 
      onClick={onRelease}
      className="w-[72px] h-[72px] rounded-full border-[1.5px] border-[#888681] p-1 flex items-center justify-center bg-transparent active:scale-95 transition-none cursor-pointer"
      aria-label="Actuate Shutter"
    >
      <div className="w-full h-full rounded-full bg-white active:bg-[#F4F3EF]" />
    </button>

    {/* Optical Turret / Reversal Action */}
    <button className="w-11 h-11 border border-[#262524] flex flex-col items-center justify-center bg-[#141312] text-[#D6D3CB] hover:border-white transition-none">
      <span className="text-[12px]">⟲</span>
      <span className="text-[6.5px] tracking-widest text-[#888681] mt-0.5">REV</span>
    </button>
  </div>
);
```

### 5.2 Archive Roll Deck Summary Card (`<ArchiveRollSummary />`)
A fabric-swatch preview tile for captured rolls and DNG files.

```tsx
export const ArchiveRollSummary = ({ rollId = "#0084", location = "PARIS 11e ARR", size = "14.8 MB", ext = "DNG" }) => (
  <div className="w-full bg-[#141312] border border-[#262524] p-3 flex items-center justify-between font-mono">
    <div className="flex items-center gap-3">
      <div className="w-10 h-10 bg-[#080808] border border-[#888681] p-1 flex flex-col justify-between text-[7px] text-[#888681]">
        <span>MM</span>
        <span className="text-white font-bold">{rollId}</span>
      </div>
      <div>
        <div className="text-[10px] text-white font-bold tracking-[0.16em] uppercase">
          ARCHIVE ROLL {rollId}
        </div>
        <div className="text-[8px] text-[#888681] tracking-widest uppercase">
          {location} · {size} · {ext}
        </div>
      </div>
    </div>
    <button className="border border-[#262524] hover:border-white text-white px-2.5 py-1 text-[8px] tracking-[0.18em] uppercase transition-none">
      INSPECT ↗
    </button>
  </div>
);
```

---

## 6. LENS TURRET & FOCAL SELECTOR

### 6.1 Mechanical Turret Focal Stepper (`<TurretFocalSelector />`)
Discrete mechanical lens selector mimicking turret cameras (13mm, 24mm, 48mm, 77mm).

```tsx
export const TurretFocalSelector = ({ activeFocal = "24mm", onSelect = (f: string) => {} }) => {
  const steps = [
    { label: ".5", focal: "13mm" },
    { label: "1x", focal: "24mm" },
    { label: "2", focal: "48mm" },
    { label: "3", focal: "77mm" }
  ];
  return (
    <div className="inline-flex items-center bg-[#080808]/90 border border-[#262524] p-1 gap-1.5 font-mono select-none">
      {steps.map((step) => {
        const isActive = step.focal === activeFocal;
        return (
          <button
            key={step.focal}
            onClick={() => onSelect(step.focal)}
            className={`px-2 py-1 flex flex-col items-center transition-none cursor-pointer ${
              isActive ? 'bg-[#262524] text-white' : 'text-[#888681] hover:text-[#D6D3CB]'
            }`}
          >
            <span className="text-[9px] font-bold">{step.label}</span>
            <span className="text-[7px] tracking-tight text-[#888681]">{step.focal}</span>
          </button>
        );
      })}
    </div>
  );
};
```

---

## 7. SYSTEM COMPONENT INVENTORY SUMMARY

| Component Primitive | Semiotic Function | Primary Tokens Used |
| :--- | :--- | :--- |
| `BastingStitchReticle` | Margiela 4-point tack autofocus & classification | `--mm-color-gesso-pure`, `--mm-type-nano-size` |
| `CareLabelStrip` | Garment care-tag optical telemetry & EXIF readout | `--mm-color-carbon-matrix`, `--mm-color-bleached-muslin` |
| `NumericLineMatrix` | 0–23 Collection numerical filter & pipeline engine | `--mm-color-photometric-low`, `--mm-type-display-size` |
| `TactileCalibrationDial` | Milled knurled metal mechanical parameter scrub bar | `--mm-color-raw-calico`, `--mm-color-carbon-matrix` |
| `EmulsionToggleCard` | Binary mechanical toggle cards for texture/edge passes | `--mm-color-thread-ash`, `--mm-color-photometric-low` |
| `GessoShutterActuator` | Blank white gesso release disc with zero digital branding | `--mm-color-gesso-pure`, `--mm-color-thread-ash` |
| `ArchiveRollSummary` | Archival cotton-swatch specimen review & catalog deck | `--mm-color-carbon-matrix`, `--mm-type-micro-size` |
| `TurretFocalSelector` | Cinéma vérité turret lens switching with carbon blanking | `--mm-color-photometric-deep`, `--mm-type-telemetry-size` |

*Design tokens and components calibrated for production handoff to iOS AVFoundation / SwiftUI or React web camera shells.*