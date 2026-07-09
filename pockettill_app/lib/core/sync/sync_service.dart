/// Drains the `SyncEvent` queue to Supabase in batches when [ReachabilityService]
/// confirms connectivity, in priority order: credit transactions, sales,
/// stock, then catalogue contributions.
///
/// Depends on the `SyncEvent` Isar collection introduced in Stage 2 - left
/// unimplemented until that schema exists.
