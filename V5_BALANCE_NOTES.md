# V5 balance benchmark

Measured with Godot 4.6.3 on 2026-10-10. Raw observations and source hashes: `balance_results_v5.json`.

## Main result

- Natural 20-stage campaign clears: **v4 25/25 → v5 23/25**. V4: 0 deaths, 0 live timeouts. V5: 1 death, 1 live timeout.
- Across 140 matched stage-15–20 campaign observations, median actual damage per encounter: **9.8 → 30.2 HP**; mean 12.0 → 37.6 HP. Median paired change: 19.4 HP.
- In the fixed 40 late healthy-entry lateral encounters, clears: **35/40 → 25/40**; survival: 40/40 → 31/40. Median damage: 50.2 → 154.8 HP.
- These observations measure added combat pressure without requiring the controller to lose. They do not establish human difficulty, a guaranteed win rate, or equal difficulty between classes.

## Method and parity checks

- Five seeds: 1760, 2026, 4511, 7727, 9981. Twenty-five natural campaigns per release: sword/Farshot, ranger, mage, dagger/dash, and sword/Life Drain, each on all five seeds.
- Eighty separate healthy-entry encounters per release: four classes × guardians at stages 5/10/15/20 × five seeds. Their simple left/right lateral movement is unchanged, with no dash.
- Natural campaigns use real attacks, XP, drops, healing, offered upgrades, offered relics and HP carryover. Only post-combat portal travel is shortened. No HP resets during campaigns.
- Starting-ability assumptions: Farshot for sword/ranger, Starlight for mage, Comet Tail for dagger/dash, and Life Drain for the drain policy. These are normal equip options after discovery; the benchmark assumes they have been unlocked and does not measure a first-ever profile.
- Healthy-entry setup grants the exact XP from earlier spawned enemies and one legal random relic offer per earlier guardian, then enters at the ordinary maximum HP. This isolates encounters; it is not an earlier-stage survival claim.
- Shared competent controller uses physical-key events through the actual input path, eight directions, decisions at 12 Hz, ordinary collision movement and the normal dash action. AStarGrid2D routes around blocked lines of sight, including collision-safe start cells and corner waypoints. Actual primary/unlocked aimed attacks determine range; v4 Ranger starts with a sword, and legacy radial magic is treated as support to melee.
- Both versions use byte-identical controller and probe files. Relic score treats v4 “range” and v5 “reach / shot speed” labels identically. Scores are applied only to legal displayed choices and deprioritize capped-out upgrades.
- Authoritative runs have zero script/resource errors. V5 campaigns were completed in seed batches and merged in the declared order; 44 repeated seed-4511 stage rows matched exactly across the sequential and independent runs. Earlier incomplete/resource-error pilots are excluded.
- Simulation is 120 Hz; each encounter has a 120-second observation limit. A live timeout is reported separately from death. Clear-time medians include only successful clears.
- Damage counters sum actual HP removed by successful damage calls after armor/invulnerability, capped at remaining HP on a lethal hit. Healing is measured independently through entry/end/minimum HP and does not erase damage history.

## Campaigns by build

| Build | v4 full clears | v5 full clears | v4 deaths / timeouts | v5 deaths / timeouts | Reached stage 15 v4 → v5 |
|---|---:|---:|---:|---:|---:|
| Sword / Farshot | 5/5 | 5/5 | 0 / 0 | 0 / 0 | 5 → 5 |
| Ranger | 5/5 | 5/5 | 0 / 0 | 0 / 0 | 5 → 5 |
| Mage | 5/5 | 3/5 | 0 / 0 | 1 / 1 | 5 → 4 |
| Dagger / dash | 5/5 | 5/5 | 0 / 0 | 0 / 0 | 5 → 5 |
| Sword / Life Drain | 5/5 | 5/5 | 0 / 0 | 0 / 0 | 5 → 5 |

### Late campaign observations by build

| Build | Observed stages v4 / v5 | Median damage HP v4 → v5 | Median successful clear seconds v4 → v5 |
|---|---:|---:|---:|
| Sword / Farshot | 30 / 30 | 5.0 → 21.7 | 12.8 → 22.3 |
| Ranger | 30 / 30 | 12.4 → 32.1 | 15.1 → 26.3 |
| Mage | 30 / 20 | 15.8 → 74.9 | 16.5 → 57.3 |
| Dagger / dash | 30 / 30 | 0.0 → 24.3 | 8.7 → 15.5 |
| Sword / Life Drain | 30 / 30 | 15.0 → 24.6 | 13.5 → 17.7 |

