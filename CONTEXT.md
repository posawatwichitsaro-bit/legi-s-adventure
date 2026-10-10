# Legi's Adventure

The language of player progression and rewards in Legi's Adventure.

## Language

**Class**:
The player's combat identity: Fighter emphasizes melee combat, HP and Block; Ranger emphasizes fast single-target attacks and trap avoidance; Wizard emphasizes elemental power or coverage; Rogue emphasizes speed, Dash, critical hits and Dodge.
_Avoid_: Build, Path

**Tactic**:
A combat adjustment chosen from random offers every five levels, improving shared attributes or behaviors. A weapon/element-switching Tactic offers alternatives belonging to the current Class; deeper Class-specific capabilities belong to Skills.
_Avoid_: Special Upgrade, Upgrade, Class Tactic, Skill Rank

**Skill**:
A Class-specific capability chosen from random offers earned through boss victories that changes how the Class plays. Offers contain only Skills belonging to the player's Class.
_Avoid_: Starting Ability, Starting Skill

**Skill Upgrade**:
A distinct higher-step Skill, such as Extra Attack II, requiring the earlier step and replacing its effect. It is a separate selectable capability rather than a repeat selection of Extra Attack I.

**Starting Option**:
The weapon or spell element selected within a Class before a run. It establishes the player's initial combat approach.
_Avoid_: Starting Skill, Starting Ability

**Dormant Skill**:
A learned Skill whose effect is inactive because it is incompatible with the current weapon or element. It remains learned and becomes active again when the player returns to a compatible choice.

**Equipment**:
Wearable items that add attribute bonuses or effects, chosen as a separate reward after clearing a boss arena.
_Avoid_: Relic, Gear

**Stats**:
The player's combat attributes, including health, damage, speed, armor, Mage Armor, Critical Rate, Critical Damage, Dodge Rate and Block Rate.
_Avoid_: Path Bonus

**Critical Rate**:
The chance for an eligible player attack to deal a critical hit.

**Critical Damage**:
The bonus damage added to an ordinary hit when it becomes critical. A base of 50% means a critical hit deals 150% of ordinary damage.

**Dodge Rate**:
The chance to avoid all damage from an incoming melee attack or projectile when Dodge is available. Dodge does not apply to map traps or damage over time, and is distinct from moving out of an attack or using Dash.

**Dodge Cooldown**:
The recovery period during which probabilistic Dodge is unavailable. Its minimum is two seconds for most Classes and one second for Rogue.

**Block Rate**:
The chance to reduce an incoming melee attack or projectile's damage by 50%, with no Block cooldown. Block does not apply to map traps or damage over time.

**Mage Armor**:
Wizard's innate shield attribute, distinct from HP and ordinary Armor, that recharges after a period without taking damage. Wizard's starting combined HP and shield remains lower than the other Classes, while Tactics can improve survivability.

**Cosmetics**:
Permanent appearance choices earned through stage progression that do not change combat attributes.
_Avoid_: Equipment Color

**Run**:
One adventure beginning at stage one and ending in defeat, victory or abandonment. A saved pause and later resume continue the same Run.

**Run Save**:
The local checkpoint automatically saved after clearing a Stage, allowing the player to continue later. It is distinct from permanent profile progress.

**Checkpoint**:
Progress recorded at a completed Stage boundary, rather than the exact state of an ongoing battle.

**Element**:
Wizard's active spell identity: Fire burns, Ice slows, Lightning chains between targets, and Light pierces targets. One primary Element is active at a time; Skills add deeper behaviors.

**Damage over Time**:
Damage applied over a duration, such as burn, poison or bleed, distinct from the direct hit that applies it. Bleed and poison can coexist, each with a limited number of stacks.

**Stage**:
One arena in the adventure, cleared by defeating all enemy groups and resolving their drops.
