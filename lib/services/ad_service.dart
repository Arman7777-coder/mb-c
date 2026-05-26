import 'dart:async';
import 'dart:io';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// AdMob configuration.
//
// All ad-unit IDs and the iOS/Android App IDs default to Google's official
// TEST values so dev builds never hit the real publisher account (which
// would risk invalid-traffic flags). Production builds pass real IDs via:
//
//   flutter build ios --release \
//     --dart-define=ADMOB_REWARDED_IOS=ca-app-pub-XXXX/YYYY \
//     --dart-define=ADMOB_INTERSTITIAL_IOS=ca-app-pub-XXXX/YYYY \
//     --dart-define=ADMOB_BANNER_IOS=ca-app-pub-XXXX/YYYY \
//     --dart-define=ADMOB_REWARDED_ANDROID=ca-app-pub-XXXX/YYYY \
//     --dart-define=ADMOB_INTERSTITIAL_ANDROID=ca-app-pub-XXXX/YYYY \
//     --dart-define=ADMOB_BANNER_ANDROID=ca-app-pub-XXXX/YYYY \
//     --dart-define=ADMOB_TEST_DEVICE_IDS=ABCD1234,EFGH5678
//
// The App IDs in ios/Runner/Info.plist (GADApplicationIdentifier) and
// android/app/src/main/AndroidManifest.xml (com.google.android.gms.ads.
// APPLICATION_ID) must be swapped at release time as well — those are
// read by the GMA SDK at process start, before any Dart code runs.

class _AdMobIds {
  // iOS
  static const rewardedIos = String.fromEnvironment(
    'ADMOB_REWARDED_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/1712485313',
  );
  static const interstitialIos = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/4411468910',
  );
  static const bannerIos = String.fromEnvironment(
    'ADMOB_BANNER_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/2934735716',
  );

  // Android
  static const rewardedAndroid = String.fromEnvironment(
    'ADMOB_REWARDED_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/5224354917',
  );
  static const interstitialAndroid = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/1033173712',
  );
  static const bannerAndroid = String.fromEnvironment(
    'ADMOB_BANNER_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/6300978111',
  );

  // Comma-separated list of test device IDs. Required when running a
  // build with PRODUCTION ad-unit IDs against a real device — without
  // it the impressions count as invalid traffic and Google may suspend
  // the AdMob account. Find the device ID in the first ad-request log
  // line: "Use RequestConfiguration.Builder.setTestDeviceIds(...) to
  // get test ads on this device."
  static const testDeviceIdsCsv = String.fromEnvironment(
    'ADMOB_TEST_DEVICE_IDS',
    defaultValue: '',
  );

  static List<String> get testDeviceIds => testDeviceIdsCsv
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

class AdService {
  static final AdService _instance = AdService._();
  factory AdService() => _instance;
  AdService._();

  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;
  bool _isRewardedAdReady = false;
  bool _isInterstitialReady = false;
  bool _initialized = false;
  Completer<void>? _initializing;

  // Exponential backoff with a ceiling so a wedged ad network can't
  // pin us to a tight 30 s retry loop forever (battery + log spam).
  int _rewardedFailCount = 0;
  int _interstitialFailCount = 0;
  static const _maxBackoff = Duration(minutes: 5);

  String get _rewardedAdUnitId =>
      Platform.isAndroid ? _AdMobIds.rewardedAndroid : _AdMobIds.rewardedIos;

  String get _interstitialAdUnitId => Platform.isAndroid
      ? _AdMobIds.interstitialAndroid
      : _AdMobIds.interstitialIos;

  String get _bannerAdUnitId =>
      Platform.isAndroid ? _AdMobIds.bannerAndroid : _AdMobIds.bannerIos;

  bool get isRewardedAdReady => _isRewardedAdReady;
  bool get isInterstitialReady => _isInterstitialReady;

