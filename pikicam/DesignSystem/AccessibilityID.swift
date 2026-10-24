// periphery:ignore
import Foundation

enum AccessibilityID {
    enum Camera {
        static let statusBadge = "camera.statusBadge"
        static let shutter = "camera.shutter"
        static let lensRail = "camera.lensRail"
        static let readoutRail = "camera.readoutRail"
        static let modeStrip = "camera.modeStrip"
        static let thumbnail = "camera.thumbnail"
        static let cropChip = "camera.cropChip"
        static let lineMatrix = "camera.lineMatrix"
        static let histogram = "camera.histogram"
        static let levelIndicator = "camera.levelIndicator"
        static let quickSettings = "camera.quickSettings"
        static let recordControl = "camera.recordControl"
    }

    enum Manual {
        static let panel = "manual.panel"
        static let isoDial = "manual.isoDial"
        static let shutterDial = "manual.shutterDial"
        static let wbDial = "manual.wbDial"
        static let focusDial = "manual.focusDial"
    }

    enum Library {
        static let grid = "library.grid"
        static let cell = "library.cell"
    }

    enum Viewer {
        static let pager = "viewer.pager"
        static let infoButton = "viewer.infoButton"
        static let developButton = "viewer.developButton"
        static let shareButton = "viewer.shareButton"
        static let deleteButton = "viewer.deleteButton"
        static let revertButton = "viewer.revertButton"
    }
}
