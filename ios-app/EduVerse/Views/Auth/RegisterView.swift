import SwiftUI

struct RegisterView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var api = APIService.shared

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""

    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 10/255, green: 10/255, blue: 20/255)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header Logo
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "8B5CF6"), Color(hex: "6366F1")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 72, height: 72)
                                .shadow(color: Color(hex: "8B5CF6").opacity(0.35), radius: 12)

                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 10)

                        VStack(spacing: 4) {
                            Text("Create Student Account")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)

                            Text("Join the EduVerse live training network")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.6))
                        }

                        // Authorizer Notice Banner
                        HStack(spacing: 10) {
                            Image(systemName: "shield.lefthalf.filled")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "F59E0B"))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Authorization Required")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                Text("New student registrations are reviewed & authorized by our academic administrators before login access.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .padding(12)
                        .background(Color(hex: "F59E0B").opacity(0.12))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "F59E0B").opacity(0.3), lineWidth: 1)
                        )

                        // Form Card
                        VStack(spacing: 14) {
                            // First Name
                            HStack {
                                Image(systemName: "person")
                                    .foregroundColor(.white.opacity(0.5))
                                    .frame(width: 24)
                                TextField("First Name", text: $firstName)
                                    .autocapitalization(.words)
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))

                            // Last Name
                            HStack {
                                Image(systemName: "person")
                                    .foregroundColor(.white.opacity(0.5))
                                    .frame(width: 24)
                                TextField("Last Name", text: $lastName)
                                    .autocapitalization(.words)
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))

                            // Email
                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundColor(.white.opacity(0.5))
                                    .frame(width: 24)
                                TextField("Email Address", text: $email)
                                    .autocapitalization(.none)
                                    .keyboardType(.emailAddress)
                                    .disableAutocorrection(true)
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))

                            // Password
                            HStack {
                                Image(systemName: "lock")
                                    .foregroundColor(.white.opacity(0.5))
                                    .frame(width: 24)
                                SecureField("Password (min 6 chars)", text: $password)
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))

                            // Confirm Password
                            HStack {
                                Image(systemName: "lock.shield")
                                    .foregroundColor(.white.opacity(0.5))
                                    .frame(width: 24)
                                SecureField("Confirm Password", text: $confirmPassword)
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))

                            // Feedback Banners
                            if let err = errorMessage {
                                HStack {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundColor(Color(hex: "EF4444"))
                                    Text(err)
                                        .font(.system(size: 13))
                                        .foregroundColor(Color(hex: "F87171"))
                                    Spacer()
                                }
                                .padding(10)
                                .background(Color(hex: "EF4444").opacity(0.15))
                                .cornerRadius(8)
                            }

                            if let msg = successMessage {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Color(hex: "10B981"))
                                    Text(msg)
                                        .font(.system(size: 13))
                                        .foregroundColor(Color(hex: "10B981"))
                                    Spacer()
                                }
                                .padding(12)
                                .background(Color(hex: "10B981").opacity(0.15))
                                .cornerRadius(8)
                            }

                            // Submit Button
                            Button(action: handleRegister) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("Complete Registration")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "8B5CF6"), Color(hex: "6366F1")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                                .shadow(color: Color(hex: "8B5CF6").opacity(0.3), radius: 10, y: 4)
                            }
                            .disabled(isLoading || firstName.isEmpty || email.isEmpty || password.isEmpty)
                        }
                        .padding(20)

                        // Already have account button
                        Button(action: { dismiss() }) {
                            HStack(spacing: 4) {
                                Text("Already have an account?")
                                    .foregroundColor(.white.opacity(0.6))
                                Text("Sign In")
                                    .fontWeight(.bold)
                                    .foregroundColor(Color(hex: "8B5CF6"))
                            }
                            .font(.system(size: 14))
                        }
                        .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }

    private func handleRegister() {
        if password != confirmPassword {
            errorMessage = "Passwords do not match."
            return
        }
        if password.count < 6 {
            errorMessage = "Password must be at least 6 characters."
            return
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil

        Task {
            do {
                let msg = try await api.register(
                    firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                    lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    pass: password
                )
                successMessage = msg
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    dismiss()
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
