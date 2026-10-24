# pikicam — colour pipeline sources

Working space: extendedLinearDisplayP3 as scene-linear. Choice: the sensor's
colour matrix targets P3 primaries; working in the same primaries means the
look operates on capture-referred data without an intermediate conversion.

- Mono luminance row (0.22897, 0.69174, 0.07929): the Y row of the linear
  Display-P3->XYZ matrix (SMPTE RP 431-2 primaries, D65 white). The kernel
  constants must equal scripts/p3-luminance.py output (unit-tested).
- Tone curve: filmic scene-linear -> display-linear, fixes 0->0, 0.18->0.18,
  asymptotic shoulder (2.69 -> (0.95, 1.0), never a hard clip). Reference
  behaviour: darktable filmic-rgb (source-studied; darktable itself
  unavailable for rendering, DECISIONS D2).
- Gamut compression: distance-based soft compression toward the achromatic
  axis, parameterized after the ACES reference gamut compression (threshold
  0.02, limit 0.35 in the kernel).
- Dither: deterministic triangular PDF, +-0.5 LSB at 10-bit, hashed from
  pixel coordinates — banding control without breaking fingerprint
  reproducibility.
- Encode: HEIC 10-bit Display P3. The final working->P3 match is ColorSync's
  default (no rendering-intent option exists on this SDK) — recorded.
