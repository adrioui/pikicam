import SwiftUI

struct BastingStitchReticle: View {
    enum Mode {
        case tracking
        case locked

        var size: CGFloat {
            switch self {
            case .tracking: return 144
            case .locked: return 110
            }
        }
    }

    var mode: Mode
    var stitchColor = Palette.gesso

    var body: some View {
        ZStack(alignment: .center) {
            stitches
            Text("[ + ]")
                .font(PikicamFont.mono(.micro))
                .foregroundStyle(TextColor.muted)
        }
        .frame(width: mode.size, height: mode.size)
        .animation(.easeOut(duration: 0.2), value: mode)
        .accessibilityLabel("Focus reticle")
        .accessibilityValue(mode == .locked ? "Locked" : "Tracking")
    }

    private var stitches: some View {
        ForEach(Array(StitchArm.positions(mode: mode.size).enumerated()), id: \.offset) { _, arm in
            Rectangle()
                .fill(Palette.gesso)
                .frame(width: arm.width, height: arm.height)
                .position(arm.center)
        }
    }
}

private struct StitchArm {
    let width: CGFloat
    let height: CGFloat
    let center: CGPoint

    static func positions(mode size: CGFloat) -> [StitchArm] {
        let length: CGFloat = 20
        let thickness: CGFloat = 2
        let inset: CGFloat = 1
        let near = inset + length / 2
        var result: [StitchArm] = []
        let xs: [CGFloat] = [near, size / 2, size - near, size - near]
        let ys: [CGFloat] = [inset, inset, inset + length, size - inset - length]
        result.append(StitchArm(width: length, height: thickness, center: CGPoint(x: xs[0], y: ys[0])))
        result.append(StitchArm(width: thickness, height: length, center: CGPoint(x: xs[0], y: ys[0] + 0)))
        result.append(StitchArm(width: length, height: thickness, center: CGPoint(x: xs[1], y: ys[1])))
        result.append(StitchArm(width: thickness, height: length, center: CGPoint(x: size - near, y: ys[1])))
        result.append(StitchArm(width: length, height: thickness, center: CGPoint(x: xs[2], y: ys[2])))
        result.append(StitchArm(width: thickness, height: length, center: CGPoint(x: near, y: ys[2])))
        result.append(StitchArm(width: length, height: thickness, center: CGPoint(x: xs[3], y: ys[3])))
        result.append(StitchArm(width: thickness, height: length, center: CGPoint(x: size - near, y: ys[3])))
        return result
    }
}
