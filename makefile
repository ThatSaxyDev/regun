FLUTTER ?= flutter
DART ?= dart
RELEASE_CONFIG ?= config/telling.local.json
RELEASE_DEFINES = $(if $(wildcard $(RELEASE_CONFIG)),--dart-define-from-file=$(RELEASE_CONFIG),)
DEVICE ?=

.PHONY: analyze test soak verify runRelease build buildAPK buildIOS buildIPA cleanAndGet pubGet createLauncherIcons createSplashScreen

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
