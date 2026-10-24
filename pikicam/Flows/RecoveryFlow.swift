import Foundation

struct RecoveryFlow: Sendable {
    let deps: Dependencies

    func run() async throws(CameraError) {
        let pending: [JournalEntry]
        do {
            pending = try await deps.journal.pending()
        } catch {
            throw CameraError.journal(error)
        }
        for entry in pending {
            try await recover(entry)
        }
    }

    private func recover(_ entry: JournalEntry) async throws(CameraError) {
        let data: Data
        do {
            data = try await deps.journal.dngData(for: entry.id)
        } catch {
            throw CameraError.journal(error)
        }
        let raw = RawCapture(id: entry.id, dng: data, provenance: entry.provenance)
        let rendition = await developForCapture(raw, entry)
        let payload = AdjustmentPayload(entry, rendition: rendition)
        do {
            _ = try await SaveRetry.perform(deps: deps, raw: raw, rendition: rendition, payload: payload)
        } catch {
            throw CameraError.library(error)
        }
        do {
            try await deps.journal.complete(entry.id)
        } catch {
            throw CameraError.journal(error)
        }
    }

    private func developForCapture(_ raw: RawCapture, _ entry: JournalEntry) async -> Rendition? {
        do {
            return try await deps.developer.export(raw.dng, look: entry.look, geometry: entry.geometry)
        } catch {
            return nil
        }
    }
}
