import SwiftUI

struct CalendarView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @State private var showAddActivity = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Month Heatmap
                    MonthHeatmapView(
                        stressAverages: viewModel.monthlyAverages,
                        selectedDate: $viewModel.selectedDate,
                        onMonthChange: { newMonth in
                            Task { await viewModel.loadMonthlyAverages(for: newMonth) }
                        }
                    )
                    .onChange(of: viewModel.selectedDate) { _, newDate in
                        Task { await viewModel.loadData(for: newDate) }
                    }

                    // Daily Summary
                    if let avg = viewModel.averageStress {
                        dailySummary(averageStress: avg)
                    }

                    // Readings
                    if !viewModel.readings.isEmpty {
                        readingsSection
                    }

                    // Activities
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
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddActivity) {
                AddActivitySheet(viewModel: viewModel)
            }
            .task {
                await viewModel.loadData(for: viewModel.selectedDate)
            }
        }
    }

    private func dailySummary(averageStress: Double) -> some View {
        let category = StressCategory(level: averageStress)
        return HStack {
            VStack(alignment: .leading) {
                Text("Daily Average")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(Int(averageStress))")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(category.brandColor)
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
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var readingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Readings")
                .font(.headline)

            ForEach(viewModel.readings) { reading in
                HStack {
                    // Spike indicator
                    if reading.isSpikeCandidate == true {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.stressHigh)
                    }
                    Text(reading.stressCategory.emoji)
                    VStack(alignment: .leading) {
                        Text("Stress: \(Int(reading.stressLevel))")
                            .font(.subheadline.weight(.medium))
                        Text(reading.timestamp, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("\(Int(reading.heartRate)) bpm")
                        Text("HRV: \(Int(reading.hrv))ms")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                Divider()
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var activitiesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Activities")
                .font(.headline)

            if viewModel.activities.isEmpty {
                Text("No activities logged")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(viewModel.activities) { activity in
                    HStack {
                        Image(systemName: activity.category.icon)
                            .foregroundStyle(.softTeal)
                            .frame(width: 30)
                        VStack(alignment: .leading) {
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
                    Divider()
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Month Heatmap

struct MonthHeatmapView: View {
    let stressAverages: [String: Double]
    @Binding var selectedDate: Date
    let onMonthChange: (Date) -> Void

    @State private var displayedMonth: Date = Date()

    private let calendar = Calendar.current
    private let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: displayedMonth)
    }

    private var daysGrid: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let firstDay = interval.start
        // weekday: 1=Sun, 2=Mon ... shift to 0-indexed with Sunday=0
        let firstWeekday = (calendar.component(.weekday, from: firstDay) - 1 + 7) % 7
        let numDays = calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 30

        var grid: [Date?] = Array(repeating: nil, count: firstWeekday)
        for day in 0..<numDays {
            grid.append(calendar.date(byAdding: .day, value: day, to: firstDay))
        }
        while grid.count % 7 != 0 { grid.append(nil) }
        return grid
    }

    private func dotColor(for date: Date) -> Color? {
        let key = dayFormatter.string(from: date)
        guard let avg = stressAverages[key] else { return nil }
        switch avg {
        case 0..<25: return .stressLow
        case 25..<50: return .stressModerate
        case 50..<75: return .stressElevated
        default: return .stressHigh
        }
    }

    private func changeMonth(_ delta: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth) else { return }
        displayedMonth = newMonth
        onMonthChange(newMonth)
    }

    var body: some View {
        VStack(spacing: 10) {
            // Month navigation
            HStack {
                Button { changeMonth(-1) } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(.deepTeal)
                        .frame(width: 32, height: 32)
                }
                Spacer()
                Text(monthTitle)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button { changeMonth(1) } label: {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.deepTeal)
                        .frame(width: 32, height: 32)
                }
            }

            // Day-of-week headers
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                ForEach(Array(["S","M","T","W","T","F","S"].enumerated()), id: \.offset) { _, label in
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(daysGrid.enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                        let isToday = calendar.isDateInToday(date)
                        let dot = dotColor(for: date)

                        VStack(spacing: 2) {
                            ZStack {
                                if isSelected {
                                    Circle().fill(Color.deepTeal)
                                } else if isToday {
                                    Circle().stroke(Color.deepTeal, lineWidth: 1)
                                }
                                Text("\(calendar.component(.day, from: date))")
                                    .font(.caption2)
                                    .foregroundStyle(isSelected ? .white : .primary)
                            }
                            .frame(width: 26, height: 26)

                            Circle()
                                .fill(dot ?? .clear)
                                .frame(width: 5, height: 5)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedDate = date
                        }
                    } else {
                        Color.clear.frame(height: 36)
                    }
                }
            }

            // Legend
            HStack(spacing: 12) {
                ForEach([
                    ("Low", Color.stressLow),
                    ("Moderate", Color.stressModerate),
                    ("High", Color.stressElevated),
                    ("Very High", Color.stressHigh)
                ], id: \.0) { label, color in
                    HStack(spacing: 4) {
                        Circle().fill(color).frame(width: 6, height: 6)
                        Text(label).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onChange(of: selectedDate) { _, newDate in
            if !calendar.isDate(newDate, equalTo: displayedMonth, toGranularity: .month) {
                displayedMonth = newDate
            }
        }
        .onAppear {
            displayedMonth = selectedDate
        }
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

// MARK: - Add Activity Sheet (unchanged)

struct AddActivitySheet: View {
    @ObservedObject var viewModel: CalendarViewModel
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
