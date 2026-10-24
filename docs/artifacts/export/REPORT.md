# Export byte truth (composition path)

Provenance: AGENT-MEASURED on the iPhone 12 mini (A14, iOS 26.6.2),
face-down low-light desk, clip dumped from the app container via
`-pikicam.dumpclip` during the on-device smoke
(`WalkSmokeUITests.testMonoClipExportsAndSaves`). Tools: ffprobe/ffmpeg
on this host (nix ffmpeg).

| Metric | Master (MovieFileOutput) | Mono export (composition) |
|---|---|---|
| video | hevc Main 1128x1504 ~11.2 Mb/s | h264 High 1128x1504 ~10.8 Mb/s |
| frames | 95 over 6.333 s @ 15 fps* | 95 over 6.333 s @ 15 fps* |
| frame arithmetic | — | 95 = 6.333 x 15 +/- 0.0 |
| audio | aac LC 48 kHz mono | aac LC 48 kHz mono |
| audio md5 (ffmpeg -map 0:a -c copy -f md5) | d954949ab1696288907720659afbe8ec | d954949ab1696288907720659afbe8ec |

*15 fps is low-light throttling in this environment (nominal 30); the
arithmetic check is rate-relative, so it holds either way. Re-run in
light: expect 30 fps with the same exact-arithmetic property.

## Verdict

- Video re-encoded WITH the shared Look (that is the composition path's
  purpose).
- Audio PASS-THROUGH: byte-identical MD5 — no silent re-encode.
- Frame count == duration x fps +/- 0.

Raw reports: mono-clip-ffprobe.txt, master-clip-ffprobe.txt (clips
themselves are multi-MB and stay out of git).
