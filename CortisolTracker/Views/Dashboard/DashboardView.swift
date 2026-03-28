import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "F2F2F7").ignoresSafeArea()

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
                ZStack {
                    Circle()
                        .stroke(Color(hex: "E5E7EB"), lineWidth: 16)
                        .frame(width: 160, height: 160)
                    Circle()
                        .trim(from: 0, to: reading.stressLevel / 100)
                        .stroke(stressColor(for: reading.stressCategory), style: StrokeStyle(lineWidth: 16, lineCap: .round))
                        .frame(width: 160, height: 160)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.8), value: reading.stressLevel)
                    VStack(spacing: 2) {
                        Text("\(Int(reading.stressLevel))")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                        Text(reading.stressCategory.rawValue)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(stressColor(for: reading.stressCategory))
                    }
                }
                .padding(.top, 8)
                Text("Last scan \(reading.timestamp, style: .relative) ago")
                    .font(.caption)
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
