@preconcurrency import AVFoundation
import CryptoKit
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
    private(set) var usingFrontCamera = false
    var movieDelegate: MovieRecorderBox?
    var audioInput: AVCaptureDeviceInput?

    func flipCamera() async {
        usingFrontCamera.toggle()
        guard isConfigured else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let position: AVCaptureDevice.Position = usingFrontCamera ? .front : .back
            let wideType: AVCaptureDevice.DeviceType = .builtInWideAngleCamera
            let queue = sessionQueue
            let session = self.session
            queue.async {
                session.beginConfiguration()
                for input in session.inputs {
                    session.removeInput(input)
                }
                if let device = AVCaptureDevice.default(wideType, for: .video, position: position),
                    let input = try? AVCaptureDeviceInput(device: device),
                    session.canAddInput(input)
                {
                    session.addInput(input)
                }
                session.commitConfiguration()
                continuation.resume()
            }
        }
        WalkMark.mark(usingFrontCamera ? "flip-front" : "flip-back")
    }

    func start() async {
        guard AVCaptureDevice.authorizationStatus(for: .video) != .denied else {
            lastMessage = "CAMERA ACCESS IS OFF. TURN ON ACCESS IN SETTINGS."
            return
        }
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            lastMessage = "CAMERA ACCESS IS OFF. TURN ON ACCESS IN SETTINGS."
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

    struct ManifestEntry: Codable {
        let assetID: String
        let sha256: String
        let bytes: Int
        let recordedAt: Date
    }

    final class CreationBox: @unchecked Sendable {
        var created: String?
    }

    nonisolated private static func appendManifest(assetID: String, data: Data) {
        let digest = SHA256.hash(data: data)
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent("integrity-manifest.json")
        var entries = (try? JSONDecoder().decode([ManifestEntry].self, from: Data(contentsOf: url))) ?? []
        entries.append(ManifestEntry(
            assetID: assetID, sha256: hex, bytes: data.count, recordedAt: Date()
        ))
        if let encoded = try? JSONEncoder().encode(entries) {
            try? encoded.write(to: url, options: [.atomic])
        }
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
                lastMessage = "CAPTURE FAILED. TRY AGAIN."
                return nil
            }
            let result = CaptureResult(data: data, isDNG: photo.isRawPhoto, timestamp: Date())
            lastCapture = result
            return result
        }
    }

    func saveToPhotos(_ result: CaptureResult) async {
        guard let createdID = await persist(result) else {
            lastMessage = "SAVE FAILED. TRY AGAIN."
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
            lastMessage = "PHOTOS ACCESS IS OFF. CAPTURES DO NOT SAVE. TURN ON ACCESS IN SETTINGS."
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
        if let createdID {
            Self.appendManifest(assetID: createdID, data: data)
        }
        return createdID
    }
}
