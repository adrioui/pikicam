# Parity: status and artifacts

Provenance: the capture mode (`-pikicam.parity`) and the oracle
(scripts/parity.py, band = max(4x run-to-run sigma, honest floor)) are
committed and working on-device.

## Agent provisional pair (DEGENERATE — not evidence)

Captured by the agent with the device FACE-DOWN on a dark desk:
stills-luma mean 0.0009, video-luma mean 0.0000 — both effectively
black; the comparison runs at the noise floor and cannot judge parity.
Files kept out of git (multi-MB, meaningless as evidence).

## Owner controlled pair (the judging instrument)

Tripod, locked AE/AF/WB via the mode, grey card, fixed light:
1. Unlock phone face-up on tripod; `devicectl process launch ... piki.pikicam -- -pikicam.parity -pikicam.dumpclip`
2. Wait ~40 s; pull Documents/parity-still.dng + parity-video.mov
3. `.venv/bin/python scripts/parity.py` — verdict prints WITHIN/OUTSIDE
   against the derived band.

The band derivation note: deterministic decodes yield sigma ~ 0, so the
committed floor (1e-4 luma units) stands until a capture environment
with real run-to-run noise exists; an asserted tighter band would be a
bug by the mandate's own rule.
