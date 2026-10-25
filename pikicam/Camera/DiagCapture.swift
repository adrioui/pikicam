import SwiftUI
import UIKit

enum DiagCapture {
    @MainActor
    static func run() async {
        WalkMark.mark("diag-capture-begin")
        let engine = CameraEngine()
        await engine.start()
        for round in 1...2 {
            var capture = await engine.capturePhoto()
            var source = "camera"
            if capture == nil, !engine.session.isRunning {
                source = "synthetic"
                capture = Self.synthetic()
            }
            guard let shot = capture else {
                WalkMark.mark("diag-round-\(round)-no-frame")
                try? await Task.sleep(nanoseconds: 12_000_000_000)
                continue
            }
            WalkMark.mark("diag-round-\(round)-source-\(source)")
            await engine.saveToPhotos(shot)
            try? await Task.sleep(nanoseconds: 12_000_000_000)
        }
        if let consolidation = await Archive.consolidateIfNeeded() {
            WalkMark.mark(
                "diag-consolidation-moved-\(consolidation.moved)"
                + "-deleted-\(consolidation.deleted)-complete-\(consolidation.complete)"
            )
        }
        ArchiveDiag.dumpFetch(reason: "post-consolidation")
        if let verdict = ArchiveScreen.readPathVerdict() {
            WalkMark.mark("diag-verdict-\(verdict)")
        }
        try? await Task.sleep(nanoseconds: 600_000_000_000)
    }

    private static func synthetic() -> CaptureResult? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 1600))
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1200, height: 1600))
            UIColor.black.setFill()
            ctx.fill(CGRect(x: 100, y: 100, width: 1000, height: 1400))
        }
        guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
        return CaptureResult(data: data, isDNG: false, timestamp: Date())
    }
}
