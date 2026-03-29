import SwiftUI

struct ScanView: View {
    @Environment(\.dismiss) private var dismiss
    let presage = PresageService.shared
    let userID: String
    let onComplete: (CortisolReading) -> Void

    @State private var reading: CortisolReading?
    @State private var showResult = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showResult, let reading = reading {
                    resultView(reading: reading)
                } else {
                    scanView
                }
            }
            .background(AppTheme.background)
            .navigationTitle("Scan Vitals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppTheme.deepTeal)
                }
            }
        }
    }

    // MARK: - Scan View

    private var scanView: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("Get ready to scan")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Hold your phone steady\nand look at the camera")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if presage.isScanning {
                VStack(spacing: 12) {
                    ProgressView(value: presage.scanProgress)
                        .progressViewStyle(.linear)
                        .tint(AppTheme.deepTeal)
                        .padding(.horizontal, 40)
                    Text("\(Int(presage.scanProgress * 100))%")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding()
            } else {
                Button {
                    Task {
                        do {
                            let result = try await presage.startScan(userID: userID)
                            withAnimation(.easeInOut(duration: 0.3)) {
                                reading = result
                                showResult = true
                            }
                        } catch {
                            self.error = error.localizedDescription
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "camera.viewfinder")
                        Text("Start Scan")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.deepTeal)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 40)
                }
            }

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(AppTheme.stressHigh)
                    .padding()
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
    }

    // MARK: - Result View

    private func resultView(reading: CortisolReading) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Your Results")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .foregroundStyle(AppTheme.textSecondary)
                    .tracking(0.5)

                ZStack {
                    Circle()
                        .stroke(AppTheme.divider, lineWidth: 10)
                        .frame(width: 120, height: 120)
                    Circle()
                        .trim(from: 0, to: CGFloat(reading.stressLevel) / 100)
                        .stroke(
                            AppTheme.stressColor(for: reading.stressCategory),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(reading.stressLevel))")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                }

                Text(reading.stressCategory.rawValue)
                    .font(.headline)
                    .foregroundStyle(AppTheme.stressTextColor(for: reading.stressCategory))

                HStack(spacing: 12) {
                    resultVital(icon: "heart.fill", value: "\(Int(reading.pulseRate))", unit: "BPM", color: AppTheme.warmCoral)
                    resultVital(icon: "wind", value: "\(Int(reading.breathingRate))", unit: "br/min", color: AppTheme.calmBlue)
                    if let sys = reading.bloodPressureSystolic {
                        resultVital(icon: "waveform.path.ecg", value: "\(Int(sys))", unit: "mmHg", color: AppTheme.softPurple)
                    }
                }
                .padding(.vertical, 8)

                Button {
                    onComplete(reading)
                    dismiss()
                } label: {
                    Text("Save Reading")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.deepTeal)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    withAnimation {
                        self.reading = nil
                        showResult = false
                    }
                } label: {
                    Text("Scan Again")
                        .font(.headline)
                        .foregroundStyle(AppTheme.deepTeal)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.deepTeal.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.deepTeal, lineWidth: 2))
                }

                Button("Discard") { dismiss() }
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.top, 4)
            }
            .padding()
        }
    }

    private func resultVital(icon: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(color)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
            Text(unit)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }
}
