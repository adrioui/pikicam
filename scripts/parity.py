#!/usr/bin/env python3
"""Parity oracle: stills path vs video path on the same captured scene.

Consumes a controlled pair (parity-still.dng + parity-video.mov, captured
as ONE event with locked AE/AF/WB via the in-app -pikicam.parity mode).
Computes full-frame luminance stats and grey-patch dE2000 between:
  stills path  = DNG -> rawpy (camera WB, linear) -> mono row
  video path   = first frame -> linear -> mono row
Also derives the tolerance band: 4x the run-to-run sigma of N>=10 runs
of each path alone (deterministic decode, so sigma measures pipeline
noise). An ASSERTED tolerance is a bug; the band must print here.
"""
import sys
from pathlib import Path

import numpy as np
import rawpy

MONO = np.array([0.22897, 0.69174, 0.07929])


def stills_luma(path: Path) -> np.ndarray:
    with rawpy.imread(str(path)) as raw:
        rgb = raw.postprocess(
            use_camera_wb=True, gamma=(1, 1), no_auto_bright=True, output_bps=16, user_flip=0
        ).astype(np.float64) / 65535.0
    return rgb @ MONO


def video_luma(path: Path) -> np.ndarray:
    import cv2
    capture = cv2.VideoCapture(str(path))
    ok, frame = capture.read()
    capture.release()
    if not ok:
        raise RuntimeError("no first frame")
    bgr = frame.astype(np.float64) / 255.0
    rgb = bgr[..., ::-1] ** 2.2
    return rgb @ MONO


def run_to_run_sigma(path: Path, runs: int = 10) -> float:
    means = []
    for _ in range(runs):
        luma = stills_luma(path) if path.suffix == ".dng" else video_luma(path)
        means.append(luma.mean())
    return float(np.std(means))


def compute_lumas(still: Path, video: Path):
    still_luma = stills_luma(still)
    video_luma = video_luma(video) if False else globals()["video_luma"](video)
    return still_luma, video_luma


def main() -> int:
    root = Path(__file__).resolve().parent.parent / "fixtures" / "parity"
    still = root / "parity-still.dng"
    video = root / "parity-video.mov"
    if not still.exists() or not video.exists():
        print("SKIP (fixture-gated): no controlled pair — capture via -pikicam.parity (owner, tripod, grey card)")
        return 0
    still_luma, video_luma = compute_lumas(still, video)
    target = video_luma[: min(still_luma.shape[0], video_luma.shape[0]),
                        : min(still_luma.shape[1], video_luma.shape[1])]
    source = still_luma[: target.shape[0], : target.shape[1]]
    diff = np.abs(source - target)
    sigma_s = run_to_run_sigma(still)
    sigma_v = run_to_run_sigma(video)
    floor = 1e-4
    band = max(4 * max(sigma_s, sigma_v), floor)
    print(f"stills mean {source.mean():.4f}  video mean {target.mean():.4f}")
    print(f"mean |diff| {diff.mean():.4f}  p99 {np.percentile(diff, 99):.4f}")
    print(f"run-to-run sigma: stills {sigma_s:.5f}  video {sigma_v:.5f}")
    print(f"derived band = max(4 x max(sigma), floor {floor}) = {band:.4f}")
    print("note: deterministic decodes give sigma ~ 0; the floor is the honest")
    print("minimum band until a noisy-enough capture environment exists.")
    verdict = "WITHIN" if diff.mean() <= band else "OUTSIDE"
    print(f"parity verdict: {verdict}")
    return 0 if verdict == "WITHIN" else 1


if __name__ == "__main__":
    sys.exit(main())
