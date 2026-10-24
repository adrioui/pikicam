import SwiftUI

struct CameraScreen: View {
    @State private var model: CameraModel
    @Environment(\.scenePhase) private var scenePhase

    init(deps: Dependencies) {
        _model = State(initialValue: CameraModel(deps: deps))
    }

    var body: some View {
        VStack(spacing: 0) {
            statusPlate
            ZStack {
                Viewfinder(
                    source: model.deps.capture.preview,
                    geometry: modelGeometry,
                    showGrid: false
                )
                BastingStitchReticle(mode: .tracking)
            }
            .frame(maxHeight: .infinity)
            readoutRail
            lensRail
            lineMatrix
            dock
        }
        .background(SurfaceColor.surface)
        .preferredColorScheme(.dark)
        .task { await model.start() }
        .onDisappear { model.stop() }
        .fullScreenCover(isPresented: $model.isLibraryPresented) {
            LibraryScreen(deps: model.deps)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task { await model.start() }
            case .background:
                model.stop()
            default:
                break
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var modelGeometry: FrameGeometry {
        let dims = model.capabilities?.rawDimensions ?? CGSize(width: 4032, height: 3024)
        return FrameGeometry(
            aspect: model.settings.aspect, crop: model.settings.crop,
            sensorWidth: dims.width, sensorHeight: dims.height
        )
    }

    private var statusPlate: some View {
        HStack {
            Text(model.statusBadge)
                .font(PikicamFont.mono(.telemetry))
                .foregroundStyle(Palette.muslin)
            Spacer()
            BracketButton(title: "[ QS ]", accessibilityID: AccessibilityID.Camera.quickSettings) {
                model.isLevelsVisible.toggle()
            }
        }
        .padding(.horizontal, UGrid.micro)
        .frame(height: 44)
        .background(SurfaceColor.low)
    }

    private var readoutRail: some View {
        CareLabelStrip(telemetry: CareLabelStrip.Telemetry(
            focal: model.capabilities?.lens(model.settings.lens)?.equivalentFocalLength ?? 26,
            aperture: String(format: "F/%.2F", model.capabilities?.lens(model.settings.lens).map { _ in 1.8 } ?? 1.8),
            shutter: "AUTO",
            iso: 0,
            kelvin: 5600
        ))
        .padding(.horizontal, UGrid.micro)
        .frame(height: 56)
        .background(SurfaceColor.low)
    }

    private var lensRail: some View {
        HStack {
            TurretFocalSelector(
                lenses: model.capabilities?.lenses ?? [],
                selected: model.settings.lens,
                onSelect: { kind in
                    Task { await model.selectLens(kind) }
                }
            )
            Spacer()
            BracketButton(title: "CROP", accessibilityID: AccessibilityID.Camera.cropChip) {
                let next = model.settings.crop >= 4 ? 1 : model.settings.crop * 2
                model.settings.crop = next
            }
        }
        .padding(.horizontal, UGrid.micro)
        .frame(height: 52)
    }

    private var lineMatrix: some View {
        NumericLineMatrix(
            active: model.activeLine,
            dormantNumbers: Set(LineProfile.table.filter(\.isDormant).map(\.number)),
            onSelect: { model.selectLine($0) }
        )
        .frame(height: 44)
    }

    private var dock: some View {
        HStack {
            thumbnail
            Spacer()
            GessoShutterActuator(state: model.shutterState) {
                Task { await model.pressShutter() }
            }
            Spacer()
            modeStrip
        }
        .padding(.horizontal, UGrid.medium)
        .frame(height: 96)
        .background(SurfaceColor.low)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = model.lastThumbnail, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable().scaledToFill()
                .frame(width: 64, height: 64)
                .clipped()
                .overlay(Rectangle().strokeBorder(Palette.ash, lineWidth: UGrid.hairline))
                .accessibilityIdentifier(AccessibilityID.Camera.thumbnail)
                .accessibilityLabel("Last capture")
                .onTapGesture { model.isLibraryPresented = true }
        } else {
            Rectangle()
                .fill(SurfaceColor.elevated)
                .frame(width: 64, height: 64)
                .overlay(Rectangle().strokeBorder(Palette.ash.opacity(0.5), lineWidth: UGrid.hairline))
                .accessibilityLabel("No captures yet")
                .onTapGesture { model.isLibraryPresented = true }
        }
    }

    private var modeStrip: some View {
        HStack(spacing: UGrid.nano) {
            ForEach(CameraModel.Mode.allCases, id: \.self) { mode in
                let selected = mode == model.mode
                Button {
                    model.mode = mode
                } label: {
                    Text(mode.rawValue.uppercased())
                        .font(PikicamFont.mono(.micro))
                        .foregroundStyle(selected ? SurfaceColor.surface : Palette.calico)
                        .padding(.horizontal, UGrid.micro)
                        .frame(minHeight: 44)
                        .background(selected ? Palette.gesso : Color.clear)
                        .overlay(Rectangle().strokeBorder(Palette.ash.opacity(0.6), lineWidth: UGrid.hairline))
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityIdentifier("camera.mode.\(mode.rawValue)")
                .accessibilityLabel("\(mode.rawValue) mode")
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }

    }
}
