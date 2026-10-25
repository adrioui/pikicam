@preconcurrency import AVFoundation
import Photos
import UIKit

extension CameraEngine {
    func startRecording() async {
        guard !isRecording, isRunning else {
            clipMessage = isRecording ? clipMessage : "Camera not ready."
            return
        }
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        }
        await attachMicIfNeeded()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("piki-clip-\(UUID().uuidString).mov")
        let box = MovieRecorderBox()
        movieDelegate = box
        movieOutput.startRecording(to: url, recordingDelegate: box)
        isRecording = true
        recordingStarted = Date()
        WalkMark.mark("record-started")
    }

    private func attachMicIfNeeded() async {
        guard audioInput == nil,
            AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
            let mic = AVCaptureDevice.default(for: .audio),
            let input = try? AVCaptureDeviceInput(device: mic)
        else {
            clipMessage = audioInput == nil && AVCaptureDevice.authorizationStatus(for: .audio) != .authorized
                ? "Mic off — clip will have no sound." : clipMessage
            return
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [session] in
                session.beginConfiguration()
                if session.canAddInput(input) {
                    session.addInput(input)
                }
                session.commitConfiguration()
                continuation.resume()
            }
        }
        audioInput = input
    }

    func stopRecording() async {
        guard isRecording else { return }
        WalkMark.mark("record-stop-requested")
        let monoWasOn = isMonoOn
        let box = movieDelegate
        movieOutput.stopRecording()
        if let url = await box?.finishedURL() {
            WalkMark.mark("record-file-ready")
            if monoWasOn {
                WalkMark.mark("mono-export-begin")
                if let rendition = await ClipLookExporter.monochromeVersion(of: url) {
                    WalkMark.mark("mono-export-done")
                    if ProcessInfo.processInfo.arguments.contains("-pikicam.dumpclip") {
                        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        let monoDest = docs.appendingPathComponent("last-mono-clip.mov")
                        let sourceDest = docs.appendingPathComponent("last-source-clip.mov")
                        try? FileManager.default.removeItem(at: monoDest)
                        try? FileManager.default.copyItem(at: rendition, to: monoDest)
                        try? FileManager.default.copyItem(at: url, to: sourceDest)
                    }
                    await saveClip(rendition)
                    try? FileManager.default.removeItem(at: url)
                    return
                }
                clipMessage = "MONO EXPORT FAILED. THE CLIP SAVED WITHOUT MONO."
            }
            if ProcessInfo.processInfo.arguments.contains("-pikicam.dumpclip") {
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let sourceDest = docs.appendingPathComponent("last-source-clip.mov")
                try? FileManager.default.removeItem(at: sourceDest)
                try? FileManager.default.copyItem(at: url, to: sourceDest)
            }
            await saveClip(url)
        } else {
            clipMessage = "RECORD FAILED. START AGAIN."
        }
        isRecording = false
        recordingStarted = nil
    }

    func handleAppBackground() async {
        guard isRecording else { return }
        let taskID = UIApplication.shared.beginBackgroundTask(withName: "clip-save")
        await stopRecording()
        if taskID != .invalid {
            UIApplication.shared.endBackgroundTask(taskID)
        }
    }

    private func saveClip(_ url: URL) async {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            photosDenied = true
            clipMessage = "PHOTOS ACCESS IS OFF. THE CLIP DID NOT SAVE. TURN ON ACCESS IN SETTINGS."
            return
        }
        WalkMark.mark("clip-save-begin")
        ArchiveDiag.beginWitness(verb: "video")
        let createdID = await Self.performVideoWrite(fileURL: url)
        WalkMark.mark(createdID != nil ? "clip-save-done" : "clip-save-failed")
        if let createdID {
            savedCount += 1
            clipMessage = "CLIP SAVED."
            if let album = try? await Archive.ensureAlbum() {
                try? await Archive.add(createdID, to: album)
            }
        } else {
            clipMessage = "SAVE FAILED. RECORD AGAIN."
        }
        let savedID = createdID
        Task.detached(priority: .utility) {
            await ArchiveDiag.endWitness(verb: "video", createdID: savedID)
        }
        try? FileManager.default.removeItem(at: url)
    }

    nonisolated private static func performVideoWrite(fileURL: URL) async -> String? {
        let box = CameraEngine.CreationBox()
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd_HHmmss"
                options.originalFilename = "PIKI_\(formatter.string(from: Date())).mov"
                request.addResource(with: .video, fileURL: fileURL, options: options)
                box.created = request.placeholderForCreatedAsset?.localIdentifier
            } completionHandler: { success, _ in
                continuation.resume(returning: success ? box.created : nil)
            }
        }
    }
}
