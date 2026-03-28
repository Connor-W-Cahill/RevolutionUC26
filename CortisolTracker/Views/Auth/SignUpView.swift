import SwiftUI

struct SignUpView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    private var passwordsMatch: Bool { !password.isEmpty && password == confirmPassword }
    private var isValid: Bool { !displayName.isEmpty && !email.isEmpty && passwordsMatch && password.count >= 6 }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "F2F2F7").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 8) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 48))
                                .foregroundStyle(Color(hex: "1A6B5C"))
                            Text("Create Account")
                                .font(.title2.weight(.bold))
                        }
                        .padding(.top, 20)

                        VStack(spacing: 12) {
                            TextField("Display Name", text: $displayName)
                                .textContentType(.name)
                                .padding()
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)

                            TextField("Email", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .padding()
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)

                            SecureField("Password (min 6 characters)", text: $password)
                                .textContentType(.newPassword)
                                .padding()
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)

                            SecureField("Confirm Password", text: $confirmPassword)
                                .textContentType(.newPassword)
                                .padding()
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)

                            if !confirmPassword.isEmpty && !passwordsMatch {
                                Text("Passwords don't match")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }

                        Button {
                            Task {
                                await authViewModel.signUp(email: email, password: password, displayName: displayName)
                                if authViewModel.isAuthenticated { dismiss() }
                            }
                        } label: {
                            if authViewModel.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Create Account").font(.headline)
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isValid ? Color(hex: "1A6B5C") : Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .disabled(!isValid || authViewModel.isLoading)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color(hex: "1A6B5C"))
                }
            }
            .alert("Error", isPresented: .constant(authViewModel.error != nil)) {
                Button("OK") { authViewModel.error = nil }
            } message: {
                Text(authViewModel.error ?? "")
            }
        }
    }
}
