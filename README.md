# Legi's adventure — v7

An original pixel-art survivors roguelike made in **Godot 4.6.3**.
Four distinct Classes with bounded branches, rechargeable resources and original
pixel effects. Twenty expanded arenas, four guardians, ten regular enemy types,
staggered enemy groups and environmental hazards remain. This ZIP is the editable source project, **not a standalone EXE**.

## Play
1. Install standard Godot 4.6.x from https://godotengine.org/download/.
2. Extract the ZIP, import `project.godot`, and press F5.
3. Choose CLASS in the normal menu, then Start Adventure.

No add-ons, paid assets, network connection, or external dependencies are
required. The Compatibility renderer is used. The default scene is
`main.tscn`; no test controller, seeded encounter, invulnerability, or saved
QA progress is enabled by default.

## Controls
- WASD / arrows: move; hold left mouse to follow the pointer.
- Space / right mouse: dash. One charge (Comet can unlock two), serial recharge, dash immunity. A second dash starts after the first ends.
- Escape: pause / resume.
- Primary attacks automatically aim at the nearest living enemy. Move to
  establish line of sight; arrows and spells stop at walls and their first hit.

## Player systems

| System | Current behavior |
|---|---|
| Class | Select the primary weapon, starting attributes, Class bonus and resources before a run. |
| Tactic | Every five levels, choose one of up to three random offers. Ranks reset each run; a Class Tactic is offered whenever eligible. |
| Skill | Choosing a Tactic permanently discovers its corresponding Skill. Equip one Starting Skill at rank 1 for the next run. |
| Equipment | After clearing a guardian arena, choose one random Equipment reward with two stat bonuses. Bonuses stack for this run; discovered names remain in the Equipment Journal. |
| Stats | Bounded combat attributes affected by levels, Class bonuses, Tactics and Equipment. |
| Cosmetics | Permanent appearance choices with no stat bonuses. |

These names replace Build, Special Upgrade, Starting Ability and Relic.
This terminology update preserves the current reward rules: guardians award Equipment; Skills are discovered through Tactics. Equipment has no removable slots in the current game. See [CONTEXT.md](CONTEXT.md) for the glossary.

## Four Class identities

All primary attacks have visible anticipation and aim automatically. No class has
an invisible sword. Hybrid Tactics remain available, but auxiliary bow/magic caps
are lower than the specialist's caps. At least one eligible class branch is offered
in every three-choice Tactic menu; the remaining offers come from the shuffled pool.
Class branches are standalone so any discovered branch can be your one Starting Skill.
Auxiliary Starlight gives eight support sparks at 15% / 20% base damage and a
fixed 2.3s cooldown. Its old high-damage, attack-speed-multiplied volley is reduced
so an auxiliary does not overshadow a class primary. Auxiliary bow still uses
a 1.4s base cooldown and at most two arrows.

### Blade Dancer: narrow precision or lower-damage coverage
Starts with a **70-degree focused sword slash**, 78px reach, 18 damage and
0.85s base start-to-start cooldown. Windup/active/recovery are 0.12s each.
Choose **one** style per run; selecting it locks the other two out:

| Style | Total arc | Reach multiplier | Damage per target | Base cooldown |
|---|---:|---:|---:|---:|
| Starting slash | ~70° | 100% | 100% | 0.85s |
| Needle Thrust | ~33° | 130% | 130% | 0.90s |
| Crescent Cleave | 180° | 100% | 80% | 0.85s |
| Whirlwind Sweep | 360° | 90% | 55% | 0.85s |

Each swing hits each enemy once. A full sweep includes directly behind the owl.
Thrust is longer and stronger but narrower and slower; wide styles sacrifice
single-target damage. Actual reach follows the drawn outer arc.

