// periphery:ignore
import Foundation

public struct Provenance: Codable, Hashable, Sendable {
    public var deviceUniqueID: String
    public var deviceType: String
    public var lensKind: LensKind
    public var lensAperture: Double
    public var activeFormatDescription: String
    public var bayerFormatFourCC: String
    public var rawWidth: Int
    public var rawHeight: Int
    public var iso: Double
    public var exposureDuration: Double
    public var lensPosition: Double
    public var whiteBalanceGains: [Double]
    public var whiteBalanceTemperature: Double
    public var whiteBalanceTint: Double
    public var exposureModeWasManual: Bool
    public var determinism: DeviceDeterminism
    public var zeroShutterLag: Bool
    public var iOSVersion: String
    public var appVersion: String
    public var capturedAt: Date

    public init(
        deviceUniqueID: String,
        deviceType: String,
        lensKind: LensKind,
        lensAperture: Double,
        activeFormatDescription: String,
        bayerFormatFourCC: String,
        rawWidth: Int,
        rawHeight: Int,
        iso: Double,
        exposureDuration: Double,
        lensPosition: Double,
        whiteBalanceGains: [Double],
        whiteBalanceTemperature: Double,
        whiteBalanceTint: Double,
        exposureModeWasManual: Bool,
        determinism: DeviceDeterminism,
        zeroShutterLag: Bool,
        iOSVersion: String,
        appVersion: String,
        capturedAt: Date
    ) {
        self.deviceUniqueID = deviceUniqueID
        self.deviceType = deviceType
        self.lensKind = lensKind
        self.lensAperture = lensAperture
        self.activeFormatDescription = activeFormatDescription
        self.bayerFormatFourCC = bayerFormatFourCC
        self.rawWidth = rawWidth
        self.rawHeight = rawHeight
        self.iso = iso
        self.exposureDuration = exposureDuration
        self.lensPosition = lensPosition
        self.whiteBalanceGains = whiteBalanceGains
        self.whiteBalanceTemperature = whiteBalanceTemperature
        self.whiteBalanceTint = whiteBalanceTint
        self.exposureModeWasManual = exposureModeWasManual
        self.determinism = determinism
        self.zeroShutterLag = zeroShutterLag
        self.iOSVersion = iOSVersion
        self.appVersion = appVersion
        self.capturedAt = capturedAt
    }
}
