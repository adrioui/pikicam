# pikicam STATE MATRIX (E channel) — lock candidate v2

Suggested storage: `/Users/adrifadilah/Desktop/pikicam/docs/.P.E-STATE-MATRIX.md` (returned here as text per harness rule).
Supersedes the v1 table in `docs/design/spec-state-matrix.md`. Coverage retained: **S01–S37**. Added: **S38** (volume HUD, owner Q4), **S39** (viewer provenance sheet, owner DATA-sheet ruling). Every state now carries the **six separate, checkable fields** the completeness gate requires (critic #11).

Provenance legend (R7): **(O)** OBSERVED — read from code or a fetch-cited source · **(D)** DERIVED — computed from OBSERVED values · **(P)** PROPOSAL — authored direction, implementer-pinned. Never read a (P) as (O).
Citation verdict legend (R1): **CONFIRMED** (line exact) · **LINE_DRIFT** (claim true, cited line wrong — corrected here) · **REFUTED** · **NOT-OPENED** (no citable evidence at v1; now opened where noted).
Sources: Courier New is an iOS system font `https://developer.apple.com/fonts/system-fonts/` **(O)** · WCAG 2.2 AA, 4.5:1 normal / 3:1 large (≥18pt or ≥14pt bold) / 3:1 non-text **(O)** · NN/g "Icon labels should be visible at all times" **(O)** · house stylesheet `global.css` **(O)**, house faces in `fonts.css` **(O)**.

---

## §0 — Canonical scale (the ONLY permitted tokens)

### §0.1 Type — six tokens, no others

Face: **Courier New** via `Font.custom(_:size:relativeTo:)`. **The two-arg overload is FORBIDDEN** (freezes under Dynamic Type). **No sans in chrome.** Fallback `Courier New → Menlo → .system(design:.monospaced)` is defensive only inside the token layer **(P)**.

| token | size / weight | tracking | case | `relativeTo` | provenance |
|---|---|---|---|---|---|
| `display` | 96 Bold, tabular | 0 | numerals | `.largeTitle` | **(P)** — no Apple parity |
| `title` | 17 Bold | +40/1000em = **0.68pt** | UPPERCASE | `.headline` | **(P)** size; weight request **(O)** house `global.css` (`font-weight:500`, shipped 400) |
| `body` | 14 Regular | 0 | sentence | `.body` | **(O)** house `.mm-txt-default` is 14px Courier |
| `label` | 13 Regular; **Bold when selected** | +80/1000em = **1.04pt** | UPPERCASE | `.callout` | **(P)** |
| `caption` | 11 Regular | +80/1000em = **0.88pt** | UPPERCASE | `.caption` | **(P)** |
| `tick` | 11 Regular, `monospacedDigit` | 0 | numerals + `X` `+` `−` `/3` | `.caption` | **(P)** |

Tracking in **pt** is given per §6 #7 (em→pt: `0.68 / 1.04 / 0.88` · spec `tokens:61-64`). `label` and `caption` share `+80/1000em`; their pt differ by size. U+2212 minus (not hyphen) in EV labels.

### §0.2 Ink — BLACK room (camera, permission surfaces)

| token | value | provenance |
|---|---|---|
| `bg` | `#000000` | **(O)** `CameraView.swift:26` |
| `ink` | `#FFFFFF` | **(O)** `ShutterButton.swift:21`, `CameraHUDButton.swift:19` |
| `secondary` | White 60% | **(P)** |
| `rule` | White 25% | **(O)** `CameraView.swift:389` |
| `wash` | Black 55% | **(O)** `CameraView.swift:384` |
| `scrim` | Black 45% → 0%, 88pt | **(P)** replaces per-control `opacity(0.45/0.5/0.6)` |
| `selectBg` / `selectInk` | `#FFFFFF` / `#000000` | inversion |
| `fail` | `#EA0000` | **(O)** house `--color-mm-base-red`; **failure only** |

### §0.3 Ink — WHITE room (gallery, viewer)

| token | value | provenance |
|---|---|---|
| `bg` | `#FCFCFC` | **(O)** house `--color-mm-base-off-white` |
| `ink` | `#000000` | — |
| `secondary` | `#6C6C6C` | **(O)** house **`--color-mm-base-neutral-500`** (§6 #1 corrected name); contrast **5.12:1** **(D)** |
| `secondary-IC` | `#595959` | **(D)** **6.83:1** on `#FCFCFC` — INC step only. **Locked at 6.83, not 6.82** (§6 #3); the vestigial `#6C6C6C`-on-`#FFFFFF` = 5.25:1 row is deleted |
| `rule` | `#000000` @ 1px | — |
| `ruleSoft` | Black 10% | gutters only (**O** token form `#0000001a`, `spec-camera:41`) |
| `selectBg` / `selectInk` | `#000000` / `#FFFFFF` | inversion |
| `fail` | **none** | **NO RED in this room** (§0.5 #6). Error = `ink` + `ERROR —` + Bold + a rule above |

The two v1-fabricated names (`--color-mm-base-strong-grey`, `--color-mm-base-light-grey`) are deleted; the real names are **`--color-mm-base-neutral-500`** (`#6c6c6c`) and **`--color-mm-base-neutral-100`** (`#e5e5e5`). The `@font-face` weight-400 observation belongs to **`fonts.css`**, not `global.css` (§6 #2).

### §0.4 Space, Rule, Shape, Hit-area

- **Space** (spacing only): `2 / 4 / 8 / 12 / 16 / 20 / 24 / 32`. No other spacing. Remap of the current `10/14/40` → `8/16/32`.
- **Rule**: `Rectangle().frame(height: 1 / displayScale)`. **`Divider()` is FORBIDDEN.** Rule locations (complete): top bar · bottom dock · viewer image/metadata · blank-tag border · **above the error banner** · **grid-banner border** (fixes the v1 "exactly four" claim, §6 #6).
- **Shape**: radius **0** everywhere. Complete deletion list (§6 #5): `Capsule()` (`CameraView.swift:144,162,417,444`), `Circle()` (`CameraHUDButton.swift:21`), `RoundedRectangle(8)` (`CameraView.swift:178`), `RoundedRectangle(6)` (`CameraView.swift:321`), `RoundedRectangle(4)` (`GalleryView.swift:26`), `RoundedRectangle(8)` (`GalleryView.swift:132`), countdown `Circle()` (`CameraView.swift:486`), EV tick `Circle()` (`CameraView.swift:423`), `Capsule()` (`ZoomIndicatorView.swift:15`). Shapes: the shutter is a **square hairline ring** — outer 80×80 (`ink`, 1pt), inner 64×64 `ink` fill (owner #6); the blank tag is 64×20; the countdown numeral is square 168×168. These shape dimensions are §2.5/§2.6 geometry, **not** spacing tokens.
- **Hit-area**: word controls and any tappable declare `.frame(minWidth: 44, minHeight: 44)` — a 44pt **a11y floor** sanctioned by the lint (`DesignLintTests.swift:411-459`), **not** a spacing token. Readouts have no hit area.

---

## §1 — The six-field record (the completeness gate, redefined)

The gate (`§5`, `§11` exit criterion) is: **every state specifies all six fields — trigger · surface · word(s) · type-token · ink-token · hit-area — or is marked `BLOCKED-ON-OWNER`.** Table A carries exactly those six as separate columns, so the gate is now checkable and **satisfiable** (critic #11 fixed). Table B carries the remaining v1 coverage: room, affordance, no-op, screen, and the verified code handling.

A field that is genuinely absent for a state is written `—` and is a *specified* value (e.g. a transition with no words), not an omission.

---

## §2 — Table A · the six-field gate

| ID | trigger | surface (what renders) | word(s) — byte-exact | type-token | ink-token | hit-area |
|---|---|---|---|---|---|---|
| **S01** | First launch; camera+Photos `.notDetermined` | Black room interstitial. Blank-tag mark (64×20, `bg`-coloured, 4 tacks) replaces the 72pt `camera.aperture` glyph **(O `RootView.swift:63-64`)**; layout **(P)** | `WELCOME TO PIKICAM` · `Honest photographs, one Bayer exposure at a time. No AI. No computation. Just light.` **(O `:70`)** · `DEVELOPED COLLECTIVELY` · `CONTINUE` **(O `:75`)** | `title` · `body` · `caption` · `label` | `ink`; `secondary` (collective line); `rule` under top bar | `CONTINUE` WordControl ≥44×44; mark not tappable |
| **S02** | CONTINUE tapped; camera sheet then Photos sheet, sequential | Black room fullscreen; system sheets are system-owned (not designable) | `WAITING — ANSWER THE SYSTEM SHEETS` **(P)** · `CONTINUE` (disabled) | `body` · `label` (disabled) | `ink` · `secondary` (disabled CONTINUE) | `CONTINUE` disabled WordControl ≥44×44; sheets system-owned |
| **S03** | camera OR Photos denied (not restricted) | Black room denial surface **(PROPOSAL: full layout, §10 #1)** | `PERMISSIONS REQUIRED` **(O `:96`)** · `pikicam needs camera and photo library access to function. Please grant these permissions in Settings.` **(O `:99`)** · `OPEN SETTINGS` **(O `:104`)** | `title` · `body` · `label` | `ink` · `secondary` · `rule` | `OPEN SETTINGS` WordControl ≥44×44 |
| **S04** | camera `.restricted` (Screen Time / MDM) | Black room denial surface, DISTINCT copy **(P)**; no Settings promise | `RESTRICTED — CAMERA BLOCKED BY DEVICE POLICY. PIKICAM CANNOT REQUEST IT.` **(P)** | `body` | `ink` + `rule` above; `fail` only if owner classifies restricted as failure — **unconfirmed** | `—` (no action) |
| **S05** | Photos `.restricted` | same denial surface, distinct copy **(P)** | `RESTRICTED — PHOTO ACCESS BLOCKED BY DEVICE POLICY.` **(P)** | `body` | `ink` + `rule` above | `—` |
| **S06** | Photos `.limited` | camera proceeds; limited-notice readout in camera top bar **(P — placement unruled)** | `PHOTOS — LIMITED` **(P)** | `caption` | `secondary` | `—` (Settings manages) |
| **S07** | granted in Settings → `scenePhase == .active` | denial→camera cut; a 0.2 fade **(P, §0.5 #8)** | `—` | `—` | `—` | `—` |
| **S08** | no back-wide camera, or no Bayer RAW format | Black room error surface; preview black | `NO CAMERA — NO BAYER RAW FORMAT IS AVAILABLE ON THIS CAMERA.` **(O `CaptureService.swift:747`)** · `RETRY` | `body` · `label` | `fail` (body) · `ink` (RETRY) | `RETRY` WordControl ≥44×44 |
| **S09** | `wasInterruptedNotification` (another app seized camera) | black preview + notice | `INTERRUPTED — CAMERA IN USE. WAITING.` **(P)** · `RETRY` | `body` · `label` | `ink` · `secondary`; no `fail` | `RETRY` WordControl ≥44×44 |
| **S10** | `scenePhase == .inactive` (Control Centre) | same as S09 | `INTERRUPTED — CAMERA IN USE. WAITING.` **(P)** · `RETRY` | `body` · `label` | `ink` · `secondary` | `RETRY` WordControl ≥44×44 |
| **S11** | `runtimeErrorNotification` (media-services reset) | black preview + notice | `SESSION ERROR.` **(P)** · `RETRY` | `body` · `label` | `fail` (body) · `ink` (RETRY) | `RETRY` WordControl ≥44×44 |
| **S12** | session stopped out-of-band; `start()` no-op risk | same as S11 | `SESSION ERROR.` **(P)** · `RETRY` | `body` · `label` | `fail` · `ink` | `RETRY` WordControl ≥44×44 |
| **S13** | shutter pressed; exposure in flight (`phase == .capturing`) | shutter locked (inner 30%); busy readout | `EXPOSING` **(P)** | `caption` | `ink` (or `secondary`) | shutter disabled (no target); shutter target 80×80 when idle |
| **S14** | exposure done; DNG committing (`phase == .savingDNG`) | busy readout near thumbnail | `SAVING DNG — WAIT.` **(P)** | `caption` | `ink` | `—` (locked) |
| **S15** | capture error: `missingImageData` / `captureFailed` / `deviceLockFailed` / `captureInProgress` / `sessionNotConfigured` | error banner **inside** the `isConfigured` gate | `The captured photo contains no image data.` / `The photo could not be captured: <desc>` / `The camera could not be configured: <desc>` / `A photo is already being captured.` / `The capture session is not configured yet.` **(O `CaptureService.swift:749/751/765/753/759`)** · `RETRY` | `body` · `label` | `fail` (body) · `ink` (RETRY) | `RETRY` WordControl ≥44×44 |
| **S16** | `PhotoLibraryManager.save` throws | error banner | `Photos rejected the DNG save: <message>` **(O `PhotoLibraryManager.swift:171`)** / `The DNG was saved to Photos but the capture record could not be committed; it will be recovered on the next refresh.` **(O `:177`)** · `RETRY` | `body` · `label` | `fail` · `ink` | `RETRY` WordControl ≥44×44 |
| **S17** | PhotoCapture 15s watchdog fires | error banner | `The photo capture did not complete in time.` **(O `CaptureService.swift:755`)** · `RETRY` | `body` · `label` | `fail` · `ink` | `RETRY` WordControl ≥44×44 |
| **S18** | device storage exhausted at save | error banner | `STORAGE FULL — FREE SPACE THEN RETRY.` **(P)** · `RETRY` | `body` · `label` | `fail` · `ink` | `RETRY` WordControl ≥44×44 |
| **S19** | shutter with `zoomFactor > 1` (1× snap + 250ms settle) | framing notice over preview | `FRAMING — CAPTURING AT 1X.` **(P)** | `caption` | `ink` over `scrim` | `—` |
| **S20** | torch pulse during exposure; or torch unavailable | pulse (dark preview → flash); unavailable → banner | `This camera has no flash (torch).` **(O `CaptureService.swift:761`)** · `FLASH OFF` (control word) | `body` · `label` | `fail` (unavailable body) · `ink` (FLASH word) | `FLASH OFF|ON` WordControl ≥44×44 |
| **S21** | tap-to-focus unsupported (`focusExposureUnavailable`) | error banner | `This camera does not support tap-to-focus/exposure.` **(O `CaptureService.swift:763`)** · `RETRY` | `body` · `label` | `fail` · `ink` | `RETRY` ≥44×44; preview tap target = full preview |
| **S22** | shutter with self-timer armed (`phase == .countdown`) | 96 Bold tabular numeral, square, no disc, centred **(P: disc → `scrim`)** | `<3…1>` / `<10…1>` · `TAP TO CANCEL` · `OFF` `3S` `10S` **(O labels `CameraViewModel.swift:360-362`)** | `display` (numeral) · `caption` (TAP TO CANCEL, OFF/3S/10S) | `ink` numeral over `scrim`; `selectBg/selectInk` when timer selected | numeral ≥44×44 (`contentShape(Rectangle())`); timer WordControl ≥44×44 |
| **S23** | viewer presented; rendition developing | White room fullscreen; progress readout | `DEVELOPING` **(P)** | `caption` | `secondary` (or `ink`); **no red** | `—` |
| **S24** | develop failed (filter nil / output nil / decode) | White room failure surface; DATA sheet (S39) still reachable | `ERROR — UNABLE TO LOAD DNG` **(O base `GalleryView.swift:171`; `ERROR —` prefix P)** · `This capture could not be developed.` **(O `:173`)** · `BACK` `DELETE` `RETRY` **(P: RETRY missing today)** | `title` (ERROR — line) · `body` · `label` | white room: `ink` + `ERROR —` + Bold + `rule` above; **no red** | `BACK` / `DELETE` / `RETRY` WordControls ≥44×44 |
| **S25** | library first load (`isLoading && empty && error == nil`) | White room loading readout | `LOADING` **(P)** | `caption` | `secondary`; **no yellow** | `—` |
| **S26** | library empty (`captures` empty, no error) | White room empty state; **date header + DNG count readout + index chip retained (owner Q3)** | `0 / NO CAPTURES` **(P; `0` maps onto `display` — §6 #10)** · `CAPTURE A PHOTO TO BEGIN.` **(O base `:99`)** · `DNG 00 / 00` (count readout, **P**) · `<WEEKDAY DD MONTH YYYY>` (date header, **P**) | `display` (`0`) · `title` (NO CAPTURES) · `body` · `caption` (date, count) | white room `ink` / `secondary`; `rule` | `SHOOT` / `BACK TO CAMERA` WordControl ≥44×44 |
| **S27** | library load failed (empty+error) OR stale-grid banner | White room error surface / stale-grid banner | `ERROR — UNABLE TO LOAD LIBRARY` **(O base `:82`)** · `<dynamic description>` **(O `:84`)** · `RETRY` **(O `:89`)** · banner `ERROR — <message>` **(O `:123`)** | `title` · `body` · `label` · `caption` (banner) | white room error pattern (`ink` + `ERROR —` + Bold + `rule`); banner `rule` border; **no red** | `RETRY` WordControl ≥44×44 |
| **S28** | library permission revoked while open | stale-grid banner, distinct copy | `ERROR — ACCESS REVOKED. GRANT ACCESS, THEN RETRY.` **(P)** · `RETRY` | `caption` · `label` | white room error pattern; **no red** | `RETRY` WordControl ≥44×44 |
| **S29** | asset exists but DNG unreadable | viewer failure surface (S24) / grey cell | `ERROR —` + `The photo asset <id> is not available.` / `The photo asset <id> no longer exposes its original DNG resource.` / `Failed to load the original DNG: <message>` **(O `PhotoLibraryManager.swift:187/189/183`)** | `body` · `label` | white room error pattern; **no red** | `BACK` / `DELETE` ≥44×44 |
| **S30** | delete selected; last capture | confirmation dialog (system today) OR white-room designed confirm | `DELETE CAPTURE?` **(O `:51`)** · `DELETE` **(O `:52`)** · `CANCEL` **(O `:53`)** · `This removes the DNG from Pikicam.` **(O `:227`)** | `title` · `label` · `body` | white room: `DELETE` = `ink` Bold + `rule` (**NO RED**, owner §0.5 #6) | `DELETE` / `CANCEL` ≥44×44 |
| **S31** | delete in viewer; non-last | same dialog; success dismisses to grid | same as S30 | same | same | same |
| **S32** | device rotation during capture — **landscape DESIGNED (owner Q5)**, iPad OUT OF SCOPE | chrome reflows for landscape; provenance sampled at shutter press | `CAPTURED AS SHOT — ORIENTATION LOCKED.` **(P)** | `caption` | `ink` / `secondary` | `—` |
| **S33** | call arriving mid-capture | notice over preview | `INTERRUPTED — CAPTURE KEPT OR FAILED. CHECK LIBRARY.` **(P)** | `body` | `ink`; no `fail` | `—` |
| **S34** | app backgrounded mid-capture (countdown/capturing/savingDNG) | teardown; notice on return | `STOPPED — COUNTDOWN DISCARDED.` **(P)** | `body` | `ink` | `SHOOT` WordControl ≥44×44 (restart) |
| **S35** | thermal state elevated | notice over preview | `COOLING — CAPTURE PAUSED. WAIT.` **(P)** | `body` | `ink` / `secondary`; no `fail` | `—` |
| **S36** | Low Power Mode | notice; preview dimmed | `LOW POWER — PREVIEW DIMMED. CAPTURE STILL AVAILABLE.` **(P)** | `body` | `ink` / `secondary` | `—` |
| **S37** | thermal / low-storage system warning | system banner passes through; inline notice | `SYSTEM WARNING — SAVE MAY FAIL. FREE SPACE.` **(P)** | `body` | `ink` / `secondary` (warning); `fail` only if the save itself fails | `—` |
| **S38** *(NEW)* | hardware volume button pressed while camera active **(owner Q4)** | **system volume HUD ACCEPTED — not suppressed**; capture fires | `—` (system HUD is system-owned) | `—` | `—` | `—` in-app (hardware button) |
| **S39** *(NEW)* | viewer per-image provenance sheet shown **(owner: FULL sheet; bypass STATED here)** | White room sheet, toggled by `HIDE|SHOW` | full row set in §3 | `label` (row keys) · `body` (values) · `caption` (recipe rows) | white room `ink` / `secondary`; `rule` per row; **no red** | `HIDE|SHOW` WordControl ≥44×44 |

---

## §3 — S39 · the viewer provenance sheet (full row set — §6 #15, owner DATA-sheet ruling)

The owner **rejected** the §0.4/§0.6 strip-to-raw-DNG-tags deletion. The sheet is the **full provenance sheet**, and it is the **only place the bypass is stated**:

| key | value shape | provenance |
|---|---|---|
| `FILE` | `pikicam-<uuid>.dng` | **(O)** `PhotoLibraryManager.swift:886` |
| `BYTES` | `<byte count>` (e.g. `24 117 888`) | **(P)** |
| `SENSOR` | `4000×3000 FULL-SENSOR RETAINED` | **(P)**; dimensions **(O)** `PikicamCapture.pixelWidth/pixelHeight` (`PhotoLibraryManager.swift:96-97`, `:405-406`) |
| `BAYER` | `14-BIT RGGB` | **(P)**; 14-bit Bayer **(O)** `CaptureService.swift:638-641` |
| `EXPOSURE` | `1/120 · f/1.9 · ISO 64` | **(P)** |
| recipe list | the zero-process recipe, one row per surviving conversion stage | **(O)** retained stages `CIRAWZeroProcessor.swift:8-13` |

**Bypass statement.** On the camera chrome the bypass is expressed by **absence** (no manifesto strip, §0.5 #12). On this sheet it is **stated**: the conversion line — demosaic · black-level · color matrix · AsShotNeutral WB — and the enhancement list at neutral. Never ship unqualified `NO PROCESSING`; the sheet states `NO ENHANCEMENTS — CONVERSION ONLY`.

---

## §4 — Table B · coverage (room · affordance · no-op · screen · verified code handling)

| ID | room | affordance (words) | no-op | screen | code handling (verified — R1) |
|---|---|---|---|---|---|
| S01 | black | `CONTINUE` | stays on interstitial | Permissions interstitial | **OBSERVED** `RootView.swift:16 / :75 / :77` all **CONFIRMED** |
| S02 | black | answer system ALLOW/DENY | app waits | Permissions interstitial | **OBSERVED** `CameraViewModel.swift:119` (**LINE_DRIFT**, v1 cited `:118`) · `:120` **CONFIRMED**. Busy UI: **NOT-OPENED → NO HANDLING** |
| S03 | black | `OPEN SETTINGS` | stays denied until granted in Settings | PermissionsDeniedView | **OBSERVED** `RootView.swift:20 / :96 / :104` **CONFIRMED** · `CameraViewModel.swift:49` (**LINE_DRIFT**, v1 `:48`) · `:50` **CONFIRMED** |
| S04 | black | `—` | stays denied; Settings cannot fix | PermissionsDeniedView | **OBSERVED branch** `RootView.swift:20`; comment `CameraViewModel.swift:101-102` **CONFIRMED**. **NO distinct copy** |
| S05 | black | `—` | stays denied | PermissionsDeniedView | **OBSERVED gate** `CameraViewModel.swift:50` **CONFIRMED**. **NO distinct copy** |
| S06 | black | `CONTINUE` shooting / manage in Settings | works with visibility gaps | Camera | **OBSERVED pass** `CameraViewModel.swift:50` **CONFIRMED**; **NO limited notice** |
| S07 | black | `—` (automatic) | auto-enters camera if granted | Denied → Camera | **OBSERVED** `RootView.swift:43 / :44 / :45` **CONFIRMED** |
| S08 | black | `RETRY` | black preview persists | Camera | **OBSERVED** `CaptureService.swift:747` (**LINE_DRIFT**, v1 `:746`) · `:739` (**LINE_DRIFT**, v1 `:738`) · `:507` **CONFIRMED** · `:120` **CONFIRMED** |
| S09 | black | `RETRY` / wait | best-effort auto-resume when clear | Camera | **OBSERVED flags** `CaptureService.swift:194 / :196` **CONFIRMED**; resume guard `:205` (**LINE_DRIFT**, v1 `:204`). **NO UI** |
| S10 | black | wait | session restarts on `.active` | Camera | **OBSERVED** `RootView.swift:47 / :48` **CONFIRMED**. **NO notice** |
| S11 | black | `RETRY` | frozen preview until next start | Camera | **OBSERVED flags** `CaptureService.swift:184 / :185 / :187` **CONFIRMED**; reconcile `:159` **CONFIRMED** |
| S12 | black | `RETRY` | reconciled on explicit start | Camera | **OBSERVED** `CaptureService.swift:158 / :159-161` **CONFIRMED**. **NO UI** |
| S13 | black | wait (controls locked) | completes to savingDNG then idle/error | Camera | **OBSERVED** `CameraViewModel.swift:26 / :263` **CONFIRMED** · `CaptureService.swift:500` **CONFIRMED**. **NO busy UI** |
| S14 | black | wait | auto-selects new capture; phase idle | Camera | **OBSERVED** `CameraViewModel.swift:284 / :285 / :287 / :289` **CONFIRMED**. **NO progress UI / timeout** |
| S15 | black | `RETRY` (shutter) | error clears on next idle shutter | Camera | **OBSERVED** `CaptureService.swift:749/751/765/753/759` (**LINE_DRIFT +1** across the error-string switch; v1 `:748/750/764/752`) · clear `CameraViewModel.swift:255` **CONFIRMED** |
| S16 | black | `RETRY` | stays in error; no DNG published | Camera | **OBSERVED** call + path `CameraViewModel.swift:285 / :300` **CONFIRMED**; strings **now cited** `PhotoLibraryManager.swift:171 / :177 / :179` **OBSERVED** (v1: NOT-OPENED) |
| S17 | black | `RETRY` | error banner until next shutter | Camera | **OBSERVED** `CaptureService.swift:755` (**LINE_DRIFT**, v1 `:754`); watchdog **now cited** `PhotoCapture.swift:34` `captureTimeout = .seconds(15)` **OBSERVED** |
| S18 | black | `RETRY` / free space | capture fails; error persists | Camera | **NO HANDLING** as a distinct state. Closest generic `CaptureService.swift:751` **(O)** |
| S19 | black | wait | FOV jumps to 1×, waits, exposes, restores | Camera | **OBSERVED** `CaptureService.swift:518 / :519 / :521 / :530 / :589` **CONFIRMED**. **NO explanation copy** |
| S20 | black | `FLASH OFF` / `RETRY` | torch forced off after; failure swallowed | Camera | **OBSERVED** `CaptureService.swift:761` (**LINE_DRIFT**, v1 `:760`) · `:543 / :545 / :555` **CONFIRMED** · `:369` **CONFIRMED** |
| S21 | black | `RETRY` / continue without tap | error banner | Camera | **OBSERVED** `CaptureService.swift:763` (**LINE_DRIFT**, v1 `:762`) · `:384` **CONFIRMED** |
| S22 | black | `TAP TO CANCEL` (shutter or numeral) | counts then exposes; cancel returns idle | Camera | **OBSERVED** `CameraViewModel.swift:360 / :361 / :362 / :318 / :332 / :252` **CONFIRMED**. Disc/`.rounded` `CameraView.swift:482 / :486` **CONFIRMED** |
| S23 | white | wait | resolves to image or S24 | Viewer | **OBSERVED** `GalleryView.swift:178 / :229 / :235` **CONFIRMED** |
| S24 | white | `BACK` / `DELETE` / `RETRY` (**P**) | stuck on failure view until navigation | Viewer | **OBSERVED** `GalleryView.swift:171 / :173 / :176` **CONFIRMED** · `CIRAWZeroProcessor.swift:31 / :37` **CONFIRMED**. **NO retry** |
| S25 | white | wait | grid or S26/S27 | Gallery | **OBSERVED** `GalleryView.swift:75 / :77` **CONFIRMED** |
| S26 | white | `SHOOT` | stays empty | Gallery | **OBSERVED** `GalleryView.swift:99` **CONFIRMED** |
| S27 | white | `RETRY` | retry re-runs refresh; stale grid stays under banner | Gallery | **OBSERVED** `GalleryView.swift:82 / :89 / :123 / :124 / :131 / :132 / :70` **CONFIRMED** |
| S28 | white | `RETRY` / open Settings | grid goes stale/error on next refresh | Gallery | **NO HANDLING** as distinct copy. Re-read `RootView.swift:43` **CONFIRMED**; gate `:20` **CONFIRMED** |
| S29 | white | `BACK` / `DELETE` | failure view persists | Viewer / grid cell | **OBSERVED** `GalleryView.swift:234 / :242` **CONFIRMED**; manager strings **now cited** `PhotoLibraryManager.swift:187 / :189 / :183` **OBSERVED** |
| S30 | white | `DELETE` / `CANCEL` | delete commits, viewer closes; empty state (S26) | Gallery / Viewer | **OBSERVED** `GalleryView.swift:51 / :52 / :53` + `:216 / :227 / :219 / :221` **CONFIRMED** |
| S31 | white | `DELETE` / `CANCEL` | grid reflects removal; **failure is silent in viewer** | Viewer | success **CONFIRMED** (lines above). **NO in-viewer failure feedback**: `PikicamLibraryModel.deleteSelected` sets `error` at `:65` (**O**), the viewer renders none |
| S32 | black | `—` | orientation tag may mis-tag if rotated mid-exposure | Camera | **OBSERVED** `CameraViewModel.swift:281` **CONFIRMED**; fallback `CaptureService.swift:599-601` **OBSERVED**. **NO landscape chrome designed** (Info.plist already permits landscape on iPhone — **O** `Info.plist:38-41`) |
| S33 | black | wait / `RETRY` | session does not auto-resume until explicit start | Camera | **OBSERVED** `CaptureService.swift:205` guard includes `!isCaptureInFlight` (**LINE_DRIFT**, v1 `:204`). **NO call-specific copy** |
| S34 | black | restart (`SHOOT`) | countdown zeroed, capture cancelled, session stopped | Camera | **OBSERVED** `CameraViewModel.swift:142 / :143 / :145 / :146` **CONFIRMED**. **NO confirmation** |
| S35 | black | wait | captures slow/fail generically until cool | Camera | **NO HANDLING** — no thermal API anywhere in `pikicam/` (**O** grep). The absence is the finding |
| S36 | black | continue / wait | no behaviour change today | Camera | **NO HANDLING** — no `ProcessInfo`/Low-Power read (**O** grep) |
| S37 | black | dismiss (system) / free space | system alert dismisses; capture likely fails S18 | Camera / Gallery | **NO HANDLING** — no observer |
| S38 | black | volume press (hardware) | capture fires; system HUD shows and volume audibly changes | Camera | **OBSERVED** `VolumeButtonCaptureView.swift:9-11` (HUD not suppressed) **CONFIRMED**; call site `CameraView.swift:221-226` **OBSERVED** |
| S39 | white | `HIDE` / `SHOW` | sheet stays as toggled | Viewer | **OBSERVED** chrome toggle `GalleryView.swift:196-199` **CONFIRMED** (`viewer-chrome-toggle`; rename → `viewer-hide-show` pending). Sheet content **(P)** |

Provenance note for Table B: **code handling is OBSERVED**; every **surface/word/type/ink/hit-area treatment that has no code today is PROPOSAL**, tagged per-state in Table A.

---

## §5 — Likelihood rank (most-hit first)

1. **S06** Photos limited grant — default iOS path; silently changes visibility. Placement unruled.
2. **S03/S04/S05** denied/restricted — every fresh install; restricted copy must not promise Settings.
3. **S13/S14** capture busy + saving — every shutter passes through; needs honest busy treatment (today silent lock).
4. **S25/S26/S27** gallery loading/empty/failed — every new user; failures need Retry.
5. **S24/S29** develop/read failure — the zero-process promise breaks on a dead end; today `GalleryView.swift:171` has no Retry.

---

## §6 — Code-citation audit (critic #12)

Every per-state code line was re-opened and re-read (the E channel's whole evidence base).

- **Citations verified:** **62** · **CONFIRMED:** 50 · **LINE_DRIFT:** 12 · **REFUTED:** 0 · **NOT-OPENED → now resolved:** 4.
- **LINE_DRIFT (v1 line → real line):** `CameraViewModel.swift:118→119` (S02) · `:48→49` (S03) · `CaptureService.swift:738→739`, `:746→747` (S08) · `:204→205` (S09, S33) · `:748→749`, `:750→751`, `:752→753`, `:754→755`, `:760→761`, `:762→763`, `:764→765` (S15, S17, S20, S21). All drift is **+1**: a line was inserted above the `errorDescription` switch in `CaptureService` after v1 was written. The claims are true; the v1 numbers are wrong and are corrected in Tables A/B.
- **REFUTED:** none — the state matrix's own citations contain no false claim. (The 7 REFUTED in `VERIFICATION.md §2.1` are against `.P.DESIGN` §4/§10, not this file.)
- **Now citable (were NOT-OPENED):** S16 save strings `PhotoLibraryManager.swift:169/171/177/179`; S17 watchdog `PhotoCapture.swift:34`; S29 read strings `PhotoLibraryManager.swift:183/187/189`; S31 failure path `PikicamLibraryModel.swift:54-71`.
- **Unconfirmable-as-stated:** none of the six-field cells depends on a line I could not read.

---

## §7 — Honest-bypass note (updated)

- The bypass is expressed by **ABSENCE on the camera chrome** (no manifesto strip, §0.5 #12) and **STATED on the viewer's per-image sheet** (S39, owner ruling).
- Zero-process neutralizes the declared enhancement set — `CIRAWZeroProcessor.swift:63-81` **(O)** — and retains demosaic / black-level / color matrix / AsShotNeutral — `:8-13` **(O)**.
- **`baselineExposure` — PROPOSAL, not settled.** Owner ruling and `VERIFICATION.md §5`: do not override a file-derived decoder default without cause. The recipe currently sets `baselineExposure = 0.0` (`CIRAWZeroProcessor.swift:65`, **O**) — an active override, not a no-op. **PROPOSAL:** remove `baselineExposure` from the neutralize list so the decoder's file-derived baseline is respected; replace the "assert == 0" test with a "left untouched" test; keep the flagged alternative on record. This is **not** to be presented as OBSERVED and was not measured on-device.
- **R3 defect (either way):** the header comment `CIRAWZeroProcessor.swift:8-13` lists only four operations while the recipe also zeroes `baselineExposure` (plus 14 more). The comment overstates its own case and must be corrected regardless of the verdict.

---

## §8 — BLOCKED-ON-OWNER

**Zero states are blocked on their six fields.** Owner Q4 (volume HUD accepted) and Q5 (landscape designed; iPad out of scope) have unblocked S38 and S32. §10 #1's permission-interstitial layout and §10 #5's limited/restricted placement are now specified as PROPOSALs rather than left blank.

Sub-surfaces that are **system-owned and therefore not designable** (not owner decisions): the two permission sheets and their back-to-back ordering (S02), the system volume HUD (S38), the system storage/thermal warnings (S37), and the share sheet. These are stated as `—` with the system named, never invented.

---

## §9 — Unresolved (for owner confirmation, not blocking)

1. **S04/S05 restricted copy** and whether restricted is rendered with `fail` (`#EA0000`) or plain `ink` + `rule`. Owner §0.5 #6 governs red **only** for the white room; the black-room failure rule permits red. Applied: plain `ink` + `rule`; confirm.
2. **S06 limited-notice placement** — proposed as a top-bar `caption` readout (`PHOTOS — LIMITED`); the placement is unruled (§10 #5).
3. **S22 countdown disc.** v1 carried a `Circle()` disc; the design deletes it (radius 0, §2.5). The countdown numeral now sits over the `scrim`. Confirm the scrim is sufficient contrast in the black room.
4. **S30/S31 destructive `DELETE`** — applied as `ink` Bold + `rule` (NO RED, owner §0.5 #6). Confirm the destructive affordance is strong enough without red.
5. **White-room dark-appearance ink** (VERIFICATION §6 #4). §2.1 promises explicit dark pairs, but the sources disagree (`spec-camera:41` `#A6A6A6` vs `spec-gallery:81` `#A8A8A8`) and the canonical scale supplies no dark column for the white room. The state matrix supplies none either; a dark-appearance ink set must be pinned before the lint can snapshot it.
6. **S26 empty-state count literal** (`DNG 00 / 00`) is authored; the exact zero-count rendering is unruled.
7. **En dash glyph** for S38's line-items and the provenance legend uses `—`; confirm the U+2014 vs `--` house spelling across chrome.

