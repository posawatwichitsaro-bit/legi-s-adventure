# Combat balance verification

Godot 4.6.3, 10 October 2026. Raw inputs, every measured arena, chosen upgrades,
relics, HP, outcomes, summaries, and tested source hashes are in
`balance_results.json` (762 arena records). The reusable harness is
`balance_simulation.gd`. No gameplay fixture remains in `main.gd` or `data.gd`.

## Main finding

The old late-game collapse is reproducible with actual combat and attainable
progression. Five Farshot/Blade Dancer campaigns cleared all 20 arenas through
normal attacks, XP, and healing. Their median final-arena clear time was **1.69
seconds**, compared with **13.22 seconds** after the caps. All five still cleared
the complete updated game. The capped version preserves a strong build without
the former late-game near-instant arena wipe.

This is an automated balance benchmark, not a claim that human difficulty is
fully tuned or that every path/skill combination has been exhaustively tested.

## Why the old build snowballed

- Every level compounded active damage, range, movement, attack speed and other
  stats by 3%. Blade Dancer additionally gained 3.96 movement speed and 0.063
  attack-speed multiplier per level. Earned upgrades and gear compounded too.
- Farshot could repeat without a limit, adding +4 damage and +20 sword range each
  time; those bonuses also received later level growth.
- The sword damages every living enemy inside its broad approximately 197-degree
  forward arc. Its hit test has no obstacle line-of-sight check. Increasing reach
  therefore amplified crowd coverage in addition to safer engagement distance.
- Arrows and magic **do not pierce**: each projectile is removed at its first hit
  or upon hitting a wall. The observed crowd wiping was principally oversized,
  rapidly repeating sword attacks, with additional ordinary ranged damage.
- In the five real Farshot campaigns, old stage-20 sword range reached roughly
  367–434 pixels and attack-speed values reached 6.83–9.03. The candidate limits
  these to 145 pixels and 2.2, shared across level growth, skills and equipment.

## Real progression budgets

These are derived from the game's enemy counts, boss XP multiplier, crystal
values and `6 + 3 × current level` XP requirements; levels were not guessed.
All earlier-stage crystals must be collected before the portal opens.

| Arena entered | XP from preceding arenas | Entry level | Unspent XP |
|---|---:|---:|---:|
| 5 | 104 | 7 | 5 |
| 10 | 440 | 15 | 41 |
| 15 | 1,088 | 25 | 44 |
| 20 | 2,148 | 36 | 48 |

A complete run defeats 584 enemies, including the four guardians.

## Natural full campaigns

Seeds: 1760, 2026, 4511, 7727, 9981. Each begins at ordinary stage 1, level 1,
100 HP. Every enemy death, XP gain, upgrade, potion and heal occurs through the
real game. There are **no injected kills, XP grants, HP boosts/resets, or special
invulnerability** in these campaigns.

The controller uses ordinary collision-respecting movement, kiting, bullet
avoidance and the normal emergency dash. Comet Strider additionally uses normal
offensive dashes. After all combat and drops finish, portal travel is skipped;
the actual portal transition, reward flow and next stage start still execute.

Farshot Charm starting ability + Blade Dancer, five complete campaigns per version:

| Guardian arena | Old median clear time | Capped median clear time |
|---|---:|---:|
| 5 | 20.30 s | 21.47 s |
| 10 | 10.49 s | 14.79 s |
| 15 | 3.53 s | 11.27 s |
| 20 | 1.69 s | 13.22 s |

Other campaigns:

| Path / starting ability | Old complete runs | Capped complete runs | Old → capped final-arena median |
|---|---:|---:|---:|
| Star Ranger / Farshot Charm | 5/5 | 5/5 | 1.68 → 12.44 s |
| Blade Dancer / Life Drain | 4/5 | 4/5 | 2.48 → 13.22 s |
| Moon Weaver / Starlight | 1/1 | 1/1 | 4.12 → 14.79 s |
| Comet Strider / Comet Tail | 1/1 | 1/1 | 4.98 → 13.62 s |

