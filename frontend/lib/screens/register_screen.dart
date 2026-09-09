import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/providers.dart';
import '../core/theme.dart';
import 'home_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _isInstructor = false;

  late AnimationController _enterCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late AnimationController _bgCtrl;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _fadeAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutQuint));
    
    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 15))..repeat(reverse: true);

    _enterCtrl.forward();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _bgCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref.read(authProvider.notifier).register(
        _firstNameCtrl.text.trim(),
        _lastNameCtrl.text.trim(),
        _emailCtrl.text.trim(),
        _passCtrl.text,
        _isInstructor);
    if (success && mounted) {
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D1A) : AppColors.lightBg,
      body: Stack(
        children: [
          // ── Animated Background Orbs ───────────────────────────────────────
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (context, _) {
              return Stack(
                children: [
                  Positioned(
                    top: -100 + (50 * math.sin(_bgCtrl.value * 2 * math.pi)),
                    right: -100 + (30 * math.cos(_bgCtrl.value * 2 * math.pi)),
                    child: _BgOrb(color: AppColors.violet, size: 400),
                  ),
                  Positioned(
                    bottom: -150 + (60 * math.cos(_bgCtrl.value * 2 * math.pi)),
                    left: -100 + (40 * math.sin(_bgCtrl.value * 2 * math.pi)),
                    child: _BgOrb(color: AppColors.cyan, size: 350),
                  ),
                ],
              );
            },
          ),
          
          // ── Glass Blur Layer ─────────────────────────────────────────────
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(color: Colors.transparent),
          ),
          
          // ── Form Content ──────────────────────────────────────────────────
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: isDark 
                            ? Colors.black.withValues(alpha: 0.4) 
                            : Colors.white.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: isDark 
                              ? Colors.white.withValues(alpha: 0.1) 
                              : Colors.white.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 40,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header
                            Center(
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(22),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.violet.withValues(alpha: 0.4),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    )
                                  ],
                                ),
                                child: const Icon(Icons.person_add_alt_1_rounded,
                                    color: Colors.white, size: 38),
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text('Create Account',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.headlineLarge(
                                    isDark ? Colors.white : const Color(0xFF0F0F1A))),
                            const SizedBox(height: 8),
                            Text('Start your learning journey today',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280), 
                                    fontSize: 15)),
                            const SizedBox(height: 40),
                            
                            // Fields
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: _firstNameCtrl,
                                    label: 'First Name',
                                    isDark: isDark,
                                    validator: (v) => v!.isNotEmpty ? null : 'Required',
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildTextField(
                                    controller: _lastNameCtrl,
                                    label: 'Last Name',
                                    isDark: isDark,
                                    validator: (v) => v!.isNotEmpty ? null : 'Required',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            
                            _buildTextField(
                              controller: _emailCtrl,
                              label: 'Email Address',
                              icon: Icons.email_outlined,
                              isDark: isDark,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => v!.contains('@') ? null : 'Enter a valid email',
                            ),
                            const SizedBox(height: 20),
                            
                            _buildTextField(
                              controller: _passCtrl,
                              label: 'Password',
                              icon: Icons.lock_outline,
                              isDark: isDark,
                              obscureText: _obscurePass,
                              suffixIcon: IconButton(
                                icon: Icon(
                                    _obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                                onPressed: () => setState(() => _obscurePass = !_obscurePass),
                              ),
                              validator: (v) => v!.length >= 6 ? null : 'At least 6 characters',
                            ),
                            const SizedBox(height: 20),
                            
                            // Instructor Toggle
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                              ),
                              child: CheckboxListTile(
                                title: Text('I want to teach a course', 
                                    style: GoogleFonts.inter(
                                        color: isDark ? Colors.white : const Color(0xFF0F0F1A), 
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14)),
                                subtitle: Text('Register as an Instructor',
                                    style: GoogleFonts.inter(
                                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                        fontSize: 12)),
                                value: _isInstructor,
                                onChanged: (val) => setState(() => _isInstructor = val ?? false),
                                controlAffinity: ListTileControlAffinity.leading,
                                activeColor: AppColors.indigo,
                                checkColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            
                            // Error Message
                            if (auth.error != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.rose.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.rose.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline_rounded, color: AppColors.rose, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(auth.error!,
                                          style: GoogleFonts.inter(
                                              color: AppColors.rose,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 13)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 32),
                            
                            // Submit Button
                            Container(
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.indigo.withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  )
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: auth.isLoading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                ),
                                child: auth.isLoading
                                    ? const SizedBox(height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                            color: Colors.white, strokeWidth: 2.5))
                                    : Text('Create Account',
                                        style: GoogleFonts.inter(
                                            fontSize: 16, fontWeight: FontWeight.w700)),
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // Sign In Link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Already have an account?',
                                    style: GoogleFonts.inter(
                                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                        fontSize: 14)),
                                const SizedBox(width: 4),
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text('Sign In',
                                      style: GoogleFonts.inter(
                                          color: AppColors.indigo,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14)),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    required bool isDark,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(
          color: isDark ? Colors.white : const Color(0xFF0F0F1A), 
          fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)) : null,
        suffixIcon: suffixIcon,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.5),
      ),
      validator: validator,
    );
  }
}

class _BgOrb extends StatelessWidget {
  final Color color;
  final double size;
  const _BgOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.15),
      ),
    );
  }
}
