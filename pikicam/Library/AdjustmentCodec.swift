import Foundation
import Photos

enum AdjustmentCodec {
    enum DecodeError: Error, Equatable, Sendable {
        case foreign(formatIdentifier: String)
        case corrupt
    }

    static func encode(_ payload: AdjustmentPayload) -> PHAdjustmentData {
        PHAdjustmentData(
            formatIdentifier: AdjustmentPayload.formatIdentifier,
            formatVersion: AdjustmentPayload.formatVersion,
            data: encodeJSON(payload)
        )
    }

    static func decode(_ adjustment: PHAdjustmentData) throws(DecodeError) -> AdjustmentPayload {
        guard adjustment.formatIdentifier == AdjustmentPayload.formatIdentifier else {
            throw .foreign(formatIdentifier: adjustment.formatIdentifier)
        }
        guard adjustment.formatVersion == AdjustmentPayload.formatVersion else {
            throw .foreign(formatIdentifier: adjustment.formatIdentifier)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let payload = try? decoder.decode(AdjustmentPayload.self, from: adjustment.data) else {
            throw .corrupt
        }
        return payload
    }

    private static func encodeJSON(_ payload: AdjustmentPayload) -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(payload)) ?? Data()
    }
}
