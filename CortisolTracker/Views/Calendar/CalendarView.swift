import SwiftUI

struct CalendarView: View {
    @Environment(CalendarViewModel.self) private var viewModel
    @State private var showAddActivity = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    DatePicker("Select Date", selection: Binding(
                        get: { viewModel.selectedDate },
                        set: { newDate in
                            Task { await viewModel.loadData(for: newDate) }
                        }
                    ), displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(AppTheme.deepTeal)

                    if viewModel.isLoading {
                        ProgressView()
                            .padding()
                    }

                    if let avg = viewModel.averageStress {
                        dailySummary(averageStress: avg)
                    }

                    if !viewModel.readings.isEmpty {
                        readingsSection
                    }

                    activitiesSection
                }
                .padding()
            }
            .navigationTitle("Calendar")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddActivity = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(AppTheme.deepTeal)
                    }
                }
            }
            .sheet(isPresented: $showAddActivity) {
                AddActivitySheet(viewModel: viewModel)
            }
            .task { await viewModel.loadData(for: viewModel.selectedDate) }
        }
    }

    private func dailySummary(averageStress: Double) -> some View {
        let category = StressCategory(level: averageStress)
        return HStack {
            VStack(alignment: .leading) {
                Text("Daily Average")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(Int(averageStress))")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.stressColor(for: category))
                    Text(category.rawValue)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("\(viewModel.readings.count) reading\(viewModel.readings.count == 1 ? "" : "s")")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
        .shadow(color: .black.opacity(0.06), radius: AppTheme.cardShadow, y: 2)
    }

    private var readingsSection: some View {
        let readings: [CortisolReading] = viewModel.readings
        return VStack(alignment: .leading, spacing: 12) {
            Text("Readings")
                .font(.headline)
            ForEach(readings) { (reading: CortisolReading) in
                HStack {
                    if reading.isSpikeCandidate == true {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(AppTheme.stressHigh)
                    }
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
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(reading.pulseRate)) bpm")
                        Text("\(Int(reading.breathingRate)) br/min")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                if reading.id != readings.last?.id { Divider() }
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
        .shadow(color: .black.opacity(0.06), radius: AppTheme.cardShadow, y: 2)
    }

    private var activitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activities")
                .font(.headline)

            if viewModel.activities.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.system(size: 32))
                            .foregroundStyle(AppTheme.softTeal.opacity(0.5))
                        Text("No activities logged")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
            } else {
                ForEach(viewModel.activities) { activity in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.deepTeal.opacity(0.1))
                                .frame(width: 36, height: 36)
                            Image(systemName: activity.category.icon)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.deepTeal)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(activity.title)
                                .font(.subheadline.weight(.medium))
                            if let notes = activity.notes {
                                Text(notes)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        Spacer()
                        if let rating = activity.rating {
                            HStack(spacing: 2) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= rating ? "star.fill" : "star")
                                        .font(.caption2)
                                        .foregroundStyle(.yellow)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    if activity.id != viewModel.activities.last?.id { Divider() }
                }
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
        .shadow(color: .black.opacity(0.06), radius: AppTheme.cardShadow, y: 2)
    }
}

// MARK: - StressCategory convenience init

extension StressCategory {
    init(level: Double) {
        switch level {
        case 0..<25: self = .low
        case 25..<50: self = .moderate
        case 50..<75: self = .high
        default: self = .veryHigh
        }
    }
}

// MARK: - Add Activity Sheet

struct AddActivitySheet: View {
    var viewModel: CalendarViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var category: ActivityCategory = .sleep
    @State private var title = ""
    @State private var notes = ""
    @State private var rating = 3

    var body: some View {
        NavigationStack {
            Form {
                Picker("Category", selection: $category) {
                    ForEach(ActivityCategory.allCases, id: \.self) { cat in
                        Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                    }
                }
                TextField("Title", text: $title)
                TextField("Notes (optional)", text: $notes)
                Stepper("Rating: \(rating)/5", value: $rating, in: 1...5)
            }
            .navigationTitle("Log Activity")
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppTheme.deepTeal)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.addActivity(
                                category: category,
                                title: title,
                                notes: notes.isEmpty ? nil : notes,
                                rating: rating
                            )
                            dismiss()
                        }
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}
