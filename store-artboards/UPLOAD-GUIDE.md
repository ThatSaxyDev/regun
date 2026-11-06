# Regun landscape store artwork

| Folder | Store slot | Pixels | Images |
|---|---|---:|---:|
| 01-App-Store-iPhone-2556x1179 | iPhone with Dynamic Island, medium display | 2556 × 1179 | 6 |
| 02-App-Store-iPad-2752x2064 | iPad 13-inch display | 2752 × 2064 | 6 |
| 03-Play-Phone-1920x1080 | Google Play phone screenshots | 1920 × 1080 | 6 |
| 04-Play-Feature-1024x500 | Google Play feature graphic | 1024 × 500 | 1 |
| 05-App-Store-Header-3840x1646 | App Store Product Page Header | 3840 × 1646 | 1 |
| 06-App-Store-Search-Results-3840x2560 | App Store Search Results | 3840 × 2560 | 1 |
| 07-App-Store-Duo-Outer-2034x1398 | iPhone Duo outer display | 2034 × 1398 | 6 |
| 08-App-Store-Duo-Inner-2853x2007 | iPhone Duo inner display | 2853 × 2007 | 6 |
| 09-Play-Icon-512x512 | Google Play listing icon | 512 × 512 | 1 |
| 10-Play-Tablet-1920x1080 | Google Play tablet screenshots | 1920 × 1080 | 6 |
| 11-App-Store-Mac-2880x1800 | Mac App Store screenshots | 2880 × 1800 | 6 |

Upload the PNGs in numbered order within each screenshot set. Google Play starts with four unobstructed gameplay captures before the upgrade and loadout screens. Upload the feature graphic and listing icon in their separate fields. Use the Play tablet set for the tablet screenshot slots and review the result in Play Console.

For macOS, open the macOS version in App Store Connect and go to **App Previews and Screenshots → Mac**. Upload the six files from folder 11 in numbered order. Apple accepts 1280 × 800, 1440 × 900, 2560 × 1600 or 2880 × 1800 for the Mac slot. This set uses the largest size.

In App Store Connect, open the app version and go to **Product Page Information → Header and Search Results**. Upload each creative PNG under its corresponding tab and use Preview to check the placement. Apple also accepts a shared 5244 × 2950 universal format as an alternative to these dedicated files. Apple lists the creative placements as optional. Use the iPhone Duo folders in the corresponding display slots when applicable.

The screenshots use Flutter's actual Regun widgets, Flame renderer, art, combat and controls. The capture harness runs isolated local fixtures that stage enemies and gear, fund one upgrade choice and start a Lodestar practice encounter. It renders each aspect ratio directly, including Regun's dedicated tablet layout. The Play set uses a Flutter test viewport at 16:9. The mobile and Play layouts were rendered by the Flutter test harness. The Mac set uses the native macOS Runner and its desktop controls and HUD, captured at a 1440 × 900 logical viewport and rasterized at 2×. The feature graphic uses Rook's existing shelter artwork.

Open `index.html` for visual review. The ZIP contains the eleven upload folders, this guide and a validation manifest with source names, dimensions, hashes and suggested alt text. All screenshots and creative assets are opaque RGB PNGs. The square Google Play icon is a 32-bit RGBA PNG exported from the existing Rook launcher artwork. Videos and event-specific artwork are separate deliverables.

Regenerate the mobile and Play sources from the repo root with `flutter test tool/store_capture_test.dart`. To refresh the Mac sources, run `flutter test integration_test/macos_store_capture_test.dart -d macos` from a logged-in Mac desktop. After the test passes, copy the six PNGs from the `REGUN_MACOS_CAPTURES` path printed by the test into `store-artboards/sources/macos/`. With Pillow installed, run `python3 store-artboards/build.py --mac-only` to refresh the Mac boards and repackage the existing exports. Use `python3 store-artboards/build.py` to rebuild every board from source.

If Xcode requires a development certificate for the capture run, use a configured development signing environment or this temporary signing override for the local capture build.

```sh
capture_config=$(mktemp)
printf '%s\n' 'CODE_SIGN_ENTITLEMENTS =' > "$capture_config"
XCODE_XCCONFIG_FILE="$capture_config" flutter test integration_test/macos_store_capture_test.dart -d macos
rm "$capture_config"
```

[Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) · [Google Play preview asset requirements](https://support.google.com/googleplay/android-developer/answer/9866151) · [Apple creative asset specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications/)
