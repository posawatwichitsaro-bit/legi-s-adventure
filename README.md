# Legi's adventure — v6

An original pixel-art survivors roguelike made in **Godot 4.6.3**.
Twenty expanded arenas, four guardians, ten regular enemy types, staggered
enemy groups, environmental hazards, and four real starting weapons. This ZIP is the editable source project, **not a standalone EXE**.

## Play
1. Install standard Godot 4.6.x from https://godotengine.org/download/.
2. Extract the ZIP, import `project.godot`, and press F5.
3. Choose BUILD in the normal menu, then Start Adventure.

No add-ons, paid assets, network connection, or external dependencies are
required. The Compatibility renderer is used. The default scene is
`main.tscn`; no test controller, seeded encounter, invulnerability, or saved
QA progress is enabled by default.

## Controls
- WASD / arrows: move; hold left mouse to follow the pointer.
- Space / right mouse: dash. One charge, automatic recharge, dash immunity.
- Escape: pause / resume.
- Primary attacks automatically aim at the nearest living enemy. Move to
  establish line of sight; arrows and spells stop at walls and their first hit.

## Your BUILD equips your weapon immediately
| Build | Level-1 weapon | Playstyle |
|---|---|---|
| Blade Dancer | Sword | Wide, timed melee slash; movement and attack-speed growth |
| Star Ranger | Bow | Aimed arrow volley with visible draw; arrows and damage growth |
| Moon Weaver | Moon staff | Aimed magic bolt with visible channel; magic-power and pickup growth |
| Comet Strider | Daggers + damaging dash | Faster, shorter, narrower slash; dash-damage/recharge growth |

Ranger and Weaver **do not have a hidden sword attack**. Each class has its own
held-weapon silhouette, walking pose and attack animation. Special upgrades
still support hybrid builds: Split Shot adds a bow to another class; Starlight
adds radial magic to non-staff classes or strengthens staff bolts; Comet Tail
adds dash damage. Starting abilities are optional additions to the equipped
weapon. There is one persistent starting-ability slot.

The shared range stat extends melee reach and, above its initial 78, increases
aimed arrow/staff-bolt speed by one pixel/second per point. Thus Long Reach and
Farshot still help ranged classes. It does not add projectile piercing or
increase projectile lifetime. See [V5_COMBAT_NOTES.md](V5_COMBAT_NOTES.md) for
exact weapon damage, timing and scaling.

## New enemies and late-game pressure
The original grunt, archer, swift, bomber, ghost and potion-carrying herbalist
remain. New roles accumulate in the later mixes:
- Stage 6+: **Sentinel**, a slow frontal shield. Flank it or punish recovery.
- Stage 6+: **Assassin**, a fast lateral flanker with a committed dagger lunge.
- Stage 11+: **Chanter**, which visibly hastens nearby allies and alternates
  with a three-shot pulse. Removing support reduces pressure.
- Stage 11+: **Hexer**, which marks a locked ground pool. Relocate before it
  activates; the pool cannot repeatedly hit during one cast.

Stages 16–20 mix all ten roles. The complete stage roster is now
`ceil((8 + 2 × stage + guardian) × 1.25)`, where guardian is 1 every fifth
stage and 0 otherwise. Rounding happens once, upward, for the whole stage.
There is exactly one guardian on boss stages and one herbalist per arena;
all added foes are regular enemies. Later pressure
comes from roles, positioning, speed and cadence as well as bounded health
and damage growth. Warnings remain visible and committed. **Touching an enemy
alone never causes damage.** Dash and ordinary hurt immunity remain intact.

## Bigger worlds, staged encounters
The arena grows from **896 × 456 to 1344 × 684 world pixels**, 50% wider and
50% taller, or **2.25× the playable area**. The 960 × 600 view stays the same;
a clamped follow camera reveals the map while HUD and menus stay fixed.
Pointer movement, automatic targeting, projectiles, drops and pickups all use
world coordinates. The corner map shows obstacles, foes, the player, viewport,
and the cleared portal. A P marker points to an off-screen portal; orange !
markers warn about enemy windups outside the view.

