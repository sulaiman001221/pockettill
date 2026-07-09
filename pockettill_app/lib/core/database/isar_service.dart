import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../../shared/models/credit_customer.dart';
import '../../shared/models/credit_transaction.dart';
import '../../shared/models/product.dart';
import '../../shared/models/sale.dart';
import '../../shared/models/sale_item.dart';
import '../../shared/models/store_config.dart';
import '../../shared/models/sync_event.dart';

/// Owns the single [Isar] instance used for all local reads/writes.
///
/// PocketTill is offline-first: every read and write goes through [db]
/// first, never Supabase directly.
class IsarService {
  IsarService._();

  static Isar? _instance;

  /// The singleton Isar database. [init] must be called before this is used.
  static Isar get db {
    final instance = _instance;
    if (instance == null) {
      throw StateError('IsarService.init() must be called before use.');
    }
    return instance;
  }

  /// Opens the Isar database in the app's documents directory.
  static Future<void> init() async {
    if (_instance != null) return;
    final directory = await getApplicationDocumentsDirectory();
    _instance = await Isar.open(
      [
        ProductSchema,
        SaleSchema,
        SaleItemSchema,
        CreditCustomerSchema,
        CreditTransactionSchema,
        SyncEventSchema,
        StoreConfigSchema,
      ],
      directory: directory.path,
    );
  }
}

/// The singleton [Isar] instance. [IsarService.init] must be called before
/// this provider is read.
final isarProvider = Provider<Isar>((ref) => IsarService.db);
