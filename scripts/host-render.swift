import CoreImage
import CoreVideo
import Foundation

guard CommandLine.arguments.count >= 2 else {
    FileHandle.standardError.write("usage: host-render <file.dng>\n".data(using: .utf8)!)
    exit(2)
}
let url = URL(fileURLWithPath: CommandLine.arguments[1])
guard let data = try? Data(contentsOf: url) else {
    FileHandle.standardError.write("cannot read \(url.path)\n".data(using: .utf8)!)
    exit(2)
}
guard let filter = CIRAWFilter(imageData: data, identifierHint: "com.adobe.raw-image"),
    type(of: filter) == CIRAWFilter.self
else {
    FileHandle.standardError.write("no real CIRAWFilter\n".data(using: .utf8)!)
    exit(3)
}
filter.boostAmount = 0
filter.boostShadowAmount = 1
filter.extendedDynamicRangeAmount = 1
filter.isLensCorrectionEnabled = false
filter.isGamutMappingEnabled = false
guard let image = filter.outputImage else {
    FileHandle.standardError.write("no output\n".data(using: .utf8)!)
    exit(3)
}
let scale = CGAffineTransform(scaleX: 0.25, y: 0.25)
let scaled = image.transformed(by: scale)
let width = Int(scaled.extent.width)
let height = Int(scaled.extent.height)
guard width > 0, height > 0,
    let linearSpace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
else {
    exit(4)
}
var buffer: CVPixelBuffer?
CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_64RGBAHalf, nil, &buffer)
guard let pixelBuffer = buffer else { exit(4) }
let context = CIContext()
context.render(scaled, to: pixelBuffer, bounds: scaled.extent, colorSpace: linearSpace)
CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { exit(4) }
let stride = CVPixelBufferGetBytesPerRow(pixelBuffer) / 2
let pointer = base.assumingMemoryBound(to: UInt16.self)

struct ChannelStats: Codable {
    let mean: Double
    let median: Double
    let p1: Double
    let p99: Double
    let max: Double
}

func stats(_ values: [Double]) -> ChannelStats {
    let sorted = values.sorted()
    let count = sorted.count
    func percentile(_ p: Double) -> Double {
        let index = min(max(Int((Double(count) - 1) * p), 0), count - 1)
        return sorted[index]
    }
    return ChannelStats(
        mean: values.reduce(0, +) / Double(count),
        median: percentile(0.5),
        p1: percentile(0.01),
        p99: percentile(0.99),
        max: sorted.last ?? 0
    )
}

var channels: [[Double]] = [[], [], []]
for y in 0..<height {
    for x in 0..<width {
        let offset = y * stride + x * 4
        for c in 0..<3 {
            channels[c].append(Double(Float16(bitPattern: pointer[offset + c])))
        }
    }
}
let payload: [String: ChannelStats] = [
    "r": stats(channels[0]),
    "g": stats(channels[1]),
    "b": stats(channels[2]),
]
let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]
print(String(data: try! encoder.encode(payload), encoding: .utf8)!)
