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
    var isCompleted: Bool? = false
}

struct Lesson: Identifiable, Codable {
    let id: Int
    let title: String
    let isLive: Bool
    let meetingUrl: String?
}

struct StudentSummary: Identifiable, Codable {
    let id: String
    let email: String
    let firstName: String?
    let lastName: String?
    let fullName: String?
    let isConfirmed: Bool
    let roles: [String]?
    let createdAt: String?
}

struct CertificateInfo: Identifiable, Codable {
    var id: String { "\(courseId)-\(studentName)" }
    let courseId: Int
    let courseTitle: String
    let studentName: String
    let instructorName: String
    let issueDate: Date
    let certificateNumber: String
}
