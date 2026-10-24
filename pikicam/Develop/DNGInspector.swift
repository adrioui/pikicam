import CoreImage
import Foundation

enum DNGInspector {
    static func facts(from data: Data) -> DNGFacts? {
        guard PhotoBoundary.isTIFF(data), let header = PhotoBoundary.TIFFHeader(data) else { return nil }
        var facts = DNGFacts(
            isTIFF: true, dngVersion: nil, photometricInterpretation: nil, hasCFATags: false,
            uniqueCameraModel: nil, orientation: nil, baselineExposure: nil, asShotNeutral: nil,
            width: 0, height: 0
        )
        facts.dngVersion = dngVersion(data, header: header)
        facts.uniqueCameraModel = asciiTag(data, header: header, tag: 0xC614, ifd: .ifd0)
        facts.orientation = intTag(data, header: header, tag: 0x0112, ifd: .ifd0)
        facts.baselineExposure = rationalTag(data, header: header, tag: 0xC62A, ifd: .ifd0)
        facts.asShotNeutral = rationalTriple(data, header: header, tag: 0xC628, ifd: .ifd0)

        let ifd0Facts = ifd0RawFacts(data, header: header)
        if ifd0Facts.photometricInterpretation != nil {
            facts.photometricInterpretation = ifd0Facts.photometricInterpretation
            facts.hasCFATags = ifd0Facts.hasCFATags
            facts.width = ifd0Facts.width
            facts.height = ifd0Facts.height
            return facts
        }

        for offset in header.ifd0SubIFDs {
            let subFacts = subIFDFacts(data, header: header, offset: offset)
            if subFacts.photometricInterpretation == .cfa {
                facts.photometricInterpretation = .cfa
                facts.hasCFATags = subFacts.hasCFATags
                facts.width = subFacts.width
                facts.height = subFacts.height
                return facts
            }
            if subFacts.photometricInterpretation != nil {
                facts.photometricInterpretation = subFacts.photometricInterpretation
                facts.width = subFacts.width
                facts.height = subFacts.height
            }
        }
        return facts
    }

    private struct SubFacts {
        var photometricInterpretation: DNGFacts.Photometric?
        var hasCFATags = false
        var width = 0
        var height = 0
    }

    private static func subIFDFacts(_ data: Data, header: PhotoBoundary.TIFFHeader, offset: UInt32) -> SubFacts {
        var facts = SubFacts()
        guard
            let count = PhotoBoundary.TIFFHeader.readUInt16(data, offset: offset, littleEndian: header.littleEndian)
        else { return facts }
        for entry in 0..<Int(count) {
            let entryOffset = offset + 2 + UInt32(entry) * 12
            guard
                let tag = u16(data, header, entryOffset),
                let value = u16(data, header, entryOffset + 8)
            else { continue }
            if tag == 0x0106, value == 32803 {
                facts.photometricInterpretation = .cfa
            }
            if tag == 0x0106, value == 34892 {
                facts.photometricInterpretation = .linearRaw
            }
            if tag == 0x828D {
                facts.hasCFATags = true
            }
            if tag == 0x0100, let width = u32(data, header, entryOffset + 8) {
                facts.width = Int(width)
            }
            if tag == 0x0101, let height = u32(data, header, entryOffset + 8) {
                facts.height = Int(height)
            }
        }
        return facts
    }

    private static func ifd0RawFacts(_ data: Data, header: PhotoBoundary.TIFFHeader) -> SubFacts {
        var facts = SubFacts()
        guard
            let photometric = intTag(data, header: header, tag: 0x0106, ifd: .ifd0)
        else { return facts }
        if photometric == 32803 {
            facts.photometricInterpretation = .cfa
        }
        if photometric == 34892 {
            facts.photometricInterpretation = .linearRaw
        }
        facts.hasCFATags = intTag(data, header: header, tag: 0x828D, ifd: .ifd0) != nil
        facts.width = intTag(data, header: header, tag: 0x0100, ifd: .ifd0) ?? 0
        facts.height = intTag(data, header: header, tag: 0x0101, ifd: .ifd0) ?? 0
        return facts
    }

    private enum IFD {
        case ifd0
    }

    private struct IFDEntry {
        let type: UInt16
        let count: UInt32
        let valueOffset: UInt32
    }

    private static func u16(
        _ data: Data, _ header: PhotoBoundary.TIFFHeader, _ offset: UInt32
    ) -> UInt16? {
        PhotoBoundary.TIFFHeader.readUInt16(data, offset: offset, littleEndian: header.littleEndian)
    }

