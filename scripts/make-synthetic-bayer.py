#!/usr/bin/env python3
"""Generate a tiny deterministic Bayer DNG for parser unit tests.

64x48 RGGB 16-bit, gradient + flat patches with known values, zero noise.
Layout: header | IFD0 | SubIFD(raw) | ExifIFD | data pool | raw strip.
Validated against dng_validate (primary) and exiftool/rawpy (proxy).
"""
import struct
import sys

import numpy as np

WIDTH, HEIGHT = 64, 48
BLACK_LEVEL = 200
WHITE_LEVEL = 65535

TYPE_BYTE, TYPE_ASCII, TYPE_SHORT, TYPE_LONG, TYPE_RATIONAL, TYPE_SRATIONAL = 1, 2, 3, 4, 5, 10
SIZE = {TYPE_BYTE: 1, TYPE_ASCII: 1, TYPE_SHORT: 2, TYPE_LONG: 4, TYPE_RATIONAL: 8, TYPE_SRATIONAL: 8}


def rational(num, den):
    return struct.pack("<II", num, den)


def srational(num, den):
    return struct.pack("<ii", num, den)


def pack_value(typ, value):
    if isinstance(value, bytes):
        return value
    if typ == TYPE_SHORT:
        if not isinstance(value, (list, tuple)):
            value = [value]
        return b"".join(struct.pack("<H", v) for v in value)
    if typ == TYPE_LONG:
        if not isinstance(value, (list, tuple)):
            value = [value]
        return b"".join(struct.pack("<I", v) for v in value)
    raise ValueError(f"unexpected {typ} {value!r}")


class IFD:
    def __init__(self):
        self.entries = {}

    def set(self, tag, typ, value):
        self.entries[tag] = (typ, value)

    def size(self):
        return 2 + 12 * len(self.entries) + 4

    def serialize(self, resolve_offset):
        packed = []
        for tag in sorted(self.entries):
            typ, value = self.entries[tag]
            data = pack_value(typ, value)
            count = len(data) // SIZE[typ]
            packed.append((tag, typ, count, data))
        body = struct.pack("<H", len(packed))
        for tag, typ, count, data in packed:
            body += struct.pack("<HHI", tag, typ, count)
            if len(data) <= 4:
                body += data.ljust(4, b"\0")
            else:
                body += struct.pack("<I", resolve_offset(tag, data))
        body += struct.pack("<I", 0)
        return body


