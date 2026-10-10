# v6 expanded worlds, environmental hazards and enemy groups

## Scope

Editable Godot 4.6.3 source project. Default scene remains `main.tscn` and starts
in the ordinary menu. No save migration or new dependency is required. The
four starting weapons, ten regular enemy types, guardian signatures and eight
additional guardian moves, upgrades, relic caps and healing rules are retained.

## World and camera contract

- Old world: `Rect2(32,112,896,456)`; new world: `Rect2(32,112,1344,684)`.
- Dimensions increase 50% in each axis, so floor area increases 125% (2.25×).
- The visible playfield remains `Rect2(32,112,896,456)` in a 960×600 viewport.
- World center / portal is `(704,454)`; center-screen remains `(480,340)`.
- Camera offset is clamped to `(0..448,0..228)` and rounded to whole pixels.
- Only world draw commands translate. HUD, menus, health bars and mini-map do
  not. World pixels behind HUD borders are masked.
- `screen_to_world` and `world_to_screen` are inverses. Pointer movement uses
  logical canvas mouse coordinates plus camera offset, preserving window stretch. Aiming, attacks, projectiles,
  pickups and collisions remain entirely in world units.
- The mini-map shows the full map, solid obstacles, actors and current view.
  A P marker points toward an off-screen clear portal. An orange ! warns of
  an off-screen enemy windup.

## Four authored procedural environments

Each theme has a different route drawing, four authored landmarks, solid-prop
arrangement and pixel details. Random jitter, small prop placement, floor
patches and detail variants make seeded arenas distinct. Later stages within
each five-stage tier add detached props and floor patches; they do not close
routes. A broad cross (184 px horizontal / 164 px vertical) and 62+ px border
remain open. Solid props are isolated with at least 48 px separation; the
center portal approach is kept clear. Shadows and raised sides identify solids.

- Meadow / Willow Crossroads: winding paths, ponds, planted gardens, foliage,
  stumps and boulders.
- Ember / Ashen Causeways: broad ash roads, calderas, furnaces, scorched masonry
  and glowing cracks.
- Crystal / Prismatic Courts: rectilinear courts, prism landmarks, inlaid
  mosaics and faceted crystal props.
- Night / Moonlit Observatory: curved orbit mosaics, lunar landmarks, star
  glyphs and observatory stones.

Shallow ponds, calderas and other flat landmarks are decorative and traversable.
They are not secretly damaging terrain. Environmental danger always has the
same explicit warning/active/recovery visual language below.

## Random environmental hazards

Theme-specific bramble bursts, ember vents, prism eruptions and lunar seals
appear at randomized valid ground locations. Every hazard is a locked circle
with a 30–41 px eruption core and a 40–51 px player-center contact radius.
Every visible warning/active boundary includes the full contact radius. Warning lasts **1.4 s**, active damage **1 s**, and harmless
recovery **0.7 s**. The first hazard clock starts at 5 s; later recurrence is
randomized from 5.4–7.0 s early to 3.0–4.6 s at stage 20. Stages 11+ can
request pairs; the concurrent cap is two in the first two themes and three
later. Failure to find safe placement skips that attempt.

Warnings use hollow gold boundaries, exclamation marks and a closing timer.
Active zones use red/cream boundaries and filled theme-specific effects.
Recovery uses a fading dashed outline. Hazards draw on the floor underneath
actors and enemy warnings. Neither positions nor damage areas track the player.

Placement avoids the current player by radius +48 px, the center sanctuary by
110+radius+12 px, other hazards by both radii +42 px, and solid obstacles and
arena edges by radius +12 px. A hazard can touch once per eruption, using the
same armor and hurt/dash immunity as combat. Contact during invulnerability
consumes that hazard's one contact, so a dash cannot turn into delayed damage.
Damage is 9 +0.5×stage before armor. No hazards remain between empty waves,
after the final foe dies, on portal opening, death, menu return or new stage.

## Roster math and wave lifecycle

`total = ceil((8 + 2*stage + (1 if stage%5==0 else 0))*1.25)`.
Round up once per complete roster. On guardian stages allocate one guardian,
then fill the remaining slots with regular enemies. Herbalist index 4 is
reserved exactly once; all stage mixes retain melee and ranged foes.

