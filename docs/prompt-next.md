# pikicam — next work order

**Input to a workflow. Everything below is either a standing rule, a proven fact, or an open decision.**
Generated 2026-10-01 after `wf_5f827395-9af` (deep audit, 155 agents, 6.88M subagent tokens)
and `wf_5936906f-fbc` (UX gap sweep) completed. Findings appendix is machine-generated
from the workflow result — do not hand-edit it.

---

## 0. READ THIS FIRST — what the two sweeps actually established

| | |
|---|---|
| Raw findings | 107 |
| Adversarially confirmed | **87** |
| Refuted | **15** |
| Critic (second-lens) | **8** |
| Agents that died and were retried 6× before giving up | **5** — these are an uncovered set, not a pass |

**Line numbers in the appendix describe the tree BEFORE this session's edits.** The finders ran
16:16–16:37; edits landed 19:20–19:23. Re-resolve every `file:line` against the current tree
before acting. Treat an unresolvable line as a finding to re-derive, not to drop.

### 0.1 The single most important fact in this document

A verifier enumerated the Objective-C runtime method list of a real
`CIRAWFilter(imageData:)` on the iOS 26.5 simulator. The instance class is
`CIRAWFilterImpl`. It implements:

```
setInputBaselineExposure:   setInputBoost:   setInputLocalToneMapAmount:
setInputEnableSharpening:   setInputEnableVendorLensCorrection:   setInputDisableGamutMap:
```

It does **not** implement `setBaselineExposure:`, `setExposure:`, `setBoostAmount:`,
`setContrastAmount:`, … — the names `CIRAWZeroProcessor.apply()` derives from its
recipe strings. `responds(to:)` therefore returns **false for every entry** and the
guard skips every assignment.

Independently corroborated: this session's own
`testZeroRecipeReachesEveryControlOnARealFilter` failed on the simulator with
`CIRAWFilter does not respond to setBaselineExposure:` … for each control.

**Consequence, stated plainly:** the zero-process recipe — the product's entire
claim — applies **nothing**. It does not crash, it does not log, it does not warn;
it returns a silently unmodified image. Two of the probe names were also wrong in a
second, independent way (`setIsLensCorrectionEnabled:` for a flag whose setter is
derived from `lensCorrectionEnabled`), so at least those two were unreachable even
if the name scheme had been right.

**Not yet established:** whether a *device* `CIRAWFilterImpl` implements the plain
`setX:` names, the `setInput*:` names, or both. The simulator enumeration is the only
runtime evidence anyone has. Do not generalise it to hardware without running it on
hardware. Note also the semantic traps in the names the impl *does* expose:
`setInputEnableVendorLensCorrection:` and `setInputDisableGamutMap:` are booleans
whose polarity differs from each other, and `setInputBoost:` is not obviously
`boostAmount`.

### 0.2 What this session already changed (and what that turned out to be worth)

Committed to the working tree, build **SUCCEEDED**, tests run:

- `CIRAWZeroProcessor.swift` — recipe rewritten as a data-driven list of 15 controls;
  the two flags' probe names corrected (`isLensCorrectionEnabled` → `lensCorrectionEnabled`).
  **Superseded by 0.1:** the enumeration is right, the application mechanism is still
  wrong — the correct fix is to set via the `input*` key path, not to rename selectors.
- `CaptureService.swift` — actor-isolation violation removed from `init()`
  (observers now register on first `startSession()`). The emitted warning is gone from
  the build. Note the related finding *"Actor deinit reads isolated observer state
  off-executor"* was **REFUTED 2/2** — the `deinit` as written is fine; do not "fix" it.
- `PhotoCapture.swift` — payload and `timeoutTask` now snapshotted under one lock.
  **The finding this acted on was REFUTED 2/2.** Keep the change only if it still
  reads well; do not describe it as a bug fix in any commit message.
- `CameraViewModel.swift` — dead `cancelSelfTimer()` removed;
  `refreshCameraAuthorization()` (zero call sites) replaced by
  `refreshAuthorizationStatuses()`, which re-reads camera **and** Photos.
- `RootView.swift` — `scenePhase == .active` now re-reads authorization before deciding.
  Without this a user who grants access in Settings was stranded on `PermissionsDeniedView`
  for the life of the process.
- `PikicamPipelineTests.swift` — two new tests. `testZeroRecipeEnumeratesEveryEnhancementControl`
  **passes** (it is the regression pin for the seven controls that were missing from the
  recipe). `testZeroRecipeReachesEveryControlOnARealFilter` **fails on the simulator** —
  its assertion that every setter responds is wrong for this environment; it must be
  rewritten to assert reach for the controls the runtime implements and to skip, not fail,
  where the implementation exposes none.

### 0.3 Three findings that contradict the current code and need an OWNER decision

1. **`baselineExposure = 0.0` is not neutral.** Confirmed 2/0, high. The verifier parsed
   the repo's own DNG fixture: IFD0 tag `0xC62A` (SRATIONAL) resolves to ≈ **−0.302 EV**.
   The SDK header notes `baselineExposure`'s "default value can vary based on the image"
   (deliberately contrasted with `exposure`'s fixed "default is 0"), i.e. it is seeded from
   the DNG's own tag. Forcing 0.0 discards a real per-image value on every develop.
   The recipe currently forces it. **Remove or keep — do not decide unilaterally.**
2. **`decoderVersion` is unpinned** (confirmed, medium, 2 yes / 1 no). Output drifts across
   iOS releases. Pin it, or state that drift is accepted.
3. **`highlightRecoveryEnabled` is unreachable**: it is the one enhancement left out of the
   recipe, it defaults to `true`, and it is deprecated as of iOS 19 (`NS_AVAILABLE(16_0,19_0)`),
   so touching it emits a deprecation warning on this target.

---

## 1. STANDING RULES — carry verbatim into every agent prompt

**R1. The code is the only proof.** "dont believe any written documentation. the code itself
is the documentation and sole proof of everything." Never cite `AGENTS.md`, `CONTEXT.md`,
`README.md`, `docs/adr/*`, or a code comment as authority for what the app **is** or why a
change is **forbidden**. Where a doc and the code disagree, the code wins and the mismatch is
itself a reportable defect. Exception: statements the owner makes in conversation are
instructions, not documents. (The audit confirmed 17 doc-drift findings on exactly this basis —
including `AGENTS.md` telling an agent to delete `Features/Gallery`, which is 364 lines of live
code wired into `CameraView.swift:55`.)

**R2. The product, in the owner's words:** "iphone camera that bypasses any post-filter +
maison margiela UI + good ui/ux by adhering to usual camera app + gallery ui/ux that adheres to
usual camera app as well. the main feature is the post-filtering bypass." The bypass is
feature #1. Margiela is the skin. Stock Camera and Photos are the interaction model.

**R3. Owner rulings, final:** Margiela wins everywhere (where Margiela and "usual camera app"
conflict, Margiela wins; the conventional half governs only where things are and what gestures
do). Shutter = square hairline ring, 1pt, sharp corners, no fill. Gallery **and** viewer = white
room; the camera viewport is the one dark room. **No icons at all — words only.** The user is
expected to relearn the app.

**R4. Five byte-exact strings** must survive any reskin, because `SmokeLaunchTest` queries them:
`"Continue"`, `"Capture photo"`, `"Library"`, `"No captures"`, `"Unable to load DNG"`.

**R5. Evidence discipline.** Never claim tests pass without running
`xcodebuild -project pikicam.xcodeproj -scheme pikicam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`
and quoting the output. Pre-grant on a fresh simulator or the run hangs:
`xcrun simctl privacy <UDID> grant photos piki.pikicam` and `… grant camera piki.pikicam`.
Every finding cites `file:line` of real code. Label each claim **PROVEN** (you ran it) or
**INFERRED** (you read it).

**R6. Functional paradigm.** Everything below is written in it, and so is the code:
pure core, effects at the edges; values over mutation; total functions over partial ones;
errors as data, not as strings or as control flow; a function's dependencies passed in, never
reached for. The existing `ZoomMath`, `ExposureCompensation`, and `PrintCrop` are the house
style — pure, total, and unit-tested. New logic matches them.

---

## 2. THE DESIGN — sinthink pipeline

`X → Graph → Effect<A, E, R>`. Nodes are functions; edges are data flow. Read the problem,
draw the call graph, then write code that **is** the graph. If the code doesn't match the
graph, the implementation is wrong.

### §1 Shapes — the nouns

The domain language, as the code already spells it. Nothing new is invented here; the gap is
that one of these shapes **does not exist yet**.

```
Records   CapturedDNG · PikicamCapture · CaptureIndex · DNGDisplayRendition · ZeroRecipe
IDs       CaptureID            — branded, never a bare String; already the documented
                                 selection/paging key (PhotoLibraryManager.swift:58-59)
Variants  Phase(idle|countdown|capturing|savingDNG) · CaptureMode · FlashMode ·
          AspectRatio · SelfTimerOption · CameraPosition · AVAuthorizationStatus
Errors    CaptureError · DevelopError · PhotoLibraryError · CapturedDNGError ·
          CameraViewModelError — tagged, contextual, never a String
```

**The missing shape — and it is the whole product:**

```
RecipeApplication = { control: RecipeControl, outcome: Applied | Unsupported | Skipped }
ZeroRecipe        = [RecipeControl]   // the 15 controls, as data
```

Today `applyZeroRecipe(_:) -> Void`. It returns nothing, so nothing downstream can know what
happened. Make it return the application. That single change is what turns §4's silent
`Skipped` into a value the UI can show and a test can assert.

### §2 Think A first — the happy path

```
capture:  startSession → phase(idle) → [countdown?] → capturePhoto → CapturedDNG
          → PhotoLibraryManager.save → PikicamCapture → phase(idle)

develop:  dngData → CIRAWFilter(imageData:) → apply(ZeroRecipe) → CIImage
          → PrintCrop → CIContext → DNGDisplayRendition → viewer
```

Two graphs. The **develop** graph is where the product's claim lives, and it is the one whose
node is currently a no-op (§0.1). Draw it with the recipe node labelled by its
`RecipeApplication`, not by its Void.

### §3 One or many?

Mark cardinality on the graph so the code matches:

- `capturePhoto`, `render` — one-shot (`Effect`)
- `Phase` transitions, `PhotoKit` change events, thumbnail loads — many over time (`Stream`);
  the thumbnail stream needs a cache and a dedup of concurrent lookups (finding: no cache,
  every scroll re-requests; transient failures are indistinguishable from loading forever)
- `refresh()` — time-bounded; concurrent calls can publish stale data over newer (critic)

### §4 Think E second — where the graph breaks

Errors are **values** in the E channel until they genuinely cannot be handled. At each node
choose: **retry** · **escape hatch** · **die**.

- **retry** — transient `PhotoKit` failures; session restart after interruption
- **escape hatch** — thumbnail load failure → explicit placeholder (today: silent, forever);
  `render` failure → typed `DevelopError`, already correct
- **die** — invariant violations only. A recipe control that is *listed* but *unapplied* is
  currently neither: it is silence, which is the worst of the three.

### §5 Think R third — what each node needs

R is compile-time proof the dependencies are satisfied.

- `CaptureService` needs the AVFoundation device — satisfied, typed errors at the boundary
- `DevelopService` needs a Metal `CIContext` — **satisfied wrongly**: constructed on whatever
  thread builds `DevelopService`, including SwiftUI `@State` on main (finding)
- `apply(ZeroRecipe)` needs a `CIRAWFilter` **whose enhancement setters exist** —
  **this is the unsatisfied requirement**, and it is unsatisfied silently. The recipe's R is
  unproven for every control. Resolving §0.1 *is* resolving R.

### §6 Trust at boundary — `unknown → trusted`

The only places to parse. After them, the types guarantee shape.

| Boundary | Today |
|---|---|
| DNG bytes → `CIRAWFilter(imageData:)` | fixture-verified decode; no verification of the applied recipe |
| PhotoKit results → `PikicamCapture` | typed, correct |
| **on-disk index JSON → `CaptureIndex`** | **broken**: corruption/version mismatch degrades to `.empty()` and the *next save overwrites the file*, destroying provenance (confirmed 2/0, the riskiest path in storage) |
| `Info.plist` / privacy manifest | declared-but-unused; the tracked `Info.plist` contradicts the strings that actually ship |

### §7 Layer behavior — `.pipe()`

These wrap nodes without changing the graph: recipe-application logging/tracing (absent today —
this is how `Skipped` stops being invisible), a PhotoKit retry policy, a thumbnail cache, a
settle delay for torch (the zoom path already has an explicit 250 ms settle; the torch has none).

### §8 Scope — acquire/release tied to lifecycle

- AVFoundation session — acquire on foreground, release on background. **Currently wrong:**
  `.inactive` stops the session, so a Control Center swipe kills the camera.
- Metal `CIContext` — expensive; scope it once, don't rebuild per view (today: `@State` in the
  gallery; also a security-scoped/threading hazard)
- PhotoKit change observer — unregister in `deinit`
- Torch — on, then settle, then capture

### §9 Swap R to prove it

The graph shape must not change between production and tests; only R changes.

**It currently cannot.** No test instantiates `CameraViewModel` at all — the 35-test suite pins
only pure value types. That means the phase machine has hidden dependencies the design hasn't
surfaced. Surfacing them is a deliverable, not a nice-to-have. The recipe test must inject a
real `CIRAWFilter` and assert the `RecipeApplication` — that is the one test that would have
caught §0.1 on day one.

### §10 gen is A, pipe is E

Swift has no `Effect` monad; the discipline maps as follows, and it is binding:

