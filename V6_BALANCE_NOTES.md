# V6 maps and waves: balance verification

Measured with Godot 4.6.3 on 2026-10-10. Raw observations, method and source hashes are in `balance_results_v6.json`.

## Main result

- Natural 20-stage campaign clears: **v5 18/20 → v6 20/20**. Deaths: 1 → 0; live 240-second stage timeouts: 1 → 0.
- Median successful arena combat time: **22.1 → 39.8 seconds**. This includes group delays but excludes menus, reward choices and post-combat portal travel.
- Across 110 matched stage-15–20 observations, median actual damage: **32.3 → 49.7 HP**. Median paired damage change: 18.2 HP.
- Median total combat time among complete campaigns: 8.1 → 13.8 minutes. This is automated combat time, not an estimate of human playtime.
- The larger maps and successive groups remain winnable in this seeded automated sample. More enemies, more travel and environmental eruptions alter pacing; these results do not guarantee a human win rate or equal difficulty for all builds.

## What changed

- Arena: 896 × 456 → 1,344 × 684 world pixels, **2.25× playable area**. The 960 × 600 logical canvas and 896 × 456 world view remain unchanged; a clamped camera follows the player.
- Complete stage population: `ceil((8 + 2 × stage + guardian) × 1.25)`, where guardian is 1 on every fifth stage and 0 otherwise. Rounding happens once per stage. The full campaign has **736 enemies instead of 584** (+26.0% after rounding), including the same four guardians and one herbalist per stage.
- Group sizes by five-stage tier: 4 / 5 / 6 / 7. Active-enemy caps: 6 / 8 / 10 / 12. The first group appears immediately; later groups require a three-second interval and enough capacity for the full next group. Guardians occur in the last group.
- The remaining counter and clear gate include the queued roster. A gap between groups cannot grant the clear heal, relic, global pickup attraction or portal.
- Environmental eruptions warn for 1.4 seconds, damage for one second, recover for 0.7 seconds, and accept at most one contact. They use ordinary armor, dash immunity and hurt immunity. Placement protects the central refuge, walls, arena edges and the player’s initial position.
- Additional kills award ordinary XP. The unchanged progression rules now reach level 43 / 82 XP in the isolated full-roster lifecycle regression, rather than v5’s level 38 / 117 XP. Caps and reward rules remain unchanged.

## Matched method and safeguards

- Five fixed seeds: 1760, 2026, 4511, 7727, 9981. Four actual classes per seed: sword/Farshot, ranger/Farshot, staff/Starlight, daggers/Comet Tail. There are 20 natural campaigns per release.
- The v5 source was frozen before gameplay edits. Both releases run the byte-identical `balance_simulation_v6.gd` and read-only `balance_probe.gd` instruments. The v6 seed-1760 four-class repeat matched all 80 original stage rows exactly after the final rendering/input-only corrections. Those changes do not alter the keyboard benchmark’s numerical combat rules.
- Combat uses real attacks, enemy behaviors, deaths, drops, healing, random offered upgrades and relics, with health carried between stages. No injected kills, inflated health, immunity, enemy relocation or forced boss attacks are used in these trials.
- Movement uses normal physical-key input through the real game loop. The controller chooses among eight directions at 12 Hz, routes around obstacles using an arena-sized AStar grid, responds to committed enemy/environmental cues and bullets, and uses the ordinary dash action. The dagger policy also dashes offensively.
- Simulation is 120 Hz. The fixed **240-second per-stage** observation limit is shared by both releases and includes group downtime. A live timeout is reported separately from death. This differs from the 120-second historical v5 report; do not mix those old results with this comparison.
- Only post-combat portal travel is shortened, after the full roster and drops/rewards resolve. Starting abilities are normal equipped options after discovery; this sample assumes they have been unlocked, rather than modeling a first-ever profile.
- Seeds are matched; maps, RNG consumption, offers and XP totals differ by design. Consequently, this is a comparison of full release progression, not fixed geometry or equal-level damage.
- Actual damage is the sum of HP removed by accepted `damage_player` calls, after armor/immunity and capped at remaining HP on a lethal hit. Healing does not subtract from damage totals, so accumulated damage can exceed entry HP.
- All raw rows passed complete enemy accounting (`kills + remaining = starting roster`), queue accounting, expected population, and active-cap checks. Every authoritative log has zero script/resource errors.

