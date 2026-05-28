import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/iap_service.dart';
import 'user_provider.dart';

final iapServiceProvider = Provider<IapService>((ref) {
  final service = IapService(ref.read(apiServiceProvider));
  // On a backend-confirmed unlock, refresh the user so isPremium flips
  // and the paywall switches to the active-premium view.
  service.onUnlocked = () => ref.read(userProvider.notifier).refresh();
  ref.onDispose(service.dispose);
  service.initialize();
  return service;
});

// Live purchase state (idle / pending / success / error) for the UI.
final iapStateProvider = StreamProvider<IapState>((ref) {
  return ref.watch(iapServiceProvider).stateStream;
});

// Resolves the store products. Surfaces loading/empty/error to the UI so
// the paywall can rebuild when products arrive (the service instance
// itself is stable, so the screen can't watch its mutable fields).
final iapProductsProvider = FutureProvider<List<ProductDetails>>((ref) {
  return ref.watch(iapServiceProvider).initialize();
});