### Observed campaign stages 15–20

These rows include only campaigns that reached the listed stage. Clear time is a median over clears, not over deaths or timeouts.

| Stage | Observed v4 / v5 | Clears v4 / v5 | Survival v4 / v5 | Median damage HP v4 → v5 | Median clear seconds v4 → v5 |
|---|---:|---:|---:|---:|---:|
| 15 | 25 / 24 | 25 / 24 | 25 / 24 | 13.9 → 47.5 | 13.3 → 21.8 |
| 16 | 25 / 24 | 25 / 23 | 25 / 23 | 0.0 → 21.5 | 10.6 → 16.9 |
| 17 | 25 / 23 | 25 / 23 | 25 / 23 | 0.0 → 26.9 | 10.2 → 23.8 |
| 18 | 25 / 23 | 25 / 23 | 25 / 23 | 0.0 → 18.9 | 12.5 → 24.6 |
| 19 | 25 / 23 | 25 / 23 | 25 / 23 | 13.2 → 24.1 | 17.0 → 26.6 |
| 20 | 25 / 23 | 25 / 23 | 25 / 23 | 13.8 → 54.0 | 17.6 → 26.0 |

## Healthy-entry lateral encounters

Each guardian row has 20 independent encounters per release (four classes, five seeds). This is the less adaptive, historically unchanged stress control.

| Stage | Clears v4 → v5 | Survival v4 → v5 | Deaths v4 → v5 | Live timeouts v4 → v5 | Median damage HP v4 → v5 | Median clear seconds v4 → v5 |
|---|---:|---:|---:|---:|---:|---:|
| 5 | 12/20 → 8/20 | 17/20 → 12/20 | 3 → 8 | 5 → 4 | 51.2 → 125.0 | 40.4 → 40.2 |
| 10 | 17/20 → 8/20 | 20/20 → 16/20 | 0 → 4 | 3 → 8 | 25.0 → 85.6 | 16.5 → 17.5 |
| 15 | 16/20 → 11/20 | 20/20 → 14/20 | 0 → 6 | 4 → 3 | 43.1 → 171.7 | 16.7 → 38.6 |
| 20 | 19/20 → 14/20 | 20/20 → 17/20 | 0 → 3 | 1 → 3 | 65.8 → 135.8 | 13.2 → 24.5 |

## Naturally observed new guardian moves

Counts come from ordinary enemy state transitions during the measured fights; attacks were never forced. “Started” is entry into windup; “released” is windup → active. A death or interruption may prevent a started attack from releasing.

| New move | Campaign starts / releases | Lateral starts / releases |
|---|---:|---:|
| rootline | 64 / 61 | 54 / 53 |
| thornwheel | 37 / 37 | 75 / 75 |
| cinder_cross | 71 / 68 | 81 / 77 |
| ember_bloom | 62 / 59 | 73 / 70 |
| prism_lance | 75 / 70 | 80 / 76 |
| crystal_spokes | 28 / 27 | 10 / 10 |
| eclipse | 19 / 17 | 8 / 7 |
| nightfall | 59 / 56 | 38 / 37 |

## Non-clear outcomes

### v4 campaigns: 0 non-clears

None.

### v5 campaigns: 2 non-clears

| Seed | Build policy | Stage | Outcome | Observed seconds | Remaining enemies | HP left |
|---|---|---:|---|---:|---:|---:|
| 4511 | mage | 16 | died | 33.8 | 23 | 0.0 |
| 7727 | mage | 8 | timeout | 120.0 | 3 | 146.9 |

The mage death at seed 4511 entered stage 16 at 53.0 / 215.7 HP after real prior-stage attrition, then died after 33.8 seconds. The mage timeout at seed 7727 took no damage during stage 8, ended at 146.9 HP, and left three enemies (two with blocked line of sight). That live timeout is consistent with a policy/geometry stall and is not counted as a death or proof that the class cannot win.

The mage death entered stage 16 with 53.0 / 215.7 HP carried from earlier arenas.
The stage-8 mage timeout took zero damage during that arena and remained alive
with three enemies; remaining positions and line-of-sight/route diagnostics are
retained in the raw rows. Neither outcome was removed or tuned away.

### v4 lateral: 16 non-clears

