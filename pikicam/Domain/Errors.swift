// periphery:ignore
import Foundation

public enum CaptureError: Error, Hashable, Sendable, LocalizedError {
    case noBayerLens
    case configurationRejected(DeviceDeterminism)
    case sessionStartFailed(code: Int)
    case interrupted(reason: String)
    case mediaServicesReset
    case notBayer(pixelFormat: String)
    case unexpectedResolvedSettings(String)
    case noFileData
    case notADNG
    case timedOut
    case deviceLockFailed

    public var errorDescription: String? {
        switch self {
        case .noBayerLens: return "No lens on this device delivers Bayer RAW."
        case .configurationRejected: return "The camera configuration was rejected."
        case .sessionStartFailed(let code): return "Camera session failed to start (\(code))."
        case .interrupted(let reason): return "Capture interrupted: \(reason)."
        case .mediaServicesReset: return "Media services were reset."
        case .notBayer(let pixelFormat): return "Capture was not Bayer RAW (\(pixelFormat))."
        case .unexpectedResolvedSettings(let detail): return "Unexpected resolved settings: \(detail)."
        case .noFileData: return "The camera returned no file data."
        case .notADNG: return "The capture is not a DNG."
        case .timedOut: return "The capture timed out."
        case .deviceLockFailed: return "The camera device could not be locked."
        }
    }
}

public enum DevelopError: Error, Hashable, Sendable, LocalizedError {
    case filterUnavailable
    case undecodable
    case decoderUnavailable
    case recipeNotApplied([String])
    case renderFailed
    case encodeFailed
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .filterUnavailable: return "The RAW developer is unavailable."
        case .undecodable: return "This file cannot be decoded."
        case .decoderUnavailable: return "No usable RAW decoder is installed."
        case .recipeNotApplied(let controls): return "Recipe controls not applied: \(controls.joined(separator: ", "))."
        case .renderFailed: return "The develop render failed."
        case .encodeFailed: return "Encoding the developed image failed."
        case .cancelled: return "Develop was cancelled."
        }
    }
}

public enum LibraryError: Error, Hashable, Sendable, LocalizedError {
    case notAuthorized
    case saveFailed(code: Int)
    case storageFull
    case assetMissing
    case resourceMissing
    case editFailed
    case foreignAdjustment(formatIdentifier: String)
    case albumUnavailable

    public var errorDescription: String? {
        switch self {
        case .notAuthorized: return "Photo library access is not authorized."
        case .saveFailed(let code): return "Saving to the photo library failed (\(code))."
        case .storageFull: return "Storage is full."
        case .assetMissing: return "The photo is missing from the library."
        case .resourceMissing: return "The photo's resources are missing."
        case .editFailed: return "Committing the edit failed."
        case .foreignAdjustment(let format): return "Edited outside pikicam (\(format))."
        case .albumUnavailable: return "The pikicam album is unavailable."
        }
    }
}

public enum JournalError: Error, Hashable, Sendable, LocalizedError {
    case writeFailed
    case corrupt(CaptureID)

    public var errorDescription: String? {
        switch self {
        case .writeFailed: return "Writing the capture journal failed."
        case .corrupt(let id): return "The journal entry \(id) is corrupt."
        }
    }
}

public enum RecordingError: Error, Hashable, Sendable, LocalizedError {
    case formatUnavailable(reason: String)
    case writerFailed(code: Int)
    case framesDropped(Int)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .formatUnavailable(let reason): return "Recording format unavailable: \(reason)."
        case .writerFailed(let code): return "The recording writer failed (\(code))."
        case .framesDropped(let count): return "Recording dropped \(count) frames."
        case .cancelled: return "Recording was cancelled."
        }
    }
}

public enum ScanError: Error, Hashable, Sendable, LocalizedError {
    case framesStalled
    case gpuFailed(code: Int)
    case tooManyDrops(Int)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .framesStalled: return "Camera frames stalled during the scan."
        case .gpuFailed(let code): return "The scan assembly failed (\(code))."
        case .tooManyDrops(let count): return "The scan dropped too many frames (\(count))."
        case .cancelled: return "The scan was cancelled."
        }
    }
}

public enum CameraError: Error, Hashable, Sendable {
    case capture(CaptureError)
    case journal(JournalError)
    case library(LibraryError)

    public init(mapping error: CaptureError) {
        self = .capture(error)
    }

    public init(mapping error: JournalError) {
        self = .journal(error)
    }

    public init(mapping error: LibraryError) {
        self = .library(error)
    }
}

public enum ViewerError: Error, Hashable, Sendable {
    case develop(DevelopError)
    case library(LibraryError)

    public init(mapping error: DevelopError) {
        self = .develop(error)
    }

    public init(mapping error: LibraryError) {
        self = .library(error)
    }
}
