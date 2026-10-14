import SwiftUI

@main
struct EduVerseApp: App {
    @StateObject private var api = APIService.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if api.isAuthenticated {
                    CourseListView()
                } else {
                    LoginView()
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}
