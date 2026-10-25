import Foundation
import Photos
import Synchronization

enum ArchiveDiag {
    struct AlbumSnapshot: Codable, Sendable {
        let identifier: String
        let memberCount: Int
        let holdsTarget: Bool
    }

    struct TimelinePoint: Codable, Sendable {
        let ms: Int
        let albums: [AlbumSnapshot]
        let readerHoldsTarget: Bool
    }

    struct SaveWitness: Codable, Sendable {
        let verb: String
        let createdID: String?
        let fetchedByID: Bool
        let albumsAtBegin: [AlbumSnapshot]
        let timeline: [TimelinePoint]
        let readerAlbumID: String?
        let readerMemberCount: Int
    }

    struct FetchDump: Codable, Sendable {
        let reason: String
        let albums: [AlbumSnapshot]
        let readerAlbumID: String?
        let readerMembers: [String]
        let lastCreatedID: String?
        let readerHoldsLast: Bool
    }

    struct ChangeRecord: Codable, Sendable {
        let at: Double
        var albumsAdded: [String]
        var albumsRemoved: [String]
        var membershipAdded: [String: [String]]
        var membershipRemoved: [String: [String]]
    }

    struct Entry: Codable, Sendable {
        let kind: String
        let at: Date
        let witness: SaveWitness?
        let dump: FetchDump?
        let change: ChangeRecord?
    }

    private static let ledger = Mutex<[Entry]>([])
    private static let lastCreated = Mutex<String?>(nil)
    private static let current = Mutex<ChangeWitness?>(nil)

    static var lastCreatedID: String? {
        lastCreated.withLock { $0 }
    }

    static func beginWitness(verb: String) {
        let previous = current.withLock { box -> ChangeWitness? in
            let old = box
            box = ChangeWitness(verb: verb)
            return old
        }
        if let previous {
            _ = previous.finish()
        }
        let next = current.withLock { $0 }
        next?.register()
    }

    nonisolated static func endWitness(verb: String, createdID: String?) async {
        let w = current.withLock { box -> ChangeWitness? in
            let old = box
            guard old?.verb == verb else { return nil }
            box = nil
            return old
        }
        guard let w else { return }
        let changes = w.finish()
        var fetchedByID = false
        if let createdID {
            lastCreated.withLock { $0 = createdID }
            fetchedByID = PHAsset.fetchAssets(withLocalIdentifiers: [createdID], options: nil).count > 0
        }
        var points: [TimelinePoint] = []
        if let target = createdID, fetchedByID {
            points = await membershipTimeline(target: target)
        }
        let reader = points.isEmpty ? nil : Archive.album()
        let readerCount = reader.map { Archive.memberCount($0) } ?? 0
        let record = SaveWitness(
            verb: verb,
            createdID: createdID,
            fetchedByID: fetchedByID,
            albumsAtBegin: w.beginSnapshots,
            timeline: points,
            readerAlbumID: reader?.localIdentifier,
            readerMemberCount: readerCount
        )
        append(Entry(kind: "save-witness", at: Date(), witness: record, dump: nil, change: nil))
        for change in changes {
            append(Entry(
                kind: "change",
                at: Date(timeIntervalSince1970: change.at),
                witness: nil, dump: nil, change: change
            ))
        }
        WalkMark.mark("diag-witness-\(verb)-fetched-\(fetchedByID)-points-\(points.count)")
    }

