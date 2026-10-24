@preconcurrency import AVFoundation
import Photos
import SwiftUI
import UIKit

struct CaptureResult: Sendable {
    let data: Data
    let isDNG: Bool
    let timestamp: Date
}

@MainActor
@Observable
final class CameraEngine {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "piki.pikicam.session", qos: .userInitiated)
    private var isConfigured = false
    private var pending: PendingCapture?

    private(set) var isRunning = false
    private(set) var isCapturing = false
    private(set) var lastMessage: String?
    private(set) var photosDenied = false
    private(set) var lastCapture: CaptureResult?
    private(set) var savedCount = 0

    func start() async {
        guard AVCaptureDevice.authorizationStatus(for: .video) != .denied else {
            lastMessage = "Camera access denied. Enable it in Settings to shoot."
            return
        }
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            lastMessage = "Camera access denied. Enable it in Settings to shoot."
            return
        }
        guard !isConfigured else {
            await beginRunning()
            return
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [session, photoOutput] in
                session.beginConfiguration()
                session.sessionPreset = .photo
                if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                    let input = try? AVCaptureDeviceInput(device: device),
                    session.canAddInput(input)
                {
                    session.addInput(input)
                }
                if session.canAddOutput(photoOutput) {
                    session.addOutput(photoOutput)
                }
                session.commitConfiguration()
                continuation.resume()
            }
        }
        isConfigured = true
        await beginRunning()
    }

    private func beginRunning() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [session] in
                if !session.isRunning {
                    session.startRunning()
                }
                continuation.resume()
            }
        }
        let nowRunning = session.isRunning
        if nowRunning && !isRunning {
            WalkMark.mark("preview-started")
        }
        isRunning = nowRunning
    }


    nonisolated private static func performPhotoWrite(
        _ change: @escaping @Sendable (PHAssetCreationRequest) -> Void
    ) async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            PHPhotoLibrary.shared().performChanges {
                change(PHAssetCreationRequest.forAsset())
            } completionHandler: { success, _ in
                continuation.resume(returning: success)
            }
        }
    }

    func stopForBackground() {
        sessionQueue.async { [session] in
            if session.isRunning {
                session.stopRunning()
            }
        }
        isRunning = false
    }

    var bayerPixelFormat: OSType? {
        photoOutput.availableRawPhotoPixelFormatTypes.first(where: {
            AVCapturePhotoOutput.isBayerRAWPixelFormat($0)
        })
    }

    func capturePhoto() async -> CaptureResult? {
        guard !isCapturing else { return nil }
        isCapturing = true
        defer { isCapturing = false }
        let settings: AVCapturePhotoSettings
        if let raw = bayerPixelFormat {
            settings = AVCapturePhotoSettings(rawPixelFormatType: raw)
        } else {
            settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        }
        settings.photoQualityPrioritization = .speed
        let box = PendingCapture()
        pending = box
        let outcome = await withCheckedContinuation { continuation in
            box.resume(with: continuation)
            photoOutput.capturePhoto(with: settings, delegate: box)
        }
        pending = nil
        switch outcome {
        case .failure(let reason):
            lastMessage = "Capture failed: \(reason)"
            return nil
        case .success(let photo):
            guard let data = photo.fileDataRepresentation() else {
                lastMessage = "Capture failed: no file data"
                return nil
            }
            let result = CaptureResult(data: data, isDNG: photo.isRawPhoto, timestamp: Date())
            lastCapture = result
            return result
        }
    }

    func saveToPhotos(_ result: CaptureResult) async {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        let granted: PHAuthorizationStatus
        if status == .notDetermined {
            granted = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        } else {
            granted = status
        }
        guard granted == .authorized || granted == .limited else {
            photosDenied = true
            lastMessage = "Photos access denied — captures can't be saved. Allow access in Settings."
            return
        }
        photosDenied = false
        WalkMark.mark("save-begin")
        let timestamp = result.timestamp
        let data = result.data
        let isDNG = result.isDNG
        let saved = await Self.performPhotoWrite { request in
            request.creationDate = timestamp
            let options = PHAssetResourceCreationOptions()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let kind = isDNG ? "dng" : "heic"
            options.originalFilename = "PIKI_\(formatter.string(from: timestamp)).\(kind)"
            request.addResource(with: .photo, data: data, options: options)
        }
        WalkMark.mark(saved ? "save-done" : "save-failed")
        if saved {
            savedCount += 1
            lastMessage = nil
        } else {
            lastMessage = "Saving to Photos failed. Try again."
        }
    }
}

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
            layer as! AVCaptureVideoPreviewLayer
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
