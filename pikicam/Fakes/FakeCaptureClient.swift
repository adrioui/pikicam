// periphery:ignore
import CoreVideo
import Foundation

#if DEBUG

    actor FakeCaptureClient: CaptureClient {
        private let scenario: FakeScenario
        let capabilities: DeviceCapabilities
        let preview: PreviewSource

        private var stateContinuation: AsyncStream<SessionState>.Continuation?
        private var readingsContinuation: AsyncStream<DeviceReadings>.Continuation?
        private var metersContinuation: AsyncStream<MeterReading>.Continuation?

        nonisolated var sessionStates: AsyncStream<SessionState> {
            AsyncStream { continuation in
                Task { await self.registerSession(continuation) }
            }
        }

        nonisolated var readings: AsyncStream<DeviceReadings> {
            AsyncStream { continuation in
                Task { await self.registerReadings(continuation) }
            }
        }

        nonisolated var meters: AsyncStream<MeterReading> {
            AsyncStream { continuation in
                Task { await self.registerMeters(continuation) }
            }
        }

        init(scenario: FakeScenario) {
            self.scenario = scenario
            let lens = Lens(kind: .wide, uniqueID: "fake-wide", equivalentFocalLength: 26)
            let limits = ExposureLimits(iso: 33...3168, exposureDuration: 1.0 / 71429...1.0 / 30, bias: -8...8)
            self.capabilities = DeviceCapabilities(
                lenses: [lens],
                exposureLimits: [.wide: limits],
                whiteBalanceLimits: WhiteBalanceLimits(temperature: 2000...10000, tint: -150...150, maxGain: 8),
                flashSupported: true,
                focusLockSupported: true,
                rawDimensions: CGSize(width: 4032, height: 3024),
                bayerFormat: BayerFormat(osType: kCVPixelFormatType_14Bayer_RGGB)
            )
            self.preview = PreviewSource(provider: { nil })
        }

        private func registerSession(_ continuation: AsyncStream<SessionState>.Continuation) {
            stateContinuation = continuation
            continuation.yield(.running(.wide))
        }

        private func registerReadings(_ continuation: AsyncStream<DeviceReadings>.Continuation) {
            readingsContinuation = continuation
            continuation.yield(
                DeviceReadings(
                    iso: 100, exposureDuration: 1.0 / 120, lensPosition: 0.5, whiteBalanceGains: [1, 1, 1, 1]))
        }

        private func registerMeters(_ continuation: AsyncStream<MeterReading>.Continuation) {
            metersContinuation = continuation
            continuation.yield(MeterReading(histogram: Array(repeating: 10, count: 64), clippedLow: 0, clippedHigh: 0))
        }

        func start(lens: LensKind) throws(CaptureError) {
            stateContinuation?.yield(.running(lens))
        }

        func stop() {
            stateContinuation?.yield(.idle)
        }

        func apply(_ settings: CameraSettings) {}

        func capture(_ request: CaptureRequest) throws(CaptureError) -> RawCapture {
            if scenario == .developFails || scenario == .storageFull {
                return makeCapture(request: request, validDNG: true)
            }
            return makeCapture(request: request, validDNG: true)
        }

        private func makeCapture(request: CaptureRequest, validDNG: Bool) -> RawCapture {
            let dng = FakeFixtures.minimalDNG
            let determinism = DeviceDeterminism(
                geometricDistortionCorrection: .off,
                centerStage: .notSupported,
                videoHDR: .off,
                lowLightBoost: .notSupported,
                colorSpace: "P3_D65"
            )
            let provenance = Provenance(
                deviceUniqueID: "fake",
                deviceType: "wide",
                lensKind: .wide,
                lensAperture: 1.6,
                activeFormatDescription: "4032x3024",
                bayerFormatFourCC: "rgg4",
                rawWidth: 4032,
                rawHeight: 3024,
                iso: 100,
                exposureDuration: 1.0 / 120,
                lensPosition: 0.5,
                whiteBalanceGains: [1, 1, 1, 1],
                whiteBalanceTemperature: 5600,
                whiteBalanceTint: 0,
                exposureModeWasManual: false,
                determinism: determinism,
                zeroShutterLag: false,
                iOSVersion: "26.6.2",
                appVersion: "2.0",
                capturedAt: Date()
            )
            return RawCapture(id: request.id, dng: dng, provenance: provenance)
        }
    }

    enum FakeFixtures {
        static var minimalDNG: Data {
            let url =
                Bundle.main.url(forResource: "synthetic-bayer", withExtension: "dng")
                ?? Bundle(for: FakeBundleMarker.self).url(forResource: "synthetic-bayer", withExtension: "dng")
            if let url, let data = try? Data(contentsOf: url) {
                return data
            }
            return Data("not-a-dng".utf8)
        }
    }

    final class FakeBundleMarker {}

#endif
