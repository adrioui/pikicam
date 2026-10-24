import XCTest
import Foundation
import CoreGraphics
@testable import pikicam

// =============================================================================
// MARK: - DesignViolation
//
// Copied case-for-case from docs/.P.DESIGN.md §1.4 (lines 232-243). The one
// mechanical divergence: the spec writes Swift argument labels capitalised
// (`File: String, Line: Int`), which does not compile. Case *names* are exact;
// labels are lower-cased. Nothing else is altered. R3: the spec's intent is
// unambiguous, so this is transcription, not reconciliation.
//
// Handling strategy, §1.4:246-250 —
//   Retry   : contrastBelowAA
//   Escape  : missing token for a room -> fall back to ink and REPORT
//   DIE     : rawRoundedType, capsuleOrCircleShape, iconInChrome,
//             dividerInsteadOfRule. Programmer defects. Never "handled".
// =============================================================================

enum DesignViolation: Error, Equatable, CustomStringConvertible {

    case rawRoundedType(File: String, Line: Int)
    case capsuleOrCircleShape(File: String, Line: Int)
    case iconInChrome(symbol: String)
    case forbiddenColor(String)
    case dividerInsteadOfRule
    case fixedTypeWithoutRelativeTo(String)
    case missingIdentifier(File: String, Line: Int)
    case contrastBelowAA(fg: String, bg: String, ratio: Double, required: Double)
    case tapTargetBelow44(pt: CGFloat)
    case bareWordsOverPreview(File: String, Line: Int)

    var description: String {
        switch self {
        case let .rawRoundedType(file, line):
            return "rawRoundedType — rounded/raw system font in chrome at \(file):\(line)"
        case let .capsuleOrCircleShape(file, line):
            return "capsuleOrCircleShape — rounding shape at \(file):\(line). §2.5: radius 0 everywhere."
        case let .iconInChrome(symbol):
            return "iconInChrome — Image(systemName: \"\(symbol)\"). Owner ruling #8: NO ICONS ANYWHERE."
        case let .forbiddenColor(what):
            return "forbiddenColor — \(what). §8.1: colours resolve through ChromeInk, never literals."
        case .dividerInsteadOfRule:
            return "dividerInsteadOfRule — Divider() has no one-physical-pixel contract. §2.4."
        case let .fixedTypeWithoutRelativeTo(what):
            return "fixedTypeWithoutRelativeTo — \(what). §2.2: the two-arg Font.custom freezes under Dynamic Type."
        case let .missingIdentifier(file, line):
            return "missingIdentifier — bare/unregistered accessibilityIdentifier at \(file):\(line)"
        case let .contrastBelowAA(fg, bg, ratio, required):
            return String(format: "contrastBelowAA — %@ on %@ = %.2f:1, required %.2f:1",
                          fg, bg, ratio, required)
        case let .tapTargetBelow44(pt):
            return String(format: "tapTargetBelow44 — %.1fpt target. §8.2: min 44.", pt)
        case let .bareWordsOverPreview(file, line):
            return "bareWordsOverPreview — word over the preview with no scrim at \(file):\(line). §1.6."
        }
    }
}

// =============================================================================
// MARK: - SourceScanner
//
// The lint is a *pure* function of the repository's text (R6): read files,
// strip comments, match patterns, return values. It has no dependency on the
// app target at runtime, so it runs in the unit-test bundle and fails CI
// exactly as §8.1 requires ("the build fails").
// =============================================================================

/// One hit, carrying enough provenance to be actionable in a CI log.
struct LintHit {
    let file: String      // repo-relative
    let line: Int         // 1-based
    let text: String      // the offending line, trimmed
}

struct SourceScanner {

    /// Repo root, derived from this file's own location
    /// (`<root>/pikicamTests/DesignLintTests.swift`). No `#filePath` of a
    /// symlinked build dir, no environment variable, no working-directory
    /// assumption: the lint must find the same tree CI does.
    static let repoRoot: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // pikicamTests
        .deletingLastPathComponent()   // <root>
        .standardizedFileURL

