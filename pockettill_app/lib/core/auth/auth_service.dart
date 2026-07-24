import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../shared/models/store_config.dart';
import '../../shared/repositories/store_config_repository.dart';
import '../database/isar_service.dart';
import '../supabase/supabase_service.dart';

/// Registration, login, logout, and session state against Supabase Auth,
/// using real phone OTP verification (Twilio Verify, WhatsApp channel) for
/// registration and password reset, and phone + password for login (no OTP
/// on the same device the store already trusts - see [login] for the
/// new-device exception).
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

  /// Creates the `stores` row, registers this device as the store's trusted
  /// device, and saves [StoreConfig] locally. Call after [verifyOtp] and
  /// [setPassword] have both succeeded, so `auth.currentUser` is a real,
  /// password-protected, phone-verified account.
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
          'active_device_id': deviceId,
          'otp_channel': otpChannel.name,
          'discount_rate': 1.0,
        })
        .select()
        .single();

    await SupabaseService.supabaseClient.from('devices').upsert({
      'id': deviceId,
      'store_id': store['uuid'],
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    });

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
      ..isLoggedIn = true;

    await repo.save(config);
  }

  /// Signs in an existing store - phone + password only, no OTP, UNLESS this
  /// is a device the store hasn't already trusted (a fresh install, a
  /// different phone, a wiped device - anything whose local [StoreConfig]
  /// doesn't carry the store's `active_device_id`). In that case the
  /// password alone isn't enough: the result comes back with
  /// [LoginResult.needsDeviceVerification] set, an OTP has already been sent
  /// to the store owner's registered phone (via whichever channel they
  /// registered with), and the caller must show [OtpMode.newDeviceVerification]
  /// and call [completeNewDeviceLogin] once it succeeds before this device
  /// is actually let in.
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
    final activeDeviceId = store['active_device_id'] as String?;

    // A null active_device_id means this store predates device tracking -
    // don't retroactively challenge it since there's no real "original
    // device" on record to compare against; this device becomes the record
    // once _completeLogin runs below.
    if (activeDeviceId != null && activeDeviceId != deviceId) {
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
  /// this device as the store's new trusted device server-side before
  /// completing the same steps a same-device login does.
  static Future<void> completeNewDeviceLogin(LoginResult result) async {
    final user = SupabaseService.supabaseClient.auth.currentUser;
    if (user == null) {
      throw Exception('No session after device verification');
    }

    final store = result.store!;
    final deviceId = result.deviceId!;

    await SupabaseService.supabaseClient
        .from('stores')
        .update({'active_device_id': deviceId})
        .eq('uuid', store['uuid'] as String);

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
  /// already holds a valid session: confirms the store's `active_device_id`
  /// still matches this device before letting it straight into the app.
  /// This is the backstop for [login]'s device check - it's what catches an
  /// abandoned new-device verification that was never explicitly cancelled
  /// (e.g. the app was killed instead), since that path never reaches
  /// [abandonNewDeviceVerification].
  ///
  /// Returns null if this device is trusted (or trust can't currently be
  /// checked - fails open on a network error, since PocketTill works fully
  /// offline once set up and a connectivity blip shouldn't lock a
  /// legitimately-trusted device out of its own app). Otherwise returns a
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

      final activeDeviceId = store['active_device_id'] as String?;
      if (activeDeviceId == null || activeDeviceId == config.deviceId) {
        return null;
      }

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

  /// Shared tail end of a successful login, whether it needed device
  /// verification or not: revokes every other session, records this device
  /// as the store's device, and saves [StoreConfig] locally.
  static Future<void> _completeLogin({
    required User user,
    required Map<String, dynamic> store,
    required String deviceId,
    required StoreConfig? existingConfig,
    required String formattedPhone,
  }) async {
    // Single-device policy: logging in anywhere immediately ends every
    // other session for this account, using this brand-new session's own
    // authority (no service-role key needed). Deliberately not a "log out
    // the old device first" block - that would permanently lock a store
    // out if the old device is lost, stolen, or broken. This way a new
    // login always works, and the old device just stops being authenticated
    // next time it tries to use its session.
    await SupabaseService.supabaseClient.auth.signOut(
      scope: SignOutScope.others,
    );

    await SupabaseService.supabaseClient.from('devices').upsert({
      'id': deviceId,
      'store_id': store['uuid'],
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    });

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
      // fire on every single login regardless of real sync history.
      ..lastSyncedAt = existingConfig?.lastSyncedAt;

    final repo = StoreConfigRepository(isar: IsarService.db);
    await repo.save(config);
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
  static Future<void> logout() async {
    await SupabaseService.supabaseClient.auth.signOut(
      scope: SignOutScope.global,
    );

    final repo = StoreConfigRepository(isar: IsarService.db);
    final config = await repo.get();
    if (config != null) {
      config.isLoggedIn = false;
      await repo.save(config);
    }
  }

  /// Whether there's a live, unexpired Supabase session right now.
  static Future<bool> get isLoggedIn async {
    final session = SupabaseService.supabaseClient.auth.currentSession;
    return session != null && !session.isExpired;
  }
}

/// Outcome of [AuthService.login] or [AuthService.checkDeviceTrust]. Either
/// nothing more is needed, or this device must pass
/// [OtpMode.newDeviceVerification] - [store], [deviceId], [phone], and
/// [otpChannel] carry everything [completeNewDeviceLogin] and the OTP screen
/// need to finish that.
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
