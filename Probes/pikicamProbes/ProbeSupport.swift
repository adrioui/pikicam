import Foundation

// MARK: - JSON value

enum JSONValue: Codable, Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case dictionary([String: JSONValue])

    init(_ any: Any) {
        switch any {
        case let j as JSONValue: self = j
        case is NSNull: self = .null
        case let b as Bool: self = .bool(b)
        case let n as NSNumber: self = .double(n.doubleValue)
        case let a as [Any]: self = .array(a.map { JSONValue($0) })
        case let o as [String: Any]: self = .dictionary(o.mapValues { JSONValue($0) })
        default: self = .string(String(describing: any))
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let i = try? c.decode(Int.self) { self = .int(i) }
        else if let d = try? c.decode(Double.self) { self = .double(d) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
        else if let o = try? c.decode([String: JSONValue].self) { self = .dictionary(o) }
        else { self = .null }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .int(let i): try c.encode(i)
        case .double(let d): try c.encode(d)
        case .string(let s): try c.encode(s)
        case .array(let a): try c.encode(a)
        case .dictionary(let d): try c.encode(d)
        }
    }

    static func dict(_ pairs: [String: Any]) -> JSONValue {
        .dictionary(pairs.mapValues { JSONValue($0) })
    }
}

extension JSONValue: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral,
    ExpressibleByBooleanLiteral, ExpressibleByFloatLiteral {
    init(stringLiteral value: String) { self = .string(value) }
    init(integerLiteral value: Int) { self = .int(value) }
    init(booleanLiteral value: Bool) { self = .bool(value) }
    init(floatLiteral value: Double) { self = .double(value) }
}

// MARK: - Output model

struct ProbeRecord: Codable, Sendable {
    let name: String
    let status: String
    let data: JSONValue?
}

struct ProbeOutput: Codable, Sendable {
    var startedAt: Date
    var records: [ProbeRecord] = []
}

// MARK: - Writer

/// Appends probe records and atomically rewrites the results file after each
/// one, so a crash (the trap probe deliberately crashes) loses nothing.
@MainActor
final class ProbeRecorder: ObservableObject {
    @Published private(set) var lastRecord = ""

    private var output = ProbeOutput(startedAt: Date())
    private let url: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        url = docs.appendingPathComponent("probe-results.json")
    }

    func record(_ name: String, _ status: String, _ data: JSONValue? = nil) {
        output.records.append(ProbeRecord(name: name, status: status, data: data))
        lastRecord = name
        print("PROBE \(name) -> \(status)")
        do {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            enc.dateEncodingStrategy = .iso8601
            try enc.encode(output).write(to: url, options: [.atomic])
        } catch {
            print("PROBE-WRITE-ERROR \(error)")
        }
    }

    var resultsURL: URL { url }
}

// MARK: - Timeout race

/// Resolves to `nil` when `seconds` elapses before `op` finishes.
func raceTimeout<T: Sendable>(seconds: Double, _ op: @escaping @Sendable () async -> T) async -> T? {
    await withTaskGroup(of: T?.self) { group in
        group.addTask { await op() }
        group.addTask {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return nil
        }
        let first = await group.next() ?? nil
        group.cancelAll()
        return first
    }
}
