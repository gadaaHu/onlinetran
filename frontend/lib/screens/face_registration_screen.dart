import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/api_client.dart';
import '../core/providers.dart';
import '../core/platform/face_proctoring.dart';
import '../core/theme.dart';

/// Shown immediately after a student enrolls in a course.
/// Captures a baseline face photo and saves it to the student's profile.
/// If the student already has a profile picture, shows confirmation and exits.
class FaceRegistrationScreen extends ConsumerStatefulWidget {
  const FaceRegistrationScreen({super.key});

  @override
  ConsumerState<FaceRegistrationScreen> createState() =>
      _FaceRegistrationScreenState();
}

class _FaceRegistrationScreenState
    extends ConsumerState<FaceRegistrationScreen>
    with SingleTickerProviderStateMixin {
  final FaceProctoringPlatform _proctoringPlatform = getFaceProctoringPlatform();

  final String _viewId =
      'face-reg-video-${DateTime.now().millisecondsSinceEpoch}';

  bool _isCameraReady = false;
  bool _cameraError = false;
  String _status = 'Initializing camera…';
  bool _isCapturing = false;
  bool _isDone = false;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.04)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _initCamera();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _proctoringPlatform.disposeCamera();
    super.dispose();
  }

  Future<void> _initCamera() async {
    final modelsLoaded = await _proctoringPlatform.initFaceDetector();
    if (!modelsLoaded && mounted) {
      setState(() {
        _status = 'AI models failed to load. Please refresh.';
        _cameraError = true;
      });
      return;
    }

    try {
      final success = await _proctoringPlatform.initCamera(_viewId);
      if (success) {
        if (mounted) {
          setState(() {
            _isCameraReady = true;
            _status = 'Camera ready! Look straight at the camera and click Capture.';
          });
        }
      } else {
        throw Exception('Failed to initialize camera stream.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cameraError = true;
          _status = 'Camera access denied. Allow camera in your browser.';
        });
      }
    }
  }

  Future<void> _capture() async {
    setState(() {
      _isCapturing = true;
      _status = 'Capturing your face…';
    });

    try {
      final base64Image = await _proctoringPlatform.takeSnapshot(_viewId);
      if (base64Image == null) {
        throw Exception('Could not capture frame. Make sure your face is visible.');
      }

      final res = await ApiClient.dio.post('/auth/profile-picture', data: {
        'base64Image': base64Image,
      });

      if (res.statusCode == 200 && res.data['profilePictureUrl'] != null) {
        ref
            .read(authProvider.notifier)
            .updateProfilePicture(res.data['profilePictureUrl']);
        _proctoringPlatform.disposeCamera();
        if (mounted) {
          setState(() {
            _isDone = true;
            _status = 'Face registered successfully!';
          });
        }
      } else {
        throw Exception('Upload failed. Please try again.');
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;

    // Already has a face photo — show confirmation
    if (user != null &&
        user.profilePictureUrl != null &&
        user.profilePictureUrl!.isNotEmpty &&
        !_isDone) {
      return _buildAlreadyRegistered(context, colorScheme, bg, user.profilePictureUrl!);
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _isDone
            ? const SizedBox()
            : IconButton(
                icon: Icon(Icons.close_rounded, color: colorScheme.onSurface),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Skip for now',
              ),
        title: Text(
          'Face Registration',
          style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: colorScheme.onSurface),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: _isDone
              ? _buildSuccessView(context, colorScheme)
              : _buildCameraView(context, colorScheme),
        ),
      ),
    );
  }

  Widget _buildCameraView(BuildContext context, ColorScheme colorScheme) {
    return Column(
      children: [
        // Banner
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const Icon(Icons.face_retouching_natural_rounded,
                  size: 44, color: Colors.white),
              const SizedBox(height: 10),
              Text('One-Time Face Setup',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                'Your face will be saved securely and used to verify your identity before every exam. Do this once and you\'re set!',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                    height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Tips row
        Row(
          children: [
            _tip(Icons.light_mode_rounded, 'Good lighting', colorScheme),
            const SizedBox(width: 8),
            _tip(Icons.face_rounded, 'Look straight', colorScheme),
            const SizedBox(width: 8),
            _tip(Icons.do_not_disturb_on_rounded, 'No accessories', colorScheme),
          ],
        ),
        const SizedBox(height: 20),

        // Camera box
        ScaleTransition(
          scale: (_isCameraReady && !_cameraError)
              ? _pulse
              : const AlwaysStoppedAnimation(1.0),
          child: Container(
            height: 300,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _cameraError
                    ? Colors.red
                    : _isCameraReady
                        ? AppColors.indigo
                        : Colors.grey.shade700,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.indigo.withValues(alpha: 0.2),
                  blurRadius: 20,
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: _cameraError
                  ? _buildErrorWidget()
                  : _isCameraReady
                      ? HtmlElementView(viewType: _viewId)
                      : _buildLoadingWidget(),
            ),
          ),
        ),

        const SizedBox(height: 14),
        // Status
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: (_cameraError ? Colors.red : AppColors.indigo)
                .withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _cameraError
                    ? Icons.error_outline_rounded
                    : Icons.info_outline_rounded,
                size: 15,
                color: _cameraError ? Colors.red : AppColors.indigo,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _cameraError ? Colors.red : AppColors.indigo,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed:
                (_isCameraReady && !_isCapturing && !_cameraError)
                    ? _capture
                    : null,
            icon: _isCapturing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.camera_alt_rounded),
            label: Text(
              _isCapturing ? 'Saving…' : 'Capture & Register Face',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 4,
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Skip for now (you\'ll be asked before the exam)',
            style: GoogleFonts.inter(
                color: colorScheme.onSurface.withValues(alpha: 0.45),
                fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView(BuildContext context, ColorScheme colorScheme) {
    return Column(
      children: [
        const SizedBox(height: 50),
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: AppColors.indigo.withValues(alpha: 0.35),
                  blurRadius: 32,
                  spreadRadius: 4)
            ],
          ),
          child:
              const Icon(Icons.verified_user_rounded, size: 64, color: Colors.white),
        ),
        const SizedBox(height: 32),
        Text('You\'re All Set! 🎉',
            style: GoogleFonts.inter(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface)),
        const SizedBox(height: 12),
        Text(
          'Your face has been securely saved.\nThe system will recognize you automatically when you start any exam — no extra steps needed.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
              fontSize: 14,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
              height: 1.6),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text('Continue to Course',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlreadyRegistered(BuildContext context, ColorScheme colorScheme,
      Color bg, String picUrl) {
    final fullUrl =
        '${ApiClient.dio.options.baseUrl.replaceAll('/api', '')}/profiles/$picUrl';
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Face ID',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipOval(
                child: Image.network(fullUrl,
                    width: 160, height: 160, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        width: 160, height: 160,
                        color: AppColors.indigo.withValues(alpha: 0.1),
                        child: const Icon(Icons.face_rounded,
                            size: 80, color: AppColors.indigo))),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded, color: Colors.green, size: 18),
                    const SizedBox(width: 6),
                    Text('Face ID already registered',
                        style: GoogleFonts.inter(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text('Your face is already saved.\nYou\'re ready to take exams!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                      height: 1.6)),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check_circle_rounded),
                  label: Text('Continue',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tip(IconData icon, String label, ColorScheme colorScheme) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: AppColors.indigo.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: AppColors.indigo.withValues(alpha: 0.15)),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.indigo, size: 20),
              const SizedBox(height: 5),
              Text(label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface)),
            ],
          ),
        ),
      );

  Widget _buildLoadingWidget() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const CircularProgressIndicator(color: AppColors.indigo),
          const SizedBox(height: 14),
          Text('Starting camera…',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
        ]),
      );

  Widget _buildErrorWidget() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.videocam_off_rounded, color: Colors.red, size: 44),
          const SizedBox(height: 10),
          Text('Camera blocked',
              style: GoogleFonts.inter(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Allow camera access in your browser',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _cameraError = false;
                _isCameraReady = false;
                _status = 'Retrying…';
              });
              _initCamera();
            },
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            label: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ]),
      );
}
