import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../shared/models/credit_customer.dart';
import '../../shared/models/credit_transaction.dart';
import '../../shared/models/product.dart';
import '../../shared/models/return_item.dart';
import '../../shared/models/return_record.dart';
import '../../shared/models/sale.dart';
import '../../shared/models/sale_item.dart';
import '../../shared/models/store_config.dart';
import '../../shared/models/sync_event.dart';
import '../../shared/repositories/store_config_repository.dart';
import '../database/isar_service.dart';
import '../supabase/supabase_service.dart';
import '../sync/event_queue.dart';
import '../sync/restore_service.dart';
import '../sync/sync_service.dart';

/// Registration, login, logout, and session state against Supabase Auth,
/// using real phone OTP verification (Twilio Verify, WhatsApp channel) for
/// registration and password reset, and phone + password for login (no OTP
/// once this exact device+store pairing has ever been verified before - see
/// [login] for the new-device exception).
///
/// Device trust is per (device, store) pair, tracked in the `devices` table's
/// `verified_at` column - not a single "trusted device" per store. The same
/// physical device can independently hold verified rows for multiple store
/// accounts at once; each pairing only ever needs one OTP, the first time
/// it's used.
///
/// Registration and password reset are split across [requestOtp],
/// [verifyOtp], [setPassword], and (registration only) [createStore] so the
/// UI can insert an OTP-entry screen between requesting and verifying the
/// code. Offline-first: [StoreConfig] is never cleared on logout, so the app
/// keeps working locally without a session.
class AuthService {
  AuthService._();

  static const _uuid = Uuid();

  /// Normalizes any South African phone format to E.164 (`+27...`).
  ///
  /// Handles "071 234 5678", "0712345678", "27712345678", and
  /// "+27712345678" - all become "+27712345678".
  static String formatPhone(String raw) {
    final digitsAndPlus = raw.replaceAll(RegExp(r'[^\d+]'), '');

    if (digitsAndPlus.startsWith('+27')) return digitsAndPlus;
    if (digitsAndPlus.startsWith('27')) return '+$digitsAndPlus';
    if (digitsAndPlus.startsWith('0')) {
      return '+27${digitsAndPlus.substring(1)}';
    }
    return '+27$digitsAndPlus';
  }

  /// Whether [phone] already has an account. Check before registering (to
  /// block duplicate sign-ups without sending an OTP or touching a
  /// password) or before a password-reset request (to block resets for
  /// numbers with no account).
  static Future<bool> phoneHasAccount(String phone) async {
    final result = await SupabaseService.supabaseClient.rpc(
      'phone_has_account',
      params: {'check_phone': formatPhone(phone)},
    );
    return result as bool;
  }

  /// Sends a 6-digit code to [phone] via Twilio Verify - WhatsApp by
  /// default, with SMS available as a fallback ([channel]) for stores
  /// without WhatsApp. Starts both registration and password reset -
  /// Supabase's phone auth has no separate "recovery" endpoint the way
  /// email auth does, so both flows send an OTP the same way.
  static Future<void> requestOtp(
    String phone, {
    OtpChannel channel = OtpChannel.whatsapp,
  }) {
    return SupabaseService.supabaseClient.auth.signInWithOtp(
      phone: formatPhone(phone),
      channel: channel,
    );
  }

  /// Verifies the code sent by [requestOtp]. Succeeds with a live session on
  /// a correct, unexpired code.
  static Future<void> verifyOtp({
    required String phone,
    required String token,
  }) async {
    final response = await SupabaseService.supabaseClient.auth.verifyOTP(
      phone: formatPhone(phone),
      token: token,
      type: OtpType.sms,
    );
    if (response.user == null) {
      throw Exception('Verification failed — no user returned');
    }
  }

  /// Sets the password on the just-verified session. Call after [verifyOtp]
  /// succeeds, for both a new registration and a password reset.
  static Future<void> setPassword(String password) {
    return SupabaseService.supabaseClient.auth.updateUser(
      UserAttributes(password: password),
    );
  }