    private static func u32(
        _ data: Data, _ header: PhotoBoundary.TIFFHeader, _ offset: UInt32
    ) -> UInt32? {
        PhotoBoundary.TIFFHeader.readUInt32(data, offset: offset, littleEndian: header.littleEndian)
    }

    private static func entryValue(
        _ data: Data, header: PhotoBoundary.TIFFHeader, tag wanted: UInt16, ifd: IFD
    ) -> IFDEntry? {
        let ifdOffset = header.ifd0Offset
        guard let count = u16(data, header, ifdOffset) else { return nil }
        for entry in 0..<Int(count) {
            let entryOffset = ifdOffset + 2 + UInt32(entry) * 12
            guard
                let tag = u16(data, header, entryOffset),
                tag == wanted,
                let type = u16(data, header, entryOffset + 2),
                let valueCount = u32(data, header, entryOffset + 4)
            else { continue }
            let inline = typeSize(type) * Int(valueCount) <= 4
            let valueOffset: UInt32 = inline ? entryOffset + 8 : (u32(data, header, entryOffset + 8) ?? 0)
            return IFDEntry(type: type, count: valueCount, valueOffset: valueOffset)
        }
        return nil
    }

    private static func typeSize(_ type: UInt16) -> Int {
        switch type {
        case 1, 2, 6, 7: return 1
        case 3, 8: return 2
        case 4, 9, 11: return 4
        case 5, 10, 12: return 8
        default: return 1
        }
    }

    private static func dngVersion(_ data: Data, header: PhotoBoundary.TIFFHeader) -> String? {
        guard
            let entry = entryValue(data, header: header, tag: 0xC612, ifd: .ifd0),
            entry.type == 1,
            let b0 = u16(data, header, entry.valueOffset),
            let b1 = u16(data, header, entry.valueOffset + 1)
        else { return nil }
        return "\(b0).\(b1).0.0"
    }

    private static func asciiTag(_ data: Data, header: PhotoBoundary.TIFFHeader, tag: UInt16, ifd: IFD) -> String? {
        guard
            let entry = entryValue(data, header: header, tag: tag, ifd: ifd),
            entry.type == 2,
            Int(entry.valueOffset) + Int(entry.count) <= data.count
        else { return nil }
        let bytes = data.subdata(in: Int(entry.valueOffset)..<Int(entry.valueOffset) + Int(entry.count))
        return String(data: bytes, encoding: .utf8)?.trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
    }

    private static func intTag(_ data: Data, header: PhotoBoundary.TIFFHeader, tag: UInt16, ifd: IFD) -> Int? {
        guard let entry = entryValue(data, header: header, tag: tag, ifd: ifd) else { return nil }
        switch entry.type {
        case 3:
            return u16(data, header, entry.valueOffset).map(Int.init)
        case 4:
            return u32(data, header, entry.valueOffset).map(Int.init)
        default:
            return nil
        }
    }

    private static func rationalTag(_ data: Data, header: PhotoBoundary.TIFFHeader, tag: UInt16, ifd: IFD) -> Double? {
        guard
            let entry = entryValue(data, header: header, tag: tag, ifd: ifd),
            entry.type == 10 || entry.type == 5
        else { return nil }
        let signed = entry.type == 10
        let rawNumerator = u32(data, header, entry.valueOffset) ?? 0
        let rawDenominator = u32(data, header, entry.valueOffset + 4) ?? 1
        let numerator = Int32(bitPattern: rawNumerator)
        let denominator = Int32(bitPattern: rawDenominator)
        guard denominator != 0 else { return nil }
        if signed {
            return Double(numerator) / Double(denominator)
        }
        return Double(UInt32(bitPattern: numerator)) / Double(UInt32(bitPattern: denominator))
    }

    private static func rationalTriple(
        _ data: Data, header: PhotoBoundary.TIFFHeader, tag: UInt16, ifd: IFD
    ) -> [Double]? {
        guard
            let entry = entryValue(data, header: header, tag: tag, ifd: ifd),
            entry.type == 5, entry.count == 3
        else { return nil }
        var values: [Double] = []
        for index in 0..<3 {
            let offset = entry.valueOffset + UInt32(index) * 8
            let numerator = u32(data, header, offset) ?? 1
            let denominator = u32(data, header, offset + 4) ?? 1
            guard denominator != 0 else { return nil }
            values.append(Double(numerator) / Double(denominator))
        }
        return values
    }
}