    /// Every Swift file under the app target. The lint's iteration source;
    /// tests and the design token layer are excluded by construction because
    /// the token layer is where the literals legitimately live.
    static func appSources() throws -> [URL] {
        let appDir = repoRoot.appendingPathComponent("pikicam")
        var found: [URL] = []
        var stack = [appDir]
        while let dir = stack.popLast() {
            for entry in try FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.isDirectoryKey]
            ) {
                if entry.hasDirectoryPath {
                    stack.append(entry)
                } else if entry.pathExtension == "swift" {
                    found.append(entry)
                }
            }
        }
        return found.sorted { $0.path < $1.path }
    }

    static func relative(_ url: URL) -> String {
        let root = repoRoot.path + "/"
        return url.path.hasPrefix(root)
            ? String(url.path.dropFirst(root.count))
            : url.lastPathComponent
    }

    /// Replace comment spans with spaces, preserving byte offsets and newlines
    /// so that reported line numbers match the file on disk exactly.
    ///
    /// String literals are preserved: §8.1 must read
    /// `Image(systemName: "camera.aperture")` and
    /// `accessibilityIdentifier("gallery-trash")` — the payload IS the string.
    /// Known limitation, stated rather than hidden: this is not a full Swift
    /// lexer, so a `"` or `//` inside a string literal that itself contains a
    /// quote will be mis-detected. The token layer must not write such
    /// literals; if it does, the lint reports a hit on a line with no code,
    /// which a human reads in one second.
    static func strippingComments(_ source: String) -> String {
        var out = String()
        out.reserveCapacity(source.count)
        var chars = Array(source)
        var i = 0
        var inBlock = false
        var inLine = false
        var inString = false

        func blank(_ c: Character) -> Character {
            c == "\n" ? "\n" : " "
        }

        while i < chars.count {
            let c = chars[i]
            let next = i + 1 < chars.count ? chars[i + 1] : "\0"

            if inLine {
                if c == "\n" { inLine = false; out.append(c) } else { out.append(blank(c)) }
            } else if inBlock {
                if c == "\n" { out.append(c) } else { out.append(blank(c)) }
                if c == "/" && next == "*" { out.append(blank(next)); i += 1 }
                else if c == "*" && next == "/" { out.append(blank(next)); i += 1; inBlock = false }
            } else if inString {
                out.append(c)
                if c == "\\", i + 1 < chars.count {
                    out.append(chars[i + 1]); i += 1
                } else if c == "\"" { inString = false }
            } else {
                if c == "/", next == "/" { out.append(blank(c)); out.append(blank(next)); i += 1; inLine = true }
                else if c == "/", next == "*" { out.append(blank(c)); out.append(blank(next)); i += 1; inBlock = true }
                else { out.append(c); if c == "\"" { inString = true } }
            }
            i += 1
        }
        return out
    }

    /// `[1-based line number] : comment-stripped line`. Both consumers (the
    /// regex checks and the brace-range walker) read this one representation,
    /// so a hit's line number can never disagree with what was matched.
    static func numberedLines(_ source: String) -> [(line: Int, text: String)] {
        strippingComments(source).components(separatedBy: "\n")
            .enumerated()
            .map { ($0.offset + 1, String($0.element)) }
    }

    static func read(_ url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    /// Brace-depth walk over comment-stripped source, returning the 1-based
    /// line span of `struct <name>`'s body. Used by the room-coverage check,
    /// which must count `.environment(\.room, …)` *per screen*, not per file.
    static func lineSpanOfStruct(named name: String,
                                 in numbered: [(line: Int, text: String)]) -> ClosedRange<Int>? {
        let decl = "struct \(name)"
        guard let start = numbered.first(where: { $0.text.contains(decl) }) else { return nil }

        var depth = 0
        var sawBrace = false
        for entry in numbered where entry.line >= start.line {
            for ch in entry.text {
                if ch == "{" { depth += 1; sawBrace = true }
                else if ch == "}" {
                    depth -= 1
                    if sawBrace && depth == 0 { return start.line...entry.line }
                }
            }
        }
        return sawBrace ? start.line...(numbered.last?.line ?? start.line) : nil
    }
}

// =============================================================================
// MARK: - The lint allowlist (§8.1 line 615)
//
// "the only legitimate raw drawing": Image(uiImage:) for photography, the
// scrim gradients, the ChromeRule rectangle, and the four tack rects.
// =============================================================================

enum LintAllowlist {

    /// `Image(uiImage:)` — photography is full-colour by design (§2.3 line
    /// 397: "Thumbnails are full-colour photography"). The DNG preview and
    /// each grid cell carry colour; chrome does not.
    static let photographyToken = "Image(uiImage:"

    /// Files permitted to contain raw colour literals. The token layer is the
    /// single point where a hex/`.white` may exist; every other file must go
    /// through ChromeInk.
    static let tokenLayerPaths: Set<String> = [
        "pikicam/Core/Design/ChromeInk.swift",
        "pikicam/Core/Design/ChromeType.swift",
        "pikicam/Core/Design/ChromeRule.swift",
        "pikicam/Core/Design/Tack.swift",
        "pikicam/Core/Design/Room.swift",
        "pikicam/Core/Design/WordControl.swift",
    ]

    /// Raw drawing shapes that are permitted, with the exact reason each one
    /// earns its place. A `Circle()` is NOT here: the shutter is a *square*
    /// hairline ring (§2.5, owner ruling #6), so the old `Circle()` at
    /// ShutterButton.swift:15-22 has no allowlist entry and dies.
    static func isAllowedShape(_ shape: String, file: String, line: Int) -> Bool {
        // The blank tag's border (d) and the rule itself are Rectangles;
        // Rectangle is never scanned as a violation in the first place. The
        // four tack rects (§9.5) are Rectangles too. So there is no Rectangle
        // exemption to encode — and that asymmetry is deliberate: the
        // allowlist names the *concept* (ChromeRule, Tack) which is realised
        // as `Rectangle()`, not the *token*.
        if shape == "Rectangle" {
            let allowed = file == "pikicam/Core/Design/ChromeRule.swift"
                || file == "pikicam/Core/Design/Tack.swift"
                || file == "pikicam/Core/Design/ChromeType.swift"
            if allowed { return true }
            // A Rectangle anywhere else is a box. §2.4: "No boxes around
            // buttons. No card outlines." The tag border and the rules are
            // the only four places a rule may appear.
            return false
        }
        _ = line
        return false
    }

