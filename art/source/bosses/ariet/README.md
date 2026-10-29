# Ariet identity study

Created 28 October 2026 with the built-in image-generation tool.
Selected concept: `identity-v01.png`. Original output retained under Codex generated images.

The concept establishes the twin-pod low-hover silhouette, central hull, structural
pylons, mechanical bearings, modular front/side equipment and Regun material palette.
It is a first identity proposal for creator review. Isolated parts, weapon mechanisms,
socket alignment, real player scale and directional views still require production
validation. The illustrated ruler does not establish authoritative dimensions.
The static concept does not depict a running encounter or certify implemented flight.

The first generation attempt was rejected by the image tool. The selected result
uses the following static mechanical-design prompt. No Walker artwork was modified.

## Selected generation prompt

```text
Create a polished landscape pixel-art industrial vehicle design reference board for a fictional game vehicle named "ARIET / 02". Static mechanical product illustration only: parked/low-hover craft, no action scene, no firing, no battle or harm, no people.

The LEFT two thirds show a large beautiful three-quarter overhead view of ONE low-hover utility-style armored mechanical craft over cracked dark concrete, with soft shadow directly beneath. TWO thick articulated side engine pods connect to a compact wedge-shaped central hull through short solid pylons, circular bearings and visible hydraulic linkages. There are short stabilizer fins, twin small cylindrical nose-mounted mechanical modules, one independently swiveling cylindrical side module on a visible mounting bearing, tiny red instrument lenses, cooling shutters and modest warm nozzle glow. Every part has a plausible connected structural attachment. Distinct, wide compact silhouette, no legs, no main helicopter rotor, no long aircraft wings.

RIGHT third is a quiet charcoal workshop panel showing: a true overhead orthographic top view of the SAME craft; an orderly exploded assembly of its central hull, two engine pods, short connecting pylons and bearings, twin front module, single swiveling side module; and two small side-view silhouettes showing level hover and modest controlled bank. Consistent components, scale and proportions in every view. A simple ruler scale may sit beside the top view.

Hand-crafted premium pixel-art mechanical game style: crisp deliberate pixel-edge silhouettes, sophisticated restrained pixel material shading, worn olive armor, dark iron, brass joint hardware, scraped edges and subtle oily recesses. Weighty believable industrial machinery and clear part boundaries. Neutral overhead light, readable even at mobile-game scale. No glossy plastic or slick photoreal 3D, no anime character, no decorative neon, no magic. Hover pods have clear intakes and rear/downward nozzles. Calm presentation with clean spacing, everything fully in frame. Big hero silhouette with much less clutter than a technical schematic.

Only text: title "ARIET / 02", right-panel captions "TOP VIEW", "MODULAR ASSEMBLY", "HOVER / BANK". Restrained bone-colored pixel lettering. No paragraphs, HUD, stats, watermark or logos. This is a first mechanical identity study, not an implemented game asset.
```

## Assembly / flight study — 28 October 2026

`parts-v01.png` is a NEW generated modular sheet, not crops of the identity board.
Built-in image generation produced the sheet, then two targeted corrections
removed attached hull hardware and corrected pod/cradle proportions. Exact
prompts are retained in `parts-v01-prompts.json`; discarded intermediate outputs
remain under Codex generated images. No CLI/API fallback was used.

The source is copied byte-for-byte to `assets/art/workshop/ariet_parts_v01.png`.
Its JSON manifest records measured source rectangles, normalized attachment pivots,
world dimensions, sockets, decoded width and source SHA256. Source is1536×1024;
runtime decode1024 retains roughly336 hull source pixels for a156-logical-pixel
wide hull in an844px landscape viewport. Physical device pixel coverage still
needs inspection at native DPR. Original RGBA/alpha is preserved. Neutral overhead
lighting supports rotation; physical all-heading art acceptance remains open.

The current carrier study keeps the pods300 units across (304 including the new
84-unit pod art). The fore/aft cradle is320×180, with an approximately306×136 inner
bay; hull276×106 and mounted hardware extend the longitudinal silhouette. The
cannon sits on a forward starboard sponson ahead of the pod, rather than shooting
through it. These are assembly dimensions, not approved damage/hit geometry.

