import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/store_config.dart';
import 'repositories.dart';
import 'store_config_repository.dart';

/// The current [StoreConfig], reactively, for widgets that need to repaint
/// when it changes (drawer store name, Settings, founding-store badge)
/// without each owning its own load/refresh plumbing.
class StoreConfigNotifier extends StateNotifier<StoreConfig?> {
  StoreConfigNotifier(this._repo) : super(null) {
    _load();
  }

  final StoreConfigRepository _repo;

  Future<void> _load() async {
    state = await _repo.get();
  }

  /// Re-reads from Isar - call after registration, login, logout, or any
  /// Settings edit that saves a new [StoreConfig].
  Future<void> refresh() => _load();
}

final storeConfigProvider =
    StateNotifierProvider<StoreConfigNotifier, StoreConfig?>((ref) {
      return StoreConfigNotifier(ref.watch(storeConfigRepositoryProvider));
    });
