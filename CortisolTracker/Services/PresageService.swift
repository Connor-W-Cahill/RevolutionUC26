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

    /// Extract a CortisolReading from the latest SDK metricsBuffer.
    /// Call this after the SDK measurement completes (metricsBuffer is populated).
    func extractReading(userID: String) -> CortisolReading? {
        guard let metrics = sdk.metricsBuffer, metrics.isInitialized else {
            return nil
        }

        let pulseRate = Double(metrics.pulse.strict.value)
        let breathingRate = Double(metrics.breathing.strict.value)

        guard pulseRate > 0, breathingRate > 0 else { return nil }

        // Extract blood pressure if available
        var systolic: Double?
        var diastolic: Double?
        let bpPhasic = metrics.bloodPressure.phasic
        if !bpPhasic.isEmpty {
            // Use the latest phasic BP value as systolic estimate
            systolic = Double(bpPhasic.last?.value ?? 0)
        }

        return CortisolReading(
            userID: userID,
            pulseRate: pulseRate,
            breathingRate: breathingRate,
            bloodPressureSystolic: systolic,
            bloodPressureDiastolic: diastolic
        )
    }
}
