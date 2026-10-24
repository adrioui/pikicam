@preconcurrency import AVFoundation
import Photos
import UIKit
import SwiftUI

struct CaptureResult: Sendable {
    let data: Data
    let isDNG: Bool
    let timestamp: Date
}

@MainActor
@Observable
final class CameraEngine {
    enum Mode: String, CaseIterable {
        case photo
        case video
    }

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    let movieOutput = AVCaptureMovieFileOutput()
    let sessionQueue = DispatchQueue(label: "piki.pikicam.session", qos: .userInitiated)
    private var isConfigured = false
    private var pending: PendingCapture?

    var isRunning = false
    var isCapturing = false
    var lastMessage: String?
    var photosDenied = false
    var lastCapture: CaptureResult?
    var savedCount = 0
    var isRecording = false
    var recordingStarted: Date?
    var clipMessage: String?
    var mode: Mode = .photo
    var isMonoOn = false
    var movieDelegate: MovieRecorderBox?
    var audioInput: AVCaptureDeviceInput?

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
            sessionQueue.async { [session, photoOutput, movieOutput] in
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
                if session.canAddOutput(movieOutput) {
                    session.addOutput(movieOutput)
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

    final class CreationBox: @unchecked Sendable {
        var created: String?
    }

    nonisolated private static func performPhotoWrite(
        _ change: @escaping @Sendable (PHAssetCreationRequest) -> Void
    ) async -> String? {
        let box = CreationBox()
        return await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                change(request)
                box.created = request.placeholderForCreatedAsset?.localIdentifier
            } completionHandler: { success, _ in
                continuation.resume(returning: success ? box.created : nil)
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
        guard let createdID = await persist(result) else {
            lastMessage = "Saving to Photos failed. Try again."
            return
        }
        savedCount += 1
        lastMessage = nil
        if let album = try? await Archive.ensureAlbum() {
            try? await Archive.add(createdID, to: album)
        }
    }

    private func persist(_ result: CaptureResult) async -> String? {
        var toSave = result
        if isMonoOn, let heic = await Look.monochromeHEIC(from: result.data) {
            WalkMark.mark("mono-develop-done")
            toSave = CaptureResult(data: heic, isDNG: false, timestamp: result.timestamp)
        }
        let result = toSave
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
            return nil
        }
        photosDenied = false
        WalkMark.mark("save-begin")
        let timestamp = result.timestamp
        let data = result.data
        let isDNG = result.isDNG
        let createdID = await Self.performPhotoWrite { request in
            request.creationDate = timestamp
            let options = PHAssetResourceCreationOptions()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let kind = isDNG ? "dng" : "heic"
            options.originalFilename = "PIKI_\(formatter.string(from: timestamp)).\(kind)"
            request.addResource(with: .photo, data: data, options: options)
        }
        WalkMark.mark(createdID != nil ? "save-done" : "save-failed")
        return createdID
    }
}