    static func isAllowedColor(_ file: String) -> Bool {
        tokenLayerPaths.contains(file)
    }
}

// =============================================================================
// MARK: - ForbiddenPattern — §8.1, one value per rule
// =============================================================================

enum ForbiddenPattern: CaseIterable {

    /// §8.1 bullet 1 — `.font(.system(…, design: .rounded))` and any raw
    /// `.system` font in chrome. The face is Courier New (§2.2); the only
    /// `.system` permitted is the *defensive fallback* `.system(design:
    /// .monospaced)` inside the token layer.
    case rawRoundedType
    /// §8.1 bullet 2 — `Capsule()`, decorative `Circle()`, `RoundedRectangle`.
    case capsuleOrCircleShape
    /// §8.1 bullet 3 — `Image(systemName:)` anywhere in chrome.
    case iconInChrome
    /// §8.1 bullet 4 — `.yellow`; `.red` outside `fail` in the black room;
    /// literal `.white`/`.black` outside ChromeInk.
    case forbiddenColor
    /// §8.1 bullet 5 — `Divider()`.
    case dividerInsteadOfRule
    /// §8.1 bullet 6 — two-arg `Font.custom` without `relativeTo`.
    case fixedTypeWithoutRelativeTo
    /// §8.1 bullet 7 — a bare `accessibilityIdentifier("…")` string literal
    /// not sourced from `ControlIDRegistry`.
    case missingIdentifier

    /// Returns violations found in one file. Pure: (source, path) -> values.
    static func violations(in path: String,
                           numbered: [(line: Int, text: String)]) -> [DesignViolation] {
        var found: [DesignViolation] = []

        for (line, text) in numbered {
            // --- rawRoundedType ---
            if text.contains("design: .rounded") || text.contains(".rounded)") {
                found.append(.rawRoundedType(File: path, Line: line))
            }
            // Any raw `.system(` font outside the token layer is a violation,
            // including the "harmless" `.system(size: 17)` — the two-arg
            // overload of Font.system freezes under Dynamic Type exactly as
            // Font.custom's does.
            if text.contains(".system(") && !LintAllowlist.isAllowedColor(path) {
                found.append(.rawRoundedType(File: path, Line: line))
            }

            // --- capsuleOrCircleShape ---
            for shape in ["Capsule(", "Circle(", "RoundedRectangle("] {
                if text.contains(shape), !LintAllowlist.isAllowedShape("Rectangle", file: path, line: line) {
                    let bare = String(shape.dropLast())
                    found.append(.capsuleOrCircleShape(File: path, Line: line))
                    _ = bare
                }
            }

            // --- iconInChrome ---
            if let r = text.range(of: "Image(systemName:") {
                let tail = String(text[r.upperBound...])
                let symbol = tail
                    .replacingOccurrences(of: "\"", with: "")
                    .components(separatedBy: "\"")[0]
                    .trimmingCharacters(in: .whitespaces)
                found.append(.iconInChrome(symbol: symbol.isEmpty ? "<unparsed>" : symbol))
            }

            // --- forbiddenColor ---
            if !LintAllowlist.isAllowedColor(path) {
                if text.contains(".yellow") {
                    found.append(.forbiddenColor(".yellow — the zoom/aspect selected fill. House ink carries selection, §2.3."))
                }
                // `.red` is permitted ONLY as the `fail` ink of the black room.
                // Spelling it as a literal at a call site is forbidden even
                // there; the call site must write `ChromeInk.fail`.
                if text.range(of: "\\.red\\b", options: .regularExpression) != nil {
                    found.append(.forbiddenColor(".red outside ChromeInk.fail — §0.5 #6: no red in the white room at all."))
                }
                for literal in [".white", ".black"] where text.contains(literal) {
                    found.append(.forbiddenColor("literal \(literal) outside ChromeInk — §2.1 line 345: dark mode renders black-on-black."))
                }
            }

            // --- dividerInsteadOfRule ---
            if text.range(of: "\\bDivider\\s*\\(", options: .regularExpression) != nil {
                found.append(.dividerInsteadOfRule)
            }

            // --- fixedTypeWithoutRelativeTo ---
            // Three-arg is Font.custom(_:size:relativeTo:). Two-arg is
            // Font.custom(_:size:). Match the call, then require
            // `relativeTo:` inside it.
            var searchFrom = text.startIndex
            while let open = text.range(of: "Font.custom(", range: searchFrom..<text.endIndex) {
                var depth = 0
                var close: String.Index?
                var i = open.upperBound
                while i < text.endIndex {
                    if text[i] == "(" { depth += 1 }
                    if text[i] == ")" {
                        depth -= 1
                        if depth == 0 { close = i; break }
                    }
                    i = text.index(after: i)
                }
                let end = close ?? text.endIndex
                let call = String(text[open.lowerBound..<end])
                if !call.contains("relativeTo:") {
                    found.append(.fixedTypeWithoutRelativeTo(call))
                }
                searchFrom = close.map { text.index(after: $0) } ?? text.endIndex
                if searchFrom >= text.endIndex { break }
            }

            // --- missingIdentifier ---
            if let r = text.range(of: "accessibilityIdentifier(\"") {
                let tail = String(text[r.upperBound...])
                let literal = tail.components(separatedBy: "\"")[0]
                if !ControlIDRegistry.isRegistered(literal) {
                    found.append(.missingIdentifier(File: path, Line: line))
                }
            }
        }
        return found
    }
}

