@preconcurrency import AVFoundation
import Photos
import UIKit

extension CameraEngine {
    func startRecording() async {
        guard !isRecording else { return }
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
                clipMessage = "Mono export failed; saved the untouched clip."
            }
            if ProcessInfo.processInfo.arguments.contains("-pikicam.dumpclip") {
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let sourceDest = docs.appendingPathComponent("last-source-clip.mov")
                try? FileManager.default.removeItem(at: sourceDest)
                try? FileManager.default.copyItem(at: url, to: sourceDest)
            }
            await saveClip(url)
        } else {
            clipMessage = "Recording failed."
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
            clipMessage = "Photos access denied — clip can't be saved. Allow access in Settings."
            return
        }
        WalkMark.mark("clip-save-begin")
        let saved = await Self.performVideoWrite(fileURL: url)
        WalkMark.mark(saved ? "clip-save-done" : "clip-save-failed")
        if saved {
            savedCount += 1
            clipMessage = "Clip saved."
        } else {
            clipMessage = "Saving the clip failed."
        }
        try? FileManager.default.removeItem(at: url)
    }

    nonisolated private static func performVideoWrite(fileURL: URL) async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.originalFilename = fileURL.lastPathComponent
                request.addResource(with: .video, fileURL: fileURL, options: options)
            } completionHandler: { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}
