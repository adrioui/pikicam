import Photos
import XCTest

@testable import pikicam

final class ArchiveIdentityTests: XCTestCase, @unchecked Sendable {
    override func tearDown() async throws {
        await SeededLibrary.teardown()
    }

    func testSeededLibraryBuildsFiveAssets() async throws {
        let seeded = try await SeededLibrary.build(test: self)
        XCTAssertEqual(seeded.count, 5, "3 legacy/foreign classes x seeded rows")
    }

    func testAlbumCreateIsIdempotent() async throws {
        let first = try await Archive.ensureAlbum()
        let second = try await Archive.ensureAlbum()
        let firstID = try XCTUnwrap(first?.localIdentifier)
        let secondID = try XCTUnwrap(second?.localIdentifier)
        XCTAssertEqual(firstID, secondID, "ensureAlbum must return the same collection")
    }

    func testMigrationMovesOnlyLegacyAndIdempotent() async throws {
        _ = try await SeededLibrary.build(test: self)
        _ = try await Archive.ensureAlbum()
        Archive.markMigrationUndone()
        let report = try await Archive.migrate()
        XCTAssertEqual(report.foreignTouched, 0, "foreign assets must never be touched")
        let album = try XCTUnwrap(Archive.album())
        let legacySeeds = await MainActor.run {
            SeededLibrary.seeded.filter { $0.kind == .legacyPIKIDNG }
        }
        for seed in legacySeeds {
            XCTAssertTrue(Archive.holds(album, seed.localID), "legacy seed \(seed.filename) is album member")
        }
        let reRun = try await Archive.migrate()
        XCTAssertTrue(reRun.alreadyDone, "migration must be one-way")
        XCTAssertEqual(reRun.moved, 0, "re-run moves nothing")
    }

    func testArchiveFetchListsOnlyPikicamAssets() async throws {
        _ = try await SeededLibrary.build(test: self)
        _ = try await Archive.migrate()
        let listed = Archive.fetchArchiveAssets()
        XCTAssertFalse(listed.isEmpty, "album has our seeds")
        for asset in listed {
            let resources = PHAssetResource.assetResources(for: asset)
            let foreign = resources.contains { resource in
                resource.originalFilename.hasPrefix("IMG_")
                    || resource.originalFilename.hasPrefix("VID_")
            }
            XCTAssertFalse(
                foreign,
                "archive must never list foreign assets, found \(resources.map(\.originalFilename))"
            )
        }
    }

    func testSaveLandsInAlbumWithPIKIName() async throws {
        _ = try await SeededLibrary.build(test: self)
        let assetID = try await Self.createPIKIAsset(
            named: "PIKI_smoke.jpg", data: SeededLibrary.renderedJPEG()
        )
        let ensured = try await Archive.ensureAlbum()
        let album = try XCTUnwrap(ensured)
        try await Archive.add(assetID, to: album)
        let canonical = try XCTUnwrap(Archive.album())
        XCTAssertTrue(Archive.holds(canonical, assetID), "saved asset is album member")
    }

    func testConsolidationMergesStrandedDuplicates() async throws {
        _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        Archive.markConsolidationUndone()
        let duplicates = Archive.allAlbums()
        guard duplicates.count > 1 else {
            throw XCTSkip("repair already applied: no stranded duplicates on this library")
        }
        let strandedID = try await Self.createStrandedCapture()
        let report = await Archive.consolidateIfNeeded()
        let result = try XCTUnwrap(report, "first consolidation pass must run")
        XCTAssertGreaterThanOrEqual(result.moved, 1, "stranded capture moves into canonical album")
        let canonical = try XCTUnwrap(Archive.album())
        XCTAssertTrue(Archive.holds(canonical, strandedID), "stranded capture is readable after repair")
        XCTAssertTrue(result.complete, "no duplicate album holds residue after repair")
        XCTAssertEqual(Archive.allAlbums().count, 1, "one canonical album remains")
        let reRun = await Archive.consolidateIfNeeded()
        XCTAssertNil(reRun, "consolidation must be one-way")
    }

    nonisolated private static func createPIKIAsset(named filename: String, data: Data) async throws -> String {
        let box = IDBox()
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.creationDate = Date()
            let options = PHAssetResourceCreationOptions()
            options.originalFilename = filename
            request.addResource(with: .photo, data: data, options: options)
            box.created = request.placeholderForCreatedAsset?.localIdentifier ?? ""
        }
        return box.created
    }

    private static func createStrandedCapture() async throws -> String {
        let assetID = try await createPIKIAsset(
            named: "PIKI_stranded.jpg", data: SeededLibrary.renderedJPEG()
        )
        let duplicates = Archive.allAlbums()
        let duplicate = try XCTUnwrap(duplicates.last, "a stranded duplicate album exists")
        try await Archive.add(assetID, to: duplicate)
        return assetID
    }
}
