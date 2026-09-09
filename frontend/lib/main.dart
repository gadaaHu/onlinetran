import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'core/providers.dart';
import 'core/theme.dart';

void main() {
  runApp(const ProviderScope(child: LmsApp()));
}

class LmsApp extends ConsumerWidget {
  const LmsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return MaterialApp(
      title: 'Immigration & Citizenship Training',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ref.watch(themeProvider),
      home: auth.user != null ? const HomeScreen() : const LoginScreen(),
    );
  }
}
