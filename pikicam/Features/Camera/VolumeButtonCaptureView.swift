import AVFoundation
import MediaPlayer
import SwiftUI

/// Hidden volume-button observer: pressing the device's hardware volume
/// buttons triggers a camera capture. Uses `MPVolumeView` (public API)
/// so this works on any iOS device without private notifications.
///
/// Uses MPVolumeView slider observation; does NOT suppress the system
/// volume HUD — the user sees the HUD and hears the sound change. If
/// suppression is needed, add a custom volume overlay.
struct VolumeButtonCaptureView: UIViewRepresentable {
    let onVolumeChange: () -> Void

    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView()
        view.showsVolumeSlider = false
        view.frame = .zero
        view.isHidden = true
        // The volume slider is created lazily by MPVolumeView, so the
        // observer must be attached after it appears — retry for a short
        // window instead of assuming it exists immediately.
        attachSliderObserver(to: view, context: context, attempts: 10)
        return view
    }

    private func attachSliderObserver(to view: MPVolumeView, context: Context, attempts: Int) {
        for subview in view.subviews {
            if let slider = subview as? UISlider {
                slider.addTarget(context.coordinator, action: #selector(Coordinator.handleVolume), for: .valueChanged)
                return
            }
        }
        guard attempts > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak view] in
            guard let view else { return }
            self.attachSliderObserver(to: view, context: context, attempts: attempts - 1)
        }
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onVolumeChange: onVolumeChange)
    }

    final class Coordinator {
        let onVolumeChange: () -> Void
        private var lastVolume: Float = AVAudioSession.sharedInstance().outputVolume
        /// Minimum interval between accepted triggers, so holding the button
        /// (many rapid slider events) fires one capture, not a burst.
        private var lastTriggerAt: Date = .distantPast
        private static let minTriggerInterval: TimeInterval = 0.6

        init(onVolumeChange: @escaping () -> Void) {
            self.onVolumeChange = onVolumeChange
        }

        @objc func handleVolume() {
            let current = AVAudioSession.sharedInstance().outputVolume
            // Any non-zero delta means the user pressed a hardware button.
            guard abs(current - lastVolume) > 0.001 else { return }
            lastVolume = current
            let now = Date()
            guard now.timeIntervalSince(lastTriggerAt) >= Self.minTriggerInterval else { return }
            lastTriggerAt = now
            onVolumeChange()
        }
    }
}
