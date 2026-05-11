import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/auth_widgets.dart';
import 'dashboard_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _isLoading = false;
  String? _errorMessage;
  bool _agreeToTerms = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    FocusScope.of(context).unfocus();

    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }
    if (!_agreeToTerms) {
      setState(() => _errorMessage = 'Please agree to the Terms of Use.');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    final result = await AuthService().signup(
      _nameCtrl.text.trim(),
      _emailCtrl.text.trim(),
      _passCtrl.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const DashboardScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
            (route) => false,
      );
    } else {
      setState(() => _errorMessage = result.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 56),

                  // ── Header ────────────────────────────────────────────────
                  const Text(
                    'Create account',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: AC.textPrimary,
                      letterSpacing: -0.8,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Join the LungScan AI platform',
                    style: TextStyle(
                      fontSize: 14,
                      color: AC.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Step indicator ─────────────────────────────────────────
                  _StepIndicator(currentStep: 1, totalSteps: 1),

                  const SizedBox(height: 28),

                  // ── Error banner ──────────────────────────────────────────
                  if (_errorMessage != null) ...[
                    ErrorBanner(message: _errorMessage!),
                    const SizedBox(height: 20),
                  ],

                  // ── Fields ────────────────────────────────────────────────
                  AuthTextField(
                    label: 'FULL NAME',
                    hint: 'Dr. Jane Smith',
                    prefixIcon: Icons.person_outline_rounded,
                    controller: _nameCtrl,
                    focusNode: _nameFocus,
                    textInputAction: TextInputAction.next,
                    onEditingComplete: () =>
                        FocusScope.of(context).requestFocus(_emailFocus),
                  ),

                  const SizedBox(height: 18),

                  AuthTextField(
                    label: 'EMAIL ADDRESS',
                    hint: 'doctor@hospital.com',
                    prefixIcon: Icons.mail_outline_rounded,
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    focusNode: _emailFocus,
                    textInputAction: TextInputAction.next,
                    onEditingComplete: () =>
                        FocusScope.of(context).requestFocus(_passFocus),
                  ),

                  const SizedBox(height: 18),

                  AuthTextField(
                    label: 'PASSWORD',
                    hint: 'Min. 6 characters',
                    prefixIcon: Icons.lock_outline_rounded,
                    controller: _passCtrl,
                    isPassword: true,
                    focusNode: _passFocus,
                    textInputAction: TextInputAction.next,
                    onEditingComplete: () =>
                        FocusScope.of(context).requestFocus(_confirmFocus),
                  ),

                  const SizedBox(height: 18),

                  AuthTextField(
                    label: 'CONFIRM PASSWORD',
                    hint: 'Re-enter password',
                    prefixIcon: Icons.lock_outline_rounded,
                    controller: _confirmCtrl,
                    isPassword: true,
                    focusNode: _confirmFocus,
                    textInputAction: TextInputAction.done,
                    onEditingComplete: _signup,
                  ),

                  const SizedBox(height: 20),

                  // ── Password strength ─────────────────────────────────────
                  _PasswordStrengthBar(password: _passCtrl.text),

                  const SizedBox(height: 20),

                  // ── Terms checkbox ────────────────────────────────────────
                  GestureDetector(
                    onTap: () =>
                        setState(() => _agreeToTerms = !_agreeToTerms),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: _agreeToTerms
                                ? AC.cyan.withOpacity(0.2)
                                : AC.inputBg,
                            border: Border.all(
                              color: _agreeToTerms ? AC.cyan : AC.inputBorder,
                              width: 1.5,
                            ),
                          ),
                          child: _agreeToTerms
                              ? const Icon(Icons.check,
                              color: AC.cyan, size: 14)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'I agree to the Terms of Use and Privacy Policy',
                            style: TextStyle(
                              fontSize: 13,
                              color: AC.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Signup button ─────────────────────────────────────────
                  GradientButton(
                    label: 'Create Account',
                    isLoading: _isLoading,
                    onTap: _isLoading ? null : _signup,
                  ),

                  const SizedBox(height: 24),

                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Already have an account? ',
                          style: TextStyle(
                              color: AC.textSecondary, fontSize: 14),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Sign in',
                            style: TextStyle(
                              color: AC.cyan,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
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

// ── Step indicator ─────────────────────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _StepIndicator({
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (i) {
        final active = i < currentStep;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < totalSteps - 1 ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: active
                  ? const LinearGradient(
                colors: [AC.cyan, AC.purple],
              )
                  : null,
              color: active ? null : AC.border,
            ),
          ),
        );
      }),
    );
  }
}

// ── Password strength bar ──────────────────────────────────────────────────────
class _PasswordStrengthBar extends StatefulWidget {
  final String password;
  const _PasswordStrengthBar({required this.password});

  @override
  State<_PasswordStrengthBar> createState() => _PasswordStrengthBarState();
}

class _PasswordStrengthBarState extends State<_PasswordStrengthBar> {
  @override
  Widget build(BuildContext context) {
    final strength = _getStrength(widget.password);
    if (widget.password.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (i) {
            Color color;
            if (i < strength) {
              if (strength == 1) color = AC.error;
              else if (strength == 2) color = const Color(0xFFFFAB00);
              else if (strength == 3) color = const Color(0xFF69F0AE);
              else color = AC.success;
            } else {
              color = AC.border;
            }
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: color,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          _getLabel(strength),
          style: TextStyle(
            fontSize: 11,
            color: _getLabelColor(strength),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  int _getStrength(String p) {
    if (p.isEmpty) return 0;
    int s = 0;
    if (p.length >= 6) s++;
    if (p.contains(RegExp(r'[A-Z]'))) s++;
    if (p.contains(RegExp(r'[0-9]'))) s++;
    if (p.contains(RegExp(r'[!@#$%^&*]'))) s++;
    return s.clamp(1, 4);
  }

  String _getLabel(int s) {
    switch (s) {
      case 1: return 'Weak';
      case 2: return 'Fair';
      case 3: return 'Good';
      case 4: return 'Strong';
      default: return '';
    }
  }

  Color _getLabelColor(int s) {
    switch (s) {
      case 1: return AC.error;
      case 2: return const Color(0xFFFFAB00);
      case 3: return const Color(0xFF69F0AE);
      case 4: return AC.success;
      default: return AC.textSecondary;
    }
  }
}
