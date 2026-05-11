import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/auth_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  bool _emailSent = false;

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
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _errorMessage = null;
      _successMessage = null;
      _isLoading = true;
    });

    final result =
    await AuthService().forgotPassword(_emailCtrl.text.trim());

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      setState(() {
        _emailSent = true;
        _successMessage = result.message;
      });
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 56),

                // ── Icon ──────────────────────────────────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _emailSent
                      ? _SuccessIcon(key: const ValueKey('success'))
                      : _LockIcon(key: const ValueKey('lock')),
                ),

                const SizedBox(height: 28),

                // ── Title ─────────────────────────────────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _emailSent
                      ? _SentContent(
                    key: const ValueKey('sent'),
                    email: _emailCtrl.text.trim(),
                    onBack: () => Navigator.of(context).pop(),
                    onResend: () {
                      setState(() {
                        _emailSent = false;
                        _successMessage = null;
                      });
                    },
                  )
                      : _FormContent(
                    key: const ValueKey('form'),
                    emailCtrl: _emailCtrl,
                    isLoading: _isLoading,
                    errorMessage: _errorMessage,
                    onSend: _sendReset,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Form content ───────────────────────────────────────────────────────────────
class _FormContent extends StatelessWidget {
  final TextEditingController emailCtrl;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onSend;
  final VoidCallback onBack;

  const _FormContent({
    super.key,
    required this.emailCtrl,
    required this.isLoading,
    required this.errorMessage,
    required this.onSend,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reset password',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AC.textPrimary,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "Enter your registered email and we'll send you a password reset link.",
          style: TextStyle(
            fontSize: 14,
            color: AC.textSecondary,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 32),

        if (errorMessage != null) ...[
          ErrorBanner(message: errorMessage!),
          const SizedBox(height: 20),
        ],

        AuthTextField(
          label: 'EMAIL ADDRESS',
          hint: 'doctor@hospital.com',
          prefixIcon: Icons.mail_outline_rounded,
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onEditingComplete: onSend,
        ),

        const SizedBox(height: 28),

        GradientButton(
          label: 'Send Reset Link',
          isLoading: isLoading,
          onTap: isLoading ? null : onSend,
        ),

        const SizedBox(height: 20),

        Center(
          child: GestureDetector(
            onTap: onBack,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_ios, color: AC.textSecondary, size: 14),
                SizedBox(width: 4),
                Text(
                  'Back to Sign In',
                  style: TextStyle(
                    color: AC.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Sent content ───────────────────────────────────────────────────────────────
class _SentContent extends StatelessWidget {
  final String email;
  final VoidCallback onBack;
  final VoidCallback onResend;

  const _SentContent({
    super.key,
    required this.email,
    required this.onBack,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Check your email',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AC.textPrimary,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 10),
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 14,
              color: AC.textSecondary,
              height: 1.6,
            ),
            children: [
              const TextSpan(text: "We've sent a password reset link to\n"),
              TextSpan(
                text: email,
                style: const TextStyle(
                  color: AC.cyan,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Checklist
        ...[
          'Check your inbox and spam folder',
          'Click the reset link in the email',
          'Create a new strong password',
        ].asMap().entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AC.cyan.withOpacity(0.1),
                  border: Border.all(
                      color: AC.cyan.withOpacity(0.3)),
                ),
                child: Center(
                  child: Text(
                    '${e.key + 1}',
                    style: const TextStyle(
                      color: AC.cyan,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                e.value,
                style: const TextStyle(
                  color: AC.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        )),

        const SizedBox(height: 28),

        GradientButton(
          label: 'Back to Sign In',
          onTap: onBack,
        ),

        const SizedBox(height: 16),

        Center(
          child: GestureDetector(
            onTap: onResend,
            child: const Text(
              "Didn't receive it? Send again",
              style: TextStyle(
                color: AC.textSecondary,
                fontSize: 13,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Icons ──────────────────────────────────────────────────────────────────────
class _LockIcon extends StatelessWidget {
  const _LockIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF0C1828),
        border: Border.all(color: AC.border),
        boxShadow: [
          BoxShadow(
            color: AC.cyan.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(
        Icons.lock_reset_rounded,
        color: AC.cyan,
        size: 32,
      ),
    );
  }
}

class _SuccessIcon extends StatelessWidget {
  const _SuccessIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AC.success.withOpacity(0.1),
        border: Border.all(color: AC.success.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AC.success.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(
        Icons.mark_email_read_outlined,
        color: AC.success,
        size: 32,
      ),
    );
  }
}
