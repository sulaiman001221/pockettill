import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../shared/models/store_config.dart';
import '../../shared/repositories/store_config_repository.dart';
import '../database/isar_service.dart';
import '../supabase/supabase_service.dart';

/// Registration, login, logout, and session state against Supabase Auth,
/// using real phone OTP verification (Twilio Verify, WhatsApp channel) for
/// registration and password reset, and phone + password for login (no OTP).
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

  /// Creates the `stores` row, registers this device, and saves
  /// [StoreConfig] locally. Call after [verifyOtp] and [setPassword] have
  /// both succeeded, so `auth.currentUser` is a real, password-protected,
  /// phone-verified account.
  static Future<void> createStore({
    required String storeName,
    required String ownerName,
    required String ownerPhone,
    String? address,
  }) async {
    final user = SupabaseService.supabaseClient.auth.currentUser;
    if (user == null) {
      throw Exception('createStore called with no authenticated user');
    }

    final isFoundingStore =
        await SupabaseService.supabaseClient.rpc('is_founding_store') as bool;

    final store = await SupabaseService.supabaseClient
        .from('stores')
        .insert({
          'name': storeName,
          'owner_name': ownerName,
          'owner_phone': ownerPhone,
          'address': address,
          'auth_user_id': user.id,
          'is_beta_adopter': isFoundingStore,
          'beta_joined_at': isFoundingStore
              ? DateTime.now().toUtc().toIso8601String()
              : null,
          'discount_rate': 1.0,
        })
        .select()
        .single();

    final repo = StoreConfigRepository(isar: IsarService.db);
    final existingConfig = await repo.get();
    final deviceId = existingConfig?.deviceId ?? _uuid.v4();

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
      ..isBetaAdopter = isFoundingStore
      ..isLoggedIn = true;

    await repo.save(config);
  }

  /// Signs in an existing store on this (or a new) device - phone +
  /// password only, no OTP.
  static Future<void> login({
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
      ..authUserId = authResponse.user!.id
      ..authPhone = formatted
      ..isBetaAdopter = store['is_beta_adopter'] as bool? ?? false
      ..isLoggedIn = true
      // Logging back in on a device that has already synced before isn't a
      // fresh start - carry the timestamp over rather than resetting it to
      // null, which would otherwise make the 30-day "never synced" warning
      // fire on every single login regardless of real sync history.
      ..lastSyncedAt = existingConfig?.lastSyncedAt;

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
