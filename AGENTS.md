# pikicam — agent contract

The device (iPhone 12 mini, iOS 26.6.2) is the only verification target.
Never a simulator.

Workflow: read docs/PROMPT-v2.md is NOT in this repo; the binding spec
summary lives in docs/DECISIONS.md. When code contradicts a probe result,
follow the probe and record the discrepancy there.

- `xcodegen generate` after adding/removing files. project.yml is truth.
- `scripts/verify.sh` before claiming any work done (device unlocked).
- Swift 6, complete strict concurrency, warnings-as-errors. No `try?` in
  pikicam/. Typed errors at boundaries; no NSError past its file.
- Comments only for non-obvious why with a source; density < 10%.
- File <= 300 lines, function <= 40 (scanner-enforced).
- Banned (grep-enforced): 1-arg CIRAWFilter(imageData:), PHImageManager,
  .balanced/.quality on RAW settings, linearSpaceFilter, responds(to:,
  supportedCameraModels, MPVolumeView, AVCaptureMovieFileOutput, PRO-RAW.
- Design system: MM-NC/01 tokens only (Palette/SurfaceColor/RuleColor/
  TextColor; type 32/20/13/11/9). No raw colors outside DesignSystem.
- Commits: conventional `type(scope): description`, atomic, imperative.
- Everything not allowed by the .gitignore allow-list is invisible: add a
  `!` entry with a reason when introducing a new top-level path.
