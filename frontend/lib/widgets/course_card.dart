import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../core/models.dart';
import '../core/providers.dart';
import '../screens/course_management_screen.dart';
import '../screens/student_course_screen.dart';

class CourseCard extends ConsumerStatefulWidget {
  final CourseModel course;
  const CourseCard({super.key, required this.course});

  @override
  ConsumerState<CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends ConsumerState<CourseCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _shadow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _shadow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // Card-specific gradient per course id
  static const _gradients = [
    [Color(0xFF4F46E5), Color(0xFF7C3AED)],
    [Color(0xFF0EA5E9), Color(0xFF06B6D4)],
    [Color(0xFF10B981), Color(0xFF059669)],
    [Color(0xFFF43F5E), Color(0xFFEC4899)],
    [Color(0xFFF59E0B), Color(0xFFEF4444)],
    [Color(0xFF8B5CF6), Color(0xFF4F46E5)],
  ];

  List<Color> get _cardGradient =>
      _gradients[widget.course.id % _gradients.length];

  @override
  Widget build(BuildContext context, ) {
    final user = ref.watch(authProvider).user;
    final isInstructor = user?.roles.contains('Instructor') ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => _ctrl.forward(),
      onExit: (_) => _ctrl.reverse(),
      cursor: SystemMouseCursors.click,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          return Transform.scale(
            scale: _scale.value,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _cardGradient[0]
                        .withValues(alpha: 0.12 + 0.18 * _shadow.value),
                    blurRadius: 16 + 12 * _shadow.value,
                    spreadRadius: -2 + 2 * _shadow.value,
                    offset: Offset(0, 4 + 4 * _shadow.value),
                  ),
                ],
                border: Border.all(
                  color: isDark
                      ? AppColors.darkBorder
                      : AppColors.lightBorder,
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Material(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  child: InkWell(
                    onTap: () {
                      if (isInstructor) {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => CourseManagementScreen(
                                    course: widget.course)));
                      } else {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => StudentCourseScreen(
                                    course: widget.course)));
                      }
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Hero gradient area ──────────────────────────────
                        _HeroArea(
                          gradient: _cardGradient,
                          course: widget.course,
                        ),
                        // ── Content ─────────────────────────────────────────
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.course.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F0F1A),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    letterSpacing: -0.2,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  widget.course.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: isDark
                                        ? const Color(0xFF9CA3AF)
                                        : const Color(0xFF6B7280),
                                    fontSize: 12,
                                    height: 1.5,
                                  ),
                                ),
                                const Spacer(),
                                // ── Footer row ────────────────────────────
                                Row(
                                  children: [
                                    // Instructor avatar
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                            colors: _cardGradient),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Center(
                                        child: Text(
                                          widget.course.instructorName
                                                  .isNotEmpty
                                              ? widget.course.instructorName[0]
                                                  .toUpperCase()
                                              : '?',
                                          style: GoogleFonts.inter(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        widget.course.instructorName,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          color: isDark
                                              ? const Color(0xFF6B7280)
                                              : const Color(0xFF9CA3AF),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    // Rating
                                    const Icon(Icons.star_rounded,
                                        color: AppColors.amber, size: 13),
                                    const SizedBox(width: 2),
                                    Text('4.8',
                                        style: GoogleFonts.inter(
                                          color: isDark
                                              ? const Color(0xFF9CA3AF)
                                              : const Color(0xFF6B7280),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        )),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HeroArea extends StatelessWidget {
  final List<Color> gradient;
  final CourseModel course;
  const _HeroArea({required this.gradient, required this.course});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: 10,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          // Center icon
          Center(
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
          // Price badge — glassmorphism
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.30),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2), width: 1),
              ),
              child: Text(
                course.price == 0
                    ? 'FREE'
                    : '\$${course.price.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