| Seed | Build policy | Stage | Outcome | Observed seconds | Remaining enemies | HP left |
|---|---|---:|---|---:|---:|---:|
| 1760 | farshot | 5 | timeout | 120.0 | 1 | 21.0 |
| 1760 | ranger | 5 | died | 103.4 | 3 | 0.0 |
| 1760 | mage | 5 | timeout | 120.0 | 1 | 87.6 |
| 1760 | dash | 5 | died | 115.8 | 6 | 0.0 |
| 2026 | dash | 5 | timeout | 120.0 | 3 | 75.2 |
| 4511 | dash | 5 | timeout | 120.0 | 2 | 110.1 |
| 4511 | dash | 20 | timeout | 120.0 | 1 | 298.5 |
| 7727 | farshot | 10 | timeout | 120.0 | 1 | 160.5 |
| 7727 | dash | 5 | timeout | 120.0 | 2 | 118.0 |
| 7727 | dash | 10 | timeout | 120.0 | 1 | 160.5 |
| 9981 | farshot | 15 | timeout | 120.0 | 2 | 215.7 |
| 9981 | ranger | 15 | timeout | 120.0 | 2 | 257.7 |
| 9981 | mage | 15 | timeout | 120.0 | 2 | 137.2 |
| 9981 | dash | 5 | died | 49.6 | 5 | 0.0 |
| 9981 | dash | 10 | timeout | 120.0 | 1 | 156.7 |
| 9981 | dash | 15 | timeout | 120.0 | 2 | 144.9 |

### v5 lateral: 39 non-clears

| Seed | Build policy | Stage | Outcome | Observed seconds | Remaining enemies | HP left |
|---|---|---:|---|---:|---:|---:|
| 1760 | farshot | 5 | died | 36.9 | 5 | 0.0 |
| 1760 | farshot | 10 | timeout | 120.0 | 1 | 160.5 |
| 1760 | ranger | 5 | died | 21.0 | 10 | 0.0 |
| 1760 | mage | 5 | died | 28.8 | 10 | 0.0 |
| 1760 | mage | 10 | timeout | 120.0 | 3 | 87.8 |
| 1760 | mage | 15 | died | 37.4 | 23 | 0.0 |
| 1760 | mage | 20 | timeout | 120.0 | 2 | 227.3 |
| 1760 | dash | 5 | died | 31.3 | 7 | 0.0 |
| 1760 | dash | 10 | died | 102.9 | 5 | 0.0 |
| 2026 | mage | 15 | died | 63.1 | 2 | 0.0 |
| 2026 | mage | 20 | died | 50.6 | 5 | 0.0 |
| 2026 | dash | 5 | timeout | 120.0 | 5 | 29.6 |
| 2026 | dash | 10 | timeout | 120.0 | 1 | 103.0 |
| 4511 | ranger | 10 | timeout | 120.0 | 1 | 160.5 |
| 4511 | mage | 5 | timeout | 120.0 | 1 | 21.1 |
| 4511 | mage | 10 | timeout | 120.0 | 1 | 57.3 |
| 4511 | mage | 15 | died | 66.7 | 11 | 0.0 |
| 4511 | mage | 20 | timeout | 120.0 | 4 | 52.5 |
| 4511 | dash | 5 | timeout | 120.0 | 3 | 102.4 |
| 4511 | dash | 10 | timeout | 120.0 | 6 | 96.1 |
| 4511 | dash | 15 | timeout | 120.0 | 4 | 145.3 |
| 7727 | farshot | 10 | timeout | 120.0 | 1 | 160.5 |
| 7727 | ranger | 5 | died | 26.4 | 5 | 0.0 |
| 7727 | ranger | 20 | timeout | 120.0 | 1 | 298.5 |
| 7727 | mage | 5 | died | 23.4 | 14 | 0.0 |
| 7727 | mage | 10 | died | 47.1 | 19 | 0.0 |
| 7727 | mage | 15 | died | 50.4 | 14 | 0.0 |
| 7727 | mage | 20 | died | 36.2 | 23 | 0.0 |
| 7727 | dash | 5 | died | 31.2 | 4 | 0.0 |
| 7727 | dash | 10 | timeout | 120.0 | 1 | 160.5 |
| 9981 | farshot | 5 | died | 29.0 | 1 | 0.0 |
| 9981 | farshot | 15 | timeout | 120.0 | 2 | 174.6 |
| 9981 | ranger | 15 | timeout | 120.0 | 3 | 193.4 |
| 9981 | mage | 10 | died | 34.7 | 18 | 0.0 |
| 9981 | mage | 15 | died | 13.3 | 31 | 0.0 |
| 9981 | mage | 20 | died | 37.5 | 25 | 0.0 |
| 9981 | dash | 5 | timeout | 120.0 | 5 | 10.9 |
| 9981 | dash | 10 | died | 60.5 | 3 | 0.0 |
| 9981 | dash | 15 | died | 15.6 | 9 | 0.0 |

