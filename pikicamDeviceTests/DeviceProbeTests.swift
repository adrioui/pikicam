import XCTest

@testable import pikicam

final class DeviceProbeTests: XCTestCase {
    func testRearCamerasReportBayerRAWFormats() async {
        let types: [AVCaptureDevice.DeviceType] = [.builtInUltraWideCamera, .builtInWideAngleCamera]
        let session = AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: .video, position: .back)
        let devices = session.devices
        if devices.isEmpty {
            throw XCTSkip("No rear cameras on this hardware — run on the iPhone 12 mini")
        }
        let output = AVCapturePhotoOutput()
        let bayer = output.availableRawPhotoPixelFormatTypes.filter { AVCapturePhotoOutput.isBayerRAWPixelFormat($0) }
        if devices.allSatisfy({ !$0.hasFlash }) && bayer.isEmpty {
            throw XCTSkip("Device exposes no Bayer RAW — run on the iPhone 12 mini")
        }
        XCTAssertFalse(bayer.isEmpty, "Rear camera with flash must expose Bayer RAW formats")
    }
}
