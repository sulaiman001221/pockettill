import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../../core/database/isar_service.dart';
import '../../core/sync/event_queue.dart';
import 'credit_repository.dart';
import 'extra_income_repository.dart';
import 'product_repository.dart';
import 'return_repository.dart';
import 'risk_log_repository.dart';
import 'sale_repository.dart';
import 'store_config_repository.dart';

/// The singleton Isar instance repositories depend on. Backed by the same
/// [IsarService.db] singleton that core/sync's `isarProvider` also exposes -
/// this one exists so the repository layer doesn't have to reach into
/// core/sync for it.
final isarServiceProvider = Provider<Isar>((ref) => IsarService.db);

/// The shared [EventQueue] every repository enqueues [SyncEvent]s through.
final eventQueueProvider = Provider<EventQueue>((ref) {
  return EventQueue(ref.watch(isarServiceProvider));
});

/// [ProductRepository] singleton.
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(
    isar: ref.watch(isarServiceProvider),
    eventQueue: ref.watch(eventQueueProvider),
    riskLog: ref.watch(riskLogRepositoryProvider),
  );
});

/// [CreditRepository] singleton.
final creditRepositoryProvider = Provider<CreditRepository>((ref) {
  return CreditRepository(
    isar: ref.watch(isarServiceProvider),
    eventQueue: ref.watch(eventQueueProvider),
    riskLog: ref.watch(riskLogRepositoryProvider),
  );
});

/// [SaleRepository] singleton.
final saleRepositoryProvider = Provider<SaleRepository>((ref) {
  return SaleRepository(isar: ref.watch(isarServiceProvider));
});

/// [ReturnRepository] singleton.
final returnRepositoryProvider = Provider<ReturnRepository>((ref) {
  return ReturnRepository(isar: ref.watch(isarServiceProvider));
});

/// [StoreConfigRepository] singleton.
final storeConfigRepositoryProvider = Provider<StoreConfigRepository>((ref) {
  return StoreConfigRepository(isar: ref.watch(isarServiceProvider));
});

/// [ExtraIncomeRepository] singleton.
final extraIncomeRepositoryProvider = Provider<ExtraIncomeRepository>((ref) {
  return ExtraIncomeRepository(
    isar: ref.watch(isarServiceProvider),
    eventQueue: ref.watch(eventQueueProvider),
  );
});

/// [RiskLogRepository] singleton.
final riskLogRepositoryProvider = Provider<RiskLogRepository>((ref) {
  return RiskLogRepository(
    isar: ref.watch(isarServiceProvider),
    eventQueue: ref.watch(eventQueueProvider),
  );
});
