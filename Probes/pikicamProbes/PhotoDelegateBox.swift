import AVFoundation
import Foundation
import Synchronization

final class PhotoDelegateBox: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let state = Mutex<(CheckedContinuation<CaptureOutcome, Never>?, Bool)>((nil, false))

    func resume(with continuation: CheckedContinuation<CaptureOutcome, Never>) {
        state.withLock { s in
            if s.0 == nil {
                s.0 = continuation
            } else {
                continuation.resume(returning: CaptureOutcome(success: false, error: "double-resume prevented"))
            }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        var outcome = CaptureOutcome()
        if let error {
            outcome.error = "\(error)"
        } else {
            outcome.success = true
            outcome.isRawPhoto = photo.isRawPhoto
            if let buffer = photo.pixelBuffer {
                outcome.pixelFormat = CameraProbes.fourCCString(CVPixelBufferGetPixelFormatType(buffer))
            }
            let rs = photo.resolvedSettings
            outcome.rawWidth = Int(rs.rawPhotoDimensions.width)
            outcome.rawHeight = Int(rs.rawPhotoDimensions.height)
            outcome.expectedPhotoCount = rs.expectedPhotoCount
            outcome.flashEnabled = rs.isFlashEnabled
            if let data = photo.fileDataRepresentation() {
                outcome.fileBytes = data.count
                outcome.fileData = data
            }
            if let exif = photo.metadata[kCGImagePropertyExifDictionary as String] as? [String: Any] {
                outcome.iso = (exif["ISOSpeedRatings"] as? [NSNumber])?.first?.doubleValue ?? 0
                outcome.durationSeconds = exif["ExposureTime"] as? Double ?? 0
            }
        }
        let continuation = state.withLock { s -> CheckedContinuation<CaptureOutcome, Never>? in
            guard let c = s.0, !s.1 else { return nil }
            s.1 = true
            return c
        }
        continuation?.resume(returning: outcome)
    }
}