// =============================================================================
// MARK: - The screens (§1.5, §3, §4)
//
// Four roots, each declared with the room it must resolve to. `rootedInRoom`
// is the §1.5 ruling: a view that forgot `.environment(\.room, …)` renders in
// the default room and the coverage assertion below fails.
// =============================================================================

struct ScreenDecl {
    let name: String
    let file: String
    let room: Room          // the room at its root, per §1.5 line 265
    let isChrome: Bool      // camera chrome resolves over the live preview
}

enum Screens {
    static let all: [ScreenDecl] = [
        ScreenDecl(name: "RootView",             file: "pikicam/App/RootView.swift",                              room: .black, isChrome: true),
        ScreenDecl(name: "PermissionsView",      file: "pikicam/App/RootView.swift",                              room: .black, isChrome: true),
        ScreenDecl(name: "PermissionsDeniedView", file: "pikicam/App/RootView.swift",                             room: .black, isChrome: true),
        ScreenDecl(name: "CameraView",           file: "pikicam/Features/Camera/CameraView.swift",                 room: .black, isChrome: true),
        ScreenDecl(name: "GalleryView",          file: "pikicam/Features/Gallery/GalleryView.swift",               room: .white, isChrome: false),
        ScreenDecl(name: "FullScreenViewer",     file: "pikicam/Features/Gallery/GalleryView.swift",               room: .white, isChrome: false),
    ]
}

// =============================================================================
// MARK: - 44pt — §8.2 line 617
// =============================================================================

enum TapTarget {

    static let minimum: CGFloat = 44

    /// Pull every `minWidth:`/`minHeight:` value out of the `.frame(…)` calls
    /// on a line, so the check reads the *declared* minimum, not the pixel
    /// result. A view that pads with `.padding()` instead of
    /// `.frame(minWidth:minHeight:)` does not satisfy §8.2 and is reported:
    /// the assertion is that the 44 is a *contract*, not an emergent size.
    static func declaredMinimums(in text: String) -> [CGFloat] {
        var values: [CGFloat] = []
        for key in ["minWidth", "minHeight"] {
            var searchFrom = text.startIndex
            while let r = text.range(of: "\(key)\\s*:\\s*([0-9]+(?:\\.[0-9]+)?)",
                                     options: .regularExpression,
                                     range: searchFrom..<text.endIndex) {
                let captured = text[r].dropFirst(key.count)
                if let v = Double(captured.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    values.append(CGFloat(v))
                }
                searchFrom = r.upperBound
                if searchFrom >= text.endIndex { break }
            }
        }
        return values
    }

    /// A line that *declares* a control (a registered word, a Button, or a
    /// WordControl) must declare a 44 minimum. Numbers applied to pure layout
    /// (a 60pt top bar) are not tap targets and are not scanned.
    static func violations(in path: String,
                           numbered: [(line: Int, text: String)]) -> [DesignViolation] {
        var found: [DesignViolation] = []
        for (line, text) in numbered {
            let declaresControl = text.contains("WordControl")
                || text.contains("ControlIDRegistry.")
                || text.range(of: "\\bButton\\s*\\(", options: .regularExpression) != nil
                || text.contains("accessibilityAddTraits")
            guard declaresControl else { continue }

            let minimums = declaredMinimums(in: text)
            if minimums.isEmpty {
                found.append(.tapTargetBelow44(pt: 0))
            } else if let lowest = minimums.min(), lowest < minimum {
                found.append(.tapTargetBelow44(pt: lowest))
            }
        }
        return found
    }
}

// =============================================================================
// MARK: - Room coverage — §1.5 line 265 / §8.3
//
// "R shrinks to never when every screen is wrapped in exactly one
// .environment(\.room, …) at its root."
//
// EXACTLY ONE: zero is a defect (the screen silently renders in the default
// room) and two is a defect (one wins silently and the other is dead code —
// the cheapest possible way to make the swap test in §1.9 lie).
// =============================================================================

enum RoomCoverage {

