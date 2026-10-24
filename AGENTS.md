# pikicam — agent contract

Three verbs: SHOOT PHOTO, APPLY BNW, RECORD VIDEO. The human walk
(docs/WALK.md) is the only definition of working. No feature exists
unless a walk step needs it.

- Device only (iPhone 12 mini). Never a simulator.
- `scripts/verify.sh` before claiming work done; budgets (launch<2s,
  tap<1s) re-measured after any change that touches a verb.
- Skin: one token file (Support/Skin.swift). Nothing else may name a
  color, size, or weight — SkinTests fail the build on violations.
  HIG deviations are enumerated in docs/SKIN.md or they are bugs.
- Commits: conventional type(scope), atomic, imperative; every commit
  leaves the app launchable.
- Blocking waits inside performChanges are forbidden (DIAGNOSIS 1);
  PhotoKit completions resume through nonisolated helpers.
- New top-level paths need a `!` entry with a reason in the
  allow-list .gitignore.
