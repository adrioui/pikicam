import AVFoundation
import AVKit
import CoreMedia

enum VideoProbes {
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
                formats.append(
                    .dict([
                        "dims": "\(fd.width)x\(fd.height)",
                        "fpsMax": fpsMax,
                        "fpsMin": fpsMin,
                        "videoHDR": format.isVideoHDRSupported,
                        "binned": format.isVideoBinned,
                    ]))
            }
            deviceOut.append(
                .dictionary([
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

    static func videoFormatSummary(_ format: AVCaptureDevice.Format) -> JSONValue {
        let fd = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        var fpsMax = 0.0
        var fpsMin = 0.0
        for range in format.videoSupportedFrameRateRanges {
            fpsMax = max(fpsMax, range.maxFrameRate)
            if fpsMin == 0 { fpsMin = range.minFrameRate }
            fpsMin = min(fpsMin, range.minFrameRate)
        }
        return .dict([
            "dims": "\(fd.width)x\(fd.height)",
            "fpsMax": fpsMax,
            "fpsMin": fpsMin,
            "videoHDR": format.isVideoHDRSupported,
            "binned": format.isVideoBinned,
        ])
    }

    static func proResWriterProbe() -> JSONValue {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent("prores-probe.mov")
        try? FileManager.default.removeItem(at: url)
        do {
            let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
            let input = AVAssetWriterInput(
                mediaType: .video,
                outputSettings: [
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
