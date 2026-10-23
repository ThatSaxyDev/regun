import 'package:regun/models/player_profile.dart';

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/models/control_layout.dart';

/// Small device preferences and records. Full run checkpoints are a separate
/// milestone; these keys do not claim to serialize a living Flame world.
enum CosmeticPurchase {
  signInRequired,
  saved,
  insufficientFunds,
  unavailable,
  saveFailed,
  onlineRequired,
  pendingConfirmation,
}

class LocalPreferences extends ChangeNotifier {
  static final shared = LocalPreferences();
  PlayerProfile _profile = PlayerProfile();
  PlayerProfile get profile => _profile;
  set profile(PlayerProfile value) {
    _profile = value;
    notifyListeners();
  }

  bool profileReady = false;
  bool profileSaveFailed = false;
  bool _buying = false;
  bool Function()? spendingAuthorized;
  Future<CosmeticPurchase> Function(String id)? purchaseOnline;
  bool get canSpend =>
      profileOwner != 'guest' && (spendingAuthorized?.call() ?? false);

  String _profileOwner = 'guest';
  String get profileOwner => _profileOwner;
  set profileOwner(String owner) {
    if (_profileOwner == owner) return;
    _profileOwner = owner;
    _profile = PlayerProfile();
    profileReady = false;
    profileSaveFailed = false;
    _onlineScrap = null;
    notifyListeners();
  }

  int? _onlineScrap;
  int? get onlineScrap => _onlineScrap;
  void updateOnlineScrap(String owner, int amount) {
    if (owner == 'guest' ||
        owner != profileOwner ||
        amount < 0 ||
        _onlineScrap == amount) {
      return;
    }
    _onlineScrap = amount;
    notifyListeners();
  }

  void Function(String owner, Map<String, dynamic> snapshot)? onProfileSaved;
  Future<void> Function(String owner, Map<String, dynamic> snapshot)?
  persistAccountProfile;
  String get _profileKey =>
      profileOwner == 'guest' ? 'profile.v1' : 'profile.account.$profileOwner';
  String get _backupKey => profileOwner == 'guest'
      ? 'profile.backup.v1'
      : 'profile.account.$profileOwner.backup';
  String _recordKey(String field) =>
      profileOwner == 'guest' ? 'record.$field' : 'record.$profileOwner.$field';

  double musicVolume = 0.6, sfxVolume = 0.8;
  bool haptics = true, reducedMotion = false, aimAssist = false;
  Future<void> _saving = Future.value();
  SharedPreferences? _storage;
  int bestScore = 0;
  int bestSeconds = 0;
  String onlineName = 'Rook';
  ControlLayout controls = const ControlLayout();

  Future<void> load() async {
    try {
      await _saving;
      // Do not overwrite an unsaved run reward with the older disk snapshot.
      if (profileSaveFailed && !await saveProfile()) return;
      // Once the account controller has restored its atomic profile/outbox,
      // a menu refresh must not replace it with an older preference mirror.
      if (profileReady &&
          profileOwner != 'guest' &&
          persistAccountProfile != null) {
        return;
      }
      _storage = await SharedPreferences.getInstance();
      profileOwner = _storage!.getString('profile.activeOwner') ?? 'guest';
      if (profileOwner != 'guest' &&
          !RegExp(r'^[a-f0-9-]{36}$').hasMatch(profileOwner)) {
        profileOwner = 'guest';
      }
      onlineName = _storage!.getString('online.name') ?? 'Rook';
      musicVolume = (_storage!.getDouble('settings.music') ?? 0.6).clamp(0, 1);
      sfxVolume = (_storage!.getDouble('settings.sfx') ?? 0.8).clamp(0, 1);
      haptics = _storage!.getBool('settings.haptics') ?? true;
      reducedMotion = _storage!.getBool('settings.motion') ?? false;
      aimAssist = _storage!.getBool('settings.aim') ?? false;
      profile = PlayerProfile();
      for (final key in [_profileKey, _backupKey]) {
        try {
          final encoded = _storage!.getString(key);
          if (encoded == null) continue;
          final decoded = Map<String, dynamic>.from(jsonDecode(encoded) as Map);
          if (![1, 2, 3].contains(decoded['schema'])) continue;
          profile = PlayerProfile.fromJson(decoded);
          break;
        } on FormatException {
          /* Try the last completed profile. */
        } on TypeError {
          /* Try the last completed profile. */
        }
      }
      bestScore = _storage!.getInt(_recordKey('score')) ?? 0;
      bestSeconds = _storage!.getInt(_recordKey('seconds')) ?? 0;
      final encoded = _storage!.getString('controls.v1');
      if (encoded != null) {
        controls = ControlLayout.fromJson(
          Map<String, dynamic>.from(jsonDecode(encoded) as Map),
        );
      }
    } on MissingPluginException {
      // Headless test environments may have no platform preference channel.
    } on FormatException {
      controls = const ControlLayout();
    } on TypeError {
      controls = const ControlLayout();
    } on PlatformException {
      // Storage failure must not prevent starting an offline run.
    } finally {
      profileReady = true;
      notifyListeners();
    }
  }