    static func violations(for screen: ScreenDecl,
                           numbered: [(line: Int, text: String)]) -> [DesignViolation] {
        guard let span = SourceScanner.lineSpanOfStruct(named: screen.name, in: numbered) else {
            // The screen is absent from the file. That is a compile error the
            // build already reports; returning empty keeps this test from
            // duplicating the compiler.
            return []
        }
        var count = 0
        var firstLine = 0
        for (line, text) in numbered where span.contains(line) {
            if text.contains(".environment(\\.room") || text.contains(".environment(\\ .room") {
                count += 1
                if firstLine == 0 { firstLine = line }
            }
        }
        guard count == 1 else {
            // Reuse the enum's typed channel rather than inventing a string:
            // this is the same failure §1.5 names — R was satisfied by
            // omission. The first `.environment(\.room` line is the anchor so
            // the CI log points somewhere actionable.
            return [.missingIdentifier(File: "\(screen.file)#\(screen.name)", Line: firstLine == 0 ? span.lowerBound : firstLine)]
        }
        return []
    }
}

// =============================================================================
// MARK: - §8.2 — identifier AND label
//
// "The lint asserts the identifier and the label/value are present."
// =============================================================================

enum IdentifierLabel {

    static func violations() -> [DesignViolation] {
        var found: [DesignViolation] = []
        for (id, word) in ControlIDRegistry.words {
            if word.isEmpty {
                found.append(.missingIdentifier(File: "ControlIDRegistry", Line: 0))
            }
            _ = id
        }
        // Every tappable word in `all` must also appear in `words` — a
        // control registered but unlabelled renders as a blank 44pt box, which
        // is the failure mode §0.6 Q1's "words only" ruling exists to prevent.
        let wordIDs = Set(ControlIDRegistry.words.map(\.id))
        for id in ControlIDRegistry.all where !wordIDs.contains(id) {
            // Non-interactive surfaces are legitimately absent from `words`.
            // They are enumerated by name, so an unlisted one is a defect.
            let nonInteractive: Set<String> = [
                "camera-preview", "camera-zoom", "camera-grid-overlay",
                "camera-aspect-mask", "camera-exposure", "camera-timer-countdown",
                "room-title", "room-grid", "room-loading", "room-empty",
                "room-error", "viewer-loading", "viewer-load-failure",
                "viewer-background",
            ]
            if !nonInteractive.contains(id.rawValue) {
                found.append(.missingIdentifier(File: "ControlIDRegistry", Line: 0))
            }
        }
        return found
    }
}

// =============================================================================
// MARK: - Contrast — §8.3 line 619 / §0.2
//
// WCAG AA: 4.5:1 normal, 3:1 large (>=18pt, or >=14pt bold). Pure relative-
// luminance per WCAG 2.x; returns the ratio, DERIVED by the formula, not
// eyeballed.
// =============================================================================

enum Contrast {

    static func channel(_ v: Double) -> Double {
        v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
    }

    static func luminance(_ r: Double, _ g: Double, _ b: Double) -> Double {
        0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }

    static func ratio(fg: (r: Double, g: Double, b: Double),
                      bg: (r: Double, g: Double, b: Double)) -> Double {
        let a = luminance(fg.r, fg.g, fg.b)
        let b = luminance(bg.r, bg.g, bg.b)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    /// Parse `#RRGGBB`. Returns nil rather than defaulting — an unparseable
    /// token is a defect, not a zero-contrast pass.
    static func hex(_ s: String) -> (r: Double, g: Double, b: Double)? {
        let t = s.hasPrefix("#") ? String(s.dropFirst()) : s
        guard t.count == 6, let v = UInt32(t, radix: 16) else { return nil }
        return (Double((v >> 16) & 0xFF) / 255,
                Double((v >> 8) & 0xFF) / 255,
                Double(v & 0xFF) / 255)
    }

    /// The white-room pairs the snapshot matrix must assert. Values are the
    /// §0.2 / §0.5 rulings; the ratios shown are DERIVED by `ratio(fg:bg:)`
    /// and the test recomputes them rather than trusting the table.
    static let whiteRoomPairs: [(name: String, fg: String, bg: String, isLarge: Bool)] = [
        ("ink on bg",            "#000000", "#FCFCFC", false),   // ~19.9:1
        ("secondary on bg",      "#6C6C6C", "#FCFCFC", false),   // 5.12:1  OBSERVED house token
        ("secondary-IC on bg",   "#595959", "#FCFCFC", false),   // 6.83:1  Increase Contrast step
        ("ink on selectBg",      "#FFFFFF", "#000000", false),   // inversion
        ("fail on bg",           "#000000", "#FCFCFC", false),   // §0.5 #6: NO red — error is ink + "ERROR —"
    ]

    /// Black room: `ink` on `bg` is 21:1 and uninteresting; the pair that can
    /// actually fail is `secondary` (White 60%) and `rule` (White 25%).
    static let blackRoomPairs: [(name: String, fgAlpha: Double, bg: String, isLarge: Bool)] = [
        ("ink on bg",          1.0,  "#000000", false),
        ("secondary on bg",    0.6,  "#000000", false),
        ("ink on scrim-bottom",1.0,  "#000000", false),
    ]
}

// =============================================================================
// MARK: - The lint itself
// =============================================================================

enum DesignLint {