| Theme stages | Group size | Active cap | Counts by stage |
|---|---:|---:|---|
| Meadow 1–5 | 4 | 6 | 13,15,18,20,24 |
| Ember 6–10 | 5 | 8 | 25,28,30,33,37 |
| Crystal 11–15 | 6 | 10 | 38,40,43,45,49 |
| Night 16–20 | 7 | 12 | 50,53,55,58,62 |

First group arrives immediately. Later groups require both a minimum three
seconds since the preceding arrival and enough capacity for the whole group.
The final short group uses only its actual size. The guardian occupies the
last roster slot and therefore arrives with the last group. Arrivals get a
visible 0.85-second grace ring and cannot act during that grace.

HUD total and remaining bar count active plus queued foes. Kill counts rise
only when an actual spawned enemy dies. XP and potion attraction becomes
whole-arena only when both active and queue are empty, not between groups.
Clear healing, relic choices and portal opening wait for the entire roster and
its drops. The 10%-max-HP clear heal remains once per arena. Pauses and reward
modals freeze simulation, waves and hazards; death/menu/next-stage clear
pending hazards and groups.

All 20 stages sum to 736 foes, compared with 584 in v5: 26.03% overall because
of upward stage rounding. All kill XP yields 3,043 XP, level 43 plus 82 XP and
eight special-upgrade panels when no other XP is added. These are lifecycle
expectations, not claims that an automated controller wins every run.

## Verification

Godot 4.6.3: **863 assertions plus the integration self-test pass**.

- Existing regression 23, healing 74, balance 125, combat 93, weapon 123 and
  guardian-pattern 217 assertions: all 655 retained and passing.
- New `v6_tests.gd`: 208 assertions covering full roster math, exact boss and
  herbalist presence, caps, delayed whole-group arrivals, pause/reward gates,
  remaining-count HUD, pickup attraction, once-only clear heal, final-group
  relic/portal order, transition cleanup, camera inverse transforms, remote
  world-space aiming/pickup/projectiles, obstacle collision and hazard phases.
- Existing lifecycle regression progresses all four builds through 20 stages,
  eight upgrade choices and four guardian rewards, with natural group clocks.
  Its intentionally injected kills verify state transitions, not difficulty.
- Existing 2,000 seeded arena sweep: all roster spawns safe and reachable.
- New 200-map sweep checks the entire walkable configuration space with exact
  rectangle-boundary decomposition, rather than assuming a coarse grid proves
  connectivity. All 7,360 queued-group spawns are safe; all maps connected.
- Hazard tests cover locked harmless warning, armor, dash/hurt immunity,
  one-contact damage, recovery, pause/modal clocks, death/portal cleanup,
  random placement exclusions and population caps.

Real-combat measurements are in V6_BALANCE_NOTES.md. Those campaigns use
actual attacks, drops and progression without injected kills or invulnerability.

### Native visual QA

See the clearly labelled `visual_qa_v6.tscn` fixture and screenshots. It is
optional, save-disabled and never the default main scene. Keys: 1–4 themes;
T/Y/U warning/active/recovery; F frozen/live; C camera waypoint; G natural wave
encounter; N seeded active-group clear; P staged clear-portal scenario; B build;
R reset; F12 screenshot.
Frozen hazard poses and the portal scenario are staged QA, not proof of a
natural win. Ordinary play always begins at the menu through `main.tscn`.

Native Godot 4.6.3 inspection verified all four themes and their corner
landmarks, warning/active/recovery contrast, camera movement, queued-wave HUD,
mouse movement at 1152×720 and a 1178×814 letterboxed window, keyboard movement,
right-click dash, pause/resume, a staged empty-active/pending-queue interval,
later group arrival, ordinary combat damage, and portal advancement from stage
16 to 17. The mini-map moved aside when the player approached its corner.
Final inspection restored the normal main menu with clean default settings.
Screenshots explicitly label staged states; `normal-v6-menu.jpg` shows normal
startup.

A complete human twenty-stage playthrough and audio playback are not claimed.
The cloud desktop uses a dummy audio driver. Lightweight enemy steering can
still stall behind props; open connected geometry does not imply perfect AI
pathfinding. Automated controller outcomes are not estimates of human win rate.
