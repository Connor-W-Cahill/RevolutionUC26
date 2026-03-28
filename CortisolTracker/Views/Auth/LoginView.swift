import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "1A6B5C"), Color(hex: "2D9F8F"), Color(hex: "A8E6CF").opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 8) {
                        Image(systemName: "waveform.path.ecg.rectangle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.white)
                        Text("Cortisol Tracker")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(.white)
                        Text("Track your stress, improve your life")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Spacer()

                    VStack(spacing: 16) {
                        VStack(spacing: 12) {
                            TextField("Email", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .padding()
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            SecureField("Password", text: $password)
                                .textContentType(.password)
                                .padding()
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Button {
                            Task { await authViewModel.signIn(email: email, password: password) }
                        } label: {
                            if authViewModel.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Sign In").font(.headline)
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "1A6B5C"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .disabled(email.isEmpty || password.isEmpty || authViewModel.isLoading)

                        HStack {
                            Rectangle().frame(height: 1).foregroundStyle(.white.opacity(0.4))
                            Text("or").font(.caption).foregroundStyle(.white.opacity(0.8))
                            Rectangle().frame(height: 1).foregroundStyle(.white.opacity(0.4))
                        }

                        SignInWithAppleButton(.signIn) { request in
                            let hashedNonce = authViewModel.prepareAppleSignIn()
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = hashedNonce
                        } onCompletion: { result in
                            Task { await authViewModel.handleAppleSignIn(result: result) }
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        Button {
                            showSignUp = true
                        } label: {
                            Text("Don't have an account? **Sign Up**")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(24)
                    .background(Color.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
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
