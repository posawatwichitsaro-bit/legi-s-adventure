# v5: weapons, enemy roles and guardian expansion

Godot 4.6.3, 10 October 2026. This is an editable source release. The normal
menu and 20-stage campaign remain the default; inspection scenes and
controllers run only when explicitly selected.

## Equipped primary weapons
The BUILD selection now sets the actual primary attack at level 1. It is no
longer only a growth preference over an always-present sword.

| Primary | Start-to-start timer / attack-speed | Windup / active / recovery | Damage | Reach or projectile |
|---|---|---|---|---|
| Sword | 0.85 s | .12 / .12 / .12 s | 1 × damage stat | Range stat; forward wide cone |
| Daggers | 0.62 s | .08 / .10 / .10 s | .82 × damage stat | .78 × range; narrower cone |
| Bow | 0.85 s | .20 s draw, .18 s release pose | .9 × damage per arrow | 340 px/s base; 2.5 s lifetime; 1–4 arrows |
| Moon staff | 0.95 s | .28 s channel, .22 s release pose | damage × [1.1 + .2 × (magic − 1)] | One aimed 260 px/s base bolt; 2.5 s lifetime |

Timers and phase completion both gate repeated melee attacks. Ranged attacks
can begin a new draw/channel after their cooldown expires and the previous
windup ends; their release pose does not delay the next attack. Simulation
quantizes phase transitions to its bounded substeps. Melee damage occurs only during the
active window, once per target; projectiles appear only after draw/channel.
The shot heading locks when the draw/channel begins. Player movement can
change the release position, so spacing and line of sight still matter.

Blade Dancer starts with the sword. Star Ranger starts with one arrow and
holds only a bow. Moon Weaver starts with one magic power and holds a staff.
Comet Strider starts with daggers and 22 bonus dash damage. There is no sword
state, invisible slash or sword damage on Ranger/Weaver. The dagger has a
separate short cyan slash and dash pose. The outer slash arc follows the real
damage cone and reach.

The 80 damage limit is the shared **base stat**, not a cap on derived spell or
dash hits. All existing stat/rank limits remain. Arrows and aimed staff bolts
also gain `max(0, range − 78)` px/s, so capped speeds are 407 and 327 px/s.
Range never adds piercing or extra lifetime. Long Reach / Farshot / relic
labels describe both melee reach and aimed-shot speed.

### Hybrid builds
Split Shot unlocks a secondary bow, or adds arrows to the Ranger's primary.
Its secondary timer remains 1.4 / attack-speed seconds. Starlight/Moon Harvest
unlock eight radial sparks on non-staff classes, with the existing 2.3 /
attack-speed timer and damage × (.7 + .2 × magic). On Weaver they strengthen
the aimed staff bolt. Comet Tail adds dash damage to any class. Auxiliary
weapon feedback has independent timers; it never replaces the primary's
silhouette or hides a simultaneous release. A secondary sword is not granted.

## Ten regular roles
Original grunt / swift / archer / ghost / bomber / herbalist attacks remain.
The new roles use original articulated pixel silhouettes:

- **Sentinel** (stage 6): armored shield and spear. Frontal hits during idle or
  windup deal 55%; side/rear hits and all recovery hits deal full damage. Its
  shield bash has a locked 76 px sector. Life Drain uses damage after guard.
- **Assassin** (stage 6): low hood, twin daggers, asymmetric flank approach.
  It commits to a straight 117.8 px lunge after its warning. Move across it.
- **Chanter** (stage 11): gold mantle and staff. A visible 225 px aura grants
  allies 3 seconds of 1.16× movement/cooldown haste, then the next attack is a
  three-projectile pulse. Haste does not shorten committed windups.
- **Hexer** (stage 11): dark hood and crescent staff. Marks the player's old
  position, then activates a 49 px pool for 1 second. It hits at most once per
  cast and does not track the player after windup begins.

Later mixes retain earlier roles, with all ten possible in stages 16–20.
Counts and XP budgets are unchanged: 8 + 2×stage regulars and one boss on every
fifth stage; exactly one potion-carrying herbalist per arena.

### Bounded enemy growth
Let `p = clamp((stage − 8) / 12, 0, 1)`.
- Base movement `(45 + 1.8×stage) × (1 + .4p)`, then role/haste multipliers;
  final ordinary movement ceiling 225 px/s. Attack lunges remain separately
  committed bursts. Assassin flanking makes lateral-only movement less safe.
- Recovery cooldown multiplier `1 − .28p`, with .34 s lower bound. Haste can
  further reduce cooldown only within that bound.
- Attack/projectile damage multiplier `1 + .15p`; projectile speed multiplier
  `1 + .18p`. Sentinel/assassin melee factors are additionally 1.12 / 1.15.
- Regular windups shrink at most 8%, never below .38 s. Larger new guardian
  hazards never warn for less than .85 s. Ordinary hurt immunity stays .65 s.
