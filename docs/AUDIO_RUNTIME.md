# Audio runtime and SDK migration

Regun uses Flutter 3.47.7 / Dart 3.13.5 and pins `flutter_soloud` 5.2.1. The previous runtime resolved 3.5.4 from a `^3.4.4` constraint. SoLoud 5.x builds its native engine through Dart hooks; its `native_toolchain_c` dependency requires meta 1.19, which conflicts with Flutter 3.44.8's exact meta pin. The SDK was upgraded rather than overriding SDK package constraints. Wrapper plugins still use CocoaPods on iOS.

## Session and device ownership

SoLoud's native CoreAudio context explicitly disables AVAudioSession category management and activation. A successful `init`, valid sound handles and valid WAV files alone therefore cannot prove audible output.

`ios/Runner/AppDelegate.swift` owns the session: configure `.playback` / `.default` with `.mixWithOthers`, activate at launch before the Dart audio engine starts, and restore on foreground, media-service reset and resumable interruptions. Avoid activating a background app. In-game volume settings continue to control music and effects; no background-audio mode or microphone permission is added. The playback category uses media volume rather than the iPhone's silent switch and permits other apps' music to mix.

`lib/main.dart` explicitly awaits device startup, listens for automatic startup failures and makes one explicit recovery attempt. Foregrounding also requests an idempotent device start, preserving loaded sources and voice state. Failures are logged. Recovery does not unpause a paused match or its music. The library's own iOS suspension/resume fix is retained.

SoLoud 5.x `play()` returns a synchronous `SoundHandle`; callers no longer await that extension type. `loadAsset` remains asynchronous. `web/index.html` loads `init_soloud.js` before Flutter; the library can select its supported single-threaded fallback without COOP/COEP headers.

## Verification

- `make verify`: analyzer and game tests, including scoped run state, settings, saves, audio event triggers and combat regressions.
- `flutter drive --profile --driver=test_driver/integration_test.dart --target=integration_test/audio_playback_test.dart -d <device>`: actual native SoLoud decoding/mixer callbacks and nonzero output for menu music and all four weapons; zero SFX output with mute enabled. Runs through the production `SoloudPlay` manager. A phone test can also export `Documents/regun-audio-smoke.json` when VM-service discovery is unavailable. It temporarily installs a test entry point; reinstall the regular release afterwards. It does not alter player preferences/profile.
- `RunnerTests` native XCTest cases: check the real AVAudioSession category after launch and after a foreground notification. Both passed on the paired iPhone.
- Build/archive the regular `lib/main.dart` release, verify embedded SoLoud native assets, then install. Keep release identity 1.0.0+7.

Internal mixer capture establishes that audio is rendered, not that the phone speaker is audible. Physical checks still cover speaker/headphone routing, media volume, silent switch, app music/SFX mute, Home/lock/unlock, phone/Siri interruptions and listening quality. Do not present a mixer test or successful installation as full physical audio acceptance.

## Primary references

- [SoLoud 5.2.1 changelog](https://pub.dev/packages/flutter_soloud/versions/5.2.1/changelog), including iOS resume fix in 5.1.5 and native build hooks in 5.x.
- `flutter_soloud` 5.2.1 bundled `skills/flutter-soloud-setup/SKILL.md` and `references/audio_context.md`.
- Package `src/soloud/src/backend/miniaudio/soloud_miniaudio.cpp`: `init_platform_context` leaves AVAudioSession to the application.
- Package `lib/src/soloud.dart`: `audioDeviceStartFailures`, `startAudioDevice` and synchronous `play` contracts.

On-device evidence: `docs/validation/soloud521-iphone-mixer-2026-10-20.json` records nonzero menu/weapon RMS and exactly zero muted output. Native logs report playback category and media volume .70. The laptop SDK is Flutter 3.47.7 / Dart 3.13.5; Flutter and Xcode pass `doctor`. Android license acceptance remains pending. Local pre-upgrade SDK edits were preserved in its Git stash `regun-preserve-sdk-before-3.47-upgrade`; unused Android engine prefetch was interrupted after the core upgrade to prioritize the phone build. Platform artifacts download on demand.
