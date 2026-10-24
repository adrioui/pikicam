import Foundation

actor FileJournal: Journal {
    private let root: URL
    private let fileManager = FileManager.default

    init(root: URL? = nil) {
        if let root {
            self.root = root
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.root = base.appendingPathComponent("Journal", isDirectory: true)
        }
    }

    func persist(_ raw: RawCapture, geometry: FrameGeometry, look: LookParameters) throws(JournalError) -> JournalEntry {
        let entry = JournalEntry(
            id: raw.id,
            capturedAt: raw.provenance.capturedAt,
            phase: .captured,
            geometry: geometry,
            look: look,
            provenance: raw.provenance
        )
        let directory = directory(for: raw.id)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try raw.dng.write(to: directory.appendingPathComponent("capture.dng"), options: [.atomic])
            let data = try encode(entry)
            try data.write(to: directory.appendingPathComponent("entry.json"), options: [.atomic])
        } catch {
            throw .writeFailed
        }
        return entry
    }

    func pending() throws(JournalError) -> [JournalEntry] {
        guard let directories = try? fileManager.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            return []
        }
        var entries: [JournalEntry] = []
        for directory in directories where directory.hasDirectoryPath {
            let entryURL = directory.appendingPathComponent("entry.json")
            guard let data = try? Data(contentsOf: entryURL) else {
                let fallbackID = CaptureID(UUID(uuidString: directory.lastPathComponent) ?? UUID())
                entries.append(JournalEntry(
                    id: fallbackID, capturedAt: Date(), phase: .captured,
                    geometry: .placeholder, look: .standard, provenance: .placeholder
                ))
                continue
            }
            if let entry = try? decode(data) {
                entries.append(entry)
            } else {
                throw .corrupt(CaptureID(UUID(uuidString: directory.lastPathComponent) ?? UUID()))
            }
        }
        return entries
    }

    func dngData(for id: CaptureID) throws(JournalError) -> Data {
        let url = directory(for: id).appendingPathComponent("capture.dng")
        guard let data = try? Data(contentsOf: url) else {
            throw .corrupt(id)
        }
        return data
    }

    func complete(_ id: CaptureID) throws(JournalError) {
        do {
            try fileManager.removeItem(at: directory(for: id))
        } catch {
            throw .writeFailed
        }
    }

    private func directory(for id: CaptureID) -> URL {
        root.appendingPathComponent(id.id.uuidString, isDirectory: true)
    }

    private func encode(_ entry: JournalEntry) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(entry)
    }

    private func decode(_ data: Data) throws -> JournalEntry {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(JournalEntry.self, from: data)
    }
}

extension FrameGeometry {
    static let placeholder = FrameGeometry(aspect: .native, crop: 1, sensorWidth: 4032, sensorHeight: 3024)
}
