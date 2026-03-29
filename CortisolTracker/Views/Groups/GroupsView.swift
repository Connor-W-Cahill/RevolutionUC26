import SwiftUI

// MARK: - Groups ViewModel

@Observable
class GroupsViewModel {
    var groups: [StressGroup] = []
    var dailyStats: [String: GroupDailyStat] = [:]  // keyed by groupID
    var isLoading = false
    var error: String?

    private let firebase = FirebaseService.shared

    func loadGroups() async {
        guard let userID = firebase.currentUserID else { return }
        isLoading = true
        error = nil

        do {
            groups = try await firebase.fetchGroups(userID: userID)

            await withTaskGroup(of: (String, GroupDailyStat?).self) { taskGroup in
                for group in groups {
                    taskGroup.addTask {
                        let stats = try? await self.firebase.fetchGroupDailyStats(groupID: group.id, limit: 1)
                        return (group.id, stats?.first)
                    }
                }
                for await (groupID, stat) in taskGroup {
                    if let stat = stat {
                        dailyStats[groupID] = stat
                    }
                }
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func createGroup(name: String) async {
        do {
            let group = try await firebase.createGroup(name: name)
            groups.insert(group, at: 0)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func addMember(to group: StressGroup, memberID: String) async {
        do {
            try await firebase.addGroupMember(groupID: group.id, memberID: memberID)
            if let idx = groups.firstIndex(where: { $0.id == group.id }) {
                groups[idx].memberIDs.append(memberID)
            }
            // Trigger stats recompute
            try await firebase.recomputeGroupDailyStats(groupID: group.id)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Groups View

struct GroupsView: View {
    @State private var viewModel = GroupsViewModel()
    @State private var showCreateGroup = false

    var body: some View {
        NavigationStack {
            List {
                if viewModel.groups.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        "No Groups Yet",
                        systemImage: "person.3",
                        description: Text("Create a group to track stress with friends")
                    )
                }

                ForEach(viewModel.groups) { group in
                    NavigationLink {
                        GroupDetailView(group: group, viewModel: viewModel)
                    } label: {
                        GroupRow(group: group, stat: viewModel.dailyStats[group.id])
                    }
                }
            }
            .navigationTitle("Groups")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showCreateGroup = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateGroup) {
                CreateGroupSheet(viewModel: viewModel)
            }
            .task {
                await viewModel.loadGroups()
            }
            .refreshable {
                await viewModel.loadGroups()
            }
            .overlay {
                if viewModel.isLoading { ProgressView() }
            }
        }
    }
}

// MARK: - Group Row

struct GroupRow: View {
    let group: StressGroup
    let stat: GroupDailyStat?

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((stat?.stressCategory?.brandColor ?? .deepTeal).opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "person.3.fill")
                    .font(.callout)
                    .foregroundStyle(stat?.stressCategory?.brandColor ?? .deepTeal)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.body.weight(.medium))
                Text("\(group.memberIDs.count) member\(group.memberIDs.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let stat = stat, let avg = stat.avgStress {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(avg))")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(stat.stressCategory?.brandColor ?? .primary)
                    Text("avg stress")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No data")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Group Detail View

struct GroupDetailView: View {
    let group: StressGroup
    var viewModel: GroupsViewModel
    @State private var stats: [GroupDailyStat] = []
    @State private var isLoadingStats = false
    @State private var showAddMember = false

    private let firebase = FirebaseService.shared

    var body: some View {
        List {
            // Stats overview
            Section("This Week's Trends") {
                if isLoadingStats {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if stats.isEmpty {
                    Text("No data yet — members need to record readings.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(stats.prefix(7)) { stat in
                        HStack {
                            Text(stat.date)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if let avg = stat.avgStress {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(stat.stressCategory?.brandColor ?? .gray)
                                        .frame(width: 8, height: 8)
                                    Text("\(Int(avg)) avg")
                                        .font(.subheadline.weight(.medium))
                                }
                            } else {
                                Text("No data")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            Text("\(stat.activeMemberCount)/\(stat.memberCount) active")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Members
            Section("Members (\(group.memberIDs.count))") {
                ForEach(group.memberIDs, id: \.self) { memberID in
                    HStack {
                        Circle()
                            .fill(Color.deepTeal.opacity(0.15))
                            .frame(width: 32, height: 32)
                            .overlay {
                                Image(systemName: "person.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color.deepTeal)
                            }
                        Text(memberID == firebase.currentUserID ? "You" : memberID)
                            .font(.subheadline)
                        if memberID == group.ownerID {
                            Spacer()
                            Text("Owner")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.secondary.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }

                if group.ownerID == firebase.currentUserID {
                    Button {
                        showAddMember = true
                    } label: {
                        Label("Add member", systemImage: "person.badge.plus")
                            .foregroundStyle(Color.deepTeal)
                    }
                }
            }
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddMember) {
            AddGroupMemberSheet(group: group, viewModel: viewModel)
        }
        .task {
            await loadStats()
        }
        .refreshable {
            await loadStats()
            try? await firebase.recomputeGroupDailyStats(groupID: group.id)
            await loadStats()
        }
    }

    private func loadStats() async {
        isLoadingStats = true
        stats = (try? await firebase.fetchGroupDailyStats(groupID: group.id, limit: 14)) ?? []
        isLoadingStats = false
    }
}

// MARK: - Create Group Sheet

struct CreateGroupSheet: View {
    var viewModel: GroupsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var groupName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Group Name") {
                    TextField("e.g., Study group, Family, Work team", text: $groupName)
                }
                Section {
                    Text("You'll be added as the owner. Invite friends after creating the group.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Create Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await viewModel.createGroup(name: groupName.trimmingCharacters(in: .whitespaces))
                            dismiss()
                        }
                    }
                    .disabled(groupName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Add Group Member Sheet

struct AddGroupMemberSheet: View {
    let group: StressGroup
    var viewModel: GroupsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var memberID = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("User ID") {
                    TextField("Enter user ID", text: $memberID)
                        .autocapitalization(.none)
                }
                Section {
                    Text("Ask your friend for their user ID (visible in their profile settings).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            await viewModel.addMember(to: group, memberID: memberID.trimmingCharacters(in: .whitespaces))
                            dismiss()
                        }
                    }
                    .disabled(memberID.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
