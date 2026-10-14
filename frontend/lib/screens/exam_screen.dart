import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:async';
import '../core/providers.dart';
import '../core/models.dart';
import '../core/api_client.dart';
import '../core/platform/face_proctoring.dart';
import '../core/face_api_interop.dart' as face_api;

class ExamScreen extends ConsumerStatefulWidget {
  final int courseId;
  final String quizTitle;

  const ExamScreen({
    super.key,
    required this.courseId,
    required this.quizTitle,
  });

  @override
  ConsumerState<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends ConsumerState<ExamScreen> {
  QuizResultModel? _result;
  bool _isSubmitting = false;
  final Map<int, int> _selectedAnswers = {};
  
  // Proctoring state
  final FaceProctoringPlatform _proctoringPlatform = getFaceProctoringPlatform();
  Timer? _proctoringTimer;
  String _proctoringMessage = "Initializing camera...";
  Color _proctoringColor = Colors.orange;
  bool _isCameraReady = false;
  bool _cameraError = false;
  // Use a unique viewId per instance so registerViewFactory never conflicts
  final String _viewId = 'webcam-video-${DateTime.now().millisecondsSinceEpoch}';

  // Identity Verification
  bool _isIdentityVerified = false;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _initProctoring();
    Future.microtask(() {
      ref.read(studentQuizProvider.notifier).fetchQuiz(widget.courseId);
    });
  }

