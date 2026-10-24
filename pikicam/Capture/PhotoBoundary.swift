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

    static func validate(_ photo: AVCapturePhoto, requestedFormat: BayerFormat) -> Result<RawCapture, Rejection> {
        if !photo.isRawPhoto {
            return .failure(.notRaw)
        }
        if let buffer = photo.pixelBuffer {
            let actual = CVPixelBufferGetPixelFormatType(buffer)
            if actual != requestedFormat.osType {
                return .failure(.wrongPixelFormat(fourCC(actual)))
            }
        }
        let resolved = photo.resolvedSettings
        if resolved.expectedPhotoCount != 1 {
            return .failure(.unexpectedResolvedSettings("expectedPhotoCount \(resolved.expectedPhotoCount)"))
        }
        if resolved.rawPhotoDimensions.width <= 0 || resolved.rawPhotoDimensions.height <= 0 {
            return .failure(.unexpectedResolvedSettings("rawPhotoDimensions zero"))
        }
        guard let data = photo.fileDataRepresentation() else {
            return .failure(.noFileData)
        }
        if !isTIFF(data) {
            return .failure(.notADNG)
        }
        if rawIFDPhotometric(data) == .linearRawLike {
            return .failure(.notADNG)
        }
        return .success(makeCapture(data: data, photo: photo, requestedFormat: requestedFormat))
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
        guard
            let count = TIFFHeader.readUInt16(data, offset: offset, littleEndian: header.littleEndian)
        else { return nil }
        var isRaw = false
        var photometric: Photometric?
        for entry in 0..<Int(count) {
            let entryOffset = offset + 2 + UInt32(entry) * 12
            guard
                let tag = TIFFHeader.readUInt16(data, offset: entryOffset, littleEndian: header.littleEndian),
                let value = TIFFHeader.readUInt16(data, offset: entryOffset + 8, littleEndian: header.littleEndian)
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
        let ifd0Offset: UInt32
        let ifd0SubIFDs: [UInt32]

        init?(_ data: Data) {
            guard data.count >= 8 else { return nil }
            let head = [UInt8](data.prefix(2))
            let endian: Bool
            if head == [0x49, 0x49] {
                endian = true
            } else if head == [0x4D, 0x4D] {
                endian = false
            } else {
                return nil
            }
            littleEndian = endian
            guard let ifd0 = Self.readUInt32(data, offset: 4, littleEndian: endian),
                let entryCount = Self.readUInt16(data, offset: ifd0, littleEndian: endian)
            else { return nil }
            ifd0Offset = ifd0
            var subIFDs: [UInt32] = []
            for entry in 0..<Int(entryCount) {
                let entryOffset = ifd0 + 2 + UInt32(entry) * 12
                guard
                    let tag = Self.readUInt16(data, offset: entryOffset, littleEndian: endian),
                    tag == 0x014A,
                    let valueType = Self.readUInt16(data, offset: entryOffset + 2, littleEndian: endian),
                    valueType == 4,
                    let valueCount = Self.readUInt32(data, offset: entryOffset + 4, littleEndian: endian),
                    let value = Self.readUInt32(data, offset: entryOffset + 8, littleEndian: endian)
                else { continue }
                if valueCount == 1 {
                    subIFDs.append(value)
                    continue
                }
                for index in 0..<Int(valueCount) {
                    let arrayOffset = value + UInt32(index) * 4
                    if let subOffset = Self.readUInt32(data, offset: arrayOffset, littleEndian: endian) {
                        subIFDs.append(subOffset)
                    }
                }
            }
            ifd0SubIFDs = subIFDs
        }

        static func readUInt16(_ data: Data, offset: UInt32, littleEndian: Bool) -> UInt16? {
            let index = Int(offset)
            guard index + 2 <= data.count else { return nil }
            let low = UInt16(data[index])
            let high = UInt16(data[index + 1])
            return littleEndian ? low | (high << 8) : (low << 8) | high
        }

        static func readUInt32(_ data: Data, offset: UInt32, littleEndian: Bool) -> UInt32? {
            let index = Int(offset)
            guard index + 4 <= data.count else { return nil }
            let b0 = UInt32(data[index])
            let b1 = UInt32(data[index + 1])
            let b2 = UInt32(data[index + 2])
            let b3 = UInt32(data[index + 3])
            let little = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
            let big = (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
            return littleEndian ? little : big
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

extension CaptureError {
    init(_ rejection: PhotoBoundary.Rejection) {
        switch rejection {
        case .notRaw:
            self = .notBayer(pixelFormat: "not raw")
        case .wrongPixelFormat(let format):
            self = .notBayer(pixelFormat: format)
        case .unexpectedResolvedSettings(let detail):
            self = .unexpectedResolvedSettings(detail)
        case .noFileData:
            self = .noFileData
        case .notADNG:
            self = .notADNG
        }
    }
}

extension Result {
    func unwrapError() throws(Error) -> Success {
        switch self {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
}
