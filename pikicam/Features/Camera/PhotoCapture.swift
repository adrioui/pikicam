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
/// The capture is kept alive until `didFinishCaptureFor` fires: the output
/// retains it via `objc_setAssociatedObject`, and that callback clears the
/// association. The continuation is the only mutable state; both finish
/// callbacks arrive on AVFoundation's serial delegate queue, and the timeout
/// task shares the same isolated instance.
nonisolated final class PhotoCapture: NSObject, AVCapturePhotoCaptureDelegate {
    /// How long to wait for AVFoundation's capture callbacks before failing
    /// with `.captureTimedOut`. AVFoundation normally fires
    /// `didFinishCaptureFor` promptly; if it never does (rare internal
    /// failure), the continuation must still resume or the capture pipeline
    /// deadlocks with `isCaptureInFlight` stuck true.
    private static let captureTimeout: Duration = .seconds(15)

    private var continuation: CheckedContinuation<AVCapturePhoto, Error>?
    private var photo: AVCapturePhoto?
    private var processingError: Error?
    private var timeoutTask: Task<Void, Never>?

    init(continuation: CheckedContinuation<AVCapturePhoto, Error>) {
        self.continuation = continuation
        super.init()
        self.timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: Self.captureTimeout)
            guard !Task.isCancelled else { return }
            self?.failWithTimeout()
        }
    }

    private func failWithTimeout() {
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask = nil
        continuation.resume(throwing: CaptureError.captureTimedOut)
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
            timeoutTask?.cancel()
            timeoutTask = nil
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