  /// Creates the `stores` row, marks this device+store pairing as verified
  /// (the registration OTP just proved phone ownership, so there's no need
  /// to challenge again immediately after), and saves [StoreConfig] locally.
  /// Call after [verifyOtp] and [setPassword] have both succeeded, so
  /// `auth.currentUser` is a real, password-protected, phone-verified
  /// account.
  ///
  /// Founding store status is never granted here - it's earned later purely
  /// through usage (see `check_founding_store_qualification` in Supabase),
  /// not by the act of registering under the first-100 cap. [otpChannel] is
  /// persisted so a later new-device login knows which channel to challenge
  /// this store's owner on.
  static Future<void> createStore({
    required String storeName,
    required String ownerName,
    required String ownerPhone,
    required OtpChannel otpChannel,
    String? address,
  }) async {
    final user = SupabaseService.supabaseClient.auth.currentUser;
    if (user == null) {
      throw Exception('createStore called with no authenticated user');
    }

    final repo = StoreConfigRepository(isar: IsarService.db);
    final existingConfig = await repo.get();
    // deviceId identifies this physical install, not any one store - the
    // same value is reused across every store account this device ever logs
    // into, so its per-store verification history in `devices` means
    // something (see the class doc comment).
    final deviceId = existingConfig?.deviceId ?? _uuid.v4();

    final store = await SupabaseService.supabaseClient
        .from('stores')
        .insert({
          'name': storeName,
          'owner_name': ownerName,
          'owner_phone': ownerPhone,
          'address': address,
          'auth_user_id': user.id,
          'is_beta_adopter': false,
          'otp_channel': otpChannel.name,
          'discount_rate': 1.0,
        })
        .select()
        .single();

    await SupabaseService.supabaseClient.from('devices').upsert({
      'id': deviceId,
      'store_id': store['uuid'],
      'verified_at': DateTime.now().toUtc().toIso8601String(),
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    });

    // Registering a brand-new store can never match whatever store was
    // previously configured on this device, so any cached data left over
    // from that old store must go the same way login's store-switch does -
    // see the matching comment in _completeLogin for why.
    if (existingConfig != null && existingConfig.storeId.isNotEmpty) {
      await IsarService.db.writeTxn(() async {
        await IsarService.db.products.clear();
        await IsarService.db.sales.clear();
        await IsarService.db.saleItems.clear();
        await IsarService.db.creditCustomers.clear();
        await IsarService.db.creditTransactions.clear();
        await IsarService.db.returnRecords.clear();
        await IsarService.db.returnItems.clear();
        await IsarService.db.syncEvents.clear();
      });
    }

    final config = StoreConfig()
      ..id = 1
      ..storeId = store['uuid'] as String
      ..storeName = storeName
      ..deviceId = deviceId
      ..ownerName = ownerName
      ..ownerPhone = ownerPhone
      ..address = address
      ..authUserId = user.id
      ..authPhone = user.phone
      ..isBetaAdopter = false
      ..isLoggedIn = true
      // This physical device's own settings, not the new store's - see the
      // matching comment in _completeLogin.
      ..scanSoundEnabled = existingConfig?.scanSoundEnabled ?? true
      ..paymentSoundEnabled = existingConfig?.paymentSoundEnabled ?? true;

    await repo.save(config);
  }

  /// Signs in an existing store - phone + password only, no OTP, UNLESS this
  /// exact device+store pairing has never been verified before (checked
  /// against `devices.verified_at`, keyed on both `id` and `store_id`). In
  /// that case the password alone isn't enough: the result comes back with
  /// [LoginResult.needsDeviceVerification] set, an OTP has already been sent
  /// to the store owner's registered phone (via whichever channel they
  /// registered with), and the caller must show [OtpMode.newDeviceVerification]
  /// and call [completeNewDeviceLogin] once it succeeds before this device
  /// is actually let in. Once verified, this exact pairing never needs to be
  /// challenged again - a different device logging into this store, or this
  /// same device logging into a *different* store, each get their own
  /// independent verification history.
  static Future<LoginResult> login({
    required String phone,
    required String password,
  }) async {
    final formatted = formatPhone(phone);

    final authResponse = await SupabaseService.supabaseClient.auth
        .signInWithPassword(phone: formatted, password: password);

    if (authResponse.user == null) {
      throw Exception('Login failed');
    }

    final store = await SupabaseService.supabaseClient
        .from('stores')
        .select()
        .eq('auth_user_id', authResponse.user!.id)
        .single();

    final repo = StoreConfigRepository(isar: IsarService.db);
    final existingConfig = await repo.get();
    final deviceId = existingConfig?.deviceId ?? _uuid.v4();

    final verified = await _isDeviceVerified(
      deviceId: deviceId,
      storeId: store['uuid'] as String,
    );

    if (!verified) {
      final channel = _channelFromName(store['otp_channel'] as String?);
      await requestOtp(formatted, channel: channel);
      return LoginResult._(
        needsDeviceVerification: true,
        store: store,
        deviceId: deviceId,
        phone: formatted,
        otpChannel: channel,
      );
    }

    await _completeLogin(
      user: authResponse.user!,
      store: store,
      deviceId: deviceId,
      existingConfig: existingConfig,
      formattedPhone: formatted,
    );
    return const LoginResult._(needsDeviceVerification: false);
  }