### Moon Weaver: fragile health, mana shield and turning spells
Starts with **70 HP + 35 shield**, versus 100 HP on other classes. Shield regenerates
at **7/s after four seconds without an accepted hit**. Armor applies first, shield
absorbs next and only the remainder damages HP. Even a fully absorbed hit resets
the delay and grants the ordinary 0.65s hurt window. Ignored iframe hits do not
restart it. Potions, regen, level heals, clear heals and Life Drain restore HP only.
The HUD has a separate numeric shield bar and recharge-delay indicator.

The staff channels for 0.28s, has 0.95s base cooldown and releases a homing bolt
that turns at most **2.8 radians/s**. It still stops at walls or its first target;
it does not pierce or instantly snap direction. Spread bolts fly straight for the
first 0.12s before homing so the fan remains readable. Damage multiplier is
`1.1 + 0.15 × (magic power − 1)`, bounded to 1.1–1.4 at normal staff power.

- **Lunar Fan, 2 ranks:** 3 / 5 homing bolts. The whole volley deals 135% / 165%
  of a normal bolt if all connect, divided among the bolts; no full-damage cloning.
- **Moonburst, 2 ranks:** a staff release can add eight non-homing radial sparks,
  each 15% / 22% base damage, with a separate **2.3s minimum cooldown**.
- **Moonfire, 2 ranks:** walking leaves violet fire every 12px; dashing does not.
  Patches last 1.4s, radius 17px, maximum 32. Each enemy takes 12% / 18% base damage
  at most once per 0.35s across all overlapping patches.
- **Orbiting Familiar, 1 rank:** one little pixel spirit follows you and launches
  a homing shot every 0.9s for 35% base damage. It is not a collision blocker.
- **Waxing Ward, 2 ranks:** +10 shield capacity and +1 shield/s each; maximum 55
  shield at 9/s. Buying capacity does not fill it or bypass the damage delay.

### Star Ranger: mobility, quick volleys and finite trap avoidance
Starts at **175px/s movement, 1.15 attack speed and one arrow**. Other classes
start at 150px/s and 1.0 attack speed. Bow draw 0.20s, base cooldown 0.85s, each
arrow 90% damage. Arrows use a fixed 0.13-radian spread and stop on first hit/wall.

- **Quickdraw, 2 ranks:** +0.20 attack speed each, specialist cap 2.40.
- **Star Fan, 2 ranks:** +1 arrow each, shared with Split Shot, maximum 4 arrows.
- Base **Trap Evade:** one charge, **12s** serial recharge. An otherwise damaging
  environmental eruption spends one charge instead of damaging you.
- **Trail Instinct, 2 ranks:** +1 capacity and −1s recharge each; maximum 3 charges,
  minimum 10s. Added capacity begins empty. No extra hurt immunity is granted.

The HUD shows charges and next recharge. Trap Evade applies **only to map
eruptions**, never guardian moves, enemy melee or bullets. Existing dash/hurt
immunity avoids a map hit without wasting a charge. A different simultaneous
trap can still hit if charges are empty.

### Comet Strider: consecutive dashes, poison and impact
Starts with a fast short dagger (82% damage, 78% reach, 0.62s base cooldown) and
**+22 dash bonus damage**. A damaging dash deals base damage plus dash bonus
once per enemy per dash. The original cyan pixel afterimages now visibly mark
the travelled path.

- **Second Comet, 1 rank:** two genuinely separate dash charges. Spent charges
  recharge **one at a time**; spending the second never restarts the first timer.
  Added capacity begins empty, and you cannot restart an active dash.
- **Long Comet, 2 ranks:** dash duration 0.18 → 0.22 → 0.26s. Movement uses swept
  wall collision; longer duration cannot add another hit on the same enemy.
- **Venom Wake, 2 ranks:** a dash contact poisons its target for 3s, ticking every
  0.5s for 1.5 / 2 damage per stack. Maximum3 stacks, refreshed duration but preserved
  tick cadence. At most six ticks per application interval; no per-frame stacking.
