import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'providers/user_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/consent_screen.dart';
import 'screens/home_screen.dart';
import 'screens/survey_screen.dart';
import 'screens/results_screen.dart';
import 'screens/premium_screen.dart';
import 'screens/wallet_screen.dart';
import 'screens/transactions_screen.dart';
import 'screens/admin/admin_login_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'services/ad_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Fire-and-forget AdMob init. The first ad-request screen handles a
  // not-yet-ready service via the existing isRewardedAdReady / isInterstitialReady
  // checks, so we don't block UI on this. ATT prompt is shown inside
  // initialize() before MobileAds.initialize() — required by Apple.
  unawaited(AdService().initialize());
  runApp(const ProviderScope(child: SurveyRewardsApp()));
}

class SurveyRewardsApp extends ConsumerStatefulWidget {
  const SurveyRewardsApp({super.key});

  @override
  ConsumerState<SurveyRewardsApp> createState() => _SurveyRewardsAppState();
}

class _SurveyRewardsAppState extends ConsumerState<SurveyRewardsApp> {
  @override
  void initState() {
    super.initState();
    ref.read(userProvider.notifier).initialize();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Survey Rewards',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => const SplashScreen(),
        '/consent': (_) => const ConsentScreen(),
        '/home': (_) => const MainShell(),
        '/premium': (_) => const PremiumScreen(),
        '/admin': (_) => const AdminLoginScreen(),
        '/admin/dashboard': (_) => const AdminDashboardScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/survey') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => SurveyScreen(surveyId: args['surveyId'], title: args['title']),
          );
        }
        if (settings.name == '/results') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => ResultsScreen(
              completionId: args['completionId'],
              baseReward: args['baseReward'],
              adMultiplier: args['adMultiplier'],
              premiumMultiplier: args['premiumMultiplier'],
              finalReward: args['finalReward'],
              surveyTitle: args['surveyTitle'],
            ),
          );
        }
        return null;
      },
    );
  }
}

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;

  final _pages = const [
    HomeScreen(),
    WalletScreen(),
    TransactionsScreen(),
    PremiumScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded), label: 'Wallet'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.star_rounded), label: 'Premium'),
        ],
      ),
    );
  }
}
