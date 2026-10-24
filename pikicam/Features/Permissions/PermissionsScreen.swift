import SwiftUI

@MainActor
@Observable
final class PermissionsModel {
    let deps: Dependencies
    var states: [PermissionState] = [.notDetermined, .notDetermined]

    init(deps: Dependencies) {
        self.deps = deps
    }

    func refresh() async {
        for await current in deps.permissions.states {
            states = current
            break
        }
    }

    func request(_ permission: PikicamPermission) async {
        _ = await deps.permissions.request(permission)
        await refresh()
    }

    var cameraState: PermissionState { states.indices.contains(0) ? states[0] : .notDetermined }
    var libraryState: PermissionState { states.indices.contains(1) ? states[1] : .notDetermined }

    var isCameraUsable: Bool { cameraState == .granted }
}

struct PermissionsScreen: View {
    @State private var model: PermissionsModel
    let onReady: () -> Void

    init(deps: Dependencies, onReady: @escaping () -> Void) {
        _model = State(initialValue: PermissionsModel(deps: deps))
        self.onReady = onReady
    }

    var body: some View {
        VStack(spacing: UGrid.medium) {
            Text("PERMISSIONS")
                .pikicamType(.display)
                .foregroundStyle(InkColor.muslin)
                .padding(.top, UGrid.large)

            permissionRow(
                title: "CAMERA",
                detail: "pikicam captures Bayer RAW through the camera.",
                state: model.cameraState
            ) {
                Task { await model.request(.camera) }
            }

            permissionRow(
                title: "PHOTO LIBRARY",
                detail: "pikicam stores the untouched DNG and its developed rendition in your library.",
                state: model.libraryState
            ) {
                Task { await model.request(.photoLibrary) }
            }

            Spacer()

            if model.isCameraUsable {
                BracketButton(title: "[ ENTER ]") { onReady() }
                    .padding(.bottom, UGrid.large)
            }
        }
        .padding(UGrid.medium)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PlateColor.photometricDeep)
        .task { await model.refresh() }
    }

    @ViewBuilder
    private func permissionRow(
        title: String, detail: String, state: PermissionState, onRequest: @escaping () -> Void
    ) -> some View {
        Plate {
            AnyView(
                VStack(alignment: .leading, spacing: UGrid.small) {
                    HStack {
                        Text(title)
                            .pikicamType(.title)
                            .foregroundStyle(InkColor.muslin)
                        Spacer()
                        Text("[ \(stateLabel(state)) ]")
                            .pikicamType(.label)
                            .foregroundStyle(InkColor.ash)
                    }
                    Text(detail)
                        .pikicamType(.micro)
                        .foregroundStyle(InkColor.calico)
                    if state == .notDetermined {
                        BracketButton(title: "[ ALLOW ]", action: onRequest)
                    }
                    if state == .denied || state == .restricted {
                        Text("Enable in Settings to use this feature.")
                            .pikicamType(.micro)
                            .foregroundStyle(InkColor.ash)
                    }
                }
                .padding(UGrid.small)
            )
        }
    }

    private func stateLabel(_ state: PermissionState) -> String {
        switch state {
        case .notDetermined: return "ASK"
        case .granted: return "GRANTED"
        case .limited: return "LIMITED"
        case .denied: return "DENIED"
        case .restricted: return "RESTRICTED"
        }
    }
}

enum SettingsKeys {
    static let grid = "pikicam.settings.grid"
    static let level = "pikicam.settings.level"
    static let histogram = "pikicam.settings.histogram"
    static let haptics = "pikicam.settings.haptics"
    static let badge = "pikicam.settings.badge"
}

struct SettingsScreen: View {
    @AppStorage(SettingsKeys.grid) private var grid = true
    @AppStorage(SettingsKeys.level) private var level = false
    @AppStorage(SettingsKeys.histogram) private var histogram = false
    @AppStorage(SettingsKeys.haptics) private var haptics = true
    @AppStorage(SettingsKeys.badge) private var badge = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SETTINGS")
                    .pikicamType(.title)
                    .foregroundStyle(InkColor.muslin)
                Spacer()
            }
            .padding(.horizontal, UGrid.micro)
            .frame(height: 44)
            .background(PlateColor.photometricLow)

            List {
                toggleRow("Grid", $grid)
                toggleRow("Level indicator", $level)
                toggleRow("Histogram", $histogram)
                toggleRow("Haptics", $haptics)
                toggleRow("Capture badge", $badge)
                aboutSection
            }
            .scrollContentBackground(.hidden)
        }
        .background(PlateColor.photometricDeep)
    }

    private func toggleRow(_ title: String, _ value: Binding<Bool>) -> some View {
        Toggle(title, isOn: value)
            .font(PikicamFont.mono(.readout))
            .foregroundStyle(InkColor.muslin)
            .tint(InkColor.gesso)
            .padding(.vertical, UGrid.nano)
    }

    static let aboutText = """
        pikicam captures one untouched Bayer RAW exposure — no fusion, no noise reduction, no Apple tone mapping.
        The DNG is stored exactly as the sensor wrote it. The developed rendition is pikicam's own code:
        exposure, monochrome, filmic tone curve, gamut compression.
        Video frames are always ISP output; the look is applied by pikicam to every frame.
        """

    private var aboutSection: some View {
        Section("WHAT PIKICAM DOES TO YOUR PHOTO") {
            Text(Self.aboutText)
                .pikicamType(.micro)
            .foregroundStyle(InkColor.calico)
        }
    }
}
