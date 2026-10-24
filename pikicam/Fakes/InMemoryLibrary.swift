// periphery:ignore
import Foundation

#if DEBUG

    actor InMemoryLibrary: Library {
        private let scenario: FakeScenario
        private var stored: [LibraryItem]
        private var dngs: [AssetID: Data]
        private var payloads: [AssetID: AdjustmentPayload]
        private var renditions: [AssetID: Rendition]
        private var saveAttempts = 0
        private var continuation: AsyncStream<[LibraryItem]>.Continuation?

        nonisolated var changes: AsyncStream<[LibraryItem]> {
            AsyncStream { continuation in
                Task { await self.register(continuation) }
            }
        }

        init(scenario: FakeScenario) {
            self.scenario = scenario
            self.stored = []
            self.dngs = [:]
            self.payloads = [:]
            self.renditions = [:]
        }

        private func register(_ continuation: AsyncStream<[LibraryItem]>.Continuation) {
            self.continuation = continuation
            continuation.yield(stored)
        }

        private func publish() {
            continuation?.yield(stored)
        }

        func save(
            _ raw: RawCapture, rendition: Rendition?, payload: AdjustmentPayload
        ) throws(LibraryError) -> LibraryItem {
            saveAttempts += 1
            if scenario == .saveFailsTransient && saveAttempts <= 2 {
                throw LibraryError.saveFailed(code: -1)
            }
            if scenario == .storageFull {
                throw LibraryError.storageFull
            }
            let item = LibraryItem(
                id: AssetID(localIdentifier: "fake-\(raw.id)"),
                captureID: raw.id,
                creationDate: raw.provenance.capturedAt,
                mediaKind: .photo,
                developState: rendition == nil ? .pending : .developed
            )
            stored.insert(item, at: 0)
            dngs[item.id] = raw.dng
            payloads[item.id] = payload
            renditions[item.id] = rendition
            publish()
            return item
        }

        func saveVideo(_ clip: VideoClip, payload: AdjustmentPayload) throws(LibraryError) -> LibraryItem {
            let item = LibraryItem(
                id: AssetID(localIdentifier: "fake-\(clip.id)"),
                captureID: nil,
                creationDate: Date(),
                mediaKind: .video(ClipInfo(clipID: clip.id, duration: clip.duration, mode: clip.mode)),
                developState: .developed
            )
            stored.insert(item, at: 0)
            payloads[item.id] = payload
            publish()
            return item
        }

        func saveScan(
            _ result: ScanResult, rendition: Rendition?, payload: AdjustmentPayload
        ) throws(LibraryError) -> LibraryItem {
            let item = LibraryItem(
                id: AssetID(localIdentifier: "fake-\(result.id)"),
                captureID: result.id,
                creationDate: Date(),
                mediaKind: .photo,
                developState: rendition == nil ? .pending : .developed
            )
            stored.insert(item, at: 0)
            payloads[item.id] = payload
            publish()
            return item
        }

        func items() -> [LibraryItem] {
            stored
        }

        func dng(for id: AssetID) throws(LibraryError) -> Data {
            guard let data = dngs[id] else { throw LibraryError.assetMissing }
            return data
        }

        func commitEdit(_ id: AssetID, payload: AdjustmentPayload, rendition: Rendition?) {
            payloads[id] = payload
            renditions[id] = rendition
        }

        func revert(_ id: AssetID) {
            renditions[id] = nil
        }

        func delete(_ id: AssetID) {
            stored.removeAll { $0.id == id }
            dngs[id] = nil
            payloads[id] = nil
            renditions[id] = nil
            publish()
        }
    }

#endif
