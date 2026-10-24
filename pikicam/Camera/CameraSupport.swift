@preconcurrency import AVFoundation
import SwiftUI
import UIKit

final class PendingCapture: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    enum Outcome {
        case success(AVCapturePhoto)
        case failure(String)
    }

    private var continuation: CheckedContinuation<Outcome, Never>?
    private let lock = NSLock()

    func resume(with continuation: CheckedContinuation<Outcome, Never>) {
        lock.lock()
        self.continuation = continuation
        lock.unlock()
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?
    ) {
        let outcome: Outcome
        if let error {
            outcome = .failure(error.localizedDescription)
        } else {
            outcome = .success(photo)
        }
        lock.lock()
        let held = continuation
        continuation = nil
        lock.unlock()
        held?.resume(returning: outcome)
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var previewLayer: AVCaptureVideoPreviewLayer {
            unsafeDowncast(layer, to: AVCaptureVideoPreviewLayer.self)
        }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

final class MovieRecorderBox: NSObject, AVCaptureFileOutputRecordingDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<URL?, Never>?
    private var fileURL: URL?
    private var finished = false

    func finishedURL() async -> URL? {
        await withCheckedContinuation { continuation in
            lock.lock()
            if finished {
                lock.unlock()
                continuation.resume(returning: fileURL)
            } else {
                self.continuation = continuation
                lock.unlock()
            }
        }
    }

    func fileOutput(
        _ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection], error: Error?
    ) {
        lock.lock()
        finished = true
        fileURL = (error as? NSError)?.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool == true
            ? outputFileURL
            : (error == nil ? outputFileURL : nil)
        let held = continuation
        continuation = nil
        lock.unlock()
        held?.resume(returning: fileURL)
    }
}
