import SwiftUI
import AVFoundation

struct ScanView: View {
    @Environment(\.dismiss) private var dismiss
    let presage = PresageService.shared
    let userID: String
    let onComplete: (CortisolReading) -> Void

    @State private var reading: CortisolReading?
    @State private var showResult = false
    @State private var error: String?
    @State private var pulseAnimation = false

#if os(iOS)
    @State private var camera = CameraService()
#endif

    var body: some View {
        NavigationStack {
            ZStack {
                if showResult, let reading = reading {
                    resultView(reading: reading)
                        .background(AppTheme.background)
                } else {
                    scanView
                }
            }
            .navigationTitle(showResult ? "Your Results" : "Scan Vitals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
#if os(iOS)
                        camera.stop()
#endif
                        dismiss()
                    }
                    .foregroundStyle(showResult ? AppTheme.deepTeal : .white)
                }
            }
            .toolbarBackground(showResult ? .visible : .hidden, for: .navigationBar)
        }
#if os(iOS)
        .task {
            if !showResult {
                await camera.start()
            }
        }
        .onDisappear {
            camera.stop()
        }
#endif
    }

    // MARK: - Scan View

    private var scanView: some View {
        ZStack {
#if os(iOS)
            // Live camera feed
            if camera.isAuthorized {
                CameraPreviewView(session: camera.session)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }
#else
            Color.black.ignoresSafeArea()
#endif

            // Dark gradient overlay at top and bottom
            VStack {
                LinearGradient(
                    colors: [.black.opacity(0.6), .clear],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 160)
                Spacer()
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 260)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top status
                VStack(spacing: 6) {
                    if presage.isScanning {
                        Text("Analyzing cortisol levels...")
                            .font(.headline)
                            .foregroundStyle(.white)
                    } else {
                        Text("Position your face in the oval")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                }
                .padding(.top, 16)

                Spacer()

                // Face oval guide
                faceOvalGuide

                Spacer()

                // Bottom controls
                VStack(spacing: 16) {
                    if presage.isScanning {
                        scanProgressView
                    } else {
                        startScanButton
                    }

                    if let error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(AppTheme.stressHigh)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

#if os(iOS)
                    if camera.permissionDenied {
                        Text("Camera access denied. Enable it in Settings to use face scanning.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
#endif
                }
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Face Oval Guide

    private var faceOvalGuide: some View {
        ZStack {
            // Oval cutout effect — white border
            Ellipse()
                .stroke(
                    presage.isScanning
                        ? AppTheme.softTeal
                        : Color.white.opacity(0.6),
                    lineWidth: presage.isScanning ? 3 : 2
                )
                .frame(width: 200, height: 270)
                .scaleEffect(pulseAnimation && presage.isScanning ? 1.03 : 1.0)
                .animation(
                    presage.isScanning
                        ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                        : .default,
                    value: pulseAnimation
                )

            // Scan line sweep during active scan
            if presage.isScanning {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.softTeal.opacity(0), AppTheme.softTeal, AppTheme.softTeal.opacity(0)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: 180, height: 2)
                    .offset(y: scanLineOffset)
                    .clipShape(Ellipse().size(width: 200, height: 270).offset(x: -100, y: -135))
            }
        }
        .onChange(of: presage.isScanning) { _, scanning in
            pulseAnimation = scanning
        }
    }

    private var scanLineOffset: CGFloat {
        let progress = presage.scanProgress
        return CGFloat(-135 + progress * 270)
    }

    // MARK: - Progress & Button

    private var scanProgressView: some View {
        VStack(spacing: 10) {
            ProgressView(value: presage.scanProgress)
                .progressViewStyle(.linear)
                .tint(AppTheme.softTeal)
                .padding(.horizontal, 40)
            Text("\(Int(presage.scanProgress * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private var startScanButton: some View {
        Button {
            Task {
                do {
                    let result = try await presage.startScan(userID: userID)
#if os(iOS)
                    camera.stop()
#endif
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
                    resultVital(icon: "heart.fill",         value: "\(Int(reading.pulseRate))",     unit: "BPM",    color: AppTheme.warmCoral)
                    resultVital(icon: "wind",               value: "\(Int(reading.breathingRate))", unit: "br/min", color: AppTheme.calmBlue)
                    resultVital(icon: "waveform.path.ecg",  value: "\(Int(reading.hrv))",           unit: "HRV ms", color: AppTheme.softPurple)
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
#if os(iOS)
                    Task { await camera.start() }
#endif
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
