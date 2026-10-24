#!/usr/bin/env python3
"""Phase A calibration analysis over the device-captured flat series.

Reads fixtures/device/flat_*.dng, computes per-image signal statistics,
the photon-transfer curve per ISO, exposure linearity, and shutter-tag
accuracy. Writes docs/CALIBRATION.md inputs to stdout as JSON.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

import numpy as np
import rawpy

FIXTURES = Path(__file__).resolve().parent.parent / "fixtures" / "device"
CENTRAL_FRACTION = 0.25


def parse_exposure(value):
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str) and "/" in value:
        num, den = value.split("/")
        return float(num) / float(den)
    return float(value)


def exif_map(paths):
    proc = subprocess.run(
        ["exiftool", "-j", "-ExposureTime", "-ISO", *[str(p) for p in paths]],
        capture_output=True, text=True, check=True,
    )
    rows = json.loads(proc.stdout)
    return {Path(r["SourceFile"]).name: r for r in rows}


def central_stats(raw):
    image = raw.raw_image_visible.astype(np.float64)
    h, w = image.shape
    ch = int(h * CENTRAL_FRACTION)
    cw = int(w * CENTRAL_FRACTION)
    crop = image[h // 2 - ch // 2 : h // 2 + ch // 2, w // 2 - cw // 2 : w // 2 + cw // 2]
    black = raw.black_level_per_channel
    pattern = raw.raw_pattern
    channels = []
    for py in range(pattern.shape[0]):
        for px in range(pattern.shape[1]):
            plane = crop[py :: pattern.shape[0], px :: pattern.shape[1]]
            offset = black[py * pattern.shape[1] + px] if len(black) > py * pattern.shape[1] + px else black[0]
            channels.append(plane - offset)
    stats = []
    for plane in channels:
        stats.append(
            {
                "mean": float(plane.mean()),
                "variance": float(plane.var()),
                "p1": float(np.percentile(plane, 1)),
                "p99": float(np.percentile(plane, 99)),
            }
        )
    return stats


def main():
    files = sorted(FIXTURES.glob("flat_*.dng"))
    if not files:
        print(json.dumps({"error": "no flat fixtures found"}))
        return 1

    records = []
    exifs = exif_map(files)
    for path in files:
        match = re.match(r"flat_iso(\d+)_exp(\d+)", path.stem)
        iso = int(match.group(1))
        duration_us = int(match.group(2))
        exif = exifs.get(path.name, {})
        with rawpy.imread(str(path)) as raw:
            stats = central_stats(raw)
        tagged_duration = parse_exposure(exif.get("ExposureTime", 0))
        tagged_iso = float(exif.get("ISO", 0))
        g_mean = np.mean([s["mean"] for s in stats])
        g_var = np.mean([s["variance"] for s in stats])
        records.append(
            {
                "file": path.name,
                "isoRequested": iso,
                "durationUsRequested": duration_us,
                "isoTagged": tagged_iso,
                "durationTaggedS": tagged_duration,
                "greenMean": g_mean,
                "greenVariance": g_var,
                "channels": stats,
            }
        )

    white_level = None
    with rawpy.imread(str(files[0])) as raw:
        white_level = int(raw.white_level)

    shutter_errors = [
        abs(r["durationTaggedS"] * 1e6 - r["durationUsRequested"]) / r["durationUsRequested"]
        for r in records
        if r["durationUsRequested"] > 0
    ]

    iso_groups = {}
    for r in records:
        iso_groups.setdefault(r["isoRequested"], []).append(r)

    ptc = {}
    for iso, group in iso_groups.items():
        group = sorted(group, key=lambda r: r["durationUsRequested"])
        means = [r["greenMean"] for r in group]
        variances = [r["greenVariance"] for r in group]
        ptc[iso] = [
            {"durationUs": r["durationUsRequested"], "mean": m, "variance": v}
            for r, m, v in zip(group, means, variances)
        ]

    fixed_iso = min(iso_groups.keys())
    linear_group = sorted(iso_groups[fixed_iso], key=lambda r: r["durationUsRequested"])
    durations = np.array([r["durationUsRequested"] for r in linear_group])
    signals = np.array([r["greenMean"] for r in linear_group])
    if len(durations) >= 3 and signals.max() < white_level * 0.9:
        slope, intercept = np.polyfit(durations, signals, 1)
        predicted = slope * durations + intercept
        ss_res = float(((signals - predicted) ** 2).sum())
        ss_tot = float(((signals - signals.mean()) ** 2).sum())
        r2 = 1 - ss_res / ss_tot if ss_tot > 0 else None
    else:
        slope, intercept, r2 = None, None, None

    output = {
        "whiteLevel": white_level,
        "images": len(records),
        "isoLadder": sorted(iso_groups.keys()),
        "durationUsLadder": sorted({r["durationUsRequested"] for r in records}),
        "shutterTagRelativeError": {
            "max": max(shutter_errors),
            "median": float(np.median(shutter_errors)),
        },
        "exposureLinearity": {
            "iso": fixed_iso,
            "slopePerUs": slope,
            "intercept": intercept,
            "r2": r2,
        },
        "ptc": ptc,
        "records": records,
    }
    json.dump(output, sys.stdout, indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main())
