class CourseModel {
  final int id;
  final String title;
  final String description;
  final double price;
  final bool isPublished;
  final String instructorName;
  final DateTime createdAt;

  CourseModel({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.isPublished,
    required this.instructorName,
    required this.createdAt,
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) => CourseModel(
        id: json['id'],
        title: json['title'],
        description: json['description'],
        price: (json['price'] as num).toDouble(),
        isPublished: json['isPublished'],
        instructorName: json['instructorName'],
        createdAt: DateTime.parse(json['createdAt']),
      );
}

class AuthUser {
  final String token;
  final String email;
  final String fullName;
  final List<String> roles;
  final String? profilePictureUrl;

  AuthUser({
    required this.token,
    required this.email,
    required this.fullName,
    required this.roles,
    this.profilePictureUrl,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        token: json['token'],
        email: json['email'],
        fullName: json['fullName'],
        roles: List<String>.from(json['roles']),
        profilePictureUrl: json['profilePictureUrl'],
      );
}

class LessonModel {
  final int id;
  final int courseId;
  final String title;
  final String? videoUrl;
  final int order;
  final int durationInMinutes;
  final bool isLive;
  final String? meetingUrl;
  final String? resourceFilePath;

  LessonModel({
    required this.id,
    required this.courseId,
    required this.title,
    this.videoUrl,
    required this.order,
    required this.durationInMinutes,
    this.isLive = false,
    this.meetingUrl,
    this.resourceFilePath,
  });

  factory LessonModel.fromJson(Map<String, dynamic> json) => LessonModel(
        id: json['id'],
        courseId: json['courseId'],
        title: json['title'],
        videoUrl: json['videoUrl'],
        order: json['order'],
        durationInMinutes: json['durationInMinutes'],
        isLive: json['isLive'] ?? false,
        meetingUrl: json['meetingUrl'],
        resourceFilePath: json['resourceFilePath'],
      );
}

class CourseDetailsModel {
  final int id;
  final String title;
  final String description;
  final double price;
  final bool isPublished;
  final DateTime createdAt;
  final String instructor;
  final List<LessonModel> lessons;
  final List<QuizModel> quizzes;

  CourseDetailsModel({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.isPublished,
    required this.createdAt,
    required this.instructor,
    required this.lessons,
    required this.quizzes,
  });

  factory CourseDetailsModel.fromJson(Map<String, dynamic> json) => CourseDetailsModel(
        id: json['id'],
        title: json['title'],
        description: json['description'],
        price: (json['price'] as num).toDouble(),
        isPublished: json['isPublished'],
        createdAt: DateTime.parse(json['createdAt']),
        instructor: json['instructor'],
        lessons: (json['lessons'] as List).map((l) => LessonModel.fromJson(l)).toList(),
        quizzes: json['quizzes'] != null ? (json['quizzes'] as List).map((q) => QuizModel.fromJson(q)).toList() : [],
      );
}

class QuizModel {
  final int id;
  final int courseId;
  final String title;
  final double passingScore;

  QuizModel({required this.id, required this.courseId, required this.title, required this.passingScore});

  factory QuizModel.fromJson(Map<String, dynamic> json) => QuizModel(
    id: json['id'],
    courseId: json['courseId'],
    title: json['title'],
    passingScore: (json['passingScore'] as num).toDouble(),
  );
}

class QuestionModel {
  final int id;
  final int quizId;
  final String questionText;
  final List<AnswerOptionModel> options;

  QuestionModel({required this.id, required this.quizId, required this.questionText, required this.options});

  factory QuestionModel.fromJson(Map<String, dynamic> json) => QuestionModel(
    id: json['id'],
    quizId: json['quizId'],
    questionText: json['questionText'],
    options: (json['options'] as List).map((o) => AnswerOptionModel.fromJson(o)).toList(),
  );
}

class AnswerOptionModel {
  final int id;
  final String optionText;
  final bool isCorrect;

  AnswerOptionModel({required this.id, required this.optionText, required this.isCorrect});

  factory AnswerOptionModel.fromJson(Map<String, dynamic> json) => AnswerOptionModel(
    id: json['id'],
    optionText: json['optionText'],
    isCorrect: json['isCorrect'],
  );
}

class UserManagementModel {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final bool isActive;
  final List<String> roles;
  final int enrollmentCount;

  UserManagementModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.isActive,
    required this.roles,
    required this.enrollmentCount,
  });

  String get fullName => '$firstName $lastName';
  String get primaryRole => roles.isNotEmpty ? roles.first : 'Student';

  factory UserManagementModel.fromJson(Map<String, dynamic> json) => UserManagementModel(
    id: json['id'],
    firstName: json['firstName'],
    lastName: json['lastName'],
    email: json['email'],
    isActive: json['isActive'],
    roles: List<String>.from(json['roles']),
    enrollmentCount: json['enrollmentCount'],
  );
}

class StudentQuizModel {
  final int id;
  final int courseId;
  final String title;
  final double passingScore;
  final List<StudentQuestionModel> questions;

  StudentQuizModel({required this.id, required this.courseId, required this.title, required this.passingScore, required this.questions});

  factory StudentQuizModel.fromJson(Map<String, dynamic> json) => StudentQuizModel(
    id: json['id'],
    courseId: json['courseId'],
    title: json['title'],
    passingScore: (json['passingScore'] as num).toDouble(),
    questions: (json['questions'] as List).map((q) => StudentQuestionModel.fromJson(q)).toList(),
  );
}

class StudentQuestionModel {
  final int id;
  final String questionText;
  final List<StudentAnswerOptionModel> options;

  StudentQuestionModel({required this.id, required this.questionText, required this.options});

  factory StudentQuestionModel.fromJson(Map<String, dynamic> json) => StudentQuestionModel(
    id: json['id'],
    questionText: json['questionText'],
    options: (json['options'] as List).map((o) => StudentAnswerOptionModel.fromJson(o)).toList(),
  );
}

class StudentAnswerOptionModel {
  final int id;
  final String optionText;

  StudentAnswerOptionModel({required this.id, required this.optionText});

  factory StudentAnswerOptionModel.fromJson(Map<String, dynamic> json) => StudentAnswerOptionModel(
    id: json['id'],
    optionText: json['optionText'],
  );
}

class QuizResultModel {
  final int score;
  final bool passed;

  QuizResultModel({required this.score, required this.passed});

  factory QuizResultModel.fromJson(Map<String, dynamic> json) => QuizResultModel(
    score: json['score'],
    passed: json['passed'],
  );
}

class EnrollmentModel {
  final int courseId;
  final String courseTitle;
  final DateTime enrolledAt;
  final double progressPercentage;
  final bool hasCertificate;

  EnrollmentModel({
    required this.courseId,
    required this.courseTitle,
    required this.enrolledAt,
    required this.progressPercentage,
    required this.hasCertificate,
  });

  factory EnrollmentModel.fromJson(Map<String, dynamic> json) => EnrollmentModel(
        courseId: json['courseId'],
        courseTitle: json['courseTitle'],
        enrolledAt: DateTime.parse(json['enrolledAt']),
        progressPercentage: (json['progressPercentage'] as num).toDouble(),
        hasCertificate: json['hasCertificate'] ?? false,
      );
}
