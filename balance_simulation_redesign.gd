extends SceneTree

# Headless, seeded balance benchmark. Combat always uses unmodified main.gd
# damage/enemy/projectile/healing code; only ordinary movement is automated.
# Earlier-stage setup grants only the exact XP dropped by those stages and
# chooses from the game's real three-button upgrade/relic offers.
# No killed enemies, inflated health, or damage immunity are used in combat.
const TARGETS = [5, 10, 15, 20]
const DT = 1.0 / 120.0
const LIMIT = 240.0
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
var navigation_grid: AStarGrid2D
var navigation_stage = -1
var navigation_path = PackedVector2Array()
var path_target = Vector2.INF
const GRID_STEP = 14.0
var grid_origin = Vector2(46,126)
var grid_columns = 63
var grid_rows = 31
var pressed_keys: Dictionary = {}

func _initialize():
	call_deferred("run_benchmark")

func new_game(build: int, option: String, run_seed: int):
	set_movement_input(Vector2.ZERO)
	if is_instance_valid(game):game.free()
	game=load("res://balance_probe.gd").new();game.test_mode=true
	root.add_child(game);game.set_process(false)
	game.rng.seed=run_seed;game.selected_class=build;game.selected_option=option
	game.profile.sfx=false;game.profile.shake=false;game.start_run()
	history=[];gear=[];direction=1;controller_tick=0;navigation_direction=Vector2.RIGHT
	navigation_stage=-1;navigation_path.clear();path_target=Vector2.INF

func upgrade_score(id: String) -> float:
	var order=["life_drain","long_reach","spring_water","keen_edge","quick_hands","stone_skin","heartwood","critical_eye","duelist","ward","evasive_steps","deadly_precision","windstep"]
	if game.selected_class==2:order=["life_drain","ward","heartwood","spring_water","quick_hands","stone_skin","resilient_ward","vitality","keen_edge","critical_eye","duelist"]
	if id.begins_with("switch_"):return -1000
	return 500-order.find(id)*5 if id in order else 100

func resolve_modal():
	if game.state=="skill":
		var best=null;var best_score=-INF;var selected=""
		for child in game.panel.get_child(1).get_children():
			if not child is Button:continue
			for skill in game.D.SKILLS:
				if not child.text.begins_with(skill.name+"\n"):continue
				var priorities=["extra_attack","spread","poison","bleed","rapid","volley","ricochet","lightning","light","ward","shockwave","execution","familiar","reach","axe_crush","knife_flurry","fan"]
				var score=500-priorities.find(skill.effect)*10 if skill.effect in priorities else 100
				if score>best_score:best=child;best_score=score;selected=skill.id
		if best==null:push_error("Skill panel missing legal choice");quit(2);return
		history.append({"stage":game.stage,"id":selected,"source":"offered Skill"});best.pressed.emit()
		return
	if game.state=="tactic":
		var best=null;var best_score=-INF;var selected=""
		for child in game.panel.get_child(1).get_children():
			if not child is Button:continue
			for tactic in game.D.TACTICS:
				if child.text.begins_with(tactic.name+"\n") and upgrade_score(tactic.id)>best_score:
					best=child;best_score=upgrade_score(tactic.id);selected=tactic.id
		if best==null:
			var buttons=game.panel.find_children("*","Button",true,false)
			if buttons.is_empty():push_error("Tactic panel missing choice");quit(2);return
			best=buttons[0]
		history.append({"level":game.level,"id":selected,"source":"offered Tactic"});best.pressed.emit()
		return
	if game.state=="loot":
		var best=null;var best_score=-INF
		for child in game.panel.get_child(1).get_children():
			if not child is Button:continue
			var score=0.0
			for term in child.text.split("\n")[-1].split("/"):
				var amount=term.strip_edges().trim_prefix("+").to_float()
				if "damage" in term:score+=amount*1.5
				elif "range" in term:score+=amount*.6
				elif "attack speed" in term:score+=amount*40
				elif "regen" in term:score+=amount*10
				elif "max hp" in term:score+=amount*.1
				else:score+=amount*.2
			if score>best_score:best=child;best_score=score
		if best==null:push_error("Equipment panel missing choice");quit(2);return
		gear.append({"stage":game.stage,"description":best.text});best.pressed.emit()

