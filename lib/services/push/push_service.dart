import 'dart:async';

import 'package:flutter/material.dart';
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
      router = PushRouter(
        navigatorKey ?? pushNavigatorKey,
        pushScreenFor,
      );

  static final shared = PushService();

  /// Assigned from `main.dart` before `shared` is first touched.
  static GlobalKey<NavigatorState>? pushNavigatorKey;
  static Widget Function(String route)? pushScreenFor;

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
  });

  /// Injected by the composition root to avoid a controller import cycle.
  String? Function()? accountId;
  Future<String?> Function()? accessToken;
  Future<Map<String, dynamic>?> Function()? guestCredentials;

  bool _initialized = false;
  bool _suppressForeground = false;
  String? _subscriptionId;
  String? _lastReported;

  static const _askedKey = 'regun.push.asked.v1';

  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  bool get configured => supported && appId.isNotEmpty;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (!configured) {
      status.value = supported ? PushStatus.unconfigured : PushStatus.unsupported;
      return;
    }
    try {
      await OneSignal.initialize(appId);
      OneSignal.Notifications.addClickListener(
        (event) => router.handle(event.notification.additionalData),
      );
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        if (_suppressForeground) event.preventDefault();
      });
      OneSignal.Notifications.addPermissionObserver((granted) {
        unawaited(_report());
        unawaited(_refreshStatus(granted));
      });
      OneSignal.User.pushSubscription.addObserver((_) => unawaited(_report()));
      await _refreshStatus(OneSignal.Notifications.permission);
      await _syncIdentity();
      unawaited(_loadPreferences());
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
    await _pushPreferences(next);
    await _report();
    await _refreshStatus();
  }

  Future<void> setCategory(String category, bool enabled) async {
    if (!const ['security', 'leaderboards', 'events', 'reengagement'].contains(category)) {
      return;
    }
    final next = {...preferences.value, category: enabled};
    preferences.value = next;
    await _pushPreferences(next);
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

  Future<void> _loadPreferences() async {
    if (!configured) return;
    try {
      final credential = await _credential();
      if (credential == null) return;
      final result = await api.preferences(token: credential.token);
      if (result['master'] is bool) {
        preferences.value = {
          for (final key in const ['master', 'security', 'leaderboards', 'events', 'reengagement'])
            key: result[key] is bool
                ? result[key] as bool
                : (key == 'master' || key == 'security'),
        };
      }
    } catch (_) {
      /* Keep the local mirror. */
    }
  }

  Future<({String? token, String? deviceId, String? deviceSecret})?> _credential() async {
    final token = await accessToken?.call();
    if (token != null) return (token: token, deviceId: null, deviceSecret: null);
    final guest = await guestCredentials?.call();
    final id = guest?['id'];
    final secret = guest?['secret'];
    if (id is String && secret is String) {
      return (token: null, deviceId: id, deviceSecret: secret);
    }
    return null;
  }

  /// Called after every account transition: verify, attach, sign-out, delete.
  Future<void> syncIdentity() => _syncIdentity();

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

  /// Called when the account is deleted: drop the subscription and the alias.
  Future<void> forgetAccount() async {
    if (!configured) return;
    try {
      final subscriptionId = _subscriptionId;
      final credential = await _credential();
      if (subscriptionId != null && credential != null) {
        await api.unregister(
          subscriptionId: subscriptionId,
          token: credential.token,
          deviceId: credential.deviceId,
          deviceSecret: credential.deviceSecret,
        );
      }
      await OneSignal.logout();
    } catch (_) {
      /* Local session cleanup already completed on the account side. */
    }
  }

  Future<void> _report() async {
    if (!configured) return;
    final subscriptionId = OneSignal.User.pushSubscription.id;
    if (subscriptionId == null || subscriptionId.isEmpty) return;
    _subscriptionId = subscriptionId;
    final permission = OneSignal.Notifications.permission;
    final optedIn = OneSignal.User.pushSubscription.optedIn ?? true;
    final fingerprint = '$subscriptionId:$permission:$optedIn';
    if (fingerprint == _lastReported) return;
    try {
      final credential = await _credential();
      final info = await PackageInfo.fromPlatform();
      final result = await api.register(
        subscriptionId: subscriptionId,
        platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        appVersion: '${info.version}+${info.buildNumber}',
        locale: _locale(),
        timezone: _timezone(),
        permission: permission ? 'granted' : 'denied',
        optedIn: optedIn,
        token: credential?.token,
        deviceId: credential?.deviceId,
        deviceSecret: credential?.deviceSecret,
      );
      if (result['ok'] != false) _lastReported = fingerprint;
    } catch (_) {
      /* Bounded retry happens on the next subscription or resume event. */
    }
  }

  static String _locale() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    final tag = locale.languageCode +
        (locale.countryCode == null ? '' : '-${locale.countryCode}');
    return tag.replaceAll(RegExp(r'[^A-Za-z0-9-]'), '').substring(0, tag.length.clamp(0, 16));
  }

  static String _timezone() {
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
