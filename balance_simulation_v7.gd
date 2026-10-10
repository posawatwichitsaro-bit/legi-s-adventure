extends "res://balance_simulation_v6.gd"

# Real-combat v7 branch comparison, sharing the v6 movement/navigation probe.
# Legal mode uses prior-stage XP and actual three-choice offers. Stress mode
# deliberately grants every compatible rank before combat and is NOT a build
# that the campaign can necessarily acquire. No combat HP/damage injection.
const V7_BRANCHES = {
	"blade_base": {"build":0,"ability":"","prefer":[]},
	"blade_thrust": {"build":0,"ability":"blade_thrust","prefer":["blade_thrust","farshot","long_reach"]},
	"blade_cleave": {"build":0,"ability":"blade_cleave","prefer":["blade_cleave","duelist","quick_hands"]},
	"blade_sweep": {"build":0,"ability":"blade_sweep","prefer":["blade_sweep","keen_edge","long_reach"]},
	"ranger_base": {"build":1,"ability":"","prefer":[]},
	"ranger_rapid": {"build":1,"ability":"ranger_rapid","prefer":["ranger_rapid","ranger_evasion","keen_edge"]},
	"ranger_fan": {"build":1,"ability":"ranger_fan","prefer":["ranger_fan","split_shot","ranger_evasion"]},
	"ranger_evasion": {"build":1,"ability":"ranger_evasion","prefer":["ranger_evasion","ranger_rapid","ranger_fan"]},
	"moon_base": {"build":2,"ability":"","prefer":[]},
	"moon_spread": {"build":2,"ability":"moon_spread","prefer":["moon_spread","moon_ward","moon_harvest"]},
	"moon_radial": {"build":2,"ability":"moon_radial","prefer":["moon_radial","moon_ward","quick_hands"]},
	"moon_fire": {"build":2,"ability":"moon_fire","prefer":["moon_fire","moon_ward","starlight"]},
	"moon_familiar": {"build":2,"ability":"moon_familiar","prefer":["moon_familiar","moon_ward","moon_harvest"]},
	"moon_ward": {"build":2,"ability":"moon_ward","prefer":["moon_ward","moon_fire","moon_familiar"]},
	"comet_base": {"build":3,"ability":"","prefer":[]},
	"comet_echo": {"build":3,"ability":"comet_echo","prefer":["comet_echo","second_wind","comet_tail"]},
	"comet_length": {"build":3,"ability":"comet_length","prefer":["comet_length","second_wind","comet_echo"]},
	"comet_poison": {"build":3,"ability":"comet_poison","prefer":["comet_poison","comet_echo","comet_length"]},
	"comet_push": {"build":3,"ability":"comet_push","prefer":["comet_push","comet_echo","comet_length"]},
}
var stress = false
var selected_targets: Array = [5,10,15,20]
var combat_dash_attempts = 0

func build_index() -> int:
	return int(V7_BRANCHES[mode].build)

func starting_ability() -> String:
	return str(V7_BRANCHES[mode].ability)

func upgrade_score(id: String) -> float:
	if id.is_empty():return -1000.0
	var preferred: Array = V7_BRANCHES[mode].prefer
	if id in preferred:return 1000.0-preferred.find(id)*10.0
	var shared = ["life_drain","stone_skin","spring_water","keen_edge","quick_hands","duelist","farshot","long_reach","heartwood","windstep","treasure_magnet","second_wind"]
	if id in shared:return 500.0-shared.find(id)*10.0
	return 100.0

func move_player(_dt: float):
	if controller_tick%10==0:navigation_direction=choose_kite_direction()
	controller_tick+=1
	var desired=navigation_direction
	set_movement_input(desired)
	if game.dash_left>0:return
	var target=game.nearest_enemy(game.player)
	if target==null:return
	var distance=game.player.distance_to(target.pos)
	if game.dash_charges<=0:return
	if game.selected_class==3 and distance<125 and visible_segment(game.player,target.pos,12):
		set_movement_input((target.pos-game.player).normalized())
		game.facing=(target.pos-game.player).normalized()
		combat_dash_attempts+=1
		game.dash()
	elif distance<42:
		game.facing=desired
		combat_dash_attempts+=1
		game.dash()

func combat_distance() -> float:
	if game.selected_class in [1,2]:return 205.0
	return clampf(game.melee_range()*(0.55 if game.selected_class==3 else 0.68),40.0,105.0)