  Future<bool> saveProfile({PlayerProfile? next, bool notifyAccount = true}) {
    final payload = jsonEncode((next ?? profile).toJson());
    final snapshot = jsonDecode(payload) as Map<String, dynamic>;
    final owner = profileOwner;
    final primaryKey = _profileKey, backupKey = _backupKey;
    var success = false;
    final operation = _saving.then((_) async {
      var accountSaved = !notifyAccount && owner != 'guest';
      try {
        if (notifyAccount &&
            owner != 'guest' &&
            persistAccountProfile != null) {
          await persistAccountProfile!(owner, snapshot);
          accountSaved = true;
        }
        final previous = _storage?.getString(primaryKey);
        if (previous != null) {
          try {
            final decoded = jsonDecode(previous);
            if (decoded is Map && [1, 2, 3].contains(decoded['schema'])) {
              await _storage?.setString(backupKey, previous);
            }
          } on FormatException {
            /* Retain the existing backup. */
          }
        }

        // The account store is the durable owner-scoped source; preferences
        // are its compatibility mirror, not a second required commit.
        try {
          success = await _storage?.setString(primaryKey, payload) ?? false;
        } catch (_) {
          success = false;
        }
        success = success || accountSaved;
        if (success) {
          try {
            onProfileSaved?.call(owner, snapshot);
          } catch (_) {
            /* Reporting cannot undo a local save. */
          }
        }
      } catch (_) {
        success = accountSaved;
      }
      if (profileOwner == owner) {
        if (success && next != null) _profile = next;
        // A staged purchase failure leaves the original profile untouched.
        if (next == null || success) profileSaveFailed = !success;
        notifyListeners();
      }
    });
    _saving = operation;
    return operation.then((_) => success);
  }

  /// Ownership already cached on this device remains usable offline. A new
  /// purchase has no local fallback: only the account service may authorize it.
  Future<CosmeticPurchase> buyCosmetic(String id) async {
    if (!canSpend) return CosmeticPurchase.signInRequired;
    if (_buying || !profileReady || profileSaveFailed) {
      return CosmeticPurchase.unavailable;
    }
    if (!shopCosmetics.containsKey(id) || profile.owned.contains(id)) {
      return CosmeticPurchase.unavailable;
    }
    final purchase = purchaseOnline;
    if (purchase == null) return CosmeticPurchase.onlineRequired;
    _buying = true;
    try {
      return await purchase(id);
    } finally {
      _buying = false;
    }
  }

  Future<void> activateProfile(String owner, {PlayerProfile? initial}) async {
    await _saving;
    if (owner != 'guest' && !RegExp(r'^[a-f0-9-]{36}$').hasMatch(owner)) {
      throw const FormatException('Invalid account');
    }
    _storage ??= await SharedPreferences.getInstance();
    await _storage!.setString('profile.activeOwner', owner);
    profileOwner = owner;
    await load();
    if (initial != null) {
      profile = initial;
      bestScore = initial.bestScore;
      bestSeconds = initial.bestSeconds;
      await saveProfile();
    }
  }

  Future<void> removeAccountProfile(String owner) async {
    if (!RegExp(r'^[a-f0-9-]{36}$').hasMatch(owner)) {
      throw const FormatException('Invalid account');
    }
    await _saving;
    for (final key in [
      'profile.account.$owner',
      'profile.account.$owner.backup',
      'record.$owner.score',
      'record.$owner.seconds',
    ]) {
      await _storage?.remove(key);
    }
  }

  Future<void> resetProgress() async {
    await _saving;
    profile = PlayerProfile();
    bestScore = 0;
    bestSeconds = 0;
    try {
      for (final key in [
        _profileKey,
        _backupKey,
        _recordKey('score'),
        _recordKey('seconds'),
      ]) {
        await _storage?.remove(key);
      }
    } on PlatformException {
      /* Report the next attempted write through its result. */
    }
    await saveProfile();
  }

  Future<void> completeTraining() async {
    profile.challenges.add('training');
    await saveProfile();
  }

  Future<void> saveSettings() async {
    try {
      await _storage?.setDouble('settings.music', musicVolume);
      await _storage?.setDouble('settings.sfx', sfxVolume);
      await _storage?.setBool('settings.haptics', haptics);
      await _storage?.setBool('settings.motion', reducedMotion);
      await _storage?.setBool('settings.aim', aimAssist);
    } on PlatformException {
      /* Settings remain active in memory. */
    }
  }

  Future<void> saveOnlineName(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    onlineName = trimmed;
    try {
      await _storage?.setString('online.name', trimmed);
    } on PlatformException {
      /* Retain the name for this visit. */
    }
  }

  Future<bool> saveControls(ControlLayout value) async {
    controls = value;
    try {
      return await _storage?.setString(
            'controls.v1',
            jsonEncode(value.toJson()),
          ) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> record({required int score, required int seconds}) async {
    if (score > bestScore) bestScore = score;
    if (seconds > bestSeconds) bestSeconds = seconds;
    try {
      await _storage?.setInt(_recordKey('score'), bestScore);
      await _storage?.setInt(_recordKey('seconds'), bestSeconds);
    } on PlatformException {
      // Keep the in-memory record; do not crash the results screen.
    }
  }
}
