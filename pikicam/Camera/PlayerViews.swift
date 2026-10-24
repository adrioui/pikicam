import AVFoundation
import Photos
import SwiftUI
import UIKit

struct PlayerSurface: UIViewRepresentable {
    let player: AVQueuePlayer

    final class SurfaceView: UIView {
        override static var layerClass: AnyClass {
            AVPlayerLayer.self
        }

        var playerLayer: AVPlayerLayer {
            unsafeDowncast(layer, to: AVPlayerLayer.self)
        }
    }

    func makeUIView(context: Context) -> SurfaceView {
        let view = SurfaceView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ uiView: SurfaceView, context: Context) {
        uiView.playerLayer.player = player
    }
}

struct PlayerBar: UIViewRepresentable {
    let player: AVQueuePlayer

    func makeCoordinator() -> ObserverBox {
        ObserverBox()
    }

    func makeUIView(context: Context) -> UIStackView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.backgroundColor = .black
        stack.isOpaque = true
        stack.translatesAutoresizingMaskIntoConstraints = false
        let toggle = Self.makeToggle(player: player)
        let scrubber = Self.makeScrubber(player: player, coordinator: context.coordinator)
        stack.addArrangedSubview(toggle)
        stack.addArrangedSubview(scrubber)
        toggle.widthAnchor.constraint(equalToConstant: 88).isActive = true
        return stack
    }

    private static func makeToggle(player: AVQueuePlayer) -> UIButton {
        let toggle = UIButton(type: .system)
        toggle.setTitle("PLAY", for: .normal)
        toggle.setTitleColor(.white, for: .normal)
        toggle.titleLabel?.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        toggle.isAccessibilityElement = true
        toggle.accessibilityLabel = "Play or pause"
        toggle.addAction(UIAction { _ in
            if player.timeControlStatus == .playing {
                player.pause()
            } else {
                player.play()
            }
            let playing = player.timeControlStatus == .playing
            toggle.setTitle(playing ? "PAUSE" : "PLAY", for: .normal)
        }, for: .touchUpInside)
        return toggle
    }

    private static func makeScrubber(
        player: AVQueuePlayer, coordinator: ObserverBox
    ) -> UISlider {
        let scrubber = UISlider()
        scrubber.minimumValue = 0
        scrubber.maximumValue = 1
        scrubber.isAccessibilityElement = true
        scrubber.accessibilityLabel = "Scrub"
        let box = ScrubberBox(slider: scrubber)
        coordinator.player = player
        coordinator.token = player.addPeriodicTimeObserver(
            forInterval: CMTime(value: 1, timescale: 4), queue: .main
        ) { time in
            DispatchQueue.main.async {
                box.slider.value = Float(time.seconds)
                if let duration = player.currentItem?.duration.seconds, duration.isFinite, duration > 0 {
                    box.slider.maximumValue = Float(duration)
                }
            }
        }
        scrubber.addAction(UIAction { _ in
            player.seek(to: CMTime(seconds: Double(scrubber.value), preferredTimescale: 600))
        }, for: .valueChanged)
        return scrubber
    }

    func updateUIView(_ uiView: UIStackView, context: Context) {}

    static func dismantleUIView(_ uiView: UIStackView, coordinator: ObserverBox) {
        coordinator.stop()
    }
}

final class ObserverBox {
    var token: Any?
    weak var player: AVQueuePlayer?

    func stop() {
        if let token, let player {
            player.removeTimeObserver(token)
        }
        token = nil
    }
}

final class ScrubberBox: @unchecked Sendable {
    let slider: UISlider

    init(slider: UISlider) {
        self.slider = slider
    }
}
