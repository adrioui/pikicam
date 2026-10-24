import SwiftUI
import XCTest

@testable import pikicam

final class SkinTests: XCTestCase {
    static let appRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("pikicam")

    static func appSources() -> [(name: String, text: String)] {
        guard let walker = FileManager.default.enumerator(atPath: appRoot.path) else {
            return []
        }
        var files: [(String, String)] = []
        for case let path as String in walker where path.hasSuffix(".swift") {
            if let text = try? String(contentsOfFile: appRoot.appendingPathComponent(path).path, encoding: .utf8) {
                files.append((path, text))
            }
        }
        return files
    }

    func testNoColorsNamedOutsideSkin() throws {
        let sources = try XCTUnwrap(Self.appSources())
        for (name, text) in sources where !name.hasSuffix("Skin.swift") {
            XCTAssertNil(
                text.range(of: "Color\\(", options: .regularExpression),
                "\(name) names a color directly — colors live only in Skin.swift"
            )
            XCTAssertNil(
                text.range(of: "Color\\.", options: .regularExpression),
                "\(name) names a color directly — colors live only in Skin.swift"
            )
            XCTAssertNil(
                text.range(of: "UIColor\\.", options: .regularExpression),
                "\(name) names a UIKit color — colors live only in Skin.swift"
            )
        }
    }

    func testNoFontSizesOutsideScale() throws {
        let sources = try XCTUnwrap(Self.appSources())
        for (name, text) in sources where !name.hasSuffix("Skin.swift") {
            XCTAssertNil(
                text.range(of: "\\.system\\(size:", options: .regularExpression),
                "\(name) sets a raw font size — sizes live only in Skin.swift"
            )
            XCTAssertNil(
                text.range(of: "\\.font\\(\\.", options: .regularExpression),
                "\(name) uses a convenience font — fonts come from Skin.mono"
            )
        }
    }

    func testNoRadiusOrMotion() throws {
        let sources = try XCTUnwrap(Self.appSources())
        for (name, text) in sources {
            XCTAssertNil(
                text.range(of: "cornerRadius", options: .regularExpression),
                "\(name) sets a corner radius — the table says radius 0"
            )
            XCTAssertNil(
                text.range(of: "RoundedRectangle", options: .regularExpression),
                "\(name) rounds a rectangle — use Rectangle"
            )
            XCTAssertNil(
                text.range(of: "withAnimation|\\.animation\\(", options: .regularExpression),
                "\(name) animates — the table says motion 0 ms"
            )
        }
    }

    func testSkinScaleIsExactlyFourSizes() {
        XCTAssertEqual(Skin.Size.display.points, 34)
        XCTAssertEqual(Skin.Size.title.points, 17)
        XCTAssertEqual(Skin.Size.body.points, 13)
        XCTAssertEqual(Skin.Size.caption.points, 11)
    }

    func testContrastArithmetic() {
        func luminance(_ c: Color) -> CGFloat {
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            UIColor(c).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            func channel(_ value: CGFloat) -> CGFloat {
                value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
        }
        func ratio(_ a: Color, _ b: Color) -> CGFloat {
            let la = luminance(a)
            let lb = luminance(b)
            return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
        }
        XCTAssertGreaterThanOrEqual(ratio(Skin.Ink.white, Skin.Ink.black), 4.5)
        XCTAssertGreaterThanOrEqual(ratio(Skin.Ink.black, Skin.Ink.white), 4.5)
        XCTAssertGreaterThanOrEqual(ratio(Skin.Ink.rule, Skin.Ink.black), 3.0)
    }
}
