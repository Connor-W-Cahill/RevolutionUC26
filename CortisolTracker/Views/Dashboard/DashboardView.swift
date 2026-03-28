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
            ZStack {
                Color(hex: "F2F2F7").ignoresSafeArea()

                    // Spike Banner (shown when recent spike detected)
                    if let spike = viewModel.latestSpike {
                        SpikeBannerView(spike: spike)
                    }

                    // Scan Button
                    scanButton

                    // Streak Badges
                    if let streak = viewModel.streak {
                        StreakBadgesView(streak: streak)
                    }

                    // Vitals Grid
                    if let reading = viewModel.latestReading {
                        vitalsGrid(reading: reading)
                    }

                    // Today's Readings
                    if !viewModel.todayReadings.isEmpty {
                        todaySection
                    }
                    .padding()
                }
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
                            .foregroundStyle(Color(hex: "1A6B5C"))
                    }
                }
            }
            .task { await viewModel.loadData() }
            .refreshable { await viewModel.loadData() }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") { viewModel.error = nil }
            } message: {
                Text(viewModel.error ?? "")
            }
        }
    }

    private var stressCard: some View {
        VStack(spacing: 16) {
            if let reading = viewModel.latestReading {
                Text(reading.stressCategory.emoji)
                    .font(.system(size: 60))
                Text("Stress Index")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 56))
                        .foregroundStyle(Color(hex: "2D9F8F"))
                    Text("No readings yet")
                        .font(.title3.weight(.semibold))
                    Text("Tap Scan Vitals to take your first reading")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 20)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    private var scanButton: some View {
        Button {
            Task { await viewModel.startScan() }
        } label: {
            HStack(spacing: 10) {
                if viewModel.presage.isScanning {
                    ProgressView().tint(.white)
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
            .background(
                viewModel.presage.isScanning
                    ? Color.gray
                    : LinearGradient(colors: [Color(hex: "1A6B5C"), Color(hex: "2D9F8F")], startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color(hex: "1A6B5C").opacity(0.3), radius: 8, y: 4)
        }
        .disabled(viewModel.presage.isScanning)
    }

    private func vitalsGrid(reading: CortisolReading) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            VitalCard(title: "Heart Rate", value: "\(Int(reading.heartRate))", unit: "bpm", icon: "heart.fill", color: Color(hex: "E85D75"))
            VitalCard(title: "HRV", value: "\(Int(reading.hrv))", unit: "ms", icon: "waveform.path.ecg", color: Color(hex: "5B9BD5"))
            VitalCard(title: "SpO2", value: "\(Int(reading.spO2))", unit: "%", icon: "lungs.fill", color: Color(hex: "2D9F8F"))
            VitalCard(title: "Resp Rate", value: "\(Int(reading.respiratoryRate))", unit: "br/min", icon: "wind", color: Color(hex: "8B7EC8"))
        }
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's Readings")
                    .font(.headline)
                Spacer()
                if let avg = viewModel.averageStressToday {
                    Text("Avg: \(Int(avg))")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color(hex: "1A6B5C"))
                }
            }
            ForEach(viewModel.todayReadings) { reading in
                HStack(spacing: 12) {
                    Text(reading.stressCategory.emoji)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
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
                if reading.id != viewModel.todayReadings.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    private func stressColor(for category: StressCategory) -> Color {
        switch category {
        case .low: return Color(hex: "A8E6CF")
        case .moderate: return Color(hex: "FFD93D")
        case .high: return Color(hex: "FF8C42")
        case .veryHigh: return Color(hex: "E85D75")
        }
    }
}

// MARK: - Spike Banner

struct SpikeBannerView: View {
    let spike: SpikeEvent
    @State private var isDismissed = false

    private var bannerColor: Color {
        switch spike.severity {
        case .mild: return .stressModerate
        case .moderate: return .stressElevated
        case .high: return .stressHigh
        }
    }

    var body: some View {
        if !isDismissed {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(spike.severity.emoji)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Stress Spike Detected")
                            .font(.headline)
                        Text(spike.triggerReason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button {
                        withAnimation { isDismissed = true }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    CopingActionButton(label: "Breathe 90s", icon: "wind") {}
                    CopingActionButton(label: "Walk 10 min", icon: "figure.walk") {}
                    CopingActionButton(label: "Hydrate", icon: "drop.fill") {}
                }
            }
            .padding()
            .background(bannerColor.opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(bannerColor.opacity(0.4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

struct CopingActionButton: View {
    let label: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption2.weight(.medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.deepTeal.opacity(0.1))
            .foregroundStyle(.deepTeal)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Streak Badges

struct StreakBadgesView: View {
    let streak: Streak

    var body: some View {
        HStack(spacing: 12) {
            StreakBadge(
                icon: "flame.fill",
                label: "Scan streak",
                current: streak.currentReadingStreak,
                best: streak.bestReadingStreak,
                color: .warmCoral
            )
            StreakBadge(
                icon: "figure.run",
                label: "Activity streak",
                current: streak.currentActivityStreak,
                best: streak.bestActivityStreak,
                color: .softTeal
            )
        }
    }
}

struct StreakBadge: View {
    let icon: String
    let label: String
    let current: Int
    let best: Int
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(current) day\(current == 1 ? "" : "s")")
                    .font(.subheadline.weight(.bold))
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if best > current {
                    Text("Best: \(best)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - VitalCard (unchanged)

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
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }
}
