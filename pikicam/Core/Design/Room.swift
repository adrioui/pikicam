import SwiftUI

// MARK: - Room
//
// §2.1: `enum Room { case black, white }`. Exactly two values — a room is a
// *polarity*, not a theme. Naming it `Room` and not after any house is the
// cheapest and sharpest move in the design: the critic's point is that
// shipping the author's name in every view file is the opposite of anonymity
// (§9 bullet 4, §0.4 last row).
//
// DEFAULT IS `.black`. A view that forgets `.environment(\.room, …)` therefore
// lands in the black room rather than in an undefined state — and the lint's
// room-coverage assertion (§1.5) fails on the omission, so the default is a
// safe landing, never a silent success.

enum Room: Sendable, CaseIterable {
    case black
    case white
}

// MARK: - Environment

extension EnvironmentValues {
    /// The room the current view tree draws in. Default `.black`.
    var room: Room {
        get { self[RoomKey.self] }
        set { self[RoomKey.self] = newValue }
    }
}

private struct RoomKey: EnvironmentKey {
    static let defaultValue: Room = .black
}