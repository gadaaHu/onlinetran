import SwiftUI

struct CourseListView: View {
    @ObservedObject var api = APIService.shared
    @State private var courses: [Course] = []
    @State private var isLoading: Bool = true
    @State private var selectedLiveLesson: (roomName: String, title: String)? = nil

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
                                CourseCardView(course: course) { lesson in
                                    let room = lesson.meetingUrl ?? "eduverse-class-\(course.id)"
                                    selectedLiveLesson = (roomName: room, title: lesson.title)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Courses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(course.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("ENROLLED")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.15))
                    .cornerRadius(6)
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

            if let lesson = course.lessons?.first(where: { $0.isLive }) {
                Button(action: {
                    onJoinLive(lesson)
                }) {
                    HStack {
                        Image(systemName: "video.fill")
                            .font(.system(size: 14))
                        Text("Join Live Virtual Classroom")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(Color(red: 16/255, green: 185/255, blue: 129/255))
                    .cornerRadius(10)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color(red: 20/255, green: 20/255, blue: 38/255))
        .cornerRadius(16)
    }
}
