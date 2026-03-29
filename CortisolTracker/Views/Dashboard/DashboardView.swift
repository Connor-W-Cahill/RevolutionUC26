import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showScan = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    greetingBar
                    stressCard
                    if let reading = viewModel.latestReading {
                        vitalsGrid(reading: reading)
                    }
                    scanButton
                    if !viewModel.todayReadings.isEmpty {
                        todaySection
                    }
                }
                .padding()
            }
            .background(AppTheme.background)
            .navigationBarHidden(true)
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

    // MARK: - Greeting

    private var greetingBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(greetingText)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                Text(authViewModel.user?.displayName ?? "there")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            Spacer()
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
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.deepTeal)
            }
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning,"
        case 12..<17: return "Good afternoon,"
        default: return "Good evening,"
        }
    }

    // MARK: - Stress Card

    private var stressCard: some View {
        VStack(spacing: 12) {
            if let reading = viewModel.latestReading {
                Text("Current Stress")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .foregroundStyle(AppTheme.textSecondary)
                    .tracking(0.5)

                // Radial gauge
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
            } else {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 60))
                    .foregroundStyle(AppTheme.textSecondary)
                Text("No readings yet")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textSecondary)
                Text("Tap scan to measure your vitals")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .cardStyle()
    }

    // MARK: - Vitals Grid

    private func vitalsGrid(reading: CortisolReading) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vitals")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            HStack(spacing: 12) {
                VitalCard(title: "Pulse Rate", value: "\(Int(reading.pulseRate))", unit: "BPM", icon: "heart.fill", color: AppTheme.warmCoral)
                VitalCard(title: "Breathing", value: "\(Int(reading.breathingRate))", unit: "br/min", icon: "wind", color: AppTheme.calmBlue)
                if let sys = reading.bloodPressureSystolic {
                    VitalCard(title: "Blood Pressure", value: "\(Int(sys))", unit: "mmHg", icon: "waveform.path.ecg", color: AppTheme.softPurple)
                }
            }
        }
    }

    // MARK: - Scan Button

    private var scanButton: some View {
        Button {
            showScan = true
        } label: {
            HStack {
                Image(systemName: "camera.viewfinder")
                Text("Take Reading")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.deepTeal)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Today Section

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Today's Readings")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                if let avg = viewModel.averageStressToday {
                    Text("Avg: \(Int(avg))")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            ForEach(viewModel.todayReadings) { reading in
                HStack {
                    Circle()
                        .fill(AppTheme.stressColor(for: reading.stressCategory))
                        .frame(width: 10, height: 10)
                    VStack(alignment: .leading) {
                        Text("Stress: \(Int(reading.stressLevel))")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(reading.timestamp, style: .time)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    Text("\(Int(reading.pulseRate)) bpm")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .cardStyle()
    }
}

// MARK: - Vital Card

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
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
            Text(unit)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }
}