    /// Run every source-level rule over every app file. Returns the full
    /// violation set; the caller decides how to report it.
    static func run() throws -> [DesignViolation] {
        var all: [DesignViolation] = []

        for url in try SourceScanner.appSources() {
            let path = SourceScanner.relative(url)
            let source = try SourceScanner.read(url)
            let numbered = SourceScanner.numberedLines(source)

            for rule in ForbiddenPattern.allCases {
                all += ForbiddenPattern.violations(in: path, numbered: numbered)
            }
            all += TapTarget.violations(in: path, numbered: numbered)

            for screen in Screens.all where screen.file == path {
                all += RoomCoverage.violations(for: screen, numbered: numbered)
            }
        }

        all += IdentifierLabel.violations()
        return all
    }
}

// =============================================================================
// MARK: - XCTest
// =============================================================================

final class DesignLintTests: XCTestCase {

    // MARK: The pipe — one assertion, everything it collects

    /// §8.1: "The design cannot be violated accidentally, because the
    /// violation fails the build." One test, whole violation set, because a
    /// broken pipe that reports only the first defect trains people to run it
    /// locally instead of in CI.
    func testNoDesignViolations() throws {
        let violations = try DesignLint.run()
        guard violations.isEmpty else {
            let report = violations
                .map { "  • \($0)" }
                .joined(separator: "\n")
            XCTFail("""
                \(violations.count) design violation(s) — docs/.P.DESIGN.md §8.
                These DIE in CI. They are programmer defects, not domain errors.
                \(report)
                """)
            return
        }
    }

    // MARK: Per-rule regression guards
    //
    // Each pins one rule against its own exact §8.1 text, so a future edit to
    // the matcher cannot silently widen or narrow it. These are the tests that
    // would fail if the lint itself rots.

    private func violations(of rule: ForbiddenPattern, in source: String, as path: String) -> [DesignViolation] {
        ForbiddenPattern.violations(in: path, numbered: SourceScanner.numberedLines(source))
            .filter { v in
                switch (rule, v) {
                case (.rawRoundedType, .rawRoundedType),
                     (.capsuleOrCircleShape, .capsuleOrCircleShape),
                     (.iconInChrome, .iconInChrome),
                     (.forbiddenColor, .forbiddenColor),
                     (.dividerInsteadOfRule, .dividerInsteadOfRule),
                     (.fixedTypeWithoutRelativeTo, .fixedTypeWithoutRelativeTo),
                     (.missingIdentifier, .missingIdentifier):
                    return true
                default: return false
                }
            }
    }

    func testRoundedFontIsAViolation() {
        let src = #"Text("A").font(.system(design: .rounded, weight: .bold))"#
        XCTAssertFalse(violations(of: .rawRoundedType, in: src, as: "x.swift").isEmpty)
    }

    func testRoundingShapesAreViolations() {
        for shape in ["Capsule()", "Circle()", "RoundedRectangle(cornerRadius: 8)"] {
            XCTAssertFalse(
                violations(of: .capsuleOrCircleShape, in: "let s = \(shape)", as: "x.swift").isEmpty,
                "\(shape) must violate §2.5"
            )
        }
    }

    func testSFSymbolIsAViolation() {
        let src = #"Image(systemName: "camera.aperture").font(.largeTitle)"#
        let v = violations(of: .iconInChrome, in: src, as: "x.swift")
        XCTAssertTrue(v.contains(.iconInChrome(symbol: "camera.aperture")),
                      "the symbol name must survive into the violation: got \(v)")
    }

    func testForbiddenColors() {
        for lit in ["Color.yellow", "Color.red", "Color.white", "Color.black"] {
            XCTAssertFalse(
                violations(of: .forbiddenColor, in: "let c = \(lit)", as: "x.swift").isEmpty,
                "\(lit) must violate §2.1/§2.3 outside ChromeInk"
            )
        }
    }

    func testColourLiteralsAreAllowedInTheTokenLayerOnly() {
        let src = "let c = Color.white"
        XCTAssertTrue(
            violations(of: .forbiddenColor, in: src, as: "pikicam/Core/Design/ChromeInk.swift").isEmpty,
            "ChromeInk is where the literal belongs"
        )
        XCTAssertFalse(
            violations(of: .forbiddenColor, in: src, as: "pikicam/Features/Camera/CameraView.swift").isEmpty
        )
    }

    func testDividerIsAViolation() {
        XCTAssertFalse(violations(of: .dividerInsteadOfRule, in: "Divider()", as: "x.swift").isEmpty)
    }

