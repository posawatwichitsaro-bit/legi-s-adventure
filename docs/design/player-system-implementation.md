# Player-system redesign — local implementation and validation

Date: 2026-10-10. Baseline: `C:\godot\legis-adventure`, backed up to
`C:\godot\backups\player-redesign-20261010` before runtime changes.
The player confirmed the consolidated design and authorized GitHub PR delivery.
The separate Git checkout receives the same
implementation files at `C:\godot\legi-s-adventure-upload`.

## Delivered behavior

The four Classes now select a weapon or primary element before starting, with
all thirteen options immediately available. Starting Skill unlocks no longer
affect gameplay. Existing settings, cosmetics and Equipment Journal entries
remain in the profile; profile schema is version 8.

| Class | Starting HP / shield | Options | Growth per level |
|---|---|---|---|
| Fighter | 130 / 0 | Knife, sword, axe | HP +2.4, attack +0.65, Block +0.4 percentage points, attack speed +0.008 |
| Ranger | 90 / 0 | Bow, crossbow, gun | HP +1.15, attack +0.6, speed +0.35, attack speed +0.012 |
| Wizard | 55 / 20 | Fire, Ice, Lightning, Light | HP +0.8, attack +0.85, Mage Armor +0.45, pickup +0.7 |
| Rogue | 85 / 0 | Dagger, sword, throwing knives | HP +1.1, attack +0.55, speed +0.4, Critical Rate +0.35 percentage points, Critical Damage +0.9 percentage points, Dodge +0.4 percentage points, Dash cooldown −0.016s |

Growth replaces blanket three-percent increases. Ordinary caps still apply.
Wizard's initial HP plus shield is the lowest of the four Classes. Ranger's map
trap charge and Rogue's damaging Dash remain distinct Class behaviors.

### Progression and combat

- **Tactics:** 37 shared stat/behavior entries and 13 Class-filtered option
  switches. Every five levels offers up to three eligible choices. Most shared
  entries have several ranks; switching entries exclude the equipped option.
  Every starting option has at least thirty eligible entries. A truly exhausted
  pool grants maximum HP +10 and attack +1, allowing only these basic numeric
  stats to exceed ordinary caps.
- **Skills:** 70 distinct Class-specific steps. Boss rewards offer up to three
  unlearned, compatible, prerequisite-satisfied choices. Five selections maximum
  per run. Higher steps require and replace the earlier effect, consuming another
  selection. Incompatible learned Skills remain dormant after an option switch
  and reactivate on return. Skill selection precedes the separate Equipment panel.
- **Equipment:** all six bosses still offer three randomized items, choose one.
  The existing two-stat, stacking reward model is retained, including the journal.
  New chance, cooldown and shield stats enter the reward pool.
- **Fighter:** knife stabs quickly, sword uses its existing swing, axe swings
  wider and slower. Extra Attack I makes two sequential full-damage swings in one
  cycle; II makes three. Other Skills add reach, stagger, shockwaves or Block responses.
- **Ranger:** bow emphasizes fire rate, crossbow pierces two targets initially,
  gun trades speed for damage. Skills add piercing, volleys, pinning, ricochets,
  explosive gun hits and trap protection. Removed auxiliary weapons do not fire.
- **Wizard:** Fire burns; Ice slows; Lightning jumps sequentially to nearby
  unvisited enemies; Light flies straight and pierces. Fire/Ice/Lightning bolts
  steer at a bounded rate, with a short straight interval for fan shots. Each
  secondary direct chain hit rolls Critical independently using ordinary power.
  Skill effects include fans, radial volleys, familiar, shield and elemental depth.
- **Rogue:** dagger and throwing knives keep direct damage and can add poison
  and bleed together. Each DOT has its own three-stack limit at step I or five
  at II. Reapplication refreshes duration without resetting tick cadence. Skills
  also affect Dash, precision, flurries and knife fans. Sword has a broader swing.

### Critical, Dodge, Block and Mage Armor

All Classes start with Critical Rate, Dodge Rate and Block Rate 5%, and Critical
Damage **+50%**, producing 150% ordinary damage on a critical hit. Direct hits roll
separately per target; DOT cannot crit. Life Drain heals only from actual direct
HP removed, capped to enemy remaining HP, rather than overkill or DOT.