func grant_prior_stages(target: int):
	# This setup is not a survival result: stages before target are represented
	# solely by their exact XP and one normal reward offer per guardian.
	for previous in range(1,target):
		game.stage = previous
		game.start_stage()
		var values: Array = []
		# Count both live and queued enemies. The guardian is worth 12 crystals.
		var total = full_remaining()
		for index in range(total):
			values.append((2.0+floor((previous-1)/5.0))*(12 if previous%5==0 and index==total-1 else 1))
		for value in values:
			game.gain_xp(value)
			while game.pending_choices > 0:
				game.show_tactics();resolve_modal()
		if previous % 5 == 0:
			game.PlayerSkills.offer(game);resolve_modal()
			game.show_loot();resolve_modal()
	game.stage = target
	game.rng.seed=100000+seed_value*100+target
	game.start_stage()
	game.hp = game.stats.max_hp # Healthy-entry encounter, explicitly reported.

func set_movement_input(desired: Vector2):
	# Exercise the actual physical-key path in simulate(), at the same normal
	# speed and collision radius as a player. No positions are injected here.
	var next = {KEY_A:desired.x < -0.25, KEY_D:desired.x > 0.25,
		KEY_W:desired.y < -0.25, KEY_S:desired.y > 0.25}
	for key in next:
		if bool(pressed_keys.get(key,false)) == bool(next[key]):continue
		var event = InputEventKey.new()
		event.physical_keycode=key
		event.keycode=key
		event.pressed=next[key]
		Input.parse_input_event(event)
	Input.flush_buffered_events()
	pressed_keys=next

func move_player(dt: float):
	var desired = Vector2(direction,0)
	if movement == "kite":
		if controller_tick % 10 == 0:navigation_direction=choose_kite_direction()
		controller_tick+=1
		desired=navigation_direction
		set_movement_input(desired)
		if game.dash_left>0:return
		var target=game.nearest_enemy(game.player)
		if target != null and game.dash_cd<=0:
			var distance=game.player.distance_to(target.pos)
			if game.selected_class==3 and distance<110 and visible_segment(game.player,target.pos,12):
				set_movement_input((target.pos-game.player).normalized())
				game.facing=(target.pos-game.player).normalized()
				game.dash()
			elif distance<42:
				game.facing=desired
				game.dash()
		return
	elif movement == "pursue":
		var target = game.nearest_enemy(game.player)
		if target != null:desired=(target.pos-game.player).normalized()
	elif game.player.x >= game.ARENA.end.x-63:direction=-1;desired=Vector2.LEFT
	elif game.player.x <= game.ARENA.position.x+63:direction=1;desired=Vector2.RIGHT
	# Historical lateral controller deliberately remains unchanged.
	var next = game.move_actor(game.player,desired*game.stats.speed*dt,12)
	if next.distance_to(game.player)<game.stats.speed*dt*0.2 and movement == "horizontal":
		direction *= -1
		desired = Vector2(direction,0)
		next=game.move_actor(game.player,desired*game.stats.speed*dt,12)
	game.player=next
	game.facing=desired

