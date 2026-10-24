# VERIFICATION — `docs/.P.DESIGN.md` against the code

**Type:** research artifact. **NOT authority.** Per R1, the code is the only authority; this file is evidence *about* a document, nothing more.
**Produced:** 2026-10-01 by a 9-agent workflow (5 citation verifiers · 2 `baselineExposure` researchers · 1 adjudicator · 1 completeness critic). 696k subagent tokens, 126 tool uses, 0 errors.
**Consumes:** `docs/.P.DESIGN.md`, its five spec files, `docs/design/research/*`, and the working tree.
**Feeds:** the DESIGN-LOCK workflow. **Every correction in §6 is an instruction the locked spec must apply.**
**Raw ledger:** `docs/design/research/verify-ledger.md` — all 90 citation verdicts, machine-generated.

---

## §0 — Method

Every agent was bound by one hard rule: **the code is the only authority; a doc claim is CONFIRMED only if the agent opened the real file.** Verdicts: `CONFIRMED` · `LINE_DRIFT` (true, cited line wrong) · `REFUTED` (false) · `UNVERIFIABLE` (not a code claim). Nothing in this document is a claim about the doc's *taste* — only about its *facts*.

Five verifiers covered in-repo code lines: the §0.2 in-code inventory + §2.3 ink table; §3 camera geometry + flash + error banner; §4 identifiers + the UI-test contract; §1.8/§10 behavioral claims; Appendix B/C. Two researchers covered Apple's `CIRAWFilter.baselineExposure` documentation and the DNG tag. One adjudicator ruled on it. One critic swept the substrate **no verifier opened** — the §0.2 external fetch claims, the §2 DERIVED ratios and token provenance, the §0.5 rulings' spec-file evidence base, and the 37-state matrix.

---

## §1 — Headline

| | Count |
|---|---|
| Citations checked | **90** |
| CONFIRMED | **81** |
| LINE_DRIFT | 1 |
| REFUTED | **7** |
| UNVERIFIABLE | 1 |
| Independent findings from the critic | **16** |

**The doc's code discipline is ~90% honest, and its external substrate is mostly sound** — an unusual result given the project's history. But the defects below are exactly the class that would have been copied into the locked spec and then read by every agent downstream as fact.

