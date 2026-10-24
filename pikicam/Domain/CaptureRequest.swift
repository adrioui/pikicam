// periphery:ignore
import CoreGraphics
import Foundation

public struct CaptureRequest: Hashable, Sendable {
    public let id: CaptureID
    public let geometry: FrameGeometry
    public let settings: CameraSettings

    public init(id: CaptureID, geometry: FrameGeometry, settings: CameraSettings) {
        self.id = id
        self.geometry = geometry
        self.settings = settings
    }
}
