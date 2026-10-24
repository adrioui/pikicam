// periphery:ignore
import CoreGraphics
import Foundation

public struct FrameGeometry: Hashable, Codable, Sendable {
    public let aspect: Aspect
    public let crop: CGFloat
    public let sensorWidth: Double
    public let sensorHeight: Double
    public let normalizedRect: CGRect

    public init(aspect: Aspect, crop: CGFloat, sensorWidth: Double, sensorHeight: Double) {
        self.aspect = aspect
        self.crop = crop.isNaN || crop.isInfinite ? 1 : crop
        self.sensorWidth = sensorWidth
        self.sensorHeight = sensorHeight

        let zoom = max(self.crop, 1)
        let cropped = CGRect(
            x: (1 - 1 / zoom) / 2,
            y: (1 - 1 / zoom) / 2,
            width: 1 / zoom,
            height: 1 / zoom
        )
        self.normalizedRect = Self.applyAspect(aspect, sensorWidth: sensorWidth, sensorHeight: sensorHeight)
            .intersection(cropped)
    }

    static func applyAspect(_ aspect: Aspect, sensorWidth: Double, sensorHeight: Double) -> CGRect {
        let sensorRatio = sensorWidth / sensorHeight
        let target: Double
        switch aspect {
        case .native: return CGRect(x: 0, y: 0, width: 1, height: 1)
        case .fourThirds: target = 4.0 / 3.0
        case .square: target = 1
        case .sixteenNines: target = 16.0 / 9.0
        }
        if sensorRatio > target {
            let width = target / sensorRatio
            return CGRect(x: (1 - width) / 2, y: 0, width: width, height: 1)
        } else {
            let height = sensorRatio / target
            return CGRect(x: 0, y: (1 - height) / 2, width: 1, height: height)
        }
    }

    public func pixelRect(for pixelWidth: Int, pixelHeight: Int) -> CGRect {
        let rect = CGRect(
            x: normalizedRect.origin.x * CGFloat(pixelWidth),
            y: normalizedRect.origin.y * CGFloat(pixelHeight),
            width: normalizedRect.size.width * CGFloat(pixelWidth),
            height: normalizedRect.size.height * CGFloat(pixelHeight)
        )
        return rect.integral
    }

    public var longEdgeFraction: Double {
        max(normalizedRect.width, normalizedRect.height)
    }
}

extension FrameGeometry {
    private enum CodingKeys: String, CodingKey {
        case aspect, crop, sensorWidth, sensorHeight
        case rectX, rectY, rectWidth, rectHeight
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        aspect = try container.decode(Aspect.self, forKey: .aspect)
        crop = try container.decode(CGFloat.self, forKey: .crop)
        sensorWidth = try container.decode(Double.self, forKey: .sensorWidth)
        sensorHeight = try container.decode(Double.self, forKey: .sensorHeight)
        let x = try container.decode(Double.self, forKey: .rectX)
        let y = try container.decode(Double.self, forKey: .rectY)
        let width = try container.decode(Double.self, forKey: .rectWidth)
        let height = try container.decode(Double.self, forKey: .rectHeight)
        normalizedRect = CGRect(x: x, y: y, width: width, height: height)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(aspect, forKey: .aspect)
        try container.encode(crop, forKey: .crop)
        try container.encode(sensorWidth, forKey: .sensorWidth)
        try container.encode(sensorHeight, forKey: .sensorHeight)
        try container.encode(Double(normalizedRect.minX), forKey: .rectX)
        try container.encode(Double(normalizedRect.minY), forKey: .rectY)
        try container.encode(Double(normalizedRect.width), forKey: .rectWidth)
        try container.encode(Double(normalizedRect.height), forKey: .rectHeight)
    }
}