func fight() -> Dictionary:
	game.measured_boss_starts.clear()
	game.measured_boss_releases.clear()
	var started = game.stage
	var initial = game.stats.duplicate(true)
	var entry_level = game.level
	var entry_xp = game.xp
	var start_hp = game.hp
	var start_damage = game.measured_damage_taken
	var start_hits = game.measured_hits
	var min_hp = game.hp
	var seconds = 0.0
	var initial_enemies = full_remaining()
	var peak_active = game.enemies.size()
	var kills_before = game.kills
	var observed_hazards: Dictionary = {}
	var released_hazards: Dictionary = {}
	var touched_hazards: Dictionary = {}
	var clear_time = -1.0
	var actions_before = history.duplicate(true)
	var equipment_before = gear.duplicate(true)
	var entry_weapon=game.primary_weapon() if game.has_method("primary_weapon") else "sword"
	var total_travel=0.0
	while seconds < LIMIT and game.hp > 0 and game.stage == started:
		if game.state in ["tactic","skill","loot"]:
			resolve_modal();continue
		if game.state != "playing":break
		if full_remaining()==0:
			clear_time=seconds;break
		var before_position=game.player
		move_player(DT)
		game.simulate(DT)
		total_travel+=before_position.distance_to(game.player)
		seconds += DT
		peak_active=maxi(peak_active,game.enemies.size())
		if game.has_method("remaining_enemies") and game.stage==started:
			for hazard in game.world_data.get("hazards",[]):
				observed_hazards[hazard.serial]=true
				if hazard.state=="active":released_hazards[hazard.serial]=true
				if hazard.hit:touched_hazards[hazard.serial]=true
		min_hp=minf(min_hp,game.hp)
		if game.hp>0 and (game.stage!=started or game.state=="won"):
			clear_time=seconds
			break
	var remaining: Array=[]
	for enemy in game.enemies:
		remaining.append({"kind":enemy.kind,"hp":enemy.hp,"position":[enemy.pos.x,enemy.pos.y],"line_of_sight":visible_segment(game.player,enemy.pos,3)})
	return {"debug_navigation":{ "path":str(navigation_path), "obstacles":str(game.obstacles), "waypoint":str(obstacle_waypoint(game.enemies[0].pos)) if not game.enemies.is_empty() else ""} if clear_time<0 else {},"entry_weapon":entry_weapon,"travel_pixels":total_travel,"end_position":[game.player.x,game.player.y],"remaining_enemy_details":remaining,"seed":seed_value,"build":game.D.CLASSES[game.selected_class].id,"strategy":mode,"movement":movement,"stage":started,"entry_level":entry_level,"entry_xp":entry_xp,"entry_stats":initial,"entry_hp":start_hp,"clear_seconds":clear_time,"seconds_observed":seconds,"cleared":clear_time>=0,"survived":game.hp>0,"entry_setup":"natural_campaign" if campaign else "healthy_entry_encounter","arena_seed":null if campaign else 100000+seed_value*100+started,"outcome":"cleared" if clear_time>=0 else ("died" if game.hp<=0 else "timeout"),"boss_moves_started":game.measured_boss_starts.duplicate(),"boss_moves_released":game.measured_boss_releases.duplicate(),"damage_taken":game.measured_damage_taken-start_damage,"hits_taken":game.measured_hits-start_hits,"end_hp":game.hp,"minimum_hp":min_hp,"enemies_remaining":full_remaining(),"active_enemies_remaining":game.enemies.size(),"queued_enemies_remaining":full_remaining()-game.enemies.size(),"peak_active_enemies":peak_active,"environment_hazards_spawned":observed_hazards.size(),"environment_hazards_released":released_hazards.size(),"environment_hazard_contacts":touched_hazards.size(),"actual_kills":game.kills-kills_before,"initial_enemies":initial_enemies,"upgrades":actions_before,"gear":equipment_before}

func run_benchmark():
	var modes=["0:sword","1:bow","2:fire","3:dagger"]
	var targets=[5,25,30];var seeds=[1760]
	movement="kite";campaign=true
	for arg in OS.get_cmdline_user_args():
		if arg=="--encounters":campaign=false
		if arg.begins_with("--modes="):modes=Array(arg.trim_prefix("--modes=").split(","))
		if arg.begins_with("--output="):output_path=arg.trim_prefix("--output=")
		if arg.begins_with("--seed="):seeds=[int(arg.trim_prefix("--seed="))]
		if arg.begins_with("--targets="):
			targets=[]
			for value in arg.trim_prefix("--targets=").split(","):targets.append(int(value))
	for value in seeds:
		seed_value=value
		for strategy in modes:
			mode=strategy
			if campaign:run_campaign(value)
			else:
				for target in targets:
					new_game(build_index(),starting_ability(),value);grant_prior_stages(target)
					var result=fight();result["mode"]=mode;result["skills"]=game.learned_skills.duplicate()
					rows.append(result)
					print("ENCOUNTER ",mode," stage=",target," ",result.outcome," HP=",snappedf(result.end_hp,.1)," t=",snappedf(result.seconds_observed,.1))
	if output_path!="":
		var file=FileAccess.open(output_path,FileAccess.WRITE)
		if file==null:push_error("Cannot write benchmark output");quit(2);return
		file.store_string(JSON.stringify({"method":method_description(),"rows":rows},"  "))
	set_movement_input(Vector2.ZERO)
	if is_instance_valid(game):game.free()
	quit()

func run_campaign(run_seed: int):
	new_game(build_index(),starting_ability(),run_seed)
	while game.state!="won" and game.hp>0:
		var result=fight();result["mode"]=mode;result["skills"]=game.learned_skills.duplicate()
		rows.append(result)
		print("CAMPAIGN ",mode," stage=",result.stage," ",result.outcome," HP=",snappedf(result.end_hp,.1)," t=",snappedf(result.seconds_observed,.1))
		if not result.cleared:break
		if game.stage!=int(result.stage) or game.state=="won":continue
		var current=game.stage;var ticks=0
		set_movement_input(Vector2.ZERO)
		while game.stage==current and game.state!="won" and ticks<2400:
			if game.state in ["tactic","skill","loot"]:resolve_modal();continue
			if game.portal_open:game.player=game.CENTER
			game.simulate(DT);ticks+=1
		if ticks>=2400:push_error("Post-combat transition stuck");break

