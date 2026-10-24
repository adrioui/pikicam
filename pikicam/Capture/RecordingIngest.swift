import AVFoundation
import CoreImage
import Foundation

extension AVRecordingClient {
    func ingest(_ sampleBuffer: CMSampleBuffer) {
        guard writers != nil, startedAt != nil else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            droppedFrames += 1
            return
        }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        guard let untouchedInput, let untouchedAdapter, untouchedInput.isReadyForMoreMediaData else {
            droppedFrames += 1
            return
        }
        if !untouchedAdapter.append(pixelBuffer, withPresentationTime: timestamp) {
            droppedFrames += 1
        }
        if let renditionInput, renditionInput.isReadyForMoreMediaData, let renditionAdapter,
            let kernel = lookKernel
        {
            let ci = CIImage(cvPixelBuffer: pixelBuffer)
            let arguments: [Any] = [
                ci, NSNumber(value: lookLook.exposureEV),
                CIVector(x: 0.22897, y: 0.69174, z: 0.07929),
                NSNumber(value: lookMono == nil ? 0.0 : 1.0),
                NSNumber(value: lookLook.contrast), NSNumber(value: lookLook.highlights),
                NSNumber(value: lookLook.shadows), NSNumber(value: 1.0 / 1023.0),
            ]
            let roi: (Int32, CGRect) -> CGRect = { _, rect in rect }
            if let rendered = kernel.apply(extent: ci.extent, roiCallback: roi, arguments: arguments) {
                var outputBuffer: CVPixelBuffer?
                CVPixelBufferPoolCreatePixelBuffer(
                    nil, renditionAdapter.pixelBufferPool!, &outputBuffer
                )
                if let outputBuffer {
                    let p3 = CGColorSpace(name: CGColorSpace.displayP3)!
                    context.render(rendered, to: outputBuffer, bounds: rendered.extent, colorSpace: p3)
                    _ = renditionAdapter.append(outputBuffer, withPresentationTime: timestamp)
                }
            }
        }
        frameIndex += 1
    }
}
