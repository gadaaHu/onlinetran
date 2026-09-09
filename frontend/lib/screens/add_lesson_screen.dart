import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../core/providers.dart';
import '../core/api_client.dart';
import '../core/theme.dart';
import 'dart:typed_data';

class AddLessonScreen extends ConsumerStatefulWidget {
  final int courseId;
  final int nextOrder;
  const AddLessonScreen({super.key, required this.courseId, required this.nextOrder});

  @override
  ConsumerState<AddLessonScreen> createState() => _AddLessonScreenState();
}

class _AddLessonScreenState extends ConsumerState<AddLessonScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _videoUrlCtrl = TextEditingController();
  // Auto-generated room name for the built-in Jitsi classroom.
  String? _generatedRoomName;
  late TextEditingController _orderCtrl;
  final _durationCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isLive = false;
  bool _isUploadingResource = false;
  String _statusMessage = '';

  /// Generates a unique Jitsi room name tied to the course and timestamp.
  String _generateRoomName() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return 'lms-c${widget.courseId}-$ts';
  }

  // Resource file
  Uint8List? _resourceBytes;
  String? _resourceFileName;

  @override
  void initState() {
    super.initState();
    _orderCtrl = TextEditingController(text: widget.nextOrder.toString());
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _videoUrlCtrl.dispose();
    _orderCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickResource() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'mp4', 'mkv', 'avi', 'zip', 'png', 'jpg'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _resourceBytes = result.files.single.bytes;
        _resourceFileName = result.files.single.name;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _statusMessage = 'Saving lesson...'; });

    final errorMsg = await ref.read(coursesProvider.notifier).addLesson(
          widget.courseId,
          _titleCtrl.text.trim(),
          _isLive ? null : _videoUrlCtrl.text.trim(),
          int.tryParse(_orderCtrl.text.trim()) ?? widget.nextOrder,
          int.tryParse(_durationCtrl.text.trim()) ?? 0,
          _isLive,
          _isLive ? (_generatedRoomName ?? _generateRoomName()) : null,
        );

    if (errorMsg != null) {
      setState(() { _isLoading = false; _statusMessage = ''; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add lesson: $errorMsg')),
        );
      }
      return;
    }

    // If we have a resource file, upload it to the newly created lesson
    if (_resourceBytes != null && _resourceFileName != null) {
      setState(() { _isLoading = false; _isUploadingResource = true; _statusMessage = 'Uploading resource...'; });

      try {
        // Get the course to find the last added lesson ID
        final res = await ApiClient.dio.get('/courses/${widget.courseId}');
        final lessons = res.data['lessons'] as List;
        if (lessons.isNotEmpty) {
          final lastLesson = lessons.last;
          final lessonId = lastLesson['id'] as int;

          final formData = FormData.fromMap({
            'file': MultipartFile.fromBytes(
              _resourceBytes!,
              filename: _resourceFileName!,
            ),
          });

          await ApiClient.dio.post(
            '/courses/${widget.courseId}/lessons/$lessonId/upload-resource',
            data: formData,
            options: Options(contentType: 'multipart/form-data'),
          );
        }
      } catch (e) {
        // Resource upload failed but lesson was created — notify user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lesson created but resource upload failed.')),
          );
        }
      }
      setState(() { _isUploadingResource = false; _statusMessage = ''; });
    } else {
      setState(() { _isLoading = false; _statusMessage = ''; });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lesson added successfully!')),
      );
      Navigator.pop(context);
    }
  }

  InputDecoration _inputDecoration(String label, {String? hint, Widget? suffixIcon}) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 13),
      labelStyle: GoogleFonts.inter(color: colorScheme.onSurface.withValues(alpha: 0.7)),
      filled: true,
      fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.indigo, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBusy = _isLoading || _isUploadingResource;

    return Scaffold(
      appBar: AppBar(
        title: Text('Add New Lesson',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Title ──
                  TextFormField(
                    controller: _titleCtrl,
                    style: GoogleFonts.inter(color: colorScheme.onSurface),
                    decoration: _inputDecoration('Lesson Title'),
                    validator: (v) => v!.isNotEmpty ? null : 'Required',
                  ),
                  const SizedBox(height: 20),

                  // ── Live / Recorded toggle ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: _isLive
                              ? AppColors.violet.withValues(alpha: 0.5)
                              : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lesson Type',
                            style: GoogleFonts.inter(
                                color: colorScheme.onSurface.withValues(alpha: 0.6),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isLive = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: !_isLive ? AppColors.indigo.withValues(alpha: 0.12) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: !_isLive ? AppColors.indigo : Colors.transparent, width: 2),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.play_circle_outline_rounded,
                                          color: !_isLive ? AppColors.indigo : colorScheme.onSurface.withValues(alpha: 0.4),
                                          size: 20),
                                      const SizedBox(width: 8),
                                      Text('Pre-recorded',
                                          style: GoogleFonts.inter(
                                              color: !_isLive ? AppColors.indigo : colorScheme.onSurface.withValues(alpha: 0.4),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _isLive = true;
                                  _generatedRoomName ??= _generateRoomName();
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: _isLive ? AppColors.violet.withValues(alpha: 0.12) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: _isLive ? AppColors.violet : Colors.transparent, width: 2),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.videocam_rounded,
                                          color: _isLive ? AppColors.violet : colorScheme.onSurface.withValues(alpha: 0.4),
                                          size: 20),
                                      const SizedBox(width: 8),
                                      Text('Live Session',
                                          style: GoogleFonts.inter(
                                              color: _isLive ? AppColors.violet : colorScheme.onSurface.withValues(alpha: 0.4),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  if (_isLive) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.violet.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.violet.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.videocam_rounded, color: AppColors.violet, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'A private built-in classroom will be created automatically. Students join with one tap — no external app needed.',
                              style: GoogleFonts.inter(color: AppColors.violet, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Room ID preview chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.darkCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.darkBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.meeting_room_rounded, color: AppColors.indigo, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Room ID (auto-generated)',
                                    style: GoogleFonts.inter(
                                        color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
                                const SizedBox(height: 2),
                                Text(
                                  _generatedRoomName ?? 'will be generated on save',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Only show video URL field for pre-recorded lessons.
                  // Live lessons use the auto-generated room name instead.
                  if (!_isLive)
                    TextFormField(
                      controller: _videoUrlCtrl,
                      style: GoogleFonts.inter(color: colorScheme.onSurface),
                      decoration: _inputDecoration(
                        'Video URL',
                        hint: 'YouTube, Vimeo or direct MP4 link',
                        suffixIcon: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(Icons.link_rounded, color: AppColors.indigo, size: 20),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _orderCtrl,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.inter(color: colorScheme.onSurface),
                          decoration: _inputDecoration('Order #'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _durationCtrl,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.inter(color: colorScheme.onSurface),
                          decoration: _inputDecoration('Duration (mins)'),
                          validator: (v) {
                            if (v!.isEmpty) return 'Required';
                            if (int.tryParse(v) == null) return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Resource Upload ──
                  Text('Attach Resource / Material',
                      style: GoogleFonts.inter(
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('Upload PDFs, videos (MP4/MKV), slides, or any file for students to download.',
                      style: GoogleFonts.inter(
                          color: colorScheme.onSurface.withValues(alpha: 0.4),
                          fontSize: 12)),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: isBusy ? null : _pickResource,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _resourceFileName != null
                              ? AppColors.emerald.withValues(alpha: 0.5)
                              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          width: _resourceFileName != null ? 2 : 1,
                        ),
                      ),
                      child: _resourceFileName != null
                          ? Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.emerald.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.insert_drive_file_rounded,
                                      color: AppColors.emerald, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_resourceFileName!,
                                          style: GoogleFonts.inter(
                                              color: colorScheme.onSurface,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14),
                                          overflow: TextOverflow.ellipsis),
                                      Text(
                                          '${(_resourceBytes!.length / 1024).toStringAsFixed(1)} KB ready to upload',
                                          style: GoogleFonts.inter(
                                              color: AppColors.emerald,
                                              fontSize: 12)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.close_rounded,
                                      color: colorScheme.onSurface.withValues(alpha: 0.4), size: 18),
                                  onPressed: () => setState(() {
                                    _resourceBytes = null;
                                    _resourceFileName = null;
                                  }),
                                )
                              ],
                            )
                          : Column(
                              children: [
                                Icon(Icons.cloud_upload_rounded,
                                    size: 44,
                                    color: colorScheme.onSurface.withValues(alpha: 0.3)),
                                const SizedBox(height: 10),
                                Text('Click to upload a resource',
                                    style: GoogleFonts.inter(
                                        color: colorScheme.onSurface.withValues(alpha: 0.55),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                                const SizedBox(height: 4),
                                Text('PDF, Video (MP4/MKV), PPT, ZIP, Images — optional',
                                    style: GoogleFonts.inter(
                                        color: colorScheme.onSurface.withValues(alpha: 0.35),
                                        fontSize: 12)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Submit ──
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isBusy ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isLive ? AppColors.violet : AppColors.indigo,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: isBusy
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                    width: 18, height: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                                const SizedBox(width: 10),
                                Text(_statusMessage,
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(_isLive ? Icons.videocam_rounded : Icons.add_rounded, color: Colors.white),
                                const SizedBox(width: 8),
                                Text(_isLive ? 'Add Live Session' : 'Add Lesson',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
