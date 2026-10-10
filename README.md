# Legi's Adventure — player-system redesign

An original pixel-art Godot survivors roguelike. This editable project is tested
with the local **Godot 4.7.2** executable and the Compatibility renderer.
Current scope is **30 stages and six bosses**; endless progression remains future work.
Source, screenshots and validation evidence accompany the player-system redesign.

## Play

Open `project.godot` in Godot and press F5, or run:

```powershell
& 'C:\godot\Godot_v4.7.2-stable_win64_console.exe' --path 'C:\godot\legis-adventure'
```

Choose Class and Starting Option before START ADVENTURE. Every starting option
is available immediately. Attacks automatically aim at the nearest living target.
Use WASD/arrows or hold left mouse to move, Space/right mouse to dash, and ESC
to pause/resume. Physical shots and Light spells can pierce according to their
weapon/Skills; walls stop projectiles.

## Classes

| Class | Initial HP | Starting options | Identity |
|---|---:|---|---|
| Fighter | 130 | Knife, sword, axe | Melee, high HP, Block. Knife stabs quickly; axe swings wider and slower. |
| Ranger | 90 | Bow, crossbow, gun | Fast single-target shots and recharging map-trap protection. Crossbow starts with two-target piercing. |
| Wizard | 55 + 20 Mage Armor | Fire, Ice, Lightning, Light | Burn, slow, chain hits or piercing. One primary element; lowest starting HP plus shield. |
| Rogue | 85 | Dagger, sword, throwing knives | Speed, frequent Dash, Critical and Dodge. Knife Skills add bounded bleed/poison alongside direct damage. |

Mage Armor recharges at a base 5/s after four seconds without an accepted hit.
Ranger begins with one map-trap charge and twelve-second serial recharge.
Rogue retains damaging Dash; Skills can add capacity/duration/push or improve recharge.
Level growth is explicit for each Class, replacing the old blanket three-percent growth.
Damage, attack speed and effect durations are tuning values, not permanent balance guarantees.

## Progression

- **Tactic:** every five levels, choose one of up to three shuffled eligible offers.
  There are 37 shared Tactics plus 13 Class-filtered weapon/element switch entries.
  Shared Tactics improve attributes or behaviors and do not add another Class's weapons.
  A genuinely exhausted pool grants +10 maximum HP and +1 attack, exceeding ordinary
  numeric caps without increasing chance stats or reducing cooldowns.
- **Skill:** choose one of up to three eligible Class-specific offers after boss arenas.
  At most **five choices per run**. Seventy distinct Skill steps include prerequisites:
  Extra Attack II requires I, replaces its effect and consumes another choice.
  Learned Skills are never offered again. A weapon/element switch retains incompatible
  Skills as dormant until a compatible option is equipped again.
- **Equipment:** after every boss arena, choose one of three randomized items,
  independently of Skill. Two stat bonuses stack for the run. The sixth boss still
  awards Equipment. Existing name discoveries remain in the Equipment Journal;
  removable equipment slots are outside this iteration.
- **Starting Option:** replaces the permanent Starting Skill mechanism. Old saved
  ability selections do not grant gameplay Skills. Settings, cosmetics and valid
  Equipment journal entries are preserved.

Fighter Extra Attack I produces two normal-damage swings with a short gap in one
attack cycle. Wizard Spell Fan splits an increased total volley across its bolts.
Fire/Ice/Lightning bolts steer at a bounded rate; fan bolts initially fly straight.
Light travels straight and pierces. Rogue poison/bleed refresh duration and maintain
their own stack counts: three at step I, five at step II. Both can coexist, expire
normally and do not critically hit.

## Critical and defense

Every Class starts with Critical Rate, Dodge Rate and Block Rate **5%**.
Critical Damage starts at **+50%**, so a critical hit deals **150%** ordinary damage.
Each direct target hit has an independent roll, including secondary chain hits.
DOT ticks cannot crit in this version. Life Drain heals from actual direct damage,
capped to remaining enemy HP.

