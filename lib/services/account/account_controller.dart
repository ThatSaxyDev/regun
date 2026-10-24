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
  void Function(String accountId)? onGuestAttached;
  bool conflict = false;
  String issue = '';
  String get username => account?['username'] as String? ?? '';
  String get email => account?['email'] as String? ?? '';
  bool get verified => session != null;
  bool get ready =>
      verified && username.isNotEmpty && account?['requiresRename'] != true;
  bool get attached => session?.accountId == preferences.profileOwner;
  bool get pending => _local?['pending'] == true;
  String get saveLabel {
    if (_local?['purchase'] != null) {
      if (_local?['purchaseStatus'] == 'blocked') {
        return 'Purchase blocked · retry in Collection';
      }
      if (_local?['purchaseStatus'] == 'not_found') {
        return 'Purchase not completed · retry in Collection';
      }
      return 'Purchase awaiting confirmation';
    }
    if (conflict) return 'Choose which progress to keep';
    if (issue.isNotEmpty) return 'Saved on device · cloud backup pending';
    if (pending) return 'Saved on device · waiting to sync';
    return account?['cloud'] != null
        ? 'Saved to cloud'
        : 'Saved on this device';
  }

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
    preferences.spendingAuthorized = () => verified && attached && !conflict;
    preferences.purchaseOnline = purchaseCosmetic;
    preferences.purchaseQuotedOnline = (id, price, catalog) =>
        purchaseCosmetic(id, displayedPrice: price, displayedCatalog: catalog);
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

  Future<Map<String, dynamic>> requestCode(String email) async =>
      api.request('/request', body: {'email': email});
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
    if (sourceOwner == 'guest' &&
        generation == _generation &&
        preferences.profileOwner == id) {
      try {
        onGuestAttached?.call(id);
      } catch (_) {
        /* Background directory linkage never gates local play. */
      }
    }
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
        attached &&
        _local?['purchase'] == null) {
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
    if (_local?['purchase'] != null) {
      await _reconcilePurchase();
      if (_local?['purchase'] != null || conflict) return;
    }
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
      await _confirmWallet(data);
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

  // Reconcile the wallet separately from offline gameplay progression. Server
  // ownership is authoritative for shop items; challenge unlocks remain earned.
  PlayerProfile _withWallet(Map base, Map remote) {
    final profile = PlayerProfile.fromJson(Map<String, dynamic>.from(base));
    final confirmed = PlayerProfile.fromJson(Map<String, dynamic>.from(remote));
    final extra = (profile.earnedScrapTotal - confirmed.earnedScrapTotal).clamp(
      0,
      1000000000,
    );
    profile.scrap = confirmed.scrap + extra;
    profile.earnedScrapTotal = confirmed.earnedScrapTotal + extra;
    profile.owned.removeAll(shopCosmetics.keys);
    profile.owned.addAll(confirmed.owned.where(shopCosmetics.containsKey));
    if (!profile.owned.contains(profile.cosmetic)) {
      profile.cosmetic = 'standard';
    }
    return profile;
  }

  Future<void> _confirmWallet(
    Map<String, dynamic> data, {
    bool clearPurchase = false,
  }) async {
    final owner = session!.accountId, generation = _generation;
    final cloud = data['cloud'] as Map;
    final remote = cloud['payload'] as Map;
    final localProfile = _withWallet(_local!['profile'] as Map, remote);
    final confirmedLocal = {
      ..._local!,
      'profile': localProfile.toJson(),
      'revision': cloud['revision'].toString(),
      'epoch': cloud['epoch'].toString(),
    };
    if (clearPurchase) {
      confirmedLocal.remove('purchase');
      confirmedLocal.remove('purchaseStatus');
    }
    await _store.write(owner, confirmedLocal);
    if (generation != _generation || session?.accountId != owner) return;
    // A purchase runs under the local transition lock; ordinary uploads retain
    // any newer pending gameplay snapshot queued while the write was in flight.
    if (clearPurchase || _local!['operation'] == confirmedLocal['operation']) {
      _local = confirmedLocal;
    }
    if (!attached) return;
    preferences.profile = _withWallet(preferences.profile.toJson(), remote);
    // Persist a compatibility mirror without creating a second upload operation.
    await preferences.saveProfile(notifyAccount: false);
  }

  /// Read receipt only: Sync/reconnect must never submit a purchase mutation.
  Future<void> _reconcilePurchase() async {
    final operation = _local?['purchase'] as Map?;
    if (operation == null || !attached) return;
    final generation = _generation, owner = session!.accountId;
    try {
      final data = await api.request(
        '/purchase-status',
        token: await accessToken(),
        body: {'operation': operation['operation']},
      );
      if (generation != _generation ||
          !attached ||
          data['accountId'] != owner ||
          _local?['purchase']?['operation'] != operation['operation']) {
        return;
      }
      if (data['purchaseOperation'] != operation['operation']) {
        throw const AccountError(
          'Could not verify the purchase. Retry in Collection.',
        );
      }
      if (data['cloud']?['epoch']?.toString() != _local?['epoch']) {
        conflict = true;
        issue = 'Progress changed. Choose which progress to keep.';
        return;
      }
      if (data['purchaseCancelled'] == true) {
        await _confirmWallet(data, clearPurchase: true);
        issue = '';
        return;
      }
      final receipt = data['purchaseReceipt'] as Map?;
      if (receipt == null) {
        _local = {..._local!, 'purchaseStatus': 'not_found'};
        await _store.write(owner, _local!);
        issue = 'Purchase has not completed. Retry it in Collection.';
        return;
      }
      if (receipt['item'] != operation['item'] ||
          receipt['catalog'] != operation['catalog'] ||
          receipt['epoch'] != operation['epoch']) {
        throw const AccountError(
          'Purchase receipt did not match. Retry in Collection.',
        );
      }
      if (data['cloud']?['epoch']?.toString() != _local?['epoch']) {
        conflict = true;
        issue = 'Progress changed. Choose which progress to keep.';
        return;
      }
      if (!(data['cloud']?['payload']?['owned'] as List? ?? []).contains(
        operation['item'],
      )) {
        throw const AccountError(
          'Could not restore this purchase. Retry in Collection.',
        );
      }
      account = data;
      await _confirmWallet(data, clearPurchase: true);
      issue = '';
    } on AccountError catch (error) {
      if (generation != _generation || !attached) return;
      issue = error.message;
      if (error.status == 403) {
        _local = {..._local!, 'purchaseStatus': 'blocked'};
        await _store.write(owner, _local!);
      }
    } catch (_) {
      if (generation == _generation && attached) {
        issue = 'Could not check the purchase. Retry when connected.';
      }
    } finally {
      _notify();
    }
  }

  String? get pendingPurchaseItem => _local?['purchase']?['item'] as String?;

  /// Atomically cancel an uncommitted intent, or recover its committed receipt.
  Future<void> cancelPendingPurchase() async {
    final generation = _generation;
    await _switchLocal(() async {
      final operation = _local?['purchase'] as Map?;
      if (!verified || !attached || operation == null) return;
      try {
        final data = await api.request(
          '/purchase-cancel',
          token: await accessToken(),
          body: {'operation': operation['operation']},
        );
        if (generation != _generation ||
            !attached ||
            data['accountId'] != session?.accountId ||
            data['purchaseOperation'] != operation['operation']) {
          return;
        }
        if (data['cloud']?['epoch']?.toString() != _local?['epoch']) {
          conflict = true;
          issue = 'Progress changed. Choose which progress to keep.';
          return;
        }
        if (data['purchaseCancelled'] == true) {
          await _confirmWallet(data, clearPurchase: true);
          issue = 'Purchase cancelled. Check the price before buying again.';
        } else {
          await _reconcilePurchase();
        }
      } on AccountError catch (e) {
        if (generation == _generation && attached) issue = e.message;
      } catch (_) {
        if (generation == _generation && attached) {
          issue = 'Could not save the purchase status. Retry when connected.';
        }
      }
    });
    _notify();
  }

  Future<Map<String, dynamic>> soloRecoveryRequest(
    Map<String, dynamic> body,
  ) async {
    await initialize();
    if (!verified || !attached) {
      throw const AccountError('Sign in with the email that owns this run.');
    }
    final owner = session!.accountId, generation = _generation;
    // The run is frozen. Local-play ownership prevents profile switches, while
    // ordinary account sync is safe and does not settle this run's earnings.
    if (body['action'] == 'offer') await sync();
    if (_local == null ||
        !attached ||
        (body['action'] == 'offer' && (pending || conflict))) {
      throw const AccountError('Sync your account before reviving.');
    }
    final epoch = body['epoch'] == '' ? _local!['epoch'] : body['epoch'];
    final data = await api.request(
      '/solo-revive',
      token: await accessToken(),
      body: {...body, 'epoch': epoch},
    );
    if (generation != _generation ||
        session?.accountId != owner ||
        !attached ||
        data['accountId'] != owner) {
      throw const AccountError('Account changed. Recovery is paused.');
    }
    account = data;
    await _confirmWallet(data);
    _notify();
    return data;
  }

  Future<CosmeticPurchase> purchaseCosmetic(
    String item, {
    int? displayedPrice,
    String? displayedCatalog,
  }) async {
    if (!verified || !attached) return CosmeticPurchase.signInRequired;
    if (!api.configured) return CosmeticPurchase.onlineRequired;
    final generation = _generation, owner = session!.accountId;
    var result = CosmeticPurchase.unavailable;
    await _switchLocal(() async {
      try {
        // A saved receipt key is retried before sync: its lost response may
        // already have advanced the server revision. Never auto-retry a spend.
        var previous = _local?['purchase'] as Map?;
        if (previous != null && previous['item'] != item) {
          issue = 'Retry the pending purchase first.';
          result = CosmeticPurchase.pendingConfirmation;
          return;
        }
        Map<String, dynamic> operation;
        if (previous != null) {
          operation = Map<String, dynamic>.from(previous);
        } else {
          await sync();
          if (generation != _generation ||
              !attached ||
              conflict ||
              pending ||
              issue.isNotEmpty) {
            result = CosmeticPurchase.onlineRequired;
            return;
          }
          final cloud = account?['cloud'] as Map?;
          final catalog = account?['catalog'] as Map?;
          if (cloud == null || catalog == null || _local == null) {
            result = CosmeticPurchase.onlineRequired;
            return;
          }
          if ((catalog['prices'] as Map?)?[item] !=
                  (displayedPrice ?? shopCosmetics[item]) ||
              (displayedCatalog != null &&
                  catalog['version'] != displayedCatalog) ||
              ((catalog['available'] as Map?)?[item] == false)) {
            issue = 'Shop changed. Refresh before purchasing.';
            return;
          }
          operation = {
            'item': item,
            'catalog': catalog['version'],
            'revision': cloud['revision'].toString(),
            'epoch': cloud['epoch'].toString(),
            'operation': const Uuid().v4(),
          };
        }
        _local = {..._local!, 'purchase': operation}..remove('purchaseStatus');
        await _store.write(
          owner,
          _local!,
        ); // Retain key across lost responses/restarts.
        final data = await api.request(
          '/purchase',
          token: await accessToken(),
          body: operation,
        );
        if (generation != _generation ||
            !attached ||
            data['accountId'] != owner) {
          return;
        }
        final remote = data['cloud']?['payload'] as Map?;
        if (remote == null || !(remote['owned'] as List).contains(item)) {
          result = CosmeticPurchase.unavailable;
          return;
        }
        account = data;
        await _confirmWallet(data, clearPurchase: true);
        if (generation != _generation || !attached) return;
        preferences.profile.cosmetic = item;
        // Equip is local and remains available without a network request.
        await preferences.saveProfile(notifyAccount: false);
        _local = {..._local!, 'profile': preferences.profile.toJson()};
        await _store.write(owner, _local!);
        issue = '';
        result = CosmeticPurchase.saved;
      } on AccountError catch (e) {
        if (generation != _generation || !attached) return;
        issue = e.message;
        // Even a rejected retry may follow an earlier committed request whose
        // response was lost. Retain its key until the receipt is reconciled.
        if (e.status == 403 && _local != null) {
          _local = {..._local!, 'purchaseStatus': 'blocked'};
          await _store.write(owner, _local!);
        }
        result = e.message == 'Not enough Scrap'
            ? CosmeticPurchase.insufficientFunds
            : CosmeticPurchase.onlineRequired;
      } catch (_) {
        if (generation != _generation || !attached) return;
        issue = 'Connect to complete your purchase. Retry to check its status.';
        result = CosmeticPurchase.onlineRequired;
      }
    });
    _notify();
    return result;
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
    var profile = PlayerProfile();
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
    profile = PlayerProfile.fromJson(
      Map<String, dynamic>.from(data['cloud']['payload'] as Map),
    );
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
        preferences.profile = profile;
        await preferences.saveProfile();
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
