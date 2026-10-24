# Design token extraction — Phase 0 (v2 §16 Phase 0)

Source of truth for extraction: `docs/design-source/maison_margiela_camera_ui_design_system_spec.md`
(the export's Tailwind/Material-You config in `code.html` is the **rejected** parallel
token system — see v2 §13 standing verdicts).

## The seven palette values (MM palette)

| Token | Name | Hex | OKLCH | Role in the spec |
|---|---|---|---|---|
| gesso.pure | Gesso Pure (100 Blanc) | `#FFFFFF` | `oklch(1.000 0.000 0.0)` | Viewfinder basting reticle, active line circling, shutter surface, peak highlights |
| ink.muslin | Bleached Muslin | `#F4F3EF` | `oklch(0.962 0.005 85.0)` | Primary monospaced telemetry text, active exposure readings, care-label typography |
| ink.calico | Raw Calico (Toile Crue) | `#D6D3CB` | `oklch(0.852 0.009 82.5)` | Secondary telemetry, inactive numeric line glyphs, grid rules, ticks |
| ink.ash | Thread Ash (Cendre) | `#888681` | `oklch(0.605 0.006 78.0)` | Care-label subheaders, metadata brackets, muted disabled states, tertiary borders |
| plate.carbon | Carbon Strike Ink | `#262524` | `oklch(0.245 0.004 65.0)` | Container borders, inset calibration tracks, divider rules, secondary pills |
| plate.photometricLow | Photometric Low-Bed | `#141312` | `oklch(0.165 0.003 55.0)` | Header chrome, control console tray, active lens pill background |
| plate.photometricDeep | Photometric Black | `#080808` | `oklch(0.105 0.001 40.0)` | Root canvas, sensor letterbox frames, blackout shutter curtain |

Nothing else in `pikicam/` may name a raw colour (v2 §14).

## Type roles (from the export config)

| Role | Size | Line height | Tracking | Weight | Face |
|---|---|---|---|---|---|
| display | 18 px (mobile-reconciled from 32/26 px headline-lg) | +4 | -0.03 em | 700 | Space Mono |
| title | 13 px (from 20 px headline-md) | +4 | -0.02 em | 700 | Space Mono |
| readout | 11 px (label-md) | +3 | 0.08 em | 400 | Space Mono |
| label | 10 px (label-sm, +1 pt floor) | +3 | 0.18 em | 400 | Space Mono |
| micro | 9 px | +3 | 0.18 em | 400 | Space Mono |

Reconciliation to the 9/10 pt floors and 18/13/11/10/9 roles happens in
`pikicam/DesignSystem/Tokens.swift` (v2 §13). Geist is rejected; Space Mono
(OFL, committed at `pikicam/DesignSystem/Fonts/`) is the single brand face.

## Spacing (U-grid)

{4, 8, 16, 24, 32} pt + hairline; export values (`space-xs` 4 … `space-xl` 24,
`margin` 32-equivalent) map onto the same grid. Radius 0 except brand circles.

## References (renders)

- `references/component-system.png` — component-system export render
- `references/native-camera.png` — native-camera export render

These anchor Phase 5's `scripts/design-diff.py` parity baseline (viewfinder masked).

## Rejected from the export (recorded per v2 §13)

- Material-You colour system (`secondary-container`, `error-container`, …) — parallel
  token system; superseded by the seven MM values above.
- Geist font family — rejected; Space Mono only.
- Material Symbols icons — rejected; SF Symbols only.
- Backdrop blur chrome (`backdrop-blur-xl`) — texture overlays are chrome-only and
  must not sit under measured contrast pairs.
