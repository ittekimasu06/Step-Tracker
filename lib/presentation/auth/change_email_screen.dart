import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

/// Reached from Settings' Account section (see AccountSettingsWidget) via `context.push` -
/// not part of the pre-auth routing (unlike VerifyEmailScreen/app_routes.dart's isAuthRoute
/// check), since this flow only ever runs while already signed in. Local two-step state:
/// step 1 collects the current password + new email, step 2 confirms the OTP sent to the new
/// address - visually mirrors the OTP step of VerifyEmailScreen, duplicated rather than
/// shared since it's a single self-contained countdown timer and a handful of widgets.
class ChangeEmailScreen extends StatefulWidget {
  const ChangeEmailScreen({super.key});

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  static const _resendCooldownSeconds = 60;

  int _step = 1;
  String? _currentEmail;

  final _requestFormKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _newEmailController = TextEditingController();
  bool _obscurePassword = true;

  final _codeFormKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  Timer? _cooldownTimer;
  int _cooldownSecondsLeft = 0;

  @override
  void initState() {
    super.initState();
    AuthService.instance.currentUserEmail().then((email) {
      if (mounted) setState(() => _currentEmail = email);
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _newEmailController.dispose();
    _codeController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_requestFormKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.requestEmailChange(
      currentPassword: _passwordController.text,
      newEmail: _newEmailController.text.trim(),
    );
    if (success && mounted) {
      setState(() => _step = 2);
    }
  }

  Future<void> _confirm() async {
    if (!_codeFormKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.confirmEmailChange(_codeController.text.trim());
    if (success && mounted) {
      // go() (not pop()) so this always lands cleanly on Settings regardless of how many
      // pages are on the stack - a plain pop() here could race with the redirect that
      // AuthProvider's notifyListeners (fired moments earlier, still on this route) triggers,
      // leaving a stray duplicate of this screen on top instead of returning to Settings.
      final messenger = ScaffoldMessenger.of(context);
      context.go(AppRoutes.settingsScreen);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Email changed successfully',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w500),
          ),
          backgroundColor: AppTheme.stepsGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _resend() async {
    final auth = context.read<AuthProvider>();
    final success = await auth.resendEmailChangeCode();
    if (success && mounted) _startCooldown();
  }

  void _startCooldown() {
    setState(() => _cooldownSecondsLeft = _resendCooldownSeconds);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownSecondsLeft -= 1;
        if (_cooldownSecondsLeft <= 0) timer.cancel();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: AppTheme.textBright(context),
                ),
              ),
              const SizedBox(height: 24),
              _step == 1 ? _buildRequestStep(auth) : _buildConfirmStep(auth),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestStep(AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(
          'Change email',
          _currentEmail == null
              ? 'Enter your password and a new email'
              : 'Current email: $_currentEmail',
        ),
        const SizedBox(height: 32),
        Form(
          key: _requestFormKey,
          child: Column(
            children: [
              _buildTextField(
                controller: _passwordController,
                label: 'Current Password',
                hint: '••••••••',
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppTheme.textMuted(context),
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password is required';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _newEmailController,
                label: 'New Email',
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (auth.errorMessage != null) _buildError(auth.errorMessage!),
        const SizedBox(height: 24),
        _buildPrimaryButton(auth, label: 'Send Code', onPressed: _submitRequest),
      ],
    );
  }

  Widget _buildConfirmStep(AuthProvider auth) {
    final onCooldown = _cooldownSecondsLeft > 0;
    final target = auth.pendingNewEmail;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(
          'Verify new email',
          target == null
              ? 'Enter the 6-digit code we sent you'
              : 'Enter the 6-digit code we sent to $target',
        ),
        const SizedBox(height: 32),
        Form(
          key: _codeFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Verification code',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  letterSpacing: 6,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '000000',
                  hintStyle: GoogleFonts.manrope(
                    fontSize: 20,
                    letterSpacing: 6,
                    color: AppTheme.textDisabled(context),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.stepsGreen, width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.error, width: 1.5),
                  ),
                  errorStyle: GoogleFonts.manrope(fontSize: 12, color: Theme.of(context).colorScheme.error),
                ),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Enter the code from your email';
                  if (value.length != 6) return 'Code must be 6 digits';
                  return null;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (auth.errorMessage != null) _buildError(auth.errorMessage!),
        const SizedBox(height: 24),
        _buildPrimaryButton(auth, label: 'Verify', onPressed: _confirm),
        const SizedBox(height: 20),
        _buildResendRow(auth, onCooldown),
      ],
    );
  }

  Widget _buildHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppTheme.stepsGreen.withAlpha(30),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.alternate_email_rounded,
            color: AppTheme.stepsGreen,
            size: 28,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          style: GoogleFonts.manrope(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: AppTheme.textSecondary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: GoogleFonts.manrope(
            fontSize: 15,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.manrope(
              fontSize: 15,
              color: AppTheme.textDisabled(context),
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.stepsGreen, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.error, width: 1.5),
            ),
            errorStyle: GoogleFonts.manrope(fontSize: 12, color: Theme.of(context).colorScheme.error),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildError(String message) {
    final error = Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: error.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: error.withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: GoogleFonts.manrope(fontSize: 13, color: error)),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(
    AuthProvider auth, {
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: auth.isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.stepsGreen,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppTheme.stepsGreen.withAlpha(100),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: auth.isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(label, style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildResendRow(AuthProvider auth, bool onCooldown) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Didn't get a code? ",
          style: GoogleFonts.manrope(fontSize: 14, color: AppTheme.textSecondary(context)),
        ),
        GestureDetector(
          onTap: (auth.isLoading || onCooldown) ? null : _resend,
          child: Text(
            onCooldown ? 'Resend in ${_cooldownSecondsLeft}s' : 'Resend',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: onCooldown ? AppTheme.textMuted(context) : AppTheme.stepsGreen,
            ),
          ),
        ),
      ],
    );
  }
}
