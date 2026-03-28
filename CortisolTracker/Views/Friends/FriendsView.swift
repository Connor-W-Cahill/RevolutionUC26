import SwiftUI

struct FriendsView: View {
    @StateObject private var viewModel = FriendsViewModel()
    @State private var showSearch = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "F2F2F7").ignoresSafeArea()

                ForEach(viewModel.friends) { friend in
                    NavigationLink {
                        ShareSettingsView(friend: friend, viewModel: viewModel)
                    } label: {
                        FriendRow(friend: friend, share: viewModel.share(with: friend))
                    }
                }
            }
            .navigationTitle("Friends")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSearch = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .foregroundStyle(Color(hex: "1A6B5C"))
                    }
                }
            }
            .sheet(isPresented: $showSearch) {
                SearchFriendsSheet(viewModel: viewModel)
            }
            .task { await viewModel.loadFriends() }
            .refreshable { await viewModel.loadFriends() }
        }
    }
}

// MARK: - Friend Row

struct FriendRow: View {
    let friend: Friend
    let share: Share?

    private var avatarColor: Color {
        friend.stressCategory?.brandColor ?? .deepTeal
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(avatarColor.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay {
                    Text(String(friend.displayName.prefix(1)).uppercased())
                        .font(.headline)
                        .foregroundStyle(avatarColor)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(friend.displayName)
                    .font(.body.weight(.semibold))
                if let time = friend.latestReadingTime {
                    Text(time, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No readings yet")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                // Share status badge
                if let share = share, share.isActive {
                    Label("Sharing", systemImage: "eye.fill")
                        .font(.caption2)
                        .foregroundStyle(.deepTeal)
                }
            }

            Spacer()

            if let category = friend.stressCategory {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(category.emoji)
                        .font(.title2)
                    Text(category.rawValue)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }
}

// MARK: - Share Settings View

struct ShareSettingsView: View {
    let friend: Friend
    @ObservedObject var viewModel: FriendsViewModel

    @State private var latestStress: Bool = false
    @State private var history: Bool = false
    @State private var groupStats: Bool = false
    @State private var isSharing: Bool = false

    private var avatarColor: Color {
        friend.stressCategory?.brandColor ?? .deepTeal
    }

    var body: some View {
        List {
            // Friend header
            Section {
                HStack(spacing: 14) {
                    Circle()
                        .fill(avatarColor.opacity(0.2))
                        .frame(width: 52, height: 52)
                        .overlay {
                            Text(String(friend.displayName.prefix(1)).uppercased())
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(avatarColor)
                        }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(friend.displayName)
                            .font(.headline)
                        if let category = friend.stressCategory {
                            Text("Currently \(category.rawValue) stress \(category.emoji)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // Share toggles
            Section("What you share with them") {
                Toggle(isOn: $latestStress) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Latest stress index")
                                .font(.body)
                            Text("They can see your current reading")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "eye")
                            .foregroundStyle(.deepTeal)
                    }
                }
                .onChange(of: latestStress) { _, _ in saveShare() }

                Toggle(isOn: $history) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Stress history")
                                .font(.body)
                            Text("They can see your reading history")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundStyle(.calmBlue)
                    }
                }
                .onChange(of: history) { _, _ in saveShare() }

                Toggle(isOn: $groupStats) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Group stats")
                                .font(.body)
                            Text("They can see your group averages")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "person.3")
                            .foregroundStyle(.softPurple)
                    }
                }
                .onChange(of: groupStats) { _, _ in saveShare() }
            }

            // Revoke all
            if isSharing {
                Section {
                    Button(role: .destructive) {
                        Task {
                            await viewModel.revokeShare(for: friend)
                            latestStress = false
                            history = false
                            groupStats = false
                            isSharing = false
                        }
                    } label: {
                        Label("Stop sharing with \(friend.displayName)", systemImage: "eye.slash")
                    }
                }
            }
        }
        .navigationTitle("Share Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let share = viewModel.share(with: friend), share.isActive {
                latestStress = share.permissions.latestStress
                history = share.permissions.history
                groupStats = share.permissions.groupStats
                isSharing = true
            }
        }
    }

    private func saveShare() {
        let anyEnabled = latestStress || history || groupStats
        isSharing = anyEnabled

        let permissions = Share.SharePermissions(
            latestStress: latestStress,
            history: history,
            groupStats: groupStats
        )

        Task {
            if anyEnabled {
                await viewModel.updateShare(for: friend, permissions: permissions)
            } else {
                await viewModel.revokeShare(for: friend)
            }
        }
    }
}

// MARK: - Search Sheet (unchanged)

struct SearchFriendsSheet: View {
    @ObservedObject var viewModel: FriendsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "F2F2F7").ignoresSafeArea()

                List {
                    if viewModel.searchResults.isEmpty && !viewModel.searchQuery.isEmpty && !viewModel.isSearching {
                        ContentUnavailableView.search(text: viewModel.searchQuery)
                    }

                    ForEach(viewModel.searchResults) { user in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [Color(hex: "1A6B5C"), Color(hex: "2D9F8F")],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 40, height: 40)
                                Text(String(user.displayName.prefix(1)).uppercased())
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                            }
                            Text(user.displayName).font(.body)
                            Spacer()
                            Button {
                                Task { await viewModel.addFriend(user) }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(Color(hex: "1A6B5C"))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.searchQuery, prompt: "Search by name")
            .onChange(of: viewModel.searchQuery) { _, _ in
                Task { await viewModel.searchUsers() }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color(hex: "1A6B5C"))
                }
            }
        }
    }
}
