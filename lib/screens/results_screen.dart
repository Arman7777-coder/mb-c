import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:confetti/confetti.dart';
import '../theme/app_theme.dart';
import '../providers/user_provider.dart';
import '../services/ad_service.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  final String completionId;
  final int baseReward;
  final double adMultiplier;
  final double premiumMultiplier;
  final int finalReward;
  final String surveyTitle;

  const ResultsScreen({
    super.key,
    required this.completionId,
    required this.baseReward,
    required this.adMultiplier,
    required this.premiumMultiplier,
    required this.finalReward,
    required this.surveyTitle,
  });

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> with SingleTickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  bool _adApplied = false;
  int _displayReward = 0;
  bool _applyingAd = false;

  @override
  void initState() {
    super.initState();
    _displayReward = widget.finalReward;
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _animController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _scaleAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );
    Future.delayed(const Duration(milliseconds: 300), () {
      _confettiController.play();
      _animController.forward();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _applyAdBoost() async {
    setState(() => _applyingAd = true);
    final adService = AdService();

    if (!adService.isRewardedAdReady) {
      setState(() => _applyingAd = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ad not ready yet. Try again in a moment.')),
        );
      }
      return;
    }

    await adService.showRewardedAd(
      onRewarded: () async {
        try {
          final api = ref.read(apiServiceProvider);
          final result = await api.applyAdReward(widget.completionId);
          if (mounted) {
            setState(() {
              _adApplied = true;
              _displayReward = result['new_total'];
              _applyingAd = false;
            });
            _confettiController.play();
            ref.read(userProvider.notifier).refresh();
          }
        } catch (e) {
          if (mounted) {
            setState(() => _applyingAd = false);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
          }
        }
      },
    );

    if (!_adApplied && mounted) {
      setState(() => _applyingAd = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  ScaleTransition(
                    scale: _scaleAnim,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.earningsLight,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppColors.earnings.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
                      ),
                      child: const Icon(Icons.celebration_rounded, size: 50, color: AppColors.earnings),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Survey Complete!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(widget.surveyTitle, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary), textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      children: [
                        const Text('You earned', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                        const SizedBox(height: 8),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            '+$_displayReward',
                            key: ValueKey(_displayReward),
                            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AppColors.earnings),
                          ),
                        ),
                        const Text('points', style: TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 12),
                        _buildRewardRow('Base reward', '+${widget.baseReward}'),
                        if (widget.premiumMultiplier > 1)
                          _buildRewardRow('Premium boost', '×${widget.premiumMultiplier.toStringAsFixed(1)}', color: AppColors.premium),
                        if (_adApplied || widget.adMultiplier > 1)
                          _buildRewardRow('Ad boost', '×2.0', color: AppColors.primary),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (!_adApplied && widget.adMultiplier <= 1)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _applyingAd ? null : _applyAdBoost,
                        icon: _applyingAd
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.play_circle_outline),
                        label: const Text('Watch Ad for 2× Boost'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false),
                      child: const Text('Back to Home'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 30,
              maxBlastForce: 20,
              minBlastForce: 5,
              gravity: 0.3,
              colors: const [AppColors.primary, AppColors.earnings, AppColors.premium, Colors.pink, Colors.blue],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color ?? AppColors.earnings, fontSize: 14)),
        ],
      ),
    );
  }
}
