import AVFoundation
import MediaPlayer
import SwiftUI

/// Hidden volume-button observer: pressing the device's hardware volume
/// buttons triggers a camera capture. Uses `MPVolumeView` (public API)
/// so this works on any iOS device without private notifications.
///
/// # ponytail: uses MPVolumeView slider observation; does NOT suppress
/// the system volume HUD — user sees the HUD and hears the sound change.
/// If suppression is needed, add a custom volume overlay.
struct VolumeButtonCaptureView: UIViewRepresentable {
    let onVolumeChange: () -> Void

    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView()
        view.showsVolumeSlider = false
        view.frame = .zero
        view.isHidden = true
        // Observe the embedded slider for value-change events.
        for subview in view.subviews {
            if let slider = subview as? UISlider {
                slider.addTarget(context.coordinator, action: #selector(Coordinator.handleVolume), for: .valueChanged)
            }
        }
        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onVolumeChange: onVolumeChange)
    }

    final class Coordinator {
        let onVolumeChange: () -> Void
        private var lastVolume: Float = AVAudioSession.sharedInstance().outputVolume

        init(onVolumeChange: @escaping () -> Void) {
            self.onVolumeChange = onVolumeChange
        }

        @objc func handleVolume() {
            let current = AVAudioSession.sharedInstance().outputVolume
            // Any non-zero delta means the user pressed a hardware button.
            if abs(current - lastVolume) > 0.001 {
                lastVolume = current
                onVolumeChange()
            }
        }
    }
}
