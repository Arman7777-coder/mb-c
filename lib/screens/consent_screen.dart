import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/user_provider.dart';

class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _ageConfirmed = false;
  bool _tosAccepted = false;
  bool _privacyAccepted = false;
  bool _dataConsent = false;
  bool _loading = false;
  String? _error;

  bool get _allChecked => _ageConfirmed && _tosAccepted && _privacyAccepted && _dataConsent;

  Future<void> _proceed() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(userProvider.notifier).updateConsent(true, true);
      if (!mounted) return;
      // Read the post-call state. The notifier writes errors there;
      // navigating to /home on a failed consent call would leave the
      // user on a Home screen with no session — better to surface the
      // error and let them retry.
      final result = ref.read(userProvider);
      result.when(
        data: (_) => Navigator.pushReplacementNamed(context, '/home'),
        loading: () {},
        error: (e, _) => setState(() {
          _loading = false;
          _error = 'Couldn\'t reach the server. Check your connection and try again.';
        }),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Couldn\'t reach the server. Check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.verified_user_rounded, size: 48, color: AppColors.primary),
              const SizedBox(height: 16),
              const Text(
                'Before we begin',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please review and accept the following to continue.',
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              _buildCheckItem(
                'I am 13 years of age or older',
                _ageConfirmed,
                (v) => setState(() => _ageConfirmed = v!),
              ),
              _buildCheckItem(
                'I agree to the Terms of Service',
                _tosAccepted,
                (v) => setState(() => _tosAccepted = v!),
                hasLink: true,
              ),
              _buildCheckItem(
                'I agree to the Privacy Policy',
                _privacyAccepted,
                (v) => setState(() => _privacyAccepted = v!),
                hasLink: true,
              ),
              _buildCheckItem(
                'I consent to anonymous data collection for surveys and analytics',
                _dataConsent,
                (v) => setState(() => _dataConsent = v!),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.premiumLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.premium, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Points earned are app balance, not guaranteed cash. Redemptions are subject to review and availability.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 18, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.red))),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _allChecked && !_loading ? _proceed : null,
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Get Started'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckItem(String text, bool value, ValueChanged<bool?> onChanged, {bool hasLink = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: value ? AppColors.primary.withValues(alpha: 0.05) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: value ? AppColors.primary.withValues(alpha: 0.3) : AppColors.divider),
          ),
          child: Row(
            children: [
              Checkbox(
                value: value,
                onChanged: onChanged,
                activeColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              Expanded(
                child: Text(text, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
