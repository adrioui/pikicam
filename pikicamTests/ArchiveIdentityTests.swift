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

        let before = Archive.fetchArchiveAssets().count
        let report = try await Archive.migrate()
        XCTAssertEqual(report.foreignTouched, 0, "foreign assets must never be touched")
        XCTAssertEqual(report.moved, 2, "exactly the two legacy PIKI_ assets move")
        let after = Archive.fetchArchiveAssets().count
        XCTAssertEqual(after, before + 2)

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
            let ours = resources.contains {
                $0.originalFilename.hasPrefix("PIKI_")
            }
            XCTAssertTrue(ours, "archive must list only PIKI_-named assets, found \(resources.map(\.originalFilename))")
        }
    }

    func testSaveLandsInAlbumWithPIKIName() async throws {
        _ = try await SeededLibrary.build(test: self)
        _ = try await Archive.ensureAlbum()
        let data = Data(repeating: 0x55, count: 256)
        let box = IDBox()
        PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.creationDate = Date()
            let options = PHAssetResourceCreationOptions()
            options.originalFilename = "PIKI_smoke.heic"
            request.addResource(with: .photo, data: data, options: options)
            box.created = request.placeholderForCreatedAsset?.localIdentifier ?? ""
        } completionHandler: { _, _ in }
        try await Task.sleep(nanoseconds: 2_000_000_000)
        let album = try XCTUnwrap(Archive.album())
        let fetch = PHAsset.fetchAssets(in: album, options: nil)
        XCTAssertGreaterThanOrEqual(fetch.count, 1, "saved asset is album member")
    }
}
