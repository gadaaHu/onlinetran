import SwiftUI

struct CertificateView: View {
    @Environment(\.dismiss) private var dismiss
    let courseTitle: String
    let studentName: String
    let instructorName: String
    let courseId: Int

    @State private var isDownloading: Bool = false
    @State private var pdfURL: URL? = nil
    @State private var showShareSheet: Bool = false

    private var issueDateText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: Date())
    }

    private var certificateID: String {
        let hash = abs("\(courseId)-\(studentName)-\(courseTitle)".hashValue)
        return "EDV-\(String(format: "%06d", hash % 1000000))"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0A0A14").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Badge at top
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "10B981"))
                            Text("Verified Course Completion")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color(hex: "10B981"))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color(hex: "10B981").opacity(0.15))
                        .cornerRadius(20)
                        .padding(.top, 8)

                        // ── Certificate Parchment Container ──
                        VStack(spacing: 20) {
                            // Top Ornament
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(Color(hex: "F59E0B"))
                                Spacer()
                                Image(systemName: "graduationcap.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(Color(hex: "8B5CF6"))
                                Spacer()
                                Image(systemName: "sparkles")
                                    .foregroundColor(Color(hex: "F59E0B"))
                            }

                            VStack(spacing: 4) {
                                Text("EDUVERSE ACADEMY")
                                    .font(.system(size: 12, weight: .bold))
                                    .tracking(4)
                                    .foregroundColor(Color(hex: "8B5CF6"))

                                Text("Certificate of Completion")
                                    .font(.system(size: 22, weight: .black))
                                    .foregroundColor(.white)
                            }

                            Text("This is proudly presented to")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))

                            // Student Name
                            VStack(spacing: 6) {
                                Text(studentName)
                                    .font(.system(size: 26, weight: .bold, design: .serif))
                                    .foregroundColor(Color(hex: "F59E0B"))
                                    .multilineTextAlignment(.center)

                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.clear, Color(hex: "F59E0B"), .clear],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(height: 1.5)
                                    .padding(.horizontal, 30)
                            }

                            Text("for successfully completing the curriculum and mastering the live technical requirements of")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.65))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)

                            // Course Title
                            Text(courseTitle)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 10)

                            // Signature & Date Section
                            HStack(alignment: .bottom) {
                                VStack(spacing: 4) {
                                    Text(instructorName)
                                        .font(.system(size: 13, weight: .bold, design: .serif))
                                        .foregroundColor(.white)
                                    Rectangle().fill(Color.white.opacity(0.3)).frame(height: 1)
                                    Text("Lead Instructor")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.4))
                                }

                                Spacer(minLength: 24)

                                // Gold Seal
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(hex: "F59E0B"), Color(hex: "D97706")],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 52, height: 52)
                                        .shadow(color: Color(hex: "F59E0B").opacity(0.4), radius: 8)

                                    Image(systemName: "seal.fill")
                                        .font(.system(size: 26))
                                        .foregroundColor(Color(hex: "78350F"))
                                }

                                Spacer(minLength: 24)

                                VStack(spacing: 4) {
                                    Text(issueDateText)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                    Rectangle().fill(Color.white.opacity(0.3)).frame(height: 1)
                                    Text("Date Issued")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                            }
                            .padding(.top, 10)

                            // Certificate ID
                            HStack {
                                Text("Credential ID: \(certificateID)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.4))
                                Spacer()
                                Text("Verified via EduVerse LMS")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(hex: "151528"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(
                                            LinearGradient(
                                                colors: [Color(hex: "8B5CF6").opacity(0.6), Color(hex: "F59E0B").opacity(0.4)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.5
                                        )
                                )
                        )
                        .shadow(color: Color(hex: "8B5CF6").opacity(0.15), radius: 20)
                        .padding(.horizontal, 16)

                        // ── Actions ──
                        VStack(spacing: 12) {
                            Button(action: downloadPDF) {
                                HStack(spacing: 8) {
                                    if isDownloading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: "arrow.down.doc.fill")
                                        Text("Download Official PDF Certificate")
                                    }
                                }
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color(hex: "8B5CF6"))
                                .cornerRadius(12)
                            }
                            .disabled(isDownloading)

                            ShareLink(
                                item: "🎓 Check out my certificate for '\(courseTitle)' earned at EduVerse Academy! Credential ID: \(certificateID)",
                                subject: Text("My EduVerse Certificate: \(courseTitle)"),
                                message: Text("I completed '\(courseTitle)' at EduVerse Academy!")
                            ) {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Share Certificate Achievement")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "8B5CF6"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color(hex: "8B5CF6").opacity(0.12))
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Certificate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "0A0A14"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "8B5CF6"))
                    .fontWeight(.bold)
                }
            }
        }
    }

    private func downloadPDF() {
        isDownloading = true
        let urlStr = "\(APIService.shared.baseURL)/quizzes/\(courseId)/certificate"
        guard let url = URL(string: urlStr) else {
            isDownloading = false
            return
        }

        var request = URLRequest(url: url)
        if let token = APIService.shared.currentUser?.token ?? UserDefaults.standard.string(forKey: "auth_token") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        URLSession.shared.downloadTask(with: request) { tempURL, response, error in
            DispatchQueue.main.async {
                isDownloading = false
                guard let tempURL = tempURL, error == nil else {
                    return
                }
                do {
                    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let dest = docs.appendingPathComponent("EduVerse_Certificate_\(courseId).pdf")
                    if FileManager.default.fileExists(atPath: dest.path) {
                        try FileManager.default.removeItem(at: dest)
                    }
                    try FileManager.default.copyItem(at: tempURL, to: dest)
                    self.pdfURL = dest
                    self.showShareSheet = true
                } catch {
                    print("Error saving certificate: \(error)")
                }
            }
        }.resume()
    }
}
