import AVFoundation
import Foundation
import Photos
import UIKit

struct PlatformPermissionClient: PermissionClient {
    private var continuation: AsyncStream<[PermissionState]>.Continuation?
    private let lock = NSLock()

    nonisolated var states: AsyncStream<[PermissionState]> {
        AsyncStream { continuation in
            continuation.yield(currentAll())
        }
    }

    private func currentAll() -> [PermissionState] {
        [
            Self.mapCamera(AVCaptureDevice.authorizationStatus(for: .video)),
            Self.mapPhotos(PHPhotoLibrary.authorizationStatus(for: .readWrite)),
        ]
    }

    nonisolated static func mapCamera(_ status: AVAuthorizationStatus) -> PermissionState {
        switch status {
        case .authorized: return .granted
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    nonisolated static func mapPhotos(_ status: PHAuthorizationStatus) -> PermissionState {
        switch status {
        case .authorized: return .granted
        case .limited: return .limited
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    func request(_ permission: PikicamPermission) async -> PermissionState {
        switch permission {
        case .camera:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            return granted ? .granted : .denied
        case .photoLibrary:
            let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            return Self.mapPhotos(status)
        }
    }

    func current(_ permission: PikicamPermission) async -> PermissionState {
        currentAll()[permission == .camera ? 0 : 1]
    }
}

struct PlatformMotionClient: MotionClient {
    nonisolated var level: AsyncStream<LevelReading> {
        AsyncStream { continuation in
            continuation.yield(LevelReading(rollDegrees: 0, pitchDegrees: 0))
            continuation.finish()
        }
    }
}

struct DiskThumbnailStore: ThumbnailStore {
    private let cache = ThumbnailCache()

    func thumbnail(for item: LibraryItem, dng: Data, look: LookParameters) throws(DevelopError) -> Data {
        let key = "\(item.id.localIdentifier)-\(look.recipeVersion)" as NSString
        if let cached = cache.object(forKey: key) {
            return cached as Data
        }
        let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Thumbs")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let fileURL = url.appendingPathComponent("\(item.id.localIdentifier.replacingOccurrences(of: "/", with: "-")).heic")
        if let data = try? Data(contentsOf: fileURL) {
            cache.set(data as NSData, forKey: key)
            return data
        }
        throw .encodeFailed
    }
}

final class ThumbnailCache: @unchecked Sendable {
    private let cache = NSCache<NSString, NSData>()

    func object(forKey key: NSString) -> NSData? {
        cache.object(forKey: key)
    }

    func set(_ data: NSData, forKey key: NSString) {
        cache.setObject(data, forKey: key)
    }
}
