import SwiftUI
import Photos
import CoreImage

struct GalleryView: View {
    @Environment(PikicamLibraryModel.self) private var library
    @State private var viewerPresented = false
    @State private var chromeHidden = false
    @State private var deleteConfirmPresented = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if library.captures.isEmpty {
                    ContentUnavailableView("No captures", systemImage: "photo.fill", description: Text("Capture a photo to begin."))
                        .tint(.yellow)
                } else {
                    ScrollView(.vertical) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 2)], spacing: 2) {
                            ForEach(library.captures, id: \ .id.uuid) { capture in
                                Button(action: { library.select(capture); viewerPresented = true }) {
                                    AsyncThumbnail(assetID: capture.assetID, library: library)
                                        .aspectRatio(1, contentMode: .fit)
                                }
                            }
                        }
                        .padding(2)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    if let latest = library.captures.first {
                        Button {
                            library.select(latest)
                            viewerPresented = true
                        } label: {
                            AsyncThumbnail(assetID: latest.assetID, library: library)
                                .frame(width: 60, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    HStack(spacing: 16) {
                        Button { chromeHidden.toggle() } label: {
                            Image(systemName: chromeHidden ? "eye.slash" : "eye")
                                .foregroundStyle(.yellow)
                        }
                        Button(role: .destructive) {
                            deleteConfirmPresented = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        Button { } label: {
                            Image(systemName: "camera")
                                .foregroundStyle(.yellow)
                        }
                    }
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Delete capture?", isPresented: $deleteConfirmPresented, actions: {
                Button("Delete", role: .destructive) { Task { await library.deleteSelected() } }
                Button("Cancel", role: .cancel) {}
            })
        }
        .fullScreenCover(isPresented: $viewerPresented) {
            if let capture = library.selectedCapture {
                FullScreenViewer(capture: capture, library: library, chromeHidden: chromeHidden, isPresented: $viewerPresented)
            }
        }
        .preferredColorScheme(.dark)
        .task { await library.refresh() }
    }

}

private struct FullScreenViewer: View {
    let capture: PikicamCapture
    let library: PikicamLibraryModel
    let chromeHidden: Bool
    @Binding var isPresented: Bool
    @State private var image: UIImage?
    @State private var deleteConfirmPresented = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
            } else {
                ProgressView().tint(.yellow)
            }
        }
        .overlay(alignment: .top) {
            if !chromeHidden {
                HStack {
                    Text("DNG Viewer")
                    Spacer()
                    Button { deleteConfirmPresented = true } label: {
                        Image(systemName: "trash")
                    }
                }.padding()
            }
        }
        .overlay(alignment: .bottom) {
            if !chromeHidden {
                Button { isPresented = false } label: {
                    Text("Back to Camera")
                }.padding()
            }
        }
        .confirmationDialog("Delete capture?", isPresented: $deleteConfirmPresented, actions: {
            Button("Delete", role: .destructive) { Task { await library.deleteSelected() } }
            Button("Cancel", role: .cancel) {}
        })
        .task {
            do {
                let data = try await library.loadOriginalDNG(for: capture.assetID)
                let service = DevelopService()
                let rendition = try await service.render(dngData: data, orientation: .up)
                image = UIImage(cgImage: rendition.cgImage)
            } catch {
                image = nil
            }
        }
    }
}

private struct AsyncThumbnail: View {
    let assetID: PhotoAssetID
    let library: PikicamLibraryModel
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
        }
        .task {
            do {
                image = try await library.loadThumbnail(for: assetID)
            } catch {
                image = nil
            }
        }
    }
}
