extends SceneTree

# Headless, seeded balance benchmark. Combat always uses unmodified main.gd
# damage/enemy/projectile/healing code; only ordinary movement is automated.
# Earlier-stage setup grants only the exact XP dropped by those stages and
# chooses from the game's real three-button upgrade/relic offers.
# No killed enemies, inflated health, or damage immunity are used in combat.
const TARGETS = [5, 10, 15, 20]
const DT = 1.0 / 120.0
const LIMIT = 120.0
var game
var history: Array = []
var gear: Array = []
var direction = 1.0
var mode = "farshot"
var movement = "horizontal"
var seed_value = 0
var output_path = ""
var rows: Array = []
var campaign = false
var controller_tick = 0
var navigation_direction = Vector2.RIGHT

func _initialize():
	call_deferred("run_benchmark")

func new_game(build: int, ability: String, run_seed: int):
	if is_instance_valid(game):
		game.free()
	seed(run_seed)
	game = load("res://main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_process(false)
	game.rng.seed = run_seed
	game.selected_build = build
	game.selected_ability = ability
	game.profile.sfx = false
	game.profile.shake = false
	game.start_run()
	history = [{"level":1,"id":ability,"source":"starting ability"}]
	gear = []
	direction = 1.0
	controller_tick = 0
	navigation_direction = Vector2.RIGHT

func upgrade_score(id: String) -> float:
	var order = ["farshot","long_reach","duelist","quick_hands","keen_edge","windstep","split_shot","starlight","moon_harvest","spring_water","stone_skin","heartwood","meteor_boots","comet_tail","second_wind","treasure_magnet","life_drain"]
	if mode == "drain":
		order = ["farshot","long_reach","duelist","quick_hands","keen_edge","spring_water","stone_skin","windstep","split_shot","starlight","moon_harvest","heartwood","meteor_boots","comet_tail","second_wind","treasure_magnet","life_drain"]
	if mode == "mage":
		order = ["moon_harvest","starlight","duelist","quick_hands","keen_edge","farshot","long_reach","split_shot","spring_water","stone_skin","heartwood","windstep","meteor_boots","comet_tail","second_wind","treasure_magnet","life_drain"]
	if mode == "dash":
		order = ["comet_tail","meteor_boots","second_wind","duelist","keen_edge","quick_hands","farshot","long_reach","windstep","split_shot","starlight","moon_harvest","spring_water","stone_skin","heartwood","treasure_magnet","life_drain"]
	if mode == "ranger":
		order = ["duelist","quick_hands","keen_edge","split_shot","farshot","long_reach","starlight","moon_harvest","windstep","spring_water","stone_skin","heartwood","meteor_boots","comet_tail","second_wind","treasure_magnet","life_drain"]
	# First prefer our targeted damage/speed/range build, but never knowingly
	# spend a reward entirely above an effective stat ceiling.
	var useful=false
	var limited=game.D.get_script_constant_map().get("STAT_LIMITS",{})
	for upgrade in game.D.UPGRADES:
		if upgrade.id!=id:continue
		var changes=game.upgrade_changes(upgrade) if game.has_method("upgrade_changes") else upgrade.stats
		for key in changes:
			var before=float(game.stats.get(key,0))
			var after=before+float(changes[key])
			if limited.has(key):after=clampf(after,limited[key][0],limited[key][1])
			if absf(after-before)>0.001:useful=true
	return (100.0 - order.find(id)) if useful else -100.0 - order.find(id)

func resolve_modal():
	if game.state == "upgrade":
		var box = game.panel.get_child(1)
		var best = null
		var best_score = -INF
		var best_id = ""
		for child in box.get_children():
			if not child is Button:continue
			var id = ""
			for upgrade in game.D.UPGRADES:
				if child.text.begins_with(upgrade.name):id = upgrade.id;break
			var score = upgrade_score(id)
			if score > best_score:best_score=score;best=child;best_id=id
		if best == null:
			push_error("No legal upgrade button");quit(2);return
		history.append({"level":game.level,"id":best_id,"source":"three offered upgrades"})
		best.pressed.emit()
	elif game.state == "loot":
		var box = game.panel.get_child(1)
		var best = null
		var best_score = -INF
		for child in box.get_children():
			if not child is Button:continue
			var score = 0.0
			# Value actual displayed two-stat relics; favor sword reach/speed/damage.
			for term in child.text.split("\n")[-1].split("/"):
				var part = term.strip_edges().trim_prefix("+")
				var amount = part.to_float()
				if "attack speed" in part:score += amount * 45
				elif "damage" in part:score += amount * 1.5
				elif "range" in part:score += amount * 0.6
				elif "speed" in part:score += amount * 0.15
				elif "armor" in part:score += amount * 1.5
				elif "regen" in part:score += amount * 3
				elif "max hp" in part:score += amount * 0.04
			if score > best_score:best_score=score;best=child
		if best == null:
			push_error("No legal loot button");quit(2);return
		gear.append({"stage":game.stage,"description":best.text})
		best.pressed.emit()

func grant_prior_stages(target: int):
	# This setup is not a survival result: stages before target are represented
	# solely by their exact XP and one normal reward offer per guardian.
	for previous in range(1,target):
		game.stage = previous
		game.start_stage()
		var values: Array = []
		for enemy in game.enemies:
			values.append((2.0+floor((previous-1)/5.0))*(12 if enemy.kind=="boss" else 1))
		for value in values:
			game.gain_xp(value)
			while game.pending_choices > 0:
				game.show_upgrades();resolve_modal()
		if previous % 5 == 0:
			game.show_loot();resolve_modal()
	game.stage = target
	game.rng.seed=100000+seed_value*100+target
	game.start_stage()
	game.hp = game.stats.max_hp # Healthy-entry encounter, explicitly reported.

func move_player(dt: float):
	var desired = Vector2(direction,0)
	if movement == "kite":
		if controller_tick % 10 == 0:navigation_direction=choose_kite_direction()
		controller_tick+=1
		desired=navigation_direction
		game.facing=desired
		var target=game.nearest_enemy(game.player)
		if target != null and game.dash_cd<=0:
			var distance=game.player.distance_to(target.pos)
			if mode=="dash" and distance<110:
				game.facing=(target.pos-game.player).normalized()
				game.dash()
			elif distance<42:game.dash()
		if game.dash_left>0:return
	elif movement == "pursue":
		var target = game.nearest_enemy(game.player)
		if target != null:desired=(target.pos-game.player).normalized()
	elif game.player.x >= 865:direction=-1;desired=Vector2.LEFT
	elif game.player.x <= 95:direction=1;desired=Vector2.RIGHT
	var next = game.move_actor(game.player,desired*game.stats.speed*dt,12)
	if next.distance_to(game.player)<game.stats.speed*dt*0.2 and movement == "horizontal":
		direction *= -1
		desired = Vector2(direction,0)
		next=game.move_actor(game.player,desired*game.stats.speed*dt,12)
	game.player=next
	game.facing=desired

func fight() -> Dictionary:
	var started = game.stage
	var initial = game.stats.duplicate(true)
	var entry_level = game.level
	var entry_xp = game.xp
	var start_hp = game.hp
	var min_hp = game.hp
	var seconds = 0.0
	var initial_enemies = game.enemies.size()
	var clear_time = -1.0
	var actions_before = history.duplicate(true)
	var relics_before = gear.duplicate(true)
	while seconds < LIMIT and game.hp > 0 and game.stage == started:
		if game.state in ["upgrade","loot"]:
			resolve_modal();continue
		if game.state != "playing":break
		if game.enemies.is_empty():
			clear_time=seconds;break
		move_player(DT)
		game.simulate(DT)
		seconds += DT
		min_hp=minf(min_hp,game.hp)
	return {"seed":seed_value,"build":game.D.BUILDS[game.selected_build].id,"strategy":mode,"movement":movement,"stage":started,"entry_level":entry_level,"entry_xp":entry_xp,"entry_stats":initial,"entry_hp":start_hp,"clear_seconds":clear_time,"seconds_observed":seconds,"cleared":clear_time>=0,"survived":game.hp>0,"entry_setup":"natural_campaign" if campaign else "healthy_entry_encounter","arena_seed":null if campaign else 100000+seed_value*100+started,"outcome":"cleared" if clear_time>=0 else ("died" if game.hp<=0 else "timeout"),"end_hp":game.hp,"minimum_hp":min_hp,"enemies_remaining":game.enemies.size(),"initial_enemies":initial_enemies,"upgrades":actions_before,"gear":relics_before}

func run_benchmark():
	var args = OS.get_cmdline_user_args()
	var seeds = [1760,2026,4511,7727,9981]
	var modes = ["farshot"]
	for arg in args:
		if arg == "--campaign":campaign=true
		if arg.begins_with("--output="):output_path=arg.trim_prefix("--output=")
		if arg.begins_with("--seed="):seeds=[int(arg.trim_prefix("--seed="))]
		if arg.begins_with("--modes="):modes=Array(arg.trim_prefix("--modes=").split(","))
		if arg.begins_with("--movement="):movement=arg.trim_prefix("--movement=")
	for run_seed in seeds:
		seed_value=run_seed
		for strategy in modes:
			mode=strategy
			if campaign:
				run_campaign(run_seed)
				continue
			for target in TARGETS:
				new_game(build_index(),starting_ability(),run_seed)
				grant_prior_stages(target)
				var result=fight()
				rows.append(result)
				print("BALANCE ",JSON.stringify(result))
	if output_path != "":
		var f=FileAccess.open(output_path,FileAccess.WRITE)
		f.store_string(JSON.stringify({"method":method_description(),"rows":rows},"  "))
	if is_instance_valid(game):game.free()
	quit()

func run_campaign(run_seed: int):
	new_game(build_index(),starting_ability(),run_seed)
	while game.state != "won" and game.hp > 0:
		var result=fight()
		rows.append(result)
		print("CAMPAIGN ",JSON.stringify(result))
		if not result.cleared:break
		var stage_before=game.stage
		var ticks=0
		while game.stage==stage_before and game.state!="won" and ticks<2400:
			if game.state in ["upgrade","loot"]:resolve_modal();continue
			# Portal travel is skipped only once combat and all loot have ended.
			# start_stage places the player at this same center for the next fight.
			if game.portal_open:game.player=game.CENTER
			game.simulate(DT)
			ticks+=1
		if ticks>=2400:push_error("Post-combat transition stuck");break

func choose_kite_direction() -> Vector2:
	var target=game.nearest_enemy(game.player)
	if target==null:return Vector2.ZERO
	var ideal=clampf(game.stats.range*0.68,55,105)
	var best_score=-INF
	var best=Vector2.ZERO
	for choice in range(25):
		var heading=Vector2.RIGHT.rotated(float(choice)*TAU/24) if choice<24 else Vector2.ZERO
		var candidate=game.move_actor(game.player,heading*game.stats.speed*0.24,12)
		var distance=candidate.distance_to(target.pos)
		var score=-absf(distance-ideal)*0.18
		if heading != Vector2.ZERO and candidate.distance_to(game.player)<game.stats.speed*0.12:score-=35
		for enemy in game.enemies:
			if enemy.hp<=0:continue
			var predicted=enemy.pos+(game.player-enemy.pos).normalized()*(45+game.stage*1.8)*0.18
			var separation=candidate.distance_to(predicted)
			if separation<95:score-=pow((95-separation)/15,2)
			if separation<35:score-=200
		for bullet in game.bullets:
			if bullet.friendly:continue
			var offset=candidate-bullet.pos
			var ahead=clampf(offset.dot(bullet.vel)/bullet.vel.length_squared(),0,0.4)
			var near=candidate.distance_to(bullet.pos+bullet.vel*ahead)
			if near<35:score-=(35-near)*2
		var edge=minf(minf(candidate.x-45,915-candidate.x),minf(candidate.y-125,555-candidate.y))
		if edge<28:score-=28-edge
		if score>best_score:best_score=score;best=heading
	return best

func build_index() -> int:
	return {"ranger":1,"mage":2,"dash":3}.get(mode,0)

func starting_ability() -> String:
	return {"drain":"life_drain","mage":"starlight","dash":"comet_tail"}.get(mode,"farshot")

func method_description() -> Dictionary:
	return {
		"progression":"Natural full run: real attacks, XP, drops and healing; no injected kills or health resets. Automatic center-portal entry only after combat and all rewards." if campaign else "Independent healthy-entry encounters: preceding stages supply their exact total dropped XP and legal random three-option rewards. HP is set to normal maximum at entry. No injected kills or HP changes in measured combat; this is not a prior-stage survival result.",
		"simulation_hz":120,
		"stage_time_limit_seconds":LIMIT,
		"movement":movement,
		"controls":"Kiting with ordinary collision movement, bullet avoidance, and normal emergency dash. Dash build also dashes offensively." if movement=="kite" else "Ordinary collision movement; no dash. Horizontal reverses at arena edges/obstacles; pursue follows the closest enemy.",
		"choices":"Greedy damage/speed/range strategy chooses only from actual offered buttons; wholly ineffective upgrades are deprioritized. Relics selected from actual three offers.",
		"outcomes":"Cleared, died, or still alive at the 120-second timeout. A timeout is not a death; clear-time medians exclude timeouts/deaths.",
		"limitations":"Small seeded automated sample, not a human difficulty assessment. Obstacle/controller stalls can leave surviving enemies. Old/new offers differ because RNG implementation and eligible pools changed; independent encounter arena geometry is matched by arena_seed."
	}