- **Comet Impact, 2 ranks:** collision-safe 20 / 32px push on idle/recovering foes.
  Windup/active enemies stay anchored so their displayed attack geometry remains valid.

Poison is applied by dash contact, not by lingering decorative afterimages.
All poison, fire, familiar, bolt, melee and dash damage uses the same actual-damage
Life Drain path: no overkill healing, repeated dead-target healing or revival.
Resources and damage-over-time freeze during menus/pause/death. Every new arena
clears old effects and replenishes shield, dash and trap charges deliberately;
there is no mid-arena free refill from upgrading.

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
increase is slightly above 25%. The once-only 10% clear heal, guardian Equipment
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
five-stage theme. Every fifth level offers three Tactics (including a class branch when eligible);
guardians offer a choice of three Equipment. Enter the center portal after all
enemies and drops are resolved. Stage 20's final portal wins the run.

Shared Tactic ranks and diminishing increments remain, with class-aware final caps.
Baseline level growth is 3% for active stats, except the fixed Life Drain
percentage; each Class also receives 18% of its listed Class bonus: Blade speed 22/attack-speed 0.35; Ranger speed 4/attack-speed 0.05/damage 3; Weaver magic 0.3/pickup 20/damage 2; Comet dash-damage 22/cooldown −0.35. Death resets
run growth and equipment; discovered Skills, cosmetics, equipment journal,
records and settings persist. V6 saves are accepted: discovered IDs remain, invalid/unknown IDs are discarded, and an equipped class-incompatible skill is cleared when loading or switching classes. Run ranks, shield and charge timers are never persisted.

- Base EXP/potion pickup: **75 px**.
- Once-per-arena clear heal: **10% of maximum HP**.
- Herbalist potions: **2% / 4% / 6%**, with **60% / 30% / 10%** odds.
- Life Drain: unique, nonstacking **10% of actual enemy HP removed**, after
  shield mitigation and excluding overkill. It cannot revive a dead player.
- Level-up heal: **12 HP**. All healing is bounded by maximum HP.

### Final effective limits, including Equipment
| Stat | Limits |
|---|---|
| Maximum HP | 1–280 Weaver; 1–400 others |
| Base damage stat | 1–80 |
| Movement speed | 1–240 px/s |
| Attack-speed stat | 0.3–2.4 Ranger; 2.2 Blade; 2.0 Weaver/Comet |
| Range | 1–145; dagger78%, thrust130%, sweep90% reach |
| Arrows per volley | 0–4 Ranger; 0–2 auxiliaries; floored |
| Magic power | 0–3 Weaver; 0–2 auxiliaries |
| Dash bonus damage | 0–120 |
| Dash recharge | 1.1–10 seconds |
| Pickup radius | 1–240 px |
| Regeneration | 0–3 HP/s |
| Flat armor | 0–8 |
| Life Drain | 0–10% |

Per-run Tactic ranks: Life Drain 1; Windstep, Long Reach, Starlight, Second
Wind, Treasure Magnet, Duelist's Rhythm, Farshot, Moon Harvest and Meteor
Boots 2; other original Tactics 3. New branch caps are listed above. Farshot increments scale 1 / .7; Long Reach 1 / .65;
Keen Edge and Quick Hands 1 / .8 / .6. Starting Skills consume rank 1.
Choice cards show actual next gains. Capped or wholly ineffective choices are
excluded; an exhausted pool safely offers a one-time 10% mastery rest per
pending reward. Equipment cannot bypass final limits.

## Verification and limits

**1,375 regression assertions plus the integration self-test pass** in Godot 4.6.3.
Inherited tests were adapted explicitly for class caps, Moon HP/bolt scaling,
real charge recovery and the lower auxiliary-magic damage/cooldown. The new
293-assertion suite covers branches, resource timing, interrupted states and
no-op/overcap Tactic handling.

