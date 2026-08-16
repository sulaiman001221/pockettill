import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/auth_service.dart';
import '../../core/database/isar_service.dart';
import '../../core/supabase/supabase_service.dart';
import '../../core/sync/sync_service.dart';
import '../../shared/repositories/store_config_repository.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/pockettill_app_bar.dart';
import '../auth/founding_store_screen.dart';
import '../auth/login_screen.dart';
import '../auth/welcome_screen.dart';
import '../sales/sales_screen.dart';
import 'app_drawer.dart';

/// The app's root screen - always the base of the navigation stack. Shows
/// the drawer navigation shell wrapping [SalesScreen].
///
/// Owns the drawer's active-route tracking itself (rather than leaving it in
/// [AppDrawer]'s own state): Flutter's [Drawer] disposes its child's State
/// once its close animation finishes, so anything stored there is lost the
/// next time the drawer opens. [ShellScreen] persists for the app's whole
/// lifetime, so state lives here instead.
class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  String _activeRoute = 'sales';
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<void>? _displacedSubscription;

  /// Two independent signals can report the same sign-out (a sync cycle
  /// spotting the displacement, then the auth listener seeing the refresh
  /// fail) - without this, the second one would stack a duplicate dialog
  /// and navigation on top of the first.
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    // Catches a session that's gone invalid without this screen doing
    // anything itself - e.g. the SDK's background auto-refresh discovering
    // a revoked/expired refresh token, surfaced as a signedOut event with
    // reason sessionExpired. Without this listener, the device would just
    // start silently failing to sync forever with no explanation.
    _authSubscription = SupabaseService.supabaseClient.auth.onAuthStateChange
        .listen(_onAuthStateChange);
    // The auth listener above only fires once a token refresh actually
    // fails, which can be up to an hour after another device displaced this
    // one (the access token already on this device stays valid until it
    // expires). SyncService notices far sooner - see its
    // displacedByAnotherDevice doc comment.
    _displacedSubscription = ref
        .read(syncServiceProvider)
        .displacedByAnotherDevice
        .listen((_) => unawaited(_handleSignedOut(kickedByNewDevice: true)));
    unawaited(_checkFoundingStoreQualification());
  }

  /// Silently checks (every time the app opens to here, logged in) whether
  /// this store has now earned founding-store status through usage - see
  /// `check_founding_store_qualification` in Supabase. Never blocks the app
  /// from loading: it runs in the background, and only surfaces anything if
  /// the store just newly qualified, a couple of seconds after this screen
  /// is already up and usable.
  Future<void> _checkFoundingStoreQualification() async {
    final repo = StoreConfigRepository(isar: IsarService.db);
    final config = await repo.get();
    if (config == null || config.storeId.isEmpty || config.isBetaAdopter) {
      return;
    }

    try {
      final result = await SupabaseService.supabaseClient
          .rpc(
            'check_founding_store_qualification',
            params: {'store_uuid': config.storeId},
          )
          .single();
      final newlyQualified = result['newly_qualified'] as bool? ?? false;
      if (!newlyQualified) return;

      config.isBetaAdopter = true;
      await repo.save(config);

      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const FoundingStoreScreen()));
    } catch (_) {
      // Best-effort and silent - offline or a transient failure just means
      // this gets checked again the next time the app opens.
    }
  }

  void _onAuthStateChange(AuthState state) {
    if (state.event != AuthChangeEvent.signedOut) return;
    if (state.signOutReason != SignOutReason.sessionExpired) {
      // userInitiated is already handled by whichever screen (drawer/
      // settings) called AuthService.logout() and navigated on its own;
      // sessionMissing is a different, local-storage-corruption failure
      // mode this dialog's wording doesn't apply to.
      return;
    }
    unawaited(_handleSignedOut());
  }

  /// Signs this device out locally and explains why.
  ///
  /// [kickedByNewDevice] null means "work it out" - the auth-listener path
  /// can't tell a revoked session from a naturally expired one, since both
  /// surface as `SignOutReason.sessionExpired`, so it has to ask the server.
  /// The sync path already knows, and passes true.
  Future<void> _handleSignedOut({bool? kickedByNewDevice}) async {
    if (_signingOut) return;
    _signingOut = true;

    final repo = StoreConfigRepository(isar: IsarService.db);
    final config = await repo.get();
    if (config != null) {
      config.isLoggedIn = false;
      await repo.save(config);
    }

    // Only reached via the sync path, where the session hasn't actually
    // been torn down on this client yet - the server revoked it, but this
    // device still holds a usable access token. Clearing it locally is what
    // makes the sign-out real here.
    if (kickedByNewDevice == true) {
      try {
        await SupabaseService.supabaseClient.auth.signOut(
          scope: SignOutScope.local,
        );
      } catch (_) {
        // Already gone, or no connectivity to confirm - the local
        // StoreConfig flag above is what actually gates re-entry.
      }
    }
    if (!mounted) return;

    final displaced =
        kickedByNewDevice ??
        (config != null && config.storeId.isNotEmpty
            ? await AuthService.wasSignedOutByNewDevice(
                storeId: config.storeId,
                deviceId: config.deviceId,
              )
            : false);
    if (!mounted) return;

    if (displaced) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const LoginScreen(showKickedByOtherDeviceBanner: true),
        ),
        (route) => false,
      );
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.info_outline,
          color: AppTheme.primary,
          size: 48,
        ),
        title: const Text('Signed Out'),
        content: const Text(
          'Your session has expired. Please sign in again to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _displacedSubscription?.cancel();
    super.dispose();
  }

  Future<void> _navigateTo(String route, Widget screen) async {
    setState(() => _activeRoute = route);
    Navigator.of(context).pop();
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    // Whatever popped us back here - the screen's own back arrow, the
    // hardware/gesture back button, or anything else - we're looking at
    // Sales again, so the drawer's highlight should match that.
    if (mounted) setState(() => _activeRoute = 'sales');
  }

  /// Settings and Logout never track as the active drawer item, so this
  /// leaves [_activeRoute] untouched.
  void _navigateWithoutTrackingActive(Widget screen) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _goHome() {
    setState(() => _activeRoute = 'sales');
    Navigator.of(context).pop();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(showMenuIcon: true),
      drawer: AppDrawer(
        activeRoute: _activeRoute,
        onNavigate: _navigateTo,
        onNavigateWithoutTrackingActive: _navigateWithoutTrackingActive,
        onGoHome: _goHome,
      ),
      backgroundColor: AppTheme.background,
      // SalesScreen's fixed-height sections (scan card, search bar, checkout
      // bar) don't leave room to shrink when the keyboard appears; avoid
      // resizing the body for it rather than overflowing.
      resizeToAvoidBottomInset: false,
      body: const SalesScreen(),
    );
  }
}
