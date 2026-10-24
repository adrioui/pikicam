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
/// association. Both finish callbacks arrive on AVFoundation's serial
/// delegate queue; the timeout task does not, so a lock serializes every
/// resume path — a continuation resumed twice is a runtime crash.
nonisolated final class PhotoCapture: NSObject, AVCapturePhotoCaptureDelegate {
    /// How long to wait for AVFoundation's capture callbacks before failing
    /// with `.captureTimedOut`. AVFoundation normally fires
    /// `didFinishCaptureFor` promptly; if it never does (rare internal
    /// failure), the continuation must still resume or the capture pipeline
    /// deadlocks with `isCaptureInFlight` stuck true.
    private static let captureTimeout: Duration = .seconds(15)

    private let lock = NSLock()
    private var continuation: CheckedContinuation<AVCapturePhoto, Error>?
    private var photo: AVCapturePhoto?
    private var processingError: Error?
    private var timeoutTask: Task<Void, Never>?
    /// The output retaining this delegate via associated object. Weak: the
    /// association itself keeps the delegate alive until it is cleared.
    private weak var output: AVCapturePhotoOutput?

    init(output: AVCapturePhotoOutput, continuation: CheckedContinuation<AVCapturePhoto, Error>) {
        self.output = output
        self.continuation = continuation
        super.init()
        self.timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: Self.captureTimeout)
            guard !Task.isCancelled else { return }
            self?.failWithTimeout()
        }
    }

    /// Fails the capture with `.captureTimedOut` unless a delegate callback
    /// already claimed the continuation.
    ///
    /// This runs on the timeout task's executor, which is *not* AVFoundation's
    /// delegate queue — so every field it shares with the callbacks is touched
    /// under `lock`, including `timeoutTask` itself (the callback path cancels
    /// and clears that same property).
    private func failWithTimeout() {
        let claimed: CheckedContinuation<AVCapturePhoto, Error>? = lock.withLock {
            defer {
                self.continuation = nil
                timeoutTask = nil
            }
            guard let continuation else { return nil }
            return continuation
        }
        // A timed-out capture whose `didFinishCaptureFor` never fires must not
        // leak the delegate through its associated object — perform the same
        // teardown as the callback path. The delegate path may have already
        // detached us; clearing twice is harmless.
        if let output {
            let key = Unmanaged.passUnretained(self).toOpaque()
            objc_setAssociatedObject(output, key, nil, .OBJC_ASSOCIATION_ASSIGN)
        }
        claimed?.resume(throwing: CaptureError.captureTimedOut)
    }

    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        // Written under the lock so `didFinishCaptureFor` can take the payload
        // and the continuation as one consistent snapshot.
        lock.withLock {
            if let error = error {
                processingError = error
            } else {
                self.photo = photo
            }
        }
    }

    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        let key = Unmanaged.passUnretained(self).toOpaque()

        // One locked snapshot of everything the resume decision needs: the
        // continuation, the delegate-reported payload, and the timeout task.
        // Taking the continuation clears it, so the timeout path — which runs
        // on another executor — cannot resume it after this point.
        let (pending, capturedPhoto, capturedError, pendingTimeout) = lock.withLock {
            defer {
                self.continuation = nil
                timeoutTask = nil
            }
            return (continuation, photo, processingError, timeoutTask)
        }

        defer {
            pendingTimeout?.cancel()
            objc_setAssociatedObject(output, key, nil, .OBJC_ASSOCIATION_ASSIGN)
        }
        guard let pending else { return }

        if let error = error ?? capturedError {
            // Translate the delegate failure into a typed CaptureError so no
            // arbitrary Error crosses the capture boundary.
            pending.resume(throwing: CaptureError.captureFailed(underlying: error))
        } else if let capturedPhoto {
            pending.resume(returning: capturedPhoto)
        } else {
            pending.resume(throwing: CaptureError.missingImageData)
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
            let captureDelegate = PhotoCapture(output: self, continuation: continuation)
            // Keep the delegate alive (keyed on its own address) until the
            // capture callbacks fire; `didFinishCaptureFor` clears it.
            let key = Unmanaged.passUnretained(captureDelegate).toOpaque()
            objc_setAssociatedObject(self, key, captureDelegate, .OBJC_ASSOCIATION_RETAIN)

            self.capturePhoto(with: settings, delegate: captureDelegate)
        }
    }
}
