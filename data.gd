class_name AdventureData
extends RefCounted

## Every stats dictionary contains additive deltas, never multipliers.
## damage, max_hp, dash_damage, armor: points; speed: pixels/second;
## attack_speed: attacks/second; range, pickup: pixels;
## range also adds max(0, range - 78) pixels/second to aimed arrows/staff bolts.
## At the 145 range cap: arrows <=407 px/s, staff bolts <=327 px/s.
## projectiles, magic: whole counts; dash_cooldown: seconds; regen: HP/second.
## Negative dash_cooldown reduces the delay. Clamp its final value above zero.

# Final effective bounds apply to level growth, skills AND guardian relics.
# Keep melee local: range changes aimed projectile speed, not their lifetime.
const STAT_LIMITS = {
	"max_hp": [1.0, 400.0], "damage": [1.0, 80.0],
	"speed": [1.0, 240.0], "attack_speed": [0.3, 2.2],
	"range": [1.0, 145.0], "projectiles": [0.0, 4.0],
	"magic": [0.0, 3.0], "dash_damage": [0.0, 120.0],
	"dash_cooldown": [1.1, 10.0], "pickup": [1.0, 240.0],
	"regen": [0.0, 3.0], "armor": [0.0, 8.0], "lifesteal": [0.0, 0.1],
}

const THEMES = [
	{"name": "Meadow", "floor": Color("39664e"), "accent": Color("7ee7a2"), "wall": Color("365d45")},
	{"name": "Ember", "floor": Color("633d3b"), "accent": Color("ffad70"), "wall": Color("76453f")},
	{"name": "Crystal", "floor": Color("364f70"), "accent": Color("87ddff"), "wall": Color("4c658d")},
	{"name": "Night", "floor": Color("46375f"), "accent": Color("d3a2ff"), "wall": Color("614573")},
]

const BUILDS = [
	{
		"id": "melee", "name": "Blade Dancer", "weapon": "sword", "weapon_label": "Sword",
		"description": "Sword slashes. Level bonus: movement + attack speed.",
		"starting_stats": {},
		"stats": {"speed": 22.0, "attack_speed": 0.35},
	},
	{
		"id": "ranger", "name": "Star Ranger", "weapon": "bow", "weapon_label": "Bow",
		"description": "Bow from the start. Level bonus: arrows + damage.",
		"starting_stats": {"projectiles": 1.0},
		"stats": {"projectiles": 1, "damage": 5.0},
	},
	{
		"id": "mage", "name": "Moon Weaver", "weapon": "staff", "weapon_label": "Staff",
		"description": "Staff bolts from the start. Level bonus: magic + pickup.",
		"starting_stats": {"magic": 1.0},
		"stats": {"magic": 1, "pickup": 42.0},
	},
	{
		"id": "dash", "name": "Comet Strider", "weapon": "dagger", "weapon_label": "Dagger",
		"description": "Quick dagger + damaging dash. Level bonus: stronger dash.",
		"starting_stats": {"dash_damage": 22.0},
		"stats": {"dash_damage": 22.0, "dash_cooldown": -0.35},
	},
]

# Class attacks share capped stats but not hidden extra weapons. Timers are
# start-to-start cooldowns; windup/active/recovery also gate repeat attacks.
const PRIMARY_WEAPONS = {
	"sword": {"cooldown": 0.85, "windup": 0.12, "active": 0.12, "recover": 0.12, "damage": 1.0, "reach": 1.0, "cone_dot": -0.15},
	"dagger": {"cooldown": 0.62, "windup": 0.08, "active": 0.10, "recover": 0.10, "damage": 0.82, "reach": 0.78, "cone_dot": 0.15},
	"bow": {"cooldown": 0.85, "windup": 0.20, "release": 0.18, "damage": 0.9},
	"staff": {"cooldown": 0.95, "windup": 0.28, "release": 0.22, "damage": 1.1},
}

