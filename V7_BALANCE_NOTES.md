# v7 class identity: verification and balance notes

## Scope and rules

This release differentiates the four classes while retaining the 20-stage campaign, four guardians, expanded maps, environmental telegraphs, grouped spawning, tier-specific active-enemy caps, and 25%-larger rounded rosters. The campaign still has 736 enemies. Existing XP, potion and once-per-stage clearing-heal paths remain intact.

- Blade Dancer: narrow forward slash; choose one exclusive style. Thrust trades a narrower cone and slower start-to-start cooldown for 1.3× damage/reach. Cleave covers the forward half-plane at 0.8× damage. Sweep covers 360° at 0.55× damage and 0.9× reach. Selecting one removes the other two.
- Star Ranger: 175 starting movement speed and 1.15 attack speed; Quickdraw, Star Fan and passive environmental-trap evasion. One baseline trap charge, at most three; serial recharge takes 12/11/10 seconds. These charges do not block enemy attacks or create general invulnerability. Added capacity starts empty.
- Moon Weaver: 70 starting HP plus a separate 35-point shield. Accepted hits restart a four-second recharge delay. Regeneration is 7 shield/s; two Ward ranks raise capacity to 55 and rate to 9/s. Split staff volleys have 3/5 homing bolts sharing 135%/165% of one bolt's damage, with a readable 0.12-second straight launch before homing. Independent radial bursts, short-lived nonstacking ground fire, and one following familiar are available.
- Comet Strider: fast dagger and damaging dash, up to two serially recharging charges, 0.18–0.26-second duration, at most three finite poison stacks, and collision-checked push against idle/recovering enemies. Push cannot move committed enemy attack warnings.

Class resources are separate from the multiplicatively growing stat dictionary. Level growth and relics cannot multiply shield capacity, charge capacity, trap immunity or dash duration. Class-specific attack-speed/secondary-weapon bounds prevent hybrids inheriting a specialist's full ceiling.

### Concrete rebalance decisions

- Class-only branches reject wrong-class application and persistent starting selections, not merely hide them in the menu.
- Pure-behavior upgrades remain selectable without artificial stat deltas. Fully ineffective capped-stat offers disappear. Every eligible level-up offer includes a class branch when one remains, alongside two other shuffled choices; exhausted progression has a nonblocking mastery-rest option.
- Class caps: attack speed 2.2 Blade / 2.4 Ranger / 2.0 Moon / 2.0 Comet; arrows four for Ranger and two as support; magic three for Moon and two as support; Moon's maximum HP ceiling is 280 instead of 400.
- Auxiliary magic was reduced from eight sparks at 90–110% attack damage each, with attack-speed-scaled cadence, to eight 15–20% support sparks on a fixed 2.3-second cadence. This avoids an incidental hybrid upgrade overtaking the dedicated Moonburst role. Primary weapons remain exclusive unless an explicit support upgrade is chosen.
- Fire overlap uses one per-enemy 0.35-second tick gate, not one gate per patch. Patches expire after 1.4 seconds and are capped at 32. Dashing does not paint extra ground fire.
- Poison refresh cannot postpone its cadence or exceed three stacks. Six half-second ticks exhaust a three-second application. Life Drain uses actual HP removed, including the remaining-HP limit on overkill. Dead/expired targets cannot produce endless healing.
- Class projectiles are capped at 96, one familiar is allowed, and dash ghosts are capped at 18. All class gameplay clocks freeze outside live play. Stage/new-run transitions replenish class resources; run end clears damaging effects.

## Measurement method

The final experiment uses `balance_simulation_v7.gd`, which extends the existing v6 navigation/controller harness and reads actual combat through `balance_probe.gd`. It does not replace enemy HP, damage, collision, shield, healing, projectiles or kill logic. Combat is stepped at 120 Hz; eight-direction physical-key choices are updated at 12 Hz. The controller uses visible attack geometry, approximate AStar routing, ordinary collision movement and available dash charges.

Three distinct experiment types must not be conflated:

