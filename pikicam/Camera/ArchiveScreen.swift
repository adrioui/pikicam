import AVFoundation
import AVKit
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
                        Text("CAPTURES SHOW HERE AFTER YOU SHOOT.")
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
                AssetPage(assets: assets, current: asset, manager: imageManager)
            }
            .background(Skin.Ink.black.ignoresSafeArea())
        }
        .preferredColorScheme(.dark)
        .onAppear { reload() }
    }

    private func reload() {
        assets = Archive.fetchArchiveAssets()
        Task.detached(priority: .utility) {
            let dry = await MainActor.run { Archive.dryRun() }
            guard !dry.alreadyDone else { return }
            guard let report = try? await Archive.migrate() else { return }
            WalkMark.mark("migration-moved-\(report.moved)-foreign-\(report.foreignTouched)")
            await MainActor.run {
                assets = Archive.fetchArchiveAssets()
            }
        }
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
    let assets: [PHAsset]
    @State var current: PHAsset
    let manager: PHCachingImageManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TabView(selection: $current) {
            ForEach(assets, id: \.localIdentifier) { asset in
                MediaPage(asset: asset, manager: manager)
                    .tag(asset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Skin.Ink.black.ignoresSafeArea())
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
        .onChange(of: current) { _, newValue in
            prefetch(around: newValue)
        }
        .onAppear { prefetch(around: current) }
        .accessibilityLabel("Media pager")
    }

    private func prefetch(around asset: PHAsset) {
        guard let index = assets.firstIndex(of: asset) else { return }
        let lower = max(0, index - 1)
        let upper = min(assets.count, index + 2)
        manager.startCachingImages(
            for: Array(assets[lower..<upper]),
            targetSize: CGSize(width: 1200, height: 1200),
            contentMode: .aspectFit,
            options: nil
        )
    }
}

struct MediaPage: View {
    let asset: PHAsset
    let manager: PHCachingImageManager
    @State private var image: UIImage?
    @State private var player: AVQueuePlayer?

    var body: some View {
        ZStack {
            Skin.Ink.black.ignoresSafeArea()
            if asset.mediaType == .video {
                if let player {
                    PlayerSurface(player: player)
                    PlayerBar(player: player)
                } else {
                    Text("LOADING…")
                        .skin(.caption, Skin.Ink.rule)
                }
            } else if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Text("LOADING…")
                    .skin(.caption, Skin.Ink.rule)
            }
        }
        .task {
            if asset.mediaType == .video {
                let session = AVAudioSession.sharedInstance()
                try? session.setCategory(.playback)
                try? session.setActive(true)
                let options = PHVideoRequestOptions()
                options.deliveryMode = .highQualityFormat
                options.isNetworkAccessAllowed = false
                PHImageManager.default().requestAVAsset(
                    forVideo: asset, options: options
                ) { avAsset, _, _ in
                    guard let avAsset else { return }
                    DispatchQueue.main.async {
                        player = AVQueuePlayer(items: [AVPlayerItem(asset: avAsset)])
                    }
                }
            } else {
                let options = PHImageRequestOptions()
                options.deliveryMode = .highQualityFormat
                manager.requestImage(
                    for: asset,
                    targetSize: CGSize(width: asset.pixelWidth, height: asset.pixelHeight),
                    contentMode: .aspectFit,
                    options: options
                ) { rendered, _ in
                    image = rendered
                }
            }
        }
    }
}
