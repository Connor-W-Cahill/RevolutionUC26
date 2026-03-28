import SwiftUI

struct FriendsView: View {
    @StateObject private var viewModel = FriendsViewModel()
    @State private var showSearch = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "F2F2F7").ignoresSafeArea()

                Group {
                    if viewModel.isLoading {
                        ProgressView()
                    } else if viewModel.friends.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "person.2.slash")
                                .font(.system(size: 56))
                                .foregroundStyle(Color(hex: "2D9F8F").opacity(0.4))
                            Text("No Friends Yet")
                                .font(.title3.weight(.semibold))
                            Text("Add friends to see their stress levels")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button {
                                showSearch = true
                            } label: {
                                Label("Add a Friend", systemImage: "person.badge.plus")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color(hex: "1A6B5C"))
                                    .clipShape(Capsule())
                            }
                            .padding(.top, 4)
                        }
                        .padding()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.friends) { friend in
                                    FriendRow(friend: friend)
                                }
                            }
                            .padding()
                        }
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

struct FriendRow: View {
    let friend: Friend

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [Color(hex: "1A6B5C"), Color(hex: "2D9F8F")],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 48, height: 48)
                Text(String(friend.displayName.prefix(1)).uppercased())
                    .font(.headline)
                    .foregroundStyle(.white)
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
