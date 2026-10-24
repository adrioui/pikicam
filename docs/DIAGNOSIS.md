# DIAGNOSIS — why the current app does not work

Method: lifecycle signposts (WalkMark) were added at every step of the walk
path; the plan was to run the app live on the device. The device run is
blocked by finding 0 below (profile trust). Findings 1-6 are code-proven by
inspection of the exact lines; each cites where. When profile trust is
re-granted, `launch ... -- -pikicam.selfwalk` re-runs the instrumented path
and confirms the timings.

## Finding 0 (device-confirmed) — the app cannot launch at all right now

The personal-team profile expired mid-session and was re-minted; the device
now refuses to launch the app ("profile has not been explicitly trusted").
Owner action required: Settings → General → VPN & Device Management → trust
the developer certificate. Operational truth: with a free team this recurs
roughly weekly; the acceptance walk always starts from a fresh install.

## Finding 1 (code-proven) — every capture deadlocks at save

`PhotoKitLibrary.saveSync` (pikicam/Library/PhotoKitLibrary.swift) runs a
`PHPhotoLibrary.performChanges` closure and, inside that closure, calls
`Album.fetchOrCreateSync()` (pikicam/Library/Album.swift), which blocks a
semaphore waiting for a *second* `performChanges` to finish. Apple forbids
blocking waits inside `performChanges`; the nested change cannot complete
while the outer closure is blocked. Tap shutter → capture returns → journal
persisted → develop done → `save-begin` → never returns. The photo never
appears in Photos. Walk steps 2-4 all die here.

## Finding 2 (code-proven) — the archive is a trap door

`LibraryScreen` is presented as a `fullScreenCover` from `CameraScreen`
(pikicam/Features/Camera/CameraScreen.swift) and contains no dismiss
control. Once opened, there is no way back to the camera short of killing
the app. Walk step 5 ("tap BACK → returns to the camera") cannot pass.

## Finding 3 (code-proven) — photo-library permission is not part of the gate

`PermissionsScreen` enables [ENTER] once the CAMERA permission is granted;
the photo-library row is optional. A user who taps through (the natural
path — walk step 8's naive user) reaches a working shutter whose saves
fail: `performChanges` returns `PHPhotosError.notGranted`-family errors
that surface only as a small `lastError` string. Walk step 7 (deny →
explain, keep camera; grant later → resumes saving) is not implementable in
the current flow because the permission screen may never be seen again.

## Finding 4 (code-proven) — tap-to-capture includes a full 12 MP develop

`CameraModel.pressShutter` → `CaptureFlow.run` → `developForCapture` runs
the complete 4032x3028 develop (CIRAWFilter + custom Metal kernel) and a
HEIC encode *before* the first save attempt, on the capture path. On an
A14 this alone is well beyond the 1 s tap-to-capture budget; the walk
budget cannot be met with develop-in-the-critical-path.

## Finding 5 (code-proven) — preview layer churn

`AVCaptureClient.init` builds `PreviewSource` whose provider closure
creates a NEW `AVCaptureVideoPreviewLayer` on every access
(pikicam/Capture/AVCaptureClient.swift). SwiftUI recreating the host view
gets a different layer each time; previous layers are never removed. This
risks a black viewfinder after any view churn (rotation, cover
presentation) — the exact class of "preview sometimes black" reports.

## Finding 6 (structural) — the app does far too much

Scan client, numeric line matrix (0-23), journal/recovery, viewer develop
panels, eight-component design matrix, probe target, five oracle scripts —
none of it serves SHOOT PHOTO / APPLY BNW / RECORD VIDEO. Per the new
mandate these are deleted after the tracer bullet, one commit per
deletion, walk intact after each.

## What the instrumented run will confirm once trust is granted

Expected mark sequence today: `root-appeared → permission-camera-requested
→ enter-tapped → camera-start-begin → session-started → selfwalk-shutter →
shutter-pressed → capture-returned → journal-persisted → develop-done →
save-begin → performChanges-begin → album-fetch-begin` and then silence
(finding 1). Numbers for launch-to-preview and tap-to-capture come from the
same marks; they are written into docs/WALK.md.