Dodge completely prevents eligible damage and is capped at **70%**. Only success
starts recovery: Fighter/Ranger start at 3s, Wizard 4s, Rogue 2s. The lower bound
is 2s except Rogue at 1s. Block has no recovery and halves eligible damage,
capped at **90%**; it remains available during Dodge recovery.

Resolution is **Dodge → Block → ordinary Armor → Mage Armor → HP**.
Existing Dash and hurt immunity are checked before this path. Map traps, ground
hazards, burn/poison/bleed bypass the two probability rolls. Melee attacks and
projectiles, including piercing hostile beams, qualify.

## Auto save / Continue

The game writes one local checkpoint after a stage is cleared and all XP,
potions and Tactic/Skill/Equipment selections are settled. The menu offers
**CONTINUE CHECKPOINT** when a valid unfinished checkpoint exists.

Continue starts the **following stage** with saved Class/option, stats, HP,
XP/level, learned Skills, Tactic ranks, Equipment and RNG state. Normal stage-entry
resource replenishment applies. It does not restore a mid-fight snapshot.
Defeat may reload the last completed-stage checkpoint: replay loopholes are
intentionally allowed. A new run replaces it after clearing a stage; stage 30
finishes the adventure and removes the unfinished checkpoint.

Files live in Godot's local `user://` directory:
`legis_adventure.json` (profile) and `legis_adventure_checkpoint.json` (run).
ESC pauses; there is no manual-save button. Writes use a temporary file then rename;
malformed or incompatible checkpoint data is rejected.

## Bosses and difficulty

Bosses appear at stages 5/10/15/20/25/30. The original four retain their telegraphs.

- **Tempest Colossus, stage 25:** a new giant storm actor, triple lightning lanes,
  thunder crown with a safe center, broad sweeping strikes and second-phase volleys.
- **Eclipse Seraph, stage 30:** a new winged light/shadow actor, paired piercing beams,
  annular attacks, four surrounding seals and a stronger second phase.

Each marked hit region shares geometry with authoritative hit detection. Enemy
health/count/damage/movement and environmental pressure continue increasing past
the former stage-20 ceiling. The temporary victory remains stage 30.

## Current validation

Current acceptance: **848 assertions passed**, normal-scene self-test passed,
and **3,000 seeded arenas** had safe, reachable enemy spawns. One automated natural
Wizard Fire campaign cleared all thirty stages; this is not a human win-rate estimate.

Run from the project directory with Godot `--headless --path . --script res://NAME`:

| Suite | Purpose |
|---|---|
| `redesign_tests.gd` | All starting options, chance/cooldown caps, Skill prerequisites/dormancy, DOT, reward UI callbacks, checkpoint file IO/RNG and new bosses. |
| `combat_tests.gd` | Deterministic attack windows, immunity, interruption and primary releases. |
| `pattern_tests.gd` | Old/new boss telegraphs, safe pockets, exact shape unions and stale/expired attacks. |
| `healing_tests.gd` | Potion/clear healing, actual-damage Life Drain, callbacks and profile migration. |
| `regression_tests.gd` | Four-Class 30-stage reward-flow fixtures and 3,000 seeded spawn/reachability arenas. |
| `-- --self-test` | Quick normal-scene smoke checks. |

The reward-flow fixture sets enemy HP to zero to isolate progression. It is **not**
a natural-combat victory. `balance_simulation_redesign.gd` separately exercises
real physical-key movement, real attacks and actual offered rewards, with no health
or damage injection during measured combat. Full campaigns and healthy-entry
encounters are labeled separately. Automated samples do not establish human win rates.

Native screenshots are in `screenshots/redesign/`. See
[implementation report](docs/design/player-system-implementation.md) for results
and limitations, and [design agreement](docs/design/player-system-redesign.md).

The old v4–v7 branch-specific tests, simulators, JSON and balance notes are historical
artifacts for the previous system. Their removed Starting Skill/auxiliary-weapon
assumptions are not the current acceptance suite; their old results were not rerun
or rewritten as current redesign results.
