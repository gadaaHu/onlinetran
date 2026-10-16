import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/models.dart';

// ---------- Auth State ----------
class AuthState {
  final AuthUser? user;
  final bool isLoading;
  final String? error;
  const AuthState({this.user, this.isLoading = false, this.error});
  AuthState copyWith({AuthUser? user, bool? isLoading, String? error}) =>
      AuthState(
          user: user ?? this.user,
          isLoading: isLoading ?? this.isLoading,
          error: error);
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await ApiClient.dio
          .post('/auth/login', data: {'email': email, 'password': password});
      final user = AuthUser.fromJson(res.data);
      await ApiClient.saveToken(user.token);
      state = state.copyWith(user: user, isLoading: false);
      return true;
    } catch (e) {
      String msg = 'Invalid email or password.';
      if (e is DioException && e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map) {
          if (data['message'] != null) {
            msg = data['message'].toString();
          } else if (data['Message'] != null) {
            msg = data['Message'].toString();
          }
        }
      }
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    }
  }

  Future<Map<String, dynamic>> register(
      String firstName, String lastName, String email, String password, bool isInstructor) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await ApiClient.dio.post('/auth/register', data: {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'password': password,
        'isInstructor': isInstructor,
      });
      String successMsg =
          'Registration successful! Your student account is pending confirmation by the authorizer.';
      if (res.data is Map) {
        if (res.data['message'] != null) {
          successMsg = res.data['message'].toString();
        } else if (res.data['Message'] != null) {
          successMsg = res.data['Message'].toString();
        }
      }
      state = state.copyWith(isLoading: false, error: null);
      return {'success': true, 'message': successMsg};
    } catch (e) {
      String errorMessage = 'Registration failed.';
      if (e is DioException && e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map) {
          final errors = data['errors'] ?? data['Errors'];
          if (errors is List && errors.isNotEmpty) {
            errorMessage = errors.join('\n');
          } else if (data['message'] != null) {
            errorMessage = data['message'].toString();
          } else if (data['Message'] != null) {
            errorMessage = data['Message'].toString();
          }
        }
      }
      state = state.copyWith(isLoading: false, error: errorMessage);
      return {'success': false, 'message': errorMessage};
    }
  }

  Future<void> logout() async {
    await ApiClient.clearToken();
    state = const AuthState();
  }

  void updateProfilePicture(String url) {
    if (state.user != null) {
      final updatedUser = AuthUser(
        token: state.user!.token,
        email: state.user!.email,
        fullName: state.user!.fullName,
        roles: state.user!.roles,
        profilePictureUrl: url,
      );
      state = state.copyWith(user: updatedUser);
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
    (ref) => AuthNotifier());

// ---------- Courses State ----------
class CoursesNotifier extends StateNotifier<AsyncValue<List<CourseModel>>> {
  CoursesNotifier() : super(const AsyncValue.loading());

  Future<void> fetchCourses() async {
    state = const AsyncValue.loading();
    try {
      final res = await ApiClient.dio.get('/courses');
      final items = (res.data['items'] as List)
          .map((j) => CourseModel.fromJson(j))
          .toList();
      state = AsyncValue.data(items);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<bool> createCourse(String title, String description, double price) async {
    try {
      await ApiClient.dio.post('/courses', data: {
        'title': title,
        'description': description,
        'price': price,
      });
      await fetchCourses(); // Refresh list after creation
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> addLesson(int courseId, String title, String? videoUrl, int order, int duration, bool isLive, String? meetingUrl) async {
    try {
      await ApiClient.dio.post('/courses/$courseId/lessons', data: {
        'title': title,
        'videoUrl': videoUrl,
        'order': order,
        'durationInMinutes': duration,
        'isLive': isLive,
        'meetingUrl': meetingUrl,
      });
      return null;
    } catch (e) {
      if (e is DioException) {
        return 'HTTP ${e.response?.statusCode}: ${e.response?.data}';
      }
      return e.toString();
    }
  }

  Future<bool> createQuiz(int courseId, String title, double passingScore) async {
    try {
      await ApiClient.dio.post('/courses/$courseId/quizzes', data: {
        'title': title,
        'passingScore': passingScore,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> addQuestion(int courseId, int quizId, String questionText, List<Map<String, dynamic>> options) async {
    try {
      await ApiClient.dio.post('/courses/$courseId/quizzes/$quizId/questions', data: {
        'questionText': questionText,
        'options': options,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> setPublished(int courseId, String title, String description, double price, bool isPublished) async {
    try {
      await ApiClient.dio.put('/courses/$courseId', data: {
        'title': title,
        'description': description,
        'price': price,
        'isPublished': isPublished,
      });
      await fetchCourses();
      return true;
    } catch (e) {
      return false;
    }
  }
}

final coursesProvider =
    StateNotifierProvider<CoursesNotifier, AsyncValue<List<CourseModel>>>(
        (ref) => CoursesNotifier());

// ---------- Teaching State ----------
class TeachingCoursesNotifier extends StateNotifier<AsyncValue<List<CourseModel>>> {
  TeachingCoursesNotifier() : super(const AsyncValue.loading());

  Future<void> fetchCourses() async {
    state = const AsyncValue.loading();
    try {
      final res = await ApiClient.dio.get('/courses/my-created');
      final courses = (res.data as List).map((j) => CourseModel.fromJson(j)).toList();
      state = AsyncValue.data(courses);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

final teachingCoursesProvider =
    StateNotifierProvider<TeachingCoursesNotifier, AsyncValue<List<CourseModel>>>(
        (ref) => TeachingCoursesNotifier());

// ---------- Admin State ----------
class AdminNotifier extends StateNotifier<AsyncValue<List<UserManagementModel>>> {
  AdminNotifier() : super(const AsyncValue.loading());

  Future<void> fetchUsers({String? search}) async {
    state = const AsyncValue.loading();
    try {
      final res = await ApiClient.dio.get(
        '/admin/users',
        queryParameters: search != null && search.isNotEmpty ? {'search': search} : null,
      );
      final users = (res.data as List).map((j) => UserManagementModel.fromJson(j)).toList();
      state = AsyncValue.data(users);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<bool> setUserRole(String userId, String role) async {
    try {
      await ApiClient.dio.post('/admin/users/$userId/set-role', data: {'role': role});
      await fetchUsers();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> toggleUserStatus(String userId) async {
    try {
      await ApiClient.dio.put('/admin/users/$userId/toggle-status');
      await fetchUsers();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteUser(String userId) async {
    try {
      await ApiClient.dio.delete('/admin/users/$userId');
      await fetchUsers();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> createUser(String firstName, String lastName, String email, String password, String role) async {
    try {
      await ApiClient.dio.post('/admin/users/create', data: {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'password': password,
        'role': role,
      });
      await fetchUsers();
      return null; // success
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? 'Failed to create user';
      return msg.toString();
    } catch (e) {
      return e.toString();
    }
  }
}

final adminProvider =
    StateNotifierProvider<AdminNotifier, AsyncValue<List<UserManagementModel>>>(
        (ref) => AdminNotifier());

// ---------- Theme State ----------
class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.dark);

  void toggleTheme() {
    state = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

// ---------- Student Quiz State ----------
class StudentQuizNotifier extends StateNotifier<AsyncValue<StudentQuizModel?>> {
  StudentQuizNotifier() : super(const AsyncValue.loading());

  Future<void> fetchQuiz(int courseId) async {
    state = const AsyncValue.loading();
    try {
      final res = await ApiClient.dio.get('/courses/$courseId/quizzes');
      if (res.statusCode == 404) {
        state = const AsyncValue.data(null);
        return;
      }
      final quiz = StudentQuizModel.fromJson(res.data);
      state = AsyncValue.data(quiz);
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        state = const AsyncValue.data(null);
      } else {
        state = AsyncValue.error(e, StackTrace.current);
      }
    }
  }

  Future<QuizResultModel?> submitQuiz(int courseId, int quizId, Map<int, int> answers) async {
    try {
      final answersList = answers.entries.map((e) => {
        'questionId': e.key,
        'selectedOptionId': e.value
      }).toList();
      
      final res = await ApiClient.dio.post('/courses/$courseId/quizzes/$quizId/submit', data: {
        'answers': answersList,
      });
      return QuizResultModel.fromJson(res.data);
    } catch (e) {
      return null;
    }
  }

  Future<bool> checkPassedStatus(int courseId) async {
    try {
      final res = await ApiClient.dio.get('/courses/$courseId/result');
      if (res.statusCode == 200) {
        return res.data['passed'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<List<int>?> downloadCertificate(int courseId) async {
    try {
      final res = await ApiClient.dio.get<List<int>>(
        '/courses/$courseId/certificate',
        options: Options(responseType: ResponseType.bytes),
      );
      return res.data;
    } catch (e) {
      return null;
    }
  }
}

final studentQuizProvider =
    StateNotifierProvider.autoDispose<StudentQuizNotifier, AsyncValue<StudentQuizModel?>>(
        (ref) => StudentQuizNotifier());

// ---------- Enrolled Courses ----------
final enrolledCoursesProvider =
    FutureProvider.autoDispose<List<EnrollmentModel>>((ref) async {
  final res = await ApiClient.dio.get('/courses/my-enrollments');
  return (res.data as List)
      .map((e) => EnrollmentModel.fromJson(e))
      .toList();
});
