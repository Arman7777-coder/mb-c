import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/user_provider.dart';

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  bool _loading = false;

  Future<void> _activate(String plan) async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.activatePremium(plan);
      await ref.read(userProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Premium activated!'), backgroundColor: AppColors.earnings),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProvider);

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
                  'Expires: ${DateFormat('MMM d, yyyy').format(user.premiumExpiresAt!)}',
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
      ],
    );
  }

  Widget _buildUpgradeView() {
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
        _buildPricingCard('Monthly', '\$4.99', '/month', 'monthly'),
        const SizedBox(height: 12),
        _buildPricingCard('Yearly', '\$29.99', '/year (save 50%)', 'yearly', highlight: true),
        const SizedBox(height: 16),
        const Text(
          'This is a placeholder for in-app subscription integration. In production, this would use Google Play Billing / Apple In-App Purchases.',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
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

  Widget _buildPricingCard(String title, String price, String period, String plan, {bool highlight = false}) {
    return InkWell(
      onTap: _loading ? null : () => _activate(plan),
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
            _loading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(price, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: highlight ? AppColors.premium : AppColors.textPrimary)),
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