Mage and dash use seed 1760 only and ability-focused reward priorities. The
Life Drain seed 9981 run times out alive at stage 1 in **both** versions because
the controller fails to reach the last enemy. No campaign in this 17-run sample
per version died. That demonstrates viability under this controller, not a
measured human win rate. The same nominal seeds do not ensure identical natural
campaign layouts/rewards because combat history and the reward RNG changed.

## Matched healthy-entry encounters: simple left/right movement

This second experiment isolates guardian arenas using the same arena layouts
and enemy placements across versions. The preceding stages supply only their
exact XP totals and real three-option reward offers; the encounter then starts
at its ordinary maximum HP. **These are conditional healthy-entry encounter
results, not survival claims for the preceding stages.** During measured combat,
there are no injected deaths, health alterations or invulnerability.

Arena RNG seed: `100000 + run seed × 100 + stage`. Movement only goes left/right,
reversing at edges or obstacles. It does not dash, steer around bullets or chase
unreachable enemies. Combat is simulated at 120 Hz with a 120-second budget.

Farshot Charm + Blade Dancer, five seeds per arena:

| Arena | Old clears / 5 | Capped clears / 5 | Old → capped median clear time | Old → capped median minimum HP |
|---|---:|---:|---:|---:|
| 5 | 1 | 0 | 18.87 s → no clear | 0.0% → 0.0% |
| 10 | 5 | 4 | 9.57 → 22.23 s | 72.4% → 50.0% |
| 15 | 5 | 4 | 4.47 → 17.68 s | 91.8% → 84.9% |
| 20 | 5 | 4 | 2.25 → 10.18 s | 100.0% → 80.5% |

At capped stages 10/15/20, the uncleared fifth run remained alive at the time
limit; it is a controller/pathing timeout, not a death. At stage 5, old results
were one clear, three deaths and one live timeout; capped results were four
deaths and one live timeout. Early-game simple horizontal control was already
weak. Different upgrade offers and a tiny sample prevent attributing these
stage-5 differences solely to the caps. The full kiting campaigns above provide
stronger evidence that early progression remains viable.

Clear-time medians include **only successful clears**; the accompanying counts
make this censoring explicit. Minimum HP is the lowest absolute HP divided by
entry HP, including zero for death. Level-ups may raise maximum HP during an
arena, so 100% does not itself prove that no damage was taken.

Reward choices always come from the actual three offered buttons. The policy
favors Farshot, range, damage and attack speed, avoiding completely ineffective
choices when a useful alternative exists. This is a feasible strong policy,
not an exhaustive search over every possible future offer. Old/new eligible
pools and RNG differ, so only terrain/initial enemy placement is exactly paired.

## Reproduce the candidate

From the project directory:

```sh
# Five seeds; matched-entry arenas 5, 10, 15 and 20; no dash.
godot --headless --path . --script balance_simulation.gd -- \
  --modes=farshot,drain,ranger --output=/tmp/encounters.json

# Natural full campaigns with ordinary kiting/dashing.
godot --headless --path . --script balance_simulation.gd -- \
  --campaign --movement=kite --modes=farshot,drain,ranger \
  --output=/tmp/campaigns.json

# Representative remaining paths, one seed each.
godot --headless --path . --script balance_simulation.gd -- \
  --campaign --movement=kite --seed=1760 --modes=mage,dash \
  --output=/tmp/other-builds.json
```

Set `XDG_DATA_HOME`, `XDG_CONFIG_HOME` and `XDG_CACHE_HOME` to writable temporary
directories if the environment restricts Godot's usual user-data locations. The
harness sets test mode before scene initialization, so it does not write profile
progress. Starting abilities are deliberately selected as already-discovered
benchmark loadouts. `balance_results.json` also retains the pre-change measured
results and source hashes; the old gameplay implementation is not shipped as a
second playable version.
