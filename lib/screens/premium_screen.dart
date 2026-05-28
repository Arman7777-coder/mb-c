import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../providers/user_provider.dart';
import '../providers/iap_provider.dart';
import '../services/iap_service.dart';

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  ProductDetails? _productFor(List<ProductDetails> products, String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
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

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProvider);

    // Surface purchase outcomes as snackbars.
    ref.listen<AsyncValue<IapState>>(iapStateProvider, (prev, next) {
      final state = next.value;
      if (state == null) return;
      if (state.phase == IapPhase.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Premium activated!'),
            backgroundColor: AppColors.earnings,
          ),
        );
      } else if (state.phase == IapPhase.error && state.message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.message!)),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Premium')),
      body: userAsync.when(
        data: (user) {
          if (user == null) return const SizedBox.shrink();
          if (user.isPremium) return _buildActivePremium(user);
          return _buildUpgradeView();
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Error loading status')),
      ),
    );
  }

  Widget _buildActivePremium(dynamic user) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.premium, Color(0xFFE65100)]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const Icon(Icons.star_rounded, color: Colors.white, size: 48),
              const SizedBox(height: 12),
              const Text('Premium Active', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (user.premiumExpiresAt != null)
                Text(
                  'Renews: ${DateFormat('MMM d, yyyy').format(user.premiumExpiresAt!)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              const SizedBox(height: 8),
              Text(
                '${3 - user.bonusSurveysUsedToday} bonus surveys remaining today',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text('Your Premium Benefits', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _buildBenefitTile(Icons.bolt, '1.5× Reward Multiplier', 'Earn 50% more on every survey'),
        _buildBenefitTile(Icons.add_circle_outline, '3 Bonus Surveys/Day', 'Skip the 8-hour cooldown'),
        _buildBenefitTile(Icons.support_agent, 'Priority Support', 'Get help faster'),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () => _openManageSubscriptions(),
            child: const Text('Manage Subscription'),
          ),
        ),
      ],
    );
  }

  Future<void> _openManageSubscriptions() async {
    // Both stores deep-link to the system subscription management screen.
    final url = Theme.of(context).platform == TargetPlatform.iOS
        ? 'https://apps.apple.com/account/subscriptions'
        : 'https://play.google.com/store/account/subscriptions';
    await _openUrl(url);
  }

  Widget _buildUpgradeView() {
    final productsAsync = ref.watch(iapProductsProvider);
    final iapState = ref.watch(iapStateProvider).value;
    final pendingId =
        iapState?.phase == IapPhase.pending ? iapState?.activeProductId : null;
    final restoring =
        iapState?.phase == IapPhase.pending && iapState?.activeProductId == null;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 20),
        const Icon(Icons.star_rounded, color: AppColors.premium, size: 64),
        const SizedBox(height: 16),
        const Text('Upgrade to Premium', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text('Earn more, redeem faster', style: TextStyle(color: AppColors.textSecondary, fontSize: 16), textAlign: TextAlign.center),
        const SizedBox(height: 32),
        _buildComparisonRow('Reward Multiplier', '1×', '1.5×'),
        _buildComparisonRow('Surveys per Day', '1 every 8h', '+ 3 bonus'),
        _buildComparisonRow('Ad Boost', '2×', '2× (stacks to 3×)'),
        _buildComparisonRow('Support', 'Standard', 'Priority'),
        const SizedBox(height: 32),
        productsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => _buildUnavailableNotice(),
          data: (products) {
            if (products.isEmpty) return _buildUnavailableNotice();
            final monthly = _productFor(products, IapProducts.monthly);
            final yearly = _productFor(products, IapProducts.yearly);
            return Column(
              children: [
                _buildPricingCard(monthly, 'Monthly', '/month', pendingId == IapProducts.monthly),
                const SizedBox(height: 12),
                _buildPricingCard(yearly, 'Yearly', '/year (best value)', pendingId == IapProducts.yearly, highlight: true),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: restoring
                ? null
                : () => ref.read(iapServiceProvider).restore(),
            child: restoring
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Restore Purchases'),
          ),
        ),
        const SizedBox(height: 8),
        _buildLegalCopy(),
      ],
    );
  }

  Widget _buildUnavailableNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            'Plans are unavailable right now. Make sure you are signed in to '
            'the App Store, then try again.',
            style: TextStyle(fontSize: 13, color: AppColors.error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => ref.invalidate(iapProductsProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // Auto-renew disclosure + ToS/Privacy links. Required on the paywall by
  // both App Store and Play Store review.
  Widget _buildLegalCopy() {
    return Column(
      children: [
        const Text(
          'Subscriptions renew automatically unless cancelled at least 24 hours '
          'before the end of the current period. Manage or cancel anytime in '
          'your account settings.',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => _openUrl(AppConstants.termsUrl),
              child: const Text('Terms of Use', style: TextStyle(fontSize: 11)),
            ),
            const Text('·', style: TextStyle(color: AppColors.textSecondary)),
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => _openUrl(AppConstants.privacyUrl),
              child: const Text('Privacy Policy', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildComparisonRow(String feature, String free, String premium) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(feature, style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(flex: 2, child: Text(free, style: const TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center)),
          Expanded(
            flex: 2,
            child: Text(premium, style: const TextStyle(color: AppColors.premium, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCard(ProductDetails? product, String title, String period, bool pending, {bool highlight = false}) {
    final available = product != null;
    return InkWell(
      onTap: (!available || pending)
          ? null
          : () => ref.read(iapServiceProvider).buy(product),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: highlight ? AppColors.premium.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: highlight ? AppColors.premium : AppColors.divider, width: highlight ? 2 : 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(period, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
            pending
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(
                    available ? product.price : '—',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: highlight ? AppColors.premium : AppColors.textPrimary),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitTile(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.premiumLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.premium),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
