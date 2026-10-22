FLUTTER ?= flutter
DART ?= dart
RELEASE_CONFIG ?= $(if $(wildcard config/release.local.json),config/release.local.json,config/telling.local.json)
RELEASE_DEFINES = $(if $(wildcard $(RELEASE_CONFIG)),--dart-define-from-file=$(RELEASE_CONFIG),)
DEVICE ?=

FIREBASE_APP_ID ?= 1:225712394437:android:a774f7de7e22d0abd0e0ac
DIST_TESTERS ?=
DIST_GROUPS ?=
DIST_NOTES ?= Regun $(shell sed -n 's/^version: //p' pubspec.yaml)
APK_PATH ?= build/app/outputs/flutter-apk/app-release.apk

.PHONY: analyze test soak verify runRelease build buildAPK buildIOS buildIPA cleanAndGet pubGet createLauncherIcons createSplashScreen distribute

analyze:
	$(FLUTTER) analyze

test:
	$(FLUTTER) test

soak:
	$(FLUTTER) test --dart-define=REGUN_SOAK=true test/soak_test.dart

verify: analyze test

runRelease:
	$(FLUTTER) run --release $(RELEASE_DEFINES) $(if $(DEVICE),-d $(DEVICE),)

# Local Android test candidates use debug signing until upload keys are supplied.
build:
	$(FLUTTER) build appbundle --release $(RELEASE_DEFINES)

buildAPK:
	$(FLUTTER) build apk --release $(RELEASE_DEFINES)

buildIOS:
	$(FLUTTER) build ios --release $(RELEASE_DEFINES)

buildIPA:
	$(FLUTTER) build ipa --release --export-method app-store $(RELEASE_DEFINES)

cleanAndGet:
	$(FLUTTER) clean
	$(FLUTTER) pub get

pubGet:
	$(FLUTTER) pub get

createLauncherIcons:
	$(DART) run flutter_launcher_icons

createSplashScreen:
	$(DART) run flutter_native_splash:create

# Uploads the local Android release APK to Firebase App Distribution (App Tester).
distribute: buildAPK
	firebase appdistribution:distribute $(APK_PATH) --app $(FIREBASE_APP_ID) \
		$(if $(DIST_TESTERS),--testers "$(DIST_TESTERS)") \
		$(if $(DIST_GROUPS),--groups "$(DIST_GROUPS)") \
		--release-notes "$(DIST_NOTES)"
