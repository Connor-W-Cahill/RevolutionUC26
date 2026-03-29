import Foundation
import SwiftUI

// NOTE: SmartSpectraSwiftSDK must be embedded manually in Xcode (not available via SPM).
// When embedded, uncomment: import SmartSpectraSwiftSDK
// and replace the simulated startScan() with real SDK calls.

@Observable
class PresageService {
    static let shared = PresageService()

    var isScanning = false
    var scanProgress: Double = 0
    var error: String?

    private init() {}

    /// Simulate a vitals scan. Replace with SmartSpectraSwiftSDK when embedded.
    func startScan(userID: String) async throws -> CortisolReading {
        await MainActor.run {
            isScanning = true
            scanProgress = 0
            error = nil
        }

        defer {
            Task { @MainActor in
                isScanning = false
                scanProgress = 0
            }
        }

        for i in 1...10 {
            try await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run { scanProgress = Double(i) / 10.0 }
        }

        let reading = CortisolReading(
            userID: userID,
            stressLevel: Double.random(in: 10...80),
            heartRate: Double.random(in: 60...100),
            hrv: Double.random(in: 20...80),
            spO2: Double.random(in: 95...100),
            respiratoryRate: Double.random(in: 12...20),
            source: .presage
        )

        guard (0...100).contains(reading.stressLevel),
              (30...220).contains(reading.heartRate),
              reading.hrv > 0 && reading.hrv <= 250,
              (70...100).contains(reading.spO2),
              (4...40).contains(reading.respiratoryRate) else {
            throw NSError(domain: "PresageService", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Reading out of valid range"])
        }

        return reading
    }
}
