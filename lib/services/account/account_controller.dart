import 'package:regun/services/run_store.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:regun/models/account/account_session.dart';
import 'package:regun/models/player_profile.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/services/account/account_api.dart';
import 'package:regun/services/account/account_storage.dart';
import 'package:uuid/uuid.dart';

final accountProvider = Provider<AccountController>(
  (ref) => AccountController.shared,
);

class AccountController extends ChangeNotifier {
  AccountController({
    AccountApi? api,
    AccountSecrets? secrets,
    AccountLocalStore? store,
    LocalPreferences? preferences,
  }) : api = api ?? AccountApi(),
       _secrets = secrets ?? const SecureAccountSecrets(),
       _store = store ?? AccountLocalStore(),
       preferences = preferences ?? LocalPreferences.shared;
  static final shared = AccountController();
  final AccountApi api;
  final AccountSecrets _secrets;
  final AccountLocalStore _store;
  final LocalPreferences preferences;
  AccountSession? session;
  Map<String, dynamic>? account, _local;
  Future<void>? _initializing, _syncing, _refreshing;
  bool _applying = false, _disposed = false;
  int _generation = 0;
  final List<String> _revocations = [];
  bool conflict = false;
  String issue = '';
  String get username => account?['username'] as String? ?? '';
  String get email => account?['email'] as String? ?? '';
  bool get verified => session != null;
  bool get ready =>
      verified && username.isNotEmpty && account?['requiresRename'] != true;
  bool get attached => session?.accountId == preferences.profileOwner;
  bool get pending => _local?['pending'] == true;
  String get saveLabel => conflict
      ? 'Choose which progress to keep'
      : issue.isNotEmpty
      ? 'Saved on device · cloud backup pending'
      : pending
      ? 'Saved on device · waiting to sync'
      : account?['cloud'] != null
      ? 'Saved to cloud'
      : 'Saved on this device';
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  int _localPlays = 0;
  Completer<void>? _idle;
  Future<void> _profileTransition = Future.value();
  bool _changingProfile = false;
  Future<void> get localProfileReady => _profileTransition;
  Future<void> beginLocalPlay() async {
    // Only a local disk transition can delay entry, never an account request.
    if (_changingProfile) await _profileTransition;
    if (_localPlays++ == 0) _idle = Completer<void>();
  }

  void endLocalPlay() {
    if (_localPlays > 0 && --_localPlays == 0) {
      _idle?.complete();
      _idle = null;
    }
  }

  Future<void> _switchLocal(Future<void> Function() apply) {
    final next = _profileTransition.catchError((Object _) {}).then((_) async {
      while (_localPlays > 0) {
        await _idle!.future;
      }
      _changingProfile = true;
      try {
        await apply();
      } finally {
        _changingProfile = false;
      }
    });
    _profileTransition = next;
    return next;
  }

  /// Local IO only. There is deliberately no account verification/network here.
  Future<void> initialize() => _initializing ??= _initialize();
  Future<void> _initialize() async {
    try {
      final saved = await _secrets.read();
      if (saved != null) {
        final data = jsonDecode(saved) as Map<String, dynamic>;
        _revocations.addAll(
          (data['revocations'] as List? ?? []).whereType<String>(),
        );
        if (data['accountId'] is String) {
          session = AccountSession.fromJson(data);
        }
        account = data['account'] as Map<String, dynamic>?;
      }
    } catch (_) {
      /* Keychain failure must not prevent local play. */
    }
    final owner = preferences.profileOwner;
    if (owner != 'guest') {
      try {
        _local = await _store.read(owner);
        if (_local != null) {
          preferences.profile = PlayerProfile.fromJson(
            Map<String, dynamic>.from(_local!['profile'] as Map),
          );
          preferences.bestScore = preferences.profile.bestScore;
          preferences.bestSeconds = preferences.profile.bestSeconds;
        }
      } catch (_) {
        /* Existing preference backup remains playable. */
      }
    }
    preferences.persistAccountProfile = _persist;
    _notify();
  }

