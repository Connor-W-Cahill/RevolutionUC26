import SwiftUI

struct CalendarView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @State private var showAddActivity = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "F2F2F7").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Calendar
                        DatePicker("Select Date", selection: $viewModel.selectedDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .tint(Color(hex: "1A6B5C"))
                            .padding()
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
                            .onChange(of: viewModel.selectedDate) { _, newDate in
                                Task { await viewModel.loadData(for: newDate) }
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
            }
            .navigationTitle("Calendar")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddActivity = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color(hex: "1A6B5C"))
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
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Daily Average")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Stress: \(Int(averageStress))")
                    .font(.title2.weight(.bold))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(viewModel.readings.count)")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color(hex: "1A6B5C"))
                Text("readings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    private var readingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Readings")
                .font(.headline)
            ForEach(viewModel.readings) { reading in
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
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(reading.heartRate)) bpm")
                        Text("HRV: \(Int(reading.hrv))ms")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                if reading.id != viewModel.readings.last?.id { Divider() }
            }
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
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
                            .foregroundStyle(Color(hex: "2D9F8F").opacity(0.5))
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
                                .fill(Color(hex: "1A6B5C").opacity(0.1))
                                .frame(width: 36, height: 36)
                            Image(systemName: activity.category.icon)
                                .font(.subheadline)
                                .foregroundStyle(Color(hex: "1A6B5C"))
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
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
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
            .tint(Color(hex: "1A6B5C"))
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