  /// Finishes a login that [login] flagged as [LoginResult.needsDeviceVerification]
  /// - call once [OtpVerificationScreen] reports the code as verified. Marks
  /// this device+store pairing as verified server-side before completing the
  /// same steps an already-trusted login does.
  static Future<void> completeNewDeviceLogin(LoginResult result) async {
    final user = SupabaseService.supabaseClient.auth.currentUser;
    if (user == null) {
      throw Exception('No session after device verification');
    }

    final store = result.store!;
    final deviceId = result.deviceId!;

    await SupabaseService.supabaseClient.from('devices').upsert({
      'id': deviceId,
      'store_id': store['uuid'],
      'verified_at': DateTime.now().toUtc().toIso8601String(),
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    });

    final repo = StoreConfigRepository(isar: IsarService.db);
    final existingConfig = await repo.get();

    await _completeLogin(
      user: user,
      store: store,
      deviceId: deviceId,
      existingConfig: existingConfig,
      formattedPhone: result.phone!,
    );
  }

  /// Call if the user backs out of [OtpMode.newDeviceVerification] without
  /// completing it. [login]'s `signInWithPassword` call already established
  /// a live session on this device before the device-mismatch was even
  /// detected (Supabase's password grant doesn't support pausing that) - so
  /// without this, an abandoned verification would still leave a valid,
  /// unverified session sitting in local storage that a later app open could
  /// mistake for a trusted one. Revokes it server-side (not just locally) so
  /// it can't be resumed at all.
  static Future<void> abandonNewDeviceVerification() {
    return SupabaseService.supabaseClient.auth.signOut(
      scope: SignOutScope.global,
    );
  }

  /// Checked on every app open (see `SplashScreen`) for a device that
  /// already holds a valid session: confirms this device+store pairing is
  /// still verified before letting it straight into the app. This is the
  /// backstop for [login]'s device check - it's what catches an abandoned
  /// new-device verification that was never explicitly cancelled (e.g. the
  /// app was killed instead), since that path never reaches
  /// [abandonNewDeviceVerification].
  ///
  /// Returns null if this device is verified for this store (or trust can't
  /// currently be checked - fails open on a network error, since PocketTill
  /// works fully offline once set up and a connectivity blip shouldn't lock
  /// a legitimately-trusted device out of its own app). Otherwise returns a
  /// [LoginResult] with an OTP already sent, ready for
  /// [OtpMode.newDeviceVerification] the same as a fresh login.
  static Future<LoginResult?> checkDeviceTrust() async {
    final repo = StoreConfigRepository(isar: IsarService.db);
    final config = await repo.get();
    if (config == null || config.storeId.isEmpty) return null;

    try {
      final store = await SupabaseService.supabaseClient
          .from('stores')
          .select()
          .eq('uuid', config.storeId)
          .single();

      final verified = await _isDeviceVerified(
        deviceId: config.deviceId,
        storeId: config.storeId,
      );
      if (verified) return null;

      final channel = _channelFromName(store['otp_channel'] as String?);
      final phone = config.authPhone ?? formatPhone(config.ownerPhone ?? '');
      await requestOtp(phone, channel: channel);
      return LoginResult._(
        needsDeviceVerification: true,
        store: store,
        deviceId: config.deviceId,
        phone: phone,
        otpChannel: channel,
      );
    } catch (_) {
      return null;
    }
  }

  static OtpChannel _channelFromName(String? name) {
    return name == 'sms' ? OtpChannel.sms : OtpChannel.whatsapp;
  }

  /// Whether `devices` already has a verified row for this exact
  /// (deviceId, storeId) pairing - the single source of truth for whether a
  /// login needs the new-device OTP challenge.
  static Future<bool> _isDeviceVerified({
    required String deviceId,
    required String storeId,
  }) async {
    final row = await SupabaseService.supabaseClient
        .from('devices')
        .select('verified_at')
        .eq('id', deviceId)
        .eq('store_id', storeId)
        .maybeSingle();
    return row != null && row['verified_at'] != null;
  }

