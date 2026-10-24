import Foundation
import XCTest

@testable import pikicam

final class ContrastTests: XCTestCase {
    func testTextPairsMeetWCAG() {
        for pair in Contrast.textPairs {
            let ratio = Contrast.ratio(pair.foreground, pair.background)
            XCTAssertGreaterThanOrEqual(ratio, pair.minimum, "\(pair.name): \(ratio)")
        }
    }

    func testNonTextPairsMeetWCAG() {
        for pair in Contrast.nonTextPairs {
            let ratio = Contrast.ratio(pair.foreground, pair.background)
            XCTAssertGreaterThanOrEqual(ratio, pair.minimum, "\(pair.name): \(ratio)")
        }
    }

    func testStampBackingOverExtremeSurfaces() {
        let onWhite = Contrast.ratio(0xF4F3EF, 0xFFFFFF)
        let onBlack = Contrast.ratio(0xF4F3EF, 0x000000)
        XCTAssertLessThan(onWhite, 1.2, "muslin must be near-invisible on white — inverted-carbon stamp required")
        XCTAssertGreaterThanOrEqual(onBlack, 4.5)
    }
}

enum SourceScan {
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("pikicam")

    static func files() -> [URL] {
        guard let enumerator = FileManager.default.enumerator(atPath: root.path) else { return [] }
        var urls: [URL] = []
        for case let file as String in enumerator where file.hasSuffix(".swift") {
            urls.append(root.appendingPathComponent(file))
        }
        return urls
    }

    static func contents() -> [(url: URL, text: String)] {
        files().compactMap { url in
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            return (url, text)
        }
    }

    static func requireSources() throws -> [(url: URL, text: String)] {
        let sources = contents()
        if sources.isEmpty {
            throw XCTSkip("Source tree not present on device — enforced by the host CI job (documented skip class)")
        }
        return sources
    }
}

final class SourceScanTests: XCTestCase {
    static let bannedPatterns: [(String, String)] = [
        ("CIRAWFilter\\(imageData: *[A-Za-z_.\"(]", "1-arg CIRAWFilter(imageData:) binds the deprecated stub"),
        ("PHImageManager", "PHImageManager is banned; use PHAssetResourceManager via AssetBoundary"),
        ("photoQualityPrioritization *= *\\.(balanced|quality)", "RAW mandates .speed (AVCapturePhotoOutput.h:85)"),
        ("linearSpaceFilter", "custom kernels inside linearSpaceFilter are silently discarded"),
        ("responds\\(to:", "silent availability gating is banned; use typed availability"),
        ("supportedCameraModels", "gating on supportedCameraModels rejects valid files"),
        ("objc_setAssociatedObject", "associated objects banned; delegate keyed by uniqueID"),
        ("MPVolumeView", "volume-button capture hack banned; AVKit onCameraCaptureEvent only"),
        ("AVCaptureMovieFileOutput", "banned; two AVAssetWriter inputs are the video path"),
        ("try\\?", "try? is banned; use the typed error strategy"),
        ("TODO|FIXME|XXX", "no markers left in the tree"),
        ("PRO-RAW|REC\\.2020|Material Symbols", "false telemetry strings banned"),
        ("\\.preferredColorScheme\\(", "dark-only brand; no runtime scheme switching"),
    ]

    func testNoBannedConstructs() throws {
        let sources = try SourceScan.requireSources()
        for (url, text) in sources {
            for (pattern, reason) in Self.bannedPatterns {
                XCTAssertNil(
                    text.range(of: pattern, options: .regularExpression),
                    "\(reason) — \(url.lastPathComponent)"
                )
            }
        }
    }

    func testFontCustomOnlyInTypeDotSwift() throws {
        let sources = try SourceScan.requireSources()
        for (url, text) in sources where url.lastPathComponent != "Type.swift" {
            XCTAssertNil(
                text.range(of: "Font\\.custom", options: .regularExpression),
                "Font.custom outside Type.swift — \(url.lastPathComponent)"
            )
        }
    }

    func testDomainImportsOnlyFoundationAndCoreGraphics() throws {
        let domain = SourceScan.root.appendingPathComponent("Domain")
        guard let enumerator = FileManager.default.enumerator(atPath: domain.path) else {
            throw XCTSkip("Source tree not present on device — enforced by the host CI job")
        }
        var checked = 0
        for case let file as String in enumerator where file.hasSuffix(".swift") {
            let path = domain.appendingPathComponent(file).path
            guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
            for line in content.split(separator: "\n")
            where line.trimmingCharacters(in: .whitespaces).hasPrefix("import ") {
                let module = line.replacingOccurrences(of: "import", with: "").trimmingCharacters(in: .whitespaces)
                XCTAssertEqual(module, "Foundation", "Domain/\(file) imports \(module)")
            }
            checked += 1
        }
        XCTAssertGreaterThan(checked, 10)
    }

    func testFileLineBudget() throws {
        for (url, text) in try SourceScan.requireSources() {
            let lines = text.split(separator: "\n").count
            XCTAssertLessThanOrEqual(lines, 300, "\(url.lastPathComponent) has \(lines) lines")
        }
    }

    func testFunctionLineBudget() throws {
        for (url, text) in try SourceScan.requireSources() {
            let lines = text.split(separator: "\n").map(String.init)
            var depth = 0
            var functionStart: (line: Int, depth: Int)?
            for (index, line) in lines.enumerated() {
                let opens = line.reduce(0) { $0 + ($1 == "{" ? 1 : 0) }
                let closes = line.reduce(0) { $0 + ($1 == "}" ? 1 : 0) }
                if functionStart == nil, depth == 1, opens > 0, line.contains("func ") {
                    functionStart = (index, depth + opens)
                }
                depth += opens - closes
                if let start = functionStart, depth < start.depth - 1 {
                    let length = index - start.line
                    XCTAssertLessThanOrEqual(
                        length, 40, "function over 40 lines ending \(url.lastPathComponent):\(index)")
                    functionStart = nil
                }
            }
        }
    }
}
