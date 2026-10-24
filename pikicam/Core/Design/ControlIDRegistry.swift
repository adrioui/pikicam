import Foundation

// MARK: - ControlID

/// Identity for every addressable control in the app.
///
/// Branded, constrained, never a bare string (§1.1). A view that needs an
/// identifier takes a `ControlID` and renders `id.rawValue`; it may not spell
/// the literal itself. A raw `accessibilityIdentifier("…")` literal that is
/// not sourced from `ControlIDRegistry` is a `DesignViolation` (§8.1), so
/// renaming a control is a one-line change here and the UI-test contract
/// cannot drift from the design.
struct ControlID: RawRepresentable, Hashable, Sendable {
    let rawValue: String

    /// `RawRepresentable` conformance — the protocol requires this exact
    /// label. Without it the type does not satisfy the protocol and the
    /// whole design layer fails to compile.
    init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// The spelling the registry uses: `ControlID("camera-shutter")`.
    /// Both labels are kept so the type reads naturally at the call site.
    init(_ rawValue: String) {
        self.init(rawValue: rawValue)
    }
}

// MARK: - ControlIDRegistry

/// The closed set of control identifiers, and the lint's iteration source.
///
/// `all` is what the design lint walks (§8.2): every identifier rendered by
/// any view must appear here, and every tappable word must additionally
/// appear in `words` so the lint can assert the identifier *and* the label
/// together.
enum ControlIDRegistry {

    // MARK: Word controls — the tappable vocabulary
    //
    // §3 camera bottom/top bars, §4 viewer bars. Every one of these is a
    // `WordControl`: a bare word, no icon, no glyph.

    // Camera room (black)
    static let cameraShutter  = ControlID("camera-shutter")   // SHOOT
    static let cameraLibrary  = ControlID("camera-library")   // LIBRARY
    static let cameraGrid     = ControlID("camera-grid")      // GRID ON|OFF
    static let cameraFlash    = ControlID("camera-flash")     // FLASH OFF|ON
    static let cameraTimer    = ControlID("camera-timer")     // TIMER OFF|3S|10S
    static let cameraFlip     = ControlID("camera-flip")      // CAMERA BACK|FRONT
    static let cameraCancel   = ControlID("camera-cancel")    // CANCEL
    static let cameraRetry    = ControlID("camera-retry")     // RETRY

    // Gallery / viewer room (white)
    static let roomShoot      = ControlID("room-shoot")       // SHOOT
    static let roomDelete     = ControlID("room-delete")      // DELETE
    static let roomRetry      = ControlID("room-retry")       // RETRY

    static let viewerBack     = ControlID("viewer-back")      // BACK
    static let viewerDelete   = ControlID("viewer-delete")    // DELETE
    static let viewerShare    = ControlID("viewer-share")     // SHARE
    /// One control, two words: the chrome toggle renders `HIDE` when the
    /// chrome is up and `SHOW` when it is down. One identity, not two.
    static let viewerHideShow = ControlID("viewer-hide-show") // HIDE|SHOW

    /// The `DNG 03 / 11` orientation readout. Not tappable — a `caption`
    /// token — but it is spoken and screenshotted, so it is registered.
    static let viewerDNG      = ControlID("viewer-dng")       // DNG

    // MARK: Non-interactive state surfaces
    //
    // Registered because a view renders them and the lint must know the
    // identifier exists; §8.2's tappable-word rule does not apply.

    // Camera room
    static let cameraPreview       = ControlID("camera-preview")
    static let cameraZoom          = ControlID("camera-zoom")
    static let cameraGridOverlay   = ControlID("camera-grid-overlay")
    static let cameraAspectMask    = ControlID("camera-aspect-mask")
    static let cameraExposure      = ControlID("camera-exposure")
    static let cameraTimerCountdown = ControlID("camera-timer-countdown")