    nonisolated private static func membershipTimeline(target: String) async -> [TimelinePoint] {
        var points: [TimelinePoint] = []
        let started = Date()
        for step in 0...40 {
            let albums = Archive.allAlbums().map {
                AlbumSnapshot(
                    identifier: $0.localIdentifier,
                    memberCount: Archive.memberCount($0),
                    holdsTarget: Archive.holds($0, target)
                )
            }
            let reader = Archive.album()
            let readerHolds = reader.map { Archive.holds($0, target) } ?? false
            points.append(TimelinePoint(
                ms: Int(Date().timeIntervalSince(started) * 1000),
                albums: albums,
                readerHoldsTarget: readerHolds
            ))
            if readerHolds { break }
            if step < 40 {
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
        return points
    }

    static func dumpFetch(reason: String) {
        let target = lastCreatedID
        let albums = Archive.allAlbums().map { album in
            AlbumSnapshot(
                identifier: album.localIdentifier,
                memberCount: Archive.memberCount(album),
                holdsTarget: target.map { Archive.holds(album, $0) } ?? false
            )
        }
        let reader = Archive.album()
        let members = reader.map { Archive.memberIDs($0, limit: 500) } ?? []
        let dump = FetchDump(
            reason: reason,
            albums: albums,
            readerAlbumID: reader?.localIdentifier,
            readerMembers: members,
            lastCreatedID: target,
            readerHoldsLast: target.flatMap { id in reader.map { Archive.holds($0, id) } } ?? false
        )
        append(Entry(kind: "fetch-dump", at: Date(), witness: nil, dump: dump, change: nil))
    }

    private static func append(_ entry: Entry) {
        let entries = ledger.withLock { list -> [Entry] in
            list.append(entry)
            return list
        }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent("diag-archive.json")
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: url, options: [.atomic])
        }
    }
}

final class ChangeWitness: NSObject, PHPhotoLibraryChangeObserver, @unchecked Sendable {
    let verb: String
    private let lock = NSLock()
    private var records: [ArchiveDiag.ChangeRecord] = []
    private var albumFetch: PHFetchResult<PHAssetCollection>?
    private var memberFetches: [String: PHFetchResult<PHAsset>] = [:]
    private(set) var beginSnapshots: [ArchiveDiag.AlbumSnapshot] = []
    private var registered = false

    init(verb: String) {
        self.verb = verb
        super.init()
    }

    func register() {
        lock.lock()
        albumFetch = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        var albums: [PHAssetCollection] = []
        albumFetch?.enumerateObjects { collection, _, _ in
            if collection.localizedTitle == Archive.albumTitle {
                albums.append(collection)
            }
        }
        beginSnapshots = albums.map {
            ArchiveDiag.AlbumSnapshot(
                identifier: $0.localIdentifier,
                memberCount: Archive.memberCount($0),
                holdsTarget: false
            )
        }
        for album in albums {
            memberFetches[album.localIdentifier] = PHAsset.fetchAssets(in: album, options: nil)
        }
        registered = true
        lock.unlock()
        PHPhotoLibrary.shared().register(self)
    }

    func finish() -> [ArchiveDiag.ChangeRecord] {
        if registered {
            PHPhotoLibrary.shared().unregisterChangeObserver(self)
        }
        lock.lock()
        defer { lock.unlock() }
        return records
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        lock.lock()
        defer { lock.unlock() }
        var record = ArchiveDiag.ChangeRecord(
            at: Date().timeIntervalSince1970,
            albumsAdded: [],
            albumsRemoved: [],
            membershipAdded: [:],
            membershipRemoved: [:]
        )
        if let fetch = albumFetch, let details = changeInstance.changeDetails(for: fetch) {
            for collection in details.insertedObjects
            where collection.localizedTitle == Archive.albumTitle {
                record.albumsAdded.append(collection.localIdentifier)
                memberFetches[collection.localIdentifier] = PHAsset.fetchAssets(in: collection, options: nil)
            }
            for collection in details.removedObjects {
                record.albumsRemoved.append(collection.localIdentifier)
                memberFetches[collection.localIdentifier] = nil
            }
            albumFetch = details.fetchResultAfterChanges
        }
        for (albumID, fetch) in memberFetches {
            guard let details = changeInstance.changeDetails(for: fetch) else { continue }
            let added = details.insertedObjects.map(\.localIdentifier)
            let removed = details.removedObjects.map(\.localIdentifier)
            if !added.isEmpty { record.membershipAdded[albumID] = added }
            if !removed.isEmpty { record.membershipRemoved[albumID] = removed }
            memberFetches[albumID] = details.fetchResultAfterChanges
        }
        if record.albumsAdded.isEmpty, record.albumsRemoved.isEmpty,
            record.membershipAdded.isEmpty, record.membershipRemoved.isEmpty
        {
            return
        }
        records.append(record)
    }
}
