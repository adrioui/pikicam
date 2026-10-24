# WALK — the definition of working

The acceptance walk is run by a human on the connected iPhone 12 mini
before every ship. Any failing step = not shipped, regardless of tests.

## The walk

1. Cold launch -> live preview visible in under 2 seconds.
2. Tap shutter -> capture completes in under 1 second -> photo appears
   in Apple Photos.
3. Tap the BNW toggle -> shoot -> the photo in Photos is visibly
   black-and-white.
4. Switch to VIDEO -> record 10 seconds -> stop -> the clip plays in
   Photos with audio.
5. Open the archive -> tap a photo -> tap BACK -> returns to the camera.
6. Background the app mid-recording -> return -> the clip recorded so
   far is saved, not lost.
7. Deny photo-library permission -> app explains and keeps the camera
   working; granting later resumes saving.
8. Hand the phone to someone who has never seen the app; they complete
   steps 1-5 unaided.

## Machine-measured budgets (walk-marks, real pipeline on device)

| Step | Budget | Measured | When |
|---|---|---|---|
| launch -> preview-started | < 2 s | 0.24 s | tracer bullet, pre-skin |
| shutter-pressed -> capture-returned | < 1 s | 0.78 s | tracer bullet, pre-skin |
| capture -> save-done (photo in Photos) | — | 0.39 s | tracer bullet, pre-skin |
| record stop -> file ready | — | 0.12 s | video pass |
| record stop -> clip saved | — | 0.45 s | video pass |

The skin may not cost a budget: re-measure after every skin change by
running the app with `-pikicam.selfwalk`-style marks (the smoke suite
writes the same marks via the real pipeline) and reading
`Documents/walk-marks.log` from the app container.

## Post-skin re-measurement (brutalist reskin, real pipeline, device)

| Step | Budget | Measured (pre-skin) | Measured (post-skin) |
|---|---|---|---|
| launch -> preview-started | < 2 s | 0.24 s | 0.20 s |
| shutter-pressed -> capture-returned | < 1 s | 0.78 s | 0.21 s |
| capture -> save-done | — | 0.39 s | 0.18 s |

Both photo and mono smoke tests passed on device post-skin. The human
walk remains the ship gate; these numbers say the skin cost no budget.

## Grown steps (the mandate's additions)

9. Look on video is visibly the same monochrome as look on stills of the
   same locked scene (BNW ON for both).
10. The clip plays in-app: paging reaches it, PLAY/PAUSE and scrubber
    work.
11. Paging works: swipe across media in the viewer.
12. The archive lists ONLY pikicam captures (album fetch; nothing
    foreign).
13. 10-minute record soak: no drops, thermal state recorded.
14. Flip to the FRONT camera -> shoot -> photo appears in Photos; front
    video records with audio. Flip back returns the rear camera.

Steps 9-12 are covered by the device smoke suite plus the parity
artifacts; step 13 is a human soak (start record, wait 10 min, stop,
check save + thermal note here).

## Operator notes

- Free provisioning: the developer certificate must be re-trusted on the
  device whenever the profile is re-minted (~weekly). Symptom: the app
  refuses to launch with "profile not trusted". Settings -> General ->
  VPN & Device Management -> trust.
- First capture shows system permission alerts (camera, then Photos);
  the walk dismisses them once per install.
