import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Logo / Header
                VStack(spacing: 8) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.purple)
                    Text("Cortisol Tracker")
                        .font(.largeTitle.weight(.bold))
                    Text("Track your stress, improve your life")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Email/Password
                VStack(spacing: 12) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Sign In Button
                Button {
                    Task { await authViewModel.signIn(email: email, password: password) }
                } label: {
                    if authViewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Sign In")
                    }
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(email.isEmpty || password.isEmpty || authViewModel.isLoading)

                // Divider
                HStack {
                    Rectangle().frame(height: 1).foregroundStyle(.secondary.opacity(0.3))
                    Text("or")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Rectangle().frame(height: 1).foregroundStyle(.secondary.opacity(0.3))
                }

                // Apple Sign In
                SignInWithAppleButton(.signIn) { request in
                    let hashedNonce = authViewModel.prepareAppleSignIn()
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = hashedNonce
                } onCompletion: { result in
                    Task { await authViewModel.handleAppleSignIn(result: result) }
                }
                .signInWithAppleButtonStyle(.whiteOutline)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Sign Up Link
                Button {
                    showSignUp = true
                } label: {
                    Text("Don't have an account? **Sign Up**")
                        .font(.subheadline)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .alert("Error", isPresented: .constant(authViewModel.error != nil)) {
                Button("OK") { authViewModel.error = nil }
            } message: {
                Text(authViewModel.error ?? "")
            }
            .sheet(isPresented: $showSignUp) {
                SignUpView(authViewModel: authViewModel)
            }
        }
    }
}
