# Rook launcher and startup — 20 October 2026

The launcher and startup use Rook's front-facing helmet, cyan visor and ochre scarf. The character atlas `assets/art/characters/rook_run.png` supplied the reference. The image-generation tool created an enlarged head master, a full-bleed icon and a padded transparent mark; these are branded adaptations of the actual sprite, not literal pixel-for-pixel atlas crops.

- `art/source/branding/rook_head_master.png`: source head, kept outside bundled assets.
- `app_icon/launcher.png`: opaque square launcher source; system masking is left to the platform.
- `assets/art/branding/rook_mark.png`: padded transparent mark reused by the Android adaptive foreground, native launch screens and Flutter startup.

## Placement rules and measured checks

[Apple's app-icon guidance](https://developer.apple.com/design/human-interface-guidelines/app-icons) permits flattened icons, recommends recognizable centered primary content and full-bleed opaque backgrounds, and asks developers to leave masking to the system. The existing asset-catalog pipeline generates an opaque RGB **1024×1024** store icon and required smaller sizes. The head remains well away from the system's rounded corners; the icon has no baked-in rounded container or text.

[Android's adaptive-icon guidance](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive) uses separate 108dp foreground/background layers, a central 66dp safe zone and a 48–66dp essential mark. The adaptive foreground uses the padded head plus a **3% inset** applied by `flutter_launcher_icons` 0.14.4. Measuring generated xxxhdpi pixels with alpha >128 gives a maximum critical radius **0.2926×canvas width**, inside the safe radius **0.3056**. The solid background is `#161B18`. Android retains control of circular/squircle masking.

[Android's splash-screen guidance](https://developer.android.com/develop/ui/views/launch/splash-screen) requires an icon without a background to fit a circle of diameter 192dp in its 288dp area. The generated Android 12 mark's critical radius is **0.3114×canvas width**, below the allowed **1/3**. Native splash uses one opaque `#161B18` background; the mark itself has transparency. iOS uses centered launch art.

The20 October Flutter startup initially displayed the same Rook mark and background,
then replaced its route with Menu after local preparation. The creator restored the
original Flame/godKiishi intro on24 October; see the current flow below.

## Generation and acceptance

`dart run flutter_launcher_icons` and `dart run flutter_native_splash:create` regenerate native assets from `pubspec.yaml`. The splash generator also updates web startup; retain the SoLoud loader before Flutter bootstrap. Launcher generator version 0.14.4 adds the required configurable adaptive inset. Generators resize/export the source art; no hand-painted native-size variants are needed.

Verified: source/derived dimensions, opaque iOS store icon, unmasked square source, adaptive foreground XML/background, critical Android alpha bounds and Android 12 bounds. Human Home Screen appearance, OS icon caching, device splash transitions and themed launcher behavior still need hands-on review.


## Restored intro —24 October 2026

The creator explicitly requested the original Flame engine intro followed by the
original `assets/images/splash_image.png` godKiishi artwork, then Menu. Rook remains
the native launch/launcher identity. Flutter uses the original Flame package's logo
layers and pulsing composite; each logo retains its original3.2-second beat
(750ms fade in,2s hold,450ms fade out). Reduced Motion shows still logos without
fades or the pulsing Flame, preserving the same sequence.

Local preferences/account-cache initialization and image precaching complete
before the sequence begins. Account initialization remains local; no network
request is added. Menu still owns passive update checking, music and account
flows. One owned animation controller sequences the two logos instead of the
package's uncancellable delayed callbacks. Backgrounding freezes it and the logo
pulse; resume continues the same sequence. Disposal cancels animation, mounted
checks guard pending preparation and a one-shot route replacement prevents
returning to the intro from Menu.

Startup tests check ordering, completed route replacement, Reduced Motion,
background/resume and disposal alongside existing menu/update regressions.
Rendered evidence: `build/test-previews/startup-flame.png` and
`startup-godkiishi.png`. No native launch asset or release version change is made.
