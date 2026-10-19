import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telling_logger/telling_logger.dart' show VersionCheckResult;
// Pinned to 1.5.0: this version-only adapter avoids SDK initialization, which
// starts device/session collection and telemetry timers even without tracking.
// ignore: implementation_imports
import 'package:telling_logger/src/version_check.dart' as telling_version;
import 'package:url_launcher/url_launcher.dart';

export 'package:telling_logger/telling_logger.dart' show VersionCheckResult;

const tellingProjectKey = String.fromEnvironment('TELLING_PROJECT_KEY');
const tellingApiUrl = String.fromEnvironment('TELLING_API_URL',
    defaultValue: 'https://telling-api.kiishi.space/api/v1');
final appUpdatesProvider = Provider<AppUpdates>((ref) => AppUpdates());

/// Telling release configuration only. No crash hooks, player IDs or analytics.
class AppUpdates {
  AppUpdates({
    this.apiKey = tellingProjectKey,
    this.serverUrl = tellingApiUrl,
    TargetPlatform? platform,
    Future<PackageInfo> Function()? version,
    http.Client Function()? client,
    Future<bool> Function(Uri)? open,
    DateTime Function()? now,
  })  : platform = platform ?? defaultTargetPlatform,
        version = version ?? PackageInfo.fromPlatform,
        client = client ?? http.Client.new,
        open = open ??
            ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication)),
        now = now ?? DateTime.now;

  final String apiKey, serverUrl;
  final TargetPlatform platform;
  final Future<PackageInfo> Function() version;
  final http.Client Function() client;
  final Future<bool> Function(Uri) open;
  final DateTime Function() now;
  static const _snoozeKey = 'regun.update.snooze';
  static const _targetKey = 'regun.update.target';
  bool get enabled =>
      apiKey.trim().isNotEmpty &&
      !kIsWeb &&
      [TargetPlatform.iOS, TargetPlatform.android].contains(platform);

  /// Only platform store listings or official iOS TestFlight invitations.
  Uri? storeUri(String? value) {
    final uri = Uri.tryParse(value?.trim() ?? '');
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasFragment) {
      return null;
    }
    if (platform == TargetPlatform.iOS &&
        uri.host == 'apps.apple.com' &&
        RegExp(r'/id[0-9]+/?$').hasMatch(uri.path)) {
      return uri;
    }
    if (platform == TargetPlatform.iOS &&
        uri.host == 'testflight.apple.com' &&
        RegExp(r'^/join/[A-Za-z0-9]{8}/?$').hasMatch(uri.path)) {
      return uri;
    }
    if (platform == TargetPlatform.android &&
        uri.host == 'play.google.com' &&
        uri.path == '/store/apps/details' &&
        uri.queryParameters['id'] == 'dev.kiishi.regun') {
      return uri;
    }
    return null;
  }

  Future<VersionCheckResult> check() async {
    if (!enabled) return VersionCheckResult.noUpdateRequired;
    final base = Uri.tryParse(serverUrl);
    if (base == null ||
        base.scheme != 'https' ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment) {
      throw StateError('Invalid Telling API address');
    }
    final transport = client();
    try {
      return await (() async {
        final installed = await version();
        var received = false;
        final result = await telling_version.fetchVersionCheck(
          serverUrl: serverUrl.replaceFirst(RegExp(r'/+$'), ''),
          platform: platform == TargetPlatform.iOS ? 'ios' : 'android',
          version: installed.version,
          build: installed.buildNumber,
          apiKey: apiKey,
          timeout: const Duration(seconds: 4),
          get: (uri, headers) async {
            final response = await transport.get(uri, headers: headers);
            if (response.statusCode != 200) return null;
            final data =
                Map<String, dynamic>.from(jsonDecode(response.body) as Map);
            // A malformed response must not clear an existing required prompt.
            if (data['requiresUpdate'] is! bool ||
                (data['requiresUpdate'] == true &&
                    data['isRequired'] is! bool)) {
              return null;
            }
            VersionCheckResult.fromJson(data); // Validate types before receipt.
            received = true;
            return data;
          },
        );
        if (!received) throw StateError('Version check unavailable');
        if (!result.requiresUpdate) return result;
        // A release policy and its action URL are independent. A missing
        // listing must never erase an authoritative required-update decision.
        if (result.isRequired) return result;
        final prefs = await SharedPreferences.getInstance();
        if (telling_version.isUpdateSnoozed(
            result: result,
            storedTarget: prefs.getString(_targetKey),
            storedUntil: prefs.getString(_snoozeKey),
            now: now())) {
          return VersionCheckResult.noUpdateRequired;
        }
        return result;
      })()
          .timeout(const Duration(seconds: 5));
    } finally {
      transport.close();
    }
  }

  Future<void> later(VersionCheckResult result) async {
    if (result.isRequired || result.snoozeTarget == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_targetKey, result.snoozeTarget!);
    await prefs.setString(_snoozeKey,
        now().add(const Duration(days: 1)).toUtc().toIso8601String());
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
