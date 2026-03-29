import Foundation

@Observable
class FriendsViewModel {
    var friends: [Friend] = []
    var searchResults: [Friend] = []
    var searchQuery = ""
    var shares: [String: Share] = [:]  // keyed by viewerID (friend's ID)
    var isLoading = false
    var isSearching = false
    var error: String?

    private let firebase = FirebaseService.shared

    func loadFriends() async {
        guard let userID = firebase.currentUserID else { return }
        isLoading = true
        error = nil

        do {
            let user = try await firebase.fetchUser(id: userID)
            var loadedFriends = try await firebase.fetchFriends(friendIDs: user.friendIDs)

            // Fetch latest reading and share status for each friend concurrently
            let loadedShares = try await firebase.fetchMyShares()
            shares = Dictionary(uniqueKeysWithValues: loadedShares.map { ($0.viewerID, $0) })

            await withTaskGroup(of: (String, CortisolReading?).self) { group in
                for friend in loadedFriends {
                    group.addTask {
                        let readings = try? await self.firebase.fetchFriendReadings(friendID: friend.id, limit: 1)
                        return (friend.id, readings?.first)
                    }
                }
                for await (friendID, reading) in group {
                    if let idx = loadedFriends.firstIndex(where: { $0.id == friendID }),
                       let reading = reading {
                        loadedFriends[idx].latestStressLevel = reading.stressLevel
                        loadedFriends[idx].latestReadingTime = reading.timestamp
                    }
                }
            }

            friends = loadedFriends
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func searchUsers() async {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        isSearching = true

        do {
            searchResults = try await firebase.searchUsers(query: searchQuery)
            let friendIDs = Set(friends.map(\.id))
            searchResults = searchResults.filter { !friendIDs.contains($0.id) && $0.id != firebase.currentUserID }
        } catch {
            self.error = error.localizedDescription
        }

        isSearching = false
    }

    func addFriend(_ friend: Friend) async {
        guard let userID = firebase.currentUserID else { return }

        do {
            try await firebase.addFriend(userID: userID, friendID: friend.id)
            friends.append(friend)
            searchResults.removeAll { $0.id == friend.id }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func share(with friend: Friend) -> Share? {
        shares[friend.id]
    }

    func updateShare(for friend: Friend, permissions: Share.SharePermissions) async {
        do {
            try await firebase.setShare(viewerID: friend.id, permissions: permissions)
            let newShare = Share(
                ownerID: firebase.currentUserID ?? "",
                viewerID: friend.id,
                permissions: permissions
            )
            shares[friend.id] = newShare
        } catch {
            self.error = error.localizedDescription
        }
    }

    func revokeShare(for friend: Friend) async {
        do {
            try await firebase.revokeShare(viewerID: friend.id)
            shares[friend.id] = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
