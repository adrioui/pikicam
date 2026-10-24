import CoreImage
import SwiftUI

@MainActor
@Observable
final class ViewerModel {
    let deps: Dependencies
    let item: LibraryItem

    var display: DisplayImage?
    var developError: String?
    var look = LookParameters()
    var isDeveloping = false
    var provenanceSummary: String = ""
    var mono: MonoState?
    var activeLine: Int?

    private var renderTask: Task<Void, Never>?
    private var cachedDNG: Data?

    init(deps: Dependencies, item: LibraryItem) {
        self.deps = deps
        self.item = item
    }

    func load() async {
        await render()
    }

    func render() async {
        renderTask?.cancel()
        let task = Task { [weak self] in
            guard let self else { return }
            self.isDeveloping = true
            defer { self.isDeveloping = false }
            do {
                let dng = try await self.dngData()
                let facts = try await self.deps.developer.inspect(dng)
                let geometry = FrameGeometry(
                    aspect: self.look.line == nil ? .native : .native, crop: 1,
                    sensorWidth: Double(facts.width), sensorHeight: Double(facts.height)
                )
                let image = try await self.deps.developer.image(
                    dng, look: self.currentLook(), geometry: geometry,
                    target: .display(pixelSize: CGSize(width: 1024, height: 768))
                )
                if !Task.isCancelled {
                    self.display = image
                    self.developError = nil
                    self.provenanceSummary = Self.summarize(facts)
                }
            } catch {
                if !Task.isCancelled {
                    self.developError = "\(error)"
                }
            }
        }
        renderTask = task
        await task.value
    }

    private func dngData() async throws -> Data {
        if let cachedDNG { return cachedDNG }
        let data = try await deps.library.dng(for: item.id)
        cachedDNG = data
        return data
    }

    private func currentLook() -> LookParameters {
        var look = self.look
        look.mono = mono
        look.line = activeLine
        return look
    }

    func commitEdit() async {
        guard let display else { return }
        let geometry = FrameGeometry(
            aspect: .native, crop: 1,
            sensorWidth: Double(display.pixelSize.width),
            sensorHeight: Double(display.pixelSize.height)
        )
        let flow = EditFlow(deps: deps)
        try? await flow.commit(item, look: currentLook(), geometry: geometry)
    }

    func revert() async {
        try? await deps.library.revert(item.id)
    }

    func delete() async {
        try? await deps.library.delete(item.id)
    }

    static func summarize(_ facts: DNGFacts) -> String {
        var lines: [String] = []
        lines.append("DECODER \(facts.dngVersion ?? "?")")
        lines.append("SENSOR \(facts.width)x\(facts.height)")
        if let pi = facts.photometricInterpretation {
            lines.append("RAW \(pi == .cfa ? "BAYER CFA" : "LINEAR")")
        }
        if let neutral = facts.asShotNeutral {
            lines.append(String(format: "AS-SHOT WB %.3f/%.3f", neutral[0], neutral[2]))
        }
        lines.append("APPLE PROCESSING: OFF")
        return lines.joined(separator: "\n")
    }
}

struct ViewerScreen: View {
    @State private var model: ViewerModel
    @Environment(\.dismiss) private var dismiss

    init(deps: Dependencies, item: LibraryItem) {
        _model = State(initialValue: ViewerModel(deps: deps, item: item))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                BracketButton(title: "[ BACK ]", accessibilityID: AccessibilityID.Viewer.pager) {
                    dismiss()
                }
                Spacer()
                Text("[ PLATE ]")
                    .font(PikicamFont.mono(.telemetry))
                    .foregroundStyle(Palette.ash)
            }
            .frame(height: 44)
            .padding(.horizontal, UGrid.micro)
            .background(SurfaceColor.low)

            ZStack {
                SurfaceColor.surface
                if let display = model.display {
                    Image(decorative: display.cgImage, scale: 1)
                        .resizable().scaledToFit()
                        .accessibilityLabel("Developed capture")
                } else if model.isDeveloping {
                    Text("[ DEVELOPING ]")
                        .font(PikicamFont.mono(.telemetry))
                        .foregroundStyle(Palette.ash)
                } else if let error = model.developError {
                    Text("[ DEVELOP FAILED ]")
                        .font(PikicamFont.mono(.telemetry))
                        .foregroundStyle(Palette.ash)
                    Text(error)
                        .font(PikicamFont.mono(.micro))
                        .foregroundStyle(Palette.ash.opacity(0.6))
                }
            }
            .frame(maxHeight: .infinity)

            developControls
        }
        .background(SurfaceColor.surface)
        .task { await model.load() }
    }

    private var developControls: some View {
        VStack(spacing: UGrid.small) {
            HStack(spacing: UGrid.small) {
                let evSteps: [EV] = [-2, -1, 1, 2].map { EV(Double($0)) }
                ForEach(evSteps, id: \.value) { ev in
                    let label = ev.value > 0 ? "EV +\(Int(ev.value))" : "EV \(Int(ev.value))"
                    BracketButton(title: label) {
                        model.look.exposureEV = ev.value
                        Task { await model.render() }
                    }
                }
            }
            HStack(spacing: UGrid.small) {
                ForEach(MonoPreset.allCases, id: \.self) { preset in
                    BracketButton(title: preset.rawValue.uppercased()) {
                        model.mono = MonoState(preset: preset)
                        Task { await model.render() }
                    }
                }
            }
            HStack(spacing: UGrid.small) {
                BracketButton(title: "SAVE") { Task { await model.commitEdit() } }
                BracketButton(title: "REVERT") {
                    Task {
                        await model.revert()
                        await model.load()
                    }
                }
                BracketButton(title: "DELETE", accessibilityID: AccessibilityID.Viewer.deleteButton) {
                    Task {
                        await model.delete()
                        dismiss()
                    }
                }
            }
            if !model.provenanceSummary.isEmpty {
                Text(model.provenanceSummary)
                    .font(PikicamFont.mono(.micro))
                    .foregroundStyle(Palette.ash)
                    .padding(UGrid.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(SurfaceColor.low)
            }
        }
        .padding(UGrid.small)
    }
}
