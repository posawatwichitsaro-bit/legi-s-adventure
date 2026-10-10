# v4 combat balance comparison

Godot 4.6.3, 10 October 2026. `balance_results_v4.json` contains the full inputs,
legal reward choices, arena outcomes, summaries, failure snapshots, and tested
source hashes. The original `balance_results.json` and `BALANCE_NOTES.md` remain
unchanged.

**v4 completed all 17 sampled natural 20-arena campaigns, with no deaths or live
timeouts.** Capped v3 completed 16/17, with no deaths and one live stage-1
controller timeout. This supports viability under the tested controller; it is
**not proof of human fairness, a human win rate, or exhaustive build balance**.

## What is compared

Here, **v3 means the capped `candidate` results** in `balance_results.json`, not
that file's older uncapped `baseline`. v4 replaces instant attacks and passive
enemy contact damage with committed windup/active/recovery attacks and four
separate guardian attack sets. Its sword uses 0.12 s windup, 0.12 s active and
0.12 s recovery; bow and spell releases also have anticipation.

The benchmark is the unchanged `balance_simulation.gd`. It calls the real
`main.gd` simulation at 120 Hz, with a 120-second budget per arena. The complete
v4 suite contains **400 arena records: 340 natural-campaign arenas and 60
healthy-entry guardian encounters**. The comparison file also carries all 381
corresponding v3 candidate records. Godot completed the suite without script
errors or stuck post-combat transitions.

Five seeds (1760, 2026, 4511, 7727, 9981) test each main policy: Blade Dancer with
Farshot, Blade Dancer with Life Drain, and Star Ranger with Farshot. Moon Weaver
with Starlight and Comet Strider with Comet Tail each use seed 1760 only.

## Natural full campaigns

Each campaign starts at stage 1, level 1, ordinary 100 HP. Every kill, XP crystal,
upgrade, potion and heal comes through the actual game. There are no injected
kills, XP grants, health resets or special invulnerability. The unchanged
controller uses collision-respecting kiting, bullet avoidance and ordinary
emergency dashes; Comet Strider also dashes offensively. Only post-combat travel
to the center portal is skipped, after all drops and rewards resolve. Each full
campaign clears all 20 arenas and 584 enemies.

| Path / starting ability | v3 full clears | v4 full clears | v3 → v4 median total combat time |
|---|---:|---:|---:|
| Blade Dancer / Farshot | 5/5 | 5/5 | 254.87 → 258.29 s |
| Blade Dancer / Life Drain | 4/5 | 5/5 | 338.79 → 311.62 s |
| Star Ranger / Farshot | 5/5 | 5/5 | 217.83 → 208.11 s |
| Moon Weaver / Starlight | 1/1 | 1/1 | 298.21 → 304.08 s |
| Comet Strider / Comet Tail | 1/1 | 1/1 | 486.06 → 326.86 s |

Total-combat medians include only fully completed campaigns and exclude time in
reward menus and portal transitions. No campaign died in either sample. The v3
Life Drain seed-9981 timeout is retained, not counted as a death or silently
removed. That nominal seed clears all 20 arenas in v4.

### Guardian arenas: Farshot / Blade Dancer

Every row contains five successful natural-campaign clears in each version.
These times include the guardian **and the arena's other enemies**, not just
boss time-to-kill.

| Arena / guardian | v3 → v4 median clear time | v3 → v4 median minimum HP / entry HP |
|---|---:|---:|
| 5 / Thorn Warden | 21.47 → 20.76 s | 94.6% → 57.8% |
| 10 / Ember Alchemist | 14.79 → 14.13 s | 100.0% → 73.2% |
| 15 / Crystal Sentinel | 11.27 → 16.09 s | 98.1% → 100.0% |
| 20 / Night Sovereign | 13.22 → 10.22 s | 100.0% → 99.1% |

The early two guardians produced deeper HP losses for this kiting policy while
remaining clearable in every sample. The late guardian arenas are not uniformly
slower: v4's final arena clears faster in this sample. These observations do not
isolate boss strength from minions, layouts, reward choices or changed attack
behavior. All path-by-guardian counts, times and HP summaries are in the JSON.

## Healthy-entry encounters: horizontal movement only

This separate experiment tests stages 5, 10, 15 and 20 using the same arena RNG
seeds and real reward offers as v3. All **60 paired entry-stat dictionaries are
identical**. Prior stages contribute their exact XP budget; each measured arena
starts at its normal maximum HP. Thus these are conditional encounter results,
not evidence that this simple controller survived preceding stages.

Movement is left/right on y = 340, reversing at obstacles or arena edges, with
no dash, vertical pursuit, or active bullet avoidance.

| Entire 60-encounter sample | v3 | v4 |
|---|---:|---:|
| Cleared | 38 | 48 |
| Died | 8 | 1 |
| Alive at 120-second limit | 14 | 11 |

