# Ariet Walker escort coordination — release1.0.0+28

Creator feedback identified same-line attacks and poor teammate awareness. This
pass changes the two Ariet ground escorts only. Ariet's full jet/weapon/hover/
ordnance behavior and release identity1.0.0+28 remain. No roster admission/upload.

## Behavior

The previous independent fixed world offsets are replaced by one shared
ArietEscortTactics plan over a sorted snapshot of living escorts. It allocates
left/right player-relative sectors jointly using travel cost, then retains those
roles rather than swapping every frame. The formation anchor turns at most
.55rad/s, with up to80 units of player-movement lead. The ordinary stand-off is330
with flank offsets+/-1rad, providing separate attack angles and a broad escape side.

Candidate perches must fit body/bounds/cover. Shared scoring favors visible firing
positions and avoids a partner's reserved position or same-angle lane. Bounded
alternatives adapt to cover; a narrow corridor can select a spaced rear hold up
to540 rather than crowd the front Walker. Curved angular waypoints reach a flank
without cutting a straight chord through the player/partner. Existing cover
routing, right-hand traffic, swept body occupancy and mass/speed remain.

Before acquiring a volley and before every delayed shot, the actual muzzle lane
is checked against current live teammates and their projected movement during up
to.45s of bullet flight. A crossed/blocked lane cancels the remaining burst and
allows repositioning. This is no friendly damage rule: it avoids firing through
the partner. Ready shooters alternate; a covered/cooling/frozen/dead/absent partner
cannot hold the preferred ready turn. Dead membership is removed and route-owner
retirement clears all roles.

Pressure stays bounded: one escort volley at a time, three rounds, original shared
2s gate, existing range/cadence/damage and32 owned-round cap. Escorts still fire
only in navigation, never over the gunship's major attacks or quiet recovery.
Both remain67.5%/50HP without profile rewards. No new textures/audio/UI were added.

## Verification

Full `make verify`: **912 passed, 5 intentional skips**; analyzer clean.
Release remains **1.0.0+28**.


Eight portable tests cover same-line splitting, update-order stability, persistent
roles, curved approach, cover/sight/bounds, corridor backoff, current/predicted
friendly lane blocking, alternating eligible turns, dead-member release and reset.

The real native selector/encounter test additionally requires both actual escorts
to earn turns, physically resolves swapped flank goals without overlap, then puts
them into a single file and checks the rear muzzle is blocked. After active AI
movement it requires two actual attack angles greater than1rad apart. The previous
jet/charge/rear damage, actual rocket/jet pixels, all24 player weapon paths, target
gaps, recovery, underpass, disposal/restart and32MiB checks remain.

Exhaust provocation now waits for a real attack boundary rather than assuming its
window falls in a fixed wall-clock interval; its actual native attack is still
required. This makes coordination scheduling testable without weakening coverage.

Physical tactical pressure, flanking readability/fairness, cover behavior, comfort
and sustained performance require creator review. Captures are rendered test
scenes, not physical-device performance evidence.

## Native evidence

Focused native/portable capture run: **9 passed**.
[Combined encounter recording](native.mp4) · [contact sheet](review-strip.png) ·
[actual coordinated flank positions](coordinated-flanks.png).

The still follows controlled single-file setup, real muzzle-lane checks and10s of
actual escort AI repositioning. The video uses the actual game layer; controlled
traffic inspection occurs between the combat and destruction sections, and the
Flutter HUD is separate. No replacement illustration or physical-phone FPS claim.

## Device result

Release bundle built/signed (Xcode29.3s), then installed successfully on the
iPhone (installation sequence8328) and launched through Apple devicectl. Fresh
app query confirms1.0.0/build28. No version increment or distribution upload.
This confirms installation/launch, not creator tactical or physical-performance
acceptance.