- the **happy path** is a straight-line sequence of pure transformations — no error handling
  interleaved (`Effect.gen` body ≡ §2's call graph)
- the **E enumeration** is one place per layer that handles every error that layer can
  receive — Swift's `catch` blocks (`.pipe()`)
- each layer **scopes** its own E before passing on: `CaptureError` at the capture layer,
  `DevelopError` at develop, `PhotoLibraryError` at storage. Consumers never see deep
  implementation errors — the code already does this; keep it that way
- the **one exception** is a divergent strategy: two effects in the same sequence needing
  different failure semantics. Handle those inline and mark them — rare.
- a node that returns `Void` while hiding an outcome (the recipe) is a violation of this
  section. §1's `RecipeApplication` is the fix.

---

## 3. WHERE TO START, AND WHY THERE

**Phase 0 — resolve R before anything else.** Nothing in the develop graph is knowable until
§0.1 is settled:

1. Enumerate the runtime methods of a `CIRAWFilter` on **physical hardware** and diff against
   the simulator's list. Report the table: control × simulator × device.
2. Determine the correct application mechanism (`input*` key path vs. plain property vs. both,
   and the polarity of `setInputEnableVendorLensCorrection:` / `setInputDisableGamutMap:`).
3. On hardware, for each control, capture the *default* value and whether it differs from
   neutral. Apple documents `colorNoiseReductionAmount` and `moireReductionAmount` as
   "the default value will vary per image" and `highlightRecoveryEnabled` as defaulting to
   *true* — so "absent means neutral" is already falsified for at least three controls.
4. Return the recipe as data plus its `RecipeApplication`.

**Phase 1 — make the failure loud.** With `RecipeApplication` in hand: an unapplied control
must surface (typed `DevelopError`, or a user-visible "bypass not in force" state). This is the
same surface as the confirmed P0 UX gap "zero-process bypass has no visible status signal" —
deliver it once, in one place.

**Phase 2 — the three owner decisions in §0.3.** Bring them back as questions with the evidence;
do not pick.

**Phase 3 — pure core, then edges.** Fix in dependency order, core outward: storage index
provenance (`PhotoLibraryManager.swift:847`) → session lifecycle (`.inactive`, orphaned capture
task, `setExposureBias` lock held across an await) → gallery correctness (stale thumbnail `.task`
without `id`, invisible leftover selection, blank cover on delete) → camera interaction (reticle,
AE/AF lock, honest saving state, shutter-flash) → the Margiela reskin → the usability regressions.

**Phase 4 — the gate.** `scripts/verify.sh` never runs a test and its lint stage cannot fail
(`swift-format lint` exits 0 on violations; only `--strict` exits 1). Fix in three ordered,
separate commits: one deliberate repo-wide `swift-format format --in-place` pass → `--strict` in
verify.sh → add the test action.

---

## 4. HOW TO RUN THIS AS A WORKFLOW

- Fan out `sonnet` on the hard nodes: Phase 0 runtime fact-find, storage provenance, session
  lifecycle, the phase-machine testability work, the design-system pass.
- `haiku` on the mechanical nodes: doc-drift corrections, the symbol→word and font swaps,
  accessibility-label additions, the reformat.
- **Adversarially verify every claim**: ≥2 independent skeptics prompted to refute, kill on
  majority. The 15 refuted findings below are the proof this layer earns its cost — one of them
  is a finding *this* session already acted on.
- **Cover the 5 dead agents' area explicitly.** They failed on 6 consecutive stalls, not on a
  verdict. Nothing was proven about them.
- Report at every phase boundary: what changed (`file:line`), the exact command run, the output
  quoted, and what remains uncertain.

---

## Appendix A — 87 confirmed findings

### Critical — read these first

- **Zero-process promise is entirely unpinned — no test asserts any enhancement knob** — `pikicam/Features/Develop/CIRAWZeroProcessor.swift:69`

---

### — app-config (12) —

### `high` verify.sh's swift-format stage can never fail — lint exits 0 on violations

`scripts/verify.sh:29` · kind=test-gap · confidence=certain · votes=2|refute=0

**Evidence.** Line 29: `out=$(xcrun swift-format lint --configuration .swift-format -r pikicam 2>&1)` then `rc=$?` and `if [ "$rc" -eq 0 ]; then pass "swift-format lint"`. `swift-format lint` reports findings as *warnings* and always exits 0. Measured on this repo: 247 warning lines emitted, real exit code 0. Probe confirmed on a deliberately mis-spaced file: `/private/tmp/fmtprobe/A.swift:2:6: warning: [Spacing] remove 2 spaces` / `probe rc=0`.

**Failure scenario.** Any developer runs `./scripts/verify.sh` (or commits, triggering the pre-commit `verify` hook). 247 formatting violations are printed under "1/3 swift-format lint" and the stage prints `PASS  swift-format lint`; the final line reads `verify: ALL CHECKS PASS`. Formatting is never actually enforced despite AGENTS.md calling this "a real check".

**Proposed fix.** Add --strict to the lint invocation on scripts/verify.sh:29 so findings become errors with nonzero exit: `out=$(xcrun swift-format lint --strict --configuration .swift-format -r pikicam 2>&1)`. Then run `xcrun swift-format format --configuration .swift-format -r -i pikicam` (and optionally extend coverage to pikicamTests/pikicamUITests) to clear the 247 existing violations so the gate starts clean.


---

### `high` AGENTS.md says Features/Gallery was removed; it is live code wired into CameraView

`AGENTS.md:73` · kind=docs-drift · confidence=certain · votes=2|refute=0

**Evidence.** AGENTS.md line 73: "- `pikicam/Features/DualCamera|Gallery|Review|Settings/` — removed and committed; do not resurrect them unless asked." But `pikicam/Features/Gallery/GalleryView.swift` and `PikicamLibraryModel.swift` exist, are compiled (`GalleryView.swift in Sources`, pbxproj line 35), and are live: `pikicam/Features/Camera/CameraView.swift:55: GalleryView()` inside `.fullScreenCover`, and `PikicamApp.swift:14: let library = PikicamLibraryModel()`. The repo map's Camera list (AGENTS.md lines 64-67) also omits five files that exist: `CameraControls.swift`, `CameraHUDButton.swift`, `ZoomIndicatorView.swift`, `GridOverlayView.swift`, `VolumeButtonCaptureView.swift`.

**Failure scenario.** An agent (or new contributor) reads AGENTS.md, sees Gallery as removed-and-do-not-resurrect, and deletes `pikicam/Features/Gallery/` plus its pbxproj entries — breaking `CameraView.swift:55`, `PikicamLibraryModel`'s use as `CameraViewModel.libraryModel`, and the README's documented gallery feature.

**Proposed fix.** Rewrite the AGENTS.md repo map against the real tree: list `Features/Gallery/` as live, add the five missing `Features/Camera/` files, and change the "removed" line to name only the genuinely absent directories (DualCamera, Review, Settings).


---

### `high` refreshCameraAuthorization() has no callers — user is stuck on PermissionsDeniedView forever

`pikicam/App/RootView.swift:31` · kind=correctness · confidence=certain · votes=2|refute=0

**Evidence.** `CameraViewModel.swift:88` defines `func refreshCameraAuthorization() { cameraAuthStatus = AVCaptureDevice.authorizationStatus(for: .video) }` — grep finds zero call sites. `cameraAuthStatus` is otherwise written only in `init` (line 37) and `requestCameraAccess` (line 99). `RootView.swift:31-44` handles return-to-foreground with `case .active where viewModel.hasRequiredAuth: Task { await viewModel.start() }` — it never re-reads authorization, and `hasRequiredAuth` (CameraViewModel.swift:48) reads the stale cached statuses. No `UIApplication.willEnterForegroundNotification` / `didBecomeActiveNotification` observer exists anywhere in `pikicam/`.

**Failure scenario.** User taps "Continue", denies camera (or Photos). `PermissionsDeniedView` shows with an "Open Settings" button. They open Settings, grant Camera and Photos, and swipe back to pikicam. `scenePhase` becomes `.active`, but `hasRequiredAuth` is still false from the cached `.denied`, so `start()` never runs and the denied screen never re-evaluates. The user has no way back into the camera except force-quitting and relaunching.

**Proposed fix.** Add `func refreshPhotoAuthorization() { photoAuthStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite) }` to CameraViewModel, and in RootView `.onChange(of: scenePhase)` call both refresh methods before the switch: `case .active: viewModel.refreshCameraAuthorization(); viewModel.refreshPhotoAuthorization(); if viewModel.hasRequiredAuth { Task { await viewModel.start() } }`.


---

### `medium` Info.plist is dead code that contradicts the usage strings that actually ship

`pikicam/Resources/Info.plist:5` · kind=cleanup · confidence=certain · votes=2|refute=0

**Evidence.** The pbxproj sets `GENERATE_INFOPLIST_FILE = YES` (line 565/600) and never sets `INFOPLIST_FILE`; there is no `PBXFileReference` for `Info.plist` anywhere in `project.pbxproj` (only `PrivacyInfo.xcprivacy` at line 53). The real strings come from build settings, e.g. line 566: `INFOPLIST_KEY_NSCameraUsageDescription = "pikicam needs camera access to capture DNG raw photos with zero computational processing."` — while the on-disk plist line 6 says `"pikicam needs camera access to capture Bayer RAW photos with zero computational processing."` The on-disk plist is also the *only* place `UIRequiredDeviceCapabilities = [arm64, still-camera]` (lines 33-37) exists, and the generated plist has no equivalent.

**Failure scenario.** A developer edits `pikicam/Resources/Info.plist` to change the camera permission prompt (or to add `NSPhotoLibraryAddUsageDescription`). The build succeeds, the shipped app shows the old prompt — the edited file is packaged nowhere. Meanwhile `UIRequiredDeviceCapabilities/still-camera` is silently absent from the real plist, so the app installs on devices the design assumed could not run it.

**Proposed fix.** Delete pikicam/Resources/Info.plist and keep the INFOPLIST_KEY_* build settings as the single source of truth. Optionally add INFOPLIST_KEY_UIRequiredDeviceCapabilities for still-camera to project.yml and the pbxproj if that restriction is genuinely wanted.


---

### `medium` project.yml omits MARKETING_VERSION/CURRENT_PROJECT_VERSION and launch-screen settings — regenerating breaks archive

`project.yml:33` · kind=docs-drift · confidence=certain · votes=1|refute=0

**Evidence.** The pbxproj app target carries `CURRENT_PROJECT_VERSION = 1;` (line 562), `MARKETING_VERSION = 1.0;` (line 578), `INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES` (569), `INFOPLIST_KEY_UILaunchScreen_Generation = YES` (571), and `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone` / `_iPad` (572-573). project.yml's app target `settings.base` (lines 33-41) lists none of them.

**Failure scenario.** Someone installs xcodegen on a machine and runs `xcodegen generate` (the command documented in project.yml's own header). The regenerated project has no `MARKETING_VERSION`, so the built app's Info.plist lacks `CFBundleShortVersionString` and `CFBundleVersion`; App Store Connect rejects the archive and `xcodebuild archive` warns. It also loses `INFOPLIST_KEY_UILaunchScreen_Generation`, so the app launches at legacy letterboxed size on modern devices.

**Proposed fix.** Add to the `pikicam` target's `settings.base` in project.yml: `MARKETING_VERSION: "1.0"`, `CURRENT_PROJECT_VERSION: 1`, `INFOPLIST_KEY_UILaunchScreen_Generation: YES`, `INFOPLIST_KEY_UIApplicationSceneManifest_Generation: YES`, `INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents: YES`, and the two `INFOPLIST_KEY_UISupportedInterfaceOrientations_*` keys — mirroring pbxproj app-target Debug/Release configs.


---

### `medium` project.yml defines the `pikicam` scheme twice with conflicting test targets

`project.yml:42` · kind=docs-drift · confidence=certain · votes=1|refute=0

**Evidence.** Line 42-44, inside the `pikicam` target: `scheme:` / `testTargets:` / `- pikicamTests`. Then line 71-83, at top level: `schemes:` / `pikicam:` / `test:` / `targets:` / `- pikicamTests` / `- pikicamUITests`. The checked-in scheme matches the *second* definition: `pikicam.xcscheme` lists `pikicamUITests.xctest` first, then `pikicamTests.xctest`.

**Failure scenario.** `xcodegen generate` produces a `pikicam` scheme from one of the two definitions and emits a duplicate-scheme warning; whichever loses, the resulting shared scheme may drop `pikicamUITests` from the test action, so `SmokeLaunchTest` silently stops running on every future `./scripts/verify.sh` / `xcodebuild test` invocation.

**Proposed fix.** Delete the target-level `scheme:` block at project.yml lines 42-44 (`scheme: / testTargets: / - pikicamTests`) and keep only the top-level `schemes.pikicam` definition (lines 71-83, which lists both `pikicamTests` and `pikicamUITests`).


---

### `medium` Privacy manifest declares FileTimestamp, DiskSpace and SystemBootTime that no code uses

`pikicam/Resources/PrivacyInfo.xcprivacy:19` · kind=docs-drift · confidence=certain · votes=1|refute=0

**Evidence.** Three `NSPrivacyAccessedAPIType` entries: `NSPrivacyAccessedAPICategoryFileTimestamp` with reason `C617.1` (lines 20-27, comment "reading DNG file creation dates"), `NSPrivacyAccessedAPICategoryDiskSpace` / `E174.1` (lines 28-36, "checking free space before saving photos"), `NSPrivacyAccessedAPICategorySystemBootTime` / `35F9.1` (lines 37-45, "timing camera session operations"). Grepping `pikicam/` for `creationDate`, `attributesOfItem`, `FileAttributeKey`, `volumeAvailableCapacity`, `URLResourceKey`, `resourceValues`, `systemUptime`, `ProcessInfo`, `mach_absolute_time`, `CACurrentMediaTime` returns nothing — the only `creationDate` hits are in `pikicamTests/PikicamPipelineTests.swift:226,234` sorting `PHAsset`s, which is test-only and not the app binary.

**Failure scenario.** The app submits an inaccurate privacy manifest. Apple treats a declared reason code that does not match actual usage as a discrepancy; App Review can reject or require justification, and the manifest misrepresents to users what the app reads. The disk-space comment is doubly wrong — no free-space check exists anywhere in the save path (`PhotoLibraryManager` writes via `data.write(to: url, options: .atomic)` at line 858 with no space check).

**Proposed fix.** Replace the contents of NSPrivacyAccessedAPITypes with an empty array, keeping NSPrivacyTracking and NSPrivacyCollectedDataTypes as-is.


---

### `medium` AppIcon.appiconset declares three slots but contains no image files

`pikicam/Assets.xcassets/AppIcon.appiconset/Contents.json:2` · kind=feature-gap · confidence=certain · votes=1|refute=0

**Evidence.** Contents.json lists three 1024x1024 entries (universal / dark / tinted) but zero `filename` keys — `grep -c filename` returns 0 — and `find . -name "*.png"` outside build dirs returns nothing. The directory listing shows only `Contents.json`. Both `project.yml:36` and `pbxproj:559` set `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`.

**Failure scenario.** The app builds and installs but every surface that shows the icon — Home Screen, Spotlight, App Library, the device-walkthrough screenshots in `SmokeLaunchTest` — renders a blank/default placeholder. App Store Connect rejects the submission for an incomplete icon set, and the README's "open pikicam.xcodeproj and run on your iPhone" onboarding ships an unbranded app.

**Proposed fix.** Author a 1024x1024 PNG (monochrome per docs/adr/0001) and reference it as `"filename": "AppIcon.png"` in the universal entry; add the dark/tinted variants if ADR 0001 calls for them.


---

### `medium` scenePhase .inactive stops the camera session on a mere Control Center swipe

`pikicam/App/RootView.swift:39` · kind=ui-ux · confidence=likely · votes=1|refute=0

**Evidence.** Line 39: `case .background, .inactive:` / `Task { await viewModel.stop() }`, with the comment at lines 32-35 explaining that only backgrounding needs handling ("The camera view stays mounted while backgrounded, so its onDisappear never fires"). `.inactive` is also delivered for transient interruptions that are not backgrounding: Control Center / Notification Center pull-down, incoming-call banners, the app switcher, and the system permission alert itself. `viewModel.stop()` calls `captureService.stopSession()`, which halts the AVCaptureSession and drops the preview.

**Failure scenario.** A user frames a Capture with the one-handed camera UI, swipes down to glance at the time, and swipes back. The preview has gone black for the duration and must be re-acquired; on a slower device the black frame persists until `start()` completes, which reads as a dropped capture.

**Proposed fix.** case .background: Task { await viewModel.stop() }


---

### `medium` The verify chain never runs a single test — 43 tests gate nothing

`scripts/verify.sh:59` · kind=test-gap · confidence=certain · votes=1|refute=0

**Evidence.** verify.sh has exactly three stages, all declared in the header comment (lines 3-6): swift-format lint, SwiftLint, `xcodebuild build`. Stage 3 is `xcodebuild -project pikicam.xcodeproj -scheme pikicam -destination "$DEST" build` — the `build` action, not `test`. The pre-commit hook that mirrors it (`entry: ./scripts/verify.sh`, `.pre-commit-config.yaml` line 27) therefore never compiles the test targets either. The suite is substantial: 8 test funcs in `PikicamPipelineTests.swift` plus 35 in `CameraControlTests.swift`, and 3 in `SmokeLaunchTest.swift`.

**Failure scenario.** A commit breaks `CameraControlTests.swift` (e.g. a `ZoomMath.clamped` signature change). `./scripts/verify.sh` prints `verify: ALL CHECKS PASS` and the commit lands; the failure only surfaces the next time someone runs `xcodebuild ... test`, potentially many commits later.

**Proposed fix.** Add a fourth stage to scripts/verify.sh running `xcodebuild -project pikicam.xcodeproj -scheme pikicam -destination "$DEST" -only-testing:pikicamTests test` (unit target only), and update the header comment plus .pre-commit-config.yaml description to match. Note AGENTS.md's simulator privacy pre-grant requirement (simctl privacy grant photos/camera) must be documented/handled so the new test stage cannot hang the hook on a fresh simulator.


---

### `low` AGENTS.md "Repository state" is wrong on tests, commits and working tree

`AGENTS.md:75` · kind=docs-drift · confidence=certain · votes=1|refute=0

**Evidence.** Line 76: "currently 5 tests, incl. device-only Photos probes" — actual count is 43 test funcs (35 in `CameraControlTests.swift`, 8 in `PikicamPipelineTests.swift`). Line 109: "Working tree is **clean**: 7 commits on `main`" — `git log --oneline | wc -l` returns 32, and `git status --porcelain` shows 7 modified files plus untracked `CONTEXT.md` and `docs/adr/`. Line 62-83 repo map omits `Features/Gallery/` (which exists) and `pikicam/Resources/PrivacyInfo.xcprivacy` entirely.

**Failure scenario.** An agent sizes its work from AGENTS.md, believes the test surface is 5 tests and the repo is a clean 7-commit project, and skips running the 35 `CameraControlTests` regressions or stages unrelated files — the exact "do not mass-git add -A" discipline the doc itself states is being undercut by the doc being stale.

**Proposed fix.** Update AGENTS.md: replace volatile counts with durable rules — delete "currently 5 tests" and "clean: 7 commits" claims, list both test files without a count, fix repo map to include Features/Gallery/ (GalleryView.swift, PikicamLibraryModel.swift) and Resources/PrivacyInfo.xcprivacy, and correct the "Gallery removed" line.


---

### `low` verify.sh lints only pikicam/ — the test targets have unlinted violations

`scripts/verify.sh:29` · kind=cleanup · confidence=certain · votes=1|refute=0

**Evidence.** Line 29 passes `-r pikicam` and line 45 passes `--config .swiftlint.yml`, whose `included:` list (`.swiftlint.yml:9-10`) is only `- pikicam`. Neither path ever visits `pikicamTests/` or `pikicamUITests/`. Running the same lint manually over the tests yields violations that the gate structurally cannot see: `pikicamTests/CameraControlTests.swift:2:1: warning: [OrderedImports]`, `:170:67: warning: [Spacing]`, `:257:1: warning: [Indentation]`; `pikicamTests/PikicamPipelineTests.swift:445:13: warning: [OneVariableDeclarationPerLine]` (×3), `:311:61: warning: [TrailingComma]`.

**Failure scenario.** The 35-test `CameraControlTests.swift` — the file most likely to be edited by a contributor — has no formatting gate whatsoever; violations accumulate silently and only surface if someone runs lint by hand.

**Proposed fix.** Either extend the swift-format stage to `-r pikicam pikicamTests pikicamUITests` and drop `pikicamTests` from `.swiftlint.yml`'s `excluded:` list (with the existing "intentionally exploratory" rationale moved to a narrower per-file rule), or add an explicit documented exclusion so the gap is a decision rather than an oversight.


---

### — camera-ui (13) —

### `high` Camera screen uses SF Rounded everywhere; ADR 0001 mandates Courier New

`pikicam/Features/Camera/CameraView.swift:133` · kind=docs-drift · confidence=certain · votes=2|refute=0

**Evidence.** CameraView.swift:133 ".font(.system(size: 13, weight: .bold, design: .rounded))", CameraView.swift:157 ".font(.system(size: 12, weight: .bold, design: .rounded))", CameraView.swift:440 same, CameraView.swift:482 ".font(.system(size: 96, weight: .bold, design: .rounded))", CameraHUDButton.swift:23 ".font(.system(size: 11, weight: .medium, design: .rounded))", ZoomIndicatorView.swift:10 ".font(.system(size: 15, weight: .medium, design: .rounded))" — six files/lines use SF Rounded. ADR 0001 (docs/adr/0001-ui-adopts-margiela-design-system.md) mandates Courier New, explicitly "abandons iOS camera-app conventions (SF Rounded, yellow accent, capsules, icon HUD)". A repo-wide grep for "Courier" returns zero hits: the deliberate design language is entirely absent from the camera screen.

**Proposed fix.** Introduce one shared Margiela type style (Font.custom("Courier New", size:)) and apply it at the six design:.rounded call sites (CameraView.swift:133, 157, 440, 482; CameraHUDButton.swift:23; ZoomIndicatorView.swift:10); leave SF Symbol icon glyphs (e.g. CameraHUDButton.swift:18) on .system.


---

### `high` Yellow accent fills on chips violate the no-accents rule

`pikicam/Features/Camera/CameraView.swift:142` · kind=docs-drift · confidence=certain · votes=2|refute=0

**Evidence.** CameraView.swift:141-144 ".background(ZoomPresets.isSelected(...) ? Color.yellow : ...)" and :161 ".background(viewModel.aspectRatio == ratio ? .yellow : ...)", :192 ".foregroundStyle(.yellow)" (thumbnail badge), :441 ".foregroundStyle(.yellow)" (EV label). ADR 0001 explicitly rejects the yellow accent. Within the Margiela language the selected state should be inversion (white fill/black text or a hairline outline), not a yellow fill. Note ShutterButton and CameraHUDButton already avoid yellow; only these four sites violate it.

**Proposed fix.** Replace yellow selected fills with black/white inversion (selected: white fill + black text; unselected: transparent + white text + hairline), recolor thumbnail badge (line 192) and EV label (line 441) to white.


---

### `high` Shutter doubles as silent countdown-cancel with no visible affordance

`pikicam/Features/Camera/CameraView.swift:202` · kind=correctness · confidence=certain · votes=2|refute=0

**Evidence.** CameraView.swift:200-204 "ShutterButton(isCapturing: viewModel.phase == .capturing || viewModel.phase == .savingDNG, action: viewModel.capture)". ShutterButton.swift:31 ".disabled(isCapturing)". CameraViewModel.swift:253-268 capture() ignores the shutter in .capturing/.savingDNG, and phase covers .countdown — but the button is only disabled for capturing/savingDNG, so during the 3s/10s countdown it stays enabled and tapping it CANCELS the timer (same call routes to cancelCapture via phase == .countdown). The only cancel affordance is SelfTimerCountdownView's comment "Tapping anywhere on the screen cancels via the VM" (:475). Failure: user arms 10s timer, taps shutter at t=5s expecting to re-fire or do nothing, and silently cancels the whole capture with no confirmation.

**Failure scenario.** Arm 10s self-timer, press shutter mid-countdown -> capture() hits phase == .countdown -> cancelCapture() runs -> timer silently dies, no photo, no feedback; user only learns by the countdown number vanishing.

**Proposed fix.** Pass countdown state to ShutterButton (e.g. isCountdown) and render an explicit cancel affordance — changed label/hint/accessibility ("Cancel timer") or disabled shutter-tap-cancel, keeping SelfTimerCountdownView tap as the sole documented cancel path.


---

### `high` Error banner pinned under home indicator, undismissable, red

`pikicam/Features/Camera/CameraView.swift:233` · kind=ui-ux · confidence=certain · votes=2|refute=0

**Evidence.** CameraView.swift:233-239 error banner: "Text(error.localizedDescription).font(.caption).foregroundStyle(.red)" placed in the VStack AFTER the ZoomIndicatorView at :229, i.e. at the very bottom of the screen with no padding(.bottom). On failure (cameraUnavailable on simulator, capture/save errors) the red caption sits under the home indicator with no clear/dismiss/retry control, and CameraViewModel never clears it except on the next capture() (:258 error = nil). Failure: any error (e.g. denied-then-revoked permission, save failure) leaves a persistent red line the user cannot dismiss.

**Failure scenario.** Trigger any viewModel.error (e.g. failed save) -> red caption appears at bottom edge, possibly clipped by home indicator -> no tap-to-dismiss, no retry button -> persists until the next successful shutter press.

**Proposed fix.** Add CameraViewModel.clearError() (error = nil) plus safe-area monochrome error row in CameraView below ZoomIndicatorView: Text + word-only Dismiss button (and Retry=capture() only for capture/save failures), .foregroundStyle(.white) on black with .padding(.bottom) respecting safe area — matching ADR-0001 monochrome/word-only language; GalleryView's existing gallery-retry pattern is gallery-scoped and does not cover this camera path.


---

### `medium` No in-camera empty states; stale auth status strands denied users

`pikicam/Features/Camera/CameraView.swift:76` · kind=correctness · confidence=likely · votes=2|refute=0

**Evidence.** CameraView.swift:76-89 preview builder: when session != nil it shows CameraPreview; else Color.black. But CameraViewModel.start() (:120-134) sets isConfigured = false on BOTH the missing-permissions path (:121-124) and the catch path (:130-133), and CameraView only branches on isConfigured for chrome (:107, :123, :244) — never for the preview state. On simulator-with-permissions the session exists but has no back wide camera; on denied permissions the error is set but the preview area stays black with the red caption as the only signal. There is no typed empty state (icon + guidance + Open Settings) in CameraView itself; the only denied UI is RootView's PermissionsDeniedView, which shows only after didRequestPermissions flips, with no refresh path if the user grants in Settings and returns (RootView .onChange only calls start/stop, never refreshCameraAuthorization).

**Failure scenario.** Deny camera permission, kill app, relaunch (auth already denied: .task sets didRequestPermissions = true) -> PermissionsDeniedView shows "Open Settings" -> user grants in Settings, returns -> scenePhase .active calls start() which re-reads? No: start() checks hasRequiredAuth from STALE statuses (init-time values) -> still shows denied view with no pull-to-refresh or re-check button.

**Proposed fix.** Refresh live auth before gating on it: on scenePhase .active call refreshCameraAuthorization() (and add + call refreshPhotoAuthorization(), currently missing) before reading hasRequiredAuth / calling start(). Do not add a duplicate denied empty-state inside CameraView (unreachable: RootView only mounts CameraView when hasRequiredAuth is true).


---

### `medium` Capsule/circle chips and labels violate the no-rounding rule

`pikicam/Features/Camera/CameraView.swift:144` · kind=docs-drift · confidence=certain · votes=1|refute=0

**Evidence.** CameraView.swift:140-144 zoom chips use ".clipShape(Capsule())", :162 aspect strip uses ".clipShape(Capsule())", :443 EV label uses ".clipShape(Capsule())", ZoomIndicatorView.swift:15 ".background(.black.opacity(0.45), in: Capsule())", CameraView.swift:486 countdown uses ".clipShape(Circle())", CameraHUDButton.swift:21 ".background(.black.opacity(0.45), in: Circle())". ADR 0001 mandates "no rounding". The one intentional exception is the 80pt physical shutter button (ShutterButton.swift:15-17 circles), which mimics hardware; the chips/labels/captions have no such justification.

**Proposed fix.** Render chips/labels/captions as rectangles (cornerRadius 0), reserving circles strictly for the shutter release. Do not touch ShutterButton.


---

### `medium` Flip/grid/flash buttons announce state, never the action

`pikicam/Features/Camera/CameraHUDButton.swift:27` · kind=ui-ux · confidence=certain · votes=1|refute=0

**Evidence.** CameraView.swift:209-215 the lower-right flip control is "CameraHUDButton(systemImage: arrow.triangle.2.circlepath.camera, label: \"Camera\", value: viewModel.cameraPosition.label)" with .accessibilityIdentifier("front-camera-toggle"), .accessibilityLabel(label) i.e. "Camera", .accessibilityValue(value) i.e. "Back/Front" (CameraHUDButton.swift:27-29). SmokeLaunchTest.swift:174-183 taps flip and does waitForValue(flip, "Front"/"Back"). VoiceOver therefore announces "Camera, Back" — the action (switch to front) is never spoken, and sighted users get an icon plus the word "Camera", not the destination. Same pattern weakens the grid toggle (announces "Grid, On" rather than an action).

**Failure scenario.** VoiceOver user on back camera hears "Camera, Back" -> activates expecting camera settings or status -> camera flips unexpectedly; the spoken string never names the action or destination.

**Proposed fix.** Give flip/grid/flash/timer buttons action-naming accessibilityLabels (e.g. computed "Switch to front camera" / "Switch to back camera" from cameraPosition) while keeping .accessibilityIdentifier and .accessibilityValue ("Back"/"Front", "On"/"Off", flashMode.label) byte-exact so SmokeLaunchTest waitForValue contract is unbroken; visible Text(label) stays "Camera"/"Grid" so Margiela visual language is untouched.


---

### `medium` EV slider: 40pt hit zone, no VoiceOver adjust, dismisses mid-drag

`pikicam/Features/Camera/CameraView.swift:437` · kind=ui-ux · confidence=certain · votes=1|refute=0

**Evidence.** CameraView.swift:421-436 ExposureSliderView draws tick dots, a 40pt-wide frame (:437), and a DragGesture(minimumDistance: 0); :438-447 the EV value label is offset(y: -30) with .allowsHitTesting(false). The only interactive zone is the 40pt column (below the 44pt minimum), ticks are 4-7pt visual targets, and there is no accessibilityAdjustableAction — VoiceOver sees one element ("Exposure compensation", value label) with no adjust action. Also presentExposureSlider() (:93-102) shows it on EVERY tap-to-meter and hides after 2.5s, so a VoiceOver or slow-drag user can have it vanish mid-interaction.

**Failure scenario.** VoiceOver user focuses the slider -> hears value -> swipes up/down expecting stepper adjustment -> nothing happens (no adjustable action); or any user starts a slow precise drag at 2.4s after tap -> slider auto-dismisses mid-drag and the commit closure fires with a half-dragged value.

**Proposed fix.** Widen ExposureSliderView hit column to >=44pt, add .accessibilityAdjustableAction stepping exposureDraftStops by 1/3 stop (with .isAdjustable trait), and cancel/re-arm sliderDismissTask on drag-changed (or gate the 2.5s auto-hide on drag-active).


---

### `medium` Zoom/aspect chips below 44pt; taps fall through to tap-to-meter

`pikicam/Features/Camera/CameraView.swift:138` · kind=ui-ux · confidence=certain · votes=1|refute=0

**Evidence.** CameraHUDButton.swift:20 ".frame(width: 44, height: 44)" applies ONLY to the Image; the tappable Button label is VStack(spacing: 4) of circle + caption (:16-24), and CameraView.swift:247 HUDCluster uses "HStack(spacing: 20)". Adjacent 44pt circles with 20pt gaps are fine, but the caption text below each circle extends the hit area into neighbors asymmetrically, and the zoom preset chips (:138-139 padding .horizontal 10/.vertical 6 around 13pt text) and aspect chips (:159-160) are ~28-30pt tall — below the 44pt minimum. The countdown circle (:481-488 Text 96pt + padding 24 + .onTapGesture on Text with .contentShape(Rectangle())) has a huge tap area but it is the CANCEL control with no "cancel" wording anywhere.

**Failure scenario.** User with large Dynamic Type or imprecise tap aims at a 1:1 aspect chip (~30pt tall) -> misses -> taps preview instead -> fires setFocusAndExposure + re-presents EV slider unintentionally.

**Proposed fix.** Give zoom chips (CameraView.swift:131-144) and aspect chips (:155-163) a 44pt hit target without changing visuals, e.g. `.frame(minHeight: 44) + .contentShape(Capsule())` on the label or expanded invisible padding. No countdown change needed — SelfTimerCountdownView already exposes `.isButton` + `accessibilityHint("Cancels the timer")` (:490-491).


---

### `medium` Volume shutter unsuppressed: HUD flash, volume side effect, dead at rails

`pikicam/Features/Camera/VolumeButtonCaptureView.swift:9` · kind=ui-ux · confidence=certain · votes=1|refute=0

**Evidence.** VolumeButtonCaptureView.swift:9-11 comment: "does NOT suppress the system volume HUD — the user sees the HUD and hears the sound change. If suppression is needed, add a custom volume overlay." The Coordinator (:47-69) fires onVolumeChange on ANY hardware-button volume delta, and CameraView.swift:221-226 wires it to viewModel.capture() with only an isConfigured guard — no phase guard, so a volume press during .capturing/.savingDNG calls capture() (which no-ops, fine) but during .countdown it CANCELS the timer, and at volume min/max (no delta possible) the shutter silently does nothing. Every volume capture also flashes the system volume HUD over the viewfinder and changes the user's listening volume as a side effect of taking a photo.

**Failure scenario.** User at minimum volume presses volume-down to take a photo -> no delta -> handleVolume early-returns -> no capture, no feedback; or user mid-countdown bumps a volume button -> countdown cancels -> no photo. Either way a photo action unexpectedly changes/moves system volume.

**Proposed fix.** Configure the MPVolumeView so it actually suppresses the system HUD (present in window, not isHidden, with volume slider shown offscreen), snapshot and restore outputVolume around each trigger so taking a Capture does not change listening volume, and synthesize a trigger at the rails where no delta occurs; keep routing through CameraViewModel.capture() which already encodes the phase machine (idle starts, countdown cancels, capturing/savingDNG no-ops).


---

### `medium` Preview rotation hard-coded to 90deg; landscape viewfinder misoriented

`pikicam/Features/Camera/CameraPreview.swift:16` · kind=correctness · confidence=likely · votes=1|refute=0

**Evidence.** CameraPreview.swift:16 "var rotationAngle: CGFloat = 90" is a hard-coded constant; CameraView.swift:77-83 constructs "CameraPreview(session: session, onTap:)" and never passes rotationAngle, and updateUIView (:33-37) re-applies it on every state change. No observer of UIDevice.orientation / AVCaptureVideoPreviewLayer connection updates exists anywhere in the camera layer (grep for UIDevice.orientation returns only the shutter-time CaptureOrientation sampling in CameraViewModel.swift:284). Rotating the device to landscape leaves the preview layer at 90deg while the SwiftUI chrome (fixed portrait layout) does not rotate either — capture orientation is sampled correctly at shutter press but the live viewfinder does not follow the device.

**Failure scenario.** Rotate device to landscape -> preview layer keeps 90deg rotation -> viewfinder shows a sideways/letterboxed feed while framing controls stay portrait -> user frames against a misoriented preview though the saved DNG orientation tag is correct.

**Proposed fix.** Drive rotationAngle from interface/device orientation (e.g. observe UIDevice.orientationDidChangeNotification or view geometry/interface orientation and map portrait/landscape to the matching videoRotationAngle for the active camera, passing it into CameraPreview so PreviewView.setVideoRotationAngle updates); document whether SwiftUI chrome re-lays-out or stays portrait.


---

### `medium` Pinch during countdown/capture poisons the next gesture's base

`pikicam/Features/Camera/CameraView.swift:288` · kind=correctness · confidence=likely · votes=1|refute=0

**Evidence.** CameraView.swift:58-62 ".onChange(of: viewModel.cameraPosition)" resets zoomGestureBase/lastGestureFactor; pinch .onChanged (:288-302) spawns "Task { await viewModel.setZoom(factor) }" per tick (no cancellation of prior tick tasks; the VM's zoomGeneration guard at CameraViewModel.swift:185-191 drops stale publishes but every tick still hops to the capture service). During an in-flight gesture setZoom silently no-ops unless phase == .idle (:182), so pinching mid-capture or mid-countdown does nothing with no feedback, and lastGestureFactor keeps updating from factors the device never applied — on .onEnded zoomGestureBase seeds from an unapplied value.

**Failure scenario.** Start 10s countdown, pinch to reframe during countdown -> setZoom guard drops every tick -> gesture ends with zoomGestureBase = unapplied factor -> countdown fires at the OLD zoom but the next pinch starts from the phantom base -> zoom jumps.

**Proposed fix.** When phase != .idle, ignore pinch ticks without updating lastGestureFactor (or show a brief locked affordance); optionally cancel superseded per-tick tasks instead of relying solely on the generation guard.


---

### `low` Zoom indicator orphaned below dock, unlabeled for VoiceOver

`pikicam/Features/Camera/CameraView.swift:229` · kind=ui-ux · confidence=certain · votes=1|refute=0

**Evidence.** CameraView.swift:229-230 "ZoomIndicatorView(factor: viewModel.zoomFactor).padding(.bottom, 8)" is placed AFTER the bottom dock inside the same "if viewModel.isConfigured" block (:123-231) with no Spacer separation from the dock (:217-218 padding(.bottom, 32)); the indicator renders BELOW the shutter row, closest to the home indicator, while the zoom chips it mirrors sit ABOVE the dock (:127-149). ZoomIndicatorView.swift:16-17 exposes only accessibilityIdentifier + accessibilityValue, no label — VoiceOver announces a bare "1.0x" with no context. SmokeLaunchTest.swift:189-201 asserts on zoom-indicator by value, so identifier/value must stay.

**Proposed fix.** In ZoomIndicatorView.swift add `.accessibilityLabel("Zoom")` keeping identifier "zoom-indicator" and value byte-exact; in CameraView.swift move the `ZoomIndicatorView` block (currently :228-230, `.padding(.bottom, 8)` after the dock's `.padding(.bottom, 32)` at :217-218) to sit with the zoom preset chips (:127-149) or as a preview overlay.


---

### — camera-vm (4) —

### `high` No test touches CameraViewModel; suite pins only pure value types

`pikicamTests/CameraControlTests.swift:1` · kind=test-gap · confidence=certain · votes=2|refute=0

**Evidence.** CameraControlTests.swift (35 tests) never references CameraViewModel once — every test targets pure value types (CameraPosition/FlashMode/ZoomMath/GridGeometry/SelfTimerOption/CaptureOrientation/AspectRatio/PrintCrop/ExposureCompensation/ZoomPresets). The 389-line phase machine (capture()/runCapture/cancelSelfTimer/generation guards) has zero unit tests;phase/cancel/countdown logic needs no Bayer sensor yet is untested.

**Failure scenario.** A regression that strands phase (e.g. dropping a `phase = .idle` reset, or cancelSelfTimer firing a capture) passes all 35 tests green — the suite cannot fail on the highest-risk logic in scope.

**Proposed fix.** Add MainActor CameraViewModel tests behind an injected seam (protocol for CaptureService + library save) covering: cancel-during-countdown takes no photo, second shutter during countdown cancels, stop() resets phase to idle.


---

### `medium` stop()/cancelCapture never join the orphaned capture task

`pikicam/Features/Camera/CameraViewModel.swift:136` · kind=concurrency · confidence=likely · votes=2|refute=0

**Evidence.** CameraViewModel.stop() (CameraViewModel.swift:136-142): `selfTimerTask?.cancel(); ...; cancelCapture(); await captureService.stopSession()` — cancel-and-nil without awaiting/joining the in-flight runCapture. RootView.swift:36-43 auto-restarts (`Task { await viewModel.start() }` on .active) while the orphaned capture may still be inside `captureService.capturePhoto` (CaptureService.swift:496-498 holds `isCaptureInFlight=true` until defer).

**Failure scenario.** Shutter with 10s timer armed -> countdown finishes, exposure in flight -> user backgrounds app (stop() cancels, phase=idle) -> foregrounds 1s later (start() re-runs) -> orphaned capture completes and calls libraryModel.select(capture), publishing a selection the fresh idle UI never asked for; or user taps shutter (phase==idle allows it) while orphan still holds isCaptureInFlight -> new capture throws CaptureError.captureInProgress as a user-visible error from a single clean tap.

**Proposed fix.** Join the in-flight capture in stop()/cancelCapture (e.g. captureTask?.cancel(); await captureTask?.value before phase=.idle / await stopSession), or gate capture()/start() until the orphan's capturePhoto has unwound and cleared isCaptureInFlight; make the join bounded (capturePhoto is currently non-cancellable, 15s PhotoCapture timeout) so stop() cannot hang.


---

### `low` Self-timer accumulates sleep slack instead of anchoring a deadline

`pikicam/Features/Camera/CameraViewModel.swift:315` · kind=perf · confidence=likely · votes=1|refute=0

**Evidence.** CameraViewModel.swift:315-329: countdown is `while remaining > 0 { try await Task.sleep(for: .seconds(1)); remaining -= 1 }` with no deadline anchor. Each 1s sleep carries scheduler slack, so a 10s countdown runs long under CPU contention, and there is no correction.

**Failure scenario.** Arm 10s timer on a busy device (e.g. session starting, Photos refresh on main) -> each tick overshoots by tens of ms -> visible 10s countdown actually fires at ~10.5-11s; user-noticeable for a stated-duration timer.

**Proposed fix.** Anchor to a monotonic deadline but keep 1s UI ticks: `let deadline = ContinuousClock.now + .seconds(seconds)` before the loop; each iteration `try await Task.sleep(until: deadline - .seconds(remaining-1), tolerance: .zero)` (or sleep 1s then recompute `remaining = max(0, Int(ceil((deadline - ContinuousClock.now).seconds))))`) so N per-tick overshoots collapse to a single final resumption slack.


---

### `low` All control guards fail silently with no disabled-state affordance

`pikicam/Features/Camera/CameraViewModel.swift:168` · kind=ui-ux · confidence=certain · votes=1|refute=0

**Evidence.** CameraViewModel.swift:168-175 cycleFlash, 153-166 toggleCamera, 181-196 setZoom, 198-206 toggleGrid/setAspectRatio, 210-231 setFocus/setExposure, 233-239 cycleSelfTimer all `guard phase == .idle else { return }` — silent no-op with no error, no disabled-state signal. cancelSelfTimer (245-248) `guard phase == .countdown else { return }` likewise silent outside countdown.

**Failure scenario.** User taps flash/zoom/grid mid-savingDNG -> nothing happens, no feedback -> repeated taps, perceived hang; automated UI test tapping controls during capture cannot distinguish 'guarded' from 'broken'.

**Proposed fix.** Keep phase guards; add disable-only affordance (no hide per ADR 0002): bind .disabled(viewModel.phase != .idle) on HUDCluster, zoom-preset buttons, aspect-strip buttons, flip button, and ignore pinch-gesture setZoom when phase != .idle (optional opacity dim for visible refuse). Exclude cancelSelfTimer (no direct UI control) and do not hide anything.


---

### — capture-session (3) —

### `high` setExposureBias holds device lock across unbounded await

`pikicam/Features/Camera/CaptureService.swift:431` · kind=concurrency · confidence=certain · votes=2|refute=0

**Evidence.** CaptureService.swift:419-440 `setExposureBias`: `try device.lockForConfiguration()` at line 426, then `await withCheckedContinuation` at lines 431-435 inside the do-block whose `defer { device.unlockForConfiguration() }` (line 427) only runs after the await resumes. The `setExposureTargetBias` completion 'fires on an arbitrary queue'.

**Failure scenario.** If the bias completion never fires (device torn down by a camera switch, session reset, or AVFoundation bug), the continuation never resumes AND the device configuration lock is held forever: every later zoom/focus/torch/capture that calls `lockForConfiguration` throws `.deviceLockFailed`, bricking camera controls until app restart.

**Proposed fix.** Invoke the async setter while holding the lock, release immediately after the call returns, and await the completion outside the lock scope (do not call the setter unlocked). E.g.: lock; await withCheckedContinuation { cont in device.setExposureTargetBias(Float(target)) { _ in cont.resume() }; device.unlockForConfiguration() } with no defer across the await — or equivalently start the setter under lock/unlock then await a continuation the completion resumes. Optionally add a timeout that throws typed CaptureError so a lost completion cannot suspend forever.


---

### `medium` ViewModel session flags diverge from service after interruption/reset

`pikicam/Features/Camera/CameraViewModel.swift:120` · kind=correctness · confidence=likely · votes=1|refute=0

**Evidence.** CaptureService.swift:200-204 `handleSessionInterruptionEnded` returns early `guard isConfigured, ...`; lines 180-185 clear `isConfigured = false` on media-services reset. CameraViewModel.swift:120-134 `start()` sets `isConfigured = true` / `isSessionRunning = true` only on explicit start, and lines 136-142 only clear them on explicit `stop()` — nothing observes the service's interruption/runtime-error handlers.

**Failure scenario.** Media-services reset kills the session -> service sets isConfigured=false/isRunning=false, but ViewModel still shows isSessionRunning=true. Auto-resume is skipped (unconfigured), and `capture()` (guard line 259) proceeds into `capturePhoto`, which fails late with `.sessionNotConfigured`/`.noBayerFormatAvailable` instead of an honest 'camera interrupted' state; preview stays black until the user happens to re-enter the view.

**Proposed fix.** Expose read-only session state from CaptureService (e.g. `func sessionState() async -> (isConfigured: Bool, isRunning: Bool)`) and reconcile it in CameraViewModel before the `capture()` guard and after `start()`; surface an honest interrupted/error state with retry instead of stale `isSessionRunning=true`. Full AsyncStream/observation of `handleSessionInterrupted`/`handleSessionRuntimeError` is the complete fix.


---

### `medium` Volume shutter dead at min/max volume with no feedback

`pikicam/Features/Camera/VolumeButtonCaptureView.swift:59` · kind=ui-ux · confidence=certain · votes=1|refute=0

**Evidence.** VolumeButtonCaptureView.swift:59-63 `handleVolume` fires only `guard abs(current - lastVolume) > 0.001`; CameraView.swift:221-224 wires it directly to `viewModel.capture()`. AVAudioSession `outputVolume` saturates at 0.0/1.0.

**Failure scenario.** User at minimum volume presses volume-down (or at maximum presses volume-up): the slider value cannot move, delta is zero, the guard returns early — the shutter silently does nothing with no haptic, sound, or message telling the user the press was ignored.

**Proposed fix.** After each accepted trigger (and on view appear), reset the MPVolumeView slider / system volume to mid-range (~0.5) and sync lastVolume so every hardware press produces a non-zero delta; optionally treat a slider valueChanged event with zero outputVolume delta at 0.0/1.0 as an edge-press shutter (with debounce) or emit Margiela-consistent word-only/haptic feedback, without touching the five byte-exact strings in ADR 0002.


---

### — develop (10) —

### `high` baselineExposure=0 overrides the DNG default, it is not neutral

`pikicam/Features/Develop/CIRAWZeroProcessor.swift` · kind=correctness · confidence=likely · votes=2|refute=0

**Evidence.** Line 70: `apply(filter, "baselineExposure") { filter.baselineExposure = 0.0 }`. CIRAWFilter's default baselineExposure is the DNG tag value (typically ~0.5-1.0 EV of hidden gain), not 0.0 — forcing 0.0 darkens the frame relative to the shot the sensor recorded, which is a develop alteration, not the absence of one. The header comment (lines 8-13) claims only demosaic/black-level/color-matrix/WB run, but this line adds a fourth radiometric change.

**Failure scenario.** Develop any iPhone DNG whose BaselineExposure tag is nonzero (the common case) -> the rendition is ~that many stops darker than the AsShot default develop; the product's core 'no exposure beyond true defaults' claim is violated on every capture.

**Proposed fix.** Remove the ("baselineExposure", { $0.baselineExposure = 0.0 }) entry from CIRAWZeroProcessor.recipe (currently line 65) so the filter keeps its per-image default (the DNG BaselineExposure tag); document the exclusion alongside the neutralTemperature/decoderVersion exclusions. Update testZeroRecipeEnumeratesEveryEnhancementControl to drop "baselineExposure" from the expected set, and change testZeroRecipeReachesEveryControlOnARealFilter to capture filter.baselineExposure before applyZeroRecipe and assert it is unchanged afterwards (instead of asserting == 0).


---

### `medium` decoderVersion unpinned: zero-process output drifts across iOS releases

`pikicam/Features/Develop/CIRAWZeroProcessor.swift` · kind=correctness · confidence=likely · votes=2|refute=1

**Evidence.** applyZeroRecipe (lines 69-80) sets 10 controls but never sets CIRAWFilter.decoderVersion, whose default is kCIRAWDecoderVersionAuto (latest available). Apple changes demosaic/NR behavior between decoder versions, so the same DNG develops differently after an OS update with no code change and no test signal.

**Failure scenario.** Ship on iOS 26.5, user updates to 26.6+ with a new RAW decoder -> the same stored DNG re-develops to visibly different pixels in the viewer; 'what you framed is what you get' no longer holds across updates.

**Proposed fix.** Pin decoderVersion to an explicit supported constant (e.g. the newest version verified on-device) in applyZeroRecipe, and add a test asserting the pinned value.


---

### `medium` Chroma noise reduction knob missing from the 'every knob' recipe

`pikicam/Features/Develop/CIRAWZeroProcessor.swift` · kind=correctness · confidence=speculative · votes=1|refute=0

**Evidence.** The recipe (lines 70-79) zeroes luminanceNoiseReductionAmount but never touches color/chroma noise reduction, while the doc comment (lines 15-23) claims 'All subjective enhancements are explicitly disabled' and 'every enhancement knob zeroed or disabled explicitly'. On current iOS the chroma-NR default is nonzero, so color smoothing runs silently inside a pipeline advertised as having none.

**Failure scenario.** Develop a high-ISO DNG -> chroma blotches are smoothed by the filter default while the UI/copy claims zero noise reduction; a user comparing against a true-default decode sees pikicam altering color detail.

**Proposed fix.** Add `apply(filter, "colorNoiseReductionAmount") { filter.colorNoiseReductionAmount = 0.0 }` alongside line 75, and update the doc comment's NR bullet to name both luminance and color/chroma controls.


---

### `medium` Bayer-format query hops to MainActor for no reason

`pikicam/Features/Camera/CaptureService.swift` · kind=api-misuse · confidence=certain · votes=1|refute=0

**Evidence.** Lines 621-627: `queryActiveBayerFormat()` wraps `photoOutput.availableRawPhotoPixelFormatTypes` in `await MainActor.run`. AVCapturePhotoOutput is owned by CaptureService's serial-executor actor; a plain property read needs no main-thread hop, and CaptureService's own design keeps AVFoundation off-main.

**Failure scenario.** Call capturePhoto during a main-thread stall (e.g. viewer transition) -> the Bayer check blocks behind the main actor before the exposure even starts, adding main-thread latency to the shutter path for zero thread-safety benefit.

**Proposed fix.** Drop the MainActor hop in queryActiveBayerFormat() (CaptureService.swift:621-627) and read photoOutput directly on the actor's serial executor: return photoOutput.availableRawPhotoPixelFormatTypes.filter { Self.isBayerRawPixelFormat($0) }.first


---

### `medium` Viewer rasterizes the full cropped sensor bitmap just to display it

`pikicam/Features/Develop/DevelopService.swift` · kind=perf · confidence=certain · votes=1|refute=0

**Evidence.** renderBitmap (lines 76-81): `ciContext.createCGImage(ciImage, from: ciImage.extent)` renders the entire cropped extent (up to full-sensor ~12-48 MP) into a CGImage; GalleryView.swift line 240 wraps it in UIImage and shows `.scaledToFit()`. No downsample-to-screen-size step exists anywhere in the render path.

**Failure scenario.** Open a 48 MP capture in the viewer -> a ~200 MB RGBA bitmap is allocated and held in @State for a ~2 MP on-screen image; paging several captures risks jetsam events on older devices.

**Proposed fix.** Add a target-pixel-size (screen-size) parameter to DevelopService.render/renderBitmap and scale the framed CIImage (e.g. Lanczos scale to screen bounds) before ciContext.createCGImage; keep the DNG asset untouched as the full-sensor original.


---

### `medium` No test pins any zero-recipe knob value

`pikicamTests/PikicamPipelineTests.swift` · kind=test-gap · confidence=certain · votes=1|refute=0

**Evidence.** testZeroDevelopProducesViewableJPEGFromRealDNG (lines 38-65) asserts only extent > 1000px and average luminance > 5.0; testZeroDevelopAppliesFramingCropInDevelopedSpace (lines 74-104) asserts only crop geometry. Nothing reads back a single CIRAWFilter property, so re-enabling sharpening, exposure, or contrast would pass the whole suite.

**Failure scenario.** A future edit sets sharpnessAmount = 1.0 (or a setter starts existing on a new iOS and applies a nonzero default) -> all tests stay green while the zero-process guarantee is silently gone.

**Proposed fix.** Add a test that asserts the recipe, not just its output geometry: expose an internal seam (e.g. make applyZeroRecipe(_:) internal or add internal configuredFilter(for:) / factory-injected CIRAWFilter), build a filter from the existing DNG fixture (skip when absent — a truly fixture-free CIRAWFilter is not possible since CIRAWFilter(imageData:) returns nil for invalid data), run the recipe, and for every control in CIRAWZeroProcessor.applyZeroRecipe lines 70-79 assert neutral when the setter exists (baselineExposure/exposure/boostAmount/shadowBias/localToneMapAmount/luminanceNoiseReductionAmount/sharpnessAmount/contrastAmount == 0, isLensCorrectionEnabled/isGamutMappingEnabled == false). Do not assert decoderVersion until the recipe actually pins it — it is not set today.


---

### `low` Missing setters are skipped silently with no log or test signal

`pikicam/Features/Develop/CIRAWZeroProcessor.swift` · kind=test-gap · confidence=certain · votes=1|refute=0

**Evidence.** Lines 86-90: `guard filter.responds(to: setter) else { return }` — on runtimes lacking a setter (simulator CIRAWFilterImpl, iPhone 12 mini per the comment on lines 56-58) the assignment is dropped without logging, asserting, or recording which controls were skipped. Combined with the unpinned decoderVersion, two devices can run different effective recipes with zero observability.

**Failure scenario.** Run on a device whose runtime lacks e.g. localToneMapAmount -> tone mapping stays at whatever that runtime's default is, the test suite still passes (it only checks non-black + dimensions), and nobody can tell from logs which knobs were actually applied.

**Proposed fix.** Keep skip-not-error semantics (do not throw); add os_log/DEBUG reporting of skipped control names plus a test-only accessor returning the skipped set, and log/report the active decoderVersion alongside it so per-model drift is visible in device test output.


---

### `low` Metal CIContext is constructed on the caller's thread, including main

`pikicam/Features/Develop/DevelopService.swift` · kind=concurrency · confidence=certain · votes=1|refute=0

**Evidence.** init (lines 21-33) calls MTLCreateSystemDefaultDevice() + CIContext(mtlDevice:options:) synchronously on the constructing executor. GalleryView.swift line 154 does `@State private var developService = DevelopService()` (main actor), and the tests do `let service = DevelopService()`. AGENTS.md explicitly rules 'never touch [the Metal-backed CIContext] from the main thread'.

**Failure scenario.** Open the full-screen viewer -> main-thread Metal device + CIContext creation hitches the UI transition (Metal setup allocates/heavy first-use cost on the thread that creates the context), violating the project's own threading rule on every viewer open.

**Proposed fix.** Defer Metal work off the constructing thread: make ciContext lazy (created on first render inside the actor's executor) or inject a background-constructed CIContext; one shared service owned outside the viewer would also avoid per-open reconstruction cost.


---

### `low` render() accepts unvalidated zoom; CapturedDNG rejects the same values

`pikicam/Features/Develop/DevelopService.swift` · kind=cleanup · confidence=certain · votes=1|refute=0

**Evidence.** render signature lines 57-61: `zoomFactor: CGFloat = 1.0` with no validation, while CapturedDNG.init (PhotoLibraryManager.swift lines 31-33) throws .invalidZoomFactor for non-finite or < 1 values. PrintCrop.zoomRect's only guard is `zoomFactor > 1.0 else return aspectRect`, so NaN/negative silently behave as 1x and huge values produce degenerate rects that surface only as generic .renderingFailed.

**Failure scenario.** Call render(dngData:zoomFactor: .nan) directly (test, share extension, future caller) -> silently develops the 1x frame instead of a typed error, contradicting the validated boundary the capture path enforces.

**Proposed fix.** Mirror the CapturedDNG boundary in DevelopService.render: guard zoomFactor.isFinite && zoomFactor >= 1 else throw DevelopError.invalidZoomFactor(zoomFactor); add `case invalidZoomFactor(CGFloat)` to DevelopError; add unit test that render with .nan/.infinity/0/0.5 throws the typed case. Do not silently clamp — typed error matches the project's boundary-error convention.


---

### `low` AGENTS.md, CONTEXT.md, and test names describe a pipeline that no longer exists

`AGENTS.md` · kind=docs-drift · confidence=certain · votes=1|refute=0

**Evidence.** AGENTS.md lines 68-70 document `CaptureMode zero/standard/rawOnly` (no CaptureMode exists in RAWProcessor.swift — zero is the only recipe); line 104 repeats the CaptureMode.zero rule; repo-map line 70 mentions JPEG encoding in DevelopService (nothing is ever encoded — DNGDisplayRendition is CIImage+CGImage, and the test name testZeroDevelopProducesViewableJPEGFromRealDNG asserts no JPEG). CONTEXT.md lines 42-44 define Zoom as 'a sensor crop applied to both the Capture and the Print', but CaptureService captures full-sensor 1x always and zoom is a develop-time crop only.

**Failure scenario.** A new contributor implements CaptureMode.standard, adds JPEG encoding, or 'fixes' capture to sensor-crop at zoom — following the docs into work the codebase deliberately removed — or a reviewer approves a change believing JPEG output exists.

**Proposed fix.** Update AGENTS.md repo map: replace '(`CaptureMode` zero/standard/rawOnly + `DevelopError`)' with '(`DevelopError`, `DNGDisplayRendition`)', replace 'rendering, JPEG encoding' with 'rendering into transient DNGDisplayRendition (CIImage+CGImage, never JPEG-encoded)'; fix convention bullet to reference the zero-process recipe instead of `CaptureMode.zero`; rename test to testZeroDevelopProducesViewableRenditionFromRealDNG and fix the PikicamPipelineTests.swift:11 comment ('viewable JPEG' → 'viewable rendition'); correct CONTEXT.md Zoom to 'develop-time crop of a full-sensor capture' and Print definition away from 'JPEG rendition'.


---

### — docs (17) —

### `high` AGENTS.md says Features/Gallery is removed; GalleryView.swift and PikicamLibraryModel.swift exist

`AGENTS.md:73` · kind=docs-drift · confidence=certain · votes=2|refute=0

**Evidence.** AGENTS.md:73 — "- `pikicam/Features/DualCamera|Gallery|Review|Settings/` — removed and committed; do not resurrect them unless asked."

Actual tree: `pikicam/Features/Gallery/GalleryView.swift` (GalleryView, FullScreenViewer, AsyncThumbnail) and `pikicam/Features/Gallery/PikicamLibraryModel.swift` are both present and referenced: `pikicam/Features/Camera/CameraView.swift` presents `GalleryView`; `pikicam/Features/Gallery/GalleryView.swift:6` — `@Environment(PikicamLibraryModel.self) private var library`. README.md:113 also documents `pikicam/Features/Gallery/` as current. Only DualCamera/Review/Settings are actually gone.

**Failure scenario.** An agent (or new contributor) reading AGENTS.md treats the entire gallery + library model as deleted. Because the same line carries a standing "do not resurrect" instruction, they either delete working files or refuse to touch the Library code path at all — and any fix they make in GalleryView/PikicamLibraryModel gets reverted as a "resurrection".

**Proposed fix.** Rewrite AGENTS.md:73-74 as: "- `pikicam/Features/DualCamera|Review|Settings/` — removed and committed; do not resurrect them unless asked. `pikicam/Features/Gallery/` is current (`GalleryView.swift`, `PikicamLibraryModel.swift`)."


---

### `high` CONTEXT.md defines "Print" as a JPEG rendition; the code never encodes a JPEG anywhere

`CONTEXT.md:23` · kind=docs-drift · confidence=certain · votes=2|refute=0

**Evidence.** CONTEXT.md:23-24 — "**Print**: The developed image of a Capture (the JPEG rendition the viewer and gallery thumbnails show)."

The code has no JPEG artifact:
- `pikicam/Features/Develop/DevelopService.swift:13-15` — "Nothing here is persisted: no JPEG is encoded and no file is written."
- `pikicam/Features/Develop/RAWProcessor.swift:27-28` — "It is never encoded to JPEG, written to disk, or persisted anywhere."
- Gallery thumbnails come from PhotoKit, not the develop pipeline: `PhotoLibraryManager.swift:695` — `PHImageManager.default().requestImage(`.
- README.md:5-6 agrees with the code ("no hidden print") and contradicts CONTEXT.md.
- "Print" appears in zero Swift identifiers; the only hit is a test comment `CameraControlTests.swift:167 — // MARK: - Print crop`.

**Failure scenario.** Someone reads the glossary, greps for the Print pipeline, finds nothing, and concludes the Print layer was deleted or that gallery thumbnails bypass zero-process. They may then 'restore' JPEG encoding, directly violating the product's core promise stated in README.md:5.

**Proposed fix.** Redefine Print in CONTEXT.md as the transient in-memory display rendition (DNGDisplayRendition: developed CIImage + rendered CGImage bitmap) produced by DevelopService.render with PrintCrop framing applied, explicitly never encoded to JPEG or persisted; note gallery thumbnails are PhotoKit renderings via PHImageManager, not develop-pipeline output; cross-reference README.md "no hidden print" as authority.


---

### `high` CONTEXT.md caps Zoom at 5×; the code has no cap and follows the device's max zoom (up to 25×)

`CONTEXT.md:43` · kind=docs-drift · confidence=certain · votes=2|refute=0

**Evidence.** CONTEXT.md:43 — "**Zoom**: The 1×–5× magnification factor; a sensor crop applied to both the Capture and the Print".

The code has no 5× ceiling:
- `pikicam/Features/Camera/CaptureService.swift:331` — `return device.minAvailableVideoZoomFactor...device.maxAvailableVideoZoomFactor`
- `pikicam/Features/Camera/CameraControls.swift:81-85` — `clamped(_:range:)` clamps only to that device range.
- 5.0 is only a preset-chip candidate, not a limit: `CameraControls.swift:224` — `for candidate in [CGFloat(2.0), CGFloat(5.0)] where range.contains(candidate)`.

On a Pro-tier iPhone maxAvailableVideoZoomFactor is ~25, and pinch is unclamped above the device max only by the device itself (`CameraView.swift:286-302`, MagnificationGesture → `ZoomMath.factor(..., range: viewModel.zoomRange)`).

**Failure scenario.** A user on a Pro iPhone pinches to 15×; an agent debugging or a QA checklist derived from CONTEXT.md treats 15× as out-of-contract and files it as a bug, or a doc fix caps the glossary at 5× while the UI happily shows 15×.

**Proposed fix.** Change CONTEXT.md:43 from "The 1×–5× magnification factor" to "The device-available magnification (1× up to the camera's maxAvailableVideoZoomFactor; 1×/2×/5× are preset chips when in range)".


---

### `high` AGENTS.md "Repository state": says clean tree / 7 commits; actual is 32 commits with 7 modified + 2 untracked

`AGENTS.md:109` · kind=docs-drift · confidence=certain · votes=2|refute=0

**Evidence.** AGENTS.md:109-110 — "Working tree is **clean**: 7 commits on `main` (initial + 6 setup/docs/device commits: AGENTS.md, lint/format + verify chain, xcodegen model, test target + legacy-pipeline removal, swift-coding-standards skill, device walkthrough test + iOS 26.6 findings)."

`git rev-list --count HEAD` → 32. `git status --short` →
 M pikicam/Core/Storage/PhotoLibraryManager.swift
 M pikicam/Features/Camera/CameraControls.swift
 M pikicam/Features/Camera/CameraViewModel.swift
 M pikicam/Features/Camera/CaptureService.swift
 M pikicam/Features/Camera/PhotoCapture.swift
 M pikicamTests/CameraControlTests.swift
 M pikicamTests/PikicamPipelineTests.swift
?? CONTEXT.md
?? docs/adr/

The named "6 setup/docs/device commits" (414052e, 5e82fa9, e62a6d8, 6d892b3, 132966a, a01195e) are real but are 25 commits back, superseded by 7aacfe9 "feat: framing metadata pipeline + capture UX rework".

**Failure scenario.** AGENTS.md:111-113 tells the agent "Do not mass-`git add -A`; stage only what the current task touches" on the assumption the tree is otherwise clean. With 7 files of unrelated in-flight work, an agent that trusts the doc and stages broadly sweeps another task's half-finished changes into its commit.

**Proposed fix.** Delete the point-in-time state sentence in AGENTS.md:109-110 ("Working tree is clean: 7 commits on main ..."). Replace with timeless guidance only, e.g. "Check git status/log for current state; stage only what the current task touches, never mass git add -A." Do not assert a commit count or clean tree.


---

### `high` AGENTS.md names CaptureMode (zero/standard/rawOnly); the type was deleted and the code says so explicitly

`AGENTS.md:69` · kind=docs-drift · confidence=certain · votes=2|refute=0

**Evidence.** AGENTS.md:68-69 — "`pikicam/Features/Develop/` — the RAW develop pipeline: `RAWProcessor.swift` (`CaptureMode` zero/standard/rawOnly + `DevelopError`)". AGENTS.md:104-105 repeats it: "**Zero-process honesty**: `CaptureMode.zero` must keep every enhancement knob explicitly disabled".

There is no `CaptureMode` anywhere in the codebase (zero hits in `pikicam/**/*.swift`; the only hits in the repo are AGENTS.md:69 and AGENTS.md:104). The code explicitly denies it:
- `pikicam/Features/Develop/RAWProcessor.swift:8-9` — "Zero-process is the only development recipe — there are no capture modes."
- `RAWProcessor.swift:30` — `struct DNGDisplayRendition: Sendable` and `RAWProcessor.swift:40` — `enum DevelopError` are what actually live in that file.

**Failure scenario.** An agent asked to verify the zero-process honesty rule searches for `CaptureMode.zero`, finds nothing, concludes the rule is unenforced, and adds an exposure/sharpening path under a newly invented CaptureMode — the exact regression the rule exists to prevent.

**Proposed fix.** Delete `CaptureMode` from AGENTS.md:69 and re-target the honesty rule at CIRAWZeroProcessor: "Zero-process honesty: `CIRAWZeroProcessor` is the only develop recipe (there are no capture modes); keep every CIRAWFilter knob explicitly disabled — do not add exposure/nr/sharpening."


---

### `medium` ADR 0001's Margiela language is contradicted everywhere: yellow accents, rounded fonts, capsules, dark gallery

`docs/adr/0001-ui-adopts-margiela-design-system.md:4` · kind=docs-drift · confidence=certain · votes=2|refute=0

**Evidence.** ADR 0001:4 — "monochrome white room, Courier New type, hairline rules, word-only controls, no rounding, no accents." ADR 0001:9 — "White room includes the gallery; the camera viewport stays black — it is the one dark room."

Code contradicts all of it:
- Accents: 12 `.yellow` uses — `GalleryView.swift:43,77,86,93,100,175,178`, `CameraView.swift:142,161,192,441`, `RootView.swift:86`.
- Rounded type: 8 `design: .rounded` — `CameraView.swift:133,157,440,482`, `CameraHUDButton.swift:23`, `ZoomIndicatorView.swift:10`.
- Rounding: 5 `Capsule()` — `CameraView.swift:144,162,417,444`, `ZoomIndicatorView.swift:15`; plus `RoundedRectangle` at `CameraView.swift:186`, `GalleryView.swift:26,132`.
- No Courier New anywhere: zero hits for `Courier` or `UIAppFonts` in `pikicam/**` and `pikicam/Resources/Info.plist`.
- Dark gallery: `GalleryView.swift:14` — `Color.black.ignoresSafeArea()`, and `GalleryView.swift:69` — `.preferredColorScheme(.dark)`.

**Failure scenario.** A reviewer approving a change against the Margiela ADR sees a new accent/rounded control as compliant; a reviewer reading the code sees the ADR as the source of truth and rejects a change that removes a yellow capsule because "yellow is a deliberate Margiela violation" — the ADR is a live, load-bearing decision record pointing at the opposite of the shipped UI.

**Proposed fix.** Supersede ADR 0001 with a new ADR recording what actually shipped (SF Rounded, yellow accent, black gallery) and why, or restyle the code to match 0001. Leaving an accepted-but-unimplemented ADR in docs/adr/ makes the decision record unusable.


---

### `medium` AGENTS.md: "currently 5 tests" — the suite has 43 tests across two files, one of which AGENTS.md never mentions

`AGENTS.md:75` · kind=docs-drift · confidence=certain · votes=2|refute=0

**Evidence.** AGENTS.md:75-76 — "- `pikicamTests/` — XCTest suite: `PikicamPipelineTests.swift` (capture/develop/storage behavior; currently 5 tests, incl. device-only Photos probes)."

Actual: `PikicamPipelineTests.swift` has 8 `func test` (testCaptureFailsCleanlyWithoutBayerSensor, testZeroDevelopProducesViewableJPEGFromRealDNG, testZeroDevelopAppliesFramingCropInDevelopedSpace, testStorageSavesDNGSinglePhotoResourceToPhotos, testDevicePhotosLibraryContainsCapturedDNGSingleResource, testDeviceProbePhotosSaveResourceVariants, testCapturedDNGRejectsEmptyData, testCapturedDNGRejectsInvalidZoomFactor). A second file, `pikicamTests/CameraControlTests.swift`, adds 35 more (zoom, flash, grid, self-timer, aspect, PrintCrop, EV) and appears nowhere in the repo map.

**Failure scenario.** An agent adding a test for framing geometry writes it into PikicamPipelineTests.swift (per the map's file-to-concern assignment) and never discovers CameraControlTests.swift already has 20 PrintCrop/EV tests, duplicating coverage instead of extending it. The stale count also makes 'add the 6th test' style reasoning wrong.

**Proposed fix.** Drop the hardcoded count and list both files in /Users/adrifadilah/Desktop/pikicam/AGENTS.md:75-76, e.g. "- `pikicamTests/` — `PikicamPipelineTests.swift` (capture/develop/storage) and `CameraControlTests.swift` (framing math: zoom, aspect, PrintCrop, EV, grid, flash, self-timer)."


---

### `medium` AGENTS.md names StorageServiceError; the actual storage error type is PhotoLibraryError

`AGENTS.md:94` · kind=docs-drift · confidence=certain · votes=2|refute=0

**Evidence.** AGENTS.md:93-95 — "**Error handling at boundaries**: capture/develop/storage failures use typed enums (`CaptureError`, `DevelopError`, `StorageServiceError`, `CameraViewModelError`)".

`grep -rn StorageServiceError` returns exactly two hits, both documentation: AGENTS.md:94 and `.agents/skills/swift-coding-standards/SKILL.md:24,50`. The real type is:
- `pikicam/Core/Storage/PhotoLibraryManager.swift:152` — `nonisolated public enum PhotoLibraryError: LocalizedError, Equatable, Sendable {`
README.md:126 gets this right: "(`CaptureError`, `DevelopError`, `PhotoLibraryError`)".

**Failure scenario.** An agent writing a `catch` in a storage path writes `catch let error as StorageServiceError` (nonexistent → compile error), or worse writes `catch { }` after concluding the boundary is untyped, silently swallowing PhotoLibraryError.indexWriteFailed and losing the pending-record cleanup path at PhotoLibraryManager.swift:322-325.

**Proposed fix.** Change `StorageServiceError` to `PhotoLibraryError` in AGENTS.md:94 and in `.agents/skills/swift-coding-standards/SKILL.md:24,50`.


---

### `medium` pikicam/Resources/Info.plist is tracked but referenced by nothing, and its strings disagree with project.yml

`pikicam/Resources/Info.plist:1` · kind=cleanup · confidence=certain · votes=1|refute=0

**Evidence.** `grep -c "Info.plist" pikicam.xcodeproj/project.pbxproj` → 0. The pbxproj builds settings, not a file reference: `pikicam.xcodeproj/project.pbxproj:565` — `GENERATE_INFOPLIST_FILE = YES;` with usage strings injected via `pbxproj:566-568`. `project.yml:26` even excludes it: `- "Resources/Info.plist"   # redundant: GENERATE_INFOPLIST_FILE=YES`.

The strings have since diverged:
- Checked-in `pikicam/Resources/Info.plist:8` — "pikicam needs camera access to capture Bayer RAW photos with zero computational processing."
- Authoritative `pikicam.xcodeproj/project.pbxproj:566` / `project.yml:36` — "pikicam needs camera access to capture DNG raw photos with zero computational processing."
Same divergence for both NSPhotoLibrary keys.

**Failure scenario.** Someone edits `pikicam/Resources/Info.plist` to change the camera permission prompt wording, ships, and the prompt is unchanged because the file is dead. Worse, an App Review rejection about privacy wording gets 'fixed' in the file that is never read.

**Proposed fix.** Delete tracked pikicam/Resources/Info.plist (git rm) so GENERATE_INFOPLIST_FILE=YES + INFOPLIST_KEY_* in project.yml/pbxproj is the sole source of truth; do not add an INFOPLIST_FILE reference.


---

### `medium` AGENTS.md's DevelopService description says "JPEG encoding"; the file's doc comment says it never encodes a JPEG

`AGENTS.md:70` · kind=docs-drift · confidence=certain · votes=1|refute=0

**Evidence.** AGENTS.md:70-71 — "`DevelopService.swift` (Metal-backed `CIContext` rendering, JPEG encoding)".

`pikicam/Features/Develop/DevelopService.swift:13-15` — "DevelopService is used only for transient full-screen rendering of the original DNG. Nothing here is persisted: no JPEG is encoded and no file is written."
`DevelopService.swift:44-46` — "The result is in-memory only — it is for transient UI display and is never encoded to JPEG or persisted."
`grep -rn "jpegDataRepresentation\|UIImage.jpegData" pikicam` → no hits. The only `JPEG` strings in the app are the negative doc comments above.

**Failure scenario.** An agent assigned to 'complete the Develop output' reads the map, sees JPEG encoding listed as existing, and hunts for a missing encode call or adds one — reintroducing the 'hidden print' that README.md:5 explicitly promises does not exist.

**Proposed fix.** Change AGENTS.md:70-71 from "`DevelopService.swift` (Metal-backed `CIContext` rendering, JPEG encoding)" to "`DevelopService.swift` (Metal-backed `CIContext` rendering to a transient in-memory bitmap; explicitly never encodes a JPEG or writes a file)".


---

### `medium` project.yml defines two conflicting 'pikicam' schemes; the target-level one omits pikicamUITests

`project.yml:25` · kind=docs-drift · confidence=likely · votes=1|refute=0

**Evidence.** `project.yml:25-28` attaches a scheme to the app target:
    scheme:
      testTargets:
        - pikicamTests
Then `project.yml:48-58` declares a top-level scheme of the same name:
    schemes:
      pikicam:
        test: targets: [pikicamTests, pikicamUITests]

Both are named `pikicam`, so a regeneration emits two schemes with the same name (or silently drops one), and the target-scoped one contradicts AGENTS.md:116-117: "shared scheme `pikicam` (test action runs both test targets; UI tests self-skip per environment)" and README.md:99: "The shared scheme's test action runs `pikicamTests` and `pikicamUITests`".

**Failure scenario.** The next person who installs xcodegen (the file's own instruction at project.yml:11-13) regenerates the project and either gets a name collision or a `pikicam` scheme whose test action silently excludes pikicamUITests — the device walkthrough and simulator smoke check stop running with no error, since the test action still succeeds with only the unit target.

**Proposed fix.** Delete the target-level `scheme:` block at project.yml:42-44 and keep only the top-level `schemes: pikicam:` (lines 71-83) that lists both test targets.


---

### `medium` CONTEXT.md's glossary omits seven load-bearing concepts the code uses daily

`CONTEXT.md:7` · kind=feature-gap · confidence=certain · votes=1|refute=0

**Evidence.** CONTEXT.md's "## Language" section defines exactly nine terms: Capture, DNG, Develop, Print, Zero-process, Aperture, Aspect Ratio, Zoom, Preview, Library.

The code has concepts with no entry:
- Grid — `pikicam/Features/Camera/GridOverlayView.swift`, `CameraControls.swift:104` `nonisolated enum GridGeometry`, 20 tests in CameraControlTests.
- Self-timer — `pikicam/Features/Camera/CameraViewModel.swift:348` `nonisolated enum SelfTimerOption`, cases `.threeSeconds`/`.tenSeconds`.
- Exposure compensation — `CameraControls.swift:249` `nonisolated struct ExposureCompensation`, ±3 EV in 1/3 stops, 6 tests.
- Flash / torch — `CameraControls.swift:40` `nonisolated enum FlashMode`, 4 tests.
- Framing metadata (aspect+zoom+orientation persisted per capture) — `PhotoLibraryManager.swift:909-922` `struct IndexRecord` with `aspectRatio`/`zoomFactor`/`orientation`, added by commit 7aacfe9.
- Capture orientation — `pikicam/Features/Develop/DevelopService.swift:79` `public enum CaptureOrientation`.
- Library index / provenance — `PhotoLibraryManager.swift:900` `struct CaptureIndex`, 4 cases of indexReadFailed/indexWriteFailed/indexCommitFailed/indexRemovalFailed.

**Failure scenario.** Someone uses the glossary as the vocabulary contract (that is its stated purpose) and renames or re-documents `ExposureCompensation` as an 'EV setting' or `IndexRecord` as 'metadata', because the ubiquitous language has no word for either — the split vocabulary spreads through new code and comments while CONTEXT.md silently goes stale.

**Proposed fix.** Add glossary entries for Grid, Self-timer, Exposure compensation, Flash, Framing metadata (aspect ratio × zoom × orientation, persisted per capture), and Library index. Keep the existing _Avoid_ lists so the naming discipline has teeth.


---

### `medium` AGENTS.md repo map omits seven live source files plus CameraControlTests and docs/

`AGENTS.md:64` · kind=docs-drift · confidence=certain · votes=1|refute=0

**Evidence.** AGENTS.md:64-67 lists the Camera feature as "CaptureService.swift, PhotoCapture.swift, CameraPreview.swift, CameraViewModel.swift, CameraView.swift, PreviewView.swift, Views/ShutterButton.swift". Not listed but present and used:
- `pikicam/Features/Camera/CameraControls.swift` — 300+ lines holding `AspectRatio`, `PrintCrop`, `ZoomMath`, `ZoomPresets`, `ExposureCompensation`, `GridGeometry`, `FlashMode`; the single most-modified file in the tree.
- `pikicam/Features/Camera/CameraHUDButton.swift`, `GridOverlayView.swift`, `ZoomIndicatorView.swift`, `VolumeButtonCaptureView.swift` — all referenced from `CameraView.swift`.
- `pikicam/Features/Gallery/GalleryView.swift`, `PikicamLibraryModel.swift` (see the Gallery finding).
- `pikicamTests/CameraControlTests.swift` (35 tests), `pikicam/Resources/Info.plist`, `pikicam/Resources/PrivacyInfo.xcprivacy`.
- `docs/adr/0001-ui-adopts-margiela-design-system.md`, `docs/adr/0002-camera-chrome-stays-visible.md`, and `CONTEXT.md` are untracked and entirely unmentioned.

**Failure scenario.** An agent told to 'update the camera controls' opens CameraView.swift, finds none of the control math there, and either adds duplicate framing math to the view or declares the file missing. Meanwhile the two ADRs — the only record of why the UI looks the way it does — are invisible to it.

**Proposed fix.** Regenerate the repo map from the actual tree: add CameraControls.swift, the four unlisted Camera views, Features/Gallery/, CameraControlTests.swift, Resources/, docs/adr/, and CONTEXT.md.


---

### `low` CONTEXT.md defines Aperture as Aspect × Zoom, but the live aperture mask is computed at zoom 1.0 only

`CONTEXT.md:33` · kind=docs-drift · confidence=likely · votes=1|refute=0

**Evidence.** CONTEXT.md:32-34 — "**Aperture**: The compositional frame region defined by Aspect Ratio × Zoom (the `PrintCrop` rect)."

`pikicam/Features/Camera/CameraView.swift:355` — `let aperture = PrintCrop.rect(in: bounds, zoomFactor: 1.0, aspect: aspectRatio)` — the on-screen mask passes zoomFactor 1.0, and the code says why at `CameraView.swift:343-345`: "the same `PrintCrop` math the develop pipeline applies to the DNG at 1× zoom". Zoom reaches the preview through the device instead (`CameraView.swift:286-302` → `CaptureService.setVideoZoomFactor` → `device.videoZoomFactor`), not through the mask geometry. The develop-time crop does use both: `DevelopService.swift:67` — `PrintCrop.rect(in: ciImage.extent, zoomFactor: zoomFactor, aspect: aspectRatio)`.

**Failure scenario.** Someone implementing a new Aperture-driven feature (e.g. tapping inside the mask to set exposure) reads the glossary, computes Aspect × Zoom, and builds a rect that disagrees with the live mask by the zoom factor — the overlay they draw does not line up with what DevelopService later crops.

**Proposed fix.** Split CONTEXT.md Aperture entry: live Aperture mask is Aspect Ratio only in view space (CameraView.swift:355 passes zoomFactor 1.0 because zoom is already applied by device.videoZoomFactor), while the develop-time PrintCrop is Aspect Ratio x Zoom in image space (DevelopService.swift:67). Cite both call sites and the coordinate-space distinction.


---

### `low` AGENTS.md:63 attributes the simulator Photos failure to a RAW 'companion'; the app no longer writes companions

`AGENTS.md:63` · kind=docs-drift · confidence=certain · votes=1|refute=0

**Evidence.** AGENTS.md:62-63 — "`pikicam/Core/Storage/` — `PhotoLibraryManager.swift` (Photos persistence; simulator rejects RAW companions with `PHPhotosErrorChangeNotSupported`)".

The error code is right — `Photos.framework/Headers/PHError.h:29`: `PHPhotosErrorChangeNotSupported ... = 3300` — but there are no companions anymore. The app writes exactly one resource: `PhotoLibraryManager.swift:371-372` — `options.originalFilename = originalFilename; options.uniformTypeIdentifier = Self.dngUTType.identifier`. The pairing machinery is only in the device probe test, `pikicamTests/PikicamPipelineTests.swift:297-307` ("standard-pair(.photo jpeg + .alternatePhoto dng...)"). The test's own skip message is accurate: `PikicamPipelineTests.swift:129` — "Simulator Photos rejects RAW assets (3300)."

**Failure scenario.** An agent investigating a simulator save failure reads 'RAW companions' and starts looking for a leftover .alternatePhoto pairing in the save path, finding none, and concludes the doc is describing code that should exist — or 'restores' the two-resource pairing that commit a01195e deliberately removed to fix the iOS 26.6 save failure.

**Proposed fix.** Reword AGENTS.md:63 (and :102-103) to "...; the simulator's Photos rejects the single `.photo` DNG resource with `PHPhotosErrorChangeNotSupported` (3300) — see PikicamPipelineTests.swift:129."


---

### `low` AGENTS.md describes SmokeLaunchTest as two tests; it now has three including a zoomed stress walkthrough

`AGENTS.md:79` · kind=docs-drift · confidence=certain · votes=1|refute=0

**Evidence.** AGENTS.md:79-81 — "- `pikicamUITests/` — `SmokeLaunchTest.swift`: simulator launch smoke check (typed camera-unavailable message) and physical-device capture→save walkthrough with screenshots."

`pikicamUITests/SmokeLaunchTest.swift` has three tests:
- :36 `func testLaunchAndCameraUnavailableErrorShown()`
- :98 `func testDeviceCaptureWalkthrough()`
- :510 `func testDeviceCaptureStressWhileZoomed()`

The "812 lines" figure in ADR 0002:6 is accurate (`wc -l` → 812), so the line count is not the problem — the test inventory is.

**Failure scenario.** An agent asked to add a zoomed-capture device check greps the map, sees only a 'walkthrough', and either duplicates the existing stress test or assumes zoomed capture is uncovered. Neither is true.

**Proposed fix.** Update AGENTS.md:79-81 to name all three tests: "simulator launch smoke check, device capture→save walkthrough, and a device zoomed-capture stress walkthrough (`testDeviceCaptureStressWhileZoomed`)". Also update AGENTS.md:47-49 which similarly describes only one device walkthrough.


---

### `low` README 'How it works' and 'Project structure' are accurate, but README omits the CameraControls file that holds all framing math

`README.md:110` · kind=docs-drift · confidence=certain · votes=1|refute=0

**Evidence.** README.md:110 — "- `pikicam/Features/Camera/` — session, preview, capture, controls, HUD." This is the vaguest line in the README and it papers over the omission: `pikicam/Features/Camera/CameraControls.swift` (AspectRatio, PrintCrop, ZoomMath, ZoomPresets, ExposureCompensation, GridGeometry, FlashMode) is where every piece of framing math the README advertises actually lives, and neither README nor AGENTS.md names it.

Everything else I checked in README holds up: the four device-walkthrough commands, the bundle id, the `pikicam-<uuid>.dng` filename (`PhotoLibraryManager.swift:886` — `"pikicam-\(captureID.uuid.uuidString).dng"`), the `pending`→`stored` journal (`PhotoLibraryManager.swift:923-935`), and the versioned Application Support index (`PhotoLibraryManager.swift:817` — `"pikicam-capture-index-v\(indexFileVersion).json"`).

**Failure scenario.** Nothing breaks, but the README's only pointer to the framing pipeline sends a reader to a directory where the pipeline is not. The most subtle claim in the product — 'the Print always matches the framing shown at capture time' — has no file reference behind it in either doc.

**Proposed fix.** Name the file: "- `pikicam/Features/Camera/CameraControls.swift` — the pure framing math: Aspect Ratio, PrintCrop, zoom, exposure compensation, grid, flash."


---

### — gallery (11) —

### `high` Bottom-bar latest thumbnail never refreshes: AsyncThumbnail .task has no id

`pikicam/Features/Gallery/GalleryView.swift:266` · kind=correctness · confidence=certain · votes=2|refute=0

**Evidence.** GalleryView.swift:19-27 renders `if let latest = library.captures.first { ... AsyncThumbnail(assetID: latest.assetID, library: library) }`, and AsyncThumbnail.swift:266 loads with a bare `.task { image = try await library.loadThumbnail(for: assetID) }`. A `.task` without an `id:` is bound to the view's structural identity, not its inputs: when `captures` changes, the body re-evaluates with a new `assetID`, but the task does not re-run and `@State image` keeps the previous capture's bitmap.

**Failure scenario.** Open the gallery, tap the toolbar thumbnail (selecting capture A), tap the camera button to dismiss, take capture B. Reopen the gallery: `captures.first` is now B, but the bottom-left thumbnail still shows A's pixels. Deleting the newest capture likewise leaves its thumbnail on screen after the grid drops it.

**Proposed fix.** `.task(id: assetID) { image = nil; image = try? await library.loadThumbnail(for: assetID) }` in AsyncThumbnail. Apply the same fix to the identical `ThumbnailImage.task` in CameraView.swift:328 (same latent bug on the camera dock).


---

### `high` Destructive delete acts on an invisible selection left over from a previous session

`pikicam/Features/Gallery/GalleryView.swift:39` · kind=correctness · confidence=certain · votes=2|refute=0

**Evidence.** `select(_:)` (PikicamLibraryModel.swift:50-52) only ever assigns; nothing clears `selectedCapture` when the gallery is dismissed or a new grid is shown, and the grid renders no selection state at all (GalleryView.swift:107-116 draws bare thumbnails). The bottom-bar trash is merely `.disabled(library.selectedCapture == nil)` and calls `deleteSelected()` (line 52), whose confirmation dialog is the generic "Delete capture?" with no identifying information.

**Failure scenario.** Session 1: open gallery, tap any thumbnail to view it, tap the camera button (`dismiss()`) — `selectedCapture` still holds that capture. Session 2: reopen gallery; the trash button is already enabled with nothing visibly selected, and the grid shows no highlight. Tap Trash → "Delete capture?" → Delete. A photo the user never selected in this session is destroyed, with no on-screen referent for what was deleted.

**Proposed fix.** Add `func deselect() { selectedCapture = nil }` to PikicamLibraryModel, call it from GalleryView `.onDisappear`, render the selected cell (e.g. overlay a yellow hairline when `capture.id == library.selectedCapture?.id`), and add a `message:` to the line-51 confirmationDialog naming the target via its `capturedAt` date.


---

### `high` Gallery grid cells expose no VoiceOver label; the selection is unreachable

`pikicam/Features/Gallery/GalleryView.swift:108` · kind=ui-ux · confidence=certain · votes=2|refute=0

**Evidence.** Each cell is `Button(action:) { AsyncThumbnail(...) }` whose only content is an `Image(uiImage:)` (line 258) or a gray `Rectangle()` — no `.accessibilityLabel` and no `.accessibilityElement(children:)` anywhere in the file (`grep accessibilityLabel` matches nothing under Features/Gallery). The model already carries `capturedAt`, `aspectRatio`, and `zoomFactor` per capture.

**Failure scenario.** VoiceOver swiping through a 200-item grid announces an unlabeled button per cell ("Button, image") with no way to tell captures apart, no count, and no date — the Library is unusable non-visually. The same applies to `gallery-latest-thumbnail`, `gallery-trash`, and `gallery-camera`, which are bare `Image(systemName:)` labels.

**Proposed fix.** Add spoken-only labels in GalleryView.swift without changing visuals: per grid cell `.accessibilityLabel("Capture \(index + 1) of \(count), \(capture.capturedAt.formatted(...))")` + `.accessibilityValue("\(aspectRatio) \(zoom)x")` keeping `gallery-cell-\(index)` identifiers; label toolbar buttons ("Latest capture", "Delete selected capture", "Back to camera").


---

### `high` Hiding the viewer chrome leaves VoiceOver users with no way back

`pikicam/Features/Gallery/GalleryView.swift:181` · kind=ui-ux · confidence=likely · votes=2|refute=0

**Evidence.** The only chrome-free restore path is `Color.clear.contentShape(Rectangle()).onTapGesture { ... chromeHidden.toggle() }` (lines 181-190). A transparent `Color` is not a VoiceOver focusable element, and the "Back to Camera" button lives inside `if !chromeHidden` (line 191-212), so activating the eye button removes the only reachable exit.

**Failure scenario.** A VoiceOver user activates "Hide controls". The eye button and the Back-to-Camera button both disappear; the transparent background is not reachable by swipe, so the viewer becomes a full-screen dead end requiring force-quitting the app.

**Proposed fix.** Make the tap-to-reshow background a real VoiceOver element without changing visuals or the camera-chrome ADR: on the `Color.clear.contentShape(Rectangle()).onTapGesture` layer (GalleryView.swift:181-190) add `.accessibilityElement()`, `.accessibilityLabel("Show controls")`, `.accessibilityAddTraits(.isButton)` and `.accessibilityHint("Shows the viewer controls, including Back to Camera")`. Do NOT take the report's second option of a permanently visible Back button — it would break the tested hide contract (`SmokeLaunchTest` asserts `viewer-chrome-toggle` goes non-existent after toggle) and the full-bleed viewer intent. Optionally also add `.accessibilityAction(.escape) { chromeHidden = false }` so the VoiceOver scrub gesture restores chrome.


---

### `medium` Delete from the viewer blanks the full-screen cover while refresh runs

`pikicam/Features/Gallery/GalleryView.swift:57` · kind=ui-ux · confidence=certain · votes=1|refute=0

**Evidence.** The cover's content is gated on the selection: `fullScreenCover(isPresented: $viewerPresented) { if let capture = library.selectedCapture { FullScreenViewer(...) } }`. `deleteSelected()` sets `selectedCapture = nil` (PikicamLibraryModel.swift:58) *before* awaiting `refresh()` (line 62), and only then does the caller set `isPresented = false` (GalleryView.swift:219-222). The black ZStack and all chrome live inside FullScreenViewer, so nil-ing the selection removes the entire presented content.

**Failure scenario.** Open the viewer, confirm Delete. `selectedCapture` becomes nil, the cover renders an empty view (no image, no chrome, no Back to Camera), and the cover stays presented for the full duration of `PhotoLibraryManager.captures()` — index read, reconcile, batched PHAsset fetch — which can be hundreds of ms or seconds on a large library or slow device. The user stares at a featureless screen, and if refresh ever stalled the cover would be an un-dismissable empty full-screen view.

**Proposed fix.** Keep the content stable: hold the presented capture in `@State private var viewerCapture: PikicamCapture?` set at present time, and gate the cover on that value rather than on `library.selectedCapture` (which the delete path mutates). Alternatively dismiss first, then delete.


---

### `medium` No thumbnail cache: every scroll back re-requests from PhotoKit, network allowed

`pikicam/Features/Gallery/PikicamLibraryModel.swift:74` · kind=perf · confidence=likely · votes=1|refute=0

**Evidence.** `loadThumbnail` calls `manager.requestThumbnail(for:targetPixelSize: CGSize(width: 300, height: 300))` with no memoization anywhere, and `requestThumbnail` sets `options.isNetworkAccessAllowed = true` (PhotoLibraryManager.swift:683). `AsyncThumbnail` holds the bitmap only in `@State`, which LazyVGrid discards when the cell leaves the viewport, and the identical asset is requested separately by the toolbar thumbnail (GalleryView.swift:24) and cell 0.

**Failure scenario.** Scroll a 200-capture library down and back up. Each reappearance of every cell issues a fresh PHImageManager request; for iCloud-backed captures that is an iCloud Photos download re-triggered on every pass, producing visible tile-in lag and avoidable data use. The newest capture is fetched twice on every open.

**Proposed fix.** Keep PHImageManager as the fetcher but (1) add a small NSCache keyed by assetID+size (or adopt PHCachingImageManager with startCachingImages for visible indexes) populated by loadThumbnail, (2) coalesce concurrent same-key requests into one in-flight Task, and (3) pass isNetworkAccessAllowed=false for grid tiles, reserving network access for the viewer full-res load.


---

### `medium` Viewer chrome buttons have no 44pt hit area

`pikicam/Features/Gallery/GalleryView.swift:196` · kind=ui-ux · confidence=certain · votes=1|refute=0

**Evidence.** `Button { chromeHidden.toggle() } label: { Image(systemName: chromeHidden ? "eye.slash" : "eye") }` and the adjacent trash `Button { deleteConfirmPresented = true } label: { Image(systemName: "trash") }` (lines 196-204) carry no `.frame`, `.contentShape`, or padding — the hit area is roughly the 17-22pt SF Symbol. The `.padding()` on line 205 pads the enclosing HStack, not the buttons. Contrast CameraHUDButton.swift:18-20, which explicitly does `.frame(width: 44, height: 44)`.

**Failure scenario.** A user with a motor impairment aiming at the ~20pt eye glyph misses and lands on the background tap layer instead, which silently toggles chrome — an unpredictable outcome for an unlabelled ~20pt target on a first try.

**Proposed fix.** Add `.frame(minWidth: 44, minHeight: 44)` plus `.contentShape(Rectangle())` to both viewer chrome buttons, matching CameraHUDButton.


---

### `medium` Thumbnail failures are visually indistinguishable from loading, forever

`pikicam/Features/Gallery/GalleryView.swift:269` · kind=ui-ux · confidence=certain · votes=1|refute=0

**Evidence.** `AsyncThumbnail`'s `.task` swallows the error with `catch { image = nil }`, leaving the same `Rectangle().fill(Color.gray.opacity(0.3))` placeholder that the loading state draws. There is no error state, no retry, and no signal — the underlying failure is `PhotoLibraryError.assetUnavailable` / `.thumbnailFailed`.

**Failure scenario.** An iCloud-backed capture's thumbnail request fails (offline, transient Photos error). The cell renders a flat gray square indistinguishable from one still decoding, and stays gray forever with no tap-to-retry; the user concludes the capture is corrupt or missing.

**Proposed fix.** Add a third state (`loadFailed`) rendered as a hairline-crossed placeholder, and re-attempt on `.task(id:)` re-entry or on tap. Keeping the gray monochrome treatment respects the design language.


---

### `medium` A DNG load failure in the viewer offers no retry path

`pikicam/Features/Gallery/GalleryView.swift:169` · kind=feature-gap · confidence=likely · votes=1|refute=0

**Evidence.** The `loadFailed` branch renders only `ContentUnavailableView("Unable to load DNG", ...)` with no action; recovery requires dismissing the cover and re-tapping the cell, which re-runs `.task(id: capture.id)`. There is no paging/swipe between captures either — the viewer is a single-item modal (`viewerPresented: Bool`).

**Failure scenario.** A transient `loadFailed` (iCloud network hiccup on `isNetworkAccessAllowed = true`) with no cell-level retry: the user must back out, find the same cell, and hope. Meanwhile reviewing a session means back → tap next cell → repeat, with no way to step to the next capture from inside the viewer.

**Proposed fix.** Add a word-only "Retry" button to the loadFailed branch that bumps a @State retryGeneration counter consumed by .task(id:) (e.g. .task(id: capture.id.combinedHash with generation)), leaving the byte-exact "Unable to load DNG" string untouched; treat next/previous paging as a separate enhancement, not part of this fix.


---

### `medium` No test covers the library model's selection, error-retention, or refresh state machine

`pikicam/Features/Gallery/PikicamLibraryModel.swift:26` · kind=test-gap · confidence=certain · votes=1|refute=0

**Evidence.** `grep 'func test' pikicamTests` shows no test that constructs `PikicamLibraryModel` except `testStorageSavesDNGSinglePhotoResourceToPhotos` (PikicamPipelineTests.swift:114), which only round-trips one `save`. Nothing asserts the documented behaviors in the refresh comment — "a transient PhotoKit failure ... must not wipe the gallery" (lines 27-30) — nor that `select`/`deleteSelected`/`save` keep `selectedCapture` and `error` consistent, nor the overlap race described above.

**Failure scenario.** The invariant that a failing refresh preserves stale captures (and that `error` is published orthogonally) can regress silently: only the device-only Photos tests and the UI walkthrough touch this path, and neither can exercise a failure.

**Proposed fix.** Add simulator-safe unit tests for PikicamLibraryModel selection/error/refresh transitions, introducing a minimal injecting seam for PhotoLibraryManager if needed (select-nil returns false without manager call; refresh-failure retains captures and sets error; refresh-success clears error; delete success clears selection; save triggers refresh)


---

### `low` Grid accessibility identifiers use array index, contradicting the documented CaptureID rule

`pikicam/Features/Gallery/GalleryView.swift:115` · kind=docs-drift · confidence=certain · votes=1|refute=0

**Evidence.** `ForEach(Array(library.captures.enumerated()), id: \.element.id.uuid)` renders cells whose only handle is `.accessibilityIdentifier("gallery-cell-\(index)")` — positional. PhotoLibraryManager.swift:58-59 states the opposite invariant: "The gallery selects and pages by this value, never by an array index." The UI test then depends on the positional form (SmokeLaunchTest.swift:291-294 asserts `gallery-cell-0` is the newest capture).

**Failure scenario.** An invalidation refresh deletes or reorders the newest capture between the test's baseline count and its `gallery-cell-0` assertion; the identifier now points at a different DNG and the walkthrough can delete a pre-existing capture (the test's own "only delete when the baseline gallery was empty" guard exists precisely because of this).

**Proposed fix.** In /Users/adrifadilah/Desktop/pikicam/pikicam/Features/Gallery/GalleryView.swift:115 change `.accessibilityIdentifier("gallery-cell-\(index)")` to `.accessibilityIdentifier("capture-cell-\(capture.id.uuid)")` (keep `index` only if still needed for layout, not identity); update /Users/adrifadilah/Desktop/pikicam/pikicamUITests/SmokeLaunchTest.swift:291,309,353,386,397,414 and /Users/adrifadilah/Desktop/pikicam/pikicamTests/PikicamPipelineTests.swift:205 comment to resolve the walkthrough capture by its stable CaptureID instead of `gallery-cell-0`.


---

### — storage (6) —

### `high` Corrupt index silently returns empty; next save destroys all provenance

`pikicam/Core/Storage/PhotoLibraryManager.swift:847` · kind=correctness · confidence=certain · votes=2|refute=0

**Evidence.** PhotoLibraryManager.swift:836-853 — loadIndex() catches ALL decode/IO errors and returns .empty(); save() lines 310-312 then does mutateIndex { index.records.append(pending) } + saveIndex, overwriting the file. Reconcile/prune only recover pending records, never stored ones.

**Failure scenario.** Index file corrupted (killed mid-write, backup restore, disk error) while user has 50 stored captures -> app launches, gallery shows empty (false negative) -> user captures one new photo -> save() loads .empty(), appends one pending, persists -> all 50 stored records destroyed; 50 Photos DNG assets orphaned with no index entry, invisible forever, no recovery path.

**Proposed fix.** In loadIndex(), return .empty() only when the index file does not exist; on Data(contentsOf:) failure, JSON decode failure, or version != indexFileVersion, throw so callers surface indexReadFailed/indexWriteFailed instead of proceeding. This makes save()'s first mutateIndex fail rather than append-one-to-empty and overwrite history. Quarantine the unreadable file (rename to *.corrupt-<timestamp>) before failing so per-record salvage remains possible.


---

### `medium` Limited-auth hidden pendings force futile full enumeration every refresh

`pikicam/Core/Storage/PhotoLibraryManager.swift:568` · kind=perf · confidence=likely · votes=1|refute=0

**Evidence.** PhotoLibraryManager.swift:568-574 (case 0: remove only if !limited) and 496-500 (limited records retained, omitted from projection). reconcilePendingRecords lines 544-549 runs on every captures() while ANY non-in-flight pending exists — including hidden-under-limited ones that can never match the visible enumeration.

**Failure scenario.** Limited authorization + 5 pending records outside the allowed selection -> every gallery refresh (including each invalidation burst) does a full-library assetResources enumeration that provably cannot resolve them -> repeated battery/IO cost; retained records accumulate in the index file unboundedly across sessions.

**Proposed fix.** Under limited auth, skip reconciliation for pendings older than N (or after K failed passes) and persist a lastReconciledAt / attempts counter; bound retained-hidden records with a cap + eviction log. Document the retention policy in the reconcile comment.


---

### `medium` Thumbnails latch the first degraded frame and have no cache

`pikicam/Core/Storage/PhotoLibraryManager.swift:705` · kind=perf · confidence=certain · votes=1|refute=0

**Evidence.** PhotoLibraryManager.swift:695-707 requestThumbnail resumes the continuation on the FIRST usable image under .opportunistic delivery ('either is fine for a thumbnail'); GalleryView.swift AsyncThumbnail keeps that UIImage with no NSCache, no upgrade pass, re-requesting per cell appearance.

**Failure scenario.** Open Library with 200 captures on iCloud -> grid fires 200 concurrent network-enabled image requests; each cell latches its degraded preview permanently (never upgraded to the full rendition); scrolling off/on re-downloads the same thumbnails.

**Proposed fix.** Add NSCache<NSString, UIImage> in PhotoLibraryManager (or PikicamLibraryModel) keyed by localIdentifier+targetSize, invalidated on delete()/invalidationUpdates; and stop latching the degraded frame: either use deliveryMode=.highQualityFormat for a single full-quality callback, or deliver degraded to the cell via a separate @State update and resume the awaiting continuation only on the non-degraded (info[PHImageResultIsDegradedKey]==false) result; optionally prefetch with PHCachingImageManager and rely on cell-disappear cancellation to bound concurrency.


---

### `medium` No tests for reconcile/prune/partial-failure index behaviors

`pikicamTests/PikicamPipelineTests.swift:108` · kind=test-gap · confidence=certain · votes=1|refute=0

**Evidence.** PikicamPipelineTests.swift storage coverage is testStorageSavesDNGSinglePhotoResourceToPhotos (lines 108-187, happy-path save/fetch/delete) plus device probes; reconcilePendingRecords multi-match min() (PhotoLibraryManager.swift:589-592), pruneVanishedRecords limited/full branches (503-518), pending case-0 removal (568-574), and indexCommitFailed/indexRemovalFailed partial-failure paths have zero tests — and all live in private actor methods unreachable from tests.

**Failure scenario.** Someone changes matches.min() to .max() or flips the limited guard in prune -> entire suite still green; duplicate-import misbinding or limited-auth record leak ships undetected.

**Proposed fix.** Extract the pure decision logic out of the private PhotoKit-coupled actor methods as internal (non-private) nonisolated static helpers — e.g. reconcile(records:filename->ids map:limited:excluding in-flight IDs) and prune(records:visible-id set:limited:) returning (records, didChange) — and unit-test: single match commits, multi-match commits min(), zero-match removes iff full auth and retains iff limited, in-flight save IDs excluded; separately test corrupt-index load once loadIndex stops swallowing decode errors into .empty().


---

### `low` Full-library PhotoKit enumeration runs while holding the index NSLock

`pikicam/Core/Storage/PhotoLibraryManager.swift:440` · kind=perf · confidence=certain · votes=1|refute=0

**Evidence.** PhotoLibraryManager.swift:440-452 — captures() runs loadIndex + reconcilePendingRecords + pruneVanishedRecords + saveIndex inside Self.indexLock.withLock. reconcilePendingRecords lines 551-561 enumerates the ENTIRE visible image library (fetchAssets + assetResources per asset); pruneVanishedRecords line 507 does batched PHAsset fetches — all while holding the process-wide NSLock that save()/delete() need.

**Failure scenario.** User with 40k-photo library has one crash-orphaned pending record -> every gallery refresh holds indexLock through a full-library enumeration (seconds) -> concurrent save() blocks in mutateIndex, shutter-to-saved latency spikes; on main-actor-adjacent paths this risks watchdog pressure.

**Proposed fix.** Snapshot under lock, enumerate unlocked, commit under lock: copy pending filenames (and stored asset IDs for prune) inside one short indexLock.withLock(loadIndex); run PHAsset.fetchAssets + PHAssetResource.assetResources(for:) and fetchAssetsByLocalIdentifier with no lock held; then re-enter indexLock.withLock to reload index, re-check each record is still pending/stored, and apply commits/removals + conditional saveIndex.


---

### `low` Privacy manifest declares three required-reason APIs the code never calls

`pikicam/Resources/PrivacyInfo.xcprivacy:17` · kind=docs-drift · confidence=likely · votes=1|refute=0

**Evidence.** pikicam/Resources/PrivacyInfo.xcprivacy lines 17-46 declares NSPrivacyAccessedAPICategoryFileTimestamp (C617.1), DiskSpace (E174.1), SystemBootTime (35F9.1). Repo-wide grep for attributesOfItem/resourceValues/systemUptime/volumeAvailableCapacity/mach_absolute_time/getattrlist/statfs/creationDate returns zero Swift call sites.

**Failure scenario.** Submit with required-reason declarations the binary never exercises -> App Review rejection for inaccurate privacy manifest (or a future audit flags phantom data-access claims); conversely if an SDK pulls these APIs in, the manifest reasons were written for the wrong call sites.

**Proposed fix.** Delete the three NSPrivacyAccessedAPITypes dict entries in pikicam/Resources/PrivacyInfo.xcprivacy (FileTimestamp C617.1, DiskSpace E174.1, SystemBootTime 35F9.1), leaving an empty NSPrivacyAccessedAPITypes array


---

### — tests (11) —

### `critical` Zero-process promise is entirely unpinned — no test asserts any enhancement knob

`pikicam/Features/Develop/CIRAWZeroProcessor.swift:69` · kind=test-gap · confidence=certain · votes=2|refute=0

**Evidence.** `applyZeroRecipe` sets 10 knobs via `apply(filter, "baselineExposure") { filter.baselineExposure = 0.0 }` … but `apply` guards every assignment behind `filter.responds(to: Selector("set" + control.prefix(1).uppercased() + control.dropFirst() + ":"))`. I enumerated the runtime method list of a real `CIRAWFilter(imageData:)` on the iOS 26.5 simulator: the class is `CIRAWFilterImpl` and it implements `setInputBaselineExposure:`, `setInputBoost:`, `setInputLocalToneMapAmount:`, `setInputEnableSharpening:`, `setInputEnableVendorLensCorrection:`, `setInputDisableGamutMap:` — NOT the `setX:` selectors the recipe builds. `f.responds(to:)` returned `false` for all ten (`baselineExposure`, `exposure`, `boostAmount`, `shadowBias`, `localToneMapAmount`, `luminanceNoiseReductionAmount`, `sharpnessAmount`, `contrastAmount`, `isLensCorrectionEnabled`, `isGamutMappingEnabled`). Separately, the recipe omits `colorNoiseReductionAmount`, `detailAmount`, `moireReductionAmount`, and `isHighlightRecoveryEnabled` (SDK header: "The default value is true"). No file under `pikicamTests/` references `CIRAWZeroProcessor`, `RAWProcessor`, or any knob name.

**Failure scenario.** Someone adds `filter.exposure = 1.5` (or the selector strings drift, or a new knob like color NR is left at its per-image default). Every test still passes: `testZeroDevelopProducesViewableJPEGFromRealDNG` only asserts width>1000 and averageLuminance>5, both of which a fully-enhanced render satisfies. The one product claim the README leads with ships unverified.

**Proposed fix.** Fix the two boolean selector strings (ObjC setter for `lensCorrectionEnabled` is `setLensCorrectionEnabled:`, not `setIsLensCorrectionEnabled:` — same for gamut/highlight; header declares getter=isX, so the hand-built `setIsX:` never responds and both assignments are silently skipped on every runtime), extend applyZeroRecipe with the omitted knobs from CIRAWFilter.h (colorNoiseReductionAmount, detailAmount, moireReductionAmount, highlightRecoveryEnabled default true, boostShadowAmount, extendedDynamicRangeAmount), gate on the isXSupported flags instead of hand-built responds(to:) strings, and add CIRAWZeroProcessorTests asserting each supported knob reads back neutral. Do NOT use the reporter's KVC keys verbatim — runtime attribute dump shows legacy input keys (inputEV, inputBoost, inputDisableGamutMap [inverted], inputEnableSharpening) that do not map 1:1; typed-property assignment is the safe path.


---

### `high` UI smoke test asserts only "app is foreground", never the camera-unavailable state it names

`pikicamUITests/SmokeLaunchTest.swift:36` · kind=test-gap · confidence=certain · votes=2|refute=0

**Evidence.** The test is named `testLaunchAndCameraUnavailableErrorShown` and its doc comment says it exercises the "typed `CaptureError.cameraUnavailable` state". Lines 50-54 assert `app.wait(for: .runningForeground)`, and lines 69-73 assert the SAME thing again with a 20s timeout. The inline comment at 66-68 admits: "camera error state is visible in the UI (accessibility text-match unreliable on iOS 26.5 simulator framework — verified by manual screenshot)". The error label does exist and is queryable — `CameraView.swift:238` sets `.accessibilityLabel("Error: \(error.localizedDescription)")` and `CaptureError.cameraUnavailable.errorDescription` is "No back wide camera is available."

**Failure scenario.** The app launches, shows a blank black screen with no error text at all, and the test passes green. A regression that suppresses the error banner — or that surfaces a *wrong* typed error (e.g. `sessionNotConfigured` where `cameraUnavailable` is honest) — is invisible to the only test that runs on the simulator.

**Proposed fix.** Query the banner the app already publishes, accepting either honest simulator state: app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Error:'")).firstMatch must exist within timeout and its label must equal "Error: No back wide camera is available." or "Error: Camera and photo library access are required."


---

### `high` safeToCommitDelete is false whenever the baseline gallery probe misses, silently skipping delete coverage

`pikicamUITests/SmokeLaunchTest.swift:216` · kind=test-gap · confidence=certain · votes=2|refute=0

**Evidence.** `var baselineCount: Int?` is left `nil` unless the whole chain succeeds: `galleryThumbnail.waitForExistence(timeout: 5)` (line 218), then `navigationBars["Library"]` (221), then `library-grid` (225) or the "No captures" fallback (227). `safeToCommitDelete` is then `baselineCount == 0` (line 410) — `nil == 0` is false. The ~70-line delete-commit block (412-482: open viewer, tap Delete, confirm, assert viewer dismisses, assert "No captures") is skipped with no signal beyond a screenshot named "11-delete-commit-skipped-pre-existing-captures".

**Failure scenario.** The gallery thumbnail doesn't appear in the 5s window on a slow device (the capture→Photos commit→refresh chain is real async work). The entire delete path is silently never exercised, the test reports green, and a real delete bug (viewer not dismissing, index record not removed, asset orphaned in Photos) ships.

**Proposed fix.** Distinguish nil baseline from non-empty baseline: keep skip for baselineCount > 0, but XCTFail (or XCTSkip with explicit reason) when baselineCount == nil before the delete-commit decision, and rename the skip screenshot for the nil case so a probe miss is not reported as pre-existing-captures.


---

### `high` Device-only Photos probe cannot fail as documented — it passes on any recent pikicam asset

`pikicamTests/PikicamPipelineTests.swift:215` · kind=test-gap · confidence=certain · votes=2|refute=0

**Evidence.** The test's own doc comment (lines 197-214) states: "This test is NOT tied to the exact capture performed in `SmokeLaunchTest.testDeviceCaptureWalkthrough`. It will pass if any recent pikicam asset (within the last 10 minutes) exists, so a failed walkthrough could still pass". The window is `Date().addingTimeInterval(-600)` (line 224). The stress test `testDeviceCaptureStressWhileZoomed` creates 5 more pikicam DNGs per run and deletes none, so after one stress run every subsequent walkthrough has assets inside the window.

**Failure scenario.** `testDeviceCaptureWalkthrough` fails at step 3 (camera UI never appears) and never captures. `testDevicePhotosLibraryContainsCapturedDNGSingleResource` still finds the 5 assets the previous stress run left in Photos and passes. A red walkthrough plus a green probe reads as a partially-passing suite whose green half means nothing.

**Proposed fix.** Have testDeviceCaptureStressWhileZoomed clean up the captures it creates (it performs 6 shutter taps with no delete path, vs the walkthrough's guarded commit-delete), so the probe's 10-minute window is not permanently saturated; longer-term, add the App Group UserDefaults marker the comment proposes so the probe can require the walkthrough's exact capture UUID.


---

### `medium` Framing metadata (aspectRatio/zoomFactor/orientation) round-trip is persisted but never asserted

`pikicam/Core/Storage/PhotoLibraryManager.swift:104` · kind=test-gap · confidence=certain · votes=2|refute=0

**Evidence.** `PikicamCapture` carries `orientation`, `aspectRatio`, `zoomFactor`; `save` writes them into `IndexRecord` (lines 302-304) and `captures()` decodes them with defaults (lines 481-483: `orientation: record.orientation ?? .up, aspectRatio: record.aspectRatio ?? .ratio4x3, zoomFactor: record.zoomFactor ?? 1.0`). `GalleryView`'s viewer consumes them (`.task(id: capture.id)` → `developService.render(dngData:aspectRatio:zoomFactor:)`). The only storage test, `testStorageSavesDNGSinglePhotoResourceToPhotos`, constructs `CapturedDNG(data: rawData, capturedAt: Date())` — all defaults — and asserts only `pixelWidth`/`pixelHeight`/`originalFilename`. It never asserts `capture.aspectRatio`, `capture.zoomFactor`, or `capture.orientation`, and never calls `captures()` to check the decoded values.

**Failure scenario.** Commit 7aacfe9 added the `IndexRecord.orientation/aspectRatio/zoomFactor` optionals specifically so old indexes decode. A JSON key rename (e.g. `zoomFactor` → `zoom`) makes every field decode to nil; all captures silently fall back to `.up`/4:3/1× and the viewer shows a wrongly-cropped Print for every existing capture. Zero tests fail — `CameraControlTests` only tests `PrintCrop` with hand-written rects, and `PikicamPipelineTests` never round-trips an index.

**Proposed fix.** Add a device-gated save→captures() round-trip test in PikicamPipelineTests using non-default framing (e.g. orientation .left, aspectRatio .ratio1x1, zoomFactor 2.5) asserting all three fields survive captures(). For the legacy-defaults pin, the ?? fallbacks live behind private IndexRecord/private indexFileURL, so either expose a minimal internal decode helper for the fallback or test via a mirror Codable struct; asserting only save()'s return value is insufficient because save() returns fetchCapture() built from in-memory params (PhotoLibraryManager.swift:348-358, 391-410) and never exercises the JSON decode path.


---

### `medium` Self-timer countdown + cancel state machine is entirely untested

`pikicam/Features/Camera/CameraViewModel.swift:234` · kind=test-gap · confidence=certain · votes=2|refute=0

**Evidence.** `cycleSelfTimer()`, `cancelSelfTimer()`, and `runSelfTimerCountdown(generation:)` implement a generation-guarded countdown with a documented invariant ("cancel must never take the photo"). `SelfTimerCountdownView` exposes `accessibilityIdentifier("self-timer-countdown")` and `CameraHUDButton(identifier: "self-timer-toggle")` exists in `CameraView.swift:266-272`. `CameraControlTests` covers only `SelfTimerOption.next()`/`.seconds` (lines 109-122) — pure enum cycling. Grep for the identifiers in `SmokeLaunchTest` returns nothing: the device walkthrough never taps `self-timer-toggle` and never queries `self-timer-countdown`, despite walking through grid, flash, flip, zoom, aspect, and tap-to-meter.

**Failure scenario.** The `phase == .idle` guard at `runSelfTimerCountdown`'s end (line 330) races the countdown task: if `selfTimerRemaining` hits 0 and `captureGeneration == gen` but the phase was already advanced, the guard returns and the shutter stays permanently non-responsive with no error shown. Or the user taps the countdown to cancel, the cancellation lands, but a stale countdown task writes `selfTimerRemaining` — the UI shows a countdown for a capture that no longer exists. No test on any machine catches either.

**Proposed fix.** Add simulator-safe ViewModel tests that do not need a sensor or mocks: cycleSelfTimer off->3s->10s->off from .idle, cycleSelfTimer no-op when phase != .idle, cancelSelfTimer no-op when phase != .countdown, and cancel-must-never-capture via capture() second-tap path only after forcing .countdown (requires isConfigured/isSessionRunning, so cover the guardable parts first). Do not add an injectable clock or mock CaptureService — full 3s/10s countdown via Task.sleep cannot run on simulator (capture() early-returns without a session) and mocks contradict the no-mock convention. Optionally extend the device walkthrough with self-timer-toggle -> shutter -> self-timer-countdown -> tap-to-cancel.


---

### `medium` UI test uses fixed RunLoop sleeps to wait for async Photos/CI work — 15 sites, all timing-assumed

`pikicamUITests/SmokeLaunchTest.swift:119` · kind=test-gap · confidence=certain · votes=1|refute=0

**Evidence.** `RunLoop.current.run(until: Date().addingTimeInterval(...))` appears at lines 119 (1.5s for the camera prompt), 132 (2s for first preview frames), 223 (1s library reconcile), 262, 461, 526, 541, 562 (0.5s between rapid-fire taps), 567 (1s drain poll), 589, 605, and 685 (3s for DNG develop). The file already has the right primitive — `waitFor(_:on:timeout:)` at line 795 wrapping `XCTNSPredicateExpectation` — and uses it correctly elsewhere (`waitForValue`, the shutter `isEnabled == true` waits).

**Failure scenario.** On a device under thermal load, the DNG develop at line 685 takes >3s, no `ProgressView` was caught in the first 3s probe at line 678, and the test proceeds to assert `chromeToggle.exists` — which is true because the chrome renders before the image does. The viewer-load assertion (the walkthrough's headline "the DNG loads" claim, per its own comment at line 297) passes without the DNG ever loading.

**Proposed fix.** In `openViewerAndAssertLoaded` (SmokeLaunchTest.swift:650-703): scope the spinner to the viewer's own identifier (`app.activityIndicators["viewer-loading"]`, GalleryView.swift:178-179) instead of `activityIndicators.firstMatch`, and unconditionally `waitForNonExistence(timeout: 30)` after the chrome-toggle gate — delete the `else { RunLoop sleep 3 }` branch at lines 683-686. Keep asserting `unableToLoad` absent plus chrome controls present; optionally add an accessibility identifier to the rendered `Image(uiImage:)` in FullScreenViewer so the test can assert the image itself exists rather than inferring it from spinner-gone + no-failure.


---

### `medium` AGENTS.md says Features/Gallery was removed; it is 364 lines of live code the gallery depends on

`AGENTS.md:73` · kind=docs-drift · confidence=certain · votes=1|refute=0

**Evidence.** AGENTS.md line 73: "- `pikicam/Features/DualCamera|Gallery|Review|Settings/` — removed and committed; do not resurrect them unless asked." The directory contains `GalleryView.swift` (274 lines) and `PikicamLibraryModel.swift` (90 lines), both live: `CameraView.swift:56` presents `GalleryView()`, and `CameraViewModel` holds `let libraryModel: PikicamLibraryModel`. The same line's blanket claim also contradicts README.md:113, which lists `pikicam/Features/Gallery/` under "How it works".

**Failure scenario.** An agent (or a new contributor) following AGENTS.md — the file the task instructions say OVERRIDE default behavior — deletes `Features/Gallery/` as "removed and committed", breaking the build and the entire UI test contract ("Library", "No captures", "Unable to load DNG"). The instruction names a directory that is load-bearing.

**Proposed fix.** Reword AGENTS.md:73 to list only the actually-removed features (DualCamera, Review, Settings) and point at `pikicam/Features/Gallery/` as live, matching README.md:113.


---

### `low` PhotoLibraryManager index codec, reconciliation, and newest-first sort have zero tests

`pikicam/Core/Storage/PhotoLibraryManager.swift:429` · kind=test-gap · confidence=certain · votes=1|refute=0

**Evidence.** `captures()` implements a nontrivial contract: pending-record reconciliation by namespaced filename with a 0/1/many match decision table (lines 543-597), `pruneVanishedRecords` that retains under limited auth but prunes under full (503-518), a `version` check that discards unknown schemas (845), corrupt-JSON → `.empty()` (851), and a `captures.sort` with a `CaptureID` UUID-string tie-breaker (487-492). None of it is exercised by a test: `testStorageSavesDNGSinglePhotoResourceToPhotos` calls `library.save` and then inspects `PHAsset` directly — it never calls `library.manager.captures()`.

**Failure scenario.** The sort tie-breaker `lhs.id.uuid.uuidString > rhs.id.uuidString` yields a descending-UUID order for captures with identical `capturedAt`. `Date()` resolution makes same-timestamp captures common in a burst. The gallery shows the wrong capture at `gallery-cell-0` — and the walkthrough's delete-commit deletes `gallery-cell-0` believing it is its own asset, destroying a different user capture.

**Proposed fix.** Keep the test-gap, drop the bug claim: the descending-UUID tie-breaker is a valid deterministic order (contract at PhotoLibraryManager.swift:415-416 requires only determinism, no ascending/descending mandate) and deletion follows object identity (PikicamLibraryModel.deleteSelected deletes selectedCapture; GalleryView selects the tapped object), not cell index — plus SmokeLaunchTest.swift:409-411 only commits delete when baselineCount==0, so cross-user destruction is unreachable. Actionable fix: extract pure index-codec/sort helpers (version check loadIndex:845, corrupt→empty:851, sort comparator:487-492) to internal testable functions and unit-test those without Photos; testing full captures()/reconcile/prune needs usable Photos auth (captures() gates at :430 requireUsableAuthorization) so a one-line indexFileURL injection alone does not make it simulator-testable permission-free.


---

### `low` AGENTS.md repository-state block is stale on test count, commit count, and file sizes

`AGENTS.md:76` · kind=docs-drift · confidence=certain · votes=1|refute=0

**Evidence.** Line 76: "currently 5 tests, incl. device-only Photos probes" — `PikicamPipelineTests.swift` has 8 `func test` declarations. Line 109: "Working tree is **clean**: 7 commits on `main`" — `git log --oneline | wc -l` is 32, and `git status` shows 7 modified files plus untracked `CONTEXT.md` and `docs/adr/`. The repo map (lines 64-80) also omits files that exist and are load-bearing: `CameraControls.swift` (296 lines, all of `CameraControlTests`' subjects), `VolumeButtonCaptureView.swift`, `CameraHUDButton.swift`, `ZoomIndicatorView.swift`, `GridOverlayView.swift`, and `docs/adr/`.

**Failure scenario.** The stated verification command `./scripts/verify.sh` builds but the test action is only meaningful if you know which tests exist; a count of 5 sends a reader looking for 5 when 8 run. "Working tree is clean" is contradicted on sight, which erodes trust in the rest of the file's factual claims.

**Proposed fix.** Regenerate the repository-state section: correct the test count, drop the commit-count/clean-tree claim (it rots every commit), and add the omitted files to the repo map.


---

### `low` Diagnostic Photos probe is in the unit suite where it always skips and only prints

`pikicamTests/PikicamPipelineTests.swift:279` · kind=test-gap · confidence=certain · votes=1|refute=0

**Evidence.** `testDeviceProbePhotosSaveResourceVariants` is `#if targetEnvironment(simulator) throw XCTSkip` (line 281), and its body contains zero `XCTAssert` calls — only `print("🖼️ PROBE …")` (line 313) and `print("🧹 PROBE cleanup …")`. It writes 6 real DNG/JPEG assets into the user's Photos library per device run and cleans them up by filename prefix.

**Failure scenario.** On the simulator it is pure overhead that reports as a skip. On a device it mutates the user's photo library, has left a permanent record of a probe's findings in a code comment rather than an assertion, and cannot fail — so it contributes zero signal to whether the suite is green while carrying real risk to user data.

**Proposed fix.** Gate testDeviceProbePhotosSaveResourceVariants behind an opt-in (e.g. guard getenv("PIKICAM_PROBE_PHOTOS")=="1" else throw XCTSkip) so the standard test action never writes probe assets, and move the recorded layout findings into a doc/ADR.


## Appendix B — 8 critic findings (second lens)

### `medium` Torch flash fires with zero warm-up settle while zoom got an explicit 250ms one

`pikicam/Features/Camera/CaptureService.swift:544` · kind=correctness · confidence=likely

**Evidence.** CaptureService.capturePhoto fires the torch and captures back-to-back with no settle in between: `try applyTorchMode(.on, to: device)` is followed immediately by `let photo = try await photoOutput.capturePhoto(with: settings)`. Contrast the zoom path in the same function, which got an explicit 250ms settle (`try await Task.sleep(nanoseconds: 250_000_000)`) because "an immediate capture right after the zoom change can return incomplete photo data". An LED torch ramps to full output over tens of milliseconds, so the exposure can begin before the torch reaches steady state.

**Failure scenario.** User enables flash in a dark scene → torch turns on → capture starts within milliseconds → frame is exposed during torch ramp-up → underexposed or unevenly lit flash frame, the exact class of defect the zoom settle delay was added to prevent.

**Proposed fix.** Insert a short settle delay after torch-on before capturePhoto (mirroring the 250ms zoom settle), or ramp via setTorchModeOn(level:) if a controlled level is preferred.

---

### `medium` Capture session keeps streaming behind the gallery full-screen cover

`pikicam/Features/Camera/CameraView.swift:54` · kind=perf · confidence=likely

**Evidence.** CameraView presents the gallery as `.fullScreenCover(isPresented: $galleryPresented) { GalleryView()... }`, but `stop()` is only called from `.onDisappear`, which never fires while a full-screen cover is presented over the view. Nothing observes `galleryPresented` to pause the session.

**Failure scenario.** User opens Library and browses for minutes → AVCaptureSession keeps streaming full-sensor frames behind the cover → battery drain, thermal pressure, and the camera-indicator stays on while the user believes they are just looking at photos.

**Proposed fix.** Add `.onChange(of: galleryPresented)` that stops (or pauses) the session when the gallery opens and restarts it on dismiss, mirroring the scenePhase handling in RootView.

---

### `medium` Concurrent gallery refreshes can publish stale captures over newer ones

`pikicam/Features/Gallery/PikicamLibraryModel.swift:26` · kind=concurrency · confidence=likely

**Evidence.** PikicamLibraryModel.refresh() unconditionally assigns `captures = try await manager.captures()`, and two refresh triggers run concurrently with no generation guard: save() calls `await refresh()` explicitly while watchInvalidation() fires `await refresh()` on every PhotoKit change notification (including the notification the save itself generates).

**Failure scenario.** Save completes → explicit refresh A starts → own-save PhotoKit notification fires invalidation refresh B → B finishes first with the new asset, A finishes last with a fetch that raced the commit → gallery shows stale captures until the next external invalidation.

**Proposed fix.** Serialize refresh with a generation counter or a single retained refresh task: only the newest fetch may publish, stale ones are discarded.

---

### `medium` Zero localization infrastructure; all user strings are hardcoded English

`pikicam/App/RootView.swift:67` · kind=feature-gap · confidence=certain

**Evidence.** A repo-wide search for NSLocalizedString / String(localized:) returns zero hits and there are no .strings, .stringsdict, or .xcstrings files; every user-facing string is a hardcoded English literal, e.g. `Text("Welcome to pikicam")` and hard-coded `errorDescription` strings in all four typed error enums.

**Failure scenario.** Any non-English user gets an English-only app with no path to translation short of editing source; App Store Connect localization metadata would also promise languages the binary cannot render.

**Proposed fix.** Adopt a String Catalog (.xcstrings) and migrate user-facing strings, starting with the permission/error surfaces.

---

### `low` Capture timestamp sampled after exposure completes, not at shutter press

`pikicam/Features/Camera/CaptureService.swift:605` · kind=correctness · confidence=likely

**Evidence.** `capturedAt: Date()` is sampled in the `return try CapturedDNG(...)` at the end of capturePhoto — after the exposure, the zoom-restore round-trip, and the fallback orientation hop — rather than at shutter press like `shutterOrientation`, which the code deliberately samples early because "sampling after the exposure completes would mis-tag a rotation".

**Failure scenario.** Rapid successive captures (or a slow zoom-restore on failure-retry paths) skew recorded times by hundreds of milliseconds relative to the Photos asset creationDate → newest-first gallery order can disagree with the Photos app order for bursts taken seconds apart.

**Proposed fix.** Sample `let shutterDate = Date()` alongside shutterOrientation at capture entry and thread it through to the CapturedDNG.

---

### `low` Countdown cancel works only on the number, not 'anywhere' as documented

`pikicam/Features/Camera/CameraView.swift:476` · kind=correctness · confidence=likely

**Evidence.** SelfTimerCountdownView's doc comment claims it "Doubles as the cancel target — tapping anywhere on the screen cancels via the VM", but `.onTapGesture(perform: onCancel)` is attached only to the countdown-number Text itself, not to a full-screen layer.

**Failure scenario.** User taps the preview edge during a 10s countdown expecting the documented anywhere-cancels behavior → tap lands outside the number → countdown continues → unwanted flash capture fires.

**Proposed fix.** Either expand the tap target to the full countdown overlay (a full-screen contentShape) or correct the comment and add a visible Cancel affordance.

---

### `low` Volume-shutter baseline snapshotted once at init; first press swallowed after external volume change

`pikicam/Features/Camera/VolumeButtonCaptureView.swift:49` · kind=correctness · confidence=likely

**Evidence.** `private var lastVolume: Float = AVAudioSession.sharedInstance().outputVolume` is read once at coordinator creation; the code's own comment admits it "must be attached after [the slider] appears — retry for a short window instead of assuming it exists immediately", yet the volume baseline gets no equivalent re-sync.

**Failure scenario.** User changes volume via Control Center or buttons between the coordinator's creation and first press → baseline is stale → first hardware-button press only re-syncs the baseline and is swallowed, so the shutter appears dead on first press.

**Proposed fix.** Re-sync lastVolume on view appear / scenePhase active, or observe outputVolume changes continuously instead of snapshotting at init.

---

### `low` Dark mode is forced app-wide, overriding the user's system appearance

`pikicam/App/PikicamApp.swift:24` · kind=ui-ux · confidence=certain

**Evidence.** `.preferredColorScheme(.dark)` is pinned in PikicamApp.swift (`WindowGroup { RootView()... .preferredColorScheme(.dark) }`) and redundantly again in GalleryView, forcing dark appearance regardless of the system setting.

**Failure scenario.** A Light-Mode user (or one relying on increased-contrast light appearance for legibility) gets a forced-dark UI with no recourse; every future view must also remember to re-pin dark or it flashes light.

**Proposed fix.** Remove the forced `.preferredColorScheme(.dark)` calls and verify the palette works in both appearances, or make it an explicit user setting.


## Appendix C — 15 refuted findings — DO NOT ACT ON THESE WITHOUT RE-DERIVING

These were raised by a finder and **killed by majority adversarial vote**. They are listed so the next pass does not rediscover and re-fix them. If one looks obviously right, that is a reason to re-derive it from source — not to act on it.
---

### `low` Actor deinit reads isolated observer state off-executor

`pikicam/Features/Camera/CaptureService.swift:63` · kind=concurrency · confidence=likely · votes=2|refute=2

**Evidence.** CaptureService.swift:59-67: `init() { registerSessionLifecycleObservers() }` then `deinit { for observer in sessionObservers { NotificationCenter.default.removeObserver(observer) } }` where `sessionObservers` is actor-isolated mutable state (`private var sessionObservers: [NSObjectProtocol] = []`, line 55) on an actor with a custom serial executor (lines 38-42). Actor deinits are non-isolated, so reading `sessionObservers` there races executor-hop work. PhotoLibraryManager.swift:233-235 has the same pre-existing shape (`deinit { PHPhotoLibrary.shared().unregisterChangeObserver(changeBridge) }`).

**Failure scenario.** Session posts runtimeError while the actor executor is running `startSession`; the last owner releases the service concurrently -> deinit reads `sessionObservers` off-executor while an in-flight hop appends to it -> data race / missing removeObserver -> leaked observer or crash.

**Proposed fix.** Move observer lifetime out of the actor (a small nonisolated owner object that unregisters in its own deinit), or keep tokens in a Sendable box guarded by a lock that both the actor and deinit use.

---

### `low` PhotoCapture photo/error fields written off-lock despite resume lock

`pikicam/Features/Camera/PhotoCapture.swift:72` · kind=concurrency · confidence=certain · votes=2|refute=2

**Evidence.** PhotoCapture.swift:36-40 declares `continuation`, `photo`, `processingError` as plain vars; lines 72-82 write `photo`/`processingError` in `didFinishProcessingPhoto` with no lock, while lines 98-102 read/take `continuation` and lines 105-112 read `photo`/`processingError` in `didFinishCaptureFor` under `lock`. Comment at lines 23-27 claims 'a lock serializes every resume path', but the `didFinishProcessingPhoto` write path is not serialized.

**Failure scenario.** AVFoundation delivers `didFinishProcessingPhoto` (assigning `self.photo`) on its delegate queue at the same instant the 15 s timeout fires `failWithTimeout` on a cooperating-thread, or `didFinishCaptureFor` reads `photo` — unsynchronized read/write of `photo`/`processingError` across executors. Outcome ranges from a lost photo (nil read -> spurious `.missingImageData`) to a Swift 6 data race / memory corruption trap.

**Proposed fix.** Take `lock` in `didFinishProcessingPhoto` around the `photo`/`processingError` writes (or move both fields behind the same lock used for `continuation`).

---

### `low` Bayer format validated output-wide, not per active device

`pikicam/Features/Camera/CaptureService.swift:621` · kind=crash · confidence=likely · votes=2|refute=2

**Evidence.** CaptureService.swift:621-626 `queryActiveBayerFormat` returns the first Bayer entry of `photoOutput.availableRawPhotoPixelFormatTypes` — an output-wide list — with no reference to the active `cameraDevice`. `capturePhoto` (line 532) builds `AVCapturePhotoSettings(rawPixelFormatType: bayerFormat)` from it. The file's own comments (lines 616-620) acknowledge requesting a format outside the validated list raises NSInvalidArgumentException -> SIGABRT.

**Failure scenario.** Toggle to the front camera (`toggleCamera`, lines 226-288; front TrueDepth typically has no Bayer RAW), then press the shutter: the output-wide list can still be non-empty (back-camera formats), so the Bayer check at line 503 passes and `capturePhoto(with:)` raises an uncaught ObjC exception -> SIGABRT, the same crash class as the documented zoom case.

**Proposed fix.** After `toggleCamera`, re-validate the Bayer format against the now-active device (e.g. check `photoOutput.availableRawPhotoPixelFormatTypes` is insufficient — gate front-camera capture to `.noBayerFormatAvailable` or query per-device supported RAW types) and add a device-only test encoding that reality.

---

### `low` Framing overlays frozen at 1x while preview zoom goes to 5x

`pikicam/Features/Camera/CameraView.swift:355` · kind=correctness · confidence=likely · votes=2|refute=2

**Evidence.** FramingOverlays (:348-365) computes "PrintCrop.rect(in: bounds, zoomFactor: 1.0, aspect: aspectRatio)" — hard-coded 1.0 — while the live preview is an aspect-FILL full-sensor feed (PreviewView.commonInit :63 videoGravity .resizeAspectFill) whose visible crop already varies with zoomFactor. At 2-5x the grid (:357-360, clipped to the 1x aperture) and mask (:361) no longer match what the sensor crop will develop; the comment claims "the same PrintCrop math the develop pipeline applies to the DNG at 1x zoom", i.e. the mismatch is known but the overlay never follows the pinch. GridOverlayView itself is correct; the caller starves it of the zoom input.

**Failure scenario.** Set 16:9, pinch to 2.5x -> overlay still draws the 1x aperture bands -> user frames subject inside the drawn aperture -> developed PrintCrop at 2.5x crops tighter -> subject clipped though the viewfinder said it was safe.

**Proposed fix.** Pass viewModel.zoomFactor into FramingOverlays/PrintCrop.rect so grid + mask track the live zoom; verify against the walkthrough's 03d/03e assertions (aspect-overlay and zoom-indicator identifiers unchanged).

---

### `low` CaptureIndex.empty() hardcodes version 1, breaks future schema bump

`pikicam/Core/Storage/PhotoLibraryManager.swift:905` · kind=correctness · confidence=certain · votes=1|refute=1

**Evidence.** PhotoLibraryManager.swift:218 sets indexFileVersion = 1 and 817 embeds it in the filename, but CaptureIndex.empty() line 904-906 hardcodes `CaptureIndex(version: 1, records: [])`, and loadIndex line 845 compares against Self.indexFileVersion.

**Failure scenario.** Version bumped to 2 for a schema change -> empty() still writes version:1 -> every subsequent load sees version mismatch -> returns .empty() -> gallery permanently empty and finding #1's wipe repeats on every save.

**Proposed fix.** Change `private static let indexFileVersion` to `fileprivate` (or move the constant out of the actor) and make `CaptureIndex.empty()` use it instead of the literal `1`. No migrator or version-bump behavior change needed today.

---

### `low` Synchronous start/stopRunning blocks the actor serial executor

`pikicam/Features/Camera/CaptureService.swift:162` · kind=perf · confidence=certain · votes=1|refute=1

**Evidence.** CaptureService.swift:162 `session.startRunning()` and line 173 `session.stopRunning()` are synchronous blocking calls executed on the actor's custom serial executor (lines 37-42). Every actor method — including `handleSessionInterrupted`, `capturePhoto`'s `isCaptureInFlight` guard, and `startSession`'s reconcile — shares that executor.

**Failure scenario.** `startRunning()` blocks the executor for up to ~1 s on hardware; an interruption or runtime-error notification arriving in that window queues behind it, and a second `start()`/`stop()` or the shutter cannot even evaluate its guard until the hardware call returns — a hung-beachball window where lifecycle state is stale.

**Proposed fix.** Run the blocking `startRunning()`/`stopRunning()` on a detached background executor (e.g. `Task.detached`) and reconcile `isRunning` on completion, keeping the actor responsive to lifecycle events.

---

### `low` Post-capture PhotoKit refresh runs synchronously on the main actor

`pikicam/Features/Gallery/PikicamLibraryModel.swift:77` · kind=perf · confidence=likely · votes=1|refute=1

**Evidence.** PikicamLibraryModel.save (Gallery/PikicamLibraryModel.swift:77-84) calls `await refresh()` which runs `manager.captures()` PhotoKit enumeration (lines 26-41) on @MainActor; runCapture calls it inline before returning to idle (CameraViewModel.swift:288). The codebase convention is RAW/PhotoKit work off-main (DevelopService CIContext never on main).

**Failure scenario.** Every successful capture blocks the main thread on a full PhotoKit fetch (+ thumbnail/invalidation churn) between exposure and shutter re-arm -> shutter button stays in savingDNG longer, UI hitches on large libraries.

**Proposed fix.** Move captures() enumeration off-main (nonisolated fetch + MainActor publish), or append the saved capture locally instead of full refresh.

---

### `low` Live aperture preview ignores zoom; the developed Print does not

`pikicam/Features/Camera/CameraView.swift` · kind=correctness · confidence=likely · votes=1|refute=1

**Evidence.** Line 355: `PrintCrop.rect(in: bounds, zoomFactor: 1.0, aspect: aspectRatio)` — the framing mask is hardcoded to 1x. But DevelopService.render applies `PrintCrop.rect(..., zoomFactor: capture.zoomFactor)` and the live preview feed itself is device-zoomed (setVideoZoomFactor), so at 2x the user frames a zoomed feed with 1x-geometry mask bands while the stored Print is a tighter center crop.

**Failure scenario.** Set 2x zoom, compose so the subject fills the unmasked preview area, capture -> the viewer Print shows a tighter center crop than was framed; 'what you frame is what you get' breaks exactly when zoom is used.

**Proposed fix.** Pass viewModel.zoomFactor into FramingOverlays/aperture instead of 1.0 so the mask matches the develop crop; add a unit test asserting preview-aperture rect == PrintCrop with the same zoom used by render.

---

### `low` Overlapping refresh() calls can publish stale captures over newer ones

`pikicam/Features/Gallery/PikicamLibraryModel.swift:33` · kind=correctness · confidence=likely · votes=1|refute=1

**Evidence.** `refresh()` sets `isLoading = true`, then `captures = try await manager.captures()` (line 33), then `isLoading = false`. Because the class is `@MainActor`, two refreshes are interleaved at that suspension point: the model runs a refresh from `init` (line 16-18), another from `GalleryView.task { await library.refresh() }`, and a third from `watchInvalidation()` (line 45-47) on every PhotoKit change. `PhotoLibraryManager` is an actor, so call N's `captures()` observes index state as of N, and whichever call completes last wins the assignment.

**Failure scenario.** A PhotoKit change notification fires refresh B (which sees the newly saved capture) while refresh A, issued moments earlier, is still awaiting. B completes and publishes the new list; A then completes and overwrites `captures` with the list missing that capture. The gallery shows the pre-save state until the next invalidation, and the UI test's `gallery-cell-0` assertion can target the wrong DNG.

**Proposed fix.** Serialize refreshes: keep a `refreshTask` and have callers `await` the in-flight one (coalescing, like the invalidation stream's `bufferingNewest(1)`), or add a monotonic generation counter and drop the result of any refresh older than the newest issued.

---

### `low` Gallery's error/retry surfaces are untested and use colliding accessibility identifiers

`pikicam/Features/Gallery/GalleryView.swift:87` · kind=test-gap · confidence=certain · votes=1|refute=1

**Evidence.** Two independent error presentations both set `.accessibilityIdentifier("gallery-error")` and both render a `Button("Retry")` with `.accessibilityIdentifier("gallery-retry")` — the `ContentUnavailableView` branch at lines 81-97 and the inline banner at lines 121-135. A `descendants(matching: .any).matching(identifier:)` query for either returns two elements whenever both are reachable, and `firstMatch` silently picks one. No test in either suite references `gallery-error`, `gallery-retry`, `gallery-loading`, or `gallery-empty`.

**Failure scenario.** A test (or a future VoiceOver user) resolving "Retry" gets an ambiguous match; XCUITest taps the wrong one, or `waitForExistence` returns true against an element that is not hittable. The documented "transient PhotoKit failure must not wipe the gallery" behavior (`PikicamLibraryModel.refresh` keeps `captures` on error) has no test at all.

**Proposed fix.** Namespace the identifiers for test diagnosability only (e.g. gallery-error-empty/gallery-retry-empty vs gallery-error-banner/gallery-retry-banner); then add a refresh-keeps-captures test behind a new injection seam (protocol or captures-closure on PikicamLibraryModel), since manager is currently a concrete `nonisolated let manager = PhotoLibraryManager()` with no throw-injection point.

---

### `low` CapturedDNG validation does not cover the empty-but-valid-bytes boundary the real pipeline produces

`pikicamTests/PikicamPipelineTests.swift:455` · kind=test-gap · confidence=likely · votes=1|refute=1

**Evidence.** `testCapturedDNGRejectsInvalidZoomFactor` passes `let bytes = Data([0x49, 0x49, 0x2A, 0x00])` — a 4-byte TIFF header stub — as the "valid" payload for `XCTAssertNoThrow` (line 476). `CapturedDNG.init` only guards `!data.isEmpty` and the zoom range; it never validates that the bytes are a DNG. The stub is only reachable because no test feeds `CapturedDNG` a value that is non-empty but not a DNG.

**Failure scenario.** `CaptureService.capturePhoto` produces `fileDataRepresentation()` = a DNG, so this is currently unreachable in production — but the boundary's whole stated purpose (line 23-26: "an empty payload would otherwise persist as an unopenable asset that still passes the DNG-resource check") is only half-enforced. A future caller that truncates or concatenates the payload persists an unopenable asset, and `testStorageSavesDNGSinglePhotoResourceToPhotos` would still pass because it only checks the resource's UTI/filename, never that the bytes open.

**Proposed fix.** Either tighten `CapturedDNG.init` to require a TIFF/DNG magic header (matching the comment's own stated intent) and test the rejection, or drop the stub from the no-throw assertions so the test does not imply the boundary validates more than it does.

---

### `low` UI test asserts app.state == .runningForeground, which cannot fail while the test is running

`pikicamUITests/SmokeLaunchTest.swift:266` · kind=test-gap · confidence=certain · votes=1|refute=1

**Evidence.** Three sites assert `XCTAssertEqual(app.state, .runningForeground, "App left the foreground during capture (crash?).")` (lines 266, 467, 551, 574, 595, 613). XCUITest terminates the test process when the app under test crashes, so by the time this line executes the process is alive. The messages claim crash detection, but a crash surfaces as a test-runner failure, not this assertion.

**Failure scenario.** The assertion reads as crash coverage in review but contributes nothing — a reviewer greps for it and concludes the walkthrough proves crash-freedom under zoomed/rapid/flip capture. The actual crash protection comes from the test completing at all, which is undocumented and easy to lose in a refactor that adds a `continue`-style early exit.

**Proposed fix.** Either delete the three `app.state` assertions and state in the doc comment that crash detection is implicit in the test completing, or replace them with a check that has real content: assert the gallery cell count grew by 1 after the capture (scoped to the grid, so it cannot leak from the viewer cover — the pattern `galleryCellCount(in:)` at line 727 already provides).

---

### `low` Gallery cells identified by array index, contradicting CaptureID contract

`pikicam/Features/Gallery/GalleryView.swift:107` · kind=ui-ux · confidence=certain · votes=1|refute=1

**Evidence.** PhotoLibraryManager.swift:57-59 documents 'The gallery selects and pages by this value [CaptureID], never by an array index.' GalleryView.swift:107,115 builds cells as `ForEach(Array(library.captures.enumerated()), id: \.element.id.uuid)` with `.accessibilityIdentifier("gallery-cell-\(index)")` — position-based identity the UI tests depend on (SmokeLaunchTest asserts gallery-cell-0 is the newest).

**Failure scenario.** New capture arrives via invalidation refresh while VoiceOver focuses gallery-cell-3 -> indices shift, focus/content now points at a different capture; UI contract gallery-cell-0 silently rebinds, masking ordering regressions the CaptureID sort (captures() lines 487-492) is supposed to pin.

**Proposed fix.** Identify cells by stable capture ID (e.g. `gallery-cell-\(capture.id.uuid.uuidString.prefix(8))` plus a `gallery-cell-newest` alias for the walkthrough), keeping one index-based alias only where the UI test needs ordering; update SmokeLaunchTest accordingly.

---

### `low` Index lock is in-process only; cross-process file races unguarded

`pikicam/Core/Storage/PhotoLibraryManager.swift:823` · kind=concurrency · confidence=speculative · votes=1|refute=1

**Evidence.** PhotoLibraryManager.swift:820-830 — indexLock/inFlightSaveIDs are static NSLock-guarded in-process state, commented as guarding 'concurrent PhotoLibraryManager instances (the app's gallery model and the test host)'. NSLock does not synchronize across processes; test host and app are separate processes sharing one index file via mutateIndex read-modify-write.

**Failure scenario.** Future on-device test run (or app extension) mutates the index while the app writes -> interleaved load-modify-save -> last-writer-wins silently drops the other's records; in-flight save guard also invisible cross-process so a pending can be pruned mid-save, orphaning a Photos asset.

**Proposed fix.** Scope the comment to in-process instances; for the shared file use coordinated writes (NSFileCoordinator or flock(2) around read-modify-write) or accept single-writer and fail loudly (indexCommitFailed) on generation mismatch via a file UUID + inode check.

---

### `low` Thumbnail shows stale/ambiguous state during save, failure == empty

`pikicam/Features/Camera/CameraView.swift:181` · kind=ui-ux · confidence=speculative · votes=1|refute=1

**Evidence.** CameraView.swift:181-183 "if let capture = library.captures.first { ThumbnailImage(assetID: capture.assetID, library: library) }" with ThumbnailImage.task (:328-334) doing "image = try await library.loadThumbnail(for: assetID)" and swallowing errors to nil. After a fresh capture runCapture does libraryModel.select(capture) (CameraViewModel.swift:290) but the thumbnail reads captures.first (newest-first assumed, not the selected capture), has no placeholder shimmer or saving state during .savingDNG, and on load failure silently shows the same gray box as the empty state — indistinguishable from "no captures yet". No test covers thumbnail-after-save.

**Failure scenario.** Slow Photos commit: user captures, watches the thumbnail for ~2s during savingDNG -> still shows the pre-capture image (or gray box) -> taps it expecting the new DNG -> gallery opens without the new asset reconciled yet.

**Proposed fix.** Drive the thumbnail from the selected/latest capture id, show an explicit developing/saving affordance during .capturing/.savingDNG, and distinguish load-failure from empty (retry affordance). Keep the gallery-thumbnail identifier.