Two67.5% Walkers occupy fore/aft rails. Scale comparisons show65/67.5/70% alongside
the full-sized original chassis/long-leg rig and Rook. All limb/foot/height/body/
muzzle queries use the same scale as the art; the full Walker's158-unit barrel
is retained. This is a shared-rig study with one stowed gun, not a complete current
Walker's heavy arsenal or an admitted escort combat implementation.

The proposed cargo pose uses a.28 reach tuck, upward-held feet at72 with the body
at48, and downward knee bends. Original110/130 link lengths remain. This requires
more vertical clearance than the empty34-unit hover: the cutaway demonstrates
128-unit loaded hover and a side section. This is a candidate stow pose, NOT an
accepted folding/unfolding animation or proof of swept limb/hardware clearance.
No payloads release, no attack/HP system exists, and50HP is a proposal label only.

Review evidence and reproduction: `docs/validation/ariet-flight-rig-2026-10-28/README.md`.

## Roof deck v02 — 28 October 2026

Phone feedback rejected the fixed nose/broadside weapon layout. See
[redesign specification](../../../../docs/ARIET_GUNSHIP_REDESIGN.md).

- `roof-layout-v02.svg`: editable, code-native mount schematic; layout authority
  for this proposal. `roof-layout-v02.png` is its rendered preview.
- `identity-v02-draft.png`: built-in imagegen styling draft using the original
  identity as reference. It incorrectly retains fixed nose barrels and obscures
  the second rotary; do not use it as exact assembly or production art.
- `identity-v02-prompt.txt`: saved generation prompt.
- `identity-v02-refinement-prompt.txt`: saved attempted correction. The built-in
  image tool rejected that output; no refined image was selected and no CLI
  fallback was used.

The diagram specifies five stations/four families and opposite rotary facings.
Clearance and dimensions remain a study, not validated mechanical sweeps. Existing
`parts-v01` runtime art is unchanged. New design is not implemented in build +29.

## Runtime roof deck v02 — build +30

The full redesign is now implemented using the existing modular atlas: widened
hull/pods, textured gun receivers/barrels on code-native pixel iron/brass bearing
races/supports, twin-barrel flak, six recessed launcher cells and leased Walker
rocket sprites. Metadata now records actual sockets/heights/sizes. The draft
illustration is still not the layout or production sprite source. No new bitmap
atlas was required; both escorts continue sharing one Walker lease. See the
[delivered runtime contract](../../../../docs/ARIET_GUNSHIP_REDESIGN.md).

## Visible airborne carrier and exhaust — build +31

`exhaust-v01.png` was generated with the built-in imagegen tool as a transparent
sheet containing two +X ignition-to-tail jet plumes and two grey smoke puffs.
Prompt: `exhaust-v01-prompt.txt`; hash, measured source rectangles and runtime
copy/decode details: `exhaust-v01.json`. The unchanged source is copied into
`assets/art/workshop/ariet_exhaust_v01.png`; no Python bitmap edits or CLI image
fallback were used. Runtime owns one small512px decode with both pod emitters.

The full battle assembly now uses its true hover projection (160-unit height),
consistent air-plane targets/muzzles and overhead ordering; shadow and ground
traffic stay on the floor. Native pixel-centroid and underpass/head-on regressions
verify this correction. The old empty-hover34 and cancelled battle height are
historical. See the airborne validation notes for creator review.

## Flow and seeker lease correction — release1.0.0+28

The existing transparent jet sheet now renders continuous advected hot tongues
on a fixed painted nozzle axis. No new bitmap was needed for the motion change.
Ariet now also leases the existing Walker arsenal sheet at512px so its actual
rocket silhouette renders; the former parts-only lease left only a red glow.
Metal body/fins/nose draw at64 units, with small jet and harmless timed burnout.
Original full Walker defaults/source art are unchanged. Actual opaque sprite and
stationary-hull flame pixel-diff checks guard both prior visual failures.
