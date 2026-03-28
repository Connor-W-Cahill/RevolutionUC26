import SwiftUI

struct CalendarView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @State private var showAddActivity = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Date Picker
                    DatePicker("Select Date", selection: $viewModel.selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(.deepTeal)
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
        HStack {
            VStack(alignment: .leading) {
                Text("Daily Average")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Stress: \(Int(averageStress))")
                    .font(.title2.weight(.bold))
            }
            Spacer()
            Text("\(viewModel.readings.count) readings")
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