- HP multiplier rises from 1 at stage 5 to 1.2 at stage 20, on top of existing
  stage growth. Role factors: archer .55, swift .7, sentinel 1.65, assassin .9,
  chanter 1.1. Others 1. Final guardian HP is 1164.

Difficulty is not based only on inflated HP: protected fronts, flank routes,
support priority, ground hazards and denser attack cadence alter decisions.
There are no forced wave delays, passive collision hits or artificial win gates.

## Two additional moves for each guardian
| Guardian | Full cycle (new moves emphasized) | New geometry |
|---|---|---|
| Warden | Cleave → **Rootline** → Charge → **Thornwheel** | Three 34 px circles down a line; annulus 58–132 px |
| Alchemist | Blast → **Cinder Cross** → **Ember Bloom** | Two crossed 19 px half-width lanes; four 40 px circles offset 68 px from locked target |
| Crystal Sentinel | Fan → **Prism Lance** → Ring → **Crystal Spokes** | Three 300 px lanes, half-width 14 px; six 210 px spokes, half-width 13 px |
| Sovereign | Cleave → **Eclipse** → Charge → **Nightfall** → Blast | Annulus 76–182 px; three 45 px seals at locked center/side positions |

Below half HP the Sovereign inserts Fan before Blast. Short moves may be
skipped when out of reach so bosses can actually threaten distant ranged
builds. This choice occurs only while idle; a marked attack never retargets.
Nightfall seals activate on beats 0 / .34 / .68 seconds and each stays active
.28 seconds; the whole cast may hit only once. Other new guardian hazards
are active .3 seconds. All eight moves are reachable in natural selection.

A shared shape representation draws the danger area and performs hit tests,
including annular safe centers and lane endcaps. Lunges cap their endpoint at
the displayed capsule; walls stop them without sideways sliding outside that
cue. Dead actors cannot start or finish pending attacks, but already-fired
projectiles remain. Simulation and hit processing stop while paused or after
game-over; resume continues frozen attacks. Stage transitions clear pending
attacks and projectiles.

## Preserved systems
Source comparison with v4 verifies byte-identical implementations of potion
generation, heal helper, once-per-clear heal, level growth, stat clamping,
upgrade caps/ranks/changes/application, and profile load/save. Relic roll
formulas are unchanged; only range wording changed. `damage_enemy` adds guard
mitigation before its existing actual-damage and Life Drain calculation.
The stat-limit table and every upgrade's cap/scaling values remain unchanged.

## Verification
**655 assertions plus the integration self-test pass:**
- Lifecycle / save / collision regression: 23 (including 2,000 seeded arenas)
- Healing: 74
- Stat / upgrade balance: 125
- Timed combat: 93
- New primary weapons: 123
- New patterns / roles / cue geometry: 217

The new tests cover exclusivity, every weapon's damage/timing/targeting,
secondary attacks, range usefulness, caps, shield mitigation and actual Life
Drain, enemy introduction/mixes, no passive damage, all new boss patterns,
full multi-cycle/rage selection, long-range selection, safe dodge locations,
windup/active transitions, one-hit guarantees, capsule boundaries and diagonal
wall stops. Existing lifecycle regressions exercise all 20 stages; their
injected kills are explicitly separate from real-combat balance campaigns.
See V5_BALANCE_NOTES.md for the latter and any controller limitations.

### Native cloud visual QA
The actual Godot 4.6.3 cloud window was inspected for:
- All four equipped-weapon silhouettes and idle/windup/release poses
- All ten regular actors' walking, windup and active poses
- All eight new guardian moves in windup and active phases, including clear
  safe ring centers, three-lane gaps and numbered Nightfall beats
- A live bow-only Ranger damaging a guardian without a sword
- A live Nightfall dodge: ordinary rightward movement escaped all three
  locked seals and retained full HP; no dash or invulnerability was used
- Normal clean menu, all BUILD descriptions, Ranger selection, stage-1
  movement, dash, pause/resume and return to menu

Screenshots labelled **SEEDED QA** are controlled inspection scenes, not
ordinary progression or evidence of a human campaign clear. The normal-menu
smoke test used a separate clean profile, restored to Blade / no starting
ability / zero records after inspection. No saves or caches ship in the ZIP.
Audio is unverified because the cloud desktop has no audio device.

Optional fixture: run `godot --path . res://visual_qa.tscn`.
Keys 1–4 choose guardians; G shows all regular actors; H shows weapon poses;
Q cycles the actual player's build; B advances boss move; T/Y/U/I/W select
windup/active/recovery/idle/walk; P sets the Sovereign's low-HP phase; F toggles
live simulation. It never writes profile data and is not the default scene.

Enemy navigation is intentionally lightweight rather than a complete
pathfinder. Obstacle stalls remain a known limitation. Automated controllers,
seeded visual fixtures and passing regressions are not a human full-campaign
playtest or an exhaustive assessment of every build/reward combination.
