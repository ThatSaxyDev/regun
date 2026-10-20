# Creator review before public distribution

The functional roster and active gameplay art replacement are implemented. See `art/ART_OVERHAUL_PROGRESS.md` for the current art candidate. These are the remaining decisions/evidence to review with the creator, rather than missing gameplay systems.

| Material | Current source / treatment | Final review |
|---|---|---|
| Retired player/enemy/dungeon images | Inherited files preserved on disk, excluded from the Flutter package | Historical provenance remains unknown; these are no longer used by the active game. |
| Heart, icons and splash | Inherited assets still distributed | Confirm source, license, attribution and commercial redistribution rights. |
| New survivor/enemy/boss/weapon/item/arena PNGs | AI-assisted generation using built-in imagegen, unmodified sources in `assets/art` | Prompt record and SHA-256 inventory available; creator should review visual quality and distribution suitability. No commissioned pack or legal guarantee is implied. |
| Existing shotgun reload Lottie and sounds | Inherited assets; normal timing and five-shell cue schedule retained | Confirm rights; judge mix on speakers/headphones. |
| UI glyphs, warnings, weapon motion and cosmetic accessories | Dart/Canvas presentation plus the new raster art | Preserves readable gameplay cues. Additional hand cleanup and bespoke cosmetic outfits remain improvements. |
| Added music and weapon/UI cues | Original deterministic synthesis, `tool/generate_audio.py`; generated WAVs in `assets/audio` | Listen on hardware. Replace or improve loops/timbres if desired; no purchased third-party pack is implied. |
| Press Start 2P / Orbitron | Existing bundled font files | Retain the corresponding license notices with distribution; verify original font packages/provenance. |
| Flutter packages/native engine | Resolved dependencies recorded in `pubspec.lock` | Include required dependency notices in the final distribution materials. |

Do not represent inherited art/audio as rights-cleared until source licenses are supplied. Current collection credits identify the project technology and original work; add named asset creators once provenance is confirmed.

The per-file source/review ledger and SHA-256 hashes are in `ASSET_MANIFEST.csv`.

## Acceptance requiring real devices

Hands-on control comfort, boss/build balance, iOS and Android frame-time/memory/thermal traces, clean-install/update and interruption tests remain open. Follow `PLAYTEST_GUIDE.md`. A signed build and a headless soak do not establish these results.

## Distribution items outside the current implementation-to-validation handoff

- Private Android upload keystore and credentials; the local release APK is debug-signed for testing.
- App Store distribution/export configuration and developer account access, if distribution is requested.
- Final app name/icon approval, screenshots from approved builds, privacy/support contact and store listing/rating answers.
- Any replacement premium art/audio and their licenses.

No online account, ads, analytics or purchases are needed by the game. Unused Supabase and Flame Audio dependencies were removed; SoLoud supplies game audio. Store disclosures still need checking against the exact distributed binary.


Five additional boss atlases (40 poses each) are recorded in `art/source/BOSS_GENERATION_PROMPTS.md`; their source PNGs are copied unchanged. Fifteen boss warn/impact/break cues are original deterministic synthesis from `tool/generate_boss_audio.py`. The SHA-256 inventory includes all twenty files. Expansion atlases load only during their encounters and are released after death/exit, retaining the existing 32 MiB decoded texture ceiling for a pair. Visual and listening approval remain device review items.


The combat presentation correction adds one unchanged generated transparent 24-frame atlas at `assets/art/effects/combat_materials.png`, with its built-in imagegen prompt in `art/source/COMBAT_VFX_PROMPT.md`. Arc Caster's original synthesized shot variants and impact were revised with `tool/generate_weapon_audio.py --only arcCaster`; the audio manifest and file hashes are current. Decoded eager art is about 29.80 MiB; the paired expansion-boss lifecycle test retains the 32 MiB ceiling. Frame crops, source alpha and rendered combat were inspected. Device visual/listening approval remains open.
