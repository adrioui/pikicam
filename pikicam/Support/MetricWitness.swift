import Foundation
import MetricKit

final class MetricWitness: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {
    static let shared = MetricWitness()

    func start() {
        MXMetricManager.shared.add(self)
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        for payload in payloads {
            let stamp = ISO8601DateFormatter().string(from: payload.timeStampBegin)
            write(encoder, data: payload.jsonRepresentation(), prefix: "metric", stamp: stamp)
        }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            let stamp = ISO8601DateFormatter().string(from: payload.timeStampBegin)
            write(JSONEncoder(), data: payload.jsonRepresentation(), prefix: "diagnostic", stamp: stamp)
        }
    }

    private func write(_ encoder: JSONEncoder, data: Data, prefix: String, stamp: String) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("metrickit", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let name = "\(prefix)-\(stamp.replacingOccurrences(of: ":", with: "-")).json"
        try? data.write(to: dir.appendingPathComponent(name), options: [.atomic])
    }
}
