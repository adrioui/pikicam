@preconcurrency import AVFoundation
import Foundation
import Synchronization

final class PhotoCaptureDelegateBox: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    enum Outcome: Sendable {
        case success(AVCapturePhoto)
        case failure(String)
    }

    private let state = Mutex<(CheckedContinuation<Outcome, Never>?, Bool)>((nil, false))

    func hold(_ continuation: CheckedContinuation<Outcome, Never>) {
        state.withLock { current in
            if current.0 == nil {
                current.0 = continuation
            } else {
                continuation.resume(returning: .failure("double-resume prevented"))
            }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let outcome: Outcome
        if let error {
            outcome = .failure("\(error)")
        } else {
            outcome = .success(photo)
        }
        let continuation = state.withLock { current -> CheckedContinuation<Outcome, Never>? in
            guard let held = current.0, !current.1 else { return nil }
            current.1 = true
            return held
        }
        continuation?.resume(returning: outcome)
    }
}
