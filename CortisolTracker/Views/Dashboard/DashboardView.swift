import SwiftUI
import Charts

struct DashboardView: View {
    @Environment(DashboardViewModel.self) private var viewModel
    @Environment(AuthViewModel.self) var authViewModel
    @State private var showScan = false
    @State private var showEditName = false

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
                    if !viewModel.weeklyTrend.isEmpty {
                        trendChart
                    }
                    if !viewModel.todayReadings.isEmpty {
                        todaySection
                    }
                }
                .padding()
            }
            .background(AppTheme.background)
            .navigationBarHidden(true)
            .task { await viewModel.loadData() }
            .refreshable { await viewModel.loadData() }
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
            .sheet(isPresented: $showEditName) {
                EditNameSheet(authViewModel: authViewModel)
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
                    Text(user.email)
                }
                Button {
                    showEditName = true
                } label: {
                    Label("Edit Name", systemImage: "pencil")
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
                Text("High Cortisol")
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

    // MARK: - Weekly Trend Chart

    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Cortisol Trend")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("7 days")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Chart(viewModel.weeklyTrend, id: \.date) { item in
                BarMark(
                    x: .value("Day", item.date, unit: .day),
                    y: .value("Cortisol", item.avgStress)
                )
                .foregroundStyle(AppTheme.stressColor(for: StressCategory(level: item.avgStress)))
                .cornerRadius(4)
            }
            .chartYScale(domain: 0...100)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                }
            }
            .frame(height: 160)
        }
        .padding(16)
        .cardStyle()
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

// MARK: - Edit Name Sheet

struct EditNameSheet: View {
    var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Display Name") {
                    TextField("Your name", text: $name)
                        .textContentType(.name)
                }
            }
            .navigationTitle("Edit Name")
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppTheme.deepTeal)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await authViewModel.updateDisplayName(name)
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                name = authViewModel.user?.displayName ?? ""
            }
        }
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

#Preview {
    DashboardView()
        .environment(DashboardViewModel())
        .environment(AuthViewModel())
}
