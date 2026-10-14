import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../core/providers.dart';
import '../core/models.dart';
import '../core/api_client.dart';
import '../widgets/course_card.dart';
import 'login_screen.dart';
import 'create_course_screen.dart';
import 'admin_screen.dart';

// ─── Enrolled Courses Provider moved to providers.dart ────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _heroCtrl;
  late Animation<double> _heroFade;
  late Animation<Offset> _heroSlide;

  @override
  void initState() {
    super.initState();
    _heroCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _heroFade = CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut);
    _heroSlide = Tween<Offset>(
            begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut));
    _heroCtrl.forward();

    Future.microtask(() {
      ref.read(coursesProvider.notifier).fetchCourses();
      ref.read(teachingCoursesProvider.notifier).fetchCourses();
    });
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    super.dispose();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final firstName = user?.fullName.split(' ').first ?? 'there';

    final tabs = [
      _CourseCatalogTab(heroFade: _heroFade, heroSlide: _heroSlide, greeting: _greeting(), firstName: firstName),
      const _MyCoursesTab(),
      if (user != null && user.roles.contains('Instructor'))
        const _TeachingTab(),
      _ProfileTab(),
      if (user != null && user.roles.contains('Admin')) const AdminScreen(),
    ];

    return Scaffold(
      appBar: _buildAppBar(context, user, colorScheme, isDark),
      body: IndexedStack(index: _selectedIndex, children: tabs),
      floatingActionButton: (auth.user?.roles.contains('Instructor') ?? false)
          ? _buildFAB(context, colorScheme)
          : null,
      bottomNavigationBar: _buildNavBar(colorScheme, user),
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, AuthUser? user, ColorScheme colorScheme, bool isDark) {
    return AppBar(
      elevation: 0,
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.school_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Text('Immigration & Citizenship',
              style: GoogleFonts.inter(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: -0.5,
              )),
        ],
      ),
      actions: [
        // Theme toggle
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.5)),
          ),
          child: IconButton(
            iconSize: 18,
            icon: Icon(
              ref.watch(themeProvider) == ThemeMode.light
                  ? Icons.dark_mode_rounded
                  : Icons.light_mode_rounded,
              color: colorScheme.onSurface,
            ),
            onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
          ),
        ),
        const SizedBox(width: 8),
        if (user != null)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: PopupMenuButton<String>(
              offset: const Offset(0, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.3)),
              ),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: user.profilePictureUrl != null && user.profilePictureUrl!.isNotEmpty ? null : AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  image: user.profilePictureUrl != null && user.profilePictureUrl!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage('${ApiClient.baseUrl.replaceAll('/api', '')}/profiles/${user.profilePictureUrl}'),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: user.profilePictureUrl == null || user.profilePictureUrl!.isEmpty
                    ? Center(
                        child: Text(
                          user.fullName.isNotEmpty
                              ? user.fullName[0].toUpperCase()
                              : 'U',
                          style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14),
                        ),
                      )
                    : null,
              ),
              itemBuilder: (_) => [
                PopupMenuItem(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.fullName,
                          style: GoogleFonts.inter(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                      Text(user.email,
                          style: GoogleFonts.inter(
                              color: colorScheme.onSurface.withValues(alpha: 0.55),
                              fontSize: 12)),
                      const SizedBox(height: 4),
                      Divider(height: 1,
                          color: colorScheme.outline.withValues(alpha: 0.3)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'logout',
                  onTap: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                          (_) => false);
                    }
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.logout_rounded,
                          color: AppColors.rose, size: 18),
                      const SizedBox(width: 10),
                      Text('Logout',
                          style: GoogleFonts.inter(
                              color: AppColors.rose,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFAB(BuildContext context, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.indigo.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const CreateCourseScreen())),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Create Course',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavBar(ColorScheme colorScheme, AuthUser? user) {
    return NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (i) => setState(() => _selectedIndex = i),
      height: 64,
      destinations: [
        const NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Explore'),
        const NavigationDestination(
            icon: Icon(Icons.bookmark_outline_rounded),
            selectedIcon: Icon(Icons.bookmark_rounded),
            label: 'My Learning'),
        if (user != null && user.roles.contains('Instructor'))
          const NavigationDestination(
              icon: Icon(Icons.school_outlined),
              selectedIcon: Icon(Icons.school_rounded),
              label: 'Teaching'),
        const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile'),
        if (user != null && user.roles.contains('Admin'))
          const NavigationDestination(
              icon: Icon(Icons.admin_panel_settings_outlined),
              selectedIcon: Icon(Icons.admin_panel_settings_rounded),
              label: 'Admin'),
      ],
    );
  }
}

