# Minion engagement validation — 28 October 2026

Mummy speed95 preserves the base Spore-field kill regression. Arming now begins only at the original36-unit melee reach, with a.3s opening strike and.6s repeats. Initial100-speed proposal was reduced after the area-weapon regression.

Native integration covers real Skitter movement over living minions, swept player damage, solid cover, mid-flight displacement without ground relocation, contact-time mummy arming with a.3s opening strike, no distant/wall hits and retreat reset. Focused minion/weapon set77 pass. Analyzer clean. Server typecheck,209 tests and2.12 module build pass. Backend main commit279fcb2 is deployed; the live image and compiled-module source hashes match the local actors.ts. No schema/environment change.

Release1.0.0+28. Device installation/launch and final full suite recorded alongside these logs. Automated checks/installations do not establish physical readability, fairness or performance.

## Follow-up review

The gameplay implementation was correct. One legacy Skitter regression still asserted ground-body blocking; it now checks crossing a living minion without killing it and completing the leap. Mummy keeps the creator’s contact-only walk/strike revision:95 speed, .3s opening, .6s repeats, original melee reach.

The server passes209 tests, typecheck and2.12 module build; live health returns200. Game analyzer is clean. Updated full-suite and device-build evidence is stored in review logs here. The build-number change to28 is preserved. No environment or database changes were required.

Follow-up result: full Flutter suite858 passed,5 intentionally skipped; release build28 installed and launched on the connected iPhone. Physical feel/performance remains for hands-on review.
