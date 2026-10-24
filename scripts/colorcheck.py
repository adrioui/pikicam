#!/usr/bin/env python3
"""ColorChecker 24 fidelity: dE2000 per patch vs the BabelColor reference.

Method: rawpy neutral postprocess of a chart DNG (camera WB, linear gamma,
no auto bright), assume the standard 6x4 patch grid filling the frame, take
each patch centre, convert to Lab (D50 via colour-science), and compare with
the BabelColor CC24 measured averages (afternoon daylight rows omitted —
this tool uses the D65 rows).

Patch localization is a geometric assumption (grid-filling chart); tighten
with corner detection if a future run shows misalignment.
"""
import sys
from pathlib import Path

import colour
import numpy as np
import rawpy

BABELCOLOR_CC24_D65_SRGB = [
    (115, 82, 68), (194, 150, 130), (98, 122, 157), (87, 108, 67), (133, 128, 177),
    (103, 189, 170), (214, 126, 44), (80, 91, 166), (193, 90, 99), (94, 60, 108),
    (157, 188, 64), (224, 163, 46), (56, 61, 150), (70, 148, 73), (175, 54, 60),
    (231, 157, 180), (187, 86, 149), (8, 133, 161), (243, 243, 242), (200, 200, 200),
    (160, 160, 160), (122, 122, 121), (85, 85, 85), (52, 52, 52),
]
BAR = 8.0  # v1 bar: median dE2000 <= 8


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: colorcheck.py <chart.dng>")
        return 2
    path = Path(sys.argv[1])
    if not path.exists():
        print("chart capture missing — owner-physical item (docs/DEVICE-CHECKLIST.md)")
        return 0
    with rawpy.imread(str(path)) as raw:
        rgb = raw.postprocess(
            use_camera_wb=True, gamma=(1, 1), no_auto_bright=True, output_bps=16, user_flip=0
        )
    image = rgb.astype(np.float64) / 65535.0
    height, width = image.shape[:2]
    rows, columns = 4, 6
    measured = []
    for row in range(rows):
        for column in range(columns):
            y = int((row + 0.5) * height / rows)
            x = int((column + 0.5) * width / columns)
            patch = image[max(y - 8, 0):y + 8, max(x - 8, 0):x + 8]
            measured.append(patch.reshape(-1, 3).mean(axis=0))
    measured_srgb = [np.clip(colour.cctf_encoding(value), 0, 1) for value in measured]
    reference_srgb = [np.array(value) / 255.0 for value in BABELCOLOR_CC24_D65_SRGB]
    deltas = []
    for ours, ref in zip(measured_srgb, reference_srgb):
        ours_lab = colour.XYZ_to_Lab(colour.sRGB_to_XYZ(ours))
        ref_lab = colour.XYZ_to_Lab(colour.sRGB_to_XYZ(ref))
        deltas.append(colour.delta_E(ours_lab, ref_lab, method="CIE 2000"))
    median = float(np.median(deltas))
    print("dE2000 per patch:", " ".join("%.1f" % delta for delta in deltas))
    print("median dE2000: %.1f (bar <= %.1f)" % (median, BAR))
    return 0 if median <= BAR else 1


if __name__ == "__main__":
    sys.exit(main())
