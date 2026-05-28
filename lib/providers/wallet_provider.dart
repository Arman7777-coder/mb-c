import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction.dart';
import '../models/redemption.dart';
import 'user_provider.dart';

final walletProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  await awaitRegisteredUser(ref);
  final api = ref.read(apiServiceProvider);
  return await api.getWallet();
});

final transactionsProvider = FutureProvider<List<AppTransaction>>((ref) async {
  await awaitRegisteredUser(ref);
  final api = ref.read(apiServiceProvider);
  final data = await api.getTransactions();
  return data.map((t) => AppTransaction.fromJson(t)).toList();
});

final redemptionsProvider = FutureProvider<List<Redemption>>((ref) async {
  await awaitRegisteredUser(ref);
  final api = ref.read(apiServiceProvider);
  final data = await api.getRedemptions();
  return data.map((r) => Redemption.fromJson(r)).toList();
});
