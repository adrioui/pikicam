import AVFoundation
import Foundation

enum PhotoBoundary {
    enum Rejection: Error, Equatable, Sendable {
        case notRaw
        case wrongPixelFormat(String)
        case unexpectedResolvedSettings(String)
        case noFileData
        case notADNG
    }

    static func validate(_ photo: AVCapturePhoto, requestedFormat: BayerFormat) throws(Rejection) -> RawCapture {
        guard photo.isRawPhoto else {
            throw .notRaw
        }
        if let buffer = photo.pixelBuffer {
            let actual = CVPixelBufferGetPixelFormatType(buffer)
            guard actual == requestedFormat.osType else {
                throw .wrongPixelFormat(fourCC(actual))
            }
        }
        let resolved = photo.resolvedSettings
        guard resolved.expectedPhotoCount == 1 else {
            throw .unexpectedResolvedSettings("expectedPhotoCount \(resolved.expectedPhotoCount)")
        }
        guard resolved.rawPhotoDimensions.width > 0, resolved.rawPhotoDimensions.height > 0 else {
            throw .unexpectedResolvedSettings("rawPhotoDimensions zero")
        }
        guard let data = photo.fileDataRepresentation() else {
            throw .noFileData
        }
        guard isTIFF(data) else {
            throw .notADNG
        }
        guard rawIFDPhotometric(data) != .linearRawLike else {
            throw .notADNG
        }
        return makeCapture(data: data, photo: photo, requestedFormat: requestedFormat)
    }

    static func makeCapture(data: Data, photo: AVCapturePhoto, requestedFormat: BayerFormat) -> RawCapture {
        RawCapture(
            id: CaptureID(),
            dng: data,
            provenance: Provenance(
                deviceUniqueID: "",
                deviceType: "",
                lensKind: .wide,
                lensAperture: 0,
                activeFormatDescription: "",
                bayerFormatFourCC: requestedFormat.fourCC,
                rawWidth: Int(photo.resolvedSettings.rawPhotoDimensions.width),
                rawHeight: Int(photo.resolvedSettings.rawPhotoDimensions.height),
                iso: 0,
                exposureDuration: 0,
                lensPosition: 0,
                whiteBalanceGains: [],
                whiteBalanceTemperature: 0,
                whiteBalanceTint: 0,
                exposureModeWasManual: false,
                determinism: DeviceDeterminism(
                    geometricDistortionCorrection: .off,
                    centerStage: .notSupported,
                    videoHDR: .off,
                    lowLightBoost: .notSupported,
                    colorSpace: ""
                ),
                zeroShutterLag: false,
                iOSVersion: "",
                appVersion: "",
                capturedAt: Date()
            )
        )
    }

    enum Photometric: UInt16 {
        case cfa = 32803
        case linearRawLike = 34892
    }

    static func isTIFF(_ data: Data) -> Bool {
        guard data.count >= 4 else { return false }
        let head = [UInt8](data.prefix(4))
        let littleEndian = head == [0x49, 0x49, 0x2A, 0x00]
        let bigEndian = head == [0x4D, 0x4D, 0x00, 0x2A]
        return littleEndian || bigEndian
    }

    static func rawIFDPhotometric(_ data: Data) -> Photometric? {
        guard let header = TIFFHeader(data) else { return nil }
        var photometric: Photometric?
        for ifdOffset in header.ifd0SubIFDs {
            if let value = subIFDPhotometric(data, header: header, offset: ifdOffset) {
                photometric = value
            }
        }
        return photometric
    }

    private static func subIFDPhotometric(_ data: Data, header: TIFFHeader, offset: UInt32) -> Photometric? {
        guard let count = header.readUInt16(data, offset: offset) else { return nil }
        var isRaw = false
        var photometric: Photometric?
        for entry in 0..<Int(count) {
            let entryOffset = offset + 2 + UInt32(entry) * 12
            guard let tag = header.readUInt16(data, offset: entryOffset),
                let value = header.readUInt16(data, offset: entryOffset + 8)
            else { continue }
            if tag == 0x0106, value == Photometric.cfa.rawValue {
                isRaw = true
                photometric = .cfa
            }
            if tag == 0x0106, value == Photometric.linearRawLike.rawValue {
                isRaw = true
                photometric = .linearRawLike
            }
        }
        return isRaw ? (photometric ?? .cfa) : nil
    }

    struct TIFFHeader {
        let littleEndian: Bool
        let ifd0SubIFDs: [UInt32]

        init?(_ data: Data) {
            guard data.count >= 8 else { return nil }
            let head = [UInt8](data.prefix(2))
            if head == [0x49, 0x49] {
                littleEndian = true
            } else if head == [0x4D, 0x4D] {
                littleEndian = false
            } else {
                return nil
            }
            let ifd0 = readUInt32(data, offset: 4) ?? 0
            guard let entryCount = readUInt16(data, offset: ifd0) else { return nil }
            var subIFDs: [UInt32] = []
            for entry in 0..<Int(entryCount) {
                let entryOffset = ifd0 + 2 + UInt32(entry) * 12
                guard let tag = readUInt16(data, offset: entryOffset), tag == 0x014A,
                    let value = readUInt32(data, offset: entryOffset + 8)
                else { continue }
                subIFDs.append(value)
            }
            ifd0SubIFDs = subIFDs
        }

        func readUInt16(_ data: Data, offset: UInt32) -> UInt16? {
            let index = Int(offset)
            guard index + 2 <= data.count else { return nil }
            return littleEndian
                ? data[index] | (UInt16(data[index + 1]) << 8)
                : (UInt16(data[index]) << 8) | UInt16(data[index + 1])
        }

        func readUInt32(_ data: Data, offset: UInt32) -> UInt32? {
            let index = Int(offset)
            guard index + 4 <= data.count else { return nil }
            let bytes = (0..<4).map { data[index + $0] }
            return littleEndian
                ? UInt32(bytes[0]) | (UInt32(bytes[1]) << 8) | (UInt32(bytes[2]) << 16) | (UInt32(bytes[3]) << 24)
                : (UInt32(bytes[0]) << 24) | (UInt32(bytes[1]) << 16) | (UInt32(bytes[2]) << 8) | UInt32(bytes[3])
        }
    }

    static func fourCC(_ code: OSType) -> String {
        let bytes = [
            UInt8((code >> 24) & 0xFF), UInt8((code >> 16) & 0xFF),
            UInt8((code >> 8) & 0xFF), UInt8(code & 0xFF),
        ]
        return String(bytes.map { Character(UnicodeScalar($0)) })
    }
}