Eligible incoming melee/projectile hits resolve **Dodge → Block → Armor → Mage
Armor → HP** after existing Dash/hurt immunity. Successful Dodge prevents the
whole hit and starts recovery; failed rolls do not start recovery. Starting
recovery is Fighter/Ranger 3s, Wizard 4s, Rogue 2s. Minimum is 2s, or Rogue 1s.
Dodge Rate caps at 70%. Block halves eligible damage, caps at 90%, has no cooldown,
and can succeed during Dodge recovery. Map traps, ground hazards and DOT bypass
the probability rolls. Ground-fire classification is checked through the actual
boss attack path as well as direct damage fixtures.

Mage Armor restores a base 5/s after four seconds without an accepted hit.
Tactics, Equipment and Ward Skills can improve shield capacity/recovery. Ordinary
Armor remains flat reduction with minimum damage one before shield absorption.

### Stages, bosses and local checkpoint

Stages now run through **30**, with bosses at 5/10/15/20/25/30. Enemy and environment
pressure continue growing past the former stage-20 ceiling. Endless play remains
future work, as agreed.

**Tempest Colossus (25)** is a new storm giant with animated armored limbs,
lightning lanes, thunder-crown safe center, sweeping strikes and stronger volleys.
**Eclipse Seraph (30)** is a new winged light/shadow boss with paired beams,
annular attacks, surrounding seals and second-phase escalation. Their drawing and
attack sets are new. Preview and collision use the same authoritative geometry.

Auto save writes one local checkpoint after enemies, drops, XP and all earned
Tactic/Skill/Equipment choices are resolved. Continue starts the next stage with
saved build, HP, level/XP, Equipment, counters and RNG state, with normal stage-entry
resource replenishment. Defeat can reload the last checkpoint. Starting a new
run replaces the checkpoint after its first clear. Finishing stage 30 removes it.
ESC pauses; there is no manual or mid-fight save.

Checkpoint files use temporary-write/flush/rename. RNG seed/state are decimal
strings to preserve 64-bit values through JSON. Invalid versions, Classes,
options, stats, Skill prerequisites/counts and catalog IDs are rejected. This is
a simple local checkpoint, with the requested replay loopholes allowed.

## Modules and evidence

| File | Responsibility |
|---|---|
| `data.gd` | Classes, starting options, stat bounds, Tactics, Skill catalog, stage limit |
| `player_skills.gd` | Eligibility, prerequisites, compatible active tiers, learning and reward panel |
| `player_effects.gd` | Bounded DOT, slow, secondary elemental/weapon hits, shockwaves |
| `run_checkpoint.gd` | Checkpoint validation, file IO, deterministic restoration and completion |
| `class_progression.gd` / `class_combat.gd` | Class resources, weapon specifications, spells and active Skill effects |
| `main.gd` | Menu/HUD, damage resolution, leveling, reward flow, pause and autosave integration |
| `combat.gd` / `character_art.gd` / `world.gd` | Boss behavior, new art, telegraphs and environmental damage categories |
| `CONTEXT.md` | Current progression vocabulary |

### Automated acceptance

Verified with local **Godot 4.7.2**, headless for logic and native Compatibility
OpenGL on NVIDIA RTX 5060 Laptop GPU for screenshots.

| Suite | Passed | Failed |
|---|---:|---:|
| `redesign_tests.gd` | 383 | 0 |
| `combat_tests.gd` | 94 | 0 |
| `pattern_tests.gd` | 277 | 0 |
| `healing_tests.gd` | 71 | 0 |
| `regression_tests.gd` | 23 | 0 |
| **Total assertions** | **848** | **0** |

The normal-scene `-- --self-test` also reports PASS. Regression includes
**3,000 seeded arenas**, with zero unsafe spawns and zero unreachable arenas.
Four-Class reward-flow fixtures reach level 71 / XP 172 / 1,479 kills, fourteen
Tactics, five Skills and six Equipment rewards over thirty stages. These fixtures
set enemy HP to zero to isolate progression; they do **not** establish a combat win.