1. **Healthy-entry branch comparisons:** all 19 named policies, seeds 1760/2026/4511, stages 5/10/15/20, for 228 independent encounters. Earlier stages supply their exact full-roster XP and actual randomized upgrade/relic offers. The selected branch begins with its legal rank-one unlocked starting ability; baseline policies start without one. HP and stage-entry class resources are normally full when the measured encounter begins. This setup does not establish survival through earlier stages.
2. **Adversarial compatible-upgrade stress:** Blade thrust/cleave/sweep, Ranger fan, Moon spread and Comet echo policies, the same three seeds, stage 20, for 18 encounters. Every compatible upgrade is requested beyond its cap; rejected or ineffective ranks remain rejected. HP is filled for encounter entry; class resources keep their stage-entry state, and any capacity added by subsequent stress upgrades starts empty under normal rules. These intentionally generous loadouts need not be attainable in one campaign.
3. **Natural campaigns:** seeds 1760/2026 with Blade thrust, Ranger fan, Moon spread and Comet echo. XP, HP carryover, drops, upgrades and real stage-entry resource resets are used throughout. No health, damage or kill injection occurs during a campaign. Center-portal travel is skipped only after enemies and rewards are resolved.

The stage observation limit is 240 seconds. Deaths and living timeouts are retained. Clear-time medians exclude non-clears. HP-damage totals count accepted health loss after armor, immunity and mana-shield absorption; they do **not** count shield absorption or raw incoming damage. End shield and end HP are separately recorded. HP may rise above the entry value through real leveling/healing.

Each policy uses the identical seed and target arena seed, so initial map geometry, roster and stage match. Class growth, eligible random-offer pools, chosen rewards and later RNG consumption can differ. A policy prioritizes its named branch and then sustain/damage; other compatible branches can be legal fallback picks. These are representative playable builds, not isolated causal tests of one perk.

## Final experiment results

### Healthy-entry encounters

**228/228 clears; 0 deaths; 0 living timeouts. 9,804 actual kills.** Every policy has 12 encounters (three seeds at each of four guardian stages).

| Policy | Clears | Median seconds: stage 5 / 10 / 15 / 20 | Median HP loss across 12 | Median end HP |
|---|---:|---:|---:|---:|
| Blade baseline | 12/12 | 40.5 / 49.0 / 60.0 / 62.5 | 34.9 | 220.0 |
| Blade thrust | 12/12 | 49.6 / 53.3 / 50.0 / 55.0 | 43.2 | 247.0 |
| Blade cleave | 12/12 | 45.7 / 58.8 / 52.5 / 55.3 | 54.6 | 233.2 |
| Blade sweep | 12/12 | 63.4 / 77.6 / 71.3 / 77.6 | 150.1 | 225.1 |
| Ranger baseline | 12/12 | 67.2 / 99.1 / 60.4 / 69.7 | 70.5 | 206.5 |
| Ranger Quickdraw | 12/12 | 72.6 / 100.4 / 68.7 / 59.4 | 103.9 | 190.9 |
| Ranger Star Fan | 12/12 | 48.0 / 48.8 / 47.2 / 59.4 | 32.6 | 188.8 |
| Ranger Trail Instinct | 12/12 | 67.8 / 61.2 / 46.1 / 59.4 | 48.7 | 207.1 |
| Moon baseline | 12/12 | 64.0 / 63.3 / 75.0 / 94.7 | 0.0 | 124.4 |
| Moon Lunar Fan | 12/12 | 48.5 / 48.1 / 46.4 / 62.8 | 0.0 | 161.0 |
| Moonburst | 12/12 | 59.2 / 65.7 / 65.3 / 88.6 | 0.0 | 162.9 |
| Moonfire | 12/12 | 65.3 / 63.0 / 75.4 / 96.0 | 0.0 | 167.8 |
| Moon familiar | 12/12 | 52.6 / 65.7 / 62.0 / 93.6 | 5.2 | 145.7 |
| Moon Ward | 12/12 | 64.0 / 55.3 / 75.3 / 96.0 | 0.0 | 143.9 |
| Comet baseline | 12/12 | 37.6 / 40.9 / 46.3 / 42.9 | 23.5 | 209.0 |
| Second Comet | 12/12 | 38.2 / 41.1 / 39.0 / 44.5 | 32.5 | 202.5 |
| Long Comet | 12/12 | 37.8 / 37.4 / 42.8 / 43.4 | 16.9 | 202.9 |
| Venom Wake | 12/12 | 37.4 / 37.7 / 43.1 / 43.4 | 19.7 | 205.5 |
| Comet Impact | 12/12 | 37.9 / 37.0 / 40.9 / 40.4 | 26.5 | 230.2 |