def make_dng(path):
    yy, xx = np.mgrid[0:HEIGHT, 0:WIDTH]
    phase = (yy % 2) * 2 + (xx % 2)
    ramp = 1.0 + 0.5 * (np.arange(WIDTH * HEIGHT).reshape(HEIGHT, WIDTH) / (WIDTH * HEIGHT))
    cfa = np.zeros((HEIGHT, WIDTH), dtype=np.int32)
    cfa[phase == 0] = (ramp[phase == 0] * 30000).astype(np.int32)
    cfa[phase == 1] = (ramp[phase == 1] * 28000).astype(np.int32)
    cfa[phase == 2] = (ramp[phase == 2] * 29000).astype(np.int32)
    cfa[phase == 3] = (ramp[phase == 3] * 24000).astype(np.int32)
    cfa = np.clip(cfa + BLACK_LEVEL, 0, WHITE_LEVEL).astype(np.uint16)
    raw_bytes = cfa.tobytes()

    ifd0 = IFD()
    sub = IFD()
    exif = IFD()

    thumb = ((cfa.astype(np.float64) - BLACK_LEVEL) / 4).clip(0, 255).astype(np.uint8).tobytes()
    ifd0.set(0x00FE, TYPE_LONG, 1)
    ifd0.set(0x0100, TYPE_LONG, WIDTH)
    ifd0.set(0x0101, TYPE_LONG, HEIGHT)
    ifd0.set(0x0102, TYPE_SHORT, 8)
    ifd0.set(0x0103, TYPE_SHORT, 1)
    ifd0.set(0x0106, TYPE_SHORT, 1)
    ifd0.set(0x010F, TYPE_ASCII, b"pikicam\0")
    ifd0.set(0x0110, TYPE_ASCII, b"UT synthetic\0")
    ifd0.set(0x0111, TYPE_LONG, [0])
    ifd0.set(0x0115, TYPE_SHORT, 1)
    ifd0.set(0x0116, TYPE_LONG, HEIGHT)
    ifd0.set(0x0117, TYPE_LONG, [len(thumb)])
    ifd0.set(0xC612, TYPE_BYTE, bytes([1, 4, 0, 0]))
    ifd0.set(0xC614, TYPE_ASCII, b"pikicam UT\0")
    ifd0.set(0x014A, TYPE_LONG, [0])
    ifd0.set(0x8769, TYPE_LONG, [0])

    sub.set(0x00FE, TYPE_LONG, 0)
    sub.set(0x0100, TYPE_LONG, WIDTH)
    sub.set(0x0101, TYPE_LONG, HEIGHT)
    sub.set(0x0102, TYPE_SHORT, 16)
    sub.set(0x0103, TYPE_SHORT, 1)
    sub.set(0x0106, TYPE_SHORT, 32803)
    sub.set(0x0111, TYPE_LONG, [0])
    sub.set(0x0115, TYPE_SHORT, 1)
    sub.set(0x0116, TYPE_LONG, HEIGHT)
    sub.set(0x0117, TYPE_LONG, [len(raw_bytes)])
    sub.set(0x828D, TYPE_SHORT, [2, 2])
    sub.set(0x828E, TYPE_BYTE, bytes([0, 1, 1, 2]))
    sub.set(0xC61A, TYPE_SHORT, BLACK_LEVEL)
    sub.set(0xC61D, TYPE_SHORT, WHITE_LEVEL)
    sub.set(0xC68D, TYPE_LONG, [0, 0, HEIGHT, WIDTH])

    ifd0.set(0x0112, TYPE_SHORT, 1)
    ifd0.set(0xC621, TYPE_SRATIONAL,
             srational(8054, 10000) + srational(-1541, 10000) + srational(-875, 10000)
             + srational(-3284, 10000) + srational(11131, 10000) + srational(1907, 10000)
             + srational(-562, 10000) + srational(-1807, 10000) + srational(10340, 10000))
    ifd0.set(0xC628, TYPE_RATIONAL,
             rational(4873, 10000) + rational(10000, 10000) + rational(3918, 10000))
    ifd0.set(0xC65A, TYPE_SHORT, 21)

    exif.set(0x829A, TYPE_RATIONAL, rational(1, 125))
    exif.set(0x829D, TYPE_RATIONAL, rational(18, 10))
    exif.set(0x8827, TYPE_SHORT, 100)
    exif.set(0x920A, TYPE_RATIONAL, rational(26, 1))
    exif.set(0xA002, TYPE_LONG, WIDTH)
    exif.set(0xA003, TYPE_LONG, HEIGHT)

    header_size = 8
    ifd0_offset = header_size
    sub_offset = ifd0_offset + ifd0.size()
    exif_offset = sub_offset + sub.size()
    pool_offset = exif_offset + exif.size()

    pool = bytearray()
    offsets = {}

    def resolve_from(tag, ifd):
        def resolve(tag_inner, data):
            key = (ifd, tag_inner)
            if key not in offsets:
                if len(pool) % 2:
                    pool.append(0)
                offsets[key] = pool_offset + len(pool)
                pool.extend(data)
            return offsets[key]
        return resolve

    sub_body = sub.serialize(resolve_from("sub", "sub"))
    exif_body = exif.serialize(resolve_from("exif", "exif"))
    ifd0_body = ifd0.serialize(resolve_from("ifd0", "ifd0"))

    ifd0_body = bytearray(ifd0_body)
    for i, tag in enumerate(sorted(ifd0.entries)):
        if tag == 0x014A:
            ifd0_body[2 + 12 * i + 8 : 2 + 12 * i + 12] = struct.pack("<I", sub_offset)
        if tag == 0x8769:
            ifd0_body[2 + 12 * i + 8 : 2 + 12 * i + 12] = struct.pack("<I", exif_offset)
    ifd0_body = bytes(ifd0_body)

    raw_offset = pool_offset + len(pool)
    thumb_offset = raw_offset + len(raw_bytes)
    sub_body = bytearray(sub_body)
    for i, tag in enumerate(sorted(sub.entries)):
        if tag == 0x0111:
            sub_body[2 + 12 * i + 8 : 2 + 12 * i + 12] = struct.pack("<I", raw_offset)
    sub_body = bytes(sub_body)

    ifd0_body = bytearray(ifd0_body)
    for i, tag in enumerate(sorted(ifd0.entries)):
        if tag == 0x0111:
            ifd0_body[2 + 12 * i + 8 : 2 + 12 * i + 12] = struct.pack("<I", thumb_offset)
    ifd0_body = bytes(ifd0_body)

    out = bytearray()
    out += b"II" + struct.pack("<H", 42) + struct.pack("<I", ifd0_offset)
    assert len(out) == header_size
    out += ifd0_body
    assert len(out) == sub_offset
    out += sub_body
    assert len(out) == exif_offset
    out += exif_body
    assert len(out) == pool_offset
    out += pool
    assert len(out) == raw_offset, (len(out), raw_offset)
    out += raw_bytes
    out += thumb

    with open(path, "wb") as f:
        f.write(bytes(out))
    print(f"wrote {path}: {len(out)} bytes, raw at {raw_offset}")


if __name__ == "__main__":
    make_dng(sys.argv[1] if len(sys.argv) > 1 else "synthetic-bayer.dng")
