import Foundation
import FirebaseAuth
import AuthenticationServices
import CryptoKit

@Observable
class AuthViewModel {
    var user: AppUser?
    var isAuthenticated = false
    var isLoading = false
    var error: String?

    private let firebase = FirebaseService.shared
    private var currentNonce: String?

    init() {
        // Check if already signed in
        if let uid = Auth.auth().currentUser?.uid {
            isAuthenticated = true
            Task { await loadUser(id: uid) }
        }
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        error = nil

        do {
            user = try await firebase.signIn(email: email, password: password)
            isAuthenticated = true
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func signUp(email: String, password: String, displayName: String) async {
        isLoading = true
        error = nil

        do {
            user = try await firebase.signUp(email: email, password: password, displayName: displayName)
            isAuthenticated = true
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func signOut() {
        do {
            try firebase.signOut()
            user = nil
            isAuthenticated = false
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func loadUser(id: String) async {
        do {
            user = try await firebase.fetchUser(id: id)
        } catch {
            // User doc doesn't exist yet — will be created on next sign-up flow
        }
    }

    // MARK: - Apple Sign In

    func prepareAppleSignIn() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        isLoading = true
        error = nil

        switch result {
        case .success(let authorization):
            guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = appleCredential.identityToken,
                  let tokenString = String(data: identityToken, encoding: .utf8),
                  let nonce = currentNonce else {
                error = "Failed to get Apple ID credential"
                isLoading = false
                return
            }

            let credential = OAuthProvider.appleCredential(
                withIDToken: tokenString,
                rawNonce: nonce,
                fullName: appleCredential.fullName
            )

            do {
                let authResult = try await Auth.auth().signIn(with: credential)
                let uid = authResult.user.uid

                // Check if user doc exists
                if let existing = try? await firebase.fetchUser(id: uid) {
                    user = existing
                } else {
                    let displayName = [appleCredential.fullName?.givenName, appleCredential.fullName?.familyName]
                        .compactMap { $0 }
                        .joined(separator: " ")
                    let newUser = AppUser(
                        id: uid,
                        displayName: displayName.isEmpty ? "User" : displayName,
                        email: appleCredential.email ?? authResult.user.email ?? ""
                    )
                    try await firebase.saveUser(newUser)
                    user = newUser
                }
                isAuthenticated = true
            } catch {
                self.error = error.localizedDescription
            }

        case .failure(let error):
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Helpers

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        guard errorCode == errSecSuccess else { return "" }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