func visible_segment(a: Vector2, b: Vector2, clearance: float=2.0) -> bool:
	var length=a.distance_to(b)
	var steps=maxi(1,int(ceil(length/6.0)))
	for index in range(steps+1):
		if game.blocked(a.lerp(b,float(index)/steps),clearance):return false
	return true

func build_navigation_grid():
	navigation_grid=AStarGrid2D.new()
	grid_origin=game.ARENA.position+Vector2.ONE*14
	grid_columns=int(floor((game.ARENA.size.x-28)/GRID_STEP))+1
	grid_rows=int(floor((game.ARENA.size.y-28)/GRID_STEP))+1
	navigation_grid.region=Rect2i(0,0,grid_columns,grid_rows)
	navigation_grid.cell_size=Vector2.ONE*GRID_STEP
	navigation_grid.offset=grid_origin
	navigation_grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation_grid.update()
	for x in range(grid_columns):
		for y in range(grid_rows):
			var cell=Vector2i(x,y)
			navigation_grid.set_point_solid(cell,game.blocked(grid_origin+Vector2(cell)*GRID_STEP,14))
	navigation_stage=game.stage
	navigation_path.clear()
	path_target=Vector2.INF

func nearest_open_cell(point: Vector2, from_player: bool=false) -> Vector2i:
	var center=Vector2i(roundi((point.x-grid_origin.x)/GRID_STEP),roundi((point.y-grid_origin.y)/GRID_STEP))
	center=Vector2i(clampi(center.x,0,grid_columns-1),clampi(center.y,0,grid_rows-1))
	if not navigation_grid.is_point_solid(center) and (not from_player or visible_segment(point,grid_origin+Vector2(center)*GRID_STEP,12)):return center
	for ring in range(1,8):
		var best=Vector2i(-1,-1)
		var distance=INF
		for x in range(maxi(0,center.x-ring),mini(grid_columns,center.x+ring+1)):
			for y in range(maxi(0,center.y-ring),mini(grid_rows,center.y+ring+1)):
				var cell=Vector2i(x,y)
				if navigation_grid.is_point_solid(cell):continue
				if from_player and not visible_segment(point,grid_origin+Vector2(cell)*GRID_STEP,12):continue
				var d=point.distance_squared_to(grid_origin+Vector2(cell)*GRID_STEP)
				if d<distance:distance=d;best=cell
		if best.x>=0:return best
	return center

func obstacle_waypoint(target: Vector2) -> Vector2:
	if navigation_stage!=game.stage:build_navigation_grid()
	if navigation_path.is_empty() or controller_tick%60==0 or path_target.distance_to(target)>40:
		navigation_path=navigation_grid.get_point_path(nearest_open_cell(game.player,true),nearest_open_cell(target))
		path_target=target
	while navigation_path.size()>1 and game.player.distance_to(navigation_path[0])<20 and visible_segment(game.player,navigation_path[1],12):
		navigation_path.remove_at(0)
	var waypoint=game.player
	for point in navigation_path:
		if not visible_segment(game.player,point,12):break
		waypoint=point
	return waypoint

func combat_distance() -> float:
	if game.primary_weapon() in ["bow","crossbow","gun","throwing_knife","staff"]:return 205
	return clampf(game.melee_range()*.65,32,105)

