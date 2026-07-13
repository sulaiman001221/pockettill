import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/repositories/repositories.dart';
import 'analytics_notifier.dart';

/// Singleton [AnalyticsNotifier] for the Analytics screen.
final analyticsNotifierProvider =
    StateNotifierProvider<AnalyticsNotifier, AnalyticsState>((ref) {
      return AnalyticsNotifier(
        saleRepository: ref.watch(saleRepositoryProvider),
      );
    });
