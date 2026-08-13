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
/// The request is RAW-only: the delivered photo is the DNG payload, and no
/// processed print is produced. Delegate failures are translated into the
/// typed `CaptureError.captureFailed` rather than surfacing a raw `Error`.
///
/// Note: `PhotoCapture` is intentionally **not** `Sendable`. It captures a
/// `CheckedContinuation` (non-Sendable) and is bridged to a `AVCapturePhotoOutput`
/// delegate callback via `objc_setAssociatedObject`. The continuation must remain
/// alive until `photoOutput(_:didFinishProcessingPhoto:error:)` fires; the
/// associated `DelegateWrapper` holds the only strong reference for that window.
/// Marking the class `Sendable` would be incorrect under strict concurrency and
/// would hide the real lifetime guarantee provided by the wrapper.
nonisolated final class PhotoCapture: NSObject, AVCapturePhotoCaptureDelegate {
    private var continuation: CheckedContinuation<AVCapturePhoto, Error>?
    private var photo: AVCapturePhoto?
    private var processingError: Error?

    init(continuation: CheckedContinuation<AVCapturePhoto, Error>) {
        self.continuation = continuation
    }

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                  didFinishProcessingPhoto photo: AVCapturePhoto,
                                  error: Error?) {
        if let error = error {
            processingError = error
        } else {
            self.photo = photo
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
            // Translate the delegate failure into a typed CaptureError so no
            // arbitrary Error crosses the capture boundary.
            continuation?.resume(throwing: CaptureError.captureFailed(underlying: error))
        } else if let photo {
            continuation?.resume(returning: photo)
        } else {
            continuation?.resume(throwing: CaptureError.missingImageData)
        }
    }
}

// MARK: - Convenience Extension

extension AVCapturePhotoOutput {
    /// Captures a photo using Swift async/await, bridging the delegate pattern.
    ///
    /// - Parameter settings: The photo settings to use for capture. RAW-only
    ///   settings deliver the DNG photo.
    /// - Returns: The captured `AVCapturePhoto`.
    func capturePhoto(with settings: AVCapturePhotoSettings) async throws -> AVCapturePhoto {
        try await withCheckedThrowingContinuation { continuation in
            let captureDelegate = PhotoCapture(continuation: continuation)
            // Keep the delegate alive (keyed on its own address) until the
            // capture callbacks fire; `didFinishCaptureFor` clears it.
            let key = Unmanaged.passUnretained(captureDelegate).toOpaque()
            objc_setAssociatedObject(self, key, captureDelegate, .OBJC_ASSOCIATION_RETAIN)

            self.capturePhoto(with: settings, delegate: captureDelegate)
        }
    }
}
