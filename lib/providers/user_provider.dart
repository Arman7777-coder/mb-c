import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());
final deviceServiceProvider = Provider<DeviceService>((ref) => DeviceService());

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
