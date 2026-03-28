import SwiftUI
import SmartSpectraSwiftSDK

struct ScanView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var sdk = SmartSpectraSwiftSDK.shared
    let presage = PresageService.shared
    let onComplete: (CortisolReading) -> Void
    let userID: String

    @State private var reading: CortisolReading?
    @State private var showResult = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showResult, let reading = reading {
                    resultView(reading: reading)
                } else {
                    // Presage camera UI
                    SmartSpectraView()
                        .onChange(of: sdk.metricsBuffer?.pulse.strict.value) { _, newValue in
                            guard let newValue, newValue > 0 else { return }
                            // Measurement complete — extract reading
                            if let extracted = presage.extractReading(userID: userID) {
                                reading = extracted
                                showResult = true
                            }
                        }

                    if !sdk.resultErrorText.isEmpty {
                        Text(sdk.resultErrorText)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding()
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .navigationTitle("Scan Vitals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func resultView(reading: CortisolReading) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Stress indicator
                Text(reading.stressCategory.emoji)
                    .font(.system(size: 64))
                Text("Stress: \(reading.stressCategory.rawValue)")
                    .font(.title2.weight(.bold))
                Text("Score: \(Int(reading.stressLevel))/100")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                // Vitals
                VStack(spacing: 12) {
                    vitalRow(icon: "heart.fill", title: "Pulse Rate", value: "\(Int(reading.pulseRate)) bpm", color: .red)
                    vitalRow(icon: "wind", title: "Breathing Rate", value: "\(Int(reading.breathingRate)) br/min", color: .green)
                    if let sys = reading.bloodPressureSystolic {
                        vitalRow(icon: "waveform.path.ecg", title: "Blood Pressure", value: "\(Int(sys)) mmHg", color: .blue)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Save button
                Button {
                    onComplete(reading)
                    dismiss()
                } label: {
                    Text("Save Reading")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button("Discard") {
                    dismiss()
                }
                .foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    private func vitalRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 30)
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
        }
    }
}
