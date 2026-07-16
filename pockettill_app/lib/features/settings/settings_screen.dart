import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../core/auth/auth_service.dart';
import '../../core/hardware/hardware_detector.dart';
import '../../core/sync/sync_service.dart';
import '../../core/sync/sync_status_provider.dart';
import '../../shared/models/store_config.dart';
import '../../shared/models/sync_event.dart';
import '../../shared/repositories/repositories.dart';
import '../../shared/repositories/store_config_provider.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/sync_status.dart';
import '../../shared/widgets/pockettill_app_bar.dart';
import '../auth/welcome_screen.dart';

// Placeholder until the real support number is available.
const String _supportWhatsAppNumber = '27000000000';

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

  Future<void> _contactSupport() async {
    final uri = Uri.parse('https://wa.me/$_supportWhatsAppNumber');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp')),
      );
    }
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

  void _showPrivacyPolicyPlaceholder() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Privacy policy coming soon')),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text(
          'Are you sure? Your data is saved locally and will be available '
          'when you sign back in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Logout',
              style: TextStyle(color: AppTheme.logoutRed),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await AuthService.logout();
    ref.read(storeConfigProvider.notifier).refresh();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
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
                ],
                const SizedBox(height: 16),
                _buildDeviceInfoCard(),
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

  Widget _buildSupportCard() {
    return _SettingsCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _ActionRow(
            icon: Icons.chat_bubble_outline,
            label: 'Contact Support',
            onTap: _contactSupport,
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
            onTap: _showPrivacyPolicyPlaceholder,
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