const UPGRADES = [
	{"id": "life_drain", "cap": 1, "name": "Life Drain", "description": "Heal 10% of actual attack damage. Unique; does not stack.", "stats": {"lifesteal": 0.1}},
	{"id": "keen_edge", "cap": 3, "rank_scales": [1.0, 0.8, 0.6], "name": "Keen Edge", "description": "+6 attack damage.", "stats": {"damage": 6.0}},
	{"id": "heartwood", "cap": 3, "name": "Heartwood", "description": "+25 maximum health.", "stats": {"max_hp": 25.0}},
	{"id": "windstep", "cap": 2, "name": "Windstep", "description": "+20 movement speed.", "stats": {"speed": 20.0}},
	{"id": "quick_hands", "cap": 3, "rank_scales": [1.0, 0.8, 0.6], "name": "Quick Hands", "description": "+0.25 attacks per second.", "stats": {"attack_speed": 0.25}},
	{"id": "long_reach", "cap": 2, "rank_scales": [1.0, 0.65], "name": "Long Reach", "description": "+28 melee reach and +28 aimed-shot speed above 78 range.", "stats": {"range": 28.0}},
	{"id": "split_shot", "cap": 3, "name": "Split Shot", "description": "Add a bow attack, or +1 arrow to your bow volley.", "stats": {"projectiles": 1}},
	{"id": "starlight", "cap": 2, "name": "Starlight", "description": "Add eight radial sparks, or strengthen your staff bolts.", "stats": {"magic": 1}},
	{"id": "comet_tail", "cap": 3, "name": "Comet Tail", "description": "+16 dash damage.", "stats": {"dash_damage": 16.0}},
	{"id": "second_wind", "cap": 2, "name": "Second Wind", "description": "Dash cooldown reduced by 0.2 seconds.", "stats": {"dash_cooldown": -0.2}},
	{"id": "treasure_magnet", "cap": 2, "name": "Treasure Magnet", "description": "+36 pickup radius.", "stats": {"pickup": 36.0}},
	{"id": "spring_water", "cap": 3, "name": "Spring Water", "description": "Regenerate 0.75 health per second.", "stats": {"regen": 0.75}},
	{"id": "stone_skin", "cap": 3, "name": "Stone Skin", "description": "Reduce incoming hit damage by 2.", "stats": {"armor": 2.0}},
	{"id": "duelist", "cap": 2, "name": "Duelist's Rhythm", "description": "+3 damage and +0.15 attacks per second.", "stats": {"damage": 3.0, "attack_speed": 0.15}},
	{"id": "farshot", "cap": 2, "rank_scales": [1.0, 0.7], "name": "Farshot Charm", "description": "+4 damage, +20 melee reach and aimed-shot speed above 78 range.", "stats": {"damage": 4.0, "range": 20.0}},
	{"id": "moon_harvest", "cap": 2, "name": "Moon Harvest", "description": "+1 magic power and +18 pickup radius.", "stats": {"magic": 1, "pickup": 18.0}},
	{"id": "meteor_boots", "cap": 2, "name": "Meteor Boots", "description": "+10 dash damage and +12 movement speed.", "stats": {"dash_damage": 10.0, "speed": 12.0}},
]

const EQUIPMENT_NAMES = [
	"Dewdrop Blade", "Bramble Bow", "Moonstone Wand", "Comet Boots",
	"Heartwood Buckler", "Ember Pendant", "Crystal Circlet", "Nightfall Cloak",
	"Lucky Acorn", "Starfall Ring", "Sunlit Gauntlets", "Windchime Charm",
]

const COSMETICS = [
	{"id": "meadow", "name": "Original Orange", "color": Color.WHITE, "stage": 0},
	{"id": "ember", "name": "Ember Glow", "color": Color("ffaf77"), "stage": 5},
	{"id": "crystal", "name": "Crystal Blue", "color": Color("8cdfff"), "stage": 10},
	{"id": "night", "name": "Royal Starlight", "color": Color("d4a4ff"), "stage": 20},
]
