import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/analytics/analytics_providers.dart';
import '../../features/history/history_providers.dart';
import '../../features/sales/sales_providers.dart';
import '../../features/stock/risk_log_providers.dart';

/// Invalidates every cached provider whose data is scoped to "whichever
/// store is currently logged in" - call this right after a login,
/// registration, or device-verification completes, alongside
/// storeConfigProvider's own refresh.
///
/// Without it, a provider that already resolved once (e.g. Sales History's
/// filtered lists) keeps showing the previous store's cached data until
/// something else happens to trigger a refetch (a pull-to-refresh, a date
/// filter change) - confusing right after switching accounts on the same
/// device, since the data on screen belongs to a store you're no longer
/// logged into.
///
/// Add any new store-scoped provider here when it's created - the same way
/// a new local-only Isar collection needs adding to every store-switch
/// clear list in `AuthService`.
void invalidateStoreScopedProviders(WidgetRef ref) {
  ref.invalidate(filteredSalesProvider);
  ref.invalidate(filteredReturnsProvider);
  ref.invalidate(filteredExtraIncomeProvider);
  ref.invalidate(filteredRiskLogProvider);
  invalidateAllEndOfDayCaches(ref);
  // The in-progress sale (cart) is a StateNotifierProvider, not a fetched
  // list - invalidating it discards whatever's currently in the cart and
  // creates a fresh, empty one. Without this, adding items to a cart and
  // then switching accounts carried that cart into the new account: not
  // just stale display, an actual wrong-store sale waiting to be
  // completed against the wrong products. Found 2026-08-23.
  ref.invalidate(salesNotifierProvider);
  // Same shape of bug for Analytics: a StateNotifierProvider that loads
  // once in its constructor and never refetches on its own.
  ref.invalidate(analyticsNotifierProvider);
}