// ─── Course Catalog Tab ───────────────────────────────────────────────────────
class _CourseCatalogTab extends ConsumerStatefulWidget {
  final Animation<double> heroFade;
  final Animation<Offset> heroSlide;
  final String greeting;
  final String firstName;

  const _CourseCatalogTab({
    required this.heroFade,
    required this.heroSlide,
    required this.greeting,
    required this.firstName,
  });

  @override
  ConsumerState<_CourseCatalogTab> createState() => _CourseCatalogTabState();
}

class _CourseCatalogTabState extends ConsumerState<_CourseCatalogTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final courses = ref.watch(coursesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return CustomScrollView(
      slivers: [
        // ── Hero Banner ─────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: widget.heroFade,
            child: SlideTransition(
              position: widget.heroSlide,
              child: _HeroBanner(
                greeting: widget.greeting,
                firstName: widget.firstName,
                searchCtrl: _searchCtrl,
                onSearch: (v) => setState(() => _query = v.toLowerCase()),
                courseCount: courses.whenOrNull(data: (d) => d.length) ?? 0,
              ),
            ),
          ),
        ),

        // ── Section header ─────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
            child: Row(
              children: [
                Text('All Courses',
                    style: AppTextStyles.headlineMedium(colorScheme.onSurface)),
                const Spacer(),
                courses.maybeWhen(
                  data: (d) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.indigo.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${d.length} courses',
                      style: GoogleFonts.inter(
                          color: AppColors.indigo,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  orElse: () => const SizedBox(),
                ),
              ],
            ),
          ),
        ),

        // ── Grid ───────────────────────────────────────────────────────────
        courses.when(
          loading: () => SliverFillRemaining(
            child: Center(
                child: CircularProgressIndicator(color: colorScheme.primary)),
          ),
          error: (e, _) => SliverFillRemaining(
            child: _ErrorState(
              onRetry: () =>
                  ref.read(coursesProvider.notifier).fetchCourses(),
            ),
          ),
          data: (allCourses) {
            final filtered = _query.isEmpty
                ? allCourses
                : allCourses
                    .where((c) =>
                        c.title.toLowerCase().contains(_query) ||
                        c.description.toLowerCase().contains(_query) ||
                        c.instructorName.toLowerCase().contains(_query))
                    .toList();

            if (filtered.isEmpty) {
              return SliverFillRemaining(
                child: _EmptyState(
                  icon: _query.isEmpty
                      ? Icons.library_books_outlined
                      : Icons.search_off_rounded,
                  message: _query.isEmpty
                      ? 'No courses published yet'
                      : 'No results for "$_query"',
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => CourseCard(course: filtered[i]),
                  childCount: filtered.length,
                ),
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 340,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.72,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─── Hero Banner ──────────────────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  final String greeting;
  final String firstName;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearch;
  final int courseCount;

  const _HeroBanner({
    required this.greeting,
    required this.firstName,
    required this.searchCtrl,
    required this.onSearch,
    required this.courseCount,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      decoration: BoxDecoration(
        gradient: isDark
            ? AppColors.heroGradientDark
            : const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFF0EA5E9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.indigo.withValues(alpha: 0.35),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background orbs
          const Positioned(
            top: -40,
            right: -30,
            child: _Orb(size: 120, opacity: 0.08),
          ),
          const Positioned(
            bottom: -20,
            left: 20,
            child: _Orb(size: 80, opacity: 0.08),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$greeting, $firstName 👋',
                  style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Text('Learn something\namazing today',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      height: 1.15)),
              const SizedBox(height: 20),
              // Stats row
              Row(
                children: [
                  _HeroStat(
                      value: '$courseCount',
                      label: 'Courses'),
                  const SizedBox(width: 16),
                  const _HeroStat(value: '1.2K', label: 'Students'),
                  const SizedBox(width: 16),
                  const _HeroStat(value: '4.8 ★', label: 'Avg Rating'),
                ],
              ),
              const SizedBox(height: 20),
              // Search bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25), width: 1.5),
                ),
                child: TextField(
                  controller: searchCtrl,
                  onChanged: onSearch,
                  style: GoogleFonts.inter(
                      color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    hintText: 'Search courses, topics...',
                    hintStyle: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: Colors.white.withValues(alpha: 0.7), size: 20),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final double opacity;
  const _Orb({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      );
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String label;
  const _HeroStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800)),
        Text(label,
            style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 11,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ─── My Courses Tab ───────────────────────────────────────────────────────────
class _MyCoursesTab extends ConsumerWidget {
  const _MyCoursesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final enrollments = ref.watch(enrolledCoursesProvider);

    return enrollments.when(
      loading: () => Center(
          child: CircularProgressIndicator(color: colorScheme.primary)),
      error: (e, _) => _ErrorState(
          onRetry: () => ref.invalidate(enrolledCoursesProvider)),
      data: (list) {
        if (list.isEmpty) {
          return const _EmptyState(
            icon: Icons.bookmark_outline_rounded,
            message: 'No enrollments yet',
            subtitle: 'Browse courses in the Explore tab and start learning',
          );
        }
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('My Learning',
                        style:
                            AppTextStyles.headlineMedium(colorScheme.onSurface)),
                    const SizedBox(height: 4),
                    Text('${list.length} courses enrolled',
                        style: GoogleFonts.inter(
                            color: colorScheme.onSurface.withValues(alpha: 0.55),
                            fontSize: 14)),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _EnrollmentCard(enrollment: list[i]),
                  childCount: list.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EnrollmentCard extends StatelessWidget {
  final EnrollmentModel enrollment;
  const _EnrollmentCard({required this.enrollment});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = enrollment.progressPercentage / 100.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.school_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(enrollment.courseTitle,
                        style: GoogleFonts.inter(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            height: 1.3)),
                    const SizedBox(height: 2),
                    Text(
                        'Enrolled ${_formatDate(enrollment.enrolledAt)}',
                        style: GoogleFonts.inter(
                            color:
                                colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.indigo.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${enrollment.progressPercentage.toInt()}%',
                  style: GoogleFonts.inter(
                      color: AppColors.indigo,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor:
                  colorScheme.onSurface.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.indigo),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays < 1) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).round()}mo ago';
  }
}

// ─── Teaching Tab ─────────────────────────────────────────────────────────────
class _TeachingTab extends ConsumerWidget {
  const _TeachingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teachingCourses = ref.watch(teachingCoursesProvider);
    final colorScheme = Theme.of(context).colorScheme;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('My Teaching',
                    style:
                        AppTextStyles.headlineMedium(colorScheme.onSurface)),
                const SizedBox(height: 4),
                Text('Manage your drafted and published courses',
                    style: GoogleFonts.inter(
                        color: colorScheme.onSurface.withValues(alpha: 0.55),
                        fontSize: 14)),
              ],
            ),
          ),
        ),
        teachingCourses.when(
          loading: () => SliverFillRemaining(
            child: Center(
                child: CircularProgressIndicator(color: colorScheme.primary)),
          ),
          error: (e, _) => SliverFillRemaining(
            child: _ErrorState(
                onRetry: () =>
                    ref.read(teachingCoursesProvider.notifier).fetchCourses()),
          ),
          data: (courses) => courses.isEmpty
              ? const SliverFillRemaining(
                  child: _EmptyState(
                    icon: Icons.edit_note_rounded,
                    message: 'No courses created yet',
                    subtitle: 'Tap "Create Course" to publish your first course',
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => CourseCard(course: courses[i]),
                      childCount: courses.length,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 340,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.72,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// ─── Profile Tab ──────────────────────────────────────────────────────────────
class _ProfileTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enrollments = ref.watch(enrolledCoursesProvider);
    if (user == null) return const SizedBox();

    return SingleChildScrollView(
      child: Column(
        children: [
          // ── Profile header ──────────────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
            ),
            padding:
                const EdgeInsets.fromLTRB(24, 40, 24, 32),
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.2),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4), width: 3),
                    image: user.profilePictureUrl != null && user.profilePictureUrl!.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage('${ApiClient.baseUrl.replaceAll('/api', '')}/profiles/${user.profilePictureUrl!}'),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: user.profilePictureUrl == null || user.profilePictureUrl!.isEmpty
                      ? Center(
                          child: Text(
                            user.fullName.isNotEmpty
                                ? user.fullName[0].toUpperCase()
                                : 'U',
                            style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 38,
                                fontWeight: FontWeight.w800),
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 14),
                Text(user.fullName,
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4)),
                const SizedBox(height: 4),
                Text(user.email,
                    style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 14)),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  children: user.roles
                      .map((r) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color:
                                      Colors.white.withValues(alpha: 0.3)),
                            ),
                            child: Text(r,
                                style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),

          // ── Stats row ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                _ProfileStat(
                  value: enrollments.maybeWhen(
                      data: (d) => '${d.length}', orElse: () => '—'),
                  label: 'Enrolled',
                  icon: Icons.bookmark_rounded,
                  color: AppColors.indigo,
                ),
                const SizedBox(width: 12),
                  _ProfileStat(
                    value: enrollments.maybeWhen(
                        data: (d) => '${d.where((e) => e.hasCertificate).length}', orElse: () => '0'),
                    label: 'Certificates',
                    icon: Icons.workspace_premium_rounded,
                    color: AppColors.amber,
                  ),
                const SizedBox(width: 12),
                const _ProfileStat(
                  value: '7 🔥',
                  label: 'Day Streak',
                  icon: Icons.local_fire_department_rounded,
                  color: AppColors.rose,
                ),
              ],
            ),
          ),

          // ── Settings list ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  trailing: Switch(
                    value: true,
                    onChanged: (_) {},
                    activeThumbColor: AppColors.indigo,
                  ),
                  color: AppColors.indigo,
                ),
                const SizedBox(height: 10),
                _SettingsTile(
                  icon: isDark
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                  title: isDark ? 'Light Mode' : 'Dark Mode',
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFF9CA3AF)),
                  color: AppColors.violet,
                  onTap: () =>
                      ref.read(themeProvider.notifier).toggleTheme(),
                ),
                const SizedBox(height: 10),
                _SettingsTile(
                  icon: Icons.logout_rounded,
                  title: 'Logout',
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFF9CA3AF)),
                  color: AppColors.rose,
                  onTap: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                          (_) => false);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const _ProfileStat(
      {required this.value,
      required this.label,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: GoogleFonts.inter(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            Text(label,
                style: GoogleFonts.inter(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                    fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget trailing;
  final Color color;
  final VoidCallback? onTap;
  const _SettingsTile(
      {required this.icon,
      required this.title,
      required this.trailing,
      required this.color,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color:
                    isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: Text(title,
                      style: GoogleFonts.inter(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                          fontSize: 14))),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subtitle;
  const _EmptyState(
      {required this.icon, required this.message, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  color: colorScheme.primary.withValues(alpha: 0.4), size: 36),
            ),
            const SizedBox(height: 20),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    color: colorScheme.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w600)),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 13,
                      height: 1.5)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded,
              color: colorScheme.onSurface.withValues(alpha: 0.3), size: 56),
          const SizedBox(height: 16),
          Text('Could not load content',
              style: GoogleFonts.inter(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