All 19 policies survived this automated sample. It therefore does not establish a mortality ranking or human difficulty estimate. The shorter Comet observations reflect offensive dash use and close-range burst; Moon frequently trades lower HP and slower encounters for shielded ranged safety. Blade area variants trade single-target damage for coverage. Random legal rewards and controller behavior also affect the differences.

Median HP-loss values for Moon exclude all shield absorption. End HP is not a normalized survivability score: each class can have different maximum HP and real level-up/healing gains. Full entry and exit stats are in the raw rows.

### Adversarial compatible-upgrade stress

**18/18 clears; 0 deaths; 0 living timeouts. 1,116 actual kills.** These are deliberately generous loadouts, not natural-campaign results.

| Stage-20 stress policy | Clears | Median clear seconds | Median HP loss | Median end HP | Median shield left |
|---|---:|---:|---:|---:|---:|
| Blade thrust | 3/3 | 42.4 | 13.8 | 400.0 | 0.0 |
| Blade cleave | 3/3 | 43.5 | 50.3 | 400.0 | 0.0 |
| Blade sweep | 3/3 | 50.6 | 104.6 | 400.0 | 0.0 |
| Ranger Star Fan | 3/3 | 58.1 | 93.8 | 400.0 | 0.0 |
| Moon Lunar Fan | 3/3 | 45.9 | 0.0 | 280.0 | 51.7 |
| Second Comet | 3/3 | 40.0 | 48.6 | 400.0 | 0.0 |

Capped upgrades stayed within their valid stat/resource bounds in the focused adversarial tests. Actual stress combat retained normal damage and healing. Full HP at exit can result from regeneration and Life Drain; it is not a damage-immunity claim.

### Natural 20-stage campaigns

**8/8 campaigns cleared all 20 stages, with 5,888 actual kills.** 160/160 clears; 0 deaths; 0 living timeouts across the 160 measured arenas. Every successful campaign killed exactly 736 enemies. The final post-combat transitions completed without errors.

| Policy | Campaign clears | Median total combat seconds | Median cumulative HP loss | Final HP: seed 1760 / 2026 | Final shield: seed 1760 / 2026 |
|---|---:|---:|---:|---:|---:|
| Blade thrust | 2/2 | 816.4 | 329.2 | 346.1 / 363.4 | 0.0 / 0.0 |
| Ranger Star Fan | 2/2 | 783.3 | 494.0 | 400.0 / 346.1 | 0.0 / 0.0 |
| Moon Lunar Fan | 2/2 | 795.8 | 30.1 | 242.2 / 242.2 | 0.0 / 29.2 |
| Second Comet | 2/2 | 665.4 | 292.6 | 346.1 / 346.1 | 0.0 / 0.0 |

Total combat seconds sum measured arena time, including intra-wave gaps. They exclude modal decision time and post-clear pickup/portal transitions. These are automated runs, not human completion times.

### Reproducibility and retained evidence

Eight independent replays (seed 1760, four representative class policies, stages 5 and 20) matched every recorded row field exactly. All final runs completed without script errors; recorded kills plus remaining foes matched each arena roster, active populations stayed within the stage caps, and exit HP stayed within the actual exit maximum.

Raw final results: `authoritative-legal.json`, `authoritative-stress.json`, `authoritative-campaigns.json`, and `authoritative-replay.json`. Preliminary pilot files are excluded. No cumulative shield-absorption figure was measured or inferred.

## Focused regression coverage

`v7_tests.gd`: **293 assertions passed**, zero failures. These fixtures deliberately inject state to isolate behavior and are separate from the real-combat results.

- Every class-only branch is offered/applied solely to its owner; every conflicting melee style and repeated capped rank is rejected.
- Persistent mismatched starting skills are cleared, valid starting ranks reset correctly, legal offer UI includes a class choice, and full-cap no-op/mastery-rest paths do not softlock.
- Narrow slash, thrust, cleave and sweep exercise actual front/side/rear hit geometry, damage/reach tradeoffs, anticipation, cadence and once-per-target swing gates.
- Staff spread checks actual projectile count, normalized damage, homing speed/turn bounds, straight-launch delay and independent radial cooldown/cap.
- Fire overlap, finite poison, overkill Life Drain, familiar cadence/cap/displacement and collision-checked push retain their intended limits.
- Shield absorption, partial spill to HP, delayed regeneration, cross-boundary frame accounting, added-capacity behavior, immunity and level-growth independence.
- Normal and two-charge dash use, serial recovery, preserved upgrade-time progress, long-frame bounds, extended travel and once-per-actual-dash damage/poison.
- Ranger movement/cadence, multi-arrow volleys, serial trap charges, real map-hazard contacts, repeat-contact prevention, ordinary enemy damage, immunity preservation and simultaneous hazards.
- Paused, upgrade, loot, menu, dead and won states freeze class mechanics. Stage entry/new runs reset resources; death clears effects.