The original release screenshots, raw benchmark JSON and frozen hashes in the release notes are historical v7 snapshots from before the terminology update. Their labels may use the former names; they have not been regenerated by this rename.

See [V7_BALANCE_NOTES.md](V7_BALANCE_NOTES.md) for the recorded actual-combat benchmark
method, class observations, regressions and limits. V6/V5 reports remain historical
records and are not claims about the new balance.

Run from the project folder:
```sh
godot --headless --editor --path . --import --quit
godot --headless --path . -- --self-test
godot --headless --path . --script regression_tests.gd
godot --headless --path . --script healing_tests.gd
godot --headless --path . --script balance_tests.gd
godot --headless --path . --script combat_tests.gd
godot --headless --path . --script weapon_tests.gd
godot --headless --path . --script pattern_tests.gd
godot --headless --path . --script v6_tests.gd
godot --headless --path . --script v7_tests.gd
```
Use writable HOME/XDG directories in restricted Linux environments. Test fixtures
never save profile progress; lifecycle regressions inject deaths for isolation.
Benchmark combat separately uses real attacks, movement, damage and kills.

The optional `visual_qa_v7.tscn` uses actual native rendering of class branches,
resources and Tactic menus, visibly labelled **SEEDED QA**. V6 and older visual
fixtures are retained for maps/enemies/guardians. The default is still the clean
normal `main.tscn` menu. Twenty-four native branch/menu screenshots are included.
Examples: [Blade choices](screenshots/seeded-v7-21-menu-blade-upgrades.png),
[Moonfire](screenshots/seeded-v7-08-moon-fire.png),
[shield damage](screenshots/seeded-v7-10-moon-shield-hit.png),
[Comet trail](screenshots/seeded-v7-16-comet-long-trail.png). A full human 20-stage playthrough, audio listening test,
exhaustive Class balance or human win-rate estimate is not claimed.

Current terminology menu captures (deterministic fixtures, not a natural playthrough): [Main menu](screenshots/systems/main-menu.png), [Class](screenshots/systems/class.png), [Tactic](screenshots/systems/tactic.png), [Starting Skill](screenshots/systems/skill.png), [Equipment](screenshots/systems/equipment.png).

## Save data and project files
Godot stores `legis_adventure.json` in its local user-data directory, usually
`%APPDATA%/Godot/app_userdata/Legi's adventure/` on Windows. No accounts or
telemetry are used. Save files and generated Godot caches are not included. The legacy profile keys `selected_build` and `selected_ability` remain unchanged so existing Class and Starting Skill selections still load.

- `CONTEXT.md`: canonical player-system terminology.
- `main.gd`: game loop, weapons, spawning, UI, healing, progression, saves.
- `combat.gd`: enemy behavior, boss selection, shared warning/hit geometry.
- `world.gd`: authored procedural maps, theme details and environmental hazards.
- `character_art.gd`: original articulated pixel characters and weapons.
- `data.gd`: Class/weapon definitions, stat limits, Tactics and cosmetics.
- `class_progression.gd`: class eligibility, final limits, shields and charge recovery.
- `class_combat.gd`: style shapes, turning magic, fire/familiar/poison and pixel effects.
- `balance_simulation_v7.gd` / `V7_BALANCE_NOTES.md`: current combat verification.
- `visual_qa_v7.gd` / `.tscn`: current isolated branch inspection fixture.
- `*_tests.gd`: automated regressions.
- `balance_simulation_v6.gd` / `balance_probe.gd`: optional instrumented controller.
- `visual_qa_v6.gd` / `.tscn`: optional labelled expanded-world inspection fixture.
- `assets/`: original transparent PNGs retained for menus/reference.
- `visual_qa.gd` / `.tscn`: optional labelled inspection fixture.
- Earlier `BALANCE_NOTES`, `V4_*` and result files are historical records.

Original code and artwork were created for this project. Godot is a separate
MIT-licensed engine and is not bundled in this download.
