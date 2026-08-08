import AVFoundation
import Foundation

/// A reusable delegate-based photo capture handler that bridges
/// `AVCapturePhotoCaptureDelegate` callbacks to Swift concurrency
/// via `withCheckedThrowingContinuation`.
///
/// ## Usage
/// ```swift
/// let photo = try await PhotoCapture.capture(
///     using: photoOutput,
///     settings: settings
/// )
/// ```
///
/// Each `PhotoCapture` instance is one-shot — it handles a single
/// capture and is then discarded.
///
/// Note: `PhotoCapture` is intentionally **not** `Sendable`. It captures a
/// `CheckedContinuation` (non-Sendable) and is bridged to a `AVCapturePhotoOutput`
/// delegate callback via `objc_setAssociatedObject`. The continuation must remain
/// alive until `photoOutput(_:didFinishProcessingPhoto:error:)` fires; the
/// associated `DelegateWrapper` holds the only strong reference for that window.
/// Marking the class `Sendable` would be incorrect under strict concurrency and
/// would hide the real lifetime guarantee provided by the wrapper.
nonisolated final class PhotoCapture: NSObject, AVCapturePhotoCaptureDelegate {
    private var continuation: CheckedContinuation<PhotoCapturePair, Error>?
    private var processedPhoto: AVCapturePhoto?
    private var rawPhoto: AVCapturePhoto?
    private var processingError: Error?

    init(continuation: CheckedContinuation<PhotoCapturePair, Error>) {
        self.continuation = continuation
    }

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                  didFinishProcessingPhoto photo: AVCapturePhoto,
                                  error: Error?) {
        if let error = error {
            processingError = error
        } else if photo.isRawPhoto {
            rawPhoto = photo
        } else {
            processedPhoto = photo
        }
    }

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                  didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
                                  error: Error?) {
        let key = Unmanaged.passUnretained(self).toOpaque()
        defer {
            continuation = nil
            objc_setAssociatedObject(output, key, nil, .OBJC_ASSOCIATION_ASSIGN)
        }

        if let error = error ?? processingError {
            continuation?.resume(throwing: error)
        } else {
            continuation?.resume(returning: PhotoCapturePair(
                processedPhoto: processedPhoto,
                rawPhoto: rawPhoto
            ))
        }
    }
}

/// The photo objects produced by one capture request.
nonisolated struct PhotoCapturePair: @unchecked Sendable {
    /// The processed JPEG/HEIC photo, if requested.
    let processedPhoto: AVCapturePhoto?

    /// The RAW DNG photo, if requested.
    let rawPhoto: AVCapturePhoto?
}

// MARK: - Convenience Extension

extension AVCapturePhotoOutput {
    /// Captures a photo using Swift async/await, bridging the delegate pattern.
    ///
    /// - Parameter settings: The photo settings to use for capture.
    /// - Returns: The captured `AVCapturePhoto`.
    func capturePhoto(with settings: AVCapturePhotoSettings) async throws -> AVCapturePhoto {
        let pair = try await capturePhotoPair(with: settings)
        if let processedPhoto = pair.processedPhoto {
            return processedPhoto
        }
        if let rawPhoto = pair.rawPhoto {
            return rawPhoto
        }
        throw CaptureError.missingImageData
    }

    /// Captures RAW and processed photos from one capture request.
    ///
    /// - Parameter settings: The photo settings to use for capture.
    /// - Returns: Both photo objects produced by the request.
    func capturePhotoPair(with settings: AVCapturePhotoSettings) async throws -> PhotoCapturePair {
        return try await withCheckedThrowingContinuation { continuation in
            let captureDelegate = PhotoCapture(continuation: continuation)
            // Keep the delegate alive (keyed on its own address) until the
            // capture callbacks fire; `didFinishCaptureFor` clears it.
            let key = Unmanaged.passUnretained(captureDelegate).toOpaque()
            objc_setAssociatedObject(self, key, captureDelegate, .OBJC_ASSOCIATION_RETAIN)

            self.capturePhoto(with: settings, delegate: captureDelegate)
        }
    }
}
