import Photos
import SwiftUI
import UIKit

struct ArchiveScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var assets: [PHAsset] = []
    private let imageManager = PHCachingImageManager()

    var body: some View {
        NavigationStack {
            Group {
                if assets.isEmpty {
                    VStack(spacing: 12) {
                        Text("NO CAPTURES")
                            .skin(.body)
                        Text("SHOTS YOU TAKE APPEAR HERE.")
                            .skin(.caption, Skin.Ink.rule)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Skin.Ink.black)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 4)], spacing: 4) {
                            ForEach(assets, id: \.localIdentifier) { asset in
                                NavigationLink(value: asset) {
                                    AssetThumb(asset: asset, manager: imageManager)
                                }
                                .accessibilityLabel("Photo, \(asset.creationDate ?? Date())")
                            }
                        }
                        .padding(4)
                    }
                }
            }
            .navigationTitle("ARCHIVE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Skin.Ink.black, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("BACK")
                            .skin(.caption)
                    }
                    .accessibilityIdentifier("archive.back")
                }
            }
            .navigationDestination(for: PHAsset.self) { asset in
                AssetPage(asset: asset, manager: imageManager)
            }
            .background(Skin.Ink.black.ignoresSafeArea())
        }
        .preferredColorScheme(.dark)
        .onAppear { reload() }
    }

    private func reload() {
        assets = Archive.fetchArchiveAssets()
        Task { await runMigrationIfFirstLaunch() }
    }

    private func runMigrationIfFirstLaunch() async {
        let dry = Archive.dryRun()
        guard !dry.alreadyDone, dry.legacyFound > 0 || dry.beforeInAlbum == 0 else { return }
        guard let report = try? await Archive.migrate() else { return }
        assets = Archive.fetchArchiveAssets()
        print("MIGRATION report:", report.beforeInAlbum, report.legacyFound, report.moved, report.foreignTouched)
    }
}

struct AssetThumb: View {
    let asset: PHAsset
    let manager: PHCachingImageManager
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Rectangle().fill(Skin.Ink.black)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
            if asset.mediaType == .video {
                VStack {
                    Spacer()
                    Text(String(format: "%d:%02d", Int(asset.duration) / 60, Int(asset.duration) % 60))
                        .skin(.caption, Skin.Ink.black)
                        .padding(4)
                        .frame(maxWidth: .infinity)
                        .background(Skin.Ink.white)
                }
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipped()
        .task {
            manager.requestImage(
                for: asset, targetSize: CGSize(width: 200, height: 200),
                contentMode: .aspectFill, options: nil
            ) { rendered, _ in
                image = rendered
            }
        }
    }
}

struct AssetPage: View {
    let asset: PHAsset
    let manager: PHCachingImageManager
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Skin.Ink.black.ignoresSafeArea()
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Text("LOADING…")
                    .skin(.caption, Skin.Ink.rule)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Text("BACK")
                        .skin(.caption)
                }
                    .accessibilityIdentifier("photo.back")
            }
        }
        .task {
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            let size = CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
            manager.requestImage(
                for: asset, targetSize: size, contentMode: .aspectFit, options: options
            ) { rendered, _ in
                image = rendered
            }
        }
    }
}
