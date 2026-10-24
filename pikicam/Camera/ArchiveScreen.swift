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
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        Text("Shots you take appear here.")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
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
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("[ BACK ]") { dismiss() }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .accessibilityIdentifier("archive.back")
                }
            }
            .navigationDestination(for: PHAsset.self) { asset in
                AssetPage(asset: asset, manager: imageManager)
            }
            .background(Color.black.ignoresSafeArea())
        }
        .preferredColorScheme(.dark)
        .onAppear { reload() }
    }

    private func reload() {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 200
        let fetch = PHAsset.fetchAssets(with: .image, options: options)
        var collected: [PHAsset] = []
        fetch.enumerateObjects { asset, _, _ in collected.append(asset) }
        assets = collected
    }
}

struct AssetThumb: View {
    let asset: PHAsset
    let manager: PHCachingImageManager
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Rectangle().fill(Color(white: 0.12))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
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
            Color.black.ignoresSafeArea()
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Text("LOADING…")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("[ BACK ]") { dismiss() }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
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
