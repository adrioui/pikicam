# SKIN — the brutalist chrome of pikicam

The entire design is one paragraph of plain prose: a black screen whose
only hero is the camera feed, labelled entirely in uppercase system
monospace at four sizes, separated by 1px grey hairlines, with instant
state changes carried by text — nothing else. If any screen needs a
picture to explain it, it is wrong.

## The token table (the whole design)

| Token | Value |
|---|---|
| Type | System monospace, regular weight |
| Scale | 34 / 17 / 13 / 11 pt — nothing between |
| Color | Pure black, pure white, mid-grey (rules only) |
| Shape | Radius 0 everywhere |
| Motion | 0 ms — no springs, no crossfades |
| Rules | 1px hairlines, grey; fills behind text only pure black/white |
| Targets | >= 44pt hit areas; visible marks may be smaller |
| States | Recording / denied / saving / error are TEXT, uppercase |

Enforced by `pikicamTests/SkinTests.swift` (greps + WCAG arithmetic), run
in `scripts/verify.sh`. A stray hex, raw font size, corner radius, or
animation modifier anywhere under `pikicam/` fails the build.

## Tone lock (PANEL CLAIM OPEN — measured by nobody)

No colorimeter exists for this device. The tone definition therefore
LOCKS to P3 D65 with the transfer math transcribed from the governing
specs: SMPTE RP 431-2 defines the P3 primaries (0.680/0.320,
0.265/0.690, 0.150/0.060) and D65 white; IEC 61966-2-1 defines the sRGB
transfer function Apple's display pipeline renders through. The panel
claim — that emitted grey values match prediction within some ΔE — is
OPEN until the owner measures a rendered grey ramp with a colorimeter.
Ramp mode: launch with `-pikicam.panel` and measure the 17-step 0..255
ramp full-screen. Record results here with the instrument's name.

## Deliberate HIG deviations (each with its reason)

1. Navigation bar translucency and blur are overridden with an opaque
   black `UINavigationBarAppearance` — translucency is decoration; the
   archive header is a label on a black plate.
2. Navigation title and BACK are forced to monospaced uppercase via the
   same appearance proxy — HIG prescribes the system serif/sans and a
   chevron; both are typography this app rejects.
3. The record state is an inverted text plate ("REC 0:08"), not a red
   indicator — iOS convention uses red; the table has no fourth color.
   The greyscale test passes by construction.
4. The shutter is a 1px-ruled circle with a solid disc (72pt ring /
   58pt disc). Circles are camera-hardware vocabulary, not corner
   radius; the stop affordance in video mode is a square — shape, not
   color.
5. Sheet presentation keeps its system slide — the transition is
   system-owned and not overridable without private API; listed here as
   accepted, not chosen.
6. `TimelineView` ticks once per second to update the timer readout; a
   clock update is not a state-change animation.
7. The video player's scrubber is a UISlider (system control) restyled
   only by inheritance from the black plate — its track tint is grey;
   building a hairline scrubber from scratch would cost accessibility
   behaviour iOS gives free. Enforced deviation, documented here.

## Layout sources (one-line rationale per screen — from TEARDOWN)

- CAMERA: broadcast panel — feed hero, top status line, bottom control
  plate, all labels.
- ARCHIVE: contact sheet — uniform grid under one rule, only what this
  app made.
- VIEWER: one capture full-bleed — BACK is the only chrome; video plays
  where it lies.

## The greyscale test

Every frame of this app is already black/white/grey; printing any screen
in pure B&W preserves all hierarchy by construction. The camera feed
itself is exempt — it is the subject, not the chrome.

## One-paragraph test

Passed: see the opening paragraph. No image needed.
