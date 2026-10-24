// periphery:ignore
import CoreGraphics
import Foundation

public struct CameraSettings: Hashable, Sendable {
    public var lens: LensKind
    public var exposure: ExposureMode
    public var whiteBalance: WhiteBalanceMode
    public var focus: FocusMode
    public var light: LightMode
    public var aspect: Aspect
    public var crop: CGFloat
    public var timer: TimerDuration

    public init(
        lens: LensKind,
        exposure: ExposureMode,
        whiteBalance: WhiteBalanceMode,
        focus: FocusMode,
        light: LightMode,
        aspect: Aspect,
        crop: CGFloat,
        timer: TimerDuration
    ) {
        self.lens = lens
        self.exposure = exposure
        self.whiteBalance = whiteBalance
        self.focus = focus
        self.light = light
        self.aspect = aspect
        self.crop = crop
        self.timer = timer
    }

    public static func standard(lens: LensKind) -> CameraSettings {
        CameraSettings(
            lens: lens,
            exposure: .auto(bias: EV(0)),
            whiteBalance: .auto,
            focus: .continuousAuto,
            light: .off,
            aspect: .native,
            crop: 1,
            timer: .off
        )
    }
}

public enum TimerDuration: Int, Hashable, Sendable, CaseIterable {
    case off = 0
    case three = 3
    case ten = 10
}

public enum Aspect: String, Hashable, Codable, Sendable, CaseIterable {
    case native
    case fourThirds
    case square
    case sixteenNines

    public var label: String {
        switch self {
        case .native: return "NATIVE"
        case .fourThirds: return "4:3"
        case .square: return "1:1"
        case .sixteenNines: return "16:9"
        }
    }
}
