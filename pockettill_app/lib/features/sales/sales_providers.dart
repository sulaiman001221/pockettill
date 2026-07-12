import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/repositories/repositories.dart';
import 'sales_notifier.dart';
import 'sales_state.dart';

/// Singleton [SalesNotifier] for the in-progress sale.
final salesNotifierProvider =
    StateNotifierProvider<SalesNotifier, SalesState>((ref) {
      return SalesNotifier(ref.watch(productRepositoryProvider));
    });