  // Idempotent — safe to call from main() and again from any screen
  // that wants to be defensive. Concurrent callers all await the same
  // in-flight initialization.
  Future<void> initialize() async {
    if (_initialized) return;
    if (_initializing != null) return _initializing!.future;
    final completer = Completer<void>();
    _initializing = completer;

    try {
      // 1. ATT prompt — must run BEFORE MobileAds.initialize() on iOS
      // so the SDK picks up the chosen tracking status. No-op on Android.
      if (Platform.isIOS) {
        await _requestTrackingAuthorization();
      }

      // 2. Register test devices so prod-ID builds tested on dev hardware
      // don't flag the AdMob account.
      if (_AdMobIds.testDeviceIds.isNotEmpty) {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(testDeviceIds: _AdMobIds.testDeviceIds),
        );
      }

      // 3. Initialize the SDK.
      await MobileAds.instance.initialize();
      _initialized = true;

      // 4. Preload first ads. Fire-and-forget — UI shouldn't block on these.
      loadRewardedAd();
      loadInterstitialAd();

      completer.complete();
    } catch (e, st) {
      debugPrint('[AdService] initialize failed: $e\n$st');
      completer.completeError(e, st);
      rethrow;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _requestTrackingAuthorization() async {
    try {
      final status =
          await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        // Apple recommends a small delay so the prompt doesn't collide
        // with the splash transition; without it the system sometimes
        // silently denies (FB-tracked behavior on iOS 17).
        await Future.delayed(const Duration(milliseconds: 250));
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (e) {
      debugPrint('[AdService] ATT request failed (non-fatal): $e');
    }
  }

  Duration _backoffFor(int failCount) {
    // 30 s, 60 s, 120 s, 240 s, capped at _maxBackoff
    final seconds = 30 * (1 << (failCount.clamp(0, 4)));
    final candidate = Duration(seconds: seconds);
    return candidate > _maxBackoff ? _maxBackoff : candidate;
  }

  // ─── Rewarded Ad (for 2x boost) ───

  void loadRewardedAd() {
    if (!_initialized) return;
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdReady = true;
          _rewardedFailCount = 0;
        },
        onAdFailedToLoad: (error) {
          _isRewardedAdReady = false;
          _rewardedFailCount++;
          final wait = _backoffFor(_rewardedFailCount - 1);
          debugPrint(
            '[AdService] rewarded load failed '
            '(code=${error.code} domain=${error.domain} '
            'msg=${error.message}) — retry in ${wait.inSeconds}s '
            '[attempt=$_rewardedFailCount]',
          );
          Future.delayed(wait, loadRewardedAd);
        },
      ),
    );
  }

  Future<bool> showRewardedAd({required Function onRewarded}) async {
    if (!_isRewardedAdReady || _rewardedAd == null) return false;

    bool rewarded = false;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _isRewardedAdReady = false;
        loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint(
          '[AdService] rewarded show failed '
          '(code=${error.code} msg=${error.message})',
        );
        ad.dispose();
        _isRewardedAdReady = false;
        loadRewardedAd();
      },
    );

    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        rewarded = true;
        onRewarded();
      },
    );

    return rewarded;
  }

  // ─── Interstitial Ad (every 5th question) ───

  void loadInterstitialAd() {
    if (!_initialized) return;
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialReady = true;
          _interstitialFailCount = 0;
        },
        onAdFailedToLoad: (error) {
          _isInterstitialReady = false;
          _interstitialFailCount++;
          final wait = _backoffFor(_interstitialFailCount - 1);
          debugPrint(
            '[AdService] interstitial load failed '
            '(code=${error.code} domain=${error.domain} '
            'msg=${error.message}) — retry in ${wait.inSeconds}s '
            '[attempt=$_interstitialFailCount]',
          );
          Future.delayed(wait, loadInterstitialAd);
        },
      ),
    );
  }

  Future<void> showInterstitialAd({Function? onDismissed}) async {
    if (!_isInterstitialReady || _interstitialAd == null) {
      onDismissed?.call();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _isInterstitialReady = false;
        loadInterstitialAd();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint(
          '[AdService] interstitial show failed '
          '(code=${error.code} msg=${error.message})',
        );
        ad.dispose();
        _isInterstitialReady = false;
        loadInterstitialAd();
        onDismissed?.call();
      },
    );

    await _interstitialAd!.show();
  }

  // ─── Banner Ad ───
  //
  // Caller owns the returned BannerAd and MUST call dispose() in the
  // widget's State.dispose() — otherwise the underlying native ad view
  // leaks across rebuilds. Prefer createAdaptiveBannerAd() — Anchored
  // Adaptive has higher fill rate and eCPM than the fixed 320×50 banner.

  // Anchored Adaptive Banner. Picks an optimal height for the given
  // screen width (Google's recommendation; replaces the deprecated
  // smart banner). Returns null on platforms where the SDK can't
  // resolve a size (rare — usually means the screen width is 0 during
  // a transient layout pass; caller should retry on the next frame).
  //
  // The caller passes `onLoaded` so the host widget can flip to its
  // loaded state. BannerAd.listener is final, so it must be supplied
  // at construction — we can't compose after the fact.
  Future<BannerAd?> createAdaptiveBannerAd(
    BuildContext context, {
    required void Function(Ad ad) onLoaded,
  }) async {
    final width = MediaQuery.of(context).size.width.truncate();
    final size = await AdSize.getAnchoredAdaptiveBannerAdSize(
      Orientation.portrait,
      width,
    );
    if (size == null) {
      debugPrint('[AdService] adaptive banner size unavailable (width=$width)');
      return null;
    }
    return BannerAd(
      adUnitId: _bannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: onLoaded,
        onAdFailedToLoad: (ad, error) {
          debugPrint(
            '[AdService] banner load failed '
            '(code=${error.code} domain=${error.domain} '
            'msg=${error.message})',
          );
          ad.dispose();
        },
      ),
    );
  }

  void dispose() {
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
  }
}
