import Foundation
import os

enum WalkMark {
    static let logger = Logger(subsystem: "piki.pikicam", category: "walk")
    private static let stamp = DateFormatter()
    private static let queue = DispatchQueue(label: "piki.pikicam.walkmarks")
    private static var url: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("walk-marks.log")
    }

    static func mark(_ step: String) {
        let line = "\(Date().timeIntervalSince1970) \(step)"
        logger.notice("WALK \(step, privacy: .public)")
        queue.sync {
            let handle = FileHandle(forWritingAtPath: url.path) ?? FileHandle.standardError
            if let file = try? FileHandle(forWritingTo: url) {
                file.seekToEndOfFile()
                file.write(Data((line + "\n").utf8))
                try? file.close()
            } else {
                try? Data((line + "\n").utf8).write(to: url)
            }
            _ = handle
        }
    }

    static func reset() {
        try? Data().write(to: url)
        mark("marks-reset")
    }
}
