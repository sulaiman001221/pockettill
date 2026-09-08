import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/supabase/supabase_service.dart';
import '../../shared/repositories/repositories.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/pockettill_app_bar.dart';

/// Every device that's ever logged into this store, with a per-device
/// remote "Log out" action - the explicit replacement for the old
/// forced-single-active-device behaviour (see auth_service.dart's
/// `_completeLogin`, 2026-09-09). Logging out a device here just clears its
/// `devices.verified_at`; that device's own next sync/app-open notices via
/// `SyncService.displacedByAnotherDevice` (fed by
/// `SupabaseService.isThisDeviceRevoked`) and gets challenged with OTP
/// again, same as a genuinely new device - there's no separate "kick"
/// mechanism to build, this reuses the device-trust check that already
/// exists.
class ActiveDevicesScreen extends ConsumerStatefulWidget {
  const ActiveDevicesScreen({super.key});

  @override
  ConsumerState<ActiveDevicesScreen> createState() =>
      _ActiveDevicesScreenState();
}

class _ActiveDevicesScreenState extends ConsumerState<ActiveDevicesScreen> {
  List<Map<String, dynamic>> _devices = [];
  String? _thisDeviceId;
  bool _loading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });

    final config = await ref.read(storeConfigRepositoryProvider).get();
    if (config == null || config.storeId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    _thisDeviceId = config.deviceId;

    try {
      final rows = await SupabaseService.fetchStoreDevices(config.storeId);
      if (!mounted) return;
      setState(() {
        _devices = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadFailed = true;
        _loading = false;
      });
    }
  }

  String _deviceLabel(Map<String, dynamic> device) {
    final name = device['device_name'] as String?;
    if (name != null && name.trim().isNotEmpty) return name;
    final id = device['id'] as String? ?? '';
    return id.length > 12 ? '${id.substring(0, 12)}...' : id;
  }

  String _lastActiveLabel(Map<String, dynamic> device) {
    final raw = device['last_seen_at'] as String?;
    if (raw == null) return 'Never synced';
    final lastSeen = DateTime.parse(raw).toLocal();
    final elapsed = DateTime.now().difference(lastSeen);
    if (elapsed.inMinutes < 1) return 'Active just now';
    if (elapsed.inHours < 1) return 'Active ${elapsed.inMinutes}m ago';
    if (elapsed.inDays < 1) return 'Active ${elapsed.inHours}h ago';
    return 'Last active ${DateFormat('d MMM, HH:mm').format(lastSeen)}';
  }

  void _confirmRevoke(Map<String, dynamic> device) {
    showDialog<void>(
      context: context,
      builder: (_) => ConfirmationDialog(
        message:
            'Log out "${_deviceLabel(device)}"? That device will need to '
            'verify with a code the next time it opens the app.',
        confirmLabel: 'Log Out Device',
        confirmColor: AppTheme.logoutRed,
        onConfirm: () => _revoke(device),
      ),
    );
  }

  Future<void> _revoke(Map<String, dynamic> device) async {
    final config = await ref.read(storeConfigRepositoryProvider).get();
    if (config == null) return;
    try {
      await SupabaseService.revokeDevice(
        storeId: config.storeId,
        deviceId: device['id'] as String,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_deviceLabel(device)} logged out')),
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not log out that device. Try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        showMenuIcon: false,
        title: 'Active Devices',
      ),
      backgroundColor: AppTheme.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadFailed
          ? _ErrorState(onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  const Text(
                    'Every device that has logged into this store. Log out '
                    'any device you no longer recognise or use.',
                    style: AppTheme.bodySubtitle,
                  ),
                  const SizedBox(height: 16),
                  for (final device in _devices) ...[
                    _DeviceCard(
                      label: _deviceLabel(device),
                      lastActiveLabel: _lastActiveLabel(device),
                      isThisDevice: device['id'] == _thisDeviceId,
                      onLogOut: () => _confirmRevoke(device),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.label,
    required this.lastActiveLabel,
    required this.isThisDevice,
    required this.onLogOut,
  });

  final String label;
  final String lastActiveLabel;
  final bool isThisDevice;
  final VoidCallback onLogOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.divider,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.smartphone_outlined,
              color: AppTheme.iconBorder,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    if (isThisDevice) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: const Text(
                          'This Device',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  lastActiveLabel,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // A device can't remotely log itself out here - it's already
          // sitting in front of whoever would tap it; Settings' own
          // "Logout" (drawer/account card) is the right action for that.
          if (!isThisDevice)
            TextButton(
              onPressed: onLogOut,
              child: const Text(
                'Log Out',
                style: TextStyle(color: AppTheme.logoutRed),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off,
              size: 48,
              color: AppTheme.iconBorder,
            ),
            const SizedBox(height: 12),
            const Text('Could not load devices', style: AppTheme.mainTitle),
            const SizedBox(height: 8),
            const Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: AppTheme.bodySubtitle,
            ),
            const SizedBox(height: 20),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
