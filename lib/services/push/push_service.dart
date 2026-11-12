import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:regun/services/push/push_api.dart';
import 'package:regun/services/push/push_router.dart';

/// Mobile-only push lifecycle. Every entry point is best-effort: an unavailable
/// provider, missing credential or failed request never blocks gameplay.
class PushService {
  PushService({PushApi? api, GlobalKey<NavigatorState>? navigatorKey})
    : api = api ?? PushApi(),
      router = PushRouter(navigatorKey ?? pushNavigatorKey, pushScreenFor);

  static final shared = PushService();

  /// Assigned from `main.dart` before `shared` is first touched.
  static GlobalKey<NavigatorState>? pushNavigatorKey;
  static Widget? Function(String route)? pushScreenFor;

  static const appId = String.fromEnvironment('ONESIGNAL_APP_ID');

  final PushApi api;
  final PushRouter router;
  final ValueNotifier<PushStatus> status = ValueNotifier(
    PushStatus.unsupported,
  );
  final ValueNotifier<Map<String, bool>> preferences = ValueNotifier(const {
    'master': true,
    'security': true,
    'leaderboards': false,
    'events': false,
    'reengagement': false,
    'returnReminders': false,
  });

  /// Injected by the composition root to avoid a controller import cycle.
  String? Function()? accountId;
  Future<String?> Function()? accessToken;
  Future<Map<String, dynamic>?> Function()? guestCredentials;

  bool _initialized = false;
  bool _suppressForeground = false;
  String? _subscriptionId;
  String? _lastReported;
  DateTime? _reportedAt;
  String? _preferenceOwner;
  String? _pendingOpen;
  bool _identityReady = true;
  Future<void> _identitySync = Future.value();
  static const _timezoneChannel = MethodChannel('regun/push_timezone');

  String? get subscriptionId => _subscriptionId;

