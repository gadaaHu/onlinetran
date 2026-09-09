import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';

class CreateQuizScreen extends ConsumerStatefulWidget {
  final int courseId;
  const CreateQuizScreen({super.key, required this.courseId});

  @override
  ConsumerState<CreateQuizScreen> createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends ConsumerState<CreateQuizScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _scoreCtrl = TextEditingController(text: '70');
  bool _isLoading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _scoreCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final success = await ref.read(coursesProvider.notifier).createQuiz(
          widget.courseId,
          _titleCtrl.text.trim(),
          double.tryParse(_scoreCtrl.text.trim()) ?? 70.0,
        );

    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quiz created!')),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create quiz.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Quiz'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _titleCtrl,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Quiz Title',
                      labelStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6)),
                      filled: true,
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    validator: (v) => v!.isNotEmpty ? null : 'Required',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _scoreCtrl,
                    style: TextStyle(color: colorScheme.onSurface),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Passing Score (%)',
                      labelStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6)),
                      filled: true,
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    validator: (v) {
                      if (v!.isEmpty) return 'Required';
                      final val = double.tryParse(v);
                      if (val == null || val < 1 || val > 100) return 'Enter a number between 1 and 100';
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? CircularProgressIndicator(color: colorScheme.onSurface)
                          : const Text('Create Quiz', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
