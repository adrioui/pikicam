import SwiftUI

struct RootView: View {
    let dependencies: Dependencies

    var body: some View {
        ZStack {
            Color(hex: 0x080808).ignoresSafeArea()
            VStack(spacing: UGrid.small) {
                Text("PIKICAM")
                    .pikicamType(.display)
                    .foregroundStyle(InkColor.muslin)
                Text("REBUILD SKELETON — PHASE 1")
                    .pikicamType(.label)
                    .foregroundStyle(InkColor.ash)
            }
        }
        .tint(InkColor.gesso)
    }
}
