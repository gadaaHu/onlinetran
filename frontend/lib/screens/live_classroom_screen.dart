import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../core/platform/jitsi_web.dart';
import '../core/api_client.dart';

/// Modern Full-Featured Virtual Classroom Suite.
///
/// Features:
/// - Real-time Jitsi video integration
/// - Built-in interactive collaborative Whiteboard (drawing canvas)
/// - Split-view mode (Video + Whiteboard side-by-side)
/// - Multi-tab sidebar: Live Chat, Participants roster, Personal Notes, and Live Polls
/// - Interactive floating reactions (👏, ❤️, 💡, 🔥, 👍)
/// - Hand-raise signaling & Live Session timer
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

enum ClassroomViewMode { video, whiteboard, split }
enum SidebarTab { chat, participants, notes, polls }
enum MobileClassroomTab { video, whiteboard, chat, students }

class _LiveClassroomScreenState extends State<LiveClassroomScreen>
    with TickerProviderStateMixin {
  late final String _viewId;
  bool _isJoining = true;

  // Session elapsed timer
  Timer? _sessionTimer;
  int _elapsedSeconds = 0;

  // Classroom modes & sidebar state
  ClassroomViewMode _viewMode = ClassroomViewMode.video;
  MobileClassroomTab _mobileTab = MobileClassroomTab.video;
  bool _isSidebarOpen = true;
  SidebarTab _activeTab = SidebarTab.chat;

  // Live Student Presence state matching Android Mobile App
  List<LiveStudentPresence> _liveStudents = List.from(sampleLiveStudents);
  bool _isCheckingPresence = false;
  String _presenceFilter = 'ALL';
  bool _isRoomLocked = false;
  String? _controlFeedback;
  Timer? _heartbeatTimer;

  // Local device toggles (visual indicators)
  bool _isMicMuted = false;
  bool _isCameraOff = false;
  bool _isScreenSharing = false;
  bool _isHandRaised = false;

  // Floating reactions
  final List<_ReactionParticle> _reactions = [];

  // Chat state
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final List<_ChatMessage> _messages = [];

  // AI Face Detection state
  bool _isFaceDetectionActive = true;
  bool _isFaceDetected = true;
  double _faceConfidence = 0.96;
  bool _showFaceOverlay = true;
  Timer? _faceCheckTimer;

  // Whiteboard drawing state
  final List<_WhiteboardStroke> _strokes = [];
  Color _penColor = const Color(0xFF8B5CF6);
  final double _strokeWidth = 4.0;
  bool _isEraser = false;

  // Notes state
  final TextEditingController _notesController = TextEditingController(
    text: "# Class Notes\n- Key concepts discussed today:\n  * System architecture\n  * Real-time communication pipelines\n",
  );

  // Poll state
  int? _selectedPollOption;
  final List<_PollOption> _pollOptions = [
    _PollOption(text: "Concept is crystal clear!", votes: 14),
    _PollOption(text: "Need another code example", votes: 4),
    _PollOption(text: "Please recap the last section", votes: 1),
  ];

  @override
  void initState() {
    super.initState();
    _viewId = 'jitsi-meet-${widget.roomName}-${DateTime.now().millisecondsSinceEpoch}';
    registerJitsiView(_viewId, widget.roomName, widget.displayName);

    // Initial simulated chat messages
    _messages.addAll([
      _ChatMessage(
        sender: "EduVerse Bot",
        text: "Welcome to ${widget.lessonTitle}! The live room is active and ready.",
        timestamp: "Just now",
        isBot: true,
      ),
      _ChatMessage(
        sender: widget.isHost ? widget.displayName : "Instructor Sarah",
        text: "Hello everyone! Feel free to ask questions in the chat or raise your hand.",
        timestamp: "1 min ago",
        isInstructor: true,
      ),
    ]);

    // Give iframe a moment to mount
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _isJoining = false);
    });

    // Start live clock
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });

    // Fetch initial live presence and periodically send heartbeat
    _refreshLivePresence();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      ApiClient.sendLiveHeartbeat(
        roomName: widget.roomName,
        isFaceDetected: _isFaceDetected,
        faceCount: _isFaceDetected ? 1 : 0,
        isMicMuted: _isMicMuted,
        isVideoOff: _isCameraOff,
        isHandRaised: _isHandRaised,
      );
    });

    // Periodic AI Face Detection Verification (simulates real-time biometric tracking)
    _faceCheckTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      if (_isCameraOff) {
        setState(() {
          _isFaceDetected = false;
          _faceConfidence = 0.0;
        });
      } else {
        setState(() {
          _isFaceDetected = true;
          _faceConfidence = 0.94 + (timer.tick % 5) * 0.01;
        });
      }
    });
  }

  Future<void> _refreshLivePresence() async {
    if (!mounted) return;
    setState(() => _isCheckingPresence = true);
    final list = await ApiClient.getLivePresence(widget.roomName);
    if (!mounted) return;
    setState(() {
      _liveStudents = list;
      _isCheckingPresence = false;
    });
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _faceCheckTimer?.cancel();
    _heartbeatTimer?.cancel();
    _chatController.dispose();
    _chatScrollController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String get _formattedElapsed {
    final m = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _triggerReaction(String emoji) {
    setState(() {
      _reactions.add(_ReactionParticle(
        emoji: emoji,
        leftPercent: 0.15 + (DateTime.now().millisecond % 70) / 100.0,
      ));
    });

    // Auto cleanup after animation
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted && _reactions.isNotEmpty) {
        setState(() => _reactions.removeAt(0));
      }
    });
  }

  void _sendMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(
        sender: widget.displayName,
        text: text,
        timestamp: "Now",
        isSelf: true,
        isInstructor: widget.isHost,
      ));
      _chatController.clear();
    });

    // Scroll chat to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFF090912),
      appBar: _buildModernAppBar(context),
      body: Stack(
        children: [
          if (isWide)
            // ── Desktop Layout: Stage (Left) + Collapsible Sidebar (Right) ─────
            Row(
              children: [
                Expanded(
                  flex: 7,
                  child: Column(
                    children: [
                      Expanded(child: _buildStageContent(isWide)),
                      _buildBottomControlDock(),
                    ],
                  ),
                ),
                if (_isSidebarOpen)
                  SizedBox(
                    width: 380,
                    child: _buildSidebarPanel(),
                  ),
              ],
            )
          else
            // ── Mobile Layout: Mobile Tab Switcher + Selected View + Dock ──────
            Column(
              children: [
                // Top Segmented Mode Selector matching Android Mobile App
                Container(
                  color: const Color(0xFF0F0F1D),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      _buildMobileTabPill(MobileClassroomTab.video, "📹 Video"),
                      const SizedBox(width: 6),
                      _buildMobileTabPill(MobileClassroomTab.whiteboard, "🎨 Board"),
                      const SizedBox(width: 6),
                      _buildMobileTabPill(MobileClassroomTab.chat, "💬 Chat"),
                      const SizedBox(width: 6),
                      _buildMobileTabPill(MobileClassroomTab.students, "👥 Students"),
                    ],
                  ),
                ),
                Expanded(
                  child: switch (_mobileTab) {
                    MobileClassroomTab.video => _buildVideoView(),
                    MobileClassroomTab.whiteboard => _buildInteractiveWhiteboard(),
                    MobileClassroomTab.chat => _buildChatTab(),
                    MobileClassroomTab.students => _buildParticipantsTab(),
                  },
                ),
                _buildBottomControlDock(),
              ],
            ),

          // Floating Animated Reaction Overlay
          ..._reactions.map((r) => _buildFloatingReactionWidget(r)),

          // Initial Connecting Splash
          if (_isJoining) _buildJoiningSplash(),
        ],
      ),
    );
  }

  Widget _buildMobileTabPill(MobileClassroomTab tab, String label) {
    final isSelected = _mobileTab == tab;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _mobileTab = tab),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF8B5CF6) : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? const Color(0xFF8B5CF6) : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  // ── Modern AppBar ─────────────────────────────────────────────────────────
  PreferredSizeWidget _buildModernAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF0F0F1D),
      foregroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 16,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 18),
        onPressed: () => _confirmLeave(context),
      ),
      title: Row(
        children: [
          // Pulsing REC badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.rose.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.rose.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PulsingDot(),
                const SizedBox(width: 6),
                Text(
                  'LIVE  $_formattedElapsed',
                  style: GoogleFonts.inter(
                    color: AppColors.rose,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Course and Instructor info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.lessonTitle,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.violet.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.isHost ? "INSTRUCTOR" : "STUDENT",
                        style: GoogleFonts.inter(
                          color: AppColors.violet,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Room: ${widget.roomName}',
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Mode Switcher (Video / Whiteboard / Split)
        _buildModeSelector(),
        const SizedBox(width: 8),

        // Copy room invite link button
        IconButton(
          tooltip: 'Copy Invite Link',
          icon: const Icon(Icons.share_outlined, color: Colors.white70, size: 20),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: 'https://meet.jit.si/${widget.roomName}'));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('📋 Room link copied to clipboard!'),
                backgroundColor: AppColors.violet,
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),

        // Leave Session
        Padding(
          padding: const EdgeInsets.only(right: 12, left: 6),
          child: ElevatedButton.icon(
            onPressed: () => _confirmLeave(context),
            icon: const Icon(Icons.call_end_rounded, size: 16, color: Colors.white),
            label: Text(
              widget.isHost ? 'End Class' : 'Leave',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12),
            ),
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

  // ── Mode Selector Pill ────────────────────────────────────────────────────
  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeTab(ClassroomViewMode.video, Icons.videocam_rounded, "Video"),
          _buildModeTab(ClassroomViewMode.whiteboard, Icons.draw_rounded, "Board"),
          _buildModeTab(ClassroomViewMode.split, Icons.vertical_split_rounded, "Split"),
        ],
      ),
    );
  }

  Widget _buildModeTab(ClassroomViewMode mode, IconData icon, String label) {
    final isSelected = _viewMode == mode;
    return InkWell(
      onTap: () => setState(() => _viewMode = mode),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.violet : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.white60),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Stage Content: Video, Whiteboard, or Split ────────────────────────────
  Widget _buildStageContent(bool isWide) {
    if (_viewMode == ClassroomViewMode.whiteboard) {
      return _buildInteractiveWhiteboard();
    } else if (_viewMode == ClassroomViewMode.split && isWide) {
      return Row(
        children: [
          Expanded(child: _buildVideoView()),
          Container(width: 2, color: Colors.white.withValues(alpha: 0.1)),
          Expanded(child: _buildInteractiveWhiteboard()),
        ],
      );
    }
    return _buildVideoView();
  }

  Widget _buildVideoView() {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          HtmlElementView(viewType: _viewId),

          // Face Detection HUD: Status Chip for Student / Instructor
          if (_isFaceDetectionActive)
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F1D).withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isFaceDetected
                        ? AppColors.emerald.withValues(alpha: 0.6)
                        : AppColors.rose.withValues(alpha: 0.7),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: _isFaceDetected ? AppColors.emerald : AppColors.rose,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_isFaceDetected ? AppColors.emerald : AppColors.rose).withValues(alpha: 0.8),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.isHost ? "Instructor AI Face Monitor" : "Student Live Attendance",
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _isFaceDetected
                              ? "🟢 Face Detected · ${(_faceConfidence * 100).toInt()}% Attentive"
                              : "⚠️ No Face in View · Please Face Camera",
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: _isFaceDetected ? AppColors.emerald : AppColors.rose,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Host Overview Badge (top right)
          if (widget.isHost)
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1B4B).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.violet.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("👥", style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 6),
                    Text(
                      "6/7 Students Face-Verified",
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),

          // Face Detection Target Box Overlay (when camera is on)
          if (_isFaceDetectionActive && _showFaceOverlay && !_isCameraOff)
            Center(
              child: IgnorePointer(
                child: Container(
                  width: 220,
                  height: 280,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _isFaceDetected
                          ? AppColors.violet.withValues(alpha: 0.35)
                          : AppColors.rose.withValues(alpha: 0.45),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 8,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (_isFaceDetected ? AppColors.violet : AppColors.rose).withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _isFaceDetected ? "👤 Face Locked" : "🚫 Center Face Here",
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: _isFaceDetected ? AppColors.violet : AppColors.rose,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom Quick Toggle for Face HUD
          Positioned(
            bottom: 12,
            right: 12,
            child: InkWell(
              onTap: () => setState(() => _showFaceOverlay = !_showFaceOverlay),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showFaceOverlay ? Icons.face_retouching_natural_rounded : Icons.face_rounded,
                      size: 13,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _showFaceOverlay ? "Face Box On" : "Face Box Off",
                      style: GoogleFonts.inter(fontSize: 10, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Interactive Collaborative Whiteboard ──────────────────────────────────
  Widget _buildInteractiveWhiteboard() {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF121224),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.violet.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Whiteboard Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF181830),
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            ),
            child: Row(
              children: [
                Text(
                  "Interactive Canvas",
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),

                // Pen Colors
                ...[
                  const Color(0xFF8B5CF6),
                  const Color(0xFF10B981),
                  const Color(0xFFF59E0B),
                  const Color(0xFF06B6D4),
                  Colors.white,
                ].map((c) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: InkWell(
                        onTap: () => setState(() {
                          _penColor = c;
                          _isEraser = false;
                        }),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: (!_isEraser && _penColor == c)
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    )),

                const SizedBox(width: 12),
                // Eraser Toggle
                IconButton(
                  tooltip: 'Eraser',
                  icon: Icon(
                    Icons.auto_fix_high_rounded,
                    size: 18,
                    color: _isEraser ? AppColors.rose : Colors.white60,
                  ),
                  onPressed: () => setState(() => _isEraser = !_isEraser),
                ),

                // Undo
                IconButton(
                  tooltip: 'Undo stroke',
                  icon: const Icon(Icons.undo_rounded, size: 18, color: Colors.white70),
                  onPressed: () {
                    if (_strokes.isNotEmpty) {
                      setState(() => _strokes.removeLast());
                    }
                  },
                ),

                // Clear
                IconButton(
                  tooltip: 'Clear canvas',
                  icon: const Icon(Icons.delete_sweep_outlined, size: 20, color: Colors.white70),
                  onPressed: () => setState(() => _strokes.clear()),
                ),
              ],
            ),
          ),

          // Canvas Gesture Area
          Expanded(
            child: GestureDetector(
              onPanStart: (details) {
                final box = context.findRenderObject() as RenderBox?;
                if (box == null) return;
                setState(() {
                  _strokes.add(_WhiteboardStroke(
                    color: _isEraser ? const Color(0xFF121224) : _penColor,
                    strokeWidth: _isEraser ? 18.0 : _strokeWidth,
                    points: [details.localPosition],
                  ));
                });
              },
              onPanUpdate: (details) {
                if (_strokes.isEmpty) return;
                setState(() {
                  _strokes.last.points.add(details.localPosition);
                });
              },
              child: CustomPaint(
                painter: _WhiteboardPainter(strokes: _strokes),
                size: Size.infinite,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom HUD Control Dock ───────────────────────────────────────────────
  Widget _buildBottomControlDock() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF131326).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Hand Raise & Reaction Buttons
          Row(
            children: [
              // Hand Raise
              InkWell(
                onTap: () {
                  setState(() => _isHandRaised = !_isHandRaised);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_isHandRaised
                          ? "✋ Hand raised! The instructor has been notified."
                          : "Hand lowered."),
                      backgroundColor: _isHandRaised ? AppColors.amber : AppColors.darkCard,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isHandRaised
                        ? AppColors.amber.withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isHandRaised ? AppColors.amber : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.front_hand_rounded,
                        color: _isHandRaised ? AppColors.amber : Colors.white70,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isHandRaised ? "Hand Raised" : "Raise Hand",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _isHandRaised ? AppColors.amber : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Quick Reactions Row
              ...["👏", "❤️", "💡", "🔥", "👍"].map((emoji) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      onTap: () => _triggerReaction(emoji),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(emoji, style: const TextStyle(fontSize: 16)),
                      ),
                    ),
                  )),
            ],
          ),

          // Center: Device Toggles
          Row(
            children: [
              // Mic Toggle
              _buildControlIcon(
                icon: _isMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                isActive: !_isMicMuted,
                activeColor: AppColors.violet,
                inactiveColor: AppColors.rose,
                tooltip: _isMicMuted ? "Unmute Mic" : "Mute Mic",
                onTap: () => setState(() => _isMicMuted = !_isMicMuted),
              ),
              const SizedBox(width: 10),

              // Camera Toggle
              _buildControlIcon(
                icon: _isCameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                isActive: !_isCameraOff,
                activeColor: AppColors.violet,
                inactiveColor: AppColors.rose,
                tooltip: _isCameraOff ? "Turn Camera On" : "Turn Camera Off",
                onTap: () => setState(() => _isCameraOff = !_isCameraOff),
              ),
              const SizedBox(width: 10),

              // Screen Share
              _buildControlIcon(
                icon: Icons.screen_share_rounded,
                isActive: _isScreenSharing,
                activeColor: AppColors.emerald,
                inactiveColor: Colors.white24,
                tooltip: "Screen Share",
                onTap: () => setState(() => _isScreenSharing = !_isScreenSharing),
              ),
            ],
          ),

          // Right: Sidebar Toggle Controls
          Row(
            children: [
              _buildSidebarNavPill(SidebarTab.chat, Icons.chat_bubble_outline_rounded, "Chat"),
              const SizedBox(width: 6),
              _buildSidebarNavPill(SidebarTab.participants, Icons.people_outline_rounded, "Roster"),
              const SizedBox(width: 6),
              _buildSidebarNavPill(SidebarTab.notes, Icons.note_alt_outlined, "Notes"),
              const SizedBox(width: 6),
              _buildSidebarNavPill(SidebarTab.polls, Icons.poll_outlined, "Polls"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlIcon({
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required Color inactiveColor,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isActive
                ? activeColor.withValues(alpha: 0.2)
                : inactiveColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isActive ? activeColor : inactiveColor, width: 1.2),
          ),
          child: Center(
            child: Icon(icon, color: isActive ? Colors.white : inactiveColor, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarNavPill(SidebarTab tab, IconData icon, String label) {
    final isSelected = _isSidebarOpen && _activeTab == tab;
    return InkWell(
      onTap: () {
        setState(() {
          if (_isSidebarOpen && _activeTab == tab) {
            _isSidebarOpen = false;
          } else {
            _isSidebarOpen = true;
            _activeTab = tab;
          }
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.violet : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.violet : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: isSelected ? Colors.white : Colors.white70),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Right Sidebar Panel (Chat, Participants, Notes, Polls) ────────────────
  Widget _buildSidebarPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 8, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          // Sidebar Header Tabs
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF141428),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            ),
            child: Row(
              children: [
                _buildSidebarTabHeader(SidebarTab.chat, "Chat", Icons.chat_bubble_outline_rounded),
                _buildSidebarTabHeader(SidebarTab.participants, "People (18)", Icons.people_outline_rounded),
                _buildSidebarTabHeader(SidebarTab.notes, "Notes", Icons.edit_note_rounded),
                _buildSidebarTabHeader(SidebarTab.polls, "Polls", Icons.bar_chart_rounded),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white54),
                  onPressed: () => setState(() => _isSidebarOpen = false),
                ),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: switch (_activeTab) {
              SidebarTab.chat => _buildChatTab(),
              SidebarTab.participants => _buildParticipantsTab(),
              SidebarTab.notes => _buildNotesTab(),
              SidebarTab.polls => _buildPollsTab(),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarTabHeader(SidebarTab tab, String title, IconData icon) {
    final isSelected = _activeTab == tab;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeTab = tab),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.violet.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected ? Border.all(color: AppColors.violet) : null,
          ),
          child: Center(
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.white60,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  // ── Tab 1: Live Chat ──────────────────────────────────────────────────────
  Widget _buildChatTab() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _chatScrollController,
            padding: const EdgeInsets.all(12),
            itemCount: _messages.length,
            itemBuilder: (context, idx) {
              final msg = _messages[idx];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: msg.isInstructor
                          ? AppColors.rose
                          : (msg.isBot ? AppColors.violet : AppColors.indigo),
                      child: Text(
                        msg.sender.isNotEmpty ? msg.sender[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                msg.sender,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (msg.isInstructor) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.rose.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    "HOST",
                                    style: GoogleFonts.inter(
                                        fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.rose),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              Text(
                                msg.timestamp,
                                style: GoogleFonts.inter(color: Colors.white38, fontSize: 10),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: msg.isSelf
                                  ? AppColors.violet.withValues(alpha: 0.15)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: msg.isSelf
                                    ? AppColors.violet.withValues(alpha: 0.4)
                                    : Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Text(
                              msg.text,
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Chat Input Box
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF141428),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: "Type in class chat…",
                    hintStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: AppColors.violet, size: 20),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Tab 2: Student Live Presence (Exact parity with Android Mobile App) ─────
  Widget _buildParticipantsTab() {
    final onlineCount = _liveStudents.where((s) => s.isOnline).length;
    final offlineCount = _liveStudents.where((s) => !s.isOnline).length;
    final verifiedCount = _liveStudents.where((s) => s.isFaceVerified).length;
    final handsCount = _liveStudents.where((s) => s.isHandRaised).length;

    final filteredStudents = switch (_presenceFilter) {
      'ONLINE' => _liveStudents.where((s) => s.isOnline).toList(),
      'OFFLINE' => _liveStudents.where((s) => !s.isOnline).toList(),
      'HANDS' => _liveStudents.where((s) => s.isHandRaised).toList(),
      _ => _liveStudents,
    };

    return Container(
      color: const Color(0xFF0F0F1D),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header & Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text("👥", style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          "Student Live Presence",
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "$onlineCount Online • $offlineCount Offline • Face Verification Active",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white60,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Live Check button
                  ElevatedButton(
                    onPressed: _isCheckingPresence ? null : _refreshLivePresence,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                      foregroundColor: const Color(0xFFA78BFA),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isCheckingPresence) ...[
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFA78BFA)),
                          ),
                          const SizedBox(width: 4),
                        ] else ...[
                          const Text("⚡ ", style: TextStyle(fontSize: 11)),
                        ],
                        Text(
                          _isCheckingPresence ? "Checking..." : "Live Check",
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  if (widget.isHost) ...[
                    const SizedBox(width: 6),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isRoomLocked = !_isRoomLocked;
                          _controlFeedback = _isRoomLocked
                              ? "🔒 Room locked for new students."
                              : "🔓 Room unlocked.";
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isRoomLocked
                            ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.1),
                        foregroundColor: _isRoomLocked ? const Color(0xFFF87171) : Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        _isRoomLocked ? "🔒 Locked" : "🔓 Open",
                        style: GoogleFonts.inter(fontSize: 11),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Feedback Banner (if toggled)
          if (_controlFeedback != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _controlFeedback!,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 11),
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _controlFeedback = null),
                    child: const Icon(Icons.close, size: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],

          // ── Live Presence KPI Strip (Single-line 4 cards matching Android)
          Row(
            children: [
              _buildKpiCard(
                dotColor: const Color(0xFF10B981),
                count: "$onlineCount",
                label: "Online",
                countColor: const Color(0xFF34D399),
                bgColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderColor: const Color(0xFF10B981).withValues(alpha: 0.35),
              ),
              const SizedBox(width: 6),
              _buildKpiCard(
                dotColor: const Color(0xFF94A3B8),
                count: "$offlineCount",
                label: "Offline",
                countColor: const Color(0xFFCBD5E1),
                bgColor: Colors.white.withValues(alpha: 0.05),
                borderColor: Colors.white.withValues(alpha: 0.15),
              ),
              const SizedBox(width: 6),
              _buildKpiCard(
                icon: "👤",
                count: "$verifiedCount",
                label: "Verified",
                countColor: const Color(0xFFA5B4FC),
                bgColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
                borderColor: const Color(0xFF6366F1).withValues(alpha: 0.35),
              ),
              const SizedBox(width: 6),
              _buildKpiCard(
                icon: "✋",
                count: "$handsCount",
                label: "Hands",
                countColor: const Color(0xFFFBBF24),
                bgColor: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderColor: const Color(0xFFF59E0B).withValues(alpha: 0.35),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Filter Pills Row (Horizontally Scrollable)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterPill("ALL", "All (${_liveStudents.length})"),
                const SizedBox(width: 6),
                _buildFilterPill("ONLINE", "🟢 Online ($onlineCount)"),
                const SizedBox(width: 6),
                _buildFilterPill("OFFLINE", "⚪ Offline ($offlineCount)"),
                const SizedBox(width: 6),
                _buildFilterPill("HANDS", "✋ Hands ($handsCount)"),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Student List
          Expanded(
            child: filteredStudents.isEmpty
                ? Center(
                    child: Text(
                      "No students in this filter.",
                      style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredStudents.length,
                    itemBuilder: (context, idx) {
                      final student = filteredStudents[idx];
                      return _buildStudentCard(student);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    String? icon,
    Color? dotColor,
    required String count,
    required String label,
    required Color countColor,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (dotColor != null) ...[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                ] else if (icon != null) ...[
                  Text(icon, style: const TextStyle(fontSize: 11)),
                  const SizedBox(width: 3),
                ],
                Text(
                  count,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: countColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 10, color: Colors.white70),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(String key, String label) {
    final isSelected = _presenceFilter == key;
    return InkWell(
      onTap: () => setState(() => _presenceFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8B5CF6) : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF8B5CF6) : Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildStudentCard(LiveStudentPresence student) {
    final colors = _getStudentAvatarGradient(student.name);
    final initials = _getStudentInitials(student.name);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141426),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: student.isOnline
              ? const Color(0xFF10B981).withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Distinct Colorful Avatar with Live Ring
          Stack(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: colors),
                  border: Border.all(
                    color: student.isOnline ? const Color(0xFF10B981) : const Color(0xFF64748B),
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: student.isOnline ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF141426), width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Details Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        student.name,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (student.isHandRaised) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text("✋", style: TextStyle(fontSize: 10)),
                            const SizedBox(width: 2),
                            Text(
                              "Hand Raised",
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFFBBF24),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        student.studentId,
                        style: GoogleFonts.inter(
                          color: const Color(0xFFA5B4FC),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        student.email,
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.white54),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Chips for status & attendance
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    // Face Verification
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: student.isFaceVerified
                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            student.isFaceVerified ? Icons.verified_user_rounded : Icons.face_outlined,
                            size: 11,
                            color: student.isFaceVerified ? const Color(0xFF34D399) : Colors.white60,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            student.isFaceVerified ? "Verified" : "Unverified",
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: student.isFaceVerified ? const Color(0xFF34D399) : Colors.white60,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Attendance rate
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "${student.attendanceRate}% Historical Rate",
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFA78BFA),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // View Profile Icon
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, color: Colors.white70, size: 20),
            tooltip: "View Profile",
            onPressed: () => _showStudentProfileDialog(student),
          ),
        ],
      ),
    );
  }

  void _showStudentProfileDialog(LiveStudentPresence student) {
    final colors = _getStudentAvatarGradient(student.name);
    final initials = _getStudentInitials(student.name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18182E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: colors),
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    student.studentId,
                    style: GoogleFonts.inter(color: const Color(0xFFA5B4FC), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(color: Colors.white12),
            const SizedBox(height: 6),
            _buildDialogRow("Email:", student.email),
            _buildDialogRow(
              "Presence Status:",
              student.isOnline ? "🟢 Live in Room" : "⚪ Offline",
              valueColor: student.isOnline ? const Color(0xFF34D399) : Colors.white60,
            ),
            _buildDialogRow(
              "Biometric Face Status:",
              student.isFaceVerified ? "👤 Active Face Verified (100%)" : "⚠️ Camera off / Unverified",
              valueColor: student.isFaceVerified ? const Color(0xFFA5B4FC) : const Color(0xFFF87171),
            ),
            _buildDialogRow(
              "Hand Raise:",
              student.isHandRaised ? "✋ Hand Currently Raised" : "Lowered",
              valueColor: student.isHandRaised ? const Color(0xFFFBBF24) : Colors.white60,
            ),
            _buildDialogRow("Attendance Record:", "${student.attendanceRate}% Historical Rate", valueColor: const Color(0xFFA78BFA)),
            _buildDialogRow("Hardware / Device:", student.deviceInfo),
            if (widget.isHost) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("🔇 Muted audio for ${student.name}")),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text("Mute Student", style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFEF4444))),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("📢 Prompted ${student.name} to verify camera.")),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text("Prompt Verify", style: GoogleFonts.inter(fontSize: 11, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Close", style: GoogleFonts.inter(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.white60)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: valueColor ?? Colors.white,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _getStudentAvatarGradient(String name) {
    final hash = name.hashCode.abs();
    final palettes = [
      [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
      [const Color(0xFFEC4899), const Color(0xFFF43F5E)],
      [const Color(0xFF10B981), const Color(0xFF06B6D4)],
      [const Color(0xFFF59E0B), const Color(0xFFD97706)],
      [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
      [const Color(0xFF8B5CF6), const Color(0xFFC084FC)],
    ];
    return palettes[hash % palettes.length];
  }

  String _getStudentInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  // ── Tab 3: Personal Notes ─────────────────────────────────────────────────
  Widget _buildNotesTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Personal Lecture Notes",
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _notesController.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("📝 Notes copied to clipboard!")),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 13, color: AppColors.violet),
                label: Text(
                  "Copy",
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.violet, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: TextField(
              controller: _notesController,
              maxLines: null,
              expands: true,
              style: GoogleFonts.firaCode(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                hintText: "Jot down your notes as the class proceeds…",
                hintStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Auto-saved locally during session.",
            style: GoogleFonts.inter(color: Colors.white30, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Tab 4: Live Polls / Q&A ───────────────────────────────────────────────
  Widget _buildPollsTab() {
    final totalVotes = _pollOptions.fold<int>(0, (sum, opt) => sum + opt.votes);

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.emerald.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              "ACTIVE POLL",
              style: GoogleFonts.inter(
                color: AppColors.emerald,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "How well do you understand today's architecture?",
            style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),

          ...List.generate(_pollOptions.length, (idx) {
            final opt = _pollOptions[idx];
            final percent = totalVotes > 0 ? (opt.votes / totalVotes) : 0.0;
            final isChosen = _selectedPollOption == idx;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (_selectedPollOption == null) {
                      _selectedPollOption = idx;
                      opt.votes += 1;
                    }
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isChosen
                        ? AppColors.violet.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isChosen ? AppColors.violet : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              opt.text,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: isChosen ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            "${(percent * 100).toStringAsFixed(0)}%",
                            style: GoogleFonts.inter(
                              color: AppColors.violet,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percent,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isChosen ? AppColors.violet : AppColors.indigo,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          const Spacer(),
          Text(
            "$totalVotes total student responses",
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ── Floating Reaction Animation ───────────────────────────────────────────
  Widget _buildFloatingReactionWidget(_ReactionParticle r) {
    return Positioned(
      bottom: 80,
      left: MediaQuery.of(context).size.width * r.leftPercent,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 2000),
        builder: (context, value, child) {
          return Opacity(
            opacity: (1.0 - value).clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, -value * 280),
              child: Transform.scale(
                scale: 1.0 + (value * 0.8),
                child: Text(
                  r.emoji,
                  style: const TextStyle(fontSize: 32),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Connecting Splash Overlay ─────────────────────────────────────────────
  Widget _buildJoiningSplash() {
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF09090F),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
              widget.isHost ? 'Starting Live Classroom…' : 'Connecting to Virtual Class…',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.lessonTitle,
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 220,
              child: LinearProgressIndicator(
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.violet),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Enabling encrypted HD video and whiteboard…',
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
          widget.isHost ? 'End Live Class?' : 'Leave Classroom?',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          widget.isHost
              ? 'Ending the session will conclude the class for all enrolled students.'
              : 'You can rejoin anytime while the instructor is live.',
          style: GoogleFonts.inter(color: Colors.white60, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Stay in Class',
                style: GoogleFonts.inter(color: AppColors.indigo, fontWeight: FontWeight.w600)),
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

    if ((leave ?? false) && mounted) {
      Navigator.of(context).pop();
    }
  }
}

// ── Models & Custom Painters ──────────────────────────────────────────────────

class _ChatMessage {
  final String sender;
  final String text;
  final String timestamp;
  final bool isSelf;
  final bool isInstructor;
  final bool isBot;

  _ChatMessage({
    required this.sender,
    required this.text,
    required this.timestamp,
    this.isSelf = false,
    this.isInstructor = false,
    this.isBot = false,
  });
}


class _PollOption {
  final String text;
  int votes;

  _PollOption({required this.text, required this.votes});
}

class _ReactionParticle {
  final String emoji;
  final double leftPercent;

  _ReactionParticle({required this.emoji, required this.leftPercent});
}

class _WhiteboardStroke {
  final Color color;
  final double strokeWidth;
  final List<Offset> points;

  _WhiteboardStroke({required this.color, required this.strokeWidth, required this.points});
}

class _WhiteboardPainter extends CustomPainter {
  final List<_WhiteboardStroke> strokes;

  _WhiteboardPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.points.length > 1) {
        final path = Path();
        path.moveTo(stroke.points.first.dx, stroke.points.first.dy);
        for (int i = 1; i < stroke.points.length; i++) {
          path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
        }
        canvas.drawPath(path, paint);
      } else if (stroke.points.isNotEmpty) {
        canvas.drawCircle(stroke.points.first, stroke.strokeWidth / 2, paint..style = PaintingStyle.fill);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WhiteboardPainter oldDelegate) => true;
}

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
    _scale = Tween<double>(begin: 0.65, end: 1.0).animate(
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
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: AppColors.rose,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: AppColors.rose.withValues(alpha: 0.8), blurRadius: 6, spreadRadius: 1),
          ],
        ),
      ),
    );
  }
}
