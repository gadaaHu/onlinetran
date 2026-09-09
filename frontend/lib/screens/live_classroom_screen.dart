import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../core/platform/jitsi_web.dart';

/// Full-screen built-in live classroom powered by Jitsi Meet.
///
/// Pass [roomName] (the stored lesson meetingUrl) and [lessonTitle].
/// [displayName] is the logged-in user's name shown inside the meeting.
/// Set [isHost] to true for the instructor so the AppBar shows "Teaching".
class LiveClassroomScreen extends StatefulWidget {
  final String roomName;
  final String lessonTitle;
  final String displayName;
  final bool isHost;

  const LiveClassroomScreen({
    super.key,
    required this.roomName,
    required this.lessonTitle,
    required this.displayName,
    this.isHost = false,
  });

  @override
  State<LiveClassroomScreen> createState() => _LiveClassroomScreenState();
}

class _LiveClassroomScreenState extends State<LiveClassroomScreen> {
  late final String _viewId;
  bool _isJoining = true;

  @override
  void initState() {
    super.initState();
    // Generate a unique view ID per screen instance to avoid collisions.
    _viewId = 'jitsi-meet-${widget.roomName}-${DateTime.now().millisecondsSinceEpoch}';

    // Register the Jitsi iframe platform view.
    registerJitsiView(_viewId, widget.roomName, widget.displayName);

    // Give the iframe a moment to load before hiding the splash.
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isJoining = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      appBar: _buildAppBar(context),
      body: Stack(
        children: [
          // ── Jitsi Meet iframe ──────────────────────────────────────────
          Positioned.fill(
            child: HtmlElementView(viewType: _viewId),
          ),

          // ── Joining splash overlay ─────────────────────────────────────
          if (_isJoining) _buildJoiningSplash(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF0D0D1A),
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
        onPressed: () => _confirmLeave(context),
      ),
      title: Row(
        children: [
          // Pulsing red dot
          _PulsingDot(),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.lessonTitle,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.isHost ? 'You are teaching' : 'Live classroom',
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Room name chip for debugging / sharing
        Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded, color: Colors.white54, size: 12),
              const SizedBox(width: 4),
              Text(
                'Private room',
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
        // Leave button
        Container(
          margin: const EdgeInsets.only(right: 12),
          child: ElevatedButton.icon(
            onPressed: () => _confirmLeave(context),
            icon: const Icon(Icons.call_end_rounded, size: 16, color: Colors.white),
            label: Text('Leave', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rose,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildJoiningSplash() {
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF09090F),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated logo
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.violet.withValues(alpha: 0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 28),
            Text(
              widget.isHost ? 'Starting your class…' : 'Joining classroom…',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.lessonTitle,
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.violet),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Setting up camera & microphone…',
              style: GoogleFonts.inter(color: Colors.white30, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Leave classroom?',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          widget.isHost
              ? 'Ending the session will disconnect all students.'
              : 'You will leave the live session.',
          style: GoogleFonts.inter(color: Colors.white60, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Stay', style: GoogleFonts.inter(color: AppColors.indigo, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rose,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              widget.isHost ? 'End Class' : 'Leave',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if ((leave ?? false) && context.mounted) {
      Navigator.of(context).pop();
    }
  }
}

// ── Pulsing red dot ───────────────────────────────────────────────────────────
class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: AppColors.rose,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: AppColors.rose.withValues(alpha: 0.6), blurRadius: 6, spreadRadius: 1),
          ],
        ),
      ),
    );
  }
}
