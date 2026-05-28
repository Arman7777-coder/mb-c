#!/usr/bin/env bash
#
# Release build for iOS with PRODUCTION AdMob ad-unit IDs.
#
# DO NOT run this for day-to-day dev/QA — plain `flutter run` keeps Google's
# test IDs (see lib/services/ad_service.dart defaults), which is what you
# want until the app is published and the AdMob app clears review. Running
# prod IDs on dev hardware risks invalid-traffic flags on the AdMob account.
#
# Before a genuine production build you must ALSO swap the app-level App ID,
# which is native config the SDK reads at process start and CANNOT be passed
# via --dart-define:
#
#   ios/Runner/Info.plist  -> GADApplicationIdentifier
#       prod iOS App ID: ca-app-pub-8330591906342449~4986991572
#       (currently set to Google's test App ID ~1458002511)
#
# Usage:
#   ADMOB_TEST_DEVICE_IDS=AAAA,BBBB ./scripts/build_release_ios.sh
#
# Pass the device IDs of any phones you test the prod build on (printed in
# the first ad-request log line) so your own impressions are not counted as
# invalid traffic.

set -euo pipefail

# ── iOS production ad-unit IDs (AdMob app ~4986991572) ──
ADMOB_BANNER_IOS="ca-app-pub-8330591906342449/1980257117"
ADMOB_INTERSTITIAL_IOS="ca-app-pub-8330591906342449/1273680102"
ADMOB_REWARDED_IOS="ca-app-pub-8330591906342449/3482560950"

TEST_DEVICES="${ADMOB_TEST_DEVICE_IDS:-}"

echo "Building iOS release with PROD AdMob unit IDs:"
echo "  banner       = $ADMOB_BANNER_IOS"
echo "  interstitial = $ADMOB_INTERSTITIAL_IOS"
echo "  rewarded     = $ADMOB_REWARDED_IOS"
echo "  test devices = ${TEST_DEVICES:-<none>}"
echo "Reminder: confirm Info.plist GADApplicationIdentifier is the prod App ID."

flutter build ipa --release \
  --dart-define=ADMOB_BANNER_IOS="$ADMOB_BANNER_IOS" \
  --dart-define=ADMOB_INTERSTITIAL_IOS="$ADMOB_INTERSTITIAL_IOS" \
  --dart-define=ADMOB_REWARDED_IOS="$ADMOB_REWARDED_IOS" \
  --dart-define=ADMOB_TEST_DEVICE_IDS="$TEST_DEVICES"
