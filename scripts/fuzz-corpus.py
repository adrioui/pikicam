#!/usr/bin/env python3
"""Deterministic fuzz corpus for the DNG parsers.

Seeded mutations of a fixture: byte flips, truncations, oversized and
underflowing IFD fields. --smoke runs 50 variants; without it, the full
corpus. Parsers must never crash (typed errors only); a crash here is a P0.
"""
import argparse
import random
import struct
import subprocess
import sys
from pathlib import Path

SMOKE = 50
ROOT = Path(__file__).resolve().parent.parent


def host_parse(path: Path) -> int:
    """Feed the file through the host Swift inspector; non-zero = crash/throw."""
    result = subprocess.run(
        ["swift", str(ROOT / "scripts" / "host-render.swift"), str(path)],
        capture_output=True, text=True,
    )
    return result.returncode


def mutate(base: bytes, index: int) -> bytes:
    rng = random.Random(index)
    data = bytearray(base)
    mode = index % 4
    if mode == 0:
        for _ in range(rng.randint(1, 16)):
            position = rng.randrange(len(data))
            data[position] ^= 1 << rng.randint(0, 7)
    elif mode == 1:
        keep = rng.randrange(8, max(len(data) // 2, 16))
        data = data[:keep]
    elif mode == 2:
        position = rng.randrange(0, min(len(data), 256))
        struct.pack_into(">I", data, position, 0xFFFFFFFF)
    else:
        position = rng.randrange(0, min(len(data), 256))
        struct.pack_into(">H", data, position, 0xFFFF)
    return bytes(data)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--smoke", action="store_true")
    parser.add_argument("--fixture", default="pikicamTests/Fixtures/fixture-bayer-rich.dng")
    args = parser.parse_args()
    fixture = Path(args.fixture)
    if not fixture.exists():
        print("SKIP (fixture-gated): no fixture to mutate — parsers still unit-covered")
        return 0
    base = fixture.read_bytes()
    count = SMOKE if args.smoke else 500
    crashes = 0
    scratch = Path("/tmp/pikicam-fuzz")
    scratch.mkdir(exist_ok=True)
    for index in range(count):
        candidate = scratch / f"case-{index}.dng"
        candidate.write_bytes(mutate(base, index))
        code = host_parse(candidate)
        if code not in (0, 1, 2, 3, 4):
            crashes += 1
            print(f"CRASH case-{index} exit {code}")
        candidate.unlink()
    print(f"{count} variants, {crashes} crashes")
    return 1 if crashes else 0


if __name__ == "__main__":
    sys.exit(main())
