// periphery:ignore
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

#if DEBUG

    actor FakeDeveloper: Developer {
        private let scenario: FakeScenario

        init(scenario: FakeScenario) {
            self.scenario = scenario
        }

        func image(
            _ dng: Data, look: LookParameters, geometry: FrameGeometry, target: PreviewTarget
        ) throws(DevelopError) -> DisplayImage {
            guard let cg = SolidImage.make(size: CGSize(width: 64, height: 48), tone: tone(for: look)) else {
                throw DevelopError.renderFailed
            }
            return DisplayImage(cgImage: cg, pixelSize: CGSize(width: 64, height: 48))
        }

        func export(_ dng: Data, look: LookParameters, geometry: FrameGeometry) throws(DevelopError) -> Rendition? {
            if scenario == .developFails {
                throw DevelopError.renderFailed
            }
            guard let cg = SolidImage.make(size: CGSize(width: 64, height: 48), tone: tone(for: look)),
                let data = SolidImage.heicData(from: cg)
            else {
                throw DevelopError.encodeFailed
            }
            return Rendition(heic: data, pixelSize: CGSize(width: 64, height: 48), recipeHash: "fake")
        }

        func inspect(_ dng: Data) throws(DevelopError) -> DNGFacts {
            DNGFacts(
                isTIFF: true,
                dngVersion: "1.4.0.0",
                photometricInterpretation: .cfa,
                hasCFATags: true,
                uniqueCameraModel: "fake",
                orientation: 1,
                baselineExposure: 0,
                asShotNeutral: [0.5, 1.0, 0.41],
                width: 4032,
                height: 3024
            )
        }

        private func tone(for look: LookParameters) -> UInt8 {
            UInt8(max(0, min(255, 128 + look.exposureEV * 40)))
        }
    }

    enum SolidImage {
        static func make(size: CGSize, tone: UInt8) -> CGImage? {
            let context = CGContext(
                data: nil, width: Int(size.width), height: Int(size.height),
                bitsPerComponent: 8, bytesPerRow: Int(size.width) * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
            guard let context else { return nil }
            context.setFillColor(
                CGColor(red: CGFloat(tone) / 255, green: CGFloat(tone) / 255, blue: CGFloat(tone) / 255, alpha: 1))
            context.fill(CGRect(origin: .zero, size: size))
            return context.makeImage()
        }

        static func heicData(from image: CGImage) -> Data? {
            let mutable = NSMutableData()
            guard
                let destination = CGImageDestinationCreateWithData(mutable, UTType.heic.identifier as CFString, 1, nil)
            else {
                return nil
            }
            CGImageDestinationAddImage(destination, image, nil)
            guard CGImageDestinationFinalize(destination) else { return nil }
            return mutable as Data
        }
    }

#endif
