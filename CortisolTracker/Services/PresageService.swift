import Foundation
import SwiftUI
import SmartSpectraSwiftSDK

class PresageService: ObservableObject {
    static let shared = PresageService()

    let sdk = SmartSpectraSwiftSDK.shared
    @Published var hasMeasurement = false

    private init() {
        sdk.setApiKey("BAThk0fR6M9h7pNP5wahf9uPo9BV3Zlr5x7S71ny")
        sdk.setSmartSpectraMode(.spot)
        sdk.setMeasurementDuration(30.0)
        sdk.setCameraPosition(.front)
        sdk.setRecordingDelay(3)
        sdk.setShowFps(false)
    }

    /// Extract a reading from the latest SDK metrics buffer.
    func extractReading(userID: String) -> CortisolReading? {
        guard let metrics = sdk.metricsBuffer, metrics.isInitialized else {
            return nil
        }

        let pulseRate = Double(metrics.pulse.strict.value)
        let breathingRate = Double(metrics.breathing.strict.value)
        guard pulseRate > 0, breathingRate > 0 else {
            return nil
        }

        var systolic: Double?
        let bpPhasic = metrics.bloodPressure.phasic
        if !bpPhasic.isEmpty {
            systolic = Double(bpPhasic.last?.value ?? 0)
        }

        let reading = CortisolReading(
            userID: userID,
            pulseRate: pulseRate,
            breathingRate: breathingRate,
            bloodPressureSystolic: systolic,
            source: .presage
        )

        guard (0...100).contains(reading.stressLevel),
              (30...220).contains(reading.heartRate),
              reading.hrv > 0 && reading.hrv <= 250,
              (70...100).contains(reading.spO2),
              (4...40).contains(reading.respiratoryRate) else {
            return nil
        }

        return reading
    }
}
