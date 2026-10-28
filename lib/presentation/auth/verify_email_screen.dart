import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';

/// Reached after registering (see RegisterScreen) or after a login attempt
/// the backend rejected specifically for an unverified email (see
/// LoginScreen) - [AuthProvider.pendingVerificationEmail] names which case.
/// Visually matches LoginScreen/RegisterScreen's conventions; no existing
/// OTP-box UI anywhere in this app to match instead, so a single 6-digit
/// text field is enough for v1.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  static const _resendCooldownSeconds = 60;

  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  Timer? _cooldownTimer;
  int _cooldownSecondsLeft = 0;

  @override
  void dispose() {
    _codeController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.verifyEmail(_codeController.text.trim());
    if (success && mounted) {
      // Same settled-before-notify ordering LoginScreen/RegisterScreen rely
      // on - auth.profileCompleted is already correct by the time verifyEmail
      // returns, no async gap for the router's own redirect to race ahead of.
      context.go(
        auth.profileCompleted
            ? AppRoutes.activityDashboardScreen
            : AppRoutes.profileSetupScreen,
      );
    }
  }

  Future<void> _resend() async {
    final auth = context.read<AuthProvider>();
    final success = await auth.resendVerificationCode();
    if (success && mounted) {
      _startCooldown();
    }
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
    final email = auth.pendingVerificationEmail;

    // Reaching this screen with nothing pending (e.g. a stale back-navigation)
    // has nowhere useful to go but back to sign-in.
    if (email == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AppRoutes.loginScreen);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              _buildHeader(email),
              const SizedBox(height: 40),
              _buildForm(),
              const SizedBox(height: 16),
              if (auth.errorMessage != null) _buildError(auth.errorMessage!),
              const SizedBox(height: 24),
              _buildVerifyButton(auth),
              const SizedBox(height: 20),
              _buildResendRow(auth),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String email) {
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
            Icons.mark_email_read_outlined,
            color: AppTheme.stepsGreen,
            size: 28,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Verify your email',
          style: GoogleFonts.manrope(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the 6-digit code we sent to $email',
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: AppTheme.textSecondary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
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

  Widget _buildVerifyButton(AuthProvider auth) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: auth.isLoading ? null : _verify,
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
            : Text('Verify', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildResendRow(AuthProvider auth) {
    final onCooldown = _cooldownSecondsLeft > 0;
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
