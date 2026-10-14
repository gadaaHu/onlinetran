import Foundation

@MainActor
class APIService: ObservableObject {
    static let shared = APIService()

    // For iOS Simulator, localhost refers to the host machine.
    // For physical iPhone, change to your Mac or Windows local IP (e.g., http://192.168.1.x:5083/api)
    @Published var baseURL: String = "http://localhost:5083/api"
    @Published var currentUser: UserSession?
    @Published var isAuthenticated: Bool = false

    func login(email: String, pass: String) async throws -> UserSession {
        guard let url = URL(string: "\(baseURL)/auth/login") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let finalEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "admin"
            ? "admin@eduverse.com"
            : email.trimmingCharacters(in: .whitespacesAndNewlines)

        let body: [String: Any] = [
            "email": finalEmail,
            "password": pass
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if (200...299).contains(httpResponse.statusCode) {
            let session = try JSONDecoder().decode(UserSession.self, from: data)
            self.currentUser = session
            self.isAuthenticated = true
            return session
        } else {
            let errDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let msg = errDict?["message"] as? String ?? "Invalid email or password (\(httpResponse.statusCode))"
            throw NSError(domain: "EduVerseAuth", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }

    func fetchCourses() async -> [Course] {
        guard let url = URL(string: "\(baseURL)/courses") else {
            return sampleCourses
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let token = currentUser?.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                var list = try JSONDecoder().decode([Course].self, from: data)
                // Ensure lessons have live classroom data
                for i in 0..<list.count {
                    if list[i].lessons == nil || list[i].lessons?.isEmpty == true {
                        list[i].lessons = [
                            Lesson(id: 1, title: "Live Classroom Session", isLive: true, meetingUrl: "eduverse-class-\(list[i].id)")
                        ]
                    }
                }
                return list
            }
        } catch {
            print("Failed to fetch live courses, falling back to sample courses: \(error)")
        }

        return sampleCourses
    }

    func logout() {
        self.currentUser = nil
        self.isAuthenticated = false
    }

    private var sampleCourses: [Course] {
        [
            Course(
                id: 1,
                title: "Full-Stack Cloud & Web Engineering",
                description: "Master ASP.NET Core, Flutter, and scalable container architectures.",
                instructorName: "Alex Turner",
                lessons: [Lesson(id: 1, title: "Live System Architecture Workshop", isLive: true, meetingUrl: "eduverse-cloud-101")]
            ),
            Course(
                id: 2,
                title: "Modern AI & Computer Vision",
                description: "Deep learning, YOLOv8, and real-time edge streaming.",
                instructorName: "Sarah Chen",
                lessons: [Lesson(id: 2, title: "Live Neural Network Lab", isLive: true, meetingUrl: "eduverse-ai-102")]
            ),
            Course(
                id: 3,
                title: "iOS Native Development with Swift & SwiftUI",
                description: "Modern Swift concurrency, WebRTC live classes, and Apple HIG design.",
                instructorName: "Michael Scott",
                lessons: [Lesson(id: 3, title: "Live SwiftUI Masterclass", isLive: true, meetingUrl: "eduverse-swift-103")]
            )
        ]
    }
}
