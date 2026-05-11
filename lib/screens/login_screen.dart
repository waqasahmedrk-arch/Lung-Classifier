import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/auth_widgets.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();

  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    final result = await AuthService().login(
      _emailCtrl.text.trim(),
      _passCtrl.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const DashboardScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } else {
      setState(() => _errorMessage = result.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
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
                  const SizedBox(height: 48),

                  // ── Header ───────────────────────────────────────────────
                  Row(
                    children: [
                      const AuthLogoMark(size: 52),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) =>
                                const LinearGradient(
                                  colors: [Color(0xFF00D4FF), Color(0xFF7B2FFF)],
                                ).createShader(bounds),
                            child: const Text(
                              'LungScan AI',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          const Text(
                            'Clinical Intelligence Platform',
                            style: TextStyle(
                              fontSize: 11,
                              color: AC.textSecondary,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 44),

                  // ── Welcome text ─────────────────────────────────────────
                  const Text(
                    'Welcome back',
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
                    'Sign in to access your diagnostic dashboard',
                    style: TextStyle(
                      fontSize: 14,
                      color: AC.textSecondary,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── Error banner ─────────────────────────────────────────
                  if (_errorMessage != null) ...[
                    ErrorBanner(message: _errorMessage!),
                    const SizedBox(height: 20),
                  ],

                  // ── Fields ───────────────────────────────────────────────
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

                  const SizedBox(height: 20),

                  AuthTextField(
                    label: 'PASSWORD',
                    hint: '••••••••',
                    prefixIcon: Icons.lock_outline_rounded,
                    controller: _passCtrl,
                    isPassword: true,
                    focusNode: _passFocus,
                    textInputAction: TextInputAction.done,
                    onEditingComplete: _login,
                  ),

                  const SizedBox(height: 12),

                  // ── Forgot password ──────────────────────────────────────
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        _slideRoute(const ForgotPasswordScreen()),
                      ),
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(
                          color: AC.cyan,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Login button ─────────────────────────────────────────
                  GradientButton(
                    label: 'Login In',
                    isLoading: _isLoading,
                    onTap: _isLoading ? null : _login,
                  ),

                  const SizedBox(height: 28),
                  const OrDivider(),
                  const SizedBox(height: 28),

                  // ── Sign up link ─────────────────────────────────────────
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            color: AC.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            _slideRoute(const SignupScreen()),
                          ),
                          child: const Text(
                            'Create account',
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

                  // ── Research disclaimer ──────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C1828),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AC.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.shield_outlined,
                            color: AC.textSecondary.withOpacity(0.6),
                            size: 16),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'For research use only. Not a substitute for professional medical diagnosis.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF3A5470),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

PageRouteBuilder _slideRoute(Widget page) => PageRouteBuilder(
  pageBuilder: (_, __, ___) => page,
  transitionsBuilder: (_, anim, __, child) => SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(1.0, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
    child: child,
  ),
  transitionDuration: const Duration(milliseconds: 350),
);
