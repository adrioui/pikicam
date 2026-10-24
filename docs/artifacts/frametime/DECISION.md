# Frame-time decision table (capture-time CI vs composition)

Provenance: AGENT-MEASURED on the iPhone 12 mini (A14, iOS 26.6.2),
device lying FACE-DOWN in a low-light room, via the in-app
`-pikicam.frametime` mode (65 s, 1080p30 requested, per-frame CI render
timings, PTS-gap drop counting, 5 s thermal samples).

| Run | Frames delivered | Drops | Render p95 | Thermal |
|---|---|---|---|---|
| locked-exposure | 4 / ~1950 expected | 0 flagged | ~21 ms (n=4) | nominal |
| auto-exposure | 1 / ~1950 expected | 0 flagged | 31.6 ms (n=1) | fair |

## Decision

NO VALID sustained-30fps capture-time trace exists: low light starved
frame delivery to near zero, so p95 over >=60 s at 30 fps cannot be
computed from this environment. The mandate's default therefore holds:
**video look ships via AVVideoComposition applying the same CI handler**
(blessed composition path; capture-time CI remains unproven on this
device, not refuted).

## Owner re-run (ratify or flip)

With the phone on a tripod in adequate light, unlock it, launch the app
with `-pikicam.frametime` for 65 s, then pull
`Documents/frametime.json` (devicectl copy) into this directory. If
that trace shows p95 < 33 ms and zero drops, the decision may flip to
capture-time CI; until then composition is the look path.
