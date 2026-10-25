# Reliability streak — 20 consecutive walk cycles

Provenance: AGENT-MEASURED, back-to-back WalkSmokeUITests cycles
(capture -> Photos, archive round-trip) on the iPhone 12 mini, one
build, no interventions.

## Measured (first, pre-hardening harness)

3/5 green, 2 runner flakes, 0 app failures — exposed a real test
fragility (archive BACK as system chevron) — fixed, hardened.

## Measured (20 cycles, post-hardening)

| Class | Count | Notes |
|---|---|---|
| GREEN | 8 | cycles 1-8 |
| App failure (unclassified) | 11 | cycles 9-20 (except 13) — BUT see below |
| Runner flake | 1 | cycle 13 |

Evidence review: cycle-log overwriting hid most failure lines, but the
one diagnostic re-run of the failing test (testMonoClipExportsAndSaves)
showed the APP COMPLETED ALL WORK — walk marks prove record 6.3 s,
export 1.4 s, save 0.5 s — while the runner connection died
("Failure collecting diagnostics", CoreDeviceCLISupport). The third
flake signature is now in both gates.

Honest classification of the 20-run: 8 confirmed green, 1 confirmed
flake, 11 presumed runner-death-after-success (unconfirmed per-cycle —
marks log overwrote each cycle). The streak script now preserves
per-cycle logs for full classification.

## Fix after this artifact

reliability.sh copies each cycle log to build/dd/cycle-N.log before
overwrite, so the next 20-run classifies every cycle. Re-run by the
owner on a cool device for the committed N/20 number.
