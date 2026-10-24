import Foundation

struct CaptureFlow: Sendable {
    let deps: Dependencies

    func run(_ request: CaptureRequest) async throws(CameraError) -> LibraryItem {
        let raw: RawCapture
        do {
            raw = try await deps.capture.capture(request)
        } catch {
            throw CameraError.capture(error)
        }
        let entry: JournalEntry
        do {
            entry = try await deps.journal.persist(raw, geometry: request.geometry, look: .standard)
        } catch {
            throw CameraError.journal(error)
        }
        let rendition = await developForCapture(raw, entry)
        let payload = AdjustmentPayload(entry, rendition: rendition)
        let item: LibraryItem
        do {
            item = try await SaveRetry.perform(deps: deps, raw: raw, rendition: rendition, payload: payload)
        } catch {
            throw CameraError.library(error)
        }
        do {
            try await deps.journal.complete(entry.id)
        } catch {
            throw CameraError.journal(error)
        }
        return item
    }

    func developForCapture(_ raw: RawCapture, _ entry: JournalEntry) async -> Rendition? {
        do {
            return try await deps.developer.export(raw.dng, look: entry.look, geometry: entry.geometry)
        } catch {
            return nil
        }
    }
}

extension RetryPolicy where E == LibraryError {
    static func photosSavePolicy() -> RetryPolicy<LibraryError> {
        RetryPolicy(attempts: 3, backoff: [0.5, 1, 2])
    }
}
