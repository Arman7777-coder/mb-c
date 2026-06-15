import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shows a popup that promotes the premium subscription. Used wherever a free
/// user hits a gate that premium removes (e.g. tapping a locked survey, or
/// wanting to skip the cooldown wait). Tapping "Upgrade to Premium" routes to
/// the full paywall at `/premium`.
Future<void> showPremiumUpsellDialog(
  BuildContext context, {
  String title = 'Unlock with Premium',
  String message = 'Go Premium to remove wait times and earn rewards faster.',
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.premiumLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.star_rounded, color: AppColors.premium, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _benefit(Icons.timer_off_rounded, 'No wait time', 'Skip the 8-hour cooldown'),
          _benefit(Icons.bolt, '1.5× rewards', 'Earn 50% more on every survey'),
          _benefit(Icons.add_circle_outline, '3 bonus surveys/day', 'Take more surveys, sooner'),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      actions: [
        Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  Navigator.pushNamed(context, '/premium');
                },
                child: const Text('Upgrade to Premium'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Maybe Later', style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _benefit(IconData icon, String title, String subtitle) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Icon(icon, color: AppColors.premium, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    ),
  );
}