Enemies arrive in groups of **4 / 5 / 6 / 7** across the four theme tiers.
The simultaneous population is bounded at **6 / 8 / 10 / 12**. Groups are at
least three seconds apart, and wait until the complete next group fits under
the cap. Each arrival has a visible 0.85-second grace ring before it can act.
The guardian comes with the final group. The first group starts immediately;
remaining enemies and the progress bar include both active and queued foes.

The larger roster totals **736 foes across the run**, versus 584 in v5. The
per-stage counts are 13, 15, 18, 20, 24 / 25, 28, 30, 33, 37 /
38, 40, 43, 45, 49 / 50, 53, 55, 58, 62. Rounding explains why the full-run
increase is slightly above 25%. The once-only 10% clear heal, guardian relic
choice and portal all wait for every group and its remaining drops.
Pausing and reward menus also freeze the wave clock and hazard clock.

The four maps now have authored routes and landmarks: Meadow ponds and gardens,
Ember causeways and furnaces, Crystal courts and mosaics, and Night observatory
orbits and lunar stones. Random details and increasingly dense isolated props
vary every stage while keeping broad routes and the center sanctuary open.

Random bramble bursts, ember vents, prism eruptions and lunar seals warn for
**1.4 seconds**, become dangerous for **1 second**, then fade harmlessly. Gold
outlines warn, red/cream filled effects are active, and dashed outlines recover.
They never appear under the player or in the center sanctuary; dashes keep
their immunity. Decorative ponds and calderas are traversable scenery. Hazard
frequency and pairs increase across tiers, with a strict two/three-zone cap.

## Four guardians, eight additional moves
Original signature attacks remain, with new attacks interleaved:
| Stage | Guardian | Preserved signatures | New moves |
|---|---|---|---|
| 5 | Thorn Warden | Cleave, charge | Rootline: three root circles; Thornwheel: ring with a safe center |
| 10 | Ember Alchemist | Locked ground blast | Cinder Cross: crossing lanes; Ember Bloom: four offset blasts with a central pocket |
| 15 | Crystal Sentinel | Seven-shot fan, twelve-shot ring | Prism Lance: three parallel lanes; Crystal Spokes: six radial lanes |
| 20 | Night Sovereign | Cleave, charge, blast; phase-II fan | Eclipse: large ring with a safe center; Nightfall: three locked, staggered seals |

The new large hazards warn for at least 0.85 seconds. Orange outlines mark
windup, pale filled shapes mark active damage. Safe holes remain visibly
unfilled. Nightfall's dots indicate beat order. Bosses choose an available
longer-range move when a short attack cannot reach, rather than chasing
forever without attacking. No mid-windup retargeting occurs.

## Progression and healing
Every run begins at stage 1 / level 1. EXP crystal value rises with each
five-stage theme. Every fifth level offers three random special upgrades;
guardians offer a choice of three relics. Enter the center portal after all
enemies and drops are resolved. Stage 20's final portal wins the run.

The v3 limits, upgrade ranks and diminishing increments are preserved.
Baseline level growth is 3% for active stats, except the fixed Life Drain
percentage; each build also receives its existing path bonuses. Death resets
run growth and equipment; discovered abilities, cosmetics, equipment journal,
records and settings persist. Existing saves need no migration.

- Base EXP/potion pickup: **75 px**.
- Once-per-arena clear heal: **10% of maximum HP**.
- Herbalist potions: **2% / 4% / 6%**, with **60% / 30% / 10%** odds.
- Life Drain: unique, nonstacking **10% of actual enemy HP removed**, after
  shield mitigation and excluding overkill. It cannot revive a dead player.
- Level-up heal: **12 HP**. All healing is bounded by maximum HP.

### Final effective limits, including relics
| Stat | Limits |
|---|---|
| Maximum HP | 1–400 |
| Base damage stat | 1–80 |
| Movement speed | 1–240 px/s |
| Attack-speed stat | 0.3–2.2 |
| Range | 1–145; dagger uses 78% of melee range |
| Arrows per volley | 0–4, floored; Ranger starts with 1 |
| Magic power | 0–3; Weaver starts with 1 |
| Dash bonus damage | 0–120 |
| Dash recharge | 1.1–10 seconds |
| Pickup radius | 1–240 px |
| Regeneration | 0–3 HP/s |
| Flat armor | 0–8 |
| Life Drain | 0–10% |

