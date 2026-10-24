# HEALTH — failure taxonomy and measured evidence

Provenance: every row states who measured it and how. Agent rows are
device runs on the iPhone 12 mini (A14, iOS 26.6.2); owner rows are
open slots.

## Failure taxonomy (from device crash logs, 2026-10-25)

| # | Severity | Failure | Evidence | Fix | Regression witness |
|---|---|---|---|---|---|
| 1 | WALK-BLOCKING | Archive crashes/freezes on open: whole-library, main-thread PHAssetResource scan in legacyPIKIAssets | 3 identical .ips stacks: ArchiveScreen.reload -> runMigrationIfFirstLaunch -> dryRun -> legacyPIKIAssets | bounded scan (post-first-launch assets, fetchLimit 200), detached at utility priority; album fetch stays main-thread-fast | ArchiveHealthUITests drives migration then asserts BACK responsive |
| 2 | leak | PlayerBar periodic time observer never removed (retains player after dismantle) | by inspection (UIKit contract) | ObserverBox.stop() on dismantle | code path; soak owner slot |
| 3 | crash-risk | startRecording before session running -> potential ObjC exception | by inspection (AVFoundation contract) | guard !isRecording, isRunning with message | covered by FrontCameraUITests flip timing |

## Measured budgets (agent, real pipeline, device)

| Metric | Budget | Pre-fix | Post-fix |
|---|---|---|---|
| launch -> preview | < 2 s | 0.20 s | 0.24 s |
| shutter -> capture | < 1 s | 0.21 s | 0.14 s (front: 0.14 s) |
| capture -> save-done | - | 0.18 s | 0.25 s |
| front flip -> capturable | - | - | ~12 s first flip (session rebuild), 3 s return flip |

## Owner slots (open)

- [ ] Instruments Leaks/Allocations over capture->save->archive->view xN
      (zero-leak claim currently rests on inspection + smoke, not a trace)
- [ ] MetricKit payloads after 24 h of real use
- [ ] 10-minute record soak (docs/artifacts/soak)