Redesign acceptance exercises all thirteen options, Class-filtered offers,
chance/cooldown bounds, damage order, independent Critical versus DOT, stack
expiration, tier prerequisites/replacement, dormant reactivation, exhaustion,
actual choice-button callbacks, boss-six reward flow, checkpoint overwrite,
restoration, exact next-map RNG and malformed saves. Combat/pattern suites check
attack windows, immunity, cancellation, honest telegraphs, safe pockets and expiry.
Healing tests cover profile migration without legacy Starting Skill gameplay effects.

Example reproducible commands (redirect APPDATA to isolate test saves):

```powershell
$env:APPDATA = 'C:\godot\test-userdata\recheck'
& 'C:\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'C:\godot\legis-adventure' --script res://redesign_tests.gd
& 'C:\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'C:\godot\legis-adventure' --script res://regression_tests.gd
& 'C:\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'C:\godot\legis-adventure' -- --self-test
```

Native `redesign_visual_qa.gd` captures twelve screens in `screenshots/redesign/`:
menu, Classes, all four Starting Option panels, Tactic, Skill, Equipment, both new
boss arenas and Pause. Captures inspected include menus/reward panels, both new
bosses and Pause; the inspected panels have no visible clipping. Boss screenshots
are staged visual fixtures, separate from combat measurements.

### Combat balance observations

The automated controller uses real physical-key input at 12 Hz, collision movement,
ordinary attacks, emergency Dash and actual offered rewards. Simulation runs at
120 Hz, with a 240-second per-stage observation limit. It has precise knowledge
of displayed attack geometry but approximate pathing/avoidance. This sample does
not establish human win rates or guarantee every build can clear.

**Current natural campaign:** `redesign-final-campaign.json`, seed 1760, Wizard
starting Fire and prioritizing survival Tactics, cleared all thirty stages with
**1,479 actual kills**, 2,671 seconds of simulated combat/stage time and **218.9 HP**
at completion. It earned all rewards normally, with no health resets or injected
kills. Its five Skills were Spell Fan I, Mage Ward I, Familiar I, Mage Ward II and
Spell Fan II. Automatic portal entry occurs only after combat and rewards.

**Healthy-entry late encounters** restore HP to maximum before measurement and
provide exact prior-stage XP plus legal random rewards. They test the late arena,
not prior-stage survival:

| Build / artifact | Stage 25 | Stage 30 |
|---|---|---|
| Fighter sword / `redesign-late-final.json` | Clear, 73.0s | Clear, 80.6s |
| Ranger bow / same | Clear, 164.9s | Clear, 137.0s |
| Rogue dagger / same | Clear, 92.6s | Clear, 100.4s |
| Wizard Fire, defensive / `redesign-wizard-defensive-final.json` | Clear, 123.7s | Clear, 147.5s |
| Wizard Lightning, defensive / same | Death, 127.5s, four enemies remained | Clear, 127.5s |

The first artifact preceded the final sequential Lightning-chain fix; the three
non-Wizard samples use unchanged relevant combat mechanics. Fire/Lightning rows
in the defensive artifact use the corrected chain and survival policy. Both use
seed 1760. Wizard Lightning remains vulnerable in the stage-25 sample; shield/HP
choices materially affect survival. This limitation is retained rather than
treating every reward-flow clear as a fight won.

Earlier `redesign-campaigns.json`, `redesign-late-encounters.json`,
`redesign-wizard-campaign.json` and `redesign-wizard-late-final.json` are tuning
iterations, with earlier runtime/policy behavior. They remain in the original
working folder but are not final acceptance evidence. Old v4–v7 tests/results
also describe the retired system and were not rewritten as redesign successes.

## Delivery limits

This is an editable Godot project with source and validation evidence prepared
for GitHub PR delivery. No executable export was requested for this step.
Manual human campaign playthrough, audio perception, broad multi-seed win rates
and long-term endless-mode balance are not verified. Equipment keeps its agreed
current reward model; equipment slots and a later reward redesign are outside
this iteration. The detailed agreement is in `player-system-redesign.md`.
