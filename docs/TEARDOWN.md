# TEARDOWN — the grammar spec pikicam's UX is built against

Provenance, honestly: the ideal method is operating both apps by hand on
this device and transcribing. A headless agent cannot drive the system
Camera or an App Store dialect (no UI automation of foreign apps, no
account to install Halide/Blackmagic). These inventories are compiled
from the authority the codebase already ranks: the AVCam sample (the
capture-graph grammar), Apple Camera's stable, documented interaction
set, and Blackmagic Camera's published manual. Every row is marked for
the owner to confirm or correct by hand during the walk — five minutes
with each app amends this file, and the amendment wins over the table.

## Table 1 — Apple Camera (the grammar baseline)

| Control | Placement | Gesture | Effect |
|---|---|---|---|
| Mode strip | bottom, above dock | horizontal swipe / tap | switches capture mode |
| Shutter | bottom center | tap (photo); tap-start/tap-stop (video) | executes the verb |
| Camera flip | bottom right | tap | front/back toggle |
| Last capture thumb | bottom left | tap (Photos); swipe up (last shot) | review path |
| Flash / Live / etc | top row | tap | toggles; state icon lit |
| Hidden manual drawer | top chevron | tap | expands timer, ratio, exposure |
| Focus + meter | anywhere in feed | tap | focus+meter at point |
| Exposure bias | vertical on feed | swipe up/down after tap | EV compensation |
| Zoom | feed | pinch / tap .5/1/2 | optical/digital factor |
| AE/AF lock | feed | long-press | locks until tap |
| Volume buttons | hardware | press | secondary shutter |

Grammar read: ONE primary verb control dead center; mode is a strip the
thumb swipes; review is the corner opposite the flip; manual controls
are HIDDEN behind a chevron (progressive disclosure); every toggle is
iconic with lit/unlit state.

## Table 2 — pro dialect (Blackmagic Camera; Halide converges)

| Control | Placement | Gesture | Effect |
|---|---|---|---|
| Status readouts | top bar, always on | read | fps, codec, ISO, shutter, WB as TEXT |
| Record | right side / bottom right | tap start / tap stop | timecode-visible run |
| Manual controls | wheels / side panel | tap+drag per control | ISO/shutter/WB explicit values |
| Histogram/peaking | feed overlay | toggle in settings | exposure evidence |
| Media | dedicated button | tap | clip/photo browser |
| Settings | sidebar | tap | deep configuration |
| Tap-to-focus | feed | tap | focus box + readout |

Grammar read: readouts are ALWAYS-ON TEXT (values, not icons); the
record control is asymmetric from photo; manual values are visible
without opening anything. This is the broadcast-panel lineage pikicam's
brutalist text states already speak.

## pikicam MODE × STATE grid (what each control does in every state)

| State | Shutter | Mode strip | BNW chip | Archive btn | Readout |
|---|---|---|---|---|---|
| PHOTO idle | capture | PHOTO/VIDEO | BNW OFF/ON | opens archive | N SAVED |
| PHOTO capturing | disabled (in-flight guard) | live | live | opens archive | N SAVED |
| PHOTO saving | live | live | live | opens archive | N SAVED (+1 on done) |
| PHOTO photos-denied | capture still works | live | live | opens archive | DENIAL BANNER + OPEN SETTINGS |
| VIDEO idle | start record | live | live (applies to clip look) | opens archive | N SAVED |
| VIDEO recording | stop (square mark) | live (switching stops? no — locked) | live (mid-clip change recorded for parity later; v1 keeps entry state) | live | REC M:SS inverted |
| VIDEO post-stop export | disabled until file ready | live | live | opens archive | SAVING CLIP |
| camera denied (launch) | — | — | — | — | DENIED + OPEN SETTINGS |

Adopted from the baseline: center verb control; corner review path;
tap-to-focus stays (free from engine). Rejected from the baseline: icon
toggles, hidden chevron drawer (we have nothing to hide — three verbs),
pinch zoom (photo framing is the walk's, not ours to re-add), volume
shutter (nice-to-have, no walk step). Adopted from the pro dialect:
always-on text readouts, asymmetric record control, REC timecode.

## Screen rationales (one line each — the layout source)

- CAMERA: "Broadcast panel: the feed is the hero; a top status line and
  a bottom control plate, both pure labels, everything else is the
  sensor."
- ARCHIVE: "Contact sheet: a uniform grid of captures under one rule
  line, listing only what this app made."
- VIEWER: "One capture at a time, full-bleed; BACK is the only chrome;
  video plays where it lies."

## Anti-pattern table (what each reference gets wrong that pikicam refuses)

| Reference | Anti-pattern inherited risk | pikicam refusal |
|---|---|---|
| Apple Camera | Icon toggles with state carried by lit/unlit color | States are TEXT, uppercase — greyscale-safe by construction |
| Apple Camera | Mode strip is a swipe surface (invisible affordance) | Mode is explicit chips, one tap, no hidden gestures |
| Apple Camera | Decorative blur/translucent chrome | Opaque black plates; nothing behind text |
| Pro dialect (Blackmagic/Halide) | Sprawling manual panels (ISO/shutter/WB wheels always exposed) | Three verbs only; no manual sprawl exists to expose |
| Pro dialect | Recording as a red-dot icon with tiny timecode | REC M:SS is an inverted text plate, arm's-length legible |
| Both | Grid/gallery content mixed into the capture screen | Archive is a separate sheet; the feed is never cluttered |
| Both | Color carries state (red = record, yellow = AE lock) | One grey rule line + text; color never means anything |

## Owner hand-check (fill during the walk)

- [ ] Apple Camera table matches what your hands find (amend rows).
- [ ] Blackmagic/Halide table matches (amend rows).
- [ ] Each screen's layout matches its one-line rationale.
