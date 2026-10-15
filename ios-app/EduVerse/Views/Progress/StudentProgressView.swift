import SwiftUI

// MARK: - Models
struct DashboardStats: Decodable {
    let enrolledCourses: Int
    let completedCourses: Int
    let totalWatchHours: Double
    let quizzesTaken: Int
    let quizzesPassed: Int
    let unreadNotifications: Int
}

struct EnrollmentProgress: Identifiable, Decodable {
    var id: Int { courseId }
    let courseId: Int
    let courseTitle: String
    let instructorName: String
    let progressPercentage: Double
    let isCompleted: Bool
}

struct RecentLesson: Identifiable, Decodable {
    let lessonId: Int
    var id: Int { lessonId }
    let lessonTitle: String
    let courseTitle: String
    let isCompleted: Bool
    let watchedSeconds: Int
}

struct QuizResultItem: Identifiable, Decodable {
    let quizId: Int
    var id: Int { quizId }
    let quizTitle: String
    let score: Int
    let isPassed: Bool
}

struct DashboardResponse: Decodable {
    let stats: DashboardStats
    let enrollments: [EnrollmentProgress]
    let recentActivity: [RecentLesson]
    let recentQuizResults: [QuizResultItem]
}

// MARK: - View
struct StudentProgressView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var dashboard: DashboardResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var baseURL: String { APIService.shared.rootURL }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0F0F1A").ignoresSafeArea()

                Group {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "6366F1")))
                            .scaleEffect(1.5)
                    } else if let err = errorMessage {
                        errorView(err)
                    } else if let dash = dashboard {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 20) {
                                StatsGridView(stats: dash.stats)

                                sectionHeader("📚 Enrolled Courses")
                                if dash.enrollments.isEmpty {
                                    emptyCard("No enrolled courses yet")
                                } else {
                                    ForEach(dash.enrollments) { e in
                                        CourseProgressCard(enrollment: e)
                                    }
                                }

                                sectionHeader("🕒 Recent Activity")
                                if dash.recentActivity.isEmpty {
                                    emptyCard("No recent activity")
                                } else {
                                    ForEach(dash.recentActivity) { a in
                                        ActivityRow(lesson: a)
                                    }
                                }

                                sectionHeader("📊 Quiz Results")
                                if dash.recentQuizResults.isEmpty {
                                    emptyCard("No quizzes taken yet")
                                } else {
                                    ForEach(dash.recentQuizResults) { q in
                                        QuizResultRow(result: q)
                                    }
                                }

                                Spacer(minLength: 24)
                            }
                            .padding(16)
                        }
                    }
                }
            }
            .navigationTitle("My Learning")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color(hex: "0F0F1A"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left").foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { loadDashboard() }) {
                        Image(systemName: "arrow.clockwise").foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .onAppear { loadDashboard() }
        }
    }

    @ViewBuilder
    func errorView(_ msg: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44)).foregroundColor(.red)
            Text(msg).foregroundColor(.white.opacity(0.7))
            Button("Retry") { loadDashboard() }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "6366F1"))
        }
    }

    func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline.weight(.bold))
            .foregroundColor(.white)
    }

    func emptyCard(_ msg: String) -> some View {
        Text(msg)
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.38))
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: "1A1A2E")))
    }

    // MARK: - API
    func loadDashboard() {
        isLoading = true
        errorMessage = nil
        guard let token = UserDefaults.standard.string(forKey: "auth_token"),
              let url = URL(string: "\(baseURL)/api/progress/dashboard")
        else { isLoading = false; return }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 10

        URLSession.shared.dataTask(with: req) { data, _, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error { errorMessage = error.localizedDescription; return }
                guard let data = data else { return }
                do {
                    dashboard = try JSONDecoder().decode(DashboardResponse.self, from: data)
                } catch {
                    errorMessage = "Parse error: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
}

// MARK: - Stats Grid
struct StatsGridView: View {
    let stats: DashboardStats

    var items: [(String, String, String, String)] {
        [
            ("Enrolled", "\(stats.enrolledCourses)", "book.fill", "6366F1"),
            ("Completed", "\(stats.completedCourses)", "checkmark.seal.fill", "10B981"),
            ("Watch Hrs", "\(stats.totalWatchHours)h", "play.circle.fill", "F59E0B"),
            ("Quizzes", "\(stats.quizzesPassed)/\(stats.quizzesTaken)", "doc.questionmark.fill", "EC4899"),
        ]
    }

    let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(items, id: \.0) { label, value, icon, colorHex in
                let color = Color(hex: colorHex)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.22), color.opacity(0.05)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.3)))
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: icon)
                            .font(.system(size: 24))
                            .foregroundColor(color)
                        Text(value)
                            .font(.title.bold())
                            .foregroundColor(color)
                        Text(label)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(16)
                }
                .frame(height: 120)
            }
        }
    }
}

// MARK: - Course Progress Card
struct CourseProgressCard: View {
    let enrollment: EnrollmentProgress

    var progressColor: Color {
        enrollment.isCompleted ? Color(hex: "10B981") : Color(hex: "6366F1")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(enrollment.courseTitle)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                Spacer()
                if enrollment.isCompleted {
                    Text("✓ Done")
                        .font(.caption.weight(.bold))
                        .foregroundColor(Color(hex: "10B981"))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color(hex: "10B981").opacity(0.2))
                        .cornerRadius(8)
                }
            }
            Text(enrollment.instructorName)
                .font(.caption).foregroundColor(.white.opacity(0.38))

            HStack(spacing: 10) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.08))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(progressColor)
                            .frame(width: geo.size.width * (enrollment.progressPercentage / 100))
                    }
                }
                .frame(height: 6)
                Text("\(Int(enrollment.progressPercentage))%")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "1A1A2E"))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06))))
    }
}

// MARK: - Activity Row
struct ActivityRow: View {
    let lesson: RecentLesson

    var iconColor: Color { lesson.isCompleted ? Color(hex: "10B981") : Color(hex: "6366F1") }
    var mins: Int { lesson.watchedSeconds / 60 }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(iconColor.opacity(0.15)).frame(width: 38, height: 38)
                Image(systemName: lesson.isCompleted ? "checkmark" : "play.circle")
                    .foregroundColor(iconColor).font(.system(size: 18))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(lesson.lessonTitle).font(.subheadline.weight(.medium))
                    .foregroundColor(.white).lineLimit(1)
                Text(lesson.courseTitle).font(.caption).foregroundColor(.white.opacity(0.38))
            }
            Spacer()
            Text(mins > 0 ? "\(mins)m" : "New")
                .font(.caption).foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: "1A1A2E"))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06))))
    }
}

// MARK: - Quiz Result Row
struct QuizResultRow: View {
    let result: QuizResultItem

    var passed: Bool { result.isPassed }
    var resultColor: Color { passed ? Color(hex: "10B981") : Color(hex: "EF4444") }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: passed ? "trophy.fill" : "xmark.circle.fill")
                .foregroundColor(resultColor).font(.system(size: 20))
            Text(result.quizTitle).font(.subheadline).foregroundColor(.white)
            Spacer()
            Text("\(result.score)%")
                .font(.subheadline.weight(.bold))
                .foregroundColor(resultColor)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(resultColor.opacity(0.15)).cornerRadius(8)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: "1A1A2E"))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(resultColor.opacity(0.3))))
    }
}
