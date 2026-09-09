import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_html/html.dart' as html;
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import '../core/models.dart';
import '../core/api_client.dart';
import '../core/providers.dart';
import '../core/theme.dart';
import 'exam_screen.dart';
import 'face_registration_screen.dart';
import 'live_classroom_screen.dart';

class StudentCourseScreen extends ConsumerStatefulWidget {
  final CourseModel course;
  const StudentCourseScreen({super.key, required this.course});

  @override
  ConsumerState<StudentCourseScreen> createState() => _StudentCourseScreenState();
}

class _StudentCourseScreenState extends ConsumerState<StudentCourseScreen> {
  bool _isLoading = true;
  bool _hasPassed = false;
  bool _isDownloading = false;
  bool _isEnrolled = false;
  bool _isEnrolling = false;
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
      final passed = await ref.read(studentQuizProvider.notifier).checkPassedStatus(widget.course.id);

      // Check if enrolled by seeing if this course appears in my enrollments
      bool enrolled = false;
      try {
        final enrollRes = await ApiClient.dio.get('/courses/my-enrollments');
        final list = enrollRes.data as List;
        enrolled = list.any((e) => e['courseId'] == widget.course.id);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _courseDetails = CourseDetailsModel.fromJson(res.data);
          _hasPassed = passed;
          _isEnrolled = enrolled;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load course details.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _enroll() async {
    setState(() => _isEnrolling = true);
    try {
      await ApiClient.dio.post('/courses/${widget.course.id}/enroll');
      setState(() {
        _isEnrolled = true;
        _isEnrolling = false;
      });
      // Invalidate the enrolled courses provider to refresh the My Learning tab
      ref.invalidate(enrolledCoursesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Successfully enrolled! Welcome to the course.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        // Navigate to face registration immediately after enrollment
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FaceRegistrationScreen()),
        );
      }
    } catch (e) {
      setState(() => _isEnrolling = false);
      String msg = 'Enrollment failed.';
      if (e is DioException && e.response?.data?['message'] != null) {
        msg = e.response!.data['message'];
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Future<void> _downloadCertificate() async {
    setState(() => _isDownloading = true);
    
    final bytes = await ref.read(studentQuizProvider.notifier).downloadCertificate(widget.course.id);
    
    if (mounted) {
      setState(() => _isDownloading = false);
    }
    
    if (bytes != null && bytes.isNotEmpty) {
      final base64data = base64Encode(bytes);
      final a = html.AnchorElement(href: 'data:application/pdf;base64,$base64data');
      a.download = 'Certificate_${widget.course.title.replaceAll(' ', '_')}.pdf';
      a.click();
      a.remove();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Certificate downloaded successfully!')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to download certificate.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      bottomNavigationBar: (!_isLoading && _error == null && !_isEnrolled)
          ? _EnrollBottomBar(
              course: widget.course,
              isEnrolling: _isEnrolling,
              onEnroll: _enroll,
            )
          : null,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.indigo))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.rose)))
              : CustomScrollView(

                  slivers: [
                    // ── Premium App Bar ─────────────────────────────────────
                    SliverAppBar(
                      expandedHeight: 240.0,
                      pinned: true,
                      flexibleSpace: FlexibleSpaceBar(
                        background: Container(
                          decoration: BoxDecoration(
                            gradient: isDark ? AppColors.heroGradientDark : AppColors.primaryGradient,
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                top: 20, right: -40,
                                child: Container(
                                  width: 150, height: 150,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 20, left: 20,
                                child: Container(
                                  width: 80, height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        'Course',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _courseDetails!.title,
                                      style: GoogleFonts.inter(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: -0.5,
                                        height: 1.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    
                    // ── Content ─────────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Description
                            Text(
                              _courseDetails!.description,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                height: 1.6,
                                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                              ),
                            ),
                            const SizedBox(height: 32),
                            
                            // Progress
                            Text('Your Progress', style: AppTextStyles.headlineMedium(colorScheme.onSurface)),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_hasPassed ? '100% Completed' : '0% Completed', 
                                          style: GoogleFonts.inter(color: colorScheme.onSurface, fontWeight: FontWeight.w600)),
                                      Text(_hasPassed ? '0 lessons left' : '${_courseDetails!.lessons.length} lessons left', 
                                          style: GoogleFonts.inter(color: colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 13)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: _hasPassed ? 1.0 : 0.0,
                                      minHeight: 8,
                                      backgroundColor: colorScheme.onSurface.withValues(alpha: 0.1),
                                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.emerald),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                            
                            // Certificate Download
                            if (_hasPassed) ...[
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.amber.withValues(alpha: 0.3),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 32),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Course Completed!',
                                            style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                                          const SizedBox(height: 4),
                                          Text('Download your official certificate',
                                            style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: _isDownloading ? null : _downloadCertificate,
                                      icon: _isDownloading
                                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                          : const Icon(Icons.download_rounded, color: Colors.white),
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                                        padding: const EdgeInsets.all(12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),
                            ],
                            
                            // Course Content
                            Text('Course Content', style: AppTextStyles.headlineMedium(colorScheme.onSurface)),
                            const SizedBox(height: 16),
                            if (_courseDetails!.lessons.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                  child: Text('No content available yet.',
                                      style: GoogleFonts.inter(color: colorScheme.onSurface.withValues(alpha: 0.5))),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _courseDetails!.lessons.length,
                                separatorBuilder: (c, i) => const SizedBox(height: 12),
                                itemBuilder: (c, i) {
                                  final lesson = _courseDetails!.lessons[i];
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: lesson.isLive
                                          ? AppColors.violet.withValues(alpha: 0.3)
                                          : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                                    ),
                                    child: Column(
                                      children: [
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.only(
                                              topLeft: const Radius.circular(16),
                                              topRight: const Radius.circular(16),
                                              bottomLeft: Radius.circular(lesson.resourceFilePath != null ? 0 : 16),
                                              bottomRight: Radius.circular(lesson.resourceFilePath != null ? 0 : 16),
                                            ),
                                            onTap: () async {
                                              if (lesson.isLive && lesson.meetingUrl != null) {
                                                // Open the built-in Jitsi classroom.
                                                final user = ref.read(authProvider).user;
                                                final displayName = user?.fullName ?? 'Student';
                                                if (context.mounted) {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => LiveClassroomScreen(
                                                        roomName: lesson.meetingUrl!,
                                                        lessonTitle: lesson.title,
                                                        displayName: displayName,
                                                        isHost: false,
                                                      ),
                                                    ),
                                                  );
                                                }
                                              } else if (lesson.videoUrl != null && lesson.videoUrl!.isNotEmpty) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Opening: ${lesson.title}')),
                                                );
                                              }
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 40, height: 40,
                                                    decoration: BoxDecoration(
                                                      color: lesson.isLive
                                                          ? AppColors.violet.withValues(alpha: 0.12)
                                                          : (_hasPassed
                                                              ? AppColors.emerald.withValues(alpha: 0.1)
                                                              : AppColors.indigo.withValues(alpha: 0.1)),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Center(
                                                      child: _hasPassed && !lesson.isLive
                                                          ? const Icon(Icons.check_rounded, color: AppColors.emerald, size: 20)
                                                          : Icon(
                                                              lesson.isLive ? Icons.videocam_rounded : Icons.play_arrow_rounded,
                                                              color: lesson.isLive ? AppColors.violet : AppColors.indigo,
                                                              size: 20,
                                                            ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            if (lesson.isLive) ...[
                                                              Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                                decoration: BoxDecoration(
                                                                  color: AppColors.rose.withValues(alpha: 0.15),
                                                                  borderRadius: BorderRadius.circular(6),
                                                                ),
                                                                child: Row(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    Container(width: 6, height: 6,
                                                                      decoration: const BoxDecoration(color: AppColors.rose, shape: BoxShape.circle)),
                                                                    const SizedBox(width: 4),
                                                                    Text('LIVE', style: GoogleFonts.inter(color: AppColors.rose, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                                                                  ],
                                                                ),
                                                              ),
                                                              const SizedBox(width: 8),
                                                            ],
                                                            Expanded(
                                                              child: Text(lesson.title,
                                                                  style: GoogleFonts.inter(
                                                                      color: colorScheme.onSurface,
                                                                      fontWeight: FontWeight.w600,
                                                                      fontSize: 15)),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Row(
                                                          children: [
                                                            Icon(Icons.schedule_rounded,
                                                                size: 14, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                                                            const SizedBox(width: 4),
                                                            Text('${lesson.durationInMinutes} mins',
                                                                style: GoogleFonts.inter(
                                                                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                                                                    fontSize: 12)),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Icon(
                                                    lesson.isLive ? Icons.open_in_new_rounded : Icons.play_circle_fill_rounded,
                                                    color: lesson.isLive ? AppColors.violet : AppColors.indigo,
                                                    size: 32,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Download resource row
                                        if (lesson.resourceFilePath != null) ...[
                                          Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius: const BorderRadius.only(
                                                bottomLeft: Radius.circular(16),
                                                bottomRight: Radius.circular(16),
                                              ),
                                              onTap: () async {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Downloading resource...')),
                                                );
                                                try {
                                                  final res = await ApiClient.dio.get<List<int>>(
                                                    '/courses/${widget.course.id}/lessons/${lesson.id}/download-resource',
                                                    options: Options(responseType: ResponseType.bytes),
                                                  );
                                                  if (res.data != null) {
                                                    final base64data = base64Encode(res.data!);
                                                    final a = html.AnchorElement(href: 'data:application/octet-stream;base64,$base64data');
                                                    a.download = lesson.resourceFilePath!;
                                                    a.click();
                                                    a.remove();
                                                  }
                                                } catch (_) {
                                                  if (mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('Failed to download resource.')),
                                                    );
                                                  }
                                                }
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.attach_file_rounded, size: 16, color: AppColors.cyan),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        lesson.resourceFilePath!.contains('_')
                                                            ? lesson.resourceFilePath!.substring(lesson.resourceFilePath!.indexOf('_') + 1)
                                                            : lesson.resourceFilePath!,
                                                        style: GoogleFonts.inter(color: AppColors.cyan, fontSize: 13, fontWeight: FontWeight.w500),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    const Icon(Icons.download_rounded, size: 18, color: AppColors.cyan),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),
                            
                            const SizedBox(height: 32),
                            Text('Assessment', style: AppTextStyles.headlineMedium(colorScheme.onSurface)),
                            const SizedBox(height: 16),
                            if (_courseDetails!.quizzes.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                  child: Text('No exams for this course.',
                                      style: GoogleFonts.inter(color: colorScheme.onSurface.withValues(alpha: 0.5))),
                                ),
                              )
                            else
                              ..._courseDetails!.quizzes.map((quiz) => Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 2),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: AppColors.violet.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(Icons.assignment_rounded, color: AppColors.violet),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(quiz.title,
                                                  style: GoogleFonts.inter(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.w700,
                                                      color: colorScheme.onSurface)),
                                              const SizedBox(height: 2),
                                              Text('Passing Score: ${quiz.passingScore}%',
                                                  style: GoogleFonts.inter(
                                                      color: colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ExamScreen(
                                                  courseId: widget.course.id,
                                                  quizTitle: quiz.title),
                                            ),
                                          );
                                          _fetchDetails();
                                        },
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                        ),
                                        child: Text(_hasPassed ? 'Retake Exam' : 'Take Exam'),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ─── Enroll Bottom Bar ────────────────────────────────────────────────────────
class _EnrollBottomBar extends StatelessWidget {
  final CourseModel course;
  final bool isEnrolling;
  final VoidCallback onEnroll;

  const _EnrollBottomBar({
    required this.course,
    required this.isEnrolling,
    required this.onEnroll,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Price display
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Price',
                style: GoogleFonts.inter(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
              Text(
                course.price == 0
                    ? 'FREE'
                    : '\$${course.price.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  color: course.price == 0 ? AppColors.emerald : colorScheme.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Enroll button
          Expanded(
            child: SizedBox(
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.indigo.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: isEnrolling ? null : onEnroll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: isEnrolling
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.rocket_launch_rounded,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Enroll Now',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
