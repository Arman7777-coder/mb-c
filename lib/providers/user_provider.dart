import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());
final deviceServiceProvider = Provider<DeviceService>((ref) => DeviceService());

// Suspends a dependent provider until the device is registered (the user is
// loaded), so calls needing the X-Device-ID header don't race registration.
// While the user is still loading, returns a future that never completes —
// the dependent provider re-runs when userProvider updates. No-op once the
// user is already loaded (the normal splash → home path).
Future<AppUser> awaitRegisteredUser(Ref ref) {
  final state = ref.watch(userProvider);
  return state.when(
    data: (u) =>
        u != null ? Future.value(u) : Completer<AppUser>().future,
    loading: () => Completer<AppUser>().future,
    error: (e, st) => Future.error(e, st),
  );
}

final userProvider = StateNotifierProvider<UserNotifier, AsyncValue<AppUser?>>((ref) {
  return UserNotifier(ref.read(apiServiceProvider), ref.read(deviceServiceProvider));
});

class UserNotifier extends StateNotifier<AsyncValue<AppUser?>> {
  final ApiService _api;
  final DeviceService _device;

  UserNotifier(this._api, this._device) : super(const AsyncValue.loading());

  Future<void> initialize() async {
    try {
      final deviceId = await _device.getOrCreateDeviceId();
      _api.setDeviceId(deviceId);
      final data = await _api.register(deviceId);
      state = AsyncValue.data(AppUser.fromJson(data));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateConsent(bool consent, bool age) async {
    try {
      final data = await _api.updateConsent(consent, age);
      await _device.setConsent(true);
      state = AsyncValue.data(AppUser.fromJson(data));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    try {
      final deviceId = await _device.getOrCreateDeviceId();
      final data = await _api.register(deviceId);
      state = AsyncValue.data(AppUser.fromJson(data));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
