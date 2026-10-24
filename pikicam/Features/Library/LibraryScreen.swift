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
                    .pikicamType(.title)
                    .foregroundStyle(InkColor.muslin)
                Spacer()
                Text("[ \(model.items.count) ]")
                    .pikicamType(.readout)
                    .foregroundStyle(InkColor.ash)
            }
            .padding(.horizontal, UGrid.micro)
            .frame(height: 44)
            .background(PlateColor.photometricLow)

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
        .background(PlateColor.photometricDeep)
        .task { await model.start() }
        .onDisappear { model.stop() }
        .sheet(item: $viewerItem) { item in
            ViewerScreen(deps: model.deps, item: item)
        }
    }

    private var emptyState: some View {
        VStack(spacing: UGrid.small) {
            Text("NO CAPTURES")
                .pikicamType(.title)
                .foregroundStyle(InkColor.ash)
            Text("THE ARCHIVE FILLS AS YOU SHOOT")
                .pikicamType(.micro)
                .foregroundStyle(InkColor.ash.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func cell(_ item: LibraryItem) -> some View {
        Button {
            viewerItem = item
        } label: {
            ZStack {
                Rectangle()
                    .fill(PlateColor.carbon)
                    .aspectRatio(1, contentMode: .fit)
                VStack(alignment: .leading) {
                    Spacer()
                    HStack {
                        Text(item.creationDate.formatted(date: .abbreviated, time: .omitted))
                            .pikicamType(.micro)
                            .foregroundStyle(InkColor.calico)
                        Spacer()
                        if case .video(let clip) = item.mediaKind {
                            Text("\(Int(clip.duration))S")
                                .pikicamType(.micro)
                                .foregroundStyle(InkColor.ash)
                        }
                    }
                    .padding(UGrid.nano)
                }
            }
            .overlay(Rectangle().strokeBorder(InkColor.ash.opacity(0.4), lineWidth: UGrid.hairline))
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier("library.cell")
        .accessibilityLabel("Photo, \(item.creationDate.formatted(date: .abbreviated, time: .omitted))")
    }
}