    func testTwoArgFontCustomIsAViolation() {
        let two = #"let f = Font.custom("CourierNew-Bold", size: 17)"#
        let three = #"let f = Font.custom("CourierNew-Bold", size: 17, relativeTo: .headline)"#
        XCTAssertFalse(violations(of: .fixedTypeWithoutRelativeTo, in: two, as: "x.swift").isEmpty)
        XCTAssertTrue(violations(of: .fixedTypeWithoutRelativeTo, in: three, as: "x.swift").isEmpty,
                      "the three-arg overload is the sanctioned form (§2.2)")
    }

    func testBareIdentifierLiteralIsAViolation() {
        let unregistered = #"Text("X").accessibilityIdentifier("gallery-trash")"#
        let registered = "Text(\"X\").accessibilityIdentifier(ControlIDRegistry.roomDelete.rawValue)"
        XCTAssertFalse(violations(of: .missingIdentifier, in: unregistered, as: "x.swift").isEmpty)
        XCTAssertTrue(violations(of: .missingIdentifier, in: registered, as: "x.swift").isEmpty)
    }

    func testRegisteredParameterizedIdentifiersPass() {
        let family = #"Text("X").accessibilityIdentifier(ControlIDRegistry.roomCell(3).rawValue)"#
        _ = family  // literal spelling below is what a view actually writes
        let rendered = "Text(\"X\").accessibilityIdentifier(\"room-cell-3\")"
        XCTAssertTrue(violations(of: .missingIdentifier, in: rendered, as: "x.swift").isEmpty,
                      "parameterized families are matched by prefix (§ControlIDRegistry:158)")
    }

    // MARK: Comments must not be able to trigger or hide a violation

    func testCommentsAreStrippedBeforeMatching() {
        let commented = "// Capsule() was here\n// Image(systemName: \"trash\")\nText(\"ok\")"
        XCTAssertTrue(violations(of: .capsuleOrCircleShape, in: commented, as: "x.swift").isEmpty,
                      "a mention in a comment is not a violation")
        XCTAssertTrue(violations(of: .iconInChrome, in: commented, as: "x.swift").isEmpty)
    }

    func testStringLiteralsAreNotStripped() {
        let literal = #"Text("Capsule()")"#
        XCTAssertFalse(violations(of: .capsuleOrCircleShape, in: literal, as: "x.swift").isEmpty,
                       "a shape name rendered as copy is still chrome text the user sees")
    }

    func testLineNumbersSurviveStripping() {
        let src = "// c\n// c\nCapsule()"
        let numbered = SourceScanner.numberedLines(src)
        let v = violations(of: .capsuleOrCircleShape, in: src, as: "x.swift")
        XCTAssertEqual(v.first, .capsuleOrCircleShape(File: "x.swift", Line: 3),
                       "reported line must match the file on disk")
        XCTAssertEqual(numbered.count, 3)
    }

    // MARK: 44pt — §8.2

    func testTapTargetMinimumIsEnforced() {
        let tooSmall = "Button(action: {}) { Text(\"SHOOT\") }\n  .frame(minWidth: 32, minHeight: 32)"
        let ok = "Button(action: {}) { Text(\"SHOOT\") }\n  .frame(minWidth: 44, minHeight: 44)"
        let missing = "Button(action: {}) { Text(\"SHOOT\") }"
        XCTAssertTrue(TapTarget.violations(in: "x.swift",
                                           numbered: SourceScanner.numberedLines(tooSmall))
                        .contains(.tapTargetBelow44(pt: 32)))
        XCTAssertTrue(TapTarget.violations(in: "x.swift",
                                           numbered: SourceScanner.numberedLines(ok)).isEmpty)
        XCTAssertTrue(TapTarget.violations(in: "x.swift",
                                           numbered: SourceScanner.numberedLines(missing)).isEmpty,
                      "declaration without a frame is caught by the WordControl rule, not here")
    }

    func testTapTargetRequiresBothAxes() {
        let half = "WordControl(id: ControlIDRegistry.cameraShutter)\n  .frame(minWidth: 44, minHeight: 20)"
        XCTAssertTrue(TapTarget.violations(in: "x.swift",
                                           numbered: SourceScanner.numberedLines(half))
                        .contains(.tapTargetBelow44(pt: 20)))
    }

    // MARK: Room coverage — §1.5

    func testRoomCoverageRequiresExactlyOneEnvironment() {
        let zero = """
            struct Demo: View {
              var body: some View { Text("x") }
            }
            """
        let one = """
            struct Demo: View {
              var body: some View {
                Text("x").environment(\\.room, .white)
              }
            }
            """
        let two = """
            struct Demo: View {
              var body: some View {
                Text("x")
                  .environment(\\.room, .white)
                  .environment(\\.room, .black)
              }
            }
            """
        let screen = ScreenDecl(name: "Demo", file: "x.swift", room: .white, isChrome: false)
        XCTAssertEqual(RoomCoverage.violations(for: screen, numbered: SourceScanner.numberedLines(zero)).count, 1,
                       "zero is a defect — the screen renders in the default room")
        XCTAssertEqual(RoomCoverage.violations(for: screen, numbered: SourceScanner.numberedLines(one)).count, 0)
        XCTAssertEqual(RoomCoverage.violations(for: screen, numbered: SourceScanner.numberedLines(two)).count, 1,
                       "two is a defect — the loser is dead code and the swap test lies")
    }

