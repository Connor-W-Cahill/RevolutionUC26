import SwiftUI

struct FriendsView: View {
    @State private var viewModel = FriendsViewModel()
    @State private var showSearch = false

    var body: some View {
        NavigationStack {
            List {
                if viewModel.friends.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        "No Friends Yet",
                        systemImage: "person.2.slash",
                        description: Text("Add friends to see their stress levels")
                    )
                }

                ForEach(viewModel.friends) { friend in
                    FriendRow(friend: friend)
                }
            }
            .navigationTitle("Friends")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSearch = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showSearch) {
                SearchFriendsSheet(viewModel: viewModel)
            }
            .task { await viewModel.loadFriends() }
            .refreshable { await viewModel.loadFriends() }
            .overlay {
                if viewModel.isLoading { ProgressView() }
            }
        }
    }
}

struct FriendRow: View {
    let friend: Friend

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(AppTheme.mint)
                .frame(width: 44, height: 44)
                .overlay {
                    Text(String(friend.displayName.prefix(1)).uppercased())
                        .font(.headline)
                        .foregroundStyle(AppTheme.deepTeal)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName)
                    .font(.body.weight(.medium))

                if let time = friend.latestReadingTime {
                    Text(time, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No readings yet")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if let category = friend.stressCategory {
                VStack(alignment: .trailing) {
                    Text(category.emoji)
                        .font(.title3)
                    Text(category.rawValue)
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

struct SearchFriendsSheet: View {
    @Bindable var viewModel: FriendsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if viewModel.searchResults.isEmpty && !viewModel.searchQuery.isEmpty && !viewModel.isSearching {
                    ContentUnavailableView.search(text: viewModel.searchQuery)
                }

                ForEach(viewModel.searchResults) { user in
                    HStack {
                        Circle()
                            .fill(AppTheme.mint)
                            .frame(width: 36, height: 36)
                            .overlay {
                                Text(String(user.displayName.prefix(1)).uppercased())
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.deepTeal)
                            }

                        Text(user.displayName)
                            .font(.body)

                        Spacer()

                        Button {
                            Task { await viewModel.addFriend(user) }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(AppTheme.deepTeal)
                        }
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
                }
            }
        }
    }
}
