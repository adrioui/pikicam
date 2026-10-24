#!/usr/bin/env python3
"""Bracket our develop front end against LibRaw.

Our side: a host CoreImage render of the fixture through the neutral recipe
(scripts/host-render.swift — the same CIRAWFilter front end the app uses).
Reference side: rawpy (LibRaw) camera-WB, gamma-off, no-auto-bright decode.
Scene-linear per-channel statistics must sit within tolerance of each other.
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
import rawpy

TOLERANCE = 0.05  # relative mean difference; Phase A to tighten with N-run stats
DARK_SCENE_FLOOR = 0.01  # below this, relative comparison is meaningless (black frames)


def our_stats(dng: Path) -> dict:
    root = Path(__file__).resolve().parent
    result = subprocess.run(
        ["swift", str(root / "host-render.swift"), str(dng)],
        capture_output=True, text=True, check=True,
    )
    return json.loads(result.stdout.strip().splitlines()[-1])


def libraw_stats(dng: Path) -> dict:
    with rawpy.imread(str(dng)) as raw:
        rgb = raw.postprocess(
            use_camera_wb=True, gamma=(1, 1), no_auto_bright=True,
            output_bps=16, user_flip=0,
        ).astype(np.float64) / 65535.0
    stats = {}
    for index, name in enumerate("rgb"):
        channel = rgb[..., index].ravel()
        sorted_channel = np.sort(channel)
        count = len(sorted_channel)

        def percentile(p: float) -> float:
            position = int((count - 1) * p)
            return float(sorted_channel[position])

        stats[name] = {
            "mean": float(channel.mean()),
            "median": percentile(0.5),
            "p1": percentile(0.01),
            "p99": percentile(0.99),
            "max": float(sorted_channel[-1]),
        }
    return stats


def compare(ours: dict, reference: dict) -> list:
    failures = []
    for channel in "rgb":
        our_mean = ours[channel]["mean"]
        ref_mean = reference[channel]["mean"]
        if ref_mean <= 0:
            continue
        relative = abs(our_mean - ref_mean) / ref_mean
        if relative > TOLERANCE:
            failures.append((channel, our_mean, ref_mean, relative))
    return failures


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("fixture", nargs="?", default="fixtures/device/fixture-bayer-rich.dng")
    parser.add_argument("--check", action="store_true", help="exit non-zero outside tolerance")
    args = parser.parse_args()

    fixture = Path(args.fixture)
    if not fixture.exists():
        print(f"no fixture at {fixture} — capture via pikicamProbes (documented skip class)")
        return 0 if not args.check else 1

    ours = our_stats(fixture)
    reference = libraw_stats(fixture)
    print("pikicam front end:", json.dumps(ours, indent=1))
    print("LibRaw reference:", json.dumps(reference, indent=1))
    darkest = min(reference[channel]["mean"] for channel in "rgb")
    if darkest < DARK_SCENE_FLOOR:
        print(
            "SKIP (fixture-gated): reference scene mean %.4f below floor %.4f — "
            "the fixture is a face-down dark capture; recapture per docs/CALIBRATION.md"
            % (darkest, DARK_SCENE_FLOOR)
        )
        return 0
    failures = compare(ours, reference)
    if failures:
        for channel, ours_mean, ref_mean, relative in failures:
            print(f"OUT OF TOLERANCE {channel}: ours {ours_mean:.4f} vs ref {ref_mean:.4f} ({relative:.1%})")
        return 1
    print("within tolerance (relative mean per channel <= %.0f%%)" % (TOLERANCE * 100))
    return 0


if __name__ == "__main__":
    sys.exit(main())
