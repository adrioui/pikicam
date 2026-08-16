import SwiftUI
import Photos
import CoreImage

struct GalleryView: View {
    @Environment(PikicamLibraryModel.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var viewerPresented = false
    @State private var chromeHidden = false
    @State private var deleteConfirmPresented = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                galleryContent
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    if let latest = library.captures.first {
                        Button {
                            library.select(latest)
                            chromeHidden = false
                            viewerPresented = true
                        } label: {
                            AsyncThumbnail(assetID: latest.assetID, library: library)
                                .frame(width: 60, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .accessibilityIdentifier("gallery-latest-thumbnail")
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    HStack(spacing: 16) {
                        Button { chromeHidden.toggle() } label: {
                            Image(systemName: chromeHidden ? "eye.slash" : "eye")
                                .foregroundStyle(.yellow)
                        }
                        .accessibilityIdentifier("gallery-eye-toggle")
                        Button(role: .destructive) {
                            deleteConfirmPresented = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .disabled(library.selectedCapture == nil)
                        .accessibilityIdentifier("gallery-trash")
                        Button { dismiss() } label: {
                            Image(systemName: "camera")
                                .foregroundStyle(.yellow)
                        }
                        .accessibilityIdentifier("gallery-camera")
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
                FullScreenViewer(
                    capture: capture,
                    library: library,
                    chromeHidden: $chromeHidden,
                    isPresented: $viewerPresented,
                    onBackToCamera: {
                        viewerPresented = false
                        dismiss()
                    }
                )
            }
        }
        .preferredColorScheme(.dark)
        .task { await library.refresh() }
    }

    @ViewBuilder
    private var galleryContent: some View {
        if library.isLoading && library.captures.isEmpty && library.error == nil {
            ProgressView()
                .tint(.yellow)
                .accessibilityIdentifier("gallery-loading")
        } else if library.captures.isEmpty {
            if let error = library.error {
                ContentUnavailableView(
                    "Unable to load library",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
                .tint(.yellow)
                .accessibilityIdentifier("gallery-error")
                .overlay(alignment: .bottom) {
                    Button("Retry") {
                        Task { await library.refresh() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.yellow)
                    .foregroundStyle(.black)
                    .accessibilityIdentifier("gallery-retry")
                    .padding()
                }
            } else {
                ContentUnavailableView("No captures", systemImage: "photo.fill", description: Text("Capture a photo to begin."))
                    .tint(.yellow)
                    .accessibilityIdentifier("gallery-empty")
            }
        } else {
            ZStack(alignment: .top) {
                ScrollView(.vertical) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 2)], spacing: 2) {
                        ForEach(Array(library.captures.enumerated()), id: \.element.id.uuid) { index, capture in
                            Button(action: {
                                library.select(capture)
                                chromeHidden = false
                                viewerPresented = true
                            }) {
                                AsyncThumbnail(assetID: capture.assetID, library: library)
                                    .aspectRatio(1, contentMode: .fit)
                            }
                            .accessibilityIdentifier("gallery-cell-\(index)")
                        }
                    }
                    .padding(2)
                }
                .accessibilityIdentifier("library-grid")
                if let error = library.error {
                    HStack(spacing: 12) {
                        Text(error.localizedDescription)
                            .font(.caption)
                            .lineLimit(2)
                        Spacer()
                        Button("Retry") { Task { await library.refresh() } }
                            .accessibilityIdentifier("gallery-retry")
                    }
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding()
                    .accessibilityIdentifier("gallery-error")
                }
            }
        }
    }
}

private struct FullScreenViewer: View {
    let capture: PikicamCapture
    let library: PikicamLibraryModel
    @Binding var chromeHidden: Bool
    @Binding var isPresented: Bool
    let onBackToCamera: () -> Void
    @State private var image: UIImage?
    @State private var loadFailed = false
    @State private var loadErrorDescription: String?
    @State private var deleteConfirmPresented = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
            } else if loadFailed {
                ContentUnavailableView(
                    "Unable to load DNG",
                    systemImage: "exclamationmark.triangle",
                    description: Text(loadErrorDescription ?? "This capture could not be developed.")
                )
                .tint(.yellow)
                .accessibilityIdentifier("viewer-load-failure")
            } else {
                ProgressView().tint(.yellow)
                    .accessibilityIdentifier("viewer-loading")
            }
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { chromeHidden.toggle() }
                .accessibilityIdentifier("viewer-background")
        }
        .overlay(alignment: .top) {
            if !chromeHidden {
                HStack {
                    Text("DNG Viewer")
                    Spacer()
                    Button { chromeHidden.toggle() } label: {
                        Image(systemName: chromeHidden ? "eye.slash" : "eye")
                    }
                    .accessibilityIdentifier("viewer-chrome-toggle")
                    Button { deleteConfirmPresented = true } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityIdentifier("viewer-delete")
                }
                .padding()
            }
        }
        .overlay(alignment: .bottom) {
            if !chromeHidden {
                Button(action: onBackToCamera) {
                    Text("Back to Camera")
                }
                .accessibilityIdentifier("viewer-back")
                .padding()
            }
        }
        .alert("Delete capture?", isPresented: $deleteConfirmPresented) {
            Button("Delete", role: .destructive) {
                Task {
                    let deleted = await library.deleteSelected()
                    if deleted {
                        isPresented = false
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the DNG from Pikicam.")
        }
        .task(id: capture.id) {
            image = nil
            loadFailed = false
            loadErrorDescription = nil
            do {
                let data = try await library.loadOriginalDNG(for: capture.assetID)
                let service = DevelopService()
                let rendition = try await service.render(dngData: data, orientation: capture.orientation)
                image = UIImage(cgImage: rendition.cgImage)
            } catch {
                loadErrorDescription = error.localizedDescription
                image = nil
                loadFailed = true
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
