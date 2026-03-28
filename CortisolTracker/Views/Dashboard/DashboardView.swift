import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showScan = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    stressCard
                    scanButton
                    if let reading = viewModel.latestReading {
                        vitalsGrid(reading: reading)
                    }
                    if !viewModel.todayReadings.isEmpty {
                        todaySection
                    }
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .toolbar {
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
            .fullScreenCover(isPresented: $showScan) {
                if let userID = viewModel.currentUserID {
                    ScanView(userID: userID) { reading in
                        Task { await viewModel.saveReading(reading) }
                    }
                }
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
            showScan = true
        } label: {
            HStack {
                Image(systemName: "camera.viewfinder")
                Text("Scan Vitals")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.purple)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func vitalsGrid(reading: CortisolReading) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            VitalCard(title: "Pulse Rate", value: "\(Int(reading.pulseRate))", unit: "bpm", icon: "heart.fill", color: .red)
            VitalCard(title: "Breathing", value: "\(Int(reading.breathingRate))", unit: "br/min", icon: "wind", color: .green)
            if let sys = reading.bloodPressureSystolic {
                VitalCard(title: "Blood Pressure", value: "\(Int(sys))", unit: "mmHg", icon: "waveform.path.ecg", color: .blue)
            }
            VitalCard(title: "Stress", value: "\(Int(reading.stressLevel))", unit: "/100", icon: "brain.head.profile", color: .purple)
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
                    Text("\(Int(reading.pulseRate)) bpm")
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
        switch category {
        case .low: return .green
        case .moderate: return .yellow
        case .high: return .orange
        case .veryHigh: return .red
        }
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