  Future<void> _persist(String owner, Map<String, dynamic> snapshot) async {
    if (_applying) return;
    if (_local?['owner'] != owner) _local = await _store.read(owner);
    _local = {
      ...?_local,
      'owner': owner,
      'profile': snapshot,
      'pending': true,
      'operation': const Uuid().v4(),
      'revision': _local?['revision'] ?? '0',
      'epoch': _local?['epoch'] ?? '0',
    };
    await _store.write(owner, _local!);
    // Upload is never part of a successful local save or settlement.
    if (session?.accountId == owner && !conflict) unawaited(sync());
    _notify();
  }

  Future<String> accessToken() async {
    await initialize();
    final s = session;
    if (s == null) {
      throw const AccountError('Verify your email to play online.');
    }
    if (s.expiresAt <= DateTime.now().millisecondsSinceEpoch ~/ 1000 + 60) {
      await (_refreshing ??= _refresh().whenComplete(() => _refreshing = null));
    }
    if (session == null) throw const AccountError('Sign in again');
    return session!.accessToken;
  }

  Future<void> _refresh() async {
    final original = session!, generation = _generation;
    final data = await api.request(
      '/refresh',
      body: {'refreshToken': original.refreshToken},
    );
    if (generation != _generation) {
      throw const AccountError('Account changed. Try again.');
    }
    session = AccountSession.fromJson(data);
    try {
      await _saveSession();
    } catch (_) {
      session = null;
      throw const AccountError(
        'Could not save your sign-in securely. Try again.',
      );
    }
  }

  Future<Map<String, dynamic>> requestCode(
    String email, {
    bool changeEmail = false,
  }) async => api.request(
    '/request',
    token: changeEmail ? await accessToken() : null,
    body: {'email': email, if (changeEmail) 'changeEmail': true},
  );
  Future<void> verifyCode(
    String requestId,
    String code, {
    String? expectedAccount,
  }) async {
    await initialize();
    final generation = ++_generation;
    final data = await api.request(
      '/verify',
      body: {'requestId': requestId, 'code': code},
    );
    final next = AccountSession.fromJson(data);
    if (expectedAccount != null && next.accountId != expectedAccount) {
      throw const AccountError(
        'Use the email already connected to this account.',
      );
    }
    if (generation != _generation) return;
    await _secrets.write(jsonEncode(next.toJson()));
    session = next;
    account = null;
    issue = '';
    await status();
  }

  Future<void> _saveSession() async {
    final s = session;
    if (s == null) {
      await _secrets.write(
        _revocations.isEmpty ? null : jsonEncode({'revocations': _revocations}),
      );
      return;
    }
    final cloud = account?['cloud'] as Map?;
    await _secrets.write(
      jsonEncode({
        ...s.toJson(),
        'revocations': _revocations,
        if (account != null)
          'account': {
            'accountId': s.accountId,
            'username': username,
            'requiresRename': account?['requiresRename'] == true,
            'email': email,
            'marketing': account?['marketing'] == true,
            'changesRemaining': account?['changesRemaining'],
            'resetAt': account?['resetAt'],
            if (cloud != null)
              'cloud': {
                'revision': cloud['revision'],
                'epoch': cloud['epoch'],
                'savedAt': cloud['savedAt'],
              },
          },
      }),
    );
  }

  Future<void> status() async {
    final generation = _generation;
    final data = await api.request('/account', token: await accessToken());
    if (generation != _generation) return;
    if (data['accountId'] != session?.accountId) {
      throw const AccountError('Account changed. Try again.');
    }
    account = data;
    issue = '';
    await _saveSession();
    _notify();
  }

  Future<void> rename(String name) async {
    final generation = _generation;
    final data = await api.request(
      '/username',
      token: await accessToken(),
      body: {'username': name, 'operation': const Uuid().v4()},
    );
    if (generation != _generation) return;
    account = data;
    await _saveSession();
    _notify();
  }

  Future<void> marketing(bool enabled) async {
    final generation = _generation;
    final data = await api.request(
      '/marketing',
      token: await accessToken(),
      body: {'enabled': enabled},
    );
    if (generation != _generation) return;
    account = data;
    await _saveSession();
    _notify();
  }

  bool _meaningful(PlayerProfile p) =>
      p.totalKills > 0 ||
      p.scrap > 0 ||
      p.challenges.isNotEmpty ||
      p.owned.length > 1;
  String _encoded(Map data) => jsonEncode(
    PlayerProfile.fromJson(Map<String, dynamic>.from(data)).toJson(),
  );

