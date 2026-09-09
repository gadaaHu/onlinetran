import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';

class CreateCourseScreen extends ConsumerStatefulWidget {
  const CreateCourseScreen({super.key});

  @override
  ConsumerState<CreateCourseScreen> createState() => _CreateCourseScreenState();
}

class _CreateCourseScreenState extends ConsumerState<CreateCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final success = await ref.read(coursesProvider.notifier).createCourse(
          _titleCtrl.text.trim(),
          _descCtrl.text.trim(),
          double.tryParse(_priceCtrl.text.trim()) ?? 0.0,
        );

    setState(() => _isLoading = false);

    if (success && mounted) {
      ref.read(teachingCoursesProvider.notifier).fetchCourses();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Course created successfully!')),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create course. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text('Create New Course', style: TextStyle(fontWeight: FontWeight.w600)),
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
                      labelText: 'Course Title',
                      labelStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6)),
                      filled: true,
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    validator: (v) => v!.isNotEmpty ? null : 'Required',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descCtrl,
                    style: TextStyle(color: colorScheme.onSurface),
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: 'Course Description',
                      labelStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6)),
                      filled: true,
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    validator: (v) => v!.isNotEmpty ? null : 'Required',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _priceCtrl,
                    style: TextStyle(color: colorScheme.onSurface),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Price (\$)',
                      labelStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6)),
                      filled: true,
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    validator: (v) {
                      if (v!.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Enter a valid number';
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
                          : const Text('Create Course', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
