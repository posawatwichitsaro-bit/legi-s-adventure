# Animated combat update (v4)

## Playing the new combat

Every actor now has original articulated 2px-grid pixel poses: owl wing/feet,
weapons, the six regular enemy types, and four separately designed guardians.
The gait advances only while an actor actually moves; idle is stationary.
Facing and locked attack headings drive the weapon poses. The original static
PNGs remain in assets for reference and menu use.

Touching an enemy no longer deals passive damage. Enemies enter windup,
active, recovery, then cooldown. Orange ground cues show the committed attack
area/direction; pale cues are active. Move outside them or dash before impact.
Each melee attack can connect once, even if the player stays overlapping.
Dash immunity and the existing 0.65-second hurt immunity remain intact.
Arrows remain dangerous after release; their visible projectiles must hit.
Ghosts lunge, bombers visibly prime a blast, and herbalists swing a flask before
returning to their potion-carrier role. Dead enemies cannot finish pending attacks.

The owl's sword has 0.12s windup, 0.12s active and 0.12s recovery. Damage is
applied only during the active phase, once per target. Bow draw takes 0.20s and
magic charge 0.28s before release. Independent unlockable attacks retain their
cooldowns; auxiliary bow/casting effects keep overlapping attacks visible.

## Four guardians

| Stage | Guardian | Patterns and warnings |
|---|---|---|
| 5 | Thorn Warden | Alternating 108px cleave and straight charge; 0.90s warning |
| 10 | Ember Alchemist | 70px ground blast locked to the player's old position; 1.00s warning |
| 15 | Crystal Sentinel | Seven-shot fan then twelve-shot ring; 0.85s warning |
| 20 | Night Sovereign | Cleave, charge, ground blast; below half HP adds fan and changes warning from 0.72s to 0.60s |

Bosses have individual silhouettes, health/name bars, and a phase-II label for
the Sovereign. No extra stages or stat-cap changes were introduced.

## Preserved systems

All 20 arenas, themes, menus, saves, starting paths, level/skill/relic growth,
stat caps, upgrade ranks, unique 10% actual-damage Life Drain, 2/4/6% potions,
75px base pickup, and once-per-clear 10% healing are preserved. Potion/healing,
leveling and stat-limit functions were compared with the v3 archive.

## Automated checks

- combat_tests.gd: 85 assertions
- regression_tests.gd: 23 assertions, including 2,000 seeded arena layouts
- healing_tests.gd: 74 assertions
- balance_tests.gd: 125 assertions
- main integration self-test

Total 307 assertions plus the integration self-test pass. Two previous tests
that assumed an instantaneous slash were updated to step through windup and
active frames. New cases cover every enemy and guardian, no overlap damage,
move-out dodges, one-hit windows, iframes/dash, bow/magic/projectile timing,
active-window expiration, dead/paused/removed/stale-stage attacks, and lethal
projectile ordering. A frame-stall check verifies bounded 120 Hz substeps.

Run from the project folder with Godot 4.6.x:

```
godot --headless --path . --script combat_tests.gd
godot --headless --path . --script regression_tests.gd
godot --headless --path . --script healing_tests.gd
godot --headless --path . --script balance_tests.gd
godot --headless --path . -- --self-test
```

See V4_BALANCE_NOTES.md and balance_results_v4.json for matched v3/v4
controller-driven campaigns and guardian encounters, including deaths and
120s timeouts. These are automated results, not human full-campaign playtests.

## Visual verification and reproducibility

The actual cloud Godot window was inspected for all regular idle/walk/windup/
release poses and the four guardians' attack cues. A live seeded Alchemist
dodge moved out of its locked ground marker before impact with full HP.
The optional visual_qa.tscn is a clearly labelled, save-disabled inspection
scene; it is not the default scene. Keys 1–4 select guardian stages, G selects
regular actors, T/Y/U/I/W select windup/active/recover/idle/walk, B advances the
boss pattern, P tests the Sovereign's half-health phase, F toggles live updates.
O/C inspect bow/cast windup and R simultaneous release. This fixture is not
normal progression and screenshots containing SEEDED QA should be read as such.

Cloud audio playback was not audited: this desktop has no audio device and
Godot falls back to its dummy driver. Headless checks emitted no script errors.

The shipping project opens its normal menu with main.tscn; no fixture, modified
save, invulnerability or auto-controller is enabled by default.