  /// Shared tail end of a successful login, whether it needed device
  /// verification or not: records this device as the store's device, and
  /// saves [StoreConfig] locally.
  static Future<void> _completeLogin({
    required User user,
    required Map<String, dynamic> store,
    required String deviceId,
    required StoreConfig? existingConfig,
    required String formattedPhone,
  }) async {
    await SupabaseService.supabaseClient.from('devices').upsert({
      'id': deviceId,
      'store_id': store['uuid'],
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    });

    // This device is now the store's single active device - stamped before
    // the revoke below so `signed_out_by_new_device` has something to
    // compare against the moment the other device's refresh fails.
    await SupabaseService.supabaseClient
        .from('stores')
        .update({'active_device_id': deviceId})
        .eq('uuid', store['uuid']);

    // A `signOut(scope: SignOutScope.others)` call used to sit here to kick
    // out every other session on login - removed after confirming (via a
    // direct RLS simulation against Supabase) that it was degrading this
    // client's own just-established session to unauthenticated, causing
    // every request right after login - including the call above - to be
    // rejected by RLS. Re-added now that the installed gotrue-dart's own
    // `_signOut` was checked directly (package:gotrue 2.26.0) and only
    // removes the *local* session when `scope != SignOutScope.others` -
    // with `others`, this client's own session is left untouched, so the
    // failure mode that caused the original removal no longer applies.
    // Best-effort: a failure here must not block this device's own login.
    try {
      await SupabaseService.supabaseClient.auth.signOut(
        scope: SignOutScope.others,
      );
    } catch (_) {}

    final isSwitchingStore =
        existingConfig != null && existingConfig.storeId != store['uuid'];

    // Every business-data collection is local-first with no store_id column
    // of its own - the app was built assuming one physical device belongs to
    // exactly one store forever, so nothing else ever scopes reads by store.
    // Logging into a *different* store on a device that already has another
    // store's data cached would otherwise keep showing that old store's
    // products/sales/customers under the new login. Clearing it here is the
    // only thing that makes the two stores' local data no longer collide -
    // [RestoreService] below is what repopulates this store's own history
    // afterward.
    if (isSwitchingStore) {
      await IsarService.db.writeTxn(() async {
        await IsarService.db.products.clear();
        await IsarService.db.sales.clear();
        await IsarService.db.saleItems.clear();
        await IsarService.db.creditCustomers.clear();
        await IsarService.db.creditTransactions.clear();
        await IsarService.db.returnRecords.clear();
        await IsarService.db.returnItems.clear();
        await IsarService.db.syncEvents.clear();
      });
    }

    final config = StoreConfig()
      ..id = 1
      ..storeId = store['uuid'] as String
      ..storeName = store['name'] as String
      ..deviceId = deviceId
      ..ownerName = store['owner_name'] as String? ?? ''
      ..ownerPhone = store['owner_phone'] as String? ?? ''
      ..address = store['address'] as String?
      ..authUserId = user.id
      ..authPhone = formattedPhone
      ..isBetaAdopter = store['is_beta_adopter'] as bool? ?? false
      ..isLoggedIn = true
      // Logging back in on a device that has already synced before isn't a
      // fresh start - carry the timestamp over rather than resetting it to
      // null, which would otherwise make the 30-day "never synced" warning
      // fire on every single login regardless of real sync history. A
      // different store, though, has no shared history to carry over.
      ..lastSyncedAt = isSwitchingStore ? null : existingConfig?.lastSyncedAt
      // Sound preferences are this physical device's own settings, not the
      // store's - carry them forward on every login (switch or not) rather
      // than silently resetting to the class default, which is what a
      // fresh `StoreConfig()` here would otherwise do every single login.
      ..scanSoundEnabled = existingConfig?.scanSoundEnabled ?? true
      ..paymentSoundEnabled = existingConfig?.paymentSoundEnabled ?? true;

    final repo = StoreConfigRepository(isar: IsarService.db);
    await repo.save(config);

    // Repopulates this store's own history whenever the local cache is
    // empty - after the clear above, after a reinstall, or on a brand-new
    // device logging into an existing account for the first time. Awaited
    // here so it's covered by whichever loading spinner already wraps
    // login/OTP verification - the user reaching the home screen is the
    // signal their data is ready, not something they should have to wait on
    // separately. Best-effort: a failed restore (e.g. connectivity drops
    // mid-pull) must not block login itself - it just leaves local data
    // empty until the next successful login retries it.
    try {
      await RestoreService(isar: IsarService.db).restoreIfEmpty(
        store['uuid'] as String,
      );
    } catch (_) {
      // Swallowed deliberately - see comment above.
    }
  }

