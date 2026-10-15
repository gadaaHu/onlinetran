import SwiftUI

struct CourseListView: View {
    @ObservedObject var api = APIService.shared
    @State private var courses: [Course] = []
    @State private var isLoading: Bool = true
    @State private var selectedLiveLesson: (roomName: String, title: String)? = nil
    @State private var showNotifications: Bool = false
    @State private var showProgress: Bool = false
    @State private var showAuthorizer: Bool = false
    @State private var selectedCertificateCourse: Course? = nil

    private var isStaffOrAdmin: Bool {
        api.currentUser?.roles.contains(where: {
            let role = $0.lowercased()
            return role == "admin" || role == "instructor" || role == "authorizer"
        }) ?? false
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 10/255, green: 10/255, blue: 20/255)
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 139/255, green: 92/255, blue: 246/255)))
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // User Welcome Header
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Welcome back,")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.6))
                                    Text(api.currentUser?.fullName ?? "EduVerse Learner")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                Spacer()
                                // Quick action buttons
                                HStack(spacing: 8) {
                                    Button(action: { showProgress = true }) {
                                        Image(systemName: "chart.bar.xaxis")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(Color(hex: "6366F1"))
                                            .padding(10)
                                            .background(Color(hex: "6366F1").opacity(0.15))
                                            .clipShape(Circle())
                                    }

                                    Button(action: { showNotifications = true }) {
                                        Image(systemName: "bell.fill")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(Color(hex: "F59E0B"))
                                            .padding(10)
                                            .background(Color(hex: "F59E0B").opacity(0.15))
                                            .clipShape(Circle())
                                    }

                                    if isStaffOrAdmin {
                                        Button(action: { showAuthorizer = true }) {
                                            Image(systemName: "shield.checkered")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(Color(hex: "10B981"))
                                                .padding(10)
                                                .background(Color(hex: "10B981").opacity(0.15))
                                                .clipShape(Circle())
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                            .padding(.top, 4)

                            // Banner Card
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("EduVerse Live Academy")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("Tap below to join live interactive lectures.")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                Spacer()
                                Image(systemName: "video.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(Color(red: 139/255, green: 92/255, blue: 246/255))
                            }
                            .padding()
                            .background(Color(red: 19/255, green: 19/255, blue: 38/255))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color(red: 139/255, green: 92/255, blue: 246/255).opacity(0.3), lineWidth: 1)
                            )

                            // Course Cards
                            ForEach(courses) { course in
                                CourseCardView(
                                    course: course,
                                    onJoinLive: { lesson in
                                        let room = lesson.meetingUrl ?? "eduverse-class-\(course.id)"
                                        selectedLiveLesson = (roomName: room, title: lesson.title)
                                    },
                                    onViewCertificate: {
                                        selectedCertificateCourse = course
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Courses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isStaffOrAdmin {
                        Button(action: { showAuthorizer = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "shield.fill")
                                Text("Authorizer")
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "10B981"))
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        api.logout()
                    }) {
                        Text("Logout")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(red: 248/255, green: 113/255, blue: 113/255))
                    }
                }
            }
            // Classroom Sheet
            .sheet(item: Binding(
                get: {
                    if let selected = selectedLiveLesson {
                        return LiveLessonWrapper(roomName: selected.roomName, title: selected.title)
                    }
                    return nil
                },
                set: { if $0 == nil { selectedLiveLesson = nil } }
            )) { item in
                LiveClassroomView(roomName: item.roomName, lessonTitle: item.title)
            }
            // Notifications Sheet
            .sheet(isPresented: $showNotifications) {
                NotificationsView()
            }
            // Progress Sheet
            .sheet(isPresented: $showProgress) {
                StudentProgressView()
            }
            // Authorizer Portal Sheet
            .sheet(isPresented: $showAuthorizer) {
                AuthorizerView()
            }
            // Certificate Sheet
            .sheet(item: $selectedCertificateCourse) { course in
                CertificateView(
                    courseTitle: course.title,
                    studentName: api.currentUser?.fullName ?? "EduVerse Student",
                    instructorName: course.instructorName,
                    courseId: course.id
                )
            }
            .task {
                courses = await api.fetchCourses()
                isLoading = false
            }
        }
    }
}

struct LiveLessonWrapper: Identifiable {
    let id = UUID()
    let roomName: String
    let title: String
}

struct CourseCardView: View {
    let course: Course
    let onJoinLive: (Lesson) -> Void
    var onViewCertificate: (() -> Void)? = nil

    var isCompleted: Bool {
        course.isCompleted ?? false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(course.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                if isCompleted {
                    Text("COMPLETED")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: "10B981"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "10B981").opacity(0.15))
                        .cornerRadius(6)
                } else {
                    Text("ENROLLED")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: "6366F1"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "6366F1").opacity(0.15))
                        .cornerRadius(6)
                }
            }

            Text(course.description)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.65))
                .lineLimit(2)

            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.white.opacity(0.4))
                Text("Instructor: \(course.instructorName)")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }

            HStack(spacing: 8) {
                if let lesson = course.lessons?.first(where: { $0.isLive }) {
                    Button(action: {
                        onJoinLive(lesson)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "video.fill")
                                .font(.system(size: 13))
                            Text("Live Classroom")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Color(hex: "10B981"))
                        .cornerRadius(10)
                    }
                }

                if isCompleted {
                    Button(action: {
                        onViewCertificate?()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "seal.fill")
                                .font(.system(size: 12))
                            Text("Certificate")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(Color(hex: "F59E0B"))
                        .frame(width: 105, height: 40)
                        .background(Color(hex: "F59E0B").opacity(0.15))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "F59E0B").opacity(0.3), lineWidth: 1))
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color(red: 20/255, green: 20/255, blue: 38/255))
        .cornerRadius(16)
    }
}
