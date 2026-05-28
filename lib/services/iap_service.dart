import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'api_service.dart';

class IapProducts {
  static const monthly = 'com.surveyrewards.premium.monthly';
  static const yearly = 'com.surveyrewards.premium.yearly';
  static const ids = {monthly, yearly};

  // Maps a store product ID to the backend plan string accepted by
  // /api/premium/activate.
  static String planFor(String productId) =>
      productId == yearly ? 'yearly' : 'monthly';
}

enum IapPhase { idle, pending, success, error }

@immutable
class IapState {
  final IapPhase phase;
  final String? message;
  // Product ID currently being purchased — lets the UI show a spinner on
  // the specific plan card rather than the whole screen.
  final String? activeProductId;

  const IapState({
    this.phase = IapPhase.idle,
    this.message,
    this.activeProductId,
  });
}

// Wraps the official in_app_purchase plugin. Receipt validation is
// delegated to the backend: on a purchased/restored transaction we POST
// the receipt to /api/premium/verify and only call completePurchase()
// once the backend confirms — a failed validation leaves the transaction
// pending so the store redelivers it on the next launch.
class IapService {
  IapService(this._api);

  final ApiService _api;
  final InAppPurchase _iap = InAppPurchase.instance;

  // When true, the store receipt is sent to /api/premium/verify and the
  // backend validates it with Apple/Google before premium is granted.
  // When false, we fall back to the existing /api/premium/activate, which
  // trusts the client (no receipt validation). Flip to true once the
  // backend verify endpoint is live. SECURITY: false is insecure — a
  // client can claim premium without paying. Acceptable for TestFlight /
  // first launch only.
  static const bool requireServerVerification = false;

  StreamSubscription<List<PurchaseDetails>>? _sub;
  final _stateController = StreamController<IapState>.broadcast();
  // Called after the backend confirms an unlock so callers can refresh
  // user state (flips isPremium → switches the UI to the active view).
  void Function()? onUnlocked;

  List<ProductDetails> _products = const [];
  List<ProductDetails> get products => _products;

  Stream<IapState> get stateStream => _stateController.stream;

  bool _available = false;
  bool get isAvailable => _available;

  // Cached so initialize() is idempotent and product-fetching callers
  // (the FutureProvider) can await the same in-flight init.
  Future<List<ProductDetails>>? _initFuture;

  Future<List<ProductDetails>> initialize() => _initFuture ??= _doInitialize();

  Future<List<ProductDetails>> _doInitialize() async {
    _available = await _iap.isAvailable();
    if (!_available) {
      debugPrint('[IapService] store not available on this device');
      return const [];
    }
    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (e) => debugPrint('[IapService] purchaseStream error: $e'),
    );
    return queryProducts();
  }

  Future<List<ProductDetails>> queryProducts() async {
    if (!_available) return const [];
    final resp = await _iap.queryProductDetails(IapProducts.ids);
    if (resp.error != null) {
      debugPrint('[IapService] queryProductDetails error: ${resp.error}');
    }
    if (resp.notFoundIDs.isNotEmpty) {
      // Almost always a store-config issue: product not in "Ready to
      // Submit", or bundle ID / signing mismatch.
      debugPrint('[IapService] products not found: ${resp.notFoundIDs}');
    }
    _products = resp.productDetails;
    return _products;
  }

  Future<void> buy(ProductDetails product) async {
    if (!_available) {
      _emit(IapPhase.error, message: 'Store unavailable on this device.');
      return;
    }
    _emit(IapPhase.pending, activeProductId: product.id);
    final param = PurchaseParam(productDetails: product);
    try {
      // Auto-renewable subscriptions go through the non-consumable path.
      await _iap.buyNonConsumable(purchaseParam: param);
    } catch (e) {
      _emit(IapPhase.error, message: 'Could not start purchase: $e');
    }
  }

  Future<void> restore() async {
    if (!_available) {
      _emit(IapPhase.error, message: 'Store unavailable on this device.');
      return;
    }
    _emit(IapPhase.pending);
    await _iap.restorePurchases();
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          _emit(IapPhase.pending, activeProductId: p.productID);
          break;
        case PurchaseStatus.canceled:
          _emit(IapPhase.idle);
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          break;
        case PurchaseStatus.error:
          _emit(IapPhase.error,
              message: p.error?.message ?? 'Purchase failed.');
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyAndComplete(p);
          break;
      }
    }
  }

  Future<void> _verifyAndComplete(PurchaseDetails p) async {
    try {
      if (requireServerVerification) {
        await _api.verifyPremiumPurchase(
          platform: Platform.isIOS ? 'ios' : 'android',
          productId: p.productID,
          receipt: p.verificationData.serverVerificationData,
        );
      } else {
        // Client-trusted fallback: grant premium via the existing endpoint
        // without receipt validation. See requireServerVerification.
        await _api.activatePremium(IapProducts.planFor(p.productID));
      }
      // Only finish the transaction once the backend has granted premium.
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
      _emit(IapPhase.success);
      onUnlocked?.call();
    } catch (e) {
      // Leave the transaction pending (do NOT complete) so the store
      // redelivers it and we can retry next launch.
      debugPrint('[IapService] unlock failed, left pending: $e');
      _emit(IapPhase.error,
          message: 'Purchase succeeded but unlock is pending. '
              'It will retry automatically.');
    }
  }

  void _emit(IapPhase phase, {String? message, String? activeProductId}) {
    if (_stateController.isClosed) return;
    _stateController.add(IapState(
      phase: phase,
      message: message,
      activeProductId: activeProductId,
    ));
  }

  void dispose() {
    _sub?.cancel();
    _stateController.close();
  }
}
