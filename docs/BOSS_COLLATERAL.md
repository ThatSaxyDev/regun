# Boss attack collateral

24 October2026. Implemented in native mobile and hosted authoritative combat;
source only, pending deployment and physical difficulty/readability review.

Ordinary boss walking, pursuit, approach, arrival and recovery do not kill minions.
Warnings do not damage them. Only an actual committed attack clears enemies:

- Shadow dash and Demon charge clear ordinary/elite minions where the moving
  boss body sweeps, in bounded wall-constrained substeps. Other bosses remain
  solid and cannot be killed by this path.
- Active sweeps, waves, traces and other committed boss damage shapes reuse the
  authoritative collision geometry, including body margins and inner safe pockets.
- Demon cleaves, Shadow strikes and boss-owned ground impacts/poison clear minions
  only during impact/active time. Ordinary enemy hazards and arena vents retain
  their previous behavior. Ranged projectile behavior is unchanged by this pass.

Solid cover blocks collateral. Pausing freezes attacks; defeated owners cancel
pending strikes. The native occupancy hook is opt-in at the two committed lunge
call sites; normal movement retains existing crowd blocking and steering.
Pending native spawn warnings actually crossed by a lunge are cancelled so an
invisible reservation cannot block it. Existing spawn/population budgets remain.

Collateral deaths reuse normal remains/death animation and remove live occupancy
immediately. They do not award player kills, XP, score, Scrap, healing rolls or
kill-triggered burn/shrapnel/fusion effects. Repeated overlap cannot pay rewards.
The server marks collateral casualties as already handled for its reward loop;
no new account, admin, wire or ENV contract is required.

Regression coverage includes normal movement versus committed movement, corridor
bystanders, other bosses, solid cover, active sweep progression, inner pockets,
warning/pause/owner-death safety, actual ground impacts and no reward inflation.
Physical review: crowd a boss in normal play, watch its warning, then verify the
attack clears its path without visual teleporting, killing unrelated enemies or
changing the player's existing damage/protection rules. Test Foundry cover and
Breach drops, plus Training individual bosses with Hordes enabled.

Local verification: mobile analyzer clean;655 tests passed with five intentional
long-test skips. A targeted rerun also checks the actual XP pickup counter after
collateral. Authoritative module148 tests/typecheck/build passed. These checks do
not replace device playtesting of crowd readability or boss difficulty.
