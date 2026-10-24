import AVFoundation
import Foundation

enum DeviceConfiguration {
    static func apply(
        session: AVCaptureSession, device: AVCaptureDevice, output: AVCapturePhotoOutput
    ) throws(CaptureError) -> DeviceDeterminism {
        session.automaticallyConfiguresCaptureDeviceForWideColor = false
        do {
            try device.lockForConfiguration()
        } catch {
            throw .deviceLockFailed
        }
        defer { device.unlockForConfiguration() }

        applyDeviceLocks(device)
        device.activeColorSpace = .P3_D65
        device.videoZoomFactor = 1.0

        let centerStage: DeterminismValue
        if AVCaptureDevice.centerStageControlMode == .app, !AVCaptureDevice.isCenterStageEnabled {
            centerStage = .off
        } else if AVCaptureDevice.isCenterStageEnabled {
            centerStage = .on
        } else {
            centerStage = .notSupported
        }
        return DeviceDeterminism(
            geometricDistortionCorrection: device.isGeometricDistortionCorrectionSupported ? .off : .notSupported,
            centerStage: centerStage,
            videoHDR: device.isVideoHDREnabled ? .on : (device.activeFormat.isVideoHDRSupported ? .off : .notSupported),
            lowLightBoost: device.isLowLightBoostSupported ? .off : .notSupported,
            colorSpace: "\(device.activeColorSpace.rawValue)"
        )
    }

    private static func applyDeviceLocks(_ device: AVCaptureDevice) {
        if device.isGeometricDistortionCorrectionSupported {
            device.isGeometricDistortionCorrectionEnabled = false
        }
        if AVCaptureDevice.centerStageControlMode != .app {
            AVCaptureDevice.centerStageControlMode = .app
        }
        if AVCaptureDevice.isCenterStageEnabled {
            AVCaptureDevice.isCenterStageEnabled = false
        }
        if device.activeFormat.isVideoHDRSupported {
            device.automaticallyAdjustsVideoHDREnabled = false
            device.isVideoHDREnabled = false
        }
        if device.isLowLightBoostSupported {
            device.automaticallyEnablesLowLightBoostWhenAvailable = false
        }
        if device.activeFormat.isGlobalToneMappingSupported {
            device.isGlobalToneMappingEnabled = false
        }
    }

    static func largestPhotoDimensions(_ device: AVCaptureDevice) -> CMVideoDimensions {
        let dims = device.activeFormat.supportedMaxPhotoDimensions
        return dims.max { $0.width * $0.height < $1.width * $1.height } ?? CMVideoDimensions(width: 0, height: 0)
    }

    static func bayerFormat(for output: AVCapturePhotoOutput) -> BayerFormat? {
        let raw = output.availableRawPhotoPixelFormatTypes.first(where: AVCapturePhotoOutput.isBayerRAWPixelFormat)
        return raw.map { BayerFormat(osType: $0) }
    }
}
