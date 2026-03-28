import Foundation

@MainActor
class FriendsViewModel: ObservableObject {
    @Published var friends: [Friend] = []
    @Published var searchResults: [Friend] = []
    @Published var searchQuery = ""
    @Published var isLoading = false
    @Published var isSearching = false
    @Published var error: String?

    private let firebase = FirebaseService.shared

    func loadFriends() async {
        guard let userID = firebase.currentUserID else { return }
        isLoading = true
        error = nil

        do {
            let user = try await firebase.fetchUser(id: userID)
            friends = try await firebase.fetchFriends(friendIDs: user.friendIDs)
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
            // Filter out existing friends
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
}