  /// Signs out of Supabase Auth. [StoreConfig] is kept (marked logged out
  /// only) so the app still works offline until the next login.
  ///
  /// Uses [SignOutScope.global] (not the default `local`) so the refresh
  /// token is actually revoked server-side, not just cleared from this
  /// client's in-memory/local storage - a `local` sign-out left a window
  /// where force-stopping the app right after tapping Logout could leave a
  /// stale-but-still-valid session on disk, silently logging the device
  /// back in on next launch.
  ///
  /// Throws [UnsyncedChangesException] instead of signing out if there are
  /// local changes still waiting to reach Supabase and no connectivity to
  /// push them first. This is the last moment this store's own session can
  /// push them under its own identity - once signed out, only a later login
  /// to *this same store* would resync them safely; a different store
  /// logging in on this device first would clear them for good (see the
  /// isSwitchingStore note in [_completeLogin]), so they cannot be silently
  /// left pending.
  static Future<void> logout() async {
    final isar = IsarService.db;
    final eventQueue = EventQueue(isar);

    var pending = await eventQueue.pendingCount();
    if (pending > 0) {
      await SyncService(isar: isar, eventQueue: eventQueue).sync();
      pending = await eventQueue.pendingCount();
    }
    if (pending > 0) {
      throw const UnsyncedChangesException();
    }

    await SupabaseService.supabaseClient.auth.signOut(
      scope: SignOutScope.global,
    );

    final repo = StoreConfigRepository(isar: isar);
    final config = await repo.get();
    if (config != null) {
      config.isLoggedIn = false;
      await repo.save(config);
    }
  }

  /// Whether this device still has a usable session.
  ///
  /// Deliberately not just `session != null && !session.isExpired`:
  /// [Session.isExpired] describes the *access* token, which lives about an
  /// hour, while the refresh token behind it lives far longer. Treating an
  /// expired access token as "logged out" signed users out of a perfectly
  /// good session any time the app had been closed longer than the access
  /// token's lifetime - and it self-corrected on the *next* open (Supabase
  /// refreshes in the background at startup, so by then the stored token
  /// was fresh again), which is exactly the "login screen once, then fine"
  /// behaviour that made it look intermittent.
  ///
  /// So an expired access token is refreshed here before deciding, and only
  /// a definitively rejected refresh token counts as signed out.
  static Future<bool> get isLoggedIn async {
    final auth = SupabaseService.supabaseClient.auth;
    final session = auth.currentSession;
    if (session == null) return false;
    if (!session.isExpired) return true;

    try {
      final response = await auth.refreshSession();
      return response.session != null;
    } on AuthRetryableFetchException {
      // Offline/unreachable - can't confirm either way. PocketTill works
      // fully offline once set up, so a connectivity blip must never eject
      // a user whose refresh token is almost certainly still valid; the
      // next successful refresh (or a real rejection) settles it later.
      return true;
    } catch (_) {
      // The refresh token itself was rejected - revoked (e.g. by a login on
      // another device) or genuinely expired. A real sign-out.
      return false;
    }
  }

  /// Whether this device's session was just invalidated because a
  /// *different* device logged into this store more recently, as opposed to
  /// a natural token expiry - the two are otherwise indistinguishable, since
  /// both surface through gotrue-dart as the same
  /// `SignOutReason.sessionExpired` (a revoked refresh token fails to
  /// refresh exactly the same way an actually-expired one does). Used by
  /// [ShellScreen] to decide which message to show after an involuntary
  /// sign-out. Best-effort: returns false on any error (e.g. offline) rather
  /// than throwing, since the caller's fallback (a generic "session
  /// expired" message) is the safe default when this can't be confirmed.
  static Future<bool> wasSignedOutByNewDevice({
    required String storeId,
    required String deviceId,
  }) {
    return SupabaseService.isDisplacedByAnotherDevice(
      storeId: storeId,
      deviceId: deviceId,
    );
  }
}

/// Outcome of [AuthService.login] or [AuthService.checkDeviceTrust]. Either
/// nothing more is needed, or this device must pass
/// [OtpMode.newDeviceVerification] - [store], [deviceId], [phone], and
/// [otpChannel] carry everything [AuthService.completeNewDeviceLogin] and
/// the OTP screen need to finish that.
class LoginResult {
  const LoginResult._({
    required this.needsDeviceVerification,
    this.store,
    this.deviceId,
    this.phone,
    this.otpChannel,
  });

  final bool needsDeviceVerification;
  final Map<String, dynamic>? store;
  final String? deviceId;
  final String? phone;
  final OtpChannel? otpChannel;
}

/// Thrown by [AuthService.logout] when local changes haven't finished
/// syncing and there's no connectivity to flush them before signing out.
class UnsyncedChangesException implements Exception {
  const UnsyncedChangesException();
}
