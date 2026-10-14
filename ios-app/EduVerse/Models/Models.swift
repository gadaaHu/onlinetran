import Foundation

struct UserSession: Codable {
    let token: String
    let email: String
    let fullName: String
    let roles: [String]
    let profilePictureUrl: String?
}

struct Course: Identifiable, Codable {
    let id: Int
    let title: String
    let description: String
    let instructorName: String
    var lessons: [Lesson]?
}

struct Lesson: Identifiable, Codable {
    let id: Int
    let title: String
    let isLive: Bool
    let meetingUrl: String?
}
