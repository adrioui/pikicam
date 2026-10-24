import AVFoundation
import AVKit
import CoreMedia

enum CameraProbes {
    static func fourCCString(_ code: FourCharCode) -> String {
        let c0 = Character(UnicodeScalar(UInt8((code >> 24) & 0xFF)))
        let c1 = Character(UnicodeScalar(UInt8((code >> 16) & 0xFF)))
        let c2 = Character(UnicodeScalar(UInt8((code >> 8) & 0xFF)))
        let c3 = Character(UnicodeScalar(UInt8(code & 0xFF)))
        return String([c0, c1, c2, c3])
    }

    private static func attachedOutput(for device: AVCaptureDevice) -> AVCapturePhotoOutput? {
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else { return nil }
        session.addInput(input)
        let output = AVCapturePhotoOutput()
        guard session.canAddOutput(output) else { return nil }
        session.addOutput(output)
        return output
    }

    static func attachedOutputProbe() -> JSONValue {
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        guard
            let device = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back
            ).devices.first,
            let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input)
        else {
            return .dict(["error": "attach failed"])
        }
        session.addInput(input)
        let output = AVCapturePhotoOutput()
        guard session.canAddOutput(output) else {
            return .dict(["error": "output failed"])
        }
        session.addOutput(output)
        session.startRunning()
        let data = outputProbe(output: output, device: device)
        session.stopRunning()
        return data
    }

    static func formatSummary(_ format: AVCaptureDevice.Format) -> JSONValue {
        let fd = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        var rates: [Double] = []
        for range in format.videoSupportedFrameRateRanges {
            rates.append(range.maxFrameRate)
        }
        return .dict([
            "dimensions": "\(fd.width)x\(fd.height)",
            "maxPhotoDimensionsCount": format.supportedMaxPhotoDimensions.count,
            "minISO": Double(format.minISO),
            "maxISO": Double(format.maxISO),
            "minExposureDuration": format.minExposureDuration.seconds,
            "maxExposureDuration": format.maxExposureDuration.seconds,
            "isVideoHDRSupported": format.isVideoHDRSupported,
            "isVideoBinned": format.isVideoBinned,
            "videoFieldOfView": Double(format.videoFieldOfView),
            "maxFrameRate": rates.max() ?? 0,
        ])
    }

    static func dumpDeviceCapabilities() -> JSONValue {
        let types: [AVCaptureDevice.DeviceType] = [
            .builtInUltraWideCamera, .builtInWideAngleCamera, .builtInTelephotoCamera,
        ]
        let session = AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: .video, position: .unspecified)
        var devices: [JSONValue] = []
        for device in session.devices {
            devices.append(deviceInfo(device))
        }
        return .dictionary(["devices": .array(devices)])
    }

    static func deviceInfo(_ device: AVCaptureDevice) -> JSONValue {
        var info = scalarDeviceInfo(device)
        info["formatsCount"] = .int(device.formats.count)
        info["formats"] = .array(device.formats.map { formatSummary($0) })
        return .dict(info)
    }

    private static func scalarDeviceInfo(_ device: AVCaptureDevice) -> [String: JSONValue] {
        let f = device.activeFormat
        let dims = CMVideoFormatDescriptionGetDimensions(f.formatDescription)

        let photoOutput = attachedOutput(for: device)
        let rawFormats = photoOutput?.availableRawPhotoPixelFormatTypes ?? []
        let bayer = rawFormats.filter { AVCapturePhotoOutput.isBayerRAWPixelFormat($0) }
        let proRAW = rawFormats.filter { AVCapturePhotoOutput.isAppleProRAWPixelFormat($0) }

        var maxDimsText = "none"
        var dimsCount = 0
        for d in f.supportedMaxPhotoDimensions {
            dimsCount += 1
            if maxDimsText == "none" {
                maxDimsText = "\(Int(d.width))x\(Int(d.height))"
            }
        }

        var flashModes: [String] = []
        if let photoOutput {
            for mode in photoOutput.supportedFlashModes {
                flashModes.append("\(mode.rawValue)")
            }
        }

        var info = basicDeviceInfo(device)
        info["supportedFlashModes"] = .array(flashModes.map { .string($0) })
        info["activeFormatFOV"] = .double(Double(f.videoFieldOfView))
        info["activeFormatDimensions"] = .string("\(dims.width)x\(dims.height)")
        info["activeFormatMaxPhotoDimensions"] = .string(maxDimsText)
        info["activeFormatMaxPhotoDimensionsCount"] = .int(dimsCount)
        info["activeFormatMinISO"] = .double(Double(f.minISO))
        info["activeFormatMaxISO"] = .double(Double(f.maxISO))
        info["activeFormatMinExposureDuration"] = .double(f.minExposureDuration.seconds)
        info["activeFormatMaxExposureDuration"] = .double(f.maxExposureDuration.seconds)
        info["availableRawPhotoPixelFormatTypes"] = .array(rawFormats.map { .string(fourCCString($0)) })
        info["bayerRAWFormats"] = .array(bayer.map { .string(fourCCString($0)) })
        info["appleProRAWFormats"] = .array(proRAW.map { .string(fourCCString($0)) })
        info.merge(determinismDeviceInfo(device, format: f), uniquingKeysWith: { _, new in new })
        return info
    }

    private static func basicDeviceInfo(_ device: AVCaptureDevice) -> [String: JSONValue] {
        [
            "uniqueID": .string(device.uniqueID),
            "deviceType": .string(device.deviceType.rawValue),
            "position": .string("\(device.position.rawValue)"),
            "modelID": .string(device.modelID),
            "hasFlash": .bool(device.hasFlash),
            "flashAvailable": .bool(device.isFlashAvailable),
            "hasTorch": .bool(device.hasTorch),
            "lensAperture": .double(Double(device.lensAperture)),
            "minAvailableVideoZoomFactor": .double(Double(device.minAvailableVideoZoomFactor)),
            "maxAvailableVideoZoomFactor": .double(Double(device.maxAvailableVideoZoomFactor)),
            "autoFocusRangeRestrictionSupported": .bool(device.isAutoFocusRangeRestrictionSupported),
            "lockFocusCustomLensPositionSupported": .bool(device.isLockingFocusWithCustomLensPositionSupported),
        ]
    }

    private static func determinismDeviceInfo(
        _ device: AVCaptureDevice, format f: AVCaptureDevice.Format
    ) -> [String: JSONValue] {
        [
            "gdcSupported": .bool(device.isGeometricDistortionCorrectionSupported),
            "gdcEnabled": .bool(device.isGeometricDistortionCorrectionEnabled),
            "centerStageControlMode": .string("\(AVCaptureDevice.centerStageControlMode.rawValue)"),
            "centerStageEnabled": .bool(AVCaptureDevice.isCenterStageEnabled),
            "autoVideoHDR": .bool(device.automaticallyAdjustsVideoHDREnabled),
            "videoHDREnabled": .bool(device.isVideoHDREnabled),
            "activeFormatVideoHDRSupported": .bool(f.isVideoHDRSupported),
            "lowLightBoostSupported": .bool(device.isLowLightBoostSupported),
            "autoLowLightBoost": .bool(device.automaticallyEnablesLowLightBoostWhenAvailable),
            "activeColorSpace": .string("\(device.activeColorSpace.rawValue)"),
            "globalToneMappingSupported": .bool(f.isGlobalToneMappingSupported),
            "globalToneMappingEnabled": .bool(device.isGlobalToneMappingEnabled),
        ]
    }

    static func rawBayerFormat(from output: AVCapturePhotoOutput) -> OSType? {
        let formats = output.availableRawPhotoPixelFormatTypes
        return formats.first(where: AVCapturePhotoOutput.isBayerRAWPixelFormat)
    }

    static func photoSettingsProbe() -> JSONValue {
        let bayer = kCVPixelFormatType_14Bayer_BGGR
        let settings = AVCapturePhotoSettings(rawPixelFormatType: bayer)
        var out: [String: JSONValue] = [:]
        out["pixelFormat"] = .string(fourCCString(bayer))
        out["isBayer"] = .bool(AVCapturePhotoOutput.isBayerRAWPixelFormat(bayer))
        out["isAppleProRAW"] = .bool(AVCapturePhotoOutput.isAppleProRAWPixelFormat(bayer))
        out["defaultPhotoQualityPrioritization"] = .string("\(settings.photoQualityPrioritization.rawValue)")
        out["defaultMaxPhotoDimensions"] = .string(
            "\(settings.maxPhotoDimensions.width)x\(settings.maxPhotoDimensions.height)")
        out["autoStillImageStabilization"] = .bool(settings.isAutoStillImageStabilizationEnabled)
        out["autoRedEyeReduction"] = .bool(settings.isAutoRedEyeReductionEnabled)
        out["autoContentAwareDistortionCorrection"] = .bool(settings.isAutoContentAwareDistortionCorrectionEnabled)
        out["autoVirtualDeviceFusion"] = .bool(settings.isAutoVirtualDeviceFusionEnabled)

        let speedEx = PIKExceptionCatcher.catchException { settings.photoQualityPrioritization = .speed }
        out["setSpeedAccepted"] = .bool(speedEx == nil)
        out["speedReadback"] = .string("\(settings.photoQualityPrioritization.rawValue)")

        let balancedEx = PIKExceptionCatcher.catchException { settings.photoQualityPrioritization = .balanced }
        out["setBalancedException"] = .string(exceptionName(balancedEx))
        if balancedEx == nil {
            out["balancedReadback"] = .string("\(settings.photoQualityPrioritization.rawValue)")
        }
        PIKExceptionCatcher.catchException { settings.photoQualityPrioritization = .speed }

        let qualityEx = PIKExceptionCatcher.catchException { settings.photoQualityPrioritization = .quality }
        out["setQualityException"] = .string(exceptionName(qualityEx))
        out["qualityExceptionReason"] = .string(qualityEx.map { $0.reason ?? "" } ?? "")
        out["readbackAfterQualityAttempt"] = .string("\(settings.photoQualityPrioritization.rawValue)")

        return .dict(out)
    }

    static func exceptionName(_ exception: NSException?) -> String {
        exception.map { "\($0.name)" } ?? ""
    }

    static func outputProbe(output: AVCapturePhotoOutput, device: AVCaptureDevice) -> JSONValue {
        let rawFormats = output.availableRawPhotoPixelFormatTypes
        let bayer = rawFormats.filter { AVCapturePhotoOutput.isBayerRAWPixelFormat($0) }
        let maxDims = output.maxPhotoDimensions
        var out: [String: JSONValue] = [:]
        out["availableRawPhotoPixelFormatTypes"] = .array(rawFormats.map { .string(fourCCString($0)) })
        out["bayerRAWFormats"] = .array(bayer.map { .string(fourCCString($0)) })
        out["maxPhotoQualityPrioritization"] = .string("\(output.maxPhotoQualityPrioritization.rawValue)")
        out["maxPhotoDimensions"] = .string("\(maxDims.width)x\(maxDims.height)")
        out["isZeroShutterLagSupported"] = .bool(output.isZeroShutterLagSupported)
        out["isZeroShutterLagEnabledDefault"] = .bool(output.isZeroShutterLagEnabled)
        out["isResponsiveCaptureSupported"] = .bool(output.isResponsiveCaptureSupported)
        out["isFastCapturePrioritizationSupported"] = .bool(output.isFastCapturePrioritizationEnabled)
        out["isAutoDeferredPhotoDeliveryEnabledDefault"] = .bool(output.isAutoDeferredPhotoDeliveryEnabled)
        out["isContentAwareDistortionCorrectionSupported"] = .bool(output.isContentAwareDistortionCorrectionSupported)
        out["virtualDeviceFusionSupported"] = .bool(output.isVirtualDeviceFusionSupported)
        out["livePhotoSupported"] = .bool(output.isLivePhotoCaptureSupported)
        out["stillImageStabilizationSupported"] = .bool(output.isStillImageStabilizationSupported)
        out["supportedFlashModes"] = .array(output.supportedFlashModes.map { .string("\($0.rawValue)") })
        out["deviceZoomFactor"] = .double(Double(device.videoZoomFactor))
        return .dict(out)
    }
}
