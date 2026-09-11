import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../services/consultant_service.dart';
import '../../theme/app_theme.dart';

class ConsultantScreen extends StatefulWidget {
  const ConsultantScreen({super.key});

  @override
  State<ConsultantScreen> createState() => _ConsultantScreenState();
}

class _ConsultantScreenState extends State<ConsultantScreen> {
  bool _isLoading = false;
  String? _advice;
  String? _errorMessage;

  Future<void> _getAdvice() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final advice = await ConsultantService.instance.getAdvice();
      if (!mounted) return;
      setState(() {
        _advice = advice;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
      // Matches the Dashboard/Settings headers' implicit height: their
      // IconButtons enforce a 48dp minimum tap target, which centers their
      // title text a few pixels lower than a bare Text row would sit -
      // without this, "AI Consultant" renders visibly higher than the other
      // two screens' titles despite using the identical top padding.
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Text(
              'AI Consultant',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Get a short, personalized summary of your recent walking activity - '
          'general encouragement and lifestyle suggestions, not medical advice.',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 13,
            color: AppTheme.textSecondary(context).withAlpha(230),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _getAdvice,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.stepsGreen,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Text(
                    'Get my advice',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 20),
        if (_errorMessage != null) _buildErrorCard(),
        if (_advice != null) _buildAdviceCard(),
      ],
    );
  }

  Widget _buildErrorCard() {
    final error = Theme.of(context).colorScheme.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: error.withAlpha(77), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _errorMessage!,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 13,
              color: error,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _getAdvice,
            child: const Text(
              'Try again',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.stepsGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdviceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.overlay(context, 15), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_outlined,
                size: 16,
                color: AppTheme.stepsGreen,
              ),
              const SizedBox(width: 8),
              Text(
                'Your advice',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary(context).withAlpha(230),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _advice!,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
