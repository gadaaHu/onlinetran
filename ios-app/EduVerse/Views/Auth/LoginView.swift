import SwiftUI

struct LoginView: View {
    @ObservedObject var api = APIService.shared
    @State private var email: String = "admin@eduverse.com"
    @State private var password: String = "Admin@123!"
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack {
            Color(red: 10/255, green: 10/255, blue: 20/255)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Logo
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 139/255, green: 92/255, blue: 246/255), Color(red: 99/255, green: 102/255, blue: 241/255)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .shadow(color: Color(red: 139/255, green: 92/255, blue: 246/255).opacity(0.4), radius: 15)

                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 38))
                        .foregroundColor(.white)
                }

                VStack(spacing: 6) {
                    Text("EduVerse for iOS")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)

                    Text("Modern Online Training & Live Class")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer().frame(height: 10)

                // Input Card
                VStack(spacing: 16) {
                    // Email Field
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 24)
                        TextField("Email or admin", text: $email)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )

                    // Password Field
                    HStack {
                        Image(systemName: "lock")
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 24)
                        SecureField("Password", text: $password)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )

                    // Quick Autofill Admin
                    HStack {
                        Spacer()
                        Button(action: {
                            email = "admin@eduverse.com"
                            password = "Admin@123!"
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 11))
                                Text("Autofill Admin Login")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(Color(red: 139/255, green: 92/255, blue: 246/255))
                        }
                    }

                    if let err = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(Color(red: 239/255, green: 68/255, blue: 68/255))
                            Text(err)
                                .font(.system(size: 13))
                                .foregroundColor(Color(red: 248/255, green: 113/255, blue: 113/255))
                            Spacer()
                        }
                        .padding(10)
                        .background(Color(red: 239/255, green: 68/255, blue: 68/255).opacity(0.15))
                        .cornerRadius(8)
                    }

                    // Sign In Button
                    Button(action: {
                        Task {
                            isLoading = true
                            errorMessage = nil
                            do {
                                _ = try await api.login(email: email, pass: password)
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                            isLoading = false
                        }
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Sign In")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 139/255, green: 92/255, blue: 246/255), Color(red: 99/255, green: 102/255, blue: 241/255)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: Color(red: 139/255, green: 92/255, blue: 246/255).opacity(0.3), radius: 10, y: 4)
                    }
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                }
                .padding(20)

                Spacer()
            }
            .padding(.horizontal, 16)
        }
    }
}
