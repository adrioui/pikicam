#!/usr/bin/env python3
"""Derive the linear Display-P3 -> XYZ luminance row from CIE primaries.

SMPTE RP 431-2 (P3) primaries, D65 white. The kernel constants are
extractable, not transcribed; a unit test recomputes this and asserts
the app's Look matches.
"""
import sys

import numpy as np

P3_XY = [(0.680, 0.320), (0.265, 0.690), (0.150, 0.060)]
WHITE_XY = (0.3127, 0.3290)


def main() -> int:
    columns = [[x / y, 1.0, (1 - x - y) / y] for x, y in P3_XY]
    primaries = np.array(columns).T
    x, y = WHITE_XY
    white = np.array([x / y, 1.0, (1 - x - y) / y])
    scale = np.linalg.solve(primaries, white)
    matrix = primaries * scale[np.newaxis, :]
    row = matrix[1, :]
    print("R %.5f  G %.5f  B %.5f" % (row[0], row[1], row[2]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