func choose_kite_direction() -> Vector2:
	var target=game.nearest_enemy(game.player)
	if target==null:return Vector2.ZERO
	var ideal=combat_distance()
	var blocked_target=not visible_segment(game.player,target.pos,3)
	var waypoint=obstacle_waypoint(target.pos) if blocked_target else game.player
	var best_score=-INF
	var best=Vector2.ZERO
	# Eight keyboard directions plus standing still; recomputed at 12 Hz.
	for choice in range(9):
		var heading=Vector2.RIGHT.rotated(float(choice)*TAU/8) if choice<8 else Vector2.ZERO
		var candidate=game.move_actor(game.player,heading*game.stats.speed*0.24,12)
		var distance=candidate.distance_to(target.pos)
		var score=-absf(distance-ideal)*0.35
		if heading != Vector2.ZERO and candidate.distance_to(game.player)<game.stats.speed*0.12:score-=50
		if blocked_target:
			score-=candidate.distance_to(waypoint)*0.3
			score+=heading.dot((waypoint-game.player).normalized())*70.0
			if visible_segment(candidate,target.pos,3):score+=45
		for enemy in game.enemies:
			if enemy.hp<=0:continue
			var predicted=enemy.pos+(game.player-enemy.pos).normalized()*(45+game.stage*1.8)*0.18
			var separation=candidate.distance_to(predicted)
			var safe_radius=minf(ideal*0.82,90.0)
			if separation<safe_radius:score-=pow((safe_radius-separation)/15,2)
			if threatened(candidate,enemy):score-=145
			if separation<28:score-=100
		for bullet in game.bullets:
			if bullet.friendly:continue
			var offset=candidate-bullet.pos
			var ahead=clampf(offset.dot(bullet.vel)/maxf(1,bullet.vel.length_squared()),0,0.4)
			var near=candidate.distance_to(bullet.pos+bullet.vel*ahead)
			if near<35:score-=(35-near)*2
		if game.has_method("remaining_enemies"):
			for hazard in game.world_data.get("hazards",[]):
				if hazard.state in ["telegraph","active"] and candidate.distance_to(hazard.pos)<hazard.radius+20:score-=145
		var safe_bounds=game.ARENA.grow(-13)
		var edge=minf(minf(candidate.x-safe_bounds.position.x,safe_bounds.end.x-candidate.x),minf(candidate.y-safe_bounds.position.y,safe_bounds.end.y-candidate.y))
		if edge<28:score-=28-edge
		if score>best_score:best_score=score;best=heading
	return best

func build_index() -> int:return int(mode.split(":")[0])

func starting_ability() -> String:return mode.split(":")[1]

func method_description() -> Dictionary:
	return {
		"progression":"Natural full run: real attacks, XP, drops and healing; no injected kills or health resets. Automatic center-portal entry only after combat and all rewards." if campaign else "Independent healthy-entry encounters: preceding stages supply their exact total dropped XP and legal random three-option rewards. HP is set to normal maximum at entry. No injected kills or HP changes in measured combat; this is not a prior-stage survival result.",
		"simulation_hz":120,
		"damage_definition":"Sum of actual HP removed by accepted damage_player calls, after armor/invulnerability and capped at remaining HP on lethal hits; healing does not subtract from this counter.",
		"stage_time_limit_seconds":LIMIT,
		"movement":movement,
		"controls":"Eight-direction physical-key input at 12 Hz, ordinary collision movement, AStarGrid2D obstacle routing, visible enemy/environmental cue avoidance and emergency dash. Rogue also dashes offensively. Navigation bounds come from the actual arena." if movement=="kite" else "Ordinary collision movement; no dash. Horizontal reverses at arena edges/obstacles; pursue follows the closest enemy.",
		"choices":"Class-aware priorities choose only from actual offered buttons. Wizard prioritizes survival Tactics; other Classes favor Life Drain, damage, speed and range. Equipment and Skills also come from actual offers.",
		"outcomes":"Cleared, died, or still alive at the 240-second timeout. A timeout is not a death; clear-time medians exclude timeouts/deaths.",
		"limitations":"Small seeded automated sample, not a human difficulty assessment or win-rate estimate. Exact visible cue geometry favors this controller; navigation and cue avoidance are approximate. A fixed 240-second per-stage limit includes wave downtime. Healthy-entry encounters do not establish full-campaign survival."
	}

# These are observations of visible committed cues, not changes to gameplay.
func threatened(point: Vector2, enemy: Dictionary) -> bool:
	if enemy.get("attack_state","idle") not in ["windup","active"]:return false
	var pattern=enemy.get("attack_pattern","")
	if pattern in ["shield_bash","shadow_lunge","hex_pool","rootline","thornwheel","cinder_cross","ember_bloom","prism_lance","crystal_spokes","eclipse","nightfall"]:
		for shape in game.Combat.attack_shapes(enemy,true):
			if game.Combat.shape_contains(shape,point):return true
		return false
	var origin=enemy.get("attack_origin",enemy.pos)
	var aim=enemy.get("attack_aim",Vector2.RIGHT)
	var offset=point-enemy.pos
	if pattern in ["melee","cleave"]:
		return offset.length()<(120 if pattern=="cleave" else 65) and aim.dot(offset.normalized())>-0.3
	if pattern in ["charge","lunge"]:
		var end=origin+aim*(172 if enemy.kind=="boss" else 92)
		return Geometry2D.get_closest_point_to_segment(point,origin,end).distance_to(point)<52
	if pattern=="blast":return point.distance_to(enemy.attack_target)<82
	if pattern=="explode":return offset.length()<89
	return false

func full_remaining() -> int:
	return game.remaining_enemies() if game.has_method("remaining_enemies") else game.enemies.size()
