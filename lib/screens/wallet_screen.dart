import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/user_provider.dart';
import '../providers/wallet_provider.dart';
import '../models/redemption.dart';
import '../utils/constants.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProvider);
    final redemptionsAsync = ref.watch(redemptionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(walletProvider);
          ref.invalidate(redemptionsProvider);
          await ref.read(userProvider.notifier).refresh();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            userAsync.when(
              data: (user) {
                if (user == null) return const SizedBox.shrink();
                return _buildBalanceSection(user.balance);
              },
              loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),
            const Text('Payout Options', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildPayoutOption('PayPal', Icons.payment, 'Cash out to your PayPal', 'paypal'),
            _buildPayoutOption('Amazon Gift Card', Icons.card_giftcard, 'Redeem for Amazon credit', 'amazon_gift_card'),
            _buildPayoutOption('Crypto (BTC/USDT)', Icons.currency_bitcoin, 'Withdraw to your wallet', 'crypto'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.premiumLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.premium, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Minimum redemption: 5,000 points (\$5.00). Requests are reviewed within 48 hours. Not instant withdrawals.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Redemption History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            redemptionsAsync.when(
              data: (list) => list.isEmpty
                  ? _buildEmptyRedemptions()
                  : Column(children: list.map((r) => _buildRedemptionTile(r)).toList()),
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
              error: (e, _) => Text('Error: $e'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceSection(int balance) {
    final dollars = balance / AppConstants.pointsPerDollar;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text('Available Balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text('\$${dollars.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
          Text('${NumberFormat('#,###').format(balance)} points', style: const TextStyle(color: Colors.white60, fontSize: 14)),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: (balance / AppConstants.minimumRedemption).clamp(0, 1).toDouble(),
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation(Colors.white),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 6),
          Text(
            balance >= AppConstants.minimumRedemption
                ? 'Ready to redeem!'
                : '${AppConstants.minimumRedemption - balance} more points to redeem',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutOption(String title, IconData icon, String subtitle, String method) {
    final userAsync = ref.read(userProvider);
    final balance = userAsync.valueOrNull?.balance ?? 0;
    final canRedeem = balance >= AppConstants.minimumRedemption;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: canRedeem ? () => _showRedeemDialog(method, title, balance) : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary),
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
              Icon(Icons.arrow_forward_ios, size: 16, color: canRedeem ? AppColors.primary : AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyRedemptions() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: const Column(
        children: [
          Icon(Icons.receipt_long, size: 48, color: AppColors.textSecondary),
          SizedBox(height: 12),
          Text('No redemptions yet', style: TextStyle(color: AppColors.textSecondary)),
          Text('Complete surveys to earn points!', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildRedemptionTile(Redemption r) {
    Color statusColor;
    switch (r.status) {
      case 'pending':
        statusColor = AppColors.premium;
        break;
      case 'approved':
        statusColor = AppColors.earnings;
        break;
      case 'rejected':
        statusColor = AppColors.error;
        break;
      default:
        statusColor = AppColors.textSecondary;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.methodLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('\$${r.dollarValue.toStringAsFixed(2)} (${NumberFormat('#,###').format(r.amount)} pts)',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  Text(DateFormat('MMM d, yyyy').format(r.createdAt),
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(r.statusLabel, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _showRedeemDialog(String method, String title, int balance) {
    final amountController = TextEditingController(text: '5000');
    final detailController = TextEditingController();
    String detailLabel;
    String detailHint;

    switch (method) {
      case 'paypal':
        detailLabel = 'PayPal Email';
        detailHint = 'your@email.com';
        break;
      case 'crypto':
        detailLabel = 'Wallet Address';
        detailHint = '0x... or bc1...';
        break;
      default:
        detailLabel = 'Email';
        detailHint = 'your@email.com';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Redeem via $title', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Points to redeem',
                helperText: 'Min 5,000 pts (\$5.00). Your balance: ${NumberFormat('#,###').format(balance)}',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: detailController,
              decoration: InputDecoration(labelText: detailLabel, hintText: detailHint),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  final amount = int.tryParse(amountController.text) ?? 0;
                  if (amount < 5000) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Minimum is 5,000 points')));
                    return;
                  }
                  Navigator.pop(ctx);
                  try {
                    final api = ref.read(apiServiceProvider);
                    await api.requestRedemption(amount, method, {
                      if (method == 'paypal') 'email': detailController.text,
                      if (method == 'crypto') 'wallet_address': detailController.text,
                      if (method == 'amazon_gift_card') 'email': detailController.text,
                    });
                    ref.invalidate(redemptionsProvider);
                    ref.invalidate(walletProvider);
                    ref.read(userProvider.notifier).refresh();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Redemption request submitted! Review within 48 hours.'), backgroundColor: AppColors.earnings),
                      );
                    }
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.error));
                  }
                },
                child: const Text('Submit Request'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