Farshot / Blade Dancer, five runs per arena:

| Arena | v3 → v4 clears / 5 | v3 → v4 deaths / 5 | v3 → v4 live timeouts / 5 | v3 → v4 median successful clear time |
|---|---:|---:|---:|---:|
| 5 | 0 → 4 | 4 → 0 | 1 → 1 | No clear → 34.76 s |
| 10 | 4 → 4 | 0 → 0 | 1 → 1 | 22.23 → 17.27 s |
| 15 | 4 → 4 | 0 → 0 | 1 → 1 | 17.68 → 22.84 s |
| 20 | 4 → 5 | 0 → 0 | 1 → 0 | 10.18 → 13.61 s |

Clear-time medians exclude deaths and timeouts; accompanying counts expose that
censoring. Other strategies' full summaries and every failed attempt are in the
JSON. A live 120-second timeout is not a death.

### Diagnosed unsuccessful encounters

A second pass added read-only snapshots to a temporary harness without changing
any gameplay script. Its 60 outcome records exactly match the authoritative
suite. The last three snapshots of all 12 uncleared encounters are retained.

- All 11 live timeouts retain ordinary enemies beyond the horizontal
  controller's attack reach or behind obstacles. The enemy AI follows direct
  movement vectors rather than finding routes around walls, and the controller
  never leaves its horizontal lane. Examples include seed 1760/stage 5's grunt
  stuck around x = 716.8 behind obstacles, and seed 7727/stage 10's archer at
  y = 487.5, beyond a 145-pixel sword's reach from y = 340.
- The single death is Star Ranger, seed 1760, stage 5. Late snapshots show two
  surviving archers outside sword reach, prolonged projectile exposure, and a
  distant wall-blocked grunt. The guardian was already defeated. The controller
  does not vertically chase or evade those shots.
- No guardian remains in any unsuccessful encounter's retained late snapshots.
  These failures still count as uncleared arenas. They are not evidence that
  every guardian is appropriately challenging for a human.

No tuning or controller changes were made to improve these results. Existing
pathfinding/controller limitations remain visible rather than being hidden by
injected damage, health or a larger time budget.

## Caps and healing preservation

The archived v3 `main.gd` matches the candidate source hash stored in the old
results. Comparison against that source verifies:

- `data.gd` is byte-identical, preserving stat ceilings, upgrade rank limits and
  diminishing returns. In particular: damage 80, sword range 145 pixels,
  attack-speed value 2.2, movement 240 pixels/s, HP 400, armor 8, regeneration
  3 HP/s, four arrows, three magic power, dash damage 120, dash cooldown floor
  1.1 s, and pickup range 240 pixels.
- Stat clamping, upgrade changes and rank-cap methods are byte-identical.
- Life Drain remains unique and nonstacking: 10% of actual damage dealt, excluding
  overkill. Level growth does not scale it; the effective cap remains 10%.
- Each herbalist still drops a 2%/4%/6% maximum-HP potion with 60%/30%/10% odds.
- Arena-clear healing is still 10% of maximum HP once per arena. Level-up healing
  is still +12 HP. Healing is bounded by maximum HP and cannot revive the dead.
- Potion generation, heal helper, clear heal, damage-to-Life-Drain conversion and
  level progression methods are byte-identical. The ordinary hurt cooldown and
  dash immunity remain, with new guards preventing damage outside live play or
  after death.

## Reproduce and interpret

From the project directory, with Godot's data/config/cache directories set to
writable paths if necessary:

```sh
# 15 natural full campaigns.
godot --headless --path . --script balance_simulation.gd -- \
  --campaign --movement=kite --modes=farshot,drain,ranger \
  --output=/tmp/v4-campaigns.json

# Two additional natural campaigns.
godot --headless --path . --script balance_simulation.gd -- \
  --campaign --movement=kite --seed=1760 --modes=mage,dash \
  --output=/tmp/v4-other-builds.json

# 60 matched healthy-entry guardian encounters.
godot --headless --path . --script balance_simulation.gd -- \
  --modes=farshot,drain,ranger --output=/tmp/v4-encounters.json
```

Test mode is set before scene initialization, so this harness does not write
profile progress. Starting abilities are selected benchmark loadouts, not a
claim about a new profile's unlock state.

The full suite used a frozen project snapshot. Tested main/combat/data/harness
hashes are recorded. Later edits were presentation-only: `_draw`, `draw_cues`
and character artwork. A source check verifies that every non-rendering
main/combat function and their preambles remain byte-identical to the tested
snapshot; the verified delivery revision hashes are also recorded. No untested
gameplay tuning is being folded into these results.

Natural campaigns are not exact paired experiments: changed combat consumes
random numbers differently, which changes later layouts and rewards even with
the same nominal seed. This small sample is a regression/viability benchmark,
not an exhaustive search, a statistical difficulty claim, or a substitute for
human playtesting of readable cues and encounter fairness.
