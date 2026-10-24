CONTEXT
Repo: /Users/adrifadilah/Desktop/pikicam (iOS camera app, Swift, XcodeGen via project.yml).
Product goal: camera -> our own code -> bypass the iPhone's post-processing. Capture the least-processed sensor data iOS exposes (Bayer RAW / DNG; avoid Apple's computational pipeline: Deep Fusion, Smart HDR, Photonic Engine, sharpening, noise reduction, local tone mapping, semantic rendering), then develop it with our own code, behind a clean, excellent camera UI/UX.
The owner says the current implementation is poor: a lot of slop code and disgusting UI/UX. Your research feeds a single implementation prompt that will be used to fix everything, so be exhaustive, concrete, and cite evidence (file:line for code, URLs for external sources).

RULES
- This is a RESEARCH task. Do NOT modify, create, or delete any file except your own output file. Do not revert, stash, or discard the uncommitted working tree.
- Run fully autonomously. No human is available. Never stop to ask questions; make reasonable calls and record them as assumptions.
- Read every relevant file completely; do not skim. Prefer reading over guessing. Verify claims.
- For external facts (Apple APIs, behaviors, OS versions), use any web/search tool you have; if none, use curl against developer.apple.com docs, Apple sample code, WWDC session pages, and reputable sources. Mark anything unverified as UNVERIFIED.
- Output: a single Markdown file at the path given below. Structure: Summary (top 10 findings), Detailed findings (each with severity P0/P1/P2, evidence, why it matters, recommended fix direction), Open questions/assumptions, Sources.
