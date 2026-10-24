TASK: Write ONE comprehensive implementation prompt that another autonomous coding agent (pi, headless, no human available, no skills) will execute to fix the pikicam iOS app end to end. You are writing the prompt, NOT implementing. Do not modify any file except the output file.

INPUTS (read every one fully before writing):
- docs/workflow/research/01-capture-pipeline.md
- docs/workflow/research/02-apple-platform-limits.md
- docs/workflow/research/03-develop-pipeline.md
- docs/workflow/research/04-code-quality.md
- docs/workflow/research/05-ui-ux.md (and docs/workflow/research/screens/ if present)
- /Users/adrifadilah/.claude/skills/sinthink/SKILL.md — a design-thinking method (written in Effect-TS terms). Read it as a reference document.
- Spot-check the repo (/Users/adrifadilah/Desktop/pikicam) to verify any research claim you rely on; if research files conflict, resolve by reading the code / sources and say which is right.

STANCE (from the owner, overrides anything above): Everything in this repo — committed AND uncommitted code, the in-progress design system (pikicam/Core/Design, DesignLintTests, verify-design.sh), docs (including docs/.P.DESIGN.md, docs/design/, docs/prompt-next.md, README), tests, CI, scripts, project config — is presumed stupid and shitty. Nothing is sacred or authoritative; no existing doc represents the owner's real intent. Judge every piece from first principles against the product goal and best practice. Existing work survives only if it clearly earns its place; default verdict is delete or rewrite. Touching/replacing uncommitted work is allowed in the eventual implementation.

PRODUCT GOAL: camera -> our own code -> bypass iPhone post-processing. Least-processed sensor capture (Bayer RAW/DNG), our own development pipeline, original DNG preserved, and a clean, excellent pro camera UI/UX. Owner judges the current code as slop and the UI/UX as disgusting; the prompt must fix everything the research found.

PROMPT REQUIREMENTS
1. Self-contained: it will be embedded verbatim into the owner's "Workflow" and run without this conversation. Inline every fact the implementer needs (key findings, file:line evidence, Apple API decisions with exact property values, sources). Also reference the research files by path for depth.
2. Directive and unambiguous: decisions made, not options. Where research left a genuine open question, make the call and state the rationale.
3. Structure (use these top-level sections):
   - Mission & definition of done (measurable).
   - Hard constraints & guardrails (the whole existing codebase — committed and uncommitted, including pikicam/Core/Design, DesignLintTests, verify-design.sh, docs/.P.DESIGN.md, docs/design, docs/prompt-next.md, tests, CI, scripts — is presumed stupid and shitty: nothing is sacred, rewrite from first principles, keep only what clearly earns its place and say exactly what is kept; project generation policy (XcodeGen: project.yml is source of truth, regenerate and keep the project file consistent); no skills; autonomous; never ask questions; commit policy).
   - Current-state diagnosis: P0/P1/P2 issue list consolidated and de-duplicated across all research, each with evidence and required fix.
   - Target behavior spec: capture (exact AVFoundation config), develop (exact CIRAWFilter / custom pipeline parameters, color management, output formats), storage (DNG original + developed rendition, Photos pairing), preview, and UI/UX spec (screens, controls, interactions, states, accessibility, design tokens) concrete enough to build without guessing.
   - IMPLEMENTATION DESIGN — this section, and only this section, must follow the sinthink method, translated faithfully from Effect-TS concepts into idiomatic modern Swift (Swift 6 strict concurrency): §1 Shapes (records, IDs as distinct types, variants as enums, errors as typed enums with context), §2 A happy-path call graph drawn as ASCII, §3 cardinality (one-shot async throws vs AsyncStream/AsyncSequence, cached/time-bounded values), §4 E (break points: retry, escape, die — typed throws), §5 R (dependencies as protocols injected at construction, compile-time proven), §6 Boundary (untrusted -> trusted parsing at edges: AVFoundation callbacks, DNG metadata, Photos results, user input), §7 Behavior (cross-cutting wrappers that don't change the graph: logging, timing, retry), §8 Scope (acquire/release tied to lifecycle: AVCaptureSession, CIContext, Metal resources, continuations), §9 Test (swap dependencies, same graph shape; which fakes, which tests), §10 Code (body = happy path, wrappers = error handling; file/module layout, which files to delete, create, rewrite). The code must BE the graph.
   - Execution plan: ordered phases, each with concrete file-level tasks, acceptance criteria, and exact verification commands (xcodebuild build/test with simulator destination, design lint script, etc.). Include on-device verification checklist items that the owner must run (simulator cannot capture camera).
   - Non-goals.
   - Final self-check checklist for the implementer.
4. The research sections of the prompt must NOT be forced into the sinthink format; sinthink applies only to the implementation design.
5. Be as comprehensive as necessary. Length is fine; padding is not. No filler, no generic advice.

OUTPUT: write the prompt to docs/workflow/PROMPT.md. Then re-read it end to end against all research files and fix gaps, contradictions, and vagueness before finishing.

Run fully autonomously; never ask questions.
