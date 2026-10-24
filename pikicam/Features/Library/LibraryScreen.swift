import SwiftUI

@MainActor
@Observable
final class LibraryModel {
    let deps: Dependencies
    private(set) var items: [LibraryItem] = []
    private var changesTask: Task<Void, Never>?

    init(deps: Dependencies) {
        self.deps = deps
    }

    func start() async {
        changesTask = Task { [weak self] in
            guard let changes = self?.deps.library.changes else { return }
            for await items in changes {
                guard let self else { return }
                self.items = items
            }
        }
        let current = await deps.library.items()
        if Task.isCancelled { return }
        items = current
    }

    func stop() {
        changesTask?.cancel()
    }

    func delete(_ item: LibraryItem) async {
        try? await deps.library.delete(item.id)
    }
}

struct LibraryScreen: View {
    @State private var model: LibraryModel
    @State private var viewerItem: LibraryItem?

    init(deps: Dependencies) {
        _model = State(initialValue: LibraryModel(deps: deps))
    }

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: UGrid.nano)]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("ARCHIVE")
                    .font(PikicamFont.mono(.headline))
                    .foregroundStyle(Palette.muslin)
                Spacer()
                Text("[ \(model.items.count) ]")
                    .font(PikicamFont.mono(.telemetry))
                    .foregroundStyle(Palette.ash)
            }
            .padding(.horizontal, UGrid.micro)
            .frame(height: 44)
            .background(SurfaceColor.low)

            if model.items.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: UGrid.nano) {
                        ForEach(model.items) { item in
                            cell(item)
                        }
                    }
                    .padding(UGrid.micro)
                }
            }
        }
        .background(SurfaceColor.surface)
        .task { await model.start() }
        .onDisappear { model.stop() }
        .sheet(item: $viewerItem) { item in
            ViewerScreen(deps: model.deps, item: item)
        }
    }

    private var emptyState: some View {
        VStack(spacing: UGrid.small) {
            Text("NO CAPTURES")
                .font(PikicamFont.mono(.headline))
                .foregroundStyle(Palette.ash)
            Text("THE ARCHIVE FILLS AS YOU SHOOT")
                .font(PikicamFont.mono(.micro))
                .foregroundStyle(Palette.ash.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func cell(_ item: LibraryItem) -> some View {
        Button {
            viewerItem = item
        } label: {
            ZStack {
                Rectangle()
                    .fill(SurfaceColor.elevated)
                    .aspectRatio(1, contentMode: .fit)
                VStack(alignment: .leading) {
                    Spacer()
                    HStack {
                        Text(item.creationDate.formatted(date: .abbreviated, time: .omitted))
                            .font(PikicamFont.mono(.micro))
                            .foregroundStyle(Palette.calico)
                        Spacer()
                        if case .video(let clip) = item.mediaKind {
                            Text("\(Int(clip.duration))S")
                                .font(PikicamFont.mono(.micro))
                                .foregroundStyle(Palette.ash)
                        }
                    }
                    .padding(UGrid.nano)
                }
            }
            .overlay(Rectangle().strokeBorder(Palette.ash.opacity(0.4), lineWidth: UGrid.hairline))
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier("library.cell")
        .accessibilityLabel("Photo, \(item.creationDate.formatted(date: .abbreviated, time: .omitted))")
    }
}