  Future<void> _initProctoring() async {
    final modelsLoaded = await _proctoringPlatform.initFaceDetector();
    if (!modelsLoaded) {
      if (mounted) {
        setState(() {
        _proctoringMessage = "Failed to load AI models";
        _proctoringColor = Colors.red;
        _cameraError = true;
      });
      }
      return;
    }

    try {
      final success = await _proctoringPlatform.initCamera(_viewId);
      if (success) {
        if (mounted) {
          setState(() {
            _isCameraReady = true;
            _proctoringMessage = "Monitoring Active";
            _proctoringColor = Colors.green;
          });
        }
      } else {
        throw Exception("Failed to initialize camera stream");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _proctoringMessage = "Camera error: $e";
          _proctoringColor = Colors.red;
          _cameraError = true;
        });
      }
    }
  }

  Future<void> _retryCameraInit() async {
    setState(() {
      _isCameraReady = false;
      _cameraError = false;
      _proctoringMessage = "Retrying camera...";
    });
    await _initProctoring();
  }

  void _startProctoringLoop() {
    _proctoringTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
       if (_result != null || _isSubmitting) {
         timer.cancel();
         return;
       }
       final count = await face_api.detectFaces(_viewId);
       if (mounted) {
          if (count == 0) {
             setState(() { _proctoringMessage = "Warning: No face detected!"; _proctoringColor = Colors.red; });
          } else if (count > 1) {
             setState(() { _proctoringMessage = "Warning: Multiple faces detected!"; _proctoringColor = Colors.red; });
          } else if (count == 1) {
             setState(() { _proctoringMessage = "Monitoring Active"; _proctoringColor = Colors.green; });
          }
       }
    });
  }

  Future<void> _setupBaselineProfilePicture() async {
    setState(() => _isVerifying = true);
    try {
      final base64Image = await _proctoringPlatform.takeSnapshot(_viewId);
      if (base64Image == null) {
        throw Exception("Could not capture webcam frame.");
      }

      final res = await ApiClient.dio.post('/auth/profile-picture', data: {
        'base64Image': base64Image
      });

      if (res.statusCode == 200 && res.data['profilePictureUrl'] != null) {
        ref.read(authProvider.notifier).updateProfilePicture(res.data['profilePictureUrl']);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Baseline photo saved successfully.')));
      } else {
        throw Exception("Failed to upload baseline photo.");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving photo: $e')));
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  Future<void> _verifyIdentity(String profilePicUrl) async {
    setState(() => _isVerifying = true);
    try {
      // Build full URL for profile pic since it's just the filename in DB
      final fullUrl = '${ApiClient.dio.options.baseUrl.replaceAll('/api', '')}/profiles/$profilePicUrl';
      
      final isMatch = await _proctoringPlatform.matchFace(_viewId, fullUrl);
      
      if (isMatch) {
        setState(() => _isIdentityVerified = true);
        _startProctoringLoop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Identity verified. Exam unlocked.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Identity verification failed. Faces do not match!')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error verifying identity: $e')));
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  @override
  void dispose() {
    _proctoringTimer?.cancel();
    _proctoringPlatform.disposeCamera();
    super.dispose();
  }

  void _selectAnswer(int questionId, int optionId) {
    setState(() {
      _selectedAnswers[questionId] = optionId;
    });
  }

  Future<void> _submitExam(StudentQuizModel quiz) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit Exam?'),
        content: const Text('Are you sure you want to submit your answers?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isSubmitting = true);
      final result = await ref.read(studentQuizProvider.notifier).submitQuiz(
            widget.courseId,
            quiz.id,
            _selectedAnswers,
          );
      setState(() {
        _isSubmitting = false;
        _result = result;
      });

      if (result == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit exam.')),
        );
      }
    }
  }

  Widget _buildVerificationView(BuildContext context, ColorScheme colorScheme, AuthState authState) {
    final user = authState.user;
    if (user == null) return const Center(child: Text("User not logged in"));

    final hasProfilePic = user.profilePictureUrl != null && user.profilePictureUrl!.isNotEmpty;

    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.face_retouching_natural, size: 80, color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              hasProfilePic ? 'Verify Your Identity' : 'Setup Face ID Baseline',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              hasProfilePic
                  ? 'Please look at the camera to verify your identity before starting the exam. The exam requires continuous webcam monitoring.'
                  : 'You do not have a baseline profile picture. Please look at the camera and take a clear photo of your face to serve as your baseline for future exams.',
              style: TextStyle(fontSize: 14, color: colorScheme.onSurface.withValues(alpha: 0.7)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              height: 250,
              width: 300,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _cameraError ? Colors.red : colorScheme.primary,
                  width: 2,
                ),
              ),
              child: _cameraError
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.videocam_off, color: Colors.white70, size: 48),
                        const SizedBox(height: 12),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'Camera blocked.\nAllow camera access in browser\nthen click Retry.',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _retryCameraInit,
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          label: const Text('Retry', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    )
                  : _isCameraReady
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: HtmlElementView(viewType: _viewId),
                        )
                      : const Center(child: CircularProgressIndicator()),
            ),
            const SizedBox(height: 32),
            if (_isVerifying)
              const CircularProgressIndicator()
            else if (hasProfilePic)
              ElevatedButton.icon(
                onPressed: _isCameraReady ? () => _verifyIdentity(user.profilePictureUrl!) : null,
                icon: const Icon(Icons.verified_user),
                label: const Text('Verify Face & Start Exam'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _isCameraReady ? _setupBaselineProfilePicture : null,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Baseline Photo'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quizState = ref.watch(studentQuizProvider);
    final authState = ref.watch(authProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quizTitle),
        actions: [
          if (quizState.value != null && !_isSubmitting && _result == null && _isIdentityVerified)
            TextButton(
              onPressed: () => _submitExam(quizState.value!),
              child: Text(
                'Submit',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: _isSubmitting
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Grading exam...'),
                ],
              ),
            )
          : (!_isIdentityVerified) 
              ? _buildVerificationView(context, colorScheme, authState)
              : quizState.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text('Failed to load exam: $e',
                        style: const TextStyle(color: Colors.red)),
                  ),
                  data: (quiz) {
                    if (quiz == null) {
                      return const Center(child: Text('No exam available.'));
                    }
                    
                    // Show result view if submitted successfully
                    if (_result != null) {
                      return _buildResultView(context, colorScheme, quiz);
                    }
                    
                    if (quiz.questions.isEmpty) {
                      return const Center(child: Text('This exam has no questions yet.'));
                    }

                    return Stack(
                      children: [
                        ListView.builder(
                          padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 100),
                          itemCount: quiz.questions.length,
                          itemBuilder: (context, index) {
                            final q = quiz.questions[index];
                            return _QuestionCard(
                              question: q,
                              questionIndex: index,
                              selectedOptionId: _selectedAnswers[q.id],
                              onSelect: (optionId) => _selectAnswer(q.id, optionId),
                            );
                          },
                        ),
                        // Proctoring UI Overlay
                        Positioned(
                          bottom: 24,
                          right: 24,
                          child: Container(
                            width: 200,
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(color: _proctoringColor, width: 2),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  height: 150,
                                  width: double.infinity,
                                  decoration: const BoxDecoration(
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                                    color: Colors.black,
                                  ),
                                  child: _isCameraReady
                                      ? ClipRRect(
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                                          child: _proctoringPlatform.buildVideoView(_viewId),
                                        )
                                      : const Center(child: Icon(Icons.videocam_off, color: Colors.white, size: 40)),
                                ),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: _proctoringColor.withValues(alpha: 0.1),
                                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _proctoringColor == Colors.green ? Icons.security : Icons.warning_amber,
                                        color: _proctoringColor,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _proctoringMessage,
                                          style: TextStyle(
                                            color: _proctoringColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }

  Widget _buildResultView(BuildContext context, ColorScheme colorScheme, StudentQuizModel quiz) {
    final passed = _result!.passed;
    final color = passed ? const Color(0xFF43B97F) : Colors.red;
    final icon = passed ? Icons.emoji_events : Icons.cancel;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 100, color: color),
            const SizedBox(height: 24),
            Text(
              passed ? 'Congratulations!' : 'Better luck next time',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your Score: ${_result!.score}%',
              style: TextStyle(
                fontSize: 24,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Passing Score: ${quiz.passingScore}%',
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  // Pop back to course screen
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                ),
                child: Text(
                  'Return to Course',
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final StudentQuestionModel question;
  final int questionIndex;
  final int? selectedOptionId;
  final void Function(int) onSelect;

  const _QuestionCard({
    required this.question,
    required this.questionIndex,
    required this.selectedOptionId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question ${questionIndex + 1}',
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              question.questionText,
              style: TextStyle(
                fontSize: 18,
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            ...question.options.map((option) {
              final isSelected = option.id == selectedOptionId;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: InkWell(
                  onTap: () => onSelect(option.id),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primary.withValues(alpha: 0.15)
                          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? colorScheme.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            option.optionText,
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