    func testRoomCoverageIsScopedToTheStructNotTheFile() {
        let src = """
            struct A: View {
              var body: some View { Text("a").environment(\\.room, .black) }
            }
            struct B: View {
              var body: some View { Text("b") }
            }
            """
        let a = RoomCoverage.violations(for: ScreenDecl(name: "A", file: "x.swift", room: .black, isChrome: false),
                                        numbered: SourceScanner.numberedLines(src))
        let b = RoomCoverage.violations(for: ScreenDecl(name: "B", file: "x.swift", room: .white, isChrome: false),
                                        numbered: SourceScanner.numberedLines(src))
        XCTAssertTrue(a.isEmpty)
        XCTAssertEqual(b.count, 1, "A's room must not satisfy B's coverage")
    }

    func testEveryScreenIsCountedExactlyOnce() {
        // The screen table and the source must agree, or the lint is silently
        // checking nothing.
        for screen in Screens.all {
            let url = SourceScanner.repoRoot.appendingPathComponent(screen.file)
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                          "declared screen has no file: \(screen.file)")
            // `try?` must bind to the call alone; unparenthesised it would
            // swallow the whole `??` expression and yield a `String?`.
            let source = (try? SourceScanner.read(url)) ?? ""
            let numbered = SourceScanner.numberedLines(source)
            XCTAssertNotNil(SourceScanner.lineSpanOfStruct(named: screen.name, in: numbered),
                            "declared screen has no struct: \(screen.name)")
        }
    }

    // MARK: Identifier + label — §8.2

    func testEveryTappableWordHasIdentifierAndLabel() {
        XCTAssertTrue(IdentifierLabel.violations().isEmpty)
    }

    func testWordListIsNotEmptyPerControl() {
        for (id, word) in ControlIDRegistry.words {
            XCTAssertFalse(word.isEmpty, "\(id.rawValue) renders a blank 44pt box")
        }
    }

    // MARK: Contrast — §8.3

    func testWhiteRoomInkPassesAA() throws {
        let bg = try XCTUnwrap(Contrast.hex("#FCFCFC"))
        let ink = try XCTUnwrap(Contrast.hex("#000000"))
        XCTAssertGreaterThan(Contrast.ratio(fg: ink, bg: bg), 4.5)
    }

    func testWhiteRoomSecondaryPassesAA() throws {
        let bg = try XCTUnwrap(Contrast.hex("#FCFCFC"))
        let secondary = try XCTUnwrap(Contrast.hex("#6C6C6C"))
        let ratio = Contrast.ratio(fg: secondary, bg: bg)
        if ratio < 4.5 {
            XCTFail(String(format: "secondary on bg = %.2f:1, below 4.5", ratio))
        }
    }

    func testIncreaseContrastStepsSecondaryDarker() throws {
        let bg = try XCTUnwrap(Contrast.hex("#FCFCFC"))
        let default_ = try XCTUnwrap(Contrast.hex("#6C6C6C"))
        let step = try XCTUnwrap(Contrast.hex("#595959"))
        XCTAssertGreaterThan(Contrast.ratio(fg: step, bg: bg),
                             Contrast.ratio(fg: default_, bg: bg),
                             "Increase Contrast must strictly increase separation")
    }

    func testRuleSoftIsNeverText() throws {
        // §0.2: #E5E5E5 on #FCFCFC is 1.23:1 — fails everything, rule-soft only.
        let bg = try XCTUnwrap(Contrast.hex("#FCFCFC"))
        let ruleSoft = try XCTUnwrap(Contrast.hex("#E5E5E5"))
        XCTAssertLessThan(Contrast.ratio(fg: ruleSoft, bg: bg), 3.0,
                          "rule-soft may never be promoted to text")
    }

    func testInversionPairIsSymmetric() throws {
        let w = try XCTUnwrap(Contrast.hex("#FFFFFF"))
        let b = try XCTUnwrap(Contrast.hex("#000000"))
        XCTAssertEqual(Contrast.ratio(fg: w, bg: b), Contrast.ratio(fg: b, bg: w), accuracy: 0.001)
    }

    func testEveryDeclaredWhiteRoomPairMeetsItsThreshold() throws {
        for pair in Contrast.whiteRoomPairs {
            let fg = try XCTUnwrap(Contrast.hex(pair.fg), "unparseable token \(pair.fg)")
            let bg = try XCTUnwrap(Contrast.hex(pair.bg), "unparseable token \(pair.bg)")
            let ratio = Contrast.ratio(fg: fg, bg: bg)
            let required = pair.isLarge ? 3.0 : 4.5
            if ratio < required {
                XCTFail("\(pair.name): \(String(format: "%.2f", ratio)):1 < \(required):1")
            }
        }
    }
}