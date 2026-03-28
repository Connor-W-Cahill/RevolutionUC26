import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel

    private var greetingTitle: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let first = authViewModel.user?.displayName.components(separatedBy: " ").first ?? ""
        let base = hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : "Good evening"
        return first.isEmpty ? base : "\(base), \(first)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Stress Level Card
                    stressCard

                    // Scan Button
                    scanButton

                    // Vitals Grid
                    if let reading = viewModel.latestReading {
                        vitalsGrid(reading: reading)
                    }

                    // Today's Readings
                    if !viewModel.todayReadings.isEmpty {
                        todaySection
                    }
                }
                .padding()
            }
            .navigationTitle(greetingTitle)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image(systemName: "bell")
                        .foregroundStyle(.deepTeal)
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        if let user = authViewModel.user {
                            Text(user.displayName)
                        }
                        Button(role: .destructive) {
                            authViewModel.signOut()
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "person.circle")
                    }
                }
            }
            .task {
                await viewModel.loadData()
            }
            .refreshable {
                await viewModel.loadData()
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") { viewModel.error = nil }
            } message: {
                Text(viewModel.error ?? "")
            }
        }
    }

    private var stressCard: some View {
        VStack(spacing: 12) {
            if let reading = viewModel.latestReading {
                Text(reading.stressCategory.emoji)
                    .font(.system(size: 60))
                Text("Stress Level")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(Int(reading.stressLevel))")
                    .font(.system(size: 48, weight: .bold))
                Text(reading.stressCategory.rawValue)
                    .font(.headline)
                    .foregroundStyle(stressColor(for: reading.stressCategory))
            } else {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                Text("No readings yet")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("Tap scan to measure your vitals")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var scanButton: some View {
        Button {
            Task { await viewModel.startScan() }
        } label: {
            HStack {
                if viewModel.presage.isScanning {
                    ProgressView()
                        .tint(.white)
                    Text("Scanning... \(Int(viewModel.presage.scanProgress * 100))%")
                } else {
                    Image(systemName: "camera.viewfinder")
                    Text("Scan Vitals")
                }
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.presage.isScanning ? Color.gray : Color.deepTeal)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(viewModel.presage.isScanning)
    }

    private func vitalsGrid(reading: CortisolReading) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            VitalCard(title: "Heart Rate", value: "\(Int(reading.heartRate))", unit: "bpm", icon: "heart.fill", color: .warmCoral)
            VitalCard(title: "HRV", value: "\(Int(reading.hrv))", unit: "ms", icon: "waveform.path.ecg", color: .calmBlue)
            VitalCard(title: "SpO2", value: "\(Int(reading.spO2))", unit: "%", icon: "lungs.fill", color: .softTeal)
            VitalCard(title: "Resp Rate", value: "\(Int(reading.respiratoryRate))", unit: "br/min", icon: "wind", color: .deepTeal)
        }
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Today's Readings")
                    .font(.headline)
                Spacer()
                if let avg = viewModel.averageStressToday {
                    Text("Avg: \(Int(avg))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(viewModel.todayReadings) { reading in
                HStack {
                    Text(reading.stressCategory.emoji)
                    VStack(alignment: .leading) {
                        Text("Stress: \(Int(reading.stressLevel))")
                            .font(.subheadline.weight(.medium))
                        Text(reading.timestamp, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(Int(reading.heartRate)) bpm")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func stressColor(for category: StressCategory) -> Color {
        category.brandColor
    }
}

struct VitalCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.title.weight(.bold))
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
