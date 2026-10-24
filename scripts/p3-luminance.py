#!/usr/bin/env python3
"""Derive the linear Display-P3 -> XYZ luminance row.

Primaries: SMPTE RP 431-2 (P3), white: D65. Prints the derivation so the
kernel constants are extractable, not transcribed. A unit test recomputes
this and asserts the kernel matches.
"""
import sys

import numpy as np

P3_PRIMARIES_XY = [
    (0.680, 0.320),
    (0.265, 0.690),
    (0.150, 0.060),
]
WHITE_XY = (0.3127, 0.3290)  # D65


def luminance_row() -> "np.ndarray":
    columns = []
    for x, y in P3_PRIMARIES_XY:
        columns.append([x / y, 1.0, (1 - x - y) / y])
    primaries_xyz = np.array(columns).T
    x, y = WHITE_XY
    white_xyz = np.array([x / y, 1.0, (1 - x - y) / y])
    scale = np.linalg.solve(primaries_xyz, white_xyz)
    rgb_to_xyz = primaries_xyz * scale[np.newaxis, :]
    return rgb_to_xyz[1, :]


def main() -> int:
    row = luminance_row()
    print("P3 (RP 431-2) primaries, D65 white")
    print("P3 -> XYZ matrix row Y:")
    print("  R %.5f  G %.5f  B %.5f" % (row[0], row[1], row[2]))
    print("kernel constants: (r=%.5f, g=%.5f, b=%.5f)" % (row[0], row[1], row[2]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
