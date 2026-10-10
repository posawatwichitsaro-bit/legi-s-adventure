class_name AdventureData
extends RefCounted

const MAX_STAGE = 30
const SCHEMA_VERSION = 8
# Rates are fractions; critical_damage is BONUS damage (0.5 means 150%).
const STAT_LIMITS = {
	"max_hp": [
		1,
		500
	],
	"damage": [
		1,
		120
	],
	"speed": [
		1,
		240
	],
	"attack_speed": [
		0.3,
		2.4
	],
	"range": [
		1,
		145
	],
	"projectiles": [
		0,
		4
	],
	"magic": [
		0,
		3
	],
	"dash_damage": [
		0,
		120
	],
	"dash_cooldown": [
		1.1,
		10
	],
	"pickup": [
		1,
		240
	],
	"regen": [
		0,
		3
	],
	"armor": [
		0,
		10
	],
	"lifesteal": [
		0,
		0.1
	],
	"critical_rate": [
		0,
		0.75
	],
	"critical_damage": [
		0,
		2.5
	],
	"dodge_rate": [
		0,
		0.7
	],
	"block_rate": [
		0,
		0.9
	],
	"dodge_cooldown": [
		2,
		10
	],
	"mage_armor": [
		0,
		150
	],
	"shield_regen": [
		0,
		10
	]
}
const THEMES = [
 {"name":"Meadow","floor":Color("39664e"),"accent":Color("7ee7a2"),"wall":Color("365d45")},
 {"name":"Ember","floor":Color("633d3b"),"accent":Color("ffad70"),"wall":Color("76453f")},
 {"name":"Crystal","floor":Color("364f70"),"accent":Color("87ddff"),"wall":Color("4c658d")},
 {"name":"Night","floor":Color("46375f"),"accent":Color("d3a2ff"),"wall":Color("614573")}
]
const CLASSES = [
	{
		"id": "melee",
		"name": "Fighter",
		"weapon": "sword",
		"weapon_label": "Sword",
		"description": "High HP and Block. Knife, sword or heavy axe.",
		"options": [
			"knife",
			"sword",
			"axe"
		],
		"starting_stats": {
			"max_hp": 30
		},
		"stats": {
			"max_hp": 2.4,
			"damage": 0.65,
			"block_rate": 0.004,
			"attack_speed": 0.008
		}
	},
	{
		"id": "ranger",
		"name": "Ranger",
		"weapon": "bow",
		"weapon_label": "Bow",
		"description": "Fast single-target shots and recharging trap protection.",
		"options": [
			"bow",
			"crossbow",
			"gun"
		],
		"starting_stats": {
			"max_hp": -10,
			"damage": -2,
			"speed": 25,
			"attack_speed": 0.1
		},
		"stats": {
			"max_hp": 1.15,
			"damage": 0.6,
			"speed": 0.35,
			"attack_speed": 0.012
		}
	},
	{
		"id": "mage",
		"name": "Wizard",
		"weapon": "staff",
		"weapon_label": "Spell",
		"description": "55 HP + 20 Mage Armor. Fire, Ice, Lightning or Light.",
		"options": [
			"fire",
			"ice",
			"lightning",
			"light"
		],
		"starting_stats": {
			"max_hp": -45,
			"damage": 6,
			"speed": -10,
			"mage_armor": 20,
			"dodge_cooldown": 1
		},
		"stats": {
			"max_hp": 0.8,
			"damage": 0.85,
			"mage_armor": 0.45,
			"pickup": 0.7
		}
	},
	{
		"id": "dash",
		"name": "Rogue",
		"weapon": "dagger",
		"weapon_label": "Dagger",
		"description": "Agile dagger, sword or throwing knives. Critical hits and Dodge.",
		"options": [
			"dagger",
			"sword",
			"throwing_knife"
		],
		"starting_stats": {
			"max_hp": -15,
			"damage": -3,
			"speed": 25,
			"dash_damage": 22,
			"dodge_cooldown": -1
		},
		"stats": {
			"max_hp": 1.1,
			"damage": 0.55,
			"speed": 0.4,
			"critical_rate": 0.0035,
			"critical_damage": 0.009,
			"dodge_rate": 0.004,
			"dash_cooldown": -0.016
		}
	}
]
const PRIMARY_WEAPONS = {
	"sword": {
		"cooldown": 0.85,
		"windup": 0.12,
		"active": 0.12,
		"recover": 0.12,
		"damage": 1,
		"reach": 1,
		"cone_dot": 0.82
	},
	"knife": {
		"cooldown": 0.48,
		"windup": 0.07,
		"active": 0.08,
		"recover": 0.08,
		"damage": 0.72,
		"reach": 0.7,
		"cone_dot": 0.88
	},
	"axe": {
		"cooldown": 1.25,
		"windup": 0.22,
		"active": 0.18,
		"recover": 0.22,
		"damage": 1.45,
		"reach": 1.1,
		"cone_dot": -0.1
	},
	"dagger": {
		"cooldown": 0.52,
		"windup": 0.07,
		"active": 0.09,
		"recover": 0.08,
		"damage": 0.8,
		"reach": 0.78,
		"cone_dot": 0.78
	},
	"bow": {
		"cooldown": 0.66,
		"windup": 0.14,
		"damage": 0.9,
		"speed": 340,
		"pierce": 1
	},
	"crossbow": {
		"cooldown": 1,
		"windup": 0.22,
		"damage": 1.3,
		"speed": 410,
		"pierce": 2
	},
	"gun": {
		"cooldown": 1.35,
		"windup": 0.26,
		"damage": 1.9,
		"speed": 520,
		"pierce": 1
	},
	"throwing_knife": {
		"cooldown": 0.6,
		"windup": 0.12,
		"damage": 0.8,
		"speed": 365,
		"pierce": 1
	},
	"staff": {
		"cooldown": 1.05,
		"windup": 0.25,
		"damage": 1.15,
		"speed": 270,
		"pierce": 1
	}
}
const TACTICS = [
	{
		"id": "keen_edge",
		"name": "Keen Edge",
		"stats": {
			"damage": 5
		},
		"cap": 3,
		"description": "+5 damage"
	},
	{
		"id": "heartwood",
		"name": "Heartwood",
		"stats": {
			"max_hp": 20
		},
		"cap": 3,
		"description": "+20 max hp"
	},
	{
		"id": "windstep",
		"name": "Windstep",
		"stats": {
			"speed": 12
		},
		"cap": 3,
		"description": "+12 speed"
	},
	{
		"id": "quick_hands",
		"name": "Quick Hands",
		"stats": {
			"attack_speed": 0.12
		},
		"cap": 3,
		"description": "+0.12 attack speed"
	},
	{
		"id": "long_reach",
		"name": "Long Reach",
		"stats": {
			"range": 12
		},
		"cap": 3,
		"description": "+12 range"
	},
	{
		"id": "second_wind",
		"name": "Second Wind",
		"stats": {
			"dash_cooldown": -0.15
		},
		"cap": 3,
		"description": "-0.15 dash cooldown"
	},
	{
		"id": "treasure_magnet",
		"name": "Treasure Magnet",
		"stats": {
			"pickup": 20
		},
		"cap": 3,
		"description": "+20 pickup"
	},
	{
		"id": "spring_water",
		"name": "Spring Water",
		"stats": {
			"regen": 0.3
		},
		"cap": 3,
		"description": "+0.3 regen"
	},
	{
		"id": "stone_skin",
		"name": "Stone Skin",
		"stats": {
			"armor": 1
		},
		"cap": 3,
		"description": "+1 armor"
	},
	{
		"id": "duelist",
		"name": "Duelist Rhythm",
		"stats": {
			"damage": 3,
			"attack_speed": 0.07
		},
		"cap": 3,
		"description": "+3 damage / +0.07 attack speed"
	},
	{
		"id": "farshot",
		"name": "Farshot",
		"stats": {
			"damage": 2,
			"range": 8
		},
		"cap": 3,
		"description": "+2 damage / +8 range"
	},
	{
		"id": "meteor_boots",
		"name": "Meteor Boots",
		"stats": {
			"dash_damage": 6,
			"speed": 7
		},
		"cap": 3,
		"description": "+6 dash damage / +7 speed"
	},
	{
		"id": "critical_eye",
		"name": "Critical Eye",
		"stats": {
			"critical_rate": 0.025
		},
		"cap": 3,
		"description": "+0.025 critical rate"
	},
	{
		"id": "deadly_precision",
		"name": "Deadly Precision",
		"stats": {
			"critical_damage": 0.12
		},
		"cap": 3,
		"description": "+0.12 critical damage"
	},
	{
		"id": "evasive_steps",
		"name": "Evasive Steps",
		"stats": {
			"dodge_rate": 0.025
		},
		"cap": 3,
		"description": "+0.025 dodge rate"
	},
	{
		"id": "guard_training",
		"name": "Guard Training",
		"stats": {
			"block_rate": 0.035
		},
		"cap": 3,
		"description": "+0.035 block rate"
	},
	{
		"id": "reflexes",
		"name": "Reflexes",
		"stats": {
			"dodge_cooldown": -0.15
		},
		"cap": 3,
		"description": "-0.15 dodge cooldown"
	},
	{
		"id": "ward",
		"name": "Protective Ward",
		"stats": {
			"mage_armor": 10
		},
		"cap": 3,
		"description": "+10 mage armor"
	},
	{
		"id": "ward_recharge",
		"name": "Ward Recharge",
		"stats": {
			"shield_regen": 0.7,
			"max_hp": 5
		},
		"cap": 3,
		"description": "+0.7 shield regen / +5 max hp"
	},
	{
		"id": "vitality",
		"name": "Vitality",
		"stats": {
			"max_hp": 12,
			"regen": 0.1
		},
		"cap": 3,
		"description": "+12 max hp / +0.1 regen"
	},
	{
		"id": "battle_focus",
		"name": "Battle Focus",
		"stats": {
			"damage": 3,
			"critical_rate": 0.01
		},
		"cap": 3,
		"description": "+3 damage / +0.01 critical rate"
	},
	{
		"id": "nimble_guard",
		"name": "Nimble Guard",
		"stats": {
			"speed": 6,
			"block_rate": 0.02
		},
		"cap": 3,
		"description": "+6 speed / +0.02 block rate"
	},
	{
		"id": "agile_heart",
		"name": "Agile Heart",
		"stats": {
			"max_hp": 10,
			"dodge_rate": 0.015
		},
		"cap": 3,
		"description": "+10 max hp / +0.015 dodge rate"
	},
	{
		"id": "duel_precision",
		"name": "Duel Precision",
		"stats": {
			"attack_speed": 0.06,
			"critical_damage": 0.08
		},
		"cap": 3,
		"description": "+0.06 attack speed / +0.08 critical damage"
	},
	{
		"id": "iron_heart",
		"name": "Iron Heart",
		"stats": {
			"max_hp": 12,
			"armor": 0.5
		},
		"cap": 3,
		"description": "+12 max hp / +0.5 armor"
	},
	{
		"id": "fleet_hands",
		"name": "Fleet Hands",
		"stats": {
			"speed": 6,
			"attack_speed": 0.06
		},
		"cap": 3,
		"description": "+6 speed / +0.06 attack speed"
	},
	{
		"id": "reach_training",
		"name": "Reach Training",
		"stats": {
			"range": 8,
			"pickup": 10
		},
		"cap": 3,
		"description": "+8 range / +10 pickup"
	},
	{
		"id": "survivor",
		"name": "Survivor",
		"stats": {
			"regen": 0.2,
			"armor": 0.5
		},
		"cap": 3,
		"description": "+0.2 regen / +0.5 armor"
	},
	{
		"id": "critical_guard",
		"name": "Critical Guard",
		"stats": {
			"critical_rate": 0.01,
			"block_rate": 0.02
		},
		"cap": 3,
		"description": "+0.01 critical rate / +0.02 block rate"
	},
	{
		"id": "dash_mastery",
		"name": "Dash Mastery",
		"stats": {
			"dash_damage": 5,
			"dash_cooldown": -0.08
		},
		"cap": 3,
		"description": "+5 dash damage / -0.08 dash cooldown"
	},
	{
		"id": "patient_guard",
		"name": "Patient Guard",
		"stats": {
			"block_rate": 0.02,
			"armor": 0.5
		},
		"cap": 3,
		"description": "+0.02 block rate / +0.5 armor"
	},
	{
		"id": "dodge_focus",
		"name": "Dodge Focus",
		"stats": {
			"dodge_rate": 0.02,
			"dodge_cooldown": -0.08
		},
		"cap": 3,
		"description": "+0.02 dodge rate / -0.08 dodge cooldown"
	},
	{
		"id": "merciless",
		"name": "Merciless",
		"stats": {
			"damage": 3,
			"critical_damage": 0.06
		},
		"cap": 3,
		"description": "+3 damage / +0.06 critical damage"
	},
	{
		"id": "resilient_ward",
		"name": "Resilient Ward",
		"stats": {
			"mage_armor": 6,
			"armor": 0.5
		},
		"cap": 3,
		"description": "+6 mage armor / +0.5 armor"
	},
	{
		"id": "scavenger",
		"name": "Scavenger",
		"stats": {
			"pickup": 15,
			"speed": 5
		},
		"cap": 3,
		"description": "+15 pickup / +5 speed"
	},
	{
		"id": "balanced_training",
		"name": "Balanced Training",
		"stats": {
			"max_hp": 8,
			"damage": 2
		},
		"cap": 3,
		"description": "+8 max hp / +2 damage"
	},
	{
		"id": "life_drain",
		"name": "Life Drain",
		"stats": {
			"lifesteal": 0.1
		},
		"cap": 1,
		"description": "+0.1 lifesteal"
	},
	{
		"id": "switch_melee_knife",
		"name": "Switch to knife",
		"description": "Change weapon/element. Incompatible learned Skills remain dormant.",
		"stats": {},
		"cap": 999,
		"classes": [
			"melee"
		],
		"effect": "switch",
		"option": "knife"
	},
	{
		"id": "switch_melee_sword",
		"name": "Switch to sword",
		"description": "Change weapon/element. Incompatible learned Skills remain dormant.",
		"stats": {},
		"cap": 999,
		"classes": [
			"melee"
		],
		"effect": "switch",
		"option": "sword"
	},
	{
		"id": "switch_melee_axe",
		"name": "Switch to axe",
		"description": "Change weapon/element. Incompatible learned Skills remain dormant.",
		"stats": {},
		"cap": 999,
		"classes": [
			"melee"
		],
		"effect": "switch",
		"option": "axe"
	},
	{
		"id": "switch_ranger_bow",
		"name": "Switch to bow",
		"description": "Change weapon/element. Incompatible learned Skills remain dormant.",
		"stats": {},
		"cap": 999,
		"classes": [
			"ranger"
		],
		"effect": "switch",
		"option": "bow"
	},
	{
		"id": "switch_ranger_crossbow",
		"name": "Switch to crossbow",
		"description": "Change weapon/element. Incompatible learned Skills remain dormant.",
		"stats": {},
		"cap": 999,
		"classes": [
			"ranger"
		],
		"effect": "switch",
		"option": "crossbow"
	},
	{
		"id": "switch_ranger_gun",
		"name": "Switch to gun",
		"description": "Change weapon/element. Incompatible learned Skills remain dormant.",
		"stats": {},
		"cap": 999,
		"classes": [
			"ranger"
		],
		"effect": "switch",
		"option": "gun"
	},
	{
		"id": "switch_mage_fire",
		"name": "Switch to fire",
		"description": "Change weapon/element. Incompatible learned Skills remain dormant.",
		"stats": {},
		"cap": 999,
		"classes": [
			"mage"
		],
		"effect": "switch",
		"option": "fire"
	},
	{
		"id": "switch_mage_ice",
		"name": "Switch to ice",
		"description": "Change weapon/element. Incompatible learned Skills remain dormant.",
		"stats": {},
		"cap": 999,
		"classes": [
			"mage"
		],
		"effect": "switch",
		"option": "ice"
	},
	{
		"id": "switch_mage_lightning",
		"name": "Switch to lightning",
		"description": "Change weapon/element. Incompatible learned Skills remain dormant.",
		"stats": {},
		"cap": 999,
		"classes": [
			"mage"
		],
		"effect": "switch",
		"option": "lightning"
	},
	{
		"id": "switch_mage_light",
		"name": "Switch to light",
		"description": "Change weapon/element. Incompatible learned Skills remain dormant.",
		"stats": {},
		"cap": 999,
		"classes": [
			"mage"
		],
		"effect": "switch",
		"option": "light"
	},
	{
		"id": "switch_dash_dagger",
		"name": "Switch to dagger",
		"description": "Change weapon/element. Incompatible learned Skills remain dormant.",
		"stats": {},
		"cap": 999,
		"classes": [
			"dash"
		],
		"effect": "switch",
		"option": "dagger"
	},
	{
		"id": "switch_dash_sword",
		"name": "Switch to sword",
		"description": "Change weapon/element. Incompatible learned Skills remain dormant.",
		"stats": {},
		"cap": 999,
		"classes": [
			"dash"
		],
		"effect": "switch",
		"option": "sword"
	},
	{
		"id": "switch_dash_throwing_knife",
		"name": "Switch to throwing knife",
		"description": "Change weapon/element. Incompatible learned Skills remain dormant.",
		"stats": {},
		"cap": 999,
		"classes": [
			"dash"
		],
		"effect": "switch",
		"option": "throwing_knife"
	}
]
const SKILLS = [
	{
		"id": "melee_extra_attack_1",
		"name": "Extra Attack I",
		"description": "Add one full-damage sequential swing per step.",
		"classes": [
			"melee"
		],
		"effect": "extra_attack",
		"tier": 1,
		"requires": "",
		"weapons": [],
		"element": ""
	},
	{
		"id": "melee_extra_attack_2",
		"name": "Extra Attack II",
		"description": "Add one full-damage sequential swing per step.",
		"classes": [
			"melee"
		],
		"effect": "extra_attack",
		"tier": 2,
		"requires": "melee_extra_attack_1",
		"weapons": [],
		"element": ""
	},
	{
		"id": "melee_cleave_1",
		"name": "Wide Cleave I",
		"description": "Widen each melee swing.",
		"classes": [
			"melee"
		],
		"effect": "cleave",
		"tier": 1,
		"requires": "",
		"weapons": [],
		"element": ""
	},
	{
		"id": "melee_cleave_2",
		"name": "Wide Cleave II",
		"description": "Widen each melee swing.",
		"classes": [
			"melee"
		],
		"effect": "cleave",
		"tier": 2,
		"requires": "melee_cleave_1",
		"weapons": [],
		"element": ""
	},
	{
		"id": "melee_reach_1",
		"name": "Advancing Edge I",
		"description": "Extend melee reach by 15% per step.",
		"classes": [
			"melee"
		],
		"effect": "reach",
		"tier": 1,
		"requires": "",
		"weapons": [],
		"element": ""
	},
	{
		"id": "melee_reach_2",
		"name": "Advancing Edge II",
		"description": "Extend melee reach by 15% per step.",
		"classes": [
			"melee"
		],
		"effect": "reach",
		"tier": 2,
		"requires": "melee_reach_1",
		"weapons": [],
		"element": ""
	},
	{
		"id": "melee_riposte_1",
		"name": "Riposte I",
		"description": "Block retaliates against nearby enemies.",
		"classes": [
			"melee"
		],
		"effect": "riposte",
		"tier": 1,
		"requires": "",
		"weapons": [],
		"element": ""
	},
	{
		"id": "melee_riposte_2",
		"name": "Riposte II",
		"description": "Block retaliates against nearby enemies.",
		"classes": [
			"melee"
		],
		"effect": "riposte",
		"tier": 2,
		"requires": "melee_riposte_1",
		"weapons": [],
		"element": ""
	},
	{
		"id": "melee_stagger_1",
		"name": "Stagger I",
		"description": "Direct hits slow enemies briefly.",
		"classes": [
			"melee"
		],
		"effect": "stagger",
		"tier": 1,
		"requires": "",
		"weapons": [],
		"element": ""
	},
	{
		"id": "melee_stagger_2",
		"name": "Stagger II",
		"description": "Direct hits slow enemies briefly.",
		"classes": [
			"melee"
		],
		"effect": "stagger",
		"tier": 2,
		"requires": "melee_stagger_1",
		"weapons": [],
		"element": ""
	},
	{
		"id": "melee_execution_1",
		"name": "Execution I",
		"description": "Deal more damage against low-health targets.",
		"classes": [
			"melee"
		],
		"effect": "execution",
		"tier": 1,
		"requires": "",
		"weapons": [],
		"element": ""
	},
	{
		"id": "melee_execution_2",
		"name": "Execution II",
		"description": "Deal more damage against low-health targets.",
		"classes": [
			"melee"
		],
		"effect": "execution",
		"tier": 2,
		"requires": "melee_execution_1",
		"weapons": [],
		"element": ""
	},
	{
		"id": "melee_shockwave_1",
		"name": "Shockwave I",
		"description": "A melee cycle launches a piercing shockwave.",
		"classes": [
			"melee"
		],
		"effect": "shockwave",
		"tier": 1,
		"requires": "",
		"weapons": [
			"sword",
			"axe"
		],
		"element": ""
	},
	{
		"id": "melee_shockwave_2",
		"name": "Shockwave II",
		"description": "A melee cycle launches a piercing shockwave.",
		"classes": [
			"melee"
		],
		"effect": "shockwave",
		"tier": 2,
		"requires": "melee_shockwave_1",
		"weapons": [
			"sword",
			"axe"
		],
		"element": ""
	},
	{
		"id": "melee_knife_flurry_1",
		"name": "Knife Flurry I",
		"description": "Faster knife cycles and stronger stabbing.",
		"classes": [
			"melee"
		],
		"effect": "knife_flurry",
		"tier": 1,
		"requires": "",
		"weapons": [
			"knife"
		],
		"element": ""
	},
	{
		"id": "melee_knife_flurry_2",
		"name": "Knife Flurry II",
		"description": "Faster knife cycles and stronger stabbing.",
		"classes": [
			"melee"
		],
		"effect": "knife_flurry",
		"tier": 2,
		"requires": "melee_knife_flurry_1",
		"weapons": [
			"knife"
		],
		"element": ""
	},
	{
		"id": "melee_axe_crush_1",
		"name": "Axe Crush I",
		"description": "Stronger heavy axe swings.",
		"classes": [
			"melee"
		],
		"effect": "axe_crush",
		"tier": 1,
		"requires": "",
		"weapons": [
			"axe"
		],
		"element": ""
	},
	{
		"id": "melee_axe_crush_2",
		"name": "Axe Crush II",
		"description": "Stronger heavy axe swings.",
		"classes": [
			"melee"
		],
		"effect": "axe_crush",
		"tier": 2,
		"requires": "melee_axe_crush_1",
		"weapons": [
			"axe"
		],
		"element": ""
	},
	{
		"id": "melee_bloodguard_1",
		"name": "Bloodguard I",
		"description": "Block restores a small amount of HP.",
		"classes": [
			"melee"
		],
		"effect": "bloodguard",
		"tier": 1,
		"requires": "",
		"weapons": [],
		"element": ""
	},
	{
		"id": "ranger_rapid_1",
		"name": "Quickdraw I",
		"description": "Faster ranged attack cycles.",
		"classes": [
			"ranger"
		],
		"effect": "rapid",
		"tier": 1,
		"requires": "",
		"weapons": [],
		"element": ""
	},
	{
		"id": "ranger_rapid_2",
		"name": "Quickdraw II",
		"description": "Faster ranged attack cycles.",
		"classes": [
			"ranger"
		],
		"effect": "rapid",
		"tier": 2,
		"requires": "ranger_rapid_1",
		"weapons": [],
		"element": ""
	},
	{
		"id": "ranger_rapid_3",
		"name": "Quickdraw III",
		"description": "Faster ranged attack cycles.",
		"classes": [
			"ranger"
		],
		"effect": "rapid",
		"tier": 3,
		"requires": "ranger_rapid_2",
		"weapons": [],
		"element": ""
	},
	{
		"id": "ranger_pierce_1",
		"name": "Piercing Shot I",
		"description": "Add one penetrated target per step.",
		"classes": [
			"ranger"
		],
		"effect": "pierce",
		"tier": 1,
		"requires": "",
		"weapons": [],
		"element": ""
	},
	{
		"id": "ranger_pierce_2",
		"name": "Piercing Shot II",
		"description": "Add one penetrated target per step.",
		"classes": [
			"ranger"
		],
		"effect": "pierce",
		"tier": 2,
		"requires": "ranger_pierce_1",
		"weapons": [],
		"element": ""
	},
	{
		"id": "ranger_volley_1",
		"name": "Twin Shot I",
		"description": "Add an arrow or bolt to each volley.",
		"classes": [
			"ranger"
		],
		"effect": "volley",
		"tier": 1,
		"requires": "",
		"weapons": [
			"bow",
			"crossbow"
		],
		"element": ""
	},
	{
		"id": "ranger_volley_2",
		"name": "Twin Shot II",
		"description": "Add an arrow or bolt to each volley.",
		"classes": [
			"ranger"
		],
		"effect": "volley",
		"tier": 2,
		"requires": "ranger_volley_1",
		"weapons": [
			"bow",
			"crossbow"
		],
		"element": ""
	},
	{
		"id": "ranger_evasion_1",
		"name": "Trail Instinct I",
		"description": "Add trap-protection capacity and faster recharge.",
		"classes": [
			"ranger"
		],
		"effect": "evasion",
		"tier": 1,
		"requires": "",
		"weapons": [],
		"element": ""
	},
	{
		"id": "ranger_evasion_2",
		"name": "Trail Instinct II",
		"description": "Add trap-protection capacity and faster recharge.",
		"classes": [
			"ranger"
		],
		"effect": "evasion",
		"tier": 2,
		"requires": "ranger_evasion_1",
		"weapons": [],
		"element": ""
	},
	{
		"id": "ranger_pin_1",
		"name": "Pinning Shot I",
		"description": "Shots slow targets.",
		"classes": [
			"ranger"
		],
		"effect": "pin",
		"tier": 1,
		"requires": "",
		"weapons": [],
		"element": ""
	},
	{
		"id": "ranger_pin_2",
		"name": "Pinning Shot II",
		"description": "Shots slow targets.",
		"classes": [
			"ranger"
		],
		"effect": "pin",
		"tier": 2,
		"requires": "ranger_pin_1",
		"weapons": [],
		"element": ""
	},
	{
		"id": "ranger_ricochet_1",
		"name": "Ricochet I",
		"description": "Shots bounce to another nearby target.",
		"classes": [
			"ranger"
		],
		"effect": "ricochet",
		"tier": 1,
		"requires": "",
		"weapons": [],
		"element": ""
	},
	{
		"id": "ranger_ricochet_2",
		"name": "Ricochet II",
		"description": "Shots bounce to another nearby target.",
		"classes": [
			"ranger"
		],
		"effect": "ricochet",
		"tier": 2,
		"requires": "ranger_ricochet_1",
		"weapons": [],
		"element": ""
	},
	{
		"id": "ranger_execution_1",
		"name": "Hunter Focus I",
		"description": "Deal more damage to low-health targets.",
		"classes": [
			"ranger"
		],
		"effect": "execution",
		"tier": 1,
		"requires": "",
		"weapons": [],
		"element": ""
	},
	{
		"id": "ranger_execution_2",
		"name": "Hunter Focus II",
		"description": "Deal more damage to low-health targets.",
		"classes": [
			"ranger"
		],
		"effect": "execution",
		"tier": 2,
		"requires": "ranger_execution_1",
		"weapons": [],
		"element": ""
	},
	{
		"id": "ranger_explosive_1",
		"name": "Explosive Round I",
		"description": "Gun hits splash nearby targets.",
		"classes": [
			"ranger"
		],
		"effect": "explosive",
		"tier": 1,
		"requires": "",
		"weapons": [
			"gun"
		],
		"element": ""
	},
	{
		"id": "ranger_explosive_2",
		"name": "Explosive Round II",
		"description": "Gun hits splash nearby targets.",
		"classes": [
			"ranger"
		],
		"effect": "explosive",
		"tier": 2,
		"requires": "ranger_explosive_1",
		"weapons": [
			"gun"
		],
		"element": ""
	},
	{
		"id": "mage_spread_1",
		"name": "Spell Fan I",
		"description": "Fire a wider fan with higher total damage.",
		"classes": [
			"mage"
		],
		"effect": "spread",
		"tier": 1,
		"requires": "",
		"weapons": [],
		"element": ""
	},
	{
		"id": "mage_spread_2",
		"name": "Spell Fan II",
		"description": "Fire a wider fan with higher total damage.",
		"classes": [
			"mage"
		],
		"effect": "spread",
		"tier": 2,
		"requires": "mage_spread_1",
		"weapons": [],
		"element": ""
	},
	{
		"id": "mage_radial_1",
		"name": "Element Burst I",
		"description": "Add a radial spell burst.",
		"classes": [
			"mage"
		],
		"effect": "radial",
		"tier": 1,
		"requires": "",
		"weapons": [],
		"element": ""
	},
	{
		"id": "mage_radial_2",
		"name": "Element Burst II",
		"description": "Add a radial spell burst.",
		"classes": [
			"mage"
		],
		"effect": "radial",
		"tier": 2,
		"requires": "mage_radial_1",
		"weapons": [],
		"element": ""
	},
	{
		"id": "mage_familiar_1",
		"name": "Spirit Familiar I",
		"description": "An orbiting spirit attacks nearby enemies.",
		"classes": [
			"mage"
		],
		"effect": "familiar",
		"tier": 1,
		"requires": "",
		"weapons": [],
		"element": ""
	},
	{
		"id": "mage_ward_1",
		"name": "Waxing Ward I",
		"description": "Improve Mage Armor capacity and recharge.",
		"classes": [
			"mage"
		],
		"effect": "ward",
		"tier": 1,
		"requires": "",
		"weapons": [],
		"element": ""
	},
	{
		"id": "mage_ward_2",
		"name": "Waxing Ward II",
		"description": "Improve Mage Armor capacity and recharge.",
		"classes": [
			"mage"
		],
		"effect": "ward",
		"tier": 2,
		"requires": "mage_ward_1",
		"weapons": [],
		"element": ""
	},
	{
		"id": "mage_fire_1",
		"name": "Inferno I",
		"description": "Burn hits harder and spread to nearby enemies.",
		"classes": [
			"mage"
		],
		"effect": "fire",
		"tier": 1,
		"requires": "",
		"weapons": [],
		"element": "fire"
	},
	{
		"id": "mage_fire_2",
		"name": "Inferno II",
		"description": "Burn hits harder and spread to nearby enemies.",
		"classes": [
			"mage"
		],
		"effect": "fire",
		"tier": 2,
		"requires": "mage_fire_1",
		"weapons": [],
		"element": "fire"
	},
	{
		"id": "mage_ice_1",
		"name": "Deep Freeze I",
		"description": "Stronger and longer slowing effects.",
		"classes": [
			"mage"
		],
		"effect": "ice",
		"tier": 1,
		"requires": "",
		"weapons": [],
		"element": "ice"
	},
	{
		"id": "mage_ice_2",
		"name": "Deep Freeze II",
		"description": "Stronger and longer slowing effects.",
		"classes": [
			"mage"
		],
		"effect": "ice",
		"tier": 2,
		"requires": "mage_ice_1",
		"weapons": [],
		"element": "ice"
	},
	{
		"id": "mage_lightning_1",
		"name": "Storm Chain I",
		"description": "Chain to more targets.",
		"classes": [
			"mage"
		],
		"effect": "lightning",
		"tier": 1,
		"requires": "",
		"weapons": [],
		"element": "lightning"
	},
	{
		"id": "mage_lightning_2",
		"name": "Storm Chain II",
		"description": "Chain to more targets.",
		"classes": [
			"mage"
		],
		"effect": "lightning",
		"tier": 2,
		"requires": "mage_lightning_1",
		"weapons": [],
		"element": "lightning"
	},
	{
		"id": "mage_light_1",
		"name": "Radiance I",
		"description": "Pierce more targets and amplify Light damage.",
		"classes": [
			"mage"
		],
		"effect": "light",
		"tier": 1,
		"requires": "",
		"weapons": [],
		"element": "light"
	},
	{
		"id": "mage_light_2",
		"name": "Radiance II",
		"description": "Pierce more targets and amplify Light damage.",
		"classes": [
			"mage"
		],
		"effect": "light",
		"tier": 2,
		"requires": "mage_light_1",
		"weapons": [],
		"element": "light"
	},
	{
		"id": "dash_poison_1",
		"name": "Venom Knives I",
		"description": "Knife hits add bounded poison stacks.",
		"classes": [
			"dash"
		],
		"effect": "poison",
		"tier": 1,
		"requires": "",
		"weapons": [
			"dagger",
			"throwing_knife"
		],
		"element": ""
	},
	{
		"id": "dash_poison_2",
		"name": "Venom Knives II",
		"description": "Knife hits add bounded poison stacks.",
		"classes": [
			"dash"
		],
		"effect": "poison",
		"tier": 2,
		"requires": "dash_poison_1",
		"weapons": [
			"dagger",
			"throwing_knife"
		],
		"element": ""
	},
	{
		"id": "dash_bleed_1",
		"name": "Bloodletting I",
		"description": "Knife hits add bounded bleed stacks.",
		"classes": [
			"dash"
		],
		"effect": "bleed",
		"tier": 1,
		"requires": "",
		"weapons": [
			"dagger",
			"throwing_knife"
		],
		"element": ""
	},
	{
		"id": "dash_bleed_2",
		"name": "Bloodletting II",
		"description": "Knife hits add bounded bleed stacks.",
		"classes": [
			"dash"
		],
		"effect": "bleed",
		"tier": 2,
		"requires": "dash_bleed_1",
		"weapons": [
			"dagger",
			"throwing_knife"
		],
		"element": ""
	},
	{
		"id": "dash_echo_1",
		"name": "Shadow Dash I",
		"description": "Carry an extra dash charge.",
		"classes": [
			"dash"
		],
		"effect": "echo",
		"tier": 1,
		"requires": "",
		"weapons": [],
		"element": ""
	},
	{
		"id": "dash_length_1",
		"name": "Long Dash I",
		"description": "Extend dash duration without repeat damage.",
		"classes": [
			"dash"
		],
		"effect": "length",
		"tier": 1,
		"requires": "",
		"weapons": [],
		"element": ""
	},
	{
		"id": "dash_length_2",
		"name": "Long Dash II",
		"description": "Extend dash duration without repeat damage.",
		"classes": [
			"dash"
		],
		"effect": "length",
		"tier": 2,
		"requires": "dash_length_1",
		"weapons": [],
		"element": ""
	},
	{
		"id": "dash_push_1",
		"name": "Dash Impact I",
		"description": "Dash pushes uncommitted enemies away.",
		"classes": [
			"dash"
		],
		"effect": "push",
		"tier": 1,
		"requires": "",
		"weapons": [],
		"element": ""
	},
	{
		"id": "dash_push_2",
		"name": "Dash Impact II",
		"description": "Dash pushes uncommitted enemies away.",
		"classes": [
			"dash"
		],
		"effect": "push",
		"tier": 2,
		"requires": "dash_push_1",
		"weapons": [],
		"element": ""
	},
	{
		"id": "dash_execution_1",
		"name": "Assassination I",
		"description": "Stronger hits against injured targets.",
		"classes": [
			"dash"
		],
		"effect": "execution",
		"tier": 1,
		"requires": "",
		"weapons": [],
		"element": ""
	},
	{
		"id": "dash_execution_2",
		"name": "Assassination II",
		"description": "Stronger hits against injured targets.",
		"classes": [
			"dash"
		],
		"effect": "execution",
		"tier": 2,
		"requires": "dash_execution_1",
		"weapons": [],
		"element": ""
	},
	{
		"id": "dash_precision_1",
		"name": "Killer Instinct I",
		"description": "More critical chance and critical damage.",
		"classes": [
			"dash"
		],
		"effect": "precision",
		"tier": 1,
		"requires": "",
		"weapons": [],
		"element": ""
	},
	{
		"id": "dash_precision_2",
		"name": "Killer Instinct II",
		"description": "More critical chance and critical damage.",
		"classes": [
			"dash"
		],
		"effect": "precision",
		"tier": 2,
		"requires": "dash_precision_1",
		"weapons": [],
		"element": ""
	},
	{
		"id": "dash_recovery_1",
		"name": "Quick Recovery I",
		"description": "Dash charges recharge faster.",
		"classes": [
			"dash"
		],
		"effect": "recovery",
		"tier": 1,
		"requires": "",
		"weapons": [],
		"element": ""
	},
	{
		"id": "dash_recovery_2",
		"name": "Quick Recovery II",
		"description": "Dash charges recharge faster.",
		"classes": [
			"dash"
		],
		"effect": "recovery",
		"tier": 2,
		"requires": "dash_recovery_1",
		"weapons": [],
		"element": ""
	},
	{
		"id": "dash_flurry_1",
		"name": "Blade Flurry I",
		"description": "Faster melee attacks.",
		"classes": [
			"dash"
		],
		"effect": "flurry",
		"tier": 1,
		"requires": "",
		"weapons": [
			"dagger",
			"sword"
		],
		"element": ""
	},
	{
		"id": "dash_flurry_2",
		"name": "Blade Flurry II",
		"description": "Faster melee attacks.",
		"classes": [
			"dash"
		],
		"effect": "flurry",
		"tier": 2,
		"requires": "dash_flurry_1",
		"weapons": [
			"dagger",
			"sword"
		],
		"element": ""
	},
	{
		"id": "dash_fan_1",
		"name": "Knife Fan I",
		"description": "Throw additional knives in a narrow fan.",
		"classes": [
			"dash"
		],
		"effect": "fan",
		"tier": 1,
		"requires": "",
		"weapons": [
			"throwing_knife"
		],
		"element": ""
	},
	{
		"id": "dash_fan_2",
		"name": "Knife Fan II",
		"description": "Throw additional knives in a narrow fan.",
		"classes": [
			"dash"
		],
		"effect": "fan",
		"tier": 2,
		"requires": "dash_fan_1",
		"weapons": [
			"throwing_knife"
		],
		"element": ""
	}
]
const EQUIPMENT_NAMES = ["Dewdrop Blade","Bramble Bow","Moonstone Wand","Comet Boots","Heartwood Buckler","Ember Pendant","Crystal Circlet","Nightfall Cloak","Lucky Acorn","Starfall Ring","Sunlit Gauntlets","Windchime Charm"]
const COSMETICS = [
 {"id":"meadow","name":"Original Orange","color":Color.WHITE,"stage":0},
 {"id":"ember","name":"Ember Glow","color":Color("ffaf77"),"stage":5},
 {"id":"crystal","name":"Crystal Blue","color":Color("8cdfff"),"stage":10},
 {"id":"night","name":"Royal Starlight","color":Color("d4a4ff"),"stage":20},
 {"id":"storm","name":"Storm Gold","color":Color("ffe09c"),"stage":25},
 {"id":"eclipse","name":"Eclipse Silver","color":Color("d5deff"),"stage":30}
]
