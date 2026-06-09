import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
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
      // Ensure the device is registered before sending consent. If the
      // initial registration in main() failed (transient network, slow
      // backend), retry it here so Get Started is a true retry — not a
      // dead button that always shows the same "couldn't reach server"
      // error. This is what trapped App Review on iPad.
      final notifier = ref.read(userProvider.notifier);
      final pre = ref.read(userProvider);
      if (pre.hasError || pre.value == null) {
        await notifier.initialize();
      }
      final ready = ref.read(userProvider);
      if (ready.value == null) {
        throw ready.error ?? StateError('Registration failed');
      }

      await notifier.updateConsent(true, true);
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
          padding: const EdgeInsets.symmetric(horizontal: 24),
          // Scrollable content above + sticky button below. Earlier this
          // was a fixed Column with a Spacer, which on shorter screens
          // (iPad landscape, smaller iPads) pushed "Get Started" below
          // the safe area — App Review on iPad couldn't reach it.
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
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
                        linkLabel: 'Terms of Service',
                        linkUrl: AppConstants.termsUrl,
                      ),
                      _buildCheckItem(
                        'I agree to the Privacy Policy',
                        _privacyAccepted,
                        (v) => setState(() => _privacyAccepted = v!),
                        linkLabel: 'Privacy Policy',
                        linkUrl: AppConstants.privacyUrl,
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
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
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

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $url')),
        );
      }
    }
  }

  // When [linkUrl] is set the row shows a "View" button that opens the
  // document — App Review requires the user be able to read the Terms /
  // Privacy Policy *before* agreeing. The button has its own tap target so
  // tapping it opens the doc instead of toggling the checkbox.
  Widget _buildCheckItem(
    String text,
    bool value,
    ValueChanged<bool?> onChanged, {
    String? linkLabel,
    String? linkUrl,
  }) {
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
              if (linkUrl != null)
                TextButton(
                  onPressed: () => _openUrl(linkUrl),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: AppColors.primary,
                  ),
                  child: Semantics(
                    label: 'View $linkLabel',
                    child: const Text(
                      'View',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