## Campaigns by class

| Class policy | Full clears v5 → v6 | Deaths v5 → v6 | Live timeouts v5 → v6 | Median late damage HP v5 → v6 | Median successful late clear seconds v5 → v6 |
|---|---:|---:|---:|---:|---:|
| Sword / Farshot | 5/5 → 5/5 | 0 → 0 | 0 → 0 | 21.7 → 58.1 | 22.3 → 50.8 |
| Ranger / bow | 5/5 → 5/5 | 0 → 0 | 0 → 0 | 32.1 → 38.6 | 26.3 → 43.3 |
| Weaver / staff | 3/5 → 5/5 | 1 → 0 | 1 → 0 | 74.9 → 75.5 | 57.3 → 77.7 |
| Strider / daggers + dash | 5/5 → 5/5 | 0 → 0 | 0 → 0 | 24.3 → 50.9 | 15.5 → 48.6 |

Late statistics include only runs that reached stages 15–20; successful clear-time medians exclude deaths and timeouts. They are not a matched difficulty ranking between classes.

## Stage-by-stage late observations

| Stage | Observed v5 / v6 | Clears v5 / v6 | Median damage HP v5 → v6 | Median successful clear seconds v5 → v6 |
|---|---:|---:|---:|---:|
| 15 | 19 / 20 | 19 / 20 | 43.6 → 60.6 | 23.7 → 47.8 |
| 16 | 19 / 20 | 18 / 20 | 25.6 → 39.6 | 20.4 → 49.2 |
| 17 | 18 / 20 | 18 / 20 | 25.5 → 59.1 | 24.4 → 45.9 |
| 18 | 18 / 20 | 18 / 20 | 15.5 → 32.5 | 26.0 → 48.7 |
| 19 | 18 / 20 | 18 / 20 | 28.5 → 60.8 | 27.8 → 52.6 |
| 20 | 18 / 20 | 18 / 20 | 55.2 → 103.6 | 27.0 → 67.5 |

## Non-clear outcomes

### v5: 2 non-clears

| Seed | Class policy | Stage | Outcome | Observed seconds | HP left | Active / queued foes |
|---|---|---:|---|---:|---:|---:|
| 4511 | Weaver / staff | 16 | died | 33.8 | 0.0 | 23 / 0 |
| 7727 | Weaver / staff | 8 | timeout | 240.0 | 146.9 | 3 / 0 |

All non-clears remain in the raw data. A live timeout can reflect the approximate navigation or combat policy and is not evidence that the level is impossible.

### v6: 0 non-clears

None.

## Naturally observed environmental hazards

Across v6 campaigns: 6491 unique eruptions observed, 6294 releases, 25 contacts. Contacts include contacts prevented by immunity and are not a separate count of accepted damage hits. A wave ending or death can remove a warned eruption before release.

| Theme stages | Eruptions observed | Released | Contacts, including immune contacts |
|---|---:|---:|---:|
| 1–5 | 544 | 523 | 1 |
| 6–10 | 887 | 855 | 1 |
| 11–15 | 2296 | 2216 | 11 |
| 16–20 | 2764 | 2700 | 12 |

## Focused regressions

`v6_tests.gd`: **208 assertions passed**, with zero script errors. Coverage:

- Every stage’s rounded full roster, HUD count, tier group size/cap, group count, one herbalist, exact queue consumption, guardian ordering and total 736-kill population.
- Capacity, release delay, kill accounting, wave pause in all non-playing states, zero-HP protection, new-run reset, and full-roster/drop gates for healing, rewards and portals.
- 2.25× arena area, unchanged viewport, camera round-trip/clamps, scrolled aim conversion, real ranged-aim direction, pickup attraction/collection and collision in world units.
- Exact configuration-space connectivity for 200 seeded maps and safe clearances for all 7,360 queued spawns, including the center portal approach and twenty distinct layouts.
- Environmental warning duration, locked shape, one contact, recovery/removal, armor, dash/hurt immunity, safe outside geometry, modal/pause clocks, inter-group/clear/portal/death cleanup, entry grace, all-theme placement constraints and active-hazard caps.