Per-run skill ranks: Life Drain 1; Windstep, Long Reach, Starlight, Second
Wind, Treasure Magnet, Duelist's Rhythm, Farshot, Moon Harvest and Meteor
Boots 2; other skills 3. Farshot increments scale 1 / .7; Long Reach 1 / .65;
Keen Edge and Quick Hands 1 / .8 / .6. Starting abilities consume rank 1.
Choice cards show actual next gains. Capped or wholly ineffective choices are
excluded; an exhausted pool safely offers a one-time 10% mastery rest per
pending reward. Relics cannot bypass final limits.

## Verification and limits
See [V6_WORLD_NOTES.md](V6_WORLD_NOTES.md) for current map, hazard, wave and
visual coverage, and [V6_BALANCE_NOTES.md](V6_BALANCE_NOTES.md) for matched
v5/v6 real-combat comparisons. V5 notes/results are retained as historical
records of the unchanged weapon and guardian mechanics.

**863 assertions plus the integration self-test pass.** Run from the project folder:
```sh
# Import assets once after extracting a fresh ZIP.
godot --headless --editor --path . --import --quit
godot --headless --path . -- --self-test
godot --headless --path . --script regression_tests.gd
godot --headless --path . --script healing_tests.gd
godot --headless --path . --script balance_tests.gd
godot --headless --path . --script combat_tests.gd
godot --headless --path . --script weapon_tests.gd
godot --headless --path . --script pattern_tests.gd
godot --headless --path . --script v6_tests.gd
```
In restricted Linux environments use writable HOME / XDG data, config and
cache directories. Tests disable profile saves. Progression regressions use
injected kills to test the lifecycle; the separately labelled balance
campaigns use actual attacks, drops and rewards without injected kills.

Native cloud-desktop v6 inspection covers all four larger themed maps,
landmarks, environmental warning/active/recovery visuals, wave HUD, camera
scrolling and the portal indicator. The earlier v5 inspection covered all four
weapon silhouettes, ten regular enemies and eight new guardian moves.
`visual_qa_v6.tscn` and the retained `visual_qa.tscn` are optional, save-disabled,
clearly labelled SEEDED QA fixtures, not normal progression. Their controls are
listed in V6_WORLD_NOTES and V5_COMBAT_NOTES respectively. A complete human 20-stage playthrough and audio
playback are not claimed. The cloud desktop uses a dummy audio driver.
Enemy steering is lightweight and may stall at obstacles; the automated
controller is not a measure of human win rate or exhaustive build balance.

Visual references: [Meadow warning](screenshots/seeded-v6-1-hazards-telegraph-view0.png),
[Ember hazard](screenshots/seeded-v6-2-hazards-active-view0.png),
[Crystal hazard](screenshots/seeded-v6-3-hazards-active-view0.png),
[Night hazard](screenshots/seeded-v6-4-hazards-active-view0.png).
Earlier references: [weapon gallery](screenshots/seeded-weapons.jpg),
[enemy gallery](screenshots/seeded-enemies.jpg),
[Nightfall warning](screenshots/seeded-nightfall.jpg). All these visual references are labelled seeded fixtures.

## Save data and project files
Godot stores `legis_adventure.json` in its local user-data directory, usually
`%APPDATA%/Godot/app_userdata/Legi's adventure/` on Windows. No accounts or
telemetry are used. Save files and generated Godot caches are not included.

- `main.gd`: game loop, weapons, spawning, UI, healing, progression, saves.
- `combat.gd`: enemy behavior, boss selection, shared warning/hit geometry.
- `world.gd`: authored procedural maps, theme details and environmental hazards.
- `character_art.gd`: original articulated pixel characters and weapons.
- `data.gd`: build/weapon definitions, stat limits, upgrades and cosmetics.
- `*_tests.gd`: automated regressions.
- `balance_simulation_v6.gd` / `balance_probe.gd`: optional instrumented controller.
- `visual_qa_v6.gd` / `.tscn`: optional labelled expanded-world inspection fixture.
- `assets/`: original transparent PNGs retained for menus/reference.
- `visual_qa.gd` / `.tscn`: optional labelled inspection fixture.
- Earlier `BALANCE_NOTES`, `V4_*` and result files are historical records.

Original code and artwork were created for this project. Godot is a separate
MIT-licensed engine and is not bundled in this download.
