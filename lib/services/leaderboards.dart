import 'package:regun/services/player_registry.dart';
import 'package:regun/services/account/account_api.dart';

import 'dart:async';

import 'package:regun/services/account/account_controller.dart';

/// Owner-scoped durable run outbox is part of PlayerProfile's atomic settlement.
/// Publication is automatic for accounts and guests, outside the simulation.
class Leaderboards {
  Leaderboards({AccountController? account, PlayerRegistry? registry})
    : account = account ?? AccountController.shared,
      registry = registry ?? PlayerRegistry.shared;
  static final shared = Leaderboards();
  final AccountController account;
  final PlayerRegistry registry;
  Future<void>? _sending;
  // Public gameplay data only; own-row/auth state is never cached here.
  Map<String, dynamic>? cachedBoard;
  final Map<String, Map<String, dynamic>> _cachedProfiles = {};
  Map<String, dynamic>? cachedProfile(String key) => _cachedProfiles[key];
  void cacheProfile(String key, Map<String, dynamic> value) {
    _cachedProfiles.remove(key);
    _cachedProfiles[key] = value;
    if (_cachedProfiles.length > 32) {
      _cachedProfiles.remove(_cachedProfiles.keys.first);
    }
  }

  void forgetProfile(String key) => _cachedProfiles.remove(key);
  void clearPublicCache() {
    cachedBoard = null;
    _cachedProfiles.clear();
  }

  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = false,
  }) async {
    if (!account.api.configured) {
      throw const AccountError('Leaderboards are not available yet.');
    }
    final owner = account.preferences.profileOwner;
    final token = authenticated ? await account.accessToken() : null;
    if (authenticated &&
        (!account.attached || account.session?.accountId != owner)) {
      throw StateError('Account changed.');
    }
    final result = await account.api.request(path, body: body, token: token);
    if (authenticated &&
        (!account.attached || account.session?.accountId != owner)) {
      throw StateError('Account changed.');
    }
    return result;
  }

  Future<Map<String, dynamic>?> myEntry() async {
    if (account.attached && account.verified && !account.needsSignIn) {
      return (await request(
            '/leaderboards/v1/me',
            body: {},
            authenticated: true,
          ))['entry']
          as Map<String, dynamic>?;
    }
    if (account.preferences.profileOwner != 'guest') return null;
    final credentials = await registry.publicCredentials();
    if (credentials == null) return null;
    return (await request('/leaderboards/v1/me', body: credentials))['entry']
        as Map<String, dynamic>?;
  }

  /// Publish the latest career snapshot without waiting for the run receipt queue.
  Future<void> publishProfile() async {
    try {
      final preferences = account.preferences;
      await registry.record(
        preferences.profileOwner,
        preferences.profile.toJson(),
        force: true,
      );
      await registry.refresh(force: true);
    } catch (_) {
      // Public browsing remains available when publishing this device fails.
    }
  }

  Future<void> flush() =>
      _sending ??= _flush().whenComplete(() => _sending = null);
  Future<void> _flush() async {
    try {
      final preferences = account.preferences;
      final owner = preferences.profileOwner;
      await publishProfile();
      if (!account.ready ||
          !account.attached ||
          account.needsSignIn ||
          owner == 'guest') {
        return;
      }
      final config = await request('/leaderboards/v1/config');
      if (config['submissions'] != true) return;
      if (preferences.profileOwner != owner || !account.attached) return;
      if (!await preferences.saveProfile()) return;
      for (final entry in preferences.profile.runRecords.entries.toList().take(
        100,
      )) {
        if (preferences.profileOwner != owner ||
            !account.attached ||
            account.session?.accountId != owner) {
          return;
        }
        final value = entry.value;
        if (value['owner'] != owner ||
            !preferences.profile.settledRuns.contains(entry.key) ||
            value['status'] != 'local') {
          continue;
        }
        final summary = Map<String, dynamic>.from(value['summary'] as Map);
        if (summary['complete'] != true || summary['revived'] == true) continue;
        try {
          final receipt = await request(
            '/leaderboards/v1/runs',
            body: summary,
            authenticated: true,
          );
          if (preferences.profileOwner != owner ||
              !account.attached ||
              account.session?.accountId != owner) {
            return;
          }
          if (receipt['runId'] != entry.key ||
              ![
                'accepted',
                'pending_review',
                'excluded',
                'withdrawn',
              ].contains(receipt['status'])) {
            throw StateError('Invalid record receipt');
          }
          // Retain receipt plus summary for private status. Acknowledged records
          // may be compacted only after their durable status commit.
          value['status'] = receipt['status'];
          if (!await preferences.saveProfile()) {
            value['status'] = 'local';
            return;
          }
        } on AccountError catch (e) {
          if (preferences.profileOwner == owner &&
              account.attached &&
              [400, 409].contains(e.status)) {
            value['status'] = 'personal_only';
            value['reason'] = e.message;
            if (!await preferences.saveProfile()) {
              value['status'] = 'local';
              return;
            }
            continue;
          }
          return;
        } catch (_) {
          return;
        } // Retry on next Home/foreground, never a tight loop.
      }
    } catch (_) {
      /* Publication cannot delay Home or offline play. */
    }
  }
}
