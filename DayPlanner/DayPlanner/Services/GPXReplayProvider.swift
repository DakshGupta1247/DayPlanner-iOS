//
//  GPXReplayProvider.swift
//  DayPlanner
//
//  Replays a GPX file as if it were live GPS. Used in DEBUG builds so
//  a reviewer can press Run on the simulator and see real movement
//  without a physical device.
//
//  - Parses the GPX file once on init.
//  - Emits each fix with the real time-gap between consecutive trackpoints,
//    divided by speedMultiplier (3.0 = 3× faster than real-time).
//  - Loops back to the first trackpoint when the file ends.
//  - Bypasses LocationIntegrityGate — replay fixes are already trusted.
//  - Publishes currentLocation on @MainActor so UI updates work correctly.
//

import CoreLocation
import Observation

@Observable
@MainActor
final class GPXReplayProvider: LocationProviding {

    // MARK: - LocationProviding

    private(set) var trustedLocationStream: AsyncStream<CLLocation>
    private(set) var currentLocation: CLLocation? = nil
    private(set) var hasReceivedFirstFix: Bool = false
    let isDenied: Bool = false
    let isAuthorized: Bool = true
    // GPX replay is always "trusted" — show a green chip in the UI.
    var latestTrust: LocationTrust? = .trusted(CLLocation())

    func requestPermission() {}
    func startTracking() {}
    func stopTracking() {}

    // MARK: - Private

    private let gpxFileName: String
    private let speedMultiplier: Double
    // nonisolated(unsafe) so deinit can cancel without hopping to MainActor
    nonisolated(unsafe) private var continuation: AsyncStream<CLLocation>.Continuation?
    nonisolated(unsafe) private var replayTask: Task<Void, Never>?

    // MARK: - Init

    init(gpxFileName: String, speedMultiplier: Double = 3.0) {
        self.gpxFileName    = gpxFileName
        self.speedMultiplier = speedMultiplier

        var cont: AsyncStream<CLLocation>.Continuation?
        trustedLocationStream = AsyncStream { cont = $0 }
        continuation = cont

        // Start replay immediately
        let fileName = gpxFileName
        let multiplier = speedMultiplier
        replayTask = Task { [weak self] in
            await self?.runReplay(fileName: fileName, speedMultiplier: multiplier)
        }
    }

    deinit {
        replayTask?.cancel()
        continuation?.finish()
    }

    // MARK: - Replay loop

    private func runReplay(fileName: String, speedMultiplier: Double) async {
        let locations = await GPXParser.parse(fileName: fileName)
        guard locations.count >= 2 else { return }

        // Loop forever so the demo keeps running
        while !Task.isCancelled {
            for index in 0 ..< locations.count {
                guard !Task.isCancelled else { return }

                let point = locations[index]

                // Calculate delay from real time gap to next point
                if index + 1 < locations.count {
                    let next     = locations[index + 1]
                    let realGap  = next.timestamp.timeIntervalSince(point.timestamp)
                    // Clamp gap: ignore gaps <= 0 or > 5 min (data artifacts)
                    let clampedGap = max(1.0, min(realGap, 300.0))
                    let delay    = clampedGap / speedMultiplier
                    let nanos    = UInt64(delay * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: nanos)
                }

                guard !Task.isCancelled else { return }

                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.currentLocation     = point
                    self.hasReceivedFirstFix = true
                    // Refresh the trust object so the chip shows a real location
                    self.latestTrust = .trusted(point)
                    self.continuation?.yield(point)
                }
            }
        }
    }
}
