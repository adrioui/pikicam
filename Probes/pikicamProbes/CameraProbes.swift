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

    static func dumpDeviceCapabilities() -> JSONValue {
        let types: [AVCaptureDevice.DeviceType] = [
            .builtInUltraWideCamera, .builtInWideAngleCamera, .builtInTelephotoCamera,
        ]
        let session = AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: .video, position: .unspecified)
        var devices: [JSONValue] = []
        for device in session.devices {
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

            var formats: [JSONValue] = []
            for format in device.formats {
                let fd = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                var rates: [Double] = []
                for range in format.videoSupportedFrameRateRanges {
                    rates.append(range.maxFrameRate)
                }
                formats.append(.dict([
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
                ]))
            }

            var flashModes: [String] = []
            if let photoOutput {
                for mode in photoOutput.supportedFlashModes {
                    flashModes.append("\(mode.rawValue)")
                }
            }

            var info: [String: JSONValue] = [:]
            info["uniqueID"] = .string(device.uniqueID)
            info["deviceType"] = .string(device.deviceType.rawValue)
            info["position"] = .string("\(device.position.rawValue)")
            info["modelID"] = .string(device.modelID)
            info["hasFlash"] = .bool(device.hasFlash)
            info["flashAvailable"] = .bool(device.isFlashAvailable)
            info["hasTorch"] = .bool(device.hasTorch)
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
            info["gdcSupported"] = .bool(device.isGeometricDistortionCorrectionSupported)
            info["gdcEnabled"] = .bool(device.isGeometricDistortionCorrectionEnabled)
            info["centerStageControlMode"] = .string("\(AVCaptureDevice.centerStageControlMode.rawValue)")
            info["centerStageEnabled"] = .bool(AVCaptureDevice.isCenterStageEnabled)
            info["autoVideoHDR"] = .bool(device.automaticallyAdjustsVideoHDREnabled)
            info["videoHDREnabled"] = .bool(device.isVideoHDREnabled)
            info["activeFormatVideoHDRSupported"] = .bool(f.isVideoHDRSupported)
            info["lowLightBoostSupported"] = .bool(device.isLowLightBoostSupported)
            info["autoLowLightBoost"] = .bool(device.automaticallyEnablesLowLightBoostWhenAvailable)
            info["activeColorSpace"] = .string("\(device.activeColorSpace.rawValue)")
            info["globalToneMappingSupported"] = .bool(f.isGlobalToneMappingSupported)
            info["globalToneMappingEnabled"] = .bool(device.isGlobalToneMappingEnabled)
            info["autoFocusRangeRestrictionSupported"] = .bool(device.isAutoFocusRangeRestrictionSupported)
            info["lockFocusCustomLensPositionSupported"] = .bool(device.isLockingFocusWithCustomLensPositionSupported)
            info["lensAperture"] = .double(Double(device.lensAperture))
            info["minAvailableVideoZoomFactor"] = .double(Double(device.minAvailableVideoZoomFactor))
            info["maxAvailableVideoZoomFactor"] = .double(Double(device.maxAvailableVideoZoomFactor))
            info["formatsCount"] = .int(device.formats.count)
            info["formats"] = .array(formats)
            devices.append(.dict(info))
        }
        return .dictionary(["devices": .array(devices)])
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
        out["defaultMaxPhotoDimensions"] = .string("\(settings.maxPhotoDimensions.width)x\(settings.maxPhotoDimensions.height)")
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

    static func videoFormatsProbe() -> JSONValue {
        let types: [AVCaptureDevice.DeviceType] = [
            .builtInUltraWideCamera, .builtInWideAngleCamera, .builtInTelephotoCamera,
        ]
        let session = AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: .video, position: .back)
        var deviceOut: [JSONValue] = []
        for device in session.devices {
            var formats: [JSONValue] = []
            for format in device.formats {
                let fd = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                var fpsMax = 0.0
                var fpsMin = 0.0
                for range in format.videoSupportedFrameRateRanges {
                    fpsMax = max(fpsMax, range.maxFrameRate)
                    if fpsMin == 0 { fpsMin = range.minFrameRate }
                    fpsMin = min(fpsMin, range.minFrameRate)
                }
                formats.append(.dict([
                    "dims": "\(fd.width)x\(fd.height)",
                    "fpsMax": fpsMax,
                    "fpsMin": fpsMin,
                    "videoHDR": format.isVideoHDRSupported,
                    "binned": format.isVideoBinned,
                ]))
            }
            deviceOut.append(.dictionary([
                "uniqueID": .string(device.uniqueID),
                "formats": .array(formats),
                "activeIsVideoHDRSupported": .bool(device.activeFormat.isVideoHDRSupported),
            ]))
        }

        let proRes = proResWriterProbe()
        let hlgKey = AVVideoTransferFunction_ITU_R_2100_HLG
        return .dictionary([
            "devices": .array(deviceOut),
            "proResWriter": proRes,
            "hlgTransferFunctionKey": .string(hlgKey),
        ])
    }

    static func proResWriterProbe() -> JSONValue {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent("prores-probe.mov")
        try? FileManager.default.removeItem(at: url)
        do {
            let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.proRes422HQ,
                AVVideoWidthKey: 1920,
                AVVideoHeightKey: 1080,
            ])
            writer.add(input)
            return .dict(["writerCreated": true, "inputAccepted": true])
        } catch {
            return .dict(["writerCreated": false, "error": "\(error)"])
        }
    }
}
