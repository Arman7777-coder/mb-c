import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../services/device_service.dart';
import '../services/ad_service.dart';
import '../providers/user_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this);
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.6, curve: Curves.easeOut)),
    );
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, 0.8, curve: Curves.easeOut)),
    );
    _controller.forward();
    _checkNavigation();
  }

  Future<void> _checkNavigation() async {
    await AdService().initialize();
    // Wait until device registration finishes before leaving splash.
    // The consent screen's "Get Started" calls /api/auth/consent with
    // X-Device-ID, which is only set on ApiService once register()
    // resolves. Navigating sooner (the old fixed 2 s delay) lets the
    // user reach consent before that header exists — which is what
    // trapped App Review on the iPad. Capped so a backend outage still
    // lets them through to retry instead of trapping them on splash.
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (mounted && DateTime.now().isBefore(deadline)) {
      final state = ref.read(userProvider);
      if (state.hasError) break;
      if (state.hasValue && state.value != null) break;
      await Future.delayed(const Duration(milliseconds: 150));
    }
    if (!mounted) return;
    final device = DeviceService();
    final hasConsent = await device.hasConsent();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, hasConsent ? '/home' : '/consent');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.primaryDark, Color(0xFF4A42C0)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: SlideTransition(
              position: _slideUp,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.poll_rounded, size: 60, color: AppColors.primary),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Survey Rewards',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Share your opinion. Earn rewards.',
                    style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.8)),
                  ),
                  const SizedBox(height: 48),
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
