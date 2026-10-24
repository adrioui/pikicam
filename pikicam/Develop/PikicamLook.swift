import CoreImage
import Foundation

enum PikicamLook {
    static let kernelName = "pikicamLook"

    static func kernel() throws(DevelopError) -> CIKernel {
        guard let url = Bundle.main.url(forResource: "default", withExtension: "metallib"),
            let data = try? Data(contentsOf: url)
        else {
            throw .filterUnavailable
        }
        do {
            return try CIKernel(functionName: kernelName, fromMetalLibraryData: data)
        } catch {
            throw .filterUnavailable
        }
    }

    static func apply(to image: CIImage, look: LookParameters) throws(DevelopError) -> CIImage {
        let kernel = try kernel()
        let mono = look.mono
        let weights = mono?.activeWeights ?? MonoPreset.neutral.weights
        let arguments: [Any] = [
            image,
            NSNumber(value: look.exposureEV),
            CIVector(x: CGFloat(weights.r), y: CGFloat(weights.g), z: CGFloat(weights.b)),
            NSNumber(value: mono == nil ? 0.0 : 1.0),
            NSNumber(value: look.contrast),
            NSNumber(value: look.highlights),
            NSNumber(value: look.shadows),
            NSNumber(value: 1.0 / 1023.0),
        ]
        let roi: (Int32, CGRect) -> CGRect = { _, rect in rect }
        guard let applied = kernel.apply(extent: image.extent, roiCallback: roi, arguments: arguments) else {
            throw .renderFailed
        }
        return applied
    }
}
