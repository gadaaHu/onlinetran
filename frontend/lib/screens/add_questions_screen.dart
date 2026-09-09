import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import '../core/models.dart';

class AddQuestionsScreen extends ConsumerStatefulWidget {
  final int courseId;
  final QuizModel quiz;

  const AddQuestionsScreen({
    super.key,
    required this.courseId,
    required this.quiz,
  });

  @override
  ConsumerState<AddQuestionsScreen> createState() => _AddQuestionsScreenState();
}

// Represents a draft option row in the UI
class _OptionDraft {
  final TextEditingController controller;
  bool isCorrect;
  _OptionDraft({String text = '', required this.isCorrect})
      : controller = TextEditingController(text: text);
  void dispose() => controller.dispose();
}

class _AddQuestionsScreenState extends ConsumerState<AddQuestionsScreen> {
  final _questionCtrl = TextEditingController();
  final List<_OptionDraft> _options = [];
  bool _isSubmitting = false;
  int _savedCount = 0;

  @override
  void initState() {
    super.initState();
    // Start with 4 blank options
    for (int i = 0; i < 4; i++) {
      _options.add(_OptionDraft(isCorrect: false));
    }
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    for (final o in _options) {
      o.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    setState(() => _options.add(_OptionDraft(isCorrect: false)));
  }

  void _removeOption(int index) {
    if (_options.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A question must have at least 2 options.')),
      );
      return;
    }
    setState(() {
      _options[index].dispose();
      _options.removeAt(index);
    });
  }

  void _setCorrect(int index) {
    setState(() {
      for (int i = 0; i < _options.length; i++) {
        _options[i].isCorrect = (i == index);
      }
    });
  }

  Future<void> _saveQuestion() async {
    final questionText = _questionCtrl.text.trim();
    if (questionText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a question.')),
      );
      return;
    }
    final filledOptions = _options.where((o) => o.controller.text.trim().isNotEmpty).toList();
    if (filledOptions.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in at least 2 options.')),
      );
      return;
    }
    if (!filledOptions.any((o) => o.isCorrect)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please mark one option as the correct answer.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final optionPayload = filledOptions.map((o) => {
      'optionText': o.controller.text.trim(),
      'isCorrect': o.isCorrect,
    }).toList();

    final success = await ref.read(coursesProvider.notifier).addQuestion(
          widget.courseId,
          widget.quiz.id,
          questionText,
          optionPayload,
        );

    setState(() => _isSubmitting = false);

    if (success && mounted) {
      setState(() {
        _savedCount++;
        // Reset form for next question
        _questionCtrl.clear();
        for (final o in _options) {
          o.controller.clear();
          o.isCorrect = false;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Question $_savedCount saved! Add another or go back.'),
          backgroundColor: const Color(0xFF43B97F),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save question. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.quiz.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Add Questions', style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.6))),
          ],
        ),
        actions: [
          if (_savedCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Chip(
                backgroundColor: const Color(0xFF43B97F),
                label: Text('$_savedCount saved', style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Quiz info banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colorScheme.primary, const Color(0xFF9C27B0)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.quiz, color: colorScheme.onPrimary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Passing Score: ${widget.quiz.passingScore}%',
                                style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.w600)),
                            Text('Add as many questions as you need, then go back.',
                                style: TextStyle(color: colorScheme.onPrimary.withValues(alpha: 0.8), fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Question text field
                Text('Question Text', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 13)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _questionCtrl,
                  style: TextStyle(color: colorScheme.onSurface),
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'e.g. What is the capital of Ethiopia?',
                    hintStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.4)),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Answer options
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Answer Options', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 13)),
                    Text('Tap ✓ to mark correct answer',
                        style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 8),
                ...List.generate(_options.length, (i) => _buildOptionRow(i)),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _addOption,
                  icon: Icon(Icons.add_circle_outline, color: colorScheme.primary),
                  label: Text('Add Option', style: TextStyle(color: colorScheme.primary)),
                ),
                const SizedBox(height: 32),

                // Save button
                SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _saveQuestion,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_alt),
                    label: Text(
                      _isSubmitting ? 'Saving...' : 'Save Question & Add Another',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check_circle_outline, color: Color(0xFF43B97F)),
                  label: Text(
                    _savedCount > 0
                        ? 'Done — $_savedCount question${_savedCount == 1 ? '' : 's'} added'
                        : 'Go Back',
                    style: const TextStyle(color: Color(0xFF43B97F)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF43B97F)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionRow(int index) {
    final option = _options[index];
    final isCorrect = option.isCorrect;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          // Correct answer toggle
          GestureDetector(
            onTap: () => _setCorrect(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isCorrect ? const Color(0xFF43B97F) : colorScheme.surface,
                border: Border.all(
                  color: isCorrect ? const Color(0xFF43B97F) : colorScheme.onSurface.withValues(alpha: 0.24),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: isCorrect
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          // Option text field
          Expanded(
            child: TextField(
              controller: option.controller,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Option ${index + 1}',
                hintStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.4)),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: isCorrect ? const Color(0xFF43B97F) : colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          // Remove button
          IconButton(
            onPressed: () => _removeOption(index),
            icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
          ),
        ],
      ),
    );
  }
}
