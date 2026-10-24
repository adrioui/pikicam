import SwiftUI

struct BracketButton: View {
    let title: String
    var accessibilityID: String = ""
    var action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .pikicamType(.label)
                .foregroundStyle(pressed ? InkColor.gesso : InkColor.calico)
                .padding(.horizontal, UGrid.micro)
                .frame(minWidth: MinTouchTarget.control, minHeight: MinTouchTarget.control)
                .background(
                    Rectangle()
                        .strokeBorder(InkColor.ash.opacity(0.6), lineWidth: UGrid.hairline)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier(accessibilityID)
        .accessibilityLabel(title)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: UMotion.duration(for: "focusSnap", reduceMotion: false) / 1000)) {
                pressed = pressing
            }
        }, perform: {})
    }
}

struct Plate: View {
    let content: AnyView

    init(@ViewBuilder content: () -> AnyView) {
        self.content = content()
    }

    var body: some View {
        content
            .background(PlateColor.photometricLow)
            .overlay(
                Rectangle().strokeBorder(PlateColor.carbon, lineWidth: UGrid.hairline)
            )
    }
}

struct CareLabelStrip: View {
    let entries: [String]

    var body: some View {
        HStack(spacing: UGrid.micro) {
            ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                Text(entry)
                    .pikicamType(.readout)
                    .foregroundStyle(InkColor.muslin)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct GessoShutterActuator: View {
    let state: ShutterState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(shutterFill)
                    .frame(width: MinTouchTarget.shutter, height: MinTouchTarget.shutter)
                Circle()
                    .strokeBorder(InkColor.ash, lineWidth: UGrid.hairline)
                    .frame(width: MinTouchTarget.shutter + UGrid.nano, height: MinTouchTarget.shutter + UGrid.nano)
                if case .countdown(let remaining) = state {
                    Text("\(remaining)")
                        .pikicamType(.display)
                        .foregroundStyle(PlateColor.photometricDeep)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier(AccessibilityID.Camera.shutter)
        .accessibilityLabel("Shutter")
        .accessibilityValue(shutterValue)
        .accessibilityAddTraits(.isButton)
    }

    private var shutterFill: Color {
        switch state {
        case .ready, .pressed: return InkColor.gesso
        case .countdown: return InkColor.gesso.opacity(0.85)
        case .capturing: return InkColor.gesso
        case .saving: return InkColor.calico
        case .failed: return PlateColor.carbon
        }
    }

    private var shutterValue: String {
        switch state {
        case .ready: return "Ready"
        case .pressed: return "Pressed"
        case .countdown: return "Counting down"
        case .capturing: return "Capturing"
        case .saving: return "Saving"
        case .failed: return "Failed"
        }
    }
}

struct TurretFocalSelector: View {
    let lenses: [Lens]
    let selected: LensKind
    let onSelect: (LensKind) -> Void

    var body: some View {
        HStack(spacing: UGrid.nano) {
            ForEach(lenses, id: \.uniqueID) { lens in
                let isSelected = lens.kind == selected
                Button {
                    onSelect(lens.kind)
                } label: {
                    Text("\(lens.equivalentFocalLength)MM")
                        .pikicamType(.label)
                        .foregroundStyle(isSelected ? PlateColor.photometricDeep : InkColor.calico)
                        .padding(.horizontal, UGrid.micro)
                        .frame(minHeight: MinTouchTarget.control)
                        .background(isSelected ? InkColor.gesso : Color.clear)
                        .overlay(
                            Rectangle().strokeBorder(InkColor.ash.opacity(0.6), lineWidth: UGrid.hairline)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityIdentifier("camera.lens.\(lens.kind.rawValue)")
                .accessibilityLabel("\(lens.equivalentFocalLength) millimetre lens")
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }

    }
}

struct NumericLineMatrix: View {
    let lines: [LineProfile]
    let active: Int?
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: UGrid.nano) {
                ForEach(lines, id: \.number) { line in
                    lineChip(line)
                }
            }
            .padding(.horizontal, UGrid.micro)
        }
        .frame(height: MinTouchTarget.control)
        .accessibilityIdentifier(AccessibilityID.Camera.lineMatrix)
    }

    @ViewBuilder
    private func lineChip(_ line: LineProfile) -> some View {
        let isActive = line.number == active
        let label = "N° \(String(format: "%02d", line.number)) \(line.name)"
        if line.isDormant {
            Text(label)
                .pikicamType(.micro)
                .foregroundStyle(InkColor.ash.opacity(0.5))
                .padding(.horizontal, UGrid.micro)
                .frame(height: MinTouchTarget.control)
                .overlay(Rectangle().strokeBorder(InkColor.ash.opacity(0.3), lineWidth: UGrid.hairline))
                .accessibilityHint(line.dormantReason ?? "Dormant line")
        } else {
            Button {
                onSelect(line.number)
            } label: {
                Text(label)
                    .pikicamType(.micro)
                    .foregroundStyle(isActive ? PlateColor.photometricDeep : InkColor.calico)
                    .padding(.horizontal, UGrid.micro)
                    .frame(height: MinTouchTarget.control)
                    .background(isActive ? InkColor.gesso : Color.clear)
                    .overlay(Rectangle().strokeBorder(InkColor.ash.opacity(0.6), lineWidth: UGrid.hairline))
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(label)
            .accessibilityAddTraits(isActive ? [.isSelected] : [])
        }
    }
}

struct ErrorBanner: View {
    let title: String
    let detail: String
    let onDismiss: () -> Void

    var body: some View {
        Plate {
            AnyView(
                HStack {
                    VStack(alignment: .leading, spacing: UGrid.nano) {
                        Text(title)
                            .pikicamType(.label)
                            .foregroundStyle(InkColor.gesso)
                        Text(detail)
                            .pikicamType(.micro)
                            .foregroundStyle(InkColor.calico)
                    }
                    Spacer()
                    Button(action: onDismiss) {
                        Text("[ DISMISS ]")
                            .pikicamType(.micro)
                            .foregroundStyle(InkColor.gesso)
                            .frame(minWidth: MinTouchTarget.control, minHeight: MinTouchTarget.control)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("Dismiss error")
                }
                .padding(UGrid.micro)
            )
        }
    }
}
