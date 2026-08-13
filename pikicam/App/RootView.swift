import SwiftUI
import UIKit

/// The root view of the pikicam application.
///
/// Manages the top-level navigation and permission flow.
/// Shows a permission-granting interstitial before the camera view
/// becomes active.
struct RootView: View {
    @Environment(CameraViewModel.self) private var viewModel
    @State private var didRequestPermissions = false

    var body: some View {
        Group {
            if !didRequestPermissions {
                PermissionsView(onComplete: {
                    didRequestPermissions = true
                })
            } else if !viewModel.hasRequiredAuth {
                PermissionsDeniedView()
            } else {
                CameraView()
                    // Gallery entry via lower-left thumbnail overlay on CameraView
            }
        }
        .task {
            if viewModel.hasRequiredAuth {
                didRequestPermissions = true
            }
        }
    }
}

/// Shown on first launch to request camera and photo library permissions.
struct PermissionsView: View {
    let onComplete: () -> Void
    @Environment(CameraViewModel.self) private var viewModel

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.aperture")
                .font(.system(size: 72))
                .foregroundStyle(.tint)

            Text("Welcome to pikicam")
                .font(.largeTitle.bold())

            Text("Honest photographs, one Bayer exposure at a time.\nNo AI. No computation. Just light.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Continue") {
                Task {
                    _ = await viewModel.requestAllPermissions()
                    onComplete()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
}

/// Shown when the user has denied required permissions.
struct PermissionsDeniedView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.yellow)

            Text("Permissions Required")
                .font(.largeTitle.bold())

            Text("pikicam needs camera and photo library access to function.\nPlease grant these permissions in Settings.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
}

#Preview("Permissions") {
    PermissionsView(onComplete: {})
}