The two most important findings are **not** citation errors: (a) **the UI test suite is red right now** (§4), and (b) **two stylesheet token names are fabricated** (§3 #1) — the precise failure Appendix A exists to prevent.

---

## §2 — REFUTED and drifted citations

### §2.1 — REFUTED (7)

| # | Where | The doc claims | Reality |
|---|---|---|---|
| R1 | §4 row 1 | removing `gallery-latest-thumbnail` "breaks `SmokeLaunchTest.swift:217`" | **False.** Line 217 is `app.buttons["camera-library"]` (HEAD: `app.buttons["gallery-thumbnail"]`). `gallery-latest-thumbnail` is referenced **only** at `GalleryView.swift:28`; **no test references it**. The doc conflated `gallery-thumbnail` (`CameraView.swift:196`) with `gallery-latest-thumbnail` (`GalleryView.swift:28`) — two different controls. |
| R2 | §4 row 8 | the UI tests contain `app.activityIndicators.firstMatch` | **False in the current tree.** `SmokeLaunchTest.swift:305` is `app.activityIndicators["viewer-loading"]`. The `.firstMatch` form existed **only at HEAD:305**. |
| R3 | §4 row 9 | the shutter is assigned `camera-shutter` | **False in code.** No identifier modifier at the call site (`CameraView.swift:201`); `camera-shutter` appears only in `ControlIDRegistry.swift:37`. The shutter exposes only `.accessibilityLabel("Capture photo")` (`ShutterButton.swift:33`). Yet the tests query `app.buttons["camera-shutter"]` (`SmokeLaunchTest.swift:121,124,527,530`) — so **this assertion cannot pass**. |
| R4 | §0.5 #10 | "rename + update the tests in the same change — applied" | **False.** The tree is mid-migration; see §4. |
| R5 | §10 #7 | `watchInvalidation` mutates the grid **and selection** | **Half false.** `refresh()` (`PikicamLibraryModel.swift:26-41`) writes only `isLoading`/`captures`/`error`. `selectedCapture` is assigned only in `select():51` and `deleteSelected():58`. The **grid** half is real; the **selection** half is not. |
| R6 | §10 #7 | the grid `ForEach` id is non-stable under `assetID` churn | **False.** `GalleryView.swift:107` keys on `\.element.id.uuid` = `CaptureID.uuid`, generated once at save (`PhotoLibraryManager.swift:297`) and persisted, re-used on fetch (`:473`). It is stable and independent of `PHAsset` churn. The value that *does* shift is the accessibility `index` in `gallery-cell-\(index)` (`GalleryView.swift:115`). |
| R7 | §1.8 / §10 #7 | `DevelopService` "currently leaks" on viewer dismissal | **False.** It is `@State`-owned inside `FullScreenViewer` (`GalleryView.swift:154`) and released on dismissal. The **real** defect is different and worse for a camera app: its default initializer rebuilds a **Metal-backed `CIContext` on every `FullScreenViewer` struct init**, i.e. on every re-evaluation of the cover body while presented. Also, §1.8's cross-reference "see §10 #7" is **broken** — §10 #7 never mentions `DevelopService`. |

### §2.2 — LINE_DRIFT (1)

- **§0.2, `CameraHUDButton.swift:18`** — the "white glyph" is not at :18. `:17` is the glyph `Image`, `:19` is `.foregroundStyle(.white)`; `:18` is `.font(.system(size: 17, weight: .medium))`. `:21` (`.background(.black.opacity(0.45), in: Circle())`) and `:23` (rounded caption font) are exact. Substantively true, wrong line.

### §2.3 — UNVERIFIABLE (1) — reclassify, don't delete

- **§3's "closed vocabulary"** is a **PROPOSAL**, not a description of code. Every word (`GRID ON|OFF`, `FLASH OFF|ON`, `TIMER OFF|3S|10S`, `1.0X`, `LIBRARY`, `DELETE`, `RETRY`, `BACK`, `DNG`) differs in case or wording from the strings that exist today (`Flash Off`/`On` `CameraControls.swift:64-65`; `Timer Off`/`3s`/`10s` `CameraViewModel.swift:358-363`; zoom `%.1fx` `:97`; `"Library"` `GalleryView.swift:49`; `"Retry"` `:89`; `"Back to Camera"` `:208`; `"DNG Viewer"` `:194`). Per R7 it must be tagged **PROPOSAL**.

---

## §3 — The completeness critic's 16 findings

The entire non-code substrate the locked spec inherits was opened by **no verifier**. The critic checked it directly. Ranked as the critic ranked them.

### Fabrications and vacuous criteria — defeat the spec's own R2/R7 discipline

**#1 — §0.2 L40-41 FABRICATES two stylesheet token names.** `--color-mm-base-strong-grey` and `--color-mm-base-light-grey` **do not exist**. The critic curled the pinned URL (HTTP 200, 2.94 MB) and grepped: zero hits for either name. The real names are **`--color-mm-base-neutral-500: #6c6c6c`** and **`--color-mm-base-neutral-100`** / `--color-mm-base-neutral-100-alpha-60: #e5e5e5`. The doc's own source (`spec-camera-screen-spec.md:41`) uses the correct name — so the doc *renamed* a sourced value while presenting it as OBSERVED. **§2.3's white-room `secondary #6C6C6C` (ruling #4) is built on the invented name.**

**#11 — §5/§11's completeness gate is UNSATISFIABLE.** §5 L516 and the §11 exit criterion (L699) require every state to specify six fields, including a separate *hit area* and *type token*. `spec-state-matrix.md` has **no hit-area column** and folds type+ink into the single "what the user sees" prose cell. **No state can satisfy the gate as written** — the criterion is vacuous, and DESIGN-LOCK could never terminate against it. *(Count of S01–S37 = 37 is correct.)*

### Contradictions the lint would encode

**#4 — §2.1 L345 promises white-room dark pairs that §2.3 never provides.** §2.3's WHITE-room table has no dark column, and the sources disagree (`spec-camera:41` says `#A6A6A6`; `spec-gallery:81` says `#A8A8A8`). §6 requires honouring both appearances, so the locked spec has **no white-room dark ink to implement**.

**#6 — §2.4 L407 "rules appear in exactly four places … nowhere else" is contradicted twice.** §0.5 #6 and §3 place a `1/displayScale` rule **above the error banner**; §8.4 adds a stale-grid banner border. That is a 5th/6th location, breaking the `exactly four` constraint the lint is meant to enforce.

**#5 — §2.5 L413's "whole surviving set is deleted" list is INCOMPLETE.** Omitted, all verified present in code and in the doc's own source: `CameraView.swift:417` `Capsule()` (EV track), `:444` `.clipShape(Capsule())` (EV bubble), `:423` tick `Circle()`, and `ZoomIndicatorView.swift:15` `.background(.black.opacity(0.45), in: Capsule())`. The lint's `capsuleOrCircleShape` rule depends on a **complete** list.

### Wrong values locked in two places

**#3 — the same pair is stated two ways.** §0.2 L53 says `#595959` on `#FCFCFC` = **6.83:1**; §0.5 #4 (L125) and §2.3 (L391) say **6.82:1**. Recomputing WCAG gives 6.8305 → **6.83**. The Increase-Contrast figure is locked **wrong** in two places.

**#16 — §0.2 L54's `#6C6C6C` on `#FFFFFF` = 5.25:1 row is vestigial.** Ruling #3 set the white-room bg to `#FCFCFC`, not `#FFFFFF`. The operative pair is `#6C6C6C` on `#FCFCFC` = 5.12:1.

### Rulings that misfire

**#8 — §0.5 #6 cites `spec-a11y:131` as support, but that line says the OPPOSITE.** It reads *"gallery trash `:37` … stay red in both modes"* — i.e. it **keeps** red in the white room, the opposite side of the ruling. (All 12 rulings were spot-checked by the critic; this is the one whose cited evidence misfires.)

**#9 — §0.5 #5 silently resolves an open question.** It locks "3 portrait / 5 landscape" and **drops** the "iPad 4 portrait / 6 landscape" its own cited source (`spec-gallery:137`) contains — while §0.6 Q5 still lists iPad as an unresolved owner decision. *(The owner has since ruled iPad out of scope — so this is now settled, but the resolution must be stated explicitly.)*

**#10 — §0.5 #7 deletes `DISPLAY-28`, orphaning a rendered element.** The canonical 6-token scale has no 28 pt and forbids sans (§2.2 L351), so §8.1's empty-state `0` numeral **maps onto no token**. The "re-express as maps onto it" mandate is unexecuted for a concrete element.

### Unpinned and incomplete

**#2 — §0.2 L44 mis-attributes the `@font-face` claim.** It says the weight-400 `@font-face` is OBSERVED "in that stylesheet" (`global.css`). `global.css` has exactly one `@font-face` and no `CourierNewRecast` face; the Recast weight-400 declarations are in **`fonts.css`** (`spec-gallery:91` says "global.css + fonts.css"). Load-bearing for §2.2's "Recast cannot ship".

**#7 — §2.2 L357-360 gives tracking only as em/1000** (`+40`, `+80`). The deliverable `.tracking(...)` (§7) needs **pt**, and the em→pt values (0.68 / 1.04 / 0.88 pt) exist **only in the spec files** (`tokens:61-64`), not in the doc. A locked spec built from the doc alone cannot compute tracking.

**#12 — the state spec's per-state code citations — the E-channel's entire evidence base — were opened by no verifier.** e.g. S01 `RootView.swift:16/75/77`, S03 `RootView.swift:20/96/104` + `CameraViewModel.swift:48/50`, S19 `CaptureService.swift:518-530`, S30 `GalleryView.swift:51-53`, S23 `GalleryView.swift:178/229/235`. §5 re-imports only the spec's likelihood ranking, never its code lines.

**#13 — §3 L450's "closed set — nothing outside it renders" is not closed.** It omits `SHARE` (§4 L486), `HIDE|SHOW` (§3 L452, §4 L486), and `CAMERA FRONT|BACK` (L448/L452) — three families the doc itself renders.

**#14 — the shutter identifier is three-way divergent:** `camera-shutter` (§4 L506, §1.1 L178), `shutter` (`spec-camera:100`), `gallery-shutter` (`spec-a11y:60`). Ruling #10 is entirely about identifier movement, and no verifier caught the three names. *(Code: the shutter has no identifier at all.)*

**#15 — §4 L490 says the DATA sheet is "stripped to raw DNG tags" and lists only what is DELETED.** The residual row set the locked sheet must render is never stated. *(The owner has since ruled **full** provenance sheet — which supersedes this and makes the question moot, but the locked spec must state the full row set.)*

---

## §4 — Live repo state: the UI suite is red

This is not a documentation defect. It is a **present-state defect in the working tree.**

§0.5 #10 says the rename and the test update happen "in the same change — applied." **Half of it is applied: the tests were flipped, the views were not.** The new `ControlIDRegistry.swift` is referenced by **no view**.

| UI test expects (`SmokeLaunchTest.swift`) | View still renders | Where |
|---|---|---|
| `navigationBars["LIBRARY"]` (:220) | `.navigationTitle("Library")` | `GalleryView.swift:49` |
| `staticTexts["0 / NO CAPTURES"]` (:227) | `"No captures"` | `GalleryView.swift:99` |
| `buttons["room-shoot"]` (:233) | `"gallery-camera"` | `GalleryView.swift:45` |
| `buttons["viewer-hide-show"]` (:303) | `"viewer-chrome-toggle"` | `GalleryView.swift:199` |
| `buttons["camera-library"]` (:217) | `"gallery-thumbnail"` | `CameraView.swift:196` |
| `buttons["camera-shutter"]` (:121,124,527,530) | *(label only — see R3)* | `ShutterButton.swift:33` |

Still matching: `library-grid` (`GalleryView.swift:120`), `gallery-cell-*` (`:115`), `viewer-loading` (`:179`), `viewer-delete` (`:203`), `viewer-back` (`:210`).

**Owner decision (2026-10-01): leave the suite red and fix it during the wiring phase.** The red state is now *known* and must not mask new failures in the interim — the wiring phase is where both sides are replaced at once.

---

## §5 — `baselineExposure`

**Adjudicator verdict: `NEEDS_MEASUREMENT`.** Not a guess dressed as authority.

**What is settled (Apple docs, authoritative):** `CIRAWFilter.baselineExposure`'s default is **not** `0.0` — it "varies with camera settings" — and **`0` specifically denotes "linear response."** Therefore the current `filter.baselineExposure = 0.0` (`CIRAWZeroProcessor.swift:65`) is an **active override**, not a no-op, whenever the default is nonzero. The repo's own fixture carries **−0.302 EV**, so on at least that file the code changes the render.

**What is NOT settled — and the verdict actually turns on it:**
1. **Correspondence.** Apple documents **no mapping** between the property and the DNG `BaselineExposure` tag. The premise that the default *is* the file's tag value is unverified. If the default is a decoder-internal heuristic, "the file's radiometric floor" collapses and forcing 0.0 touches no file tag.
2. **Classification.** Apple lists `baselineExposure` beside plainly subjective knobs (`exposure`, `boostAmount`, `shadowBias`, `contrastAmount`) and never labels it radiometric vs rendering. Apple is silent.

**What the repo settles:** the code contract is only that *someone chose 0.0*. `PikicamPipelineTests.swift:494` requires `baselineExposure` in the recipe; `:566`/`:580-585` assert it ends at `0` (1e-4). No test requires it to remain nonzero. Capture writes **no** `BaselineExposure` tag (`CaptureService.swift:536/558` pass AVFoundation's DNG through untouched). No production code reads the property back. `docs/prompt-next.md:753-761` proposes the **opposite** (remove the zeroing) and asserts the default is "typically ~0.5–1.0 EV" — **uncorroborated and contradicted by the repo's own −0.302 fixture.**

**The measurement that settles it (two cheap steps, needs a device — the simulator's `CIRAWFilterImpl` does not implement every control):**
1. **Correspondence** — `exiftool -BaselineExposure -BaselineExposureOffset fixture.dng`; then read `CIRAWFilter(imageData:).baselineExposure` *without* setting it. If default ≈ tag, the property is file-derived.
2. **Classification** — develop the DNG twice (default vs `0.0`), render both to scene-referred linear float, compute the per-pixel ratio. **Uniform scalar ≈ 2^EV ⇒ brightness convention ⇒ not a floor ⇒ `0.0` is defensible.** **Spatially varying / channel-dependent / additive ⇒ radiometric floor ⇒ forcing `0.0` strips it ⇒ the tag wins.**

### Owner ruling: "adhere to best practice" — PROPOSAL

**Best practice for a RAW pipeline is not to override a file-derived decoder default without cause.** Absence of a decision is what "zero-process" means; `= 0.0` is a decision nobody has justified, and the file's own header comment contradicts it (see below).

**PROPOSAL — to be confirmed, not assumed:**
- **Remove `baselineExposure` from the neutralize list** so the decoder's file-derived baseline is respected — a one-line change.
- **Replace the "assert == 0" test** with a test asserting the property is **left untouched**.
- **Keep the flagged alternative on record:** `0` = "linear response" is *arguably* the most zero-process state; the measurement above is what decides.

**R3 defect regardless of the verdict:** `CIRAWZeroProcessor.swift:4-17` states that only demosaic / black-level / color-matrix / WB run, while the recipe **also** zeroes `baselineExposure`. The comment **overstates its own case** and must be corrected either way.

---

## §6 — Corrections register (the locked spec must apply these)

1. Rename the two fabricated tokens to `--color-mm-base-neutral-500` / `--color-mm-base-neutral-100`; re-tag §2.3's white-room `secondary` provenance.
2. Re-attribute the `@font-face` observation to `fonts.css`.
3. Lock the Increase-Contrast ratio at **6.83:1** everywhere; delete the vestigial `#FFFFFF` row.
4. Supply the white-room **dark-appearance** ink values §2.1 promises.
5. Complete the shape-deletion list (add `CameraView:417,444,423`; `ZoomIndicatorView:15`).
6. Move to "rule locations: top bar, bottom dock, viewer metadata, blank-tag border, **above error banner**, grid-banner border" — or drop the "exactly four" claim.
7. Give tracking in **pt** as well as em.
8. Correct §0.5 #6's cited evidence (or re-open the red-in-white-room question).
9. State the iPad resolution explicitly (owner: out of scope).
10. Map the empty-state `0` numeral onto a real token.
11. **Redefine the completeness gate** — add a hit-area field to the state matrix, or change the criterion. **DESIGN-LOCK cannot terminate until this is fixed.**
12. Verify the state spec's per-state code citations before importing them.
13. Close the vocabulary: add `SHARE`, `HIDE|SHOW`, `CAMERA FRONT|BACK`.
14. Resolve the shutter identifier to **one** name (`camera-shutter`, and the views must actually emit it).
15. State the DATA sheet's **full** residual row set (owner ruled: full provenance sheet).
16. Reclassify §3's vocabulary as **PROPOSAL** (R7).
17. Per §2's refutations: correct the identifier-breakage claims (R1–R3) and the three false §10/§1.8 claims (R5–R7).
18. Fix the `baselineExposure` decision per §5, and correct the header comment regardless.

---

## §7 — Safe to build on (independently CONFIRMED)

The critic verified these directly, so the locked spec may rely on them:

- **Courier New** appears as "Version 5.00.2x / iOS system font" on Apple's fonts page.
- **WCAG**: "at least 4.5:1" / "at least 3:1" with large text = "at least 18 point or 14 point bold".
- **NN/g**, verbatim: "Icon labels should be visible at all times, without any interaction from the user."
- The stylesheet really contains `--color-mm-base-off-white: #fcfcfc`, `--color-mm-base-red: #ea0000`, `--mm-header-height: 60px`, `.rounded-0`, `.text-decoration-underline`.
- **All four §0.2 DERIVED ratios recompute exactly**: 5.12 / 6.83 / 5.25 / 1.23.
- All 12 §0.5 ruling quotes trace to the spec files (except #6's evidence, §3 #8 above).
- The §0.2 in-code inventory and the §3 deletion list are **grounded in the code as written** (23/24 and 28/29 confirmed); Appendix B and C hold up entirely; and the two ADRs + `CONTEXT.md` **never existed** as tracked files.

---

## §8 — Full identifier rename surface

Every `accessibilityIdentifier` string literal currently in `pikicam/`, extracted by verifier 3. This is the complete set the wiring phase must migrate onto `ControlIDRegistry`.

**Direct literals** — `zoom-indicator` (`ZoomIndicatorView.swift:16`) · `preview-pinch-area` (`CameraView.swift:85`) · `gallery-thumbnail` (`CameraView.swift:196`) · `aspect-overlay` (`CameraView.swift:392`) · `exposure-slider` (`CameraView.swift:449`) · `self-timer-countdown` (`CameraView.swift:489`) · `grid-overlay` (`GridOverlayView.swift:41`) · `gallery-latest-thumbnail` (`GalleryView.swift:28`) · `gallery-trash` (`:40`) · `gallery-camera` (`:45`) · `gallery-loading` (`:78`) · `gallery-error` (`:87,134`) · `gallery-retry` (`:95,128`) · `gallery-empty` (`:101`) · `library-grid` (`:120`) · `viewer-load-failure` (`:176`) · `viewer-loading` (`:179`) · `viewer-background` (`:190`) · `viewer-chrome-toggle` (`:199`) · `viewer-delete` (`:203`) · `viewer-back` (`:210`).

**Interpolated families** — `zoom-preset-\(ZoomMath.label(for:))` (`CameraView.swift:146`) · `mode-\(ratio.rawValue)` (`:164`) · `gallery-cell-\(index)` (`GalleryView.swift:115`).

**Via `CameraHUDButton(identifier:)`** — `front-camera-toggle` (`CameraView.swift:211`) · `grid-toggle` (`:251`) · `flash-toggle` (`:259`) · `self-timer-toggle` (`:268`).

**No identifier at all** — the shutter (`ShutterButton.swift`, label only).

---

## §9 — Handoff to DESIGN-LOCK

The locked spec's **exit criterion must change**: §11's "every state specifies six fields" is unsatisfiable against the current state-matrix format (§3 #11). DESIGN-LOCK must first **define the six fields against a matrix format that has them** (add a hit-area column), or the gate is vacuous and the workflow cannot terminate honestly.

With the 18 corrections in §6 and the owner's 16 rulings applied, DESIGN-LOCK's other criteria — zero unresolved contradictions, every fg/bg pair computed, every symbol house-name-free, the identifier/test diff complete — become reachable for the first time.
