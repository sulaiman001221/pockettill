import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/auth/auth_service.dart';
import '../../core/hardware/hardware_detector.dart';
import '../../core/supabase/supabase_service.dart';
import '../../core/sync/sync_service.dart';
import '../../core/sync/sync_status_provider.dart';
import '../../shared/models/store_config.dart';
import '../../shared/models/sync_event.dart';
import '../../shared/repositories/repositories.dart';
import '../../shared/repositories/store_config_provider.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/contact_support.dart';
import '../../shared/utils/sync_status.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/pockettill_app_bar.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';
import '../auth/welcome_screen.dart';

/// "Today, 09:41 AM" / "Yesterday, 09:41 AM" / "12 Oct, 09:41 AM" / "Never".
String _formatLastSynced(DateTime? lastSyncedAt) {
  if (lastSyncedAt == null) return 'Never';

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final syncedDay = DateTime(
    lastSyncedAt.year,
    lastSyncedAt.month,
    lastSyncedAt.day,
  );
  final timeText = DateFormat('hh:mm a').format(lastSyncedAt);

  if (syncedDay == today) return 'Today, $timeText';
  if (syncedDay == today.subtract(const Duration(days: 1))) {
    return 'Yesterday, $timeText';
  }
  return '${DateFormat('dd MMM').format(lastSyncedAt)}, $timeText';
}

