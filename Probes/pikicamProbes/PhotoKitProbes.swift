import CoreImage
import Foundation
import Photos
import UniformTypeIdentifiers

enum PhotoKitProbes {
    static func authorizationStatus() -> JSONValue {
        .dict(["readWrite": "\(PHPhotoLibrary.authorizationStatus(for: .readWrite).rawValue)"])
    }

    static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in
                continuation.resume()
            }
        }
        return PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized
            || PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited
    }

    static func makeSmallHEIC(from dng: Data?) async -> Data? {
        let image: CIImage?
        if let dng, let filter = CIRAWFilter(imageData: dng, identifierHint: "com.adobe.raw-image"),
            let output = filter.outputImage
        {
            image = output.transformed(by: CGAffineTransform(scaleX: 0.05, y: 0.05))
        } else {
            image = CIImage(color: CIColor(red: 0.2, green: 0.5, blue: 0.8))
                .cropped(to: CGRect(x: 0, y: 0, width: 256, height: 256))
        }
        guard let image, let p3 = CGColorSpace(name: CGColorSpace.displayP3) else { return nil }
        let context = CIContext(options: [.memoryTarget: 512])
        return try? await context.heif10Representation(of: image, colorSpace: p3, options: [:])
    }

    struct ShapeResult: Codable {
        var shape = ""
        var supportsResourceTypes = false
        var creationSucceeded = false
        var creationError = ""
        var resources: [String] = []
        var currentRenderMeanDiff = -1.0
        var dngBytesMatch = false
        var fetchError = ""
    }

    static func probeShapes(dng: Data, heic: Data) async -> [ShapeResult] {
        let supports = PHAssetCreationRequest.supportsAssetResourceTypes(
            [PHAssetResourceType.photo, .fullSizePhoto, .alternatePhoto, .adjustmentData]
                .map { NSNumber(value: $0.rawValue) }
        )
        var results: [ShapeResult] = []
        for (name, configure) in shapeVariants() {
            var result = ShapeResult()
            result.shape = name
            result.supportsResourceTypes = supports
            await runShapeVariant(name: name, configure: configure, dng: dng, heic: heic, into: &result)
            results.append(result)
        }
        return results
    }

    private static func shapeVariants() -> [(String, (PHAssetCreationRequest, Data, Data) -> Void)] {
        controlVariants() + fullShapeVariants()
    }

    private static func controlVariants() -> [(String, (PHAssetCreationRequest, Data, Data) -> Void)] {
        let variants: [(String, (PHAssetCreationRequest, Data, Data) -> Void)] = [
            (
                "control-dng-only",
                { request, dngData, _ in
                    request.addResource(
                        with: .photo, data: dngData,
                        options: resourceOptions("PIKI_ctrl.dng", UTType.rawImage.identifier))
                }
            ),
            (
                "control-heic-only",
                { request, _, heicData in
                    request.addResource(
                        with: .photo, data: heicData, options: resourceOptions("PIKI_ctrl.heic", "public.heic"))
                }
            ),
        ]
        return variants
    }

    private static func fullShapeVariants() -> [(String, (PHAssetCreationRequest, Data, Data) -> Void)] {
        [
            ("A-full", addShapeAResources(adjustment: true)),
            ("A-no-adjustment", addShapeAResources(adjustment: false)),
            ("B-full", addShapeBResources),
            ("C-full", addShapeCResources),
        ]
    }

    private static func addShapeAResources(adjustment: Bool) -> (PHAssetCreationRequest, Data, Data) -> Void {
        { request, dngData, heicData in
            request.addResource(
                with: .photo, data: dngData, options: resourceOptions("PIKI_A.dng", UTType.rawImage.identifier))
            request.addResource(
                with: .fullSizePhoto, data: heicData,
                options: resourceOptions("PIKI_A_full.heic", "public.heic"))
            if adjustment, let data = try? JSONEncoder().encode(["pikicam.probe": "v1"]) {
                request.addResource(with: .adjustmentData, data: data, options: nil)
            }
        }
    }

    private static func addShapeBResources(_ request: PHAssetCreationRequest, _ dng: Data, _ heic: Data) {
        request.addResource(
            with: .photo, data: heic, options: resourceOptions("PIKI_B.heic", "public.heic"))
        request.addResource(
            with: .alternatePhoto, data: dng,
            options: resourceOptions("PIKI_B_alt.dng", UTType.rawImage.identifier))
    }

    private static func addShapeCResources(_ request: PHAssetCreationRequest, _ dng: Data, _ heic: Data) {
        request.addResource(
            with: .photo, data: dng, options: resourceOptions("PIKI_C.dng", UTType.rawImage.identifier))
        request.addResource(
            with: .alternatePhoto, data: heic,
            options: resourceOptions("PIKI_C_alt.heic", "public.heic"))
    }

    private static func runShapeVariant(
        name: String,
        configure: @escaping (PHAssetCreationRequest, Data, Data) -> Void,
        dng: Data,
        heic: Data,
        into result: inout ShapeResult
    ) async {
        do {
            var localID = ""
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.creationDate = Date()
                configure(request, dng, heic)
                localID = request.placeholderForCreatedAsset?.localIdentifier ?? ""
            }
            result.creationSucceeded = true

            let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localID], options: nil)
            if let asset = assets.firstObject, assets.count == 1 {
                let resources = PHAssetResource.assetResources(for: asset)
                result.resources = resources.map {
                    "\($0.type.rawValue):\($0.uniformTypeIdentifier ?? "?"):\($0.originalFilename ?? "?")"
                }

                result.currentRenderMeanDiff = currentRenderMeanDiff(asset: asset, heic: heic)
                result.dngBytesMatch = await dngBytesRoundTrip(asset: asset, dng: dng, shape: name)

                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.deleteAssets([asset] as NSArray)
                }
            } else {
                result.fetchError = "fetch count \(assets.count)"
            }
        } catch {
            result.creationError = "\(error)"
        }
    }

    static func resourceOptions(_ filename: String, _ uti: String) -> PHAssetResourceCreationOptions {
        let options = PHAssetResourceCreationOptions()
        options.originalFilename = filename
        options.uniformTypeIdentifier = uti
        return options
    }

    static func currentRenderMeanDiff(asset: PHAsset, heic: Data) -> Double {
        guard let refHeic = CGImageSourceCreateWithData(heic as CFData, nil),
            let refImage = CGImageSourceCreateImageAtIndex(refHeic, 0, nil)
        else { return -1 }
        let expectation = expectationBox()
        var meanDiff = -1.0
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = false
        PHImageManager.default().requestImage(
            for: asset, targetSize: CGSize(width: 256, height: 256),
            contentMode: .aspectFit, options: options
        ) { image, _ in
            if let image, let cg = image.cgImage {
                meanDiff = meanAbsDiff(cg, refImage)
            }
            expectation.fulfill()
        }
        expectation.wait(10)
        return meanDiff
    }

    static func dngBytesRoundTrip(asset: PHAsset, dng: Data, shape: String) async -> Bool {
        let resources = PHAssetResource.assetResources(for: asset)
        let dngResource = resources.first {
            $0.uniformTypeIdentifier == UTType.rawImage.identifier
                || $0.originalFilename.hasSuffix(".dng")
        }
        guard let dngResource else { return false }
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("probe-dng-\(shape).dng")
        defer { try? FileManager.default.removeItem(at: tmp) }
        do {
            try await PHAssetResourceManager.default().writeData(for: dngResource, toFile: tmp, options: nil)
            guard let bytes = try? Data(contentsOf: tmp) else { return false }
            return bytes == dng
        } catch {
            return false
        }
    }

    final class ExpectationBox: @unchecked Sendable {
        private let semaphore = DispatchSemaphore(value: 0)
        func fulfill() { semaphore.signal() }
        func wait(_ seconds: Double) { _ = semaphore.wait(timeout: .now() + seconds) }
    }

    static func expectationBox() -> ExpectationBox { ExpectationBox() }

    static func meanAbsDiff(_ a: CGImage, _ b: CGImage) -> Double {
        let size = 64
        guard
            let context = CGContext(
                data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { return -1 }
        context.draw(a, in: CGRect(x: 0, y: 0, width: size, height: size))
        guard let aData = context.data else { return -1 }
        let aBytes = Data(bytes: aData, count: size * size * 4)
        context.clear(CGRect(x: 0, y: 0, width: size, height: size))
        context.draw(b, in: CGRect(x: 0, y: 0, width: size, height: size))
        guard let bData = context.data else { return -1 }
        let bBytes = Data(bytes: bData, count: size * size * 4)
        var total = 0
        for i in stride(from: 0, to: aBytes.count, by: 4) {
            for c in 0..<3 {
                total += abs(Int(aBytes[i + c]) - Int(bBytes[i + c]))
            }
        }
        return Double(total) / Double(size * size * 3)
    }
}
