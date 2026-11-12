import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const releaseChannel = String.fromEnvironment(
  'REGUN_RELEASE_CHANNEL',
  defaultValue: 'production',
);
const releaseIdentityOrigin = String.fromEnvironment(
  'REGUN_IDENTITY_URL',
  defaultValue: 'https://regunserver.kiishi.space',
);

const maintenanceMessage =
    'Regun is temporarily unavailable while we make improvements.';

final appUpdatesProvider = Provider<AppUpdates>((ref) => AppUpdates());

class VersionCheckResult {
  const VersionCheckResult({
    required this.requiresUpdate,
    this.isRequired = false,
    this.minVersion,
    this.minBuild,
    this.target,
    this.storeUrl,
    this.message,
    this.maintenance,
  });

  static const noUpdateRequired = VersionCheckResult(requiresUpdate: false);
  final bool requiresUpdate, isRequired;
  final String? minVersion, target, storeUrl, message, maintenance;
  final int? minBuild;
}

/// Reads the platform policy without credentials or player identifiers.
class AppUpdates {
  AppUpdates({
    this.serverUrl = releaseIdentityOrigin,
    this.channel = releaseChannel,
    TargetPlatform? platform,
    bool? web,
    Future<PackageInfo> Function()? version,
    http.Client Function()? client,
    Future<bool> Function(Uri)? open,
    DateTime Function()? now,
  }) : platform = platform ?? defaultTargetPlatform,
       web = web ?? kIsWeb,
       version = version ?? PackageInfo.fromPlatform,
       client = client ?? http.Client.new,
       open =
           open ??
           ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication)),
       now = now ?? DateTime.now;

  final String serverUrl, channel;
  final TargetPlatform platform;
  final bool web;
  final Future<PackageInfo> Function() version;
  final http.Client Function() client;
  final Future<bool> Function(Uri) open;
  final DateTime Function() now;
  bool _announcement = false;
  VoidCallback? _cancelCheck;

  void cancelCheck() => _cancelCheck?.call();

  static const _androidFirebaseAppId =
      '1:225712394437:android:a774f7de7e22d0abd0e0ac';

  String? get _platform => web
      ? 'web'
      : switch (platform) {
          TargetPlatform.iOS => 'ios',
          TargetPlatform.android => 'android',
          TargetPlatform.macOS => 'macos',
          _ => null,
        };
  bool get enabled => _platform != null;
  String get _maintenanceKey => 'regun.maintenance.$_platform.$channel';
  String get _snoozeKey => 'regun.update.$_platform.$channel.snooze';

  Future<String?> cachedMaintenance() async {
    if (!enabled) return null;
    final message = (await SharedPreferences.getInstance()).getString(
      _maintenanceKey,
    );
    return message == null ? null : _maintenanceCopy(message);
  }

  String _maintenanceCopy(String message) => switch (message) {
    '' ||
    '$maintenanceMessage Please check again shortly.' => maintenanceMessage,
    _ => message,
  };

  void reviewAnnouncement() => _announcement = true;

  Uri? storeUri(String? value) {
    final uri = Uri.tryParse(value?.trim() ?? '');
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasFragment) {
      return null;
    }
    if (['ios', 'macos'].contains(_platform) &&
        uri.host == 'apps.apple.com' &&
        RegExp(r'/id[0-9]+/?$').hasMatch(uri.path)) {
      return uri;
    }
    if (_platform == 'macos' &&
        (uri.host == 'regun.kiishi.space' ||
            (uri.host == 'github.com' &&
                RegExp(
                  r'^/ThatSaxyDev/regun/releases/(download|tag|latest)(/|$)',
                  caseSensitive: false,
                ).hasMatch(uri.path)))) {
      return uri;
    }
    if (_platform == 'ios' &&
        uri.host == 'testflight.apple.com' &&
        RegExp(r'^/join/[A-Za-z0-9]{8}/?$').hasMatch(uri.path)) {
      return uri;
    }
    if (_platform == 'android') {
      if (uri.host == 'play.google.com' &&
          uri.path == '/store/apps/details' &&
          uri.queryParametersAll['id']?.singleOrNull == 'dev.kiishi.regun') {
        return uri;
      }
      if (uri.host == 'appdistribution.firebase.dev' &&
          RegExp(r'^/i/[A-Za-z0-9_-]{6,}/?$').hasMatch(uri.path)) {
        return uri;
      }
      if (channel == 'beta' &&
          uri.host == 'appdistribution.firebase.google.com' &&
          RegExp(
            '^/testerapps/${RegExp.escape(_androidFirebaseAppId)}'
            r'/releases/[A-Za-z0-9]+/?$',
          ).hasMatch(uri.path)) {
        return uri;
      }
    }
    return null;
  }

  Future<VersionCheckResult> check() async {
    final platform = _platform;
    if (platform == null) return VersionCheckResult.noUpdateRequired;
    final base = Uri.tryParse(serverUrl);
    if (base == null ||
        (base.scheme != 'https' &&
            !(base.scheme == 'http' &&
                ['localhost', '127.0.0.1'].contains(base.host))) ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment) {
      throw StateError('Invalid Regun update address');
    }
    final announcement = _announcement;
    _announcement = false;
    cancelCheck();
    final transport = client();
    final cancelled = Completer<void>();
    void cancel() {
      if (!cancelled.isCompleted) cancelled.complete();
    }

    _cancelCheck = cancel;
    final deadline = Timer(const Duration(seconds: 5), cancel);
    Timer? metadataDeadline;
    try {
      Future<VersionCheckResult> read() async {
        PackageInfo? installed;
        if (!web) {
          try {
            final missing = Completer<PackageInfo?>();
            metadataDeadline = Timer(
              const Duration(milliseconds: 700),
              () => missing.complete(),
            );
            installed = await Future.any<PackageInfo?>([
              version(),
              missing.future,
              cancelled.future.then((_) => null),
            ]);
            metadataDeadline?.cancel();
          } catch (_) {
            // Availability remains independent of installed version metadata.
          }
        }
        if (cancelled.isCompleted) {
          throw StateError('Game availability check stopped');
        }
        final uri = base
            .resolve('/app/v1/availability')
            .replace(
              queryParameters: {
                'platform': platform,
                'channel': channel,
                if (installed != null) 'version': installed.version,
                if (installed != null) 'build': installed.buildNumber,
              },
            );
        final response = await transport.get(uri);
        if (cancelled.isCompleted ||
            response.statusCode != 200 ||
            response.bodyBytes.length > 16384) {
          throw StateError('Game availability unavailable');
        }
        final data = jsonDecode(response.body);
        if (data is! Map ||
            data['platform'] != platform ||
            data['channel'] != channel ||
            data['revision'] is! int ||
            data['maintenance'] is! Map) {
          throw StateError('Invalid game availability response');
        }
        final maintenance = data['maintenance'] as Map;
        if (maintenance['active'] is! bool ||
            maintenance['message'] is! String) {
          throw StateError('Invalid maintenance response');
        }
        final String? notice = maintenance['active'] == true
            ? (maintenance['message'] as String).trim()
            : null;
        final result = notice != null
            ? VersionCheckResult(
                requiresUpdate: false,
                maintenance: _maintenanceCopy(notice),
              )
            : _readUpdate(data['update']);
        try {
          final prefs = await SharedPreferences.getInstance();
          if (notice != null) {
            await prefs.setString(_maintenanceKey, result.maintenance!);
          } else {
            await prefs.remove(_maintenanceKey);
          }
          final snooze = prefs.getString(_snoozeKey)?.split('|');
          if (!announcement &&
              result.requiresUpdate &&
              !result.isRequired &&
              snooze?.length == 2 &&
              snooze!.first == result.target &&
              (DateTime.tryParse(snooze.last)?.isAfter(now()) ?? false)) {
            return VersionCheckResult.noUpdateRequired;
          }
        } catch (_) {
          // Storage failure cannot discard a valid server policy.
        }
        return result;
      }

      return await Future.any<VersionCheckResult>([
        read(),
        cancelled.future.then(
          (_) => throw StateError('Game availability check stopped'),
        ),
      ]);
    } finally {
      deadline.cancel();
      metadataDeadline?.cancel();
      if (identical(_cancelCheck, cancel)) _cancelCheck = null;
      transport.close();
    }
  }

  VersionCheckResult _readUpdate(Object? raw) {
    if (raw is! Map) throw StateError('Invalid update policy');
    final decision = raw['decision'];
    if (decision == 'current') return VersionCheckResult.noUpdateRequired;
    final target = raw['target'];
    if ((decision != 'optional' && decision != 'required') ||
        target is! Map ||
        target['version'] is! String ||
        target['build'] is! int ||
        raw['link'] is! String ||
        raw['message'] is! String) {
      throw StateError('Invalid update policy');
    }
    return VersionCheckResult(
      requiresUpdate: true,
      isRequired: decision == 'required',
      minVersion: target['version'] as String,
      minBuild: target['build'] as int,
      target: '${target['version']}+${target['build']}',
      storeUrl: raw['link'] as String,
      message: raw['message'] as String,
    );
  }

  Future<void> later(VersionCheckResult result) async {
    if (result.isRequired || result.target == null) return;
    final prefs = await SharedPreferences.getInstance();
    final until = now().add(const Duration(days: 1)).toUtc();
    await prefs.setString(
      _snoozeKey,
      '${result.target}|${until.toIso8601String()}',
    );
  }

  Future<bool> openStore(VersionCheckResult result) async {
    final uri = storeUri(result.storeUrl);
    if (uri == null) return false;
    try {
      return await open(uri);
    } catch (_) {
      return false;
    }
  }
}