  Future<void> attach({bool useCloud = false, bool useDevice = false}) async {
    if (!ready) throw const AccountError('Choose your username first.');
    final id = session!.accountId, generation = _generation;
    final previous = await _store.read(id);
    if (generation != _generation) return;
    final candidate =
        previous?['profile'] as Map? ??
        (preferences.profileOwner == 'guest' || preferences.profileOwner == id
            ? preferences.profile.toJson()
            : PlayerProfile().toJson());
    final cloud = account?['cloud'] as Map?;
    if (cloud != null &&
        previous == null &&
        !useCloud &&
        !useDevice &&
        _meaningful(
          PlayerProfile.fromJson(Map<String, dynamic>.from(candidate)),
        ) &&
        _encoded(candidate) != _encoded(cloud['payload'] as Map)) {
      conflict = true;
      _notify();
      return;
    }
    final cloudRevision = cloud?['revision']?.toString() ?? '0';
    if (previous != null &&
        previous['pending'] == true &&
        cloudRevision != previous['revision'] &&
        !useCloud &&
        !useDevice) {
      _local = previous;
      conflict = true;
      _notify();
      return;
    }
    final sourceOwner = preferences.profileOwner;
    final currentCandidate =
        sourceOwner == id || (previous == null && sourceOwner == 'guest');
    final takeCloud =
        cloud != null &&
        (useCloud || (!useDevice && previous?['pending'] != true));
    final profile = PlayerProfile.fromJson(
      Map<String, dynamic>.from(
        takeCloud ? cloud['payload'] as Map : candidate,
      ),
    );
    final incoming = <String, dynamic>{
      'owner': id,
      'profile': profile.toJson(),
      'revision': cloudRevision,
      'epoch': cloud?['epoch']?.toString() ?? '0',
      'pending': !takeCloud,
      'operation': const Uuid().v4(),
    };
    await _switchLocal(() async {
      if (generation != _generation) return;
      final applied =
          !takeCloud &&
              currentCandidate &&
              preferences.profileOwner == sourceOwner
          ? preferences.profile
          : profile;
      incoming['profile'] = applied.toJson();
      _local = incoming;
      await _store.write(id, _local!);
      _applying = true;
      try {
        await preferences.activateProfile(id, initial: applied);
      } finally {
        _applying = false;
      }
    });
    conflict = false;
    _notify();
    await sync();
  }

  Future<void> sync() => _syncing ??= _sync().whenComplete(() {
    _syncing = null;
    if (api.configured &&
        ready &&
        pending &&
        !conflict &&
        issue.isEmpty &&
        attached) {
      scheduleMicrotask(() => unawaited(sync()));
    }
  });
  Future<void> _sync() async {
    if (!api.configured) return;
    if (_revocations.isNotEmpty) {
      for (final value in List<String>.of(_revocations)) {
        try {
          await api.request('/revoke', body: {'refreshToken': value});
          _revocations.remove(value);
          await _saveSession();
        } catch (_) {
          break;
        }
      }
    }
    if (session == null || conflict) return;
    final generation = _generation, id = session!.accountId;
    try {
      await status();
      if (generation != _generation || !ready) return;
      if (!attached) {
        return;
      } // Attachment/restoration is an explicit account flow.
      _local ??= await _store.read(id);
      if (_local == null || _local!['pending'] != true) {
        final remote = account?['cloud'] as Map?;
        if (_local != null &&
            remote != null &&
            (remote['revision'].toString() != _local!['revision'] ||
                remote['epoch'].toString() != _local!['epoch'])) {
          if (_encoded(_local!['profile'] as Map) !=
              _encoded(remote['payload'] as Map)) {
            conflict = true;
          } else {
            _local = {
              ..._local!,
              'revision': remote['revision'].toString(),
              'epoch': remote['epoch'].toString(),
            };
            await _store.write(id, _local!);
          }
          _notify();
        }
        return;
      }
      final outgoing = Map<String, dynamic>.from(_local!);
      final remote = account?['cloud'] as Map?;
      if ((remote?['revision']?.toString() ?? '0') != outgoing['revision'] ||
          (remote?['epoch']?.toString() ?? '0') != outgoing['epoch']) {
        if (remote != null &&
            remote['epoch'].toString() == outgoing['epoch'] &&
            _encoded(remote['payload'] as Map) ==
                _encoded(outgoing['profile'] as Map)) {
          _local = {
            ..._local!,
            'revision': remote['revision'].toString(),
            'pending': _local!['operation'] != outgoing['operation'],
          };
          await _store.write(id, _local!);
          issue = '';
          _notify();
          return;
        }
        conflict = true;
        _notify();
        return;
      }
      final data = await api.request(
        '/save',
        token: await accessToken(),
        body: {
          'payload': outgoing['profile'],
          'revision': outgoing['revision'],
          'epoch': outgoing['epoch'],
          'operation': outgoing['operation'],
        },
      );
      if (generation != _generation) return;
      account = data;
      _local = {
        ..._local!,
        'revision': (data['cloud'] as Map)['revision'].toString(),
        'pending': _local!['operation'] != outgoing['operation'],
      };
      await _store.write(id, _local!);
      issue = '';
      _notify();
    } on AccountError catch (e) {
      if (generation == _generation) {
        issue = e.message;
        if (e.status == 409) conflict = true;
        _notify();
      }
    } catch (_) {
      if (generation == _generation) {
        issue = 'Cloud backup pending. Your progress stays on this device.';
        _notify();
      }
    }
  }

