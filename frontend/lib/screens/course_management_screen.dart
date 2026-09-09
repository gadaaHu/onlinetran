import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/models.dart';
import '../core/api_client.dart';
import '../core/providers.dart';
import '../core/theme.dart';
import 'add_lesson_screen.dart';
import 'create_quiz_screen.dart';
import 'add_questions_screen.dart';
import 'live_classroom_screen.dart';

class CourseManagementScreen extends ConsumerStatefulWidget {
  final CourseModel course;
  const CourseManagementScreen({super.key, required this.course});

  @override
  ConsumerState<CourseManagementScreen> createState() => _CourseManagementScreenState();
}

class _CourseManagementScreenState extends ConsumerState<CourseManagementScreen> {
  bool _isLoading = true;
  bool _isPublishing = false;
  CourseDetailsModel? _courseDetails;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.dio.get('/courses/${widget.course.id}');
      setState(() {
        _courseDetails = CourseDetailsModel.fromJson(res.data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load course details.';
        _isLoading = false;
      });
    }
  }

  Future<void> _togglePublish() async {
    if (_courseDetails == null || _isPublishing) return;
    setState(() => _isPublishing = true);
    final newValue = !_courseDetails!.isPublished;
    final success = await ref.read(coursesProvider.notifier).setPublished(
          _courseDetails!.id,
          _courseDetails!.title,
          _courseDetails!.description,
          _courseDetails!.price,
          newValue,
        );
    if (success) {
      await _fetchDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(newValue ? '🎉 Course is now LIVE and visible to students!' : 'Course unpublished.'),
          backgroundColor: newValue ? const Color(0xFF43B97F) : Colors.orange,
        ));
      }
    }
    setState(() => _isPublishing = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course.title, style: const TextStyle()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDetails,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    // --- Publish Status Banner ---
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _courseDetails!.isPublished
                            ? const Color(0xFF1A3A2A)
                            : const Color(0xFF2A1A1A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _courseDetails!.isPublished
                              ? const Color(0xFF43B97F)
                              : Colors.orange,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _courseDetails!.isPublished
                                ? Icons.public
                                : Icons.public_off,
                            color: _courseDetails!.isPublished
                                ? const Color(0xFF43B97F)
                                : Colors.orange,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _courseDetails!.isPublished
                                      ? 'Published — Visible to Students'
                                      : 'Draft — Not visible to students yet',
                                  style: TextStyle(
                                    color: _courseDetails!.isPublished
                                        ? const Color(0xFF43B97F)
                                        : Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _courseDetails!.isPublished
                                      ? 'Tap Unpublish to take it offline.'
                                      : 'Tap Publish to make it live!',
                                  style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _isPublishing
                              ? const SizedBox(width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : ElevatedButton(
                                  onPressed: _togglePublish,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _courseDetails!.isPublished
                                        ? Colors.orange
                                        : const Color(0xFF43B97F),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: Text(
                                    _courseDetails!.isPublished ? 'Unpublish' : 'Publish',
                                    style: TextStyle(color: colorScheme.onSurface),
                                  ),
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // --- Lessons ---
                    Text('Manage Lessons', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                    const SizedBox(height: 16),
                    if (_courseDetails!.lessons.isEmpty)
                      Text('No lessons added yet.', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6)))
                    else
                      ..._courseDetails!.lessons.map((lesson) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: lesson.isLive
                                  ? AppColors.violet.withValues(alpha: 0.4)
                                  : colorScheme.outline.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                // Order badge
                                CircleAvatar(
                                  backgroundColor: lesson.isLive
                                      ? AppColors.violet.withValues(alpha: 0.15)
                                      : colorScheme.primary.withValues(alpha: 0.15),
                                  child: Text(
                                    '${lesson.order}',
                                    style: TextStyle(
                                      color: lesson.isLive ? AppColors.violet : colorScheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Title + info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          if (lesson.isLive) ...[
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.rose.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: 5, height: 5,
                                                    decoration: const BoxDecoration(
                                                      color: AppColors.rose,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text('LIVE',
                                                      style: GoogleFonts.inter(
                                                          color: AppColors.rose,
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.w800,
                                                          letterSpacing: 0.5)),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                          ],
                                          Expanded(
                                            child: Text(
                                              lesson.title,
                                              style: GoogleFonts.inter(
                                                color: colorScheme.onSurface,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        lesson.isLive
                                            ? 'Live session · ${lesson.durationInMinutes} mins'
                                            : '${lesson.durationInMinutes} mins',
                                        style: GoogleFonts.inter(
                                          color: colorScheme.onSurface.withValues(alpha: 0.55),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Action button
                                if (lesson.isLive && lesson.meetingUrl != null)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        final user = ref.read(authProvider).user;
                                        final displayName = user?.fullName ?? 'Instructor';
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => LiveClassroomScreen(
                                              roomName: lesson.meetingUrl!,
                                              lessonTitle: lesson.title,
                                              displayName: displayName,
                                              isHost: true,
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.videocam_rounded, size: 14, color: Colors.white),
                                      label: Text(
                                        'Start Live',
                                        style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.violet,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8)),
                                        elevation: 0,
                                      ),
                                    ),
                                  )
                                else
                                  Icon(Icons.video_library,
                                      color: colorScheme.onSurface.withValues(alpha: 0.4)),
                              ],
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddLessonScreen(
                              courseId: widget.course.id,
                              nextOrder: _courseDetails!.lessons.length + 1,
                            ),
                          ),
                        );
                        _fetchDetails(); // Refresh list after returning
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add New Lesson'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Divider(color: colorScheme.onSurface.withValues(alpha: 0.24)),
                    const SizedBox(height: 16),
                    Text('Manage Quizzes', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                    const SizedBox(height: 16),
                    if (_courseDetails!.quizzes.isEmpty)
                      Text('No quizzes added yet.', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6)))
                    else
                      ..._courseDetails!.quizzes.map((quiz) => Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: colorScheme.secondary,
                                child: Icon(Icons.quiz, color: colorScheme.onSurface, size: 18),
                              ),
                              title: Text(quiz.title, style: TextStyle(color: colorScheme.onSurface)),
                              subtitle: Text('Passing Score: ${quiz.passingScore}%', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6))),
                              trailing: Icon(Icons.chevron_right, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddQuestionsScreen(
                                      courseId: widget.course.id,
                                      quiz: quiz,
                                    ),
                                  ),
                                );
                              },
                            ),
                          )),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreateQuizScreen(courseId: widget.course.id),
                          ),
                        );
                        _fetchDetails(); // Refresh list after returning
                      },
                      icon: const Icon(Icons.add_task),
                      label: const Text('Create New Quiz'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.secondary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ),
    );
  }
}