These regressions deliberately inject state/deaths to isolate branches. They are separate from the real-combat campaigns above. The inherited suites and rendering inspection are documented in the README.

## Limits

- The fixed five-seed sample is small. It demonstrates reproducible automated wins and exposes observed deaths/timeouts; it is not a human win-rate estimate.
- The controller has exact knowledge of committed attack geometry, including cues outside the current camera view. Its reactions and greedy upgrade choices differ from human play.
- Navigation is approximate. A map being connected does not guarantee that this lightweight enemy steering/controller finds an efficient route in every situation.
- The final per-stage time limit is an observation boundary, not a game timer. A timeout ends that measured campaign without assuming the player died.
- No gameplay tuning was made in response to the authoritative sample. A complete human twenty-stage playthrough and audio playback are not claimed by this benchmark.

## Reproduce

Use the corresponding v5 or v6 source project. Copy this release’s `balance_simulation_v6.gd` and `balance_probe.gd` unchanged into both. Import assets first. Use writable HOME/XDG directories in restricted Linux environments.

```sh
godot --headless --editor --path PROJECT --import --quit
godot --headless --path PROJECT --script balance_simulation_v6.gd -- \
  --campaign --movement=kite --modes=farshot,ranger,mage,dash \
  --output=campaigns.json
godot --headless --path PROJECT --script v6_tests.gd
```

The default benchmark runs the five listed seeds; add `--seed=1760` for one seed. Run `v6_tests.gd` only in v6. Saved profiles are disabled. The earlier independent healthy-entry helper remains available but was not used for this report.

## Source SHA-256

| File | Frozen v5 | Final v6 |
|---|---|---|
| `main.gd` | `8e63561566b1def6cdc1d7dded1205cc976acde798ff72ef4658b6c977dadaed` | `801f530afc3c67bbd0a59852be91c135ecbef161359d2817daf3e84b84f1e3df` |
| `data.gd` | `6d34d3545d2303ba60370395876d8d394aadeb635e2566b85ed928a9a779792a` | `6d34d3545d2303ba60370395876d8d394aadeb635e2566b85ed928a9a779792a` |
| `combat.gd` | `137b10d7be4bfcd9869b384dc1504c21016b29b0f73c6b152f806004d6c80011` | `137b10d7be4bfcd9869b384dc1504c21016b29b0f73c6b152f806004d6c80011` |
| `world.gd` | `not present` | `7f2039bcb9ffc5031666bc0f8d9bd08818d433a91a9940c1bdc98281818b7e3b` |
| `character_art.gd` | `6f9961fe8f4f6ae9bf6ab7de389ed4389bfdcb839fcce0f2faedc4d0cbb6dfef` | `6f9961fe8f4f6ae9bf6ab7de389ed4389bfdcb839fcce0f2faedc4d0cbb6dfef` |
| `project.godot` | `835bec1af6eacab47abc1cd3f521fcfd3bd5f12b465fc81904138ee18831eb4d` | `835bec1af6eacab47abc1cd3f521fcfd3bd5f12b465fc81904138ee18831eb4d` |
| `balance_simulation_v6.gd` | `4adc696562704228b4de3eb0c5b011afa2aa3cafc2ab5ec904627df3c0b9bdda` | `4adc696562704228b4de3eb0c5b011afa2aa3cafc2ab5ec904627df3c0b9bdda` |
| `balance_probe.gd` | `52930c8fb6a95be3882685cab9130f6d4aa47de5a9719b855a9b53eae2eaedf7` | `52930c8fb6a95be3882685cab9130f6d4aa47de5a9719b855a9b53eae2eaedf7` |