## Limitations and interpretation

- Five selected deterministic seeds are a reproducible regression sample, not an estimate of human win probability.
- Starting abilities assume prior discovery/unlock: Farshot for sword and ranger, Starlight for mage, Comet Tail for dagger/dash, and Life Drain for the drain policy. This is not a first-ever profile benchmark.
- Campaigns carry real HP, upgrades, XP, drops and damage through all stages. Healthy-entry encounters reset normal maximum HP and synthesize exact prior XP plus legal guardian rewards; their survival rates are not campaign survival rates.
- The controller sees every visible committed cue and predicts projectile motion. This is stronger than typical human play in some respects and weaker at tactical navigation in others.
- Old/new primary attacks, enemy encounters and random eligible reward pools differ. Matched seeds are not identical combat circumstances, and this comparison does not isolate enemy tuning from player weapon changes.
- Identical controller/probe source and reward scoring were used on both releases. A legacy radial magic unlock does not cause sword range to be treated as staff range.
- Timeouts remain alive at 120 seconds; they are not deaths and are excluded, with deaths, from clear-time medians. Their positions, remaining enemies, line of sight and controller routes are preserved in raw rows.
- Late campaign summaries are conditioned on reaching those stages. Paired late rows avoid comparing different seed/strategy/stage identities but do not remove all survivor/entry-state selection effects.
- Damage is actual positive HP removed after armor and immunity, capped at remaining HP for lethal hits. Healing does not subtract; repeated damage can exceed entry max HP.
- No gameplay balance was tuned in response to the final five-seed sample. No injected combat kills, HP inflation, damage immunity, enemy repositioning or forced guardian attacks.

## Reproduce

Use the unmodified corresponding release directory. Copy this release’s `balance_simulation_v5.gd` and `balance_probe.gd` unchanged into both v4 and v5. Import the project first so asset caches exist. Use a writable HOME and XDG config/data/cache directories. Run:

```sh
godot --headless --path PROJECT --editor --quit
godot --headless --path PROJECT --script balance_simulation_v5.gd -- --campaign --movement=kite --modes=farshot,ranger,mage,dash,drain --output=campaigns.json
godot --headless --path PROJECT --script balance_simulation_v5.gd -- --movement=horizontal --modes=farshot,ranger,mage,dash --output=lateral.json
```

Omitting `--seed` runs the five listed seeds. `--seed=1760` reproduces one. Do not mix these results with earlier pilots: those exposed class-range assumptions and obstacle navigation failures, and are superseded here.

## Frozen source SHA-256

| File | v4 | v5 |
|---|---|---|
| `main.gd` | `bdb115048ef133e99dc9a924c53cebfe05b50de8addecd656075bec7b16e52d1` | `8e63561566b1def6cdc1d7dded1205cc976acde798ff72ef4658b6c977dadaed` |
| `data.gd` | `3ced0558f3906c034f97ce6e42a7ab87164c7ceb27f2934751119387ef1124c6` | `6d34d3545d2303ba60370395876d8d394aadeb635e2566b85ed928a9a779792a` |
| `combat.gd` | `7c252d9b6bac99f9e96f3c5a408d77e69c6bd3c71e2f7718167cc5f94cbf1f04` | `137b10d7be4bfcd9869b384dc1504c21016b29b0f73c6b152f806004d6c80011` |
| `character_art.gd` | `741a925814963ca82ff200b14157ed220b0be7ad480db2d1f0e23fbb690dad84` | `6f9961fe8f4f6ae9bf6ab7de389ed4389bfdcb839fcce0f2faedc4d0cbb6dfef` |
| `project.godot` | `835bec1af6eacab47abc1cd3f521fcfd3bd5f12b465fc81904138ee18831eb4d` | `835bec1af6eacab47abc1cd3f521fcfd3bd5f12b465fc81904138ee18831eb4d` |
| `balance_simulation_v5.gd` | `d8cdc9b449409c1604102dff96cb44b76b466eca931a011356eaeff755b17b04` | `d8cdc9b449409c1604102dff96cb44b76b466eca931a011356eaeff755b17b04` |
| `balance_probe.gd` | `52930c8fb6a95be3882685cab9130f6d4aa47de5a9719b855a9b53eae2eaedf7` | `52930c8fb6a95be3882685cab9130f6d4aa47de5a9719b855a9b53eae2eaedf7` |