  static const _askedKey = 'regun.push.asked.v1';
  static const _promptedKey = 'regun.push.prompted.v1';

  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  bool get configured => supported && appId.isNotEmpty;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (!configured) {
      status.value = supported
          ? PushStatus.unconfigured
          : PushStatus.unsupported;
      return;
    }
    try {
      await OneSignal.initialize(appId);
      OneSignal.Notifications.addClickListener((event) {
        final data = event.notification.additionalData;
        router.handle(data);
        final id = data?['messageId'];
        if (data?['system'] == 'true' && id is String) {
          _pendingOpen = id;
          unawaited(_reportOpen());
        }
      });
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        if (_suppressForeground) event.preventDefault();
      });
      OneSignal.Notifications.addPermissionObserver((granted) {
        unawaited(_report());
        unawaited(_refreshStatus(granted));
      });
      OneSignal.User.pushSubscription.addObserver((_) => unawaited(_report()));
      await _refreshStatus(OneSignal.Notifications.permission);
      await syncIdentity();
    } catch (_) {
      status.value = PushStatus.unavailable;
    }
  }

  /// True while a run is active; foreground banners are then suppressed.
  set suppressForeground(bool value) => _suppressForeground = value;

  Future<void> _refreshStatus([bool? granted]) async {
    if (!configured) return;
    final permission = granted ?? OneSignal.Notifications.permission;
    if (!permission) {
      final prefs = await SharedPreferences.getInstance();
      status.value = prefs.getBool(_askedKey) == true
          ? PushStatus.denied
          : PushStatus.notDetermined;
      return;
    }
    status.value = OneSignal.User.pushSubscription.optedIn == false
        ? PushStatus.optedOut
        : PushStatus.enabled;
  }

  /// True only when the banner should be offered: mobile build with a provider,
  /// permission never decided, and the player has not already been asked.
  /// A denied permission never re-offers the banner.
  Future<bool> shouldOfferPrompt() async {
    if (!configured) return false;
    if (status.value != PushStatus.notDetermined) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_promptedKey) != true;
  }

  /// Recorded on either answer so the banner never returns automatically.
  Future<void> markPrompted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_promptedKey, true);
  }

  Future<bool> requestPermission() async {
    if (!configured) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_askedKey, true);
    try {
      final granted = await OneSignal.Notifications.requestPermission(true);
      await _refreshStatus(granted);
      if (granted) {
        await OneSignal.User.pushSubscription.optIn();
        await _report();
      }
      return granted;
    } catch (_) {
      return false;
    }
  }

  Future<void> setMaster(bool enabled) async {
    final next = {...preferences.value, 'master': enabled};
    preferences.value = next;
    if (!configured) return;
    try {
      if (enabled) {
        await OneSignal.User.pushSubscription.optIn();
      } else {
        await OneSignal.User.pushSubscription.optOut();
      }
    } catch (_) {
      /* Provider state is authoritative; the report below still records it. */
    }
    await _pushPreferences({'master': enabled});
    await _report();
    await _refreshStatus();
  }

  Future<void> _pushPreferences(Map<String, bool> values) async {
    if (!configured) return;
    try {
      final credential = await _credential();
      if (credential == null) return;
      await api.setPreferences(
        values: values,
        token: credential.token,
        deviceId: credential.deviceId,
        deviceSecret: credential.deviceSecret,
      );
    } catch (_) {
      /* Preferences are mirrored locally and retried on the next change. */
    }
  }

  Future<void> setReturnReminders(bool enabled) async {
    final initialAccount = accountId?.call();
    final credential = await _credential();
    if (credential == null || accountId?.call() != initialAccount) return;
    final owner = _ownerKey(credential.deviceId);
    if (owner == null) return;
    _preferenceOwner = owner;
    final store = await SharedPreferences.getInstance();
    await store.setBool('regun.push.pendingReminder.$owner', enabled);
    if (_preferenceOwner == owner) {
      preferences.value = {
        ...preferences.value,
        'returnReminders': enabled,
        'returnRemindersPending': true,
      };
    }
    await _loadPreferences();
  }

  String? _ownerKey(String? deviceId) {
    final account = accountId?.call();
    if (account != null && account.isNotEmpty) return 'account:$account';
    return deviceId == null ? null : 'guest:$deviceId';
  }

  Future<void> _loadPreferences() async {
    if (!configured) return;
    final initialAccount = accountId?.call();
    try {
      final credential = await _credential();
      if (credential == null || accountId?.call() != initialAccount) return;
      final owner = _ownerKey(credential.deviceId);
      if (owner == null) return;
      if (owner != _preferenceOwner) {
        _preferenceOwner = owner;
        preferences.value = {
          ...preferences.value,
          'returnReminders': false,
          'returnRemindersPending': false,
        };
      }
      final store = await SharedPreferences.getInstance();
      final pendingKey = 'regun.push.pendingReminder.$owner';
      final pending = store.getBool(pendingKey);
      final result = pending == null
          ? await api.preferences(
              token: credential.token,
              deviceId: credential.deviceId,
              deviceSecret: credential.deviceSecret,
            )
          : await api.setPreferences(
              values: {'returnReminders': pending},
              token: credential.token,
              deviceId: credential.deviceId,
              deviceSecret: credential.deviceSecret,
            );
      if (pending != null &&
          result['returnReminders'] == pending &&
          store.getBool(pendingKey) == pending) {
        await store.remove(pendingKey);
      }
      if (accountId?.call() != initialAccount || _preferenceOwner != owner) {
        return;
      }
      if (result['master'] is bool) {
        preferences.value = {
          for (final key in const [
            'master',
            'security',
            'leaderboards',
            'events',
            'reengagement',
            'returnReminders',
          ])
            key: result[key] is bool
                ? result[key] as bool
                : (key == 'master' || key == 'security'),
          if (store.getBool(pendingKey) case final bool pending) ...{
            'returnReminders': pending,
            'returnRemindersPending': true,
          },
        };
      }
    } catch (_) {
      /* Owner-scoped pending preference is retried on resume. */
    }
  }

  Future<({String? token, String? deviceId, String? deviceSecret})?>
  _credential() async {
    if (accountId?.call() != null) {
      try {
        final token = await accessToken?.call();
        if (token != null) {
          return (token: token, deviceId: null, deviceSecret: null);
        }
      } catch (_) {
        // Account credentials can be unavailable while offline.
      }
      return null;
    }
    final guest = await guestCredentials?.call();
    final id = guest?['id'];
    final secret = guest?['secret'];
    if (id is String && secret is String) {
      return (token: null, deviceId: id, deviceSecret: secret);
    }
    return null;
  }

  void deferIdentityUntilHome() {
    _identityReady = false;
    router.waitForHome();
  }

  void homeReady() {
    final wasWaiting = !_identityReady;
    _identityReady = true;
    router.flush();
    if (wasWaiting) unawaited(syncIdentity());
  }

  /// Called after every account transition: verify, attach, sign-out, delete.
  Future<void> syncIdentity() {
    if (!_identityReady) return Future.value();
    final account = accountId?.call();
    if (_preferenceOwner?.startsWith('account:') == true &&
        _preferenceOwner != 'account:$account') {
      _preferenceOwner = null;
      preferences.value = {
        ...preferences.value,
        'returnReminders': false,
        'returnRemindersPending': false,
      };
    }
    _identitySync = _identitySync.then((_) async {
      await _syncIdentity();
      await _loadPreferences();
      await _reportOpen();
    });
    return _identitySync;
  }

  Future<void> _syncIdentity() async {
    if (!configured) return;
    try {
      final id = accountId?.call();
      if (id != null && id.isNotEmpty) {
        await OneSignal.login('acct_$id');
      } else {
        final guest = await guestCredentials?.call();
        final guestId = guest?['id'];
        if (guestId is String) {
          await OneSignal.login('guest_$guestId');
        } else {
          await OneSignal.logout();
        }
      }
      await _report();
    } catch (_) {
      /* Identity sync is retried on the next transition or resume. */
    }
  }

  /// The deletion reducer has already removed the account's subscriptions.
  Future<void> forgetAccount() async {
    if (!configured) return;
    try {
      await OneSignal.logout();
    } catch (_) {
      // The next identity sync can still restore the guest alias.
    }
  }

  Future<void> _report() async {
    if (!configured || !_identityReady) return;
    final subscriptionId = OneSignal.User.pushSubscription.id;
    if (subscriptionId == null || subscriptionId.isEmpty) return;
    _subscriptionId = subscriptionId;
    final permission = OneSignal.Notifications.permission;
    final optedIn = OneSignal.User.pushSubscription.optedIn ?? true;
    final initialAccount = accountId?.call();
    try {
      final credential = await _credential();
      if (credential == null || accountId?.call() != initialAccount) return;
      final timezone = await _timezone();
      final fingerprint =
          '${_ownerKey(credential.deviceId)}:$subscriptionId:$permission:$optedIn:$timezone';
      final reportedAt = _reportedAt;
      if (fingerprint == _lastReported &&
          reportedAt != null &&
          DateTime.now().difference(reportedAt) < const Duration(hours: 6)) {
        return;
      }
      final info = await PackageInfo.fromPlatform();
      if (accountId?.call() != initialAccount) return;
      final result = await api.register(
        subscriptionId: subscriptionId,
        platform: defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
        appVersion: '${info.version}+${info.buildNumber}',
        locale: _locale(),
        timezone: timezone,
        permission: permission ? 'granted' : 'denied',
        optedIn: optedIn,
        token: credential.token,
        deviceId: credential.deviceId,
        deviceSecret: credential.deviceSecret,
      );
      if (result['owner'] == _ownerKey(credential.deviceId)) {
        _lastReported = fingerprint;
        _reportedAt = DateTime.now();
      }
    } catch (_) {
      /* Bounded retry happens on the next subscription or resume event. */
    }
  }

  Future<void> _reportOpen() async {
    final messageId = _pendingOpen;
    if (!_identityReady || messageId == null) return;
    final credential = await _credential();
    final subscriptionId = OneSignal.User.pushSubscription.id;
    if (credential == null || subscriptionId == null) return;
    final result = await api.request(
      '/notifications/opened',
      token: credential.token,
      body: {
        'messageId': messageId,
        'subscriptionId': subscriptionId,
        if (credential.deviceId != null) 'deviceId': credential.deviceId,
        if (credential.deviceSecret != null)
          'deviceSecret': credential.deviceSecret,
      },
    );
    if (result['ok'] == true && _pendingOpen == messageId) _pendingOpen = null;
  }

  static String _locale() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    final tag =
        locale.languageCode +
        (locale.countryCode == null ? '' : '-${locale.countryCode}');
    return tag
        .replaceAll(RegExp(r'[^A-Za-z0-9-]'), '')
        .substring(0, tag.length.clamp(0, 16));
  }

  static Future<String> _timezone() async {
    try {
      final name = await _timezoneChannel.invokeMethod<String>('current');
      if (name != null && (name.contains('/') || name == 'UTC')) return name;
    } on PlatformException {
      // The offset is sufficient for a recently registered install.
    } on MissingPluginException {
      // Older host builds can still register with an offset.
    }
    final minutes = DateTime.now().timeZoneOffset.inMinutes;
    return 'UTC${minutes >= 0 ? '+' : '-'}${minutes.abs()}';
  }
}

enum PushStatus {
  /// Platform has no push support in this build.
  unsupported,

  /// Mobile build compiled without a OneSignal app id.
  unconfigured,

  /// Permission has never been requested.
  notDetermined,

  /// The player (or OS) denied permission.
  denied,

  /// Provider is opted out in-app.
  optedOut,

  /// Ready to receive.
  enabled,

  /// SDK or provider failed to initialise.
  unavailable,
}
