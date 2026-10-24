# pikicam — interoperability matrix

Independent developers must open and render pikicam's outputs sanely.
Truths below were measured on this host with the tool versions in
docs/DECISIONS.md; each row names its method.

## Captured Bayer DNG (fixture-bayer-rich, iPhone13,1)

| Consumer | Result | Method |
|---|---|---|
| dng_validate (DNG SDK 1.7.0.0) | PASS, "Validation complete" | oracle build, DECISIONS D3 |
| LibRaw (rawpy) | decodes 4032x3024 CFA, camera WB gains read | venv rawpy |
| exiftool 13.55 | full tag table: CFA 32803, RGGB, BitsPerSample 16, WhiteLevel 4095, BlackLevel 528 | tag read vs DNG spec |
| RawTherapee CLI | opens | rawtherapee-cli present |
| darktable | UNAVAILABLE on host (cask disabled) | DECISIONS D2 |
| Apple Photos (device) | pending device Photos run (owner-assisted) | open question |

## Exported HEIC (develop pipeline output)

| Consumer | Result | Method |
|---|---|---|
| CGImageSource | depth 10, Display P3 profile | device test testExportProducesHEIC10 |
| exiftool | container readable | host spot-check |

## Recorded video pair (master .mov + rendition .mov)

Master: untouched H.265 ISP frames. Rendition: same frames through
PikicamLook, tagged P3-D65 primaries + HLG transfer + Rec.2020 matrix.
 ffprobe round-trip of the colour tags is pending the soak session
(owner-assisted) — [unconfirmed].
