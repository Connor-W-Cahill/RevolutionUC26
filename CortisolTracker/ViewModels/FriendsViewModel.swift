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

    // Demo friends shown when Firebase has no data or is offline
    private let demoFriends: [Friend] = [
        Friend(
            id: "demo_alex",
            displayName: "Alex Rivera",
            latestStressLevel: 42.0,
            latestReadingTime: Calendar.current.date(byAdding: .hour, value: -1, to: Date())
        ),
        Friend(
            id: "demo_jordan",
            displayName: "Jordan Lee",
            latestStressLevel: 71.0,
            latestReadingTime: Calendar.current.date(byAdding: .hour, value: -3, to: Date())
        ),
        Friend(
            id: "demo_sam",
            displayName: "Sam Chen",
            latestStressLevel: 18.0,
            latestReadingTime: Calendar.current.date(byAdding: .minute, value: -30, to: Date())
        ),
        Friend(
            id: "demo_morgan",
            displayName: "Morgan Park",
            latestStressLevel: 55.0,
            latestReadingTime: Calendar.current.date(byAdding: .hour, value: -5, to: Date())
        ),
    ]

    func loadFriends() async {
        guard let userID = firebase.currentUserID else {
            friends = demoFriends
            return
        }
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

            // Always include demo friends (filter out any whose name matches a real friend)
            let realNames = Set(loadedFriends.map(\.displayName))
            let extraDemos = demoFriends.filter { !realNames.contains($0.displayName) }
            friends = loadedFriends + extraDemos
        } catch {
            let nsError = error as NSError
            // Offline or error — fall back to demo friends
            friends = demoFriends
            if !(nsError.domain == "FIRFirestoreErrorDomain" && nsError.code == 14) {
                self.error = error.localizedDescription
            }
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