    // Gallery / viewer room
    static let roomTitle       = ControlID("room-title")        // LIBRARY
    static let roomGrid        = ControlID("room-grid")
    static let roomLoading     = ControlID("room-loading")
    static let roomEmpty       = ControlID("room-empty")        // 0 / NO CAPTURES
    static let roomError       = ControlID("room-error")
    static let viewerLoading   = ControlID("viewer-loading")
    static let viewerFailure   = ControlID("viewer-load-failure")
    static let viewerBackground = ControlID("viewer-background")

    // MARK: Parameterized identifiers
    //
    // Families whose raw value embeds a runtime value. Each returns a
    // `ControlID`, so the interpolation still happens inside the registry and
    // a view never builds the raw string itself.

    /// One cell per grid slot, newest-first.
    static func roomCell(_ index: Int) -> ControlID {
        ControlID("room-cell-\(index)")
    }

    /// The prefix a `roomCell` identifier begins with — the lint's and the
    /// UI test's discovery handle for the grid.
    static let roomCellPrefix = "room-cell-"

    /// A quick-zoom preset chip, e.g. `camera-zoom-preset-1.0x`.
    static func cameraZoomPreset(_ label: String) -> ControlID {
        ControlID("camera-zoom-preset-\(label)")
    }

    /// An aspect-ratio chip, e.g. `camera-aspect-ratio16x9`.
    static func cameraAspect(_ rawValue: String) -> ControlID {
        ControlID("camera-aspect-\(rawValue)")
    }

    // MARK: The lint's iteration source

    /// Every registered identifier. The design lint walks this (§8.2): a
    /// view rendering an identifier outside this set is a build failure.
    static let all: [ControlID] = [
        // Word controls — camera
        cameraShutter, cameraLibrary, cameraGrid, cameraFlash, cameraTimer,
        cameraFlip, cameraCancel, cameraRetry,
        // Word controls — gallery / viewer
        roomShoot, roomDelete, roomRetry,
        viewerBack, viewerDelete, viewerShare, viewerHideShow, viewerDNG,
        // Non-interactive surfaces — camera
        cameraPreview, cameraZoom, cameraGridOverlay, cameraAspectMask,
        cameraExposure, cameraTimerCountdown,
        // Non-interactive surfaces — gallery / viewer
        roomTitle, roomGrid, roomLoading, roomEmpty, roomError,
        viewerLoading, viewerFailure, viewerBackground,
    ]

    /// Every registered identifier as a raw string, for a membership check.
    static let allRawValues: Set<String> = Set(all.map(\.rawValue))

    /// The words, paired with the identity that carries them. The lint
    /// asserts each tappable control has both an identifier in `all` and a
    /// word here — §8.2's "the identifier **and** the label/value are
    /// present".
    static let words: [(id: ControlID, word: String)] = [
        (cameraShutter, "SHOOT"),
        (cameraLibrary, "LIBRARY"),
        (cameraGrid, "GRID ON|OFF"),
        (cameraFlash, "FLASH OFF|ON"),
        (cameraTimer, "TIMER OFF|3S|10S"),
        (cameraFlip, "CAMERA BACK|FRONT"),
        (cameraCancel, "CANCEL"),
        (cameraRetry, "RETRY"),
        (roomShoot, "SHOOT"),
        (roomDelete, "DELETE"),
        (roomRetry, "RETRY"),
        (viewerBack, "BACK"),
        (viewerDelete, "DELETE"),
        (viewerShare, "SHARE"),
        (viewerHideShow, "HIDE|SHOW"),
        (viewerDNG, "DNG"),
    ]

    /// Whether `rawValue` names a registered control. A bare
    /// `accessibilityIdentifier(literal)` that returns `false` is the §8.1
    /// lint failure.
    static func isRegistered(_ rawValue: String) -> Bool {
        allRawValues.contains(rawValue)
            || familyPrefixes.contains { rawValue.hasPrefix($0) }
    }

    /// Prefixes owned by `all`'s parameterized families. `roomCell`,
    /// `cameraZoomPreset`, and `cameraAspect` cannot be enumerated ahead of
    /// time, so the lint recognizes them by prefix.
    static let familyPrefixes: [String] = [
        roomCellPrefix,
        "camera-zoom-preset-",
        "camera-aspect-",
    ]
}