/// Store profile, sync, device info, and support. All store-profile writes
/// go through [storeConfigRepositoryProvider] - never directly to Isar.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  StoreConfig? _config;
  bool _loading = true;

  _FoundingProgress? _foundingProgress;
  bool _foundingProgressLoading = false;
  bool _checkingStatus = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    // By the time Settings is reachable, SplashScreen has already gated
    // entry behind registration/login, so a real StoreConfig (with a
    // storeId matching a genuine `stores` row) always exists - this never
    // fabricates a placeholder one, since a locally-invented storeId would
    // violate the store_id foreign key on every synced table.
    final config = await ref.read(storeConfigRepositoryProvider).get();
    if (!mounted) return;
    setState(() {
      _config = config;
      _loading = false;
    });

    if (config != null && !config.isBetaAdopter && config.storeId.isNotEmpty) {
      unawaited(_loadFoundingProgress());
    }
  }

  Future<Map<String, dynamic>> _fetchQualification(String storeId) {
    return SupabaseService.supabaseClient
        .rpc(
          'check_founding_store_qualification',
          params: {'store_uuid': storeId},
        )
        .single();
  }

  /// Flips the local badge on the moment a check (silent or manual) reports
  /// qualification, so the UI doesn't wait for a future app open to catch
  /// up with what Supabase already decided.
  Future<void> _persistIfQualified(_FoundingProgress progress) async {
    final config = _config;
    if (config == null || !progress.qualified || config.isBetaAdopter) return;
    config.isBetaAdopter = true;
    await ref.read(storeConfigRepositoryProvider).save(config);
    ref.read(storeConfigProvider.notifier).refresh();
  }

  /// Passive load for the progress card - runs once when Settings opens, no
  /// user action needed. A failure (offline, etc.) just leaves the card in
  /// its loading state; "Check My Status" is there for the user to retry.
  Future<void> _loadFoundingProgress() async {
    final config = _config;
    if (config == null) return;
    setState(() => _foundingProgressLoading = true);
    try {
      final progress = _FoundingProgress.fromRow(
        await _fetchQualification(config.storeId),
      );
      await _persistIfQualified(progress);
      if (!mounted) return;
      setState(() {
        _foundingProgress = progress;
        _foundingProgressLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _foundingProgressLoading = false);
    }
  }

  Future<void> _checkFoundingStatus() async {
    final config = _config;
    if (config == null || _checkingStatus) return;
    setState(() => _checkingStatus = true);
    try {
      final progress = _FoundingProgress.fromRow(
        await _fetchQualification(config.storeId),
      );
      await _persistIfQualified(progress);
      if (!mounted) return;
      setState(() {
        _foundingProgress = progress;
        _checkingStatus = false;
      });
      await _showFoundingStatusDialog(progress);
    } catch (_) {
      if (!mounted) return;
      setState(() => _checkingStatus = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not check status. Try again.')),
      );
    }
  }

  Future<void> _showFoundingStatusDialog(_FoundingProgress progress) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          progress.qualified ? Icons.emoji_events : Icons.hourglass_bottom,
          color: progress.qualified ? AppTheme.syncAmber : AppTheme.primary,
          size: 48,
        ),
        title: Text(
          progress.qualified ? "You're a Founding Store!" : 'Not Quite Yet',
        ),
        content: Text(
          progress.qualified
              ? 'Congratulations — your store has qualified for founding '
                    'store status and its 50% lifetime discount.'
              : "You're at ${progress.daysSinceRegistration}/7 days and "
                    "${progress.salesCount}/5 sales. Keep going — "
                    '${progress.foundingStoresRemaining} founding spots are '
                    'still available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveConfig(void Function(StoreConfig config) mutate) async {
    final config = _config;
    if (config == null) return;
    mutate(config);
    await ref.read(storeConfigRepositoryProvider).save(config);
    await _enqueueStoreProfileSync(config);
    ref.read(storeConfigProvider.notifier).refresh();
    if (mounted) setState(() {});
  }

  /// Local-only preference (Settings > Sound) - deliberately not
  /// [_saveConfig], which also enqueues a `store_profile` sync event; a
  /// sound toggle has nothing to do with the store's own profile and should
  /// never touch the network.
  Future<void> _saveSoundPreference(void Function(StoreConfig config) mutate) async {
    final config = _config;
    if (config == null) return;
    mutate(config);
    await ref.read(storeConfigRepositoryProvider).save(config);
    if (mounted) setState(() {});
  }

  /// Queues a `store_profile` sync event so the edit reaches the `stores`
  /// row on the next sync. A no-op before registration - there's no store
  /// row yet to update.
  Future<void> _enqueueStoreProfileSync(StoreConfig config) async {
    if (config.storeId.isEmpty) return;
    final event = SyncEvent()
      ..uuid = const Uuid().v4()
      ..entityType = 'store_profile'
      ..entityUuid = config.storeId
      ..operation = 'update'
      ..payload = jsonEncode({
        'uuid': config.storeId,
        'name': config.storeName,
        'owner_name': config.ownerName,
        'owner_phone': config.ownerPhone,
        'address': config.address,
      })
      ..deviceId = config.deviceId
      ..createdAt = DateTime.now();
    await ref.read(eventQueueProvider).enqueue(event);
  }

  Future<void> _editField({
    required String label,
    required String currentValue,
    required Future<void> Function(String value) onSave,
  }) async {
    final controller = TextEditingController(text: currentValue);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit $label', style: AppTheme.mainTitle),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(hintText: 'Enter $label'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.of(sheetContext).pop(controller.text.trim()),
                child: const Text('Save'),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    await onSave(result);
  }

  Future<void> _syncNow() async {
    await ref.read(syncServiceProvider).sync();
    await ref.read(syncStatusProvider.notifier).refresh();
    await _load();
    // syncStatusProvider only notifies watchers when its enum bucket
    // actually changes (e.g. overdue -> synced) - a sync that doesn't cross
    // a bucket boundary wouldn't otherwise repaint the Last Synced text, so
    // force it here regardless.
    if (mounted) setState(() {});
  }

  Future<void> _copyDeviceId() async {
    final id = _config?.deviceId ?? '';
    if (id.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: id));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied!')));
  }

  void _showAbout() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/pockettill_logo.png', height: 40),
            const SizedBox(height: 16),
            const Text(
              'PocketTill v1.0.0',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'The offline-first POS for South African spaza shops.',
              textAlign: TextAlign.center,
              style: AppTheme.bodySubtitle,
            ),
            const SizedBox(height: 8),
            const Text(
              'Free during beta · Built with ❤️ in SA',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPrivacyPolicy() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
  }

  void _openTermsOfService() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()));
  }

  void _confirmLogout() {
    showDialog<void>(
      context: context,
      builder: (_) => ConfirmationDialog(
        message:
            'Are you sure you want to logout? Your data stays safe on '
            'this device.',
        confirmLabel: 'Logout',
        confirmColor: AppTheme.primary,
        onConfirm: _performLogout,
      ),
    );
  }

  Future<void> _performLogout() async {
    try {
      await AuthService.logout();
    } on UnsyncedChangesException {
      if (!mounted) return;
      await _showUnsyncedChangesDialog();
      return;
    }
    ref.read(storeConfigProvider.notifier).refresh();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  Future<void> _showUnsyncedChangesDialog() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.cloud_off, size: 48, color: AppTheme.syncGrey),
        title: const Text('Unsynced Changes'),
        content: const Text(
          "You have sales or changes that haven't synced yet. Connect to "
          'the internet and try again, so this device can save them '
          'before you log out.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(showMenuIcon: false, title: 'Settings'),
      backgroundColor: AppTheme.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              children: [
                _buildStoreProfileCard(),
                const SizedBox(height: 16),
                _buildSyncCard(),
                if (_config?.isBetaAdopter == true) ...[
                  const SizedBox(height: 16),
                  _buildBetaCard(),
                ] else if ((_config?.storeId ?? '').isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildFoundingProgressCard(),
                ],
                const SizedBox(height: 16),
                _buildDeviceInfoCard(),
                const SizedBox(height: 16),
                _buildSoundCard(),
                const SizedBox(height: 16),
                _buildSupportCard(),
                const SizedBox(height: 16),
                _buildAccountCard(),
                _buildFooter(),
              ],
            ),
    );
  }

  Widget _buildStoreProfileCard() {
    final config = _config;
    final displayName = (config?.storeName ?? '').isEmpty
        ? 'My Store'
        : config!.storeName;
    final letter = displayName.trim()[0].toUpperCase();

    return _SettingsCard(
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppTheme.primary,
            child: Text(
              letter,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 28,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            displayName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Edit Profile',
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppTheme.divider, height: 1),
          _EditableRow(
            label: 'Store Name',
            value: (config?.storeName ?? '').isEmpty
                ? 'Not set'
                : config!.storeName,
            onTap: () => _editField(
              label: 'Store Name',
              currentValue: config?.storeName ?? '',
              onSave: (value) => _saveConfig((c) => c.storeName = value),
            ),
          ),
          _EditableRow(
            label: 'Owner Name',
            value: (config?.ownerName ?? '').isEmpty
                ? 'Not set'
                : config!.ownerName!,
            onTap: () => _editField(
              label: 'Owner Name',
              currentValue: config?.ownerName ?? '',
              onSave: (value) => _saveConfig(
                (c) => c.ownerName = value.isEmpty ? null : value,
              ),
            ),
          ),
          _EditableRow(
            label: 'Phone Number',
            value: (config?.ownerPhone ?? '').isEmpty
                ? 'Not set'
                : config!.ownerPhone!,
            onTap: () => _editField(
              label: 'Phone Number',
              currentValue: config?.ownerPhone ?? '',
              onSave: (value) => _saveConfig(
                (c) => c.ownerPhone = value.isEmpty ? null : value,
              ),
            ),
          ),
          _EditableRow(
            label: 'Address',
            value: (config?.address ?? '').isEmpty
                ? 'Not set'
                : config!.address!,
            isLast: true,
            onTap: () => _editField(
              label: 'Address',
              currentValue: config?.address ?? '',
              onSave: (value) =>
                  _saveConfig((c) => c.address = value.isEmpty ? null : value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncCard() {
    final status = ref.watch(syncStatusProvider);
    final lastSyncedAt = ref.watch(syncStatusProvider.notifier).lastSyncedAt;
    final (statusColor, statusLabel) = syncIndicatorDisplay(
      status,
      lastSyncedAt: lastSyncedAt,
    );
    final lastSyncedText = _formatLastSynced(lastSyncedAt);
    final cycleStatus = ref.watch(syncCycleStatusProvider).valueOrNull;
    final isSyncing = cycleStatus == SyncStatus.syncing;

    return _SettingsCard(
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'Sync Status',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: AppTheme.divider, height: 1),
          ),
          Row(
            children: [
              const Text(
                'Last Synced',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              ),
              const Spacer(),
              Text(
                lastSyncedText,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: AppTheme.divider, height: 1),
          ),
          Row(
            children: [
              const Text(
                'Sync Now',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              ),
              const Spacer(),
              isSyncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(
                      onPressed: _syncNow,
                      child: const Text(
                        'Sync',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBetaCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: const Border(
          left: BorderSide(color: AppTheme.syncAmber, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.emoji_events, color: AppTheme.syncAmber),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Founding Store',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'First 100 stores · 50% lifetime discount when billing '
                  'begins',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.syncGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9999),
            ),
            child: const Text(
              'Active',
              style: TextStyle(
                color: AppTheme.syncGreen,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoundingProgressCard() {
    final progress = _foundingProgress;
    final days = (progress?.daysSinceRegistration ?? 0).clamp(0, 7);
    final sales = (progress?.salesCount ?? 0).clamp(0, 5);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: const Border(
          left: BorderSide(color: AppTheme.syncAmber, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.emoji_events_outlined, color: AppTheme.syncAmber),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Founding Store Progress',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'First 100 stores to qualify get a 50% lifetime discount when '
            'billing begins',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          if (_foundingProgressLoading && progress == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else ...[
            _ProgressRow(label: 'Days since registration', value: '$days/7'),
            const SizedBox(height: 8),
            _ProgressRow(label: 'Sales recorded', value: '$sales/5'),
            const SizedBox(height: 8),
            _ProgressRow(
              label: 'Founding spots',
              value: progress == null
                  ? '—'
                  : (progress.foundingStoresRemaining > 0
                        ? 'Available'
                        : 'Full'),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: _checkingStatus ? null : _checkFoundingStatus,
              child: _checkingStatus
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Check My Status'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceInfoCard() {
    final deviceId = _config?.deviceId ?? '';
    final truncated = deviceId.length > 12
        ? '${deviceId.substring(0, 12)}...'
        : deviceId;
    final deviceType = HardwareDetector.isSunmiDevice()
        ? 'Sunmi Terminal'
        : 'Android Phone';

    return _SettingsCard(
      child: Column(
        children: [
          InkWell(
            onTap: _copyDeviceId,
            child: Row(
              children: [
                const Text(
                  'Device ID',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                ),
                const Spacer(),
                Text(
                  truncated,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.copy_outlined,
                  color: AppTheme.iconBorder,
                  size: 16,
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: AppTheme.divider, height: 1),
          ),
          Row(
            children: [
              const Text(
                'App Version',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              ),
              const Spacer(),
              const Text(
                'v1.0.0 (Beta)',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: AppTheme.divider, height: 1),
          ),
          Row(
            children: [
              const Text(
                'Device Type',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              ),
              const Spacer(),
              Text(
                deviceType,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Scan sound only shows on a phone - Sunmi's hardware scanner already
  /// beeps on its own, so a toggle for it here would control a sound that
  /// never plays.
  Widget _buildSoundCard() {
    final config = _config;
    final showScanSoundToggle = !HardwareDetector.isSunmiDevice();

    return _SettingsCard(
      child: Column(
        children: [
          if (showScanSoundToggle) ...[
            _ToggleRow(
              label: 'Scan Sound',
              subtitle: 'Play a sound when a barcode is scanned',
              value: config?.scanSoundEnabled ?? true,
              onChanged: (value) => _saveSoundPreference(
                (c) => c.scanSoundEnabled = value,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: AppTheme.divider, height: 1),
            ),
          ],
          _ToggleRow(
            label: 'Payment Success Sound',
            subtitle: 'Play a sound when a sale is completed',
            value: config?.paymentSoundEnabled ?? true,
            onChanged: (value) => _saveSoundPreference(
              (c) => c.paymentSoundEnabled = value,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportCard() {
    return _SettingsCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _ActionRow(
            icon: Icons.chat_bubble_outline,
            label: 'Contact Support',
            onTap: () => showContactSupportOptions(context),
          ),
          const Divider(
            color: AppTheme.divider,
            height: 1,
            indent: 16,
            endIndent: 16,
          ),
          _ActionRow(
            icon: Icons.info_outline,
            label: 'About PocketTill',
            onTap: _showAbout,
          ),
          const Divider(
            color: AppTheme.divider,
            height: 1,
            indent: 16,
            endIndent: 16,
          ),
          _ActionRow(
            icon: Icons.privacy_tip_outlined,
            label: 'Privacy Policy',
            onTap: _openPrivacyPolicy,
          ),
          const Divider(
            color: AppTheme.divider,
            height: 1,
            indent: 16,
            endIndent: 16,
          ),
          _ActionRow(
            icon: Icons.description_outlined,
            label: 'Terms of Service',
            onTap: _openTermsOfService,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: InkWell(
        onTap: _confirmLogout,
        borderRadius: BorderRadius.circular(16),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.logout, color: AppTheme.logoutRed),
              SizedBox(width: 12),
              Text(
                'Logout',
                style: TextStyle(
                  color: AppTheme.logoutRed,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 24),
      child: Column(
        children: [
          Image.asset('assets/images/pockettill_icon.png', height: 24),
          const SizedBox(height: 8),
          const Text(
            'PocketTill · Free Beta',
            style: TextStyle(fontSize: 12, color: AppTheme.syncGrey),
          ),
        ],
      ),
    );
  }
}

/// Result of the `check_founding_store_qualification` RPC, for the progress
/// card and the "Check My Status" confirmation dialog.
class _FoundingProgress {
  const _FoundingProgress({
    required this.qualified,
    required this.daysSinceRegistration,
    required this.salesCount,
    required this.foundingStoresRemaining,
  });

  factory _FoundingProgress.fromRow(Map<String, dynamic> row) {
    return _FoundingProgress(
      qualified: row['qualified'] as bool? ?? false,
      daysSinceRegistration: row['days_since_registration'] as int? ?? 0,
      salesCount: row['sales_count'] as int? ?? 0,
      foundingStoresRemaining: row['founding_stores_remaining'] as int? ?? 0,
    );
  }

  final bool qualified;
  final int daysSinceRegistration;
  final int salesCount;
  final int foundingStoresRemaining;
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
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
      child: child,
    );
  }
}

class _EditableRow extends StatelessWidget {
  const _EditableRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.isLast = false,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right,
                  color: AppTheme.iconBorder,
                  size: 18,
                ),
              ],
            ),
          ),
          if (!isLast) const Divider(color: AppTheme.divider, height: 1),
        ],
      ),
    );
  }
}

/// A label + subtitle with a toggle switch on the trailing edge - used for
/// the Sound section, matching [_EditableRow]'s layout otherwise.
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: isLast
          ? const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.iconBorder, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppTheme.iconBorder,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