The complete regression run passes **1,375 assertions plus the integration self-test** across all eight suites: regression, healing, balance, combat, weapon, pattern, v6 map/wave/hazards, and the focused v7 class tests. Native visual inspection also covers 24 seeded class captures plus the clean default menu; audio listening was not verified.

## Limits

- This is a small seeded automated sample, not a human playtest or human win-rate estimate. The controller knows committed geometry exactly, even outside the camera view, and often avoids attacks better than a person.
- The controller uses class-appropriate range and offensive Comet dashes. Its movement policy can favor some mechanics. Approximate pathfinding can stall; a timeout does not prove an arena is impossible.
- A shielded class's low HP-loss total cannot be read as zero incoming pressure. Direct comparisons need its lower HP ceiling and shield state as context.
- Max-stack stress primarily detects cap/resource/damage-system failures. It cannot prove balanced natural progression or equal branch strength.
- No unmeasured human campaign completion, audio playtest, or definitive competitive balance is claimed. Differences in clear time are expected tradeoffs between area, reach, burst mobility and safety.

## Reproduce

Import assets first and use writable Godot HOME/XDG directories in restricted containers.

```sh
godot --headless --editor --path PROJECT --import --quit
godot --headless --path PROJECT --script v7_tests.gd

godot --headless --path PROJECT --script balance_simulation_v7.gd -- \
  --seeds=1760,2026,4511 --output=legal.json

godot --headless --path PROJECT --script balance_simulation_v7.gd -- \
  --stress --seeds=1760,2026,4511 --targets=20 \
  --modes=blade_thrust,blade_cleave,blade_sweep,ranger_fan,moon_spread,comet_echo \
  --output=stress.json

godot --headless --path PROJECT --script balance_simulation_v7.gd -- \
  --campaign --seeds=1760,2026 \
  --modes=blade_thrust,ranger_fan,moon_spread,comet_echo \
  --output=campaigns.json
```

Full entry/exit stats, ranks, actual kills, outcome, observation time, HP loss, shield, guardian attack counts, hazards and chosen rewards are retained in each raw row. Saved profiles are disabled in all test/benchmark games.


## Frozen-source SHA-256

These measured gameplay/harness files were unchanged across all final runs and their replay.

| File | SHA-256 |
|---|---|
| `main.gd` | `af5ffd8e02c7b4fabd6e78a69e63f63cf05ef4a840258c7482c2788ae1c5e137` |
| `data.gd` | `afa39d6a3e8059d07a0da9f3f9703fc66c5a9e6d78a7094ce42f49593f707928` |
| `combat.gd` | `c091c15c3f14fde6d0c9aea6926ce947e5989df8c3bbe6458c1c6d2e849fe06b` |
| `class_combat.gd` | `e565c9212af55317d429e34cf40e862e8154cd8a99bdb37b2d9edff4795509fc` |
| `class_progression.gd` | `f89f3f63e9cad7d407b30c3795a0236d45afb6aa64bf16fec6b61b704068bedd` |
| `world.gd` | `b0fdfb7dec2899c86f2b219b5ad496847676a6ba94051b1a0fb839aa16eb09ac` |
| `balance_simulation_v7.gd` | `fc0b19ac3e2d8b137f6f01c20525465de3ff50b20f725a2d42fbb8958c47d07e` |
| `balance_probe.gd` | `52930c8fb6a95be3882685cab9130f6d4aa47de5a9719b855a9b53eae2eaedf7` |

Inherited `balance_simulation_v6.gd` SHA-256: `4adc696562704228b4de3eb0c5b011afa2aa3cafc2ab5ec904627df3c0b9bdda`. This post-run verification matches the unchanged harness hash documented in the v6 release. It is the movement, navigation, prior-stage XP, offer-resolution and campaign-transition dependency used by v7.