func fight() -> Dictionary:
	combat_dash_attempts=0
	var entry_shield = game.shield
	var entry_ranks = game.tactic_ranks.duplicate(true)
	var result = super.fight()
	result["branch"] = mode
	result["entry_ranks"] = entry_ranks
	result["exit_ranks"] = game.tactic_ranks.duplicate(true)
	result["entry_shield"] = entry_shield
	result["end_shield"] = game.shield
	result["exit_stats"] = game.stats.duplicate(true)
	result["end_trap_charges"] = game.trap_charges
	result["end_dash_charges"] = game.dash_charges
	result["dash_attempts"] = combat_dash_attempts
	result["adversarial_max_stack"] = stress
	if stress:result["entry_setup"]="adversarial_compatible_rank_stress"
	return result

func grant_stress_ranks():
	# Iteration uses the real application/eligibility gate. Exclusive melee
	# styles cannot all be accepted, even under this adversarial request.
	for upgrade in game.D.TACTICS:
		for attempt in range(int(upgrade.cap)+3):game.apply_tactic(upgrade.id)
	game.hp=game.stats.max_hp
	game.ClassProgression.reset_stage(game)

func run_benchmark():
	var seeds: Array = [1760,2026,4511]
	var modes: Array = V7_BRANCHES.keys()
	movement="kite"
	for arg in OS.get_cmdline_user_args():
		if arg=="--campaign":campaign=true
		if arg=="--stress":stress=true
		if arg.begins_with("--output="):output_path=arg.trim_prefix("--output=")
		if arg.begins_with("--seed="):seeds=[int(arg.trim_prefix("--seed="))]
		if arg.begins_with("--seeds="):
			seeds=[]
			for value in arg.trim_prefix("--seeds=").split(","):seeds.append(int(value))
		if arg.begins_with("--modes="):modes=Array(arg.trim_prefix("--modes=").split(","))
		if arg.begins_with("--targets="):
			selected_targets=[]
			for value in arg.trim_prefix("--targets=").split(","):selected_targets.append(int(value))
	for candidate in modes:
		if not V7_BRANCHES.has(candidate):
			push_error("Unknown v7 branch: "+candidate);quit(2);return
	if stress and campaign:
		push_error("Stress loadouts cannot be reported as natural campaigns");quit(2);return
	for run_seed in seeds:
		seed_value=run_seed
		for strategy in modes:
			mode=strategy
			if campaign:
				run_campaign(run_seed)
				continue
			for target in selected_targets:
				new_game(build_index(),starting_ability(),run_seed)
				grant_prior_stages(target)
				if stress:grant_stress_ranks()
				var result=fight()
				rows.append(result)
				print("BALANCE_V7 ",JSON.stringify(result))
	if output_path!="":
		var file=FileAccess.open(output_path,FileAccess.WRITE)
		if file==null:
			push_error("Cannot open benchmark output: "+output_path);quit(2);return
		file.store_string(JSON.stringify({"method":method_description(),"rows":rows},"  "))
	set_movement_input(Vector2.ZERO)
	if is_instance_valid(game):game.free()
	quit()

func method_description() -> Dictionary:
	var description=super.method_description()
	description["version"]="v7 actual combat; inherits v6 movement/navigation and measurement"
	description["choices"]="Each named branch starts with its rank-one ability (an unlocked starting ability) and prioritizes that branch among actual random offers, then common sustain/damage. Base policies start without an ability. Other compatible branches can appear as lower-priority legal fallback choices. Entry and exit ranks are recorded."
	description["controls"]="Same eight-direction physical-key controller for all classes at 12 Hz, 120 Hz combat, actual collisions and telegraph avoidance. Sword/dagger stand at their real reach; bow/staff aim at 205 pixels. Comet dashes offensively inside 125 pixels and uses only available charges. Ranger trap evasion remains passive in the unmodified hazard code. Other classes emergency-dash below 42 pixels."
	description["stress"]="Every compatible upgrade is requested beyond its cap before combat; rejected ranks stay rejected. This intentionally unattainable loadout probes caps and multiplicative interactions, not campaign progression." if stress else "No adversarial grants."
	description["matching"]="Every branch uses the identical listed seed and target-stage arena seed; map geometry, initial roster and stage match. Legal class progression, random reward pools and later RNG consumption naturally differ."
	description["shield_measurement"]="Damage counter is actual health lost after shield absorption; shield left is reported separately. This counter is not incoming raw damage or total effective damage."
	description["limitations"]="Small seeded automated sample; exact telegraph knowledge favors the controller. Approximate movement may stall and fixed 240-second observations retain living timeouts. Healthy-entry and stress encounters do not establish prior-stage survival, campaign completion, human win rates, or definitive class balance. Natural campaign observations are separately marked."
	return description