  Future<void> claimGuest(String guestToken) async {
    final generation = _generation;
    final data = await api.request(
      '/claim-guest',
      token: await accessToken(),
      body: {'guestToken': guestToken},
    );
    if (generation != _generation) return;
    account = data;
    _notify();
  }

  Future<void> resetProgress() async {
    if (!ready || !attached) {
      throw const AccountError('Sign in to reset cloud progress.');
    }
    final generation = _generation;
    await status();
    final cloud = account?['cloud'] as Map?;
    final profile = PlayerProfile();
    final data = await api.request(
      '/reset',
      token: await accessToken(),
      body: {
        'revision': cloud?['revision']?.toString() ?? '0',
        'epoch': cloud?['epoch']?.toString() ?? '0',
        'operation': const Uuid().v4(),
        'payload': profile.toJson(),
      },
    );
    if (generation != _generation) return;
    account = data;
    final incoming = <String, dynamic>{
      'owner': session!.accountId,
      'profile': profile.toJson(),
      'revision': data['cloud']['revision'].toString(),
      'epoch': data['cloud']['epoch'].toString(),
      'pending': false,
      'operation': const Uuid().v4(),
    };
    final owner = session!.accountId;
    await _switchLocal(() async {
      if (generation != _generation) return;
      _local = incoming;
      await _store.write(owner, incoming);
      _applying = true;
      try {
        await preferences.resetProgress();
      } finally {
        _applying = false;
      }
    });
    conflict = false;
    issue = '';
    _notify();
  }

  Future<void> signOut() async {
    final original = session, generation = _generation;
    if (original != null) {
      try {
        await api.request('/signout', token: await accessToken(), body: {});
      } catch (_) {
        // Local disconnect is available offline; revoke the opaque credential on reconnection.
        final refresh = generation == _generation
            ? session?.refreshToken ?? original.refreshToken
            : original.refreshToken;
        if (!_revocations.contains(refresh)) _revocations.add(refresh);
      }
    }
    if (generation != _generation) {
      await _saveSession();
      return;
    }
    await _clearSession();
  }

  Future<void> deleteAccount() async {
    final owner = session?.accountId, generation = _generation;
    if (owner == null) return;
    await api.request('/delete', token: await accessToken(), body: {});
    if (generation == _generation) await _clearSession();
    await _switchLocal(() async {
      await _store.remove(owner);
      await preferences.removeAccountProfile(owner);
      await RunStore.shared.clearOwner(owner);
    });
  }

  Future<void> _clearSession() async {
    ++_generation;
    session = null;
    await _saveSession();
    account = null;
    _local = null;
    conflict = false;
    issue = '';
    await _switchLocal(() async {
      _applying = true;
      try {
        await preferences.activateProfile('guest');
      } finally {
        _applying = false;
      }
    });
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
