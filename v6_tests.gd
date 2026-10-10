extends SceneTree

# Deterministic feature regressions. These fixtures may inject kills and state
# to isolate lifecycle branches. They are NOT the real-combat balance trials.
var game
var passed = 0
var failures: Array[String] = []

func _initialize():
	call_deferred("run_tests")

func check(condition: bool, message: String):
	if condition:
		passed += 1
		print("PASS: ", message)
	else:
		failures.append(message)
		print("FAIL: ", message)

func near(a: float,b: float) -> bool:
	return absf(a-b)<0.001

func fresh(stage_number: int = 1):
	game.selected_build=0
	game.selected_ability=""
	game.start_run()
	game.stage=stage_number
	game.rng.seed=6030+stage_number
	game.start_stage()
	game.stats.regen=0.0
	game.attack_cd=99.0
	game.bow_cd=99.0
	game.magic_cd=99.0
	game.profile.sfx=false
	game.profile.shake=false

func remove_active():
	for enemy in game.enemies:enemy.hp=0.0
	game.simulate(0.0)
	game.gems.clear()
	game.potions.clear()

func run_tests():
	seed(6030)
	game=load("res://main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.set_process(false)
	fresh()
	test_wave_rosters()
	test_wave_gates()
	test_pause_and_reset()
	test_camera_and_world_units()
	test_maps()
	test_hazards()
	print("V6_TESTS: ",passed," passed; ",failures.size()," failed")
	for failure in failures:print(" - ",failure)
	game.free()
	quit(0 if failures.is_empty() else 1)

func test_wave_rosters():
	var full_run_count=0
	for stage_number in range(1,21):
		fresh(stage_number)
		var boss_stage=stage_number%5==0
		var expected=int(ceil((8+stage_number*2+(1 if boss_stage else 0))*1.25))
		var tier=mini(3,int((stage_number-1)/5))
		var roster: Array=[]
		for enemy in game.enemies:roster.append(enemy.kind)
		roster.append_array(game.spawn_queue)
		check(game.total_enemies==expected and game.remaining_enemies()==expected,"Stage %d counts the entire +25%% roster before all groups spawn"%stage_number)
		check((str(expected)+" FOES LEFT") in game.hud.text,"Stage %d HUD displays active plus queued enemies"%stage_number)
		check(game.wave_size==4+tier and game.active_cap==6+2*tier and game.enemies.size()==game.wave_size and game.wave_index==1,"Stage %d starts one small group with its tier-specific population cap"%stage_number)
		check(game.wave_count==int(ceil(float(expected)/game.wave_size)),"Stage %d reports the complete group count"%stage_number)
		check(roster.count("herbalist")==1 and roster[4]=="herbalist","Stage %d retains exactly one herbalist at roster slot five"%stage_number)
		check(roster.count("boss")==int(boss_stage) and (not boss_stage or roster[-1]=="boss"),"Stage %d has the correct guardian, last in the queued roster"%stage_number)
		var actual_roster: Array=[]
		var overflow=false
		var boss_early=false
		while not game.enemies.is_empty() or not game.spawn_queue.is_empty():
			for enemy in game.enemies:
				actual_roster.append(enemy.kind)
				if enemy.kind=="boss" and game.wave_index!=game.wave_count:boss_early=true
			game.enemies.clear()
			game.update_waves(3.0)
			overflow=overflow or game.enemies.size()>game.active_cap
		check(actual_roster==roster and not overflow and not boss_early and game.wave_index==game.wave_count,"Stage %d consumes every queued enemy exactly once with the guardian in the final group"%stage_number)
		full_run_count+=expected
	check(full_run_count==736,"The 20-stage campaign contains exactly 736 enemies including four guardians")

func test_wave_gates():
	fresh()
	var count_before=game.remaining_enemies()
	var queue_before=game.spawn_queue.size()
	game.update_waves(50.0)
	check(game.enemies.size()==4 and game.spawn_queue.size()==queue_before,"A full next group cannot bypass the active-enemy cap after its timer expires")
	game.enemies[0].hp=0.0
	game.simulate(0.0)
	check(game.kills==1 and game.remaining_enemies()==count_before-1,"A real death-removal tick decreases the full counter exactly once")
	check(game.enemies.size()==3 and game.wave_index==1,"Three survivors still block a four-enemy next group under cap six")
	game.enemies[0].hp=0.0
	game.simulate(0.0)
	game.update_waves(0.0)
	check(game.enemies.size()==6 and game.wave_index==2 and game.remaining_enemies()==count_before-2,"A ready next group spawns when enough capacity opens, without changing the full remaining count")
	check(near(game.wave_timer,3.0),"Each released group resets a three-second spawn delay")
	game.enemies.clear()
	var waiting=game.spawn_queue.size()
	game.update_waves(2.99)
	check(game.enemies.is_empty() and game.spawn_queue.size()==waiting,"An empty field still waits for the three-second group interval")
	game.update_waves(0.02)
	check(not game.enemies.is_empty() and game.wave_index==3,"The next group releases after the delay with no extra kill requirement")

	fresh()
	game.hp=30.0
	game.wave_timer=3.0
	remove_active()
	game.gems.append({"pos":game.player+Vector2(200,0),"value":0.0})
	game.potions.append({"pos":game.player+Vector2(200,0),"fraction":0.02})
	game.simulate(0.1)
	check(not game.portal_open and not game.stage_clear_healed and near(game.hp,30),"Clearing only an active group grants neither portal nor stage-clear healing")
	check(game.gems[0].pos==game.player+Vector2(200,0) and game.potions[0].pos==game.player+Vector2(200,0),"Queued enemies prevent premature whole-arena pickup attraction")
	game.gems.clear();game.potions.clear()
	game.spawn_queue.clear()
	game.simulate(0.0)
	check(game.portal_open and game.stage_clear_healed and near(game.hp,40),"Resolving the full queue and drops grants the normal once-per-stage 10% heal and portal")
	game.simulate(0.0)
	check(near(game.hp,40),"Repeated empty-arena ticks cannot repeat clear healing")

	fresh(5)
	game.hp=30.0
	game.enemies.clear();game.wave_timer=3.0
	game.simulate(0.0)
	check(game.state=="playing" and not game.boss_reward_taken and not game.portal_open,"An inter-group gap on a guardian stage cannot open the relic reward")

func test_pause_and_reset():
	fresh()
	game.enemies.clear()
	var queue_before=game.spawn_queue.duplicate()
	var timer_before=game.wave_timer
	for state_name in ["paused","upgrade","loot","dead","menu"]:
		game.state=state_name
		game.update_waves(10.0)
		game.simulate(10.0)
		check(game.spawn_queue==queue_before and game.enemies.is_empty() and near(game.wave_timer,timer_before),"%s state freezes wave release and timer"%state_name)
	game.state="playing"
	game.hp=0
	game.update_waves(10.0)
	check(game.spawn_queue==queue_before,"A player at zero HP cannot trigger another group")
	fresh(20)
	game.wave_timer=123.0
	game.stage_clear_healed=true
	game.start_run()
	check(game.stage==1 and game.wave_index==1 and game.wave_count==4 and game.total_enemies==13 and game.remaining_enemies()==13 and near(game.wave_timer,3.0),"A new run replaces the old wave queue, counters and timer")
	check(not game.stage_clear_healed and not game.portal_open and game.kills==0,"A new run resets clear/reward lifecycle state")
	game.end_run(false)
	check(game.spawn_queue.is_empty() and (str(game.remaining_enemies())+" FOES LEFT") in game.hud.text,"Run end clears future groups before refreshing the displayed remaining counter")

func test_camera_and_world_units():
	fresh()
	check(near(game.ARENA.get_area()/Rect2(32,112,896,456).get_area(),2.25),"The playable world is 2.25 times the v5 arena area")
	check(game.VIEW==Rect2(32,112,896,456),"The visible viewport and interface footprint remain unchanged")
	for pos in [game.CENTER,game.ARENA.position+Vector2(14,14),game.ARENA.end-Vector2(14,14),Vector2(1120,650)]:
		game.player=pos
		game.update_camera()
		var projected=game.world_to_screen(pos)
		check(game.screen_to_world(projected).distance_to(pos)<0.001,"Camera transforms round-trip world position %s"%str(pos))
		check(game.camera_offset.x>=0 and game.camera_offset.y>=0 and game.camera_offset.x<=448 and game.camera_offset.y<=228,"Camera clamp stays inside the expanded world at %s"%str(pos))
	game.player=Vector2(1160,660)
	game.obstacles.clear()
	game.update_camera()
	var world_target=game.player+Vector2(80,-30)
	var pointer=game.world_to_screen(world_target)
	check((game.screen_to_world(pointer)-game.player).normalized().distance_to((world_target-game.player).normalized())<0.001,"Pointer aiming compensates for the scrolled world rather than aiming at screen coordinates")
	game.enemies.clear();game.spawn_queue.clear()
	game.spawn_enemy("grunt")
	game.enemies[0].pos=game.player+Vector2(120,0)
	game.enemies[0].cooldown=99.0
	game.enemies[0].spawn_grace=99.0
	game.potions.clear();game.gems.clear()
	game.hp=50.0
	game.potions.append({"pos":game.player+Vector2(74,0),"fraction":0.02})
	game.gems.append({"pos":game.player+Vector2(74,0),"value":0.0})
	game.simulate(0.1)
	check(near(game.potions[0].pos.distance_to(game.player),50.0) and near(game.gems[0].pos.distance_to(game.player),50.0),"Pickup radius and magnet speed use unchanged world units while the camera is scrolled")
	game.potions.clear();game.gems.clear()
	game.potions.append({"pos":game.player,"fraction":0.02})
	game.simulate(0.0)
	check(game.potions.is_empty() and near(game.hp,52),"Scrolled-camera pickups collect at the player's world position")
	game.selected_build=1
	game.bow_cd=0;game.bow_windup=0
	game.update_player_attacks(0,game.enemies[0])
	check(game.bow_aim.distance_to(Vector2.RIGHT)<0.001,"Ranged attack direction stays in world space after camera movement")
	game.obstacles=[Rect2(game.player+Vector2(35,-40),Vector2(24,80))]
	check(game.move_actor(game.player,Vector2(150,0),12).x<game.player.x+24,"Scrolled-world collision stops fast movement before a wall")

func test_maps():
	var map_signatures={}
	var disconnected=0
	var unsafe_spawns=0
	var bad_center=0
	var arenas=0
	var spawn_count=0
	for seed_number in range(10):
		for stage_number in range(1,21):
			fresh(stage_number)
			game.rng.seed=seed_number
			game.start_stage()
			arenas+=1
			if seed_number==0:map_signatures[str(game.obstacles)]=true
			if game.blocked(game.CENTER,40):bad_center+=1
			if not map_fully_connected():disconnected+=1
			while true:
				for enemy in game.enemies:
					spawn_count+=1
					if game.blocked(enemy.pos,28 if enemy.kind=="boss" else 18) or enemy.pos.distance_to(game.player)<=185:unsafe_spawns+=1
				game.enemies.clear()
				if game.spawn_queue.is_empty():break
				game.update_waves(3.0)
	check(map_signatures.size()==20,"All twenty stages have distinct obstacle layouts")
	check(disconnected==0,"All walkable space remains connected in 200 seeded expanded maps")
	check(bad_center==0,"Every tested map preserves a collision-free center portal approach")
	check(unsafe_spawns==0 and spawn_count==7360,"Every enemy in every queued group has safe player-reachable spawn clearance in 200 maps")
	print("V6_MAP_SWEEP: ",arenas," arenas; ",spawn_count," spawns; disconnected=",disconnected," unsafe_spawns=",unsafe_spawns)

func map_fully_connected() -> bool:
	# Exact obstacle-boundary decomposition, not a coarse grid that can invent
	# an impassable doorway. Check the whole player-radius configuration space.
	var bounds=game.ARENA.grow(-12)
	var xs=[bounds.position.x,bounds.end.x]
	var ys=[bounds.position.y,bounds.end.y]
	for obstacle in game.obstacles:
		var expanded=obstacle.grow(12)
		for x in [expanded.position.x,expanded.end.x]:
			var bounded=clampf(x,bounds.position.x,bounds.end.x)
			if not bounded in xs:xs.append(bounded)
		for y in [expanded.position.y,expanded.end.y]:
			var bounded=clampf(y,bounds.position.y,bounds.end.y)
			if not bounded in ys:ys.append(bounded)
	xs.sort();ys.sort()
	var width=xs.size()-1
	var height=ys.size()-1
	var occupied=PackedByteArray()
	occupied.resize(width*height)
	var visited=PackedByteArray()
	visited.resize(width*height)
	var start=-1
	var open_count=0
	for y in range(height):
		for x in range(width):
			var middle=Vector2((xs[x]+xs[x+1])/2,(ys[y]+ys[y+1])/2)
			occupied[y*width+x]=int(game.blocked(middle,12))
			if not occupied[y*width+x]:open_count+=1
			if game.CENTER.x>=xs[x] and game.CENTER.x<xs[x+1] and game.CENTER.y>=ys[y] and game.CENTER.y<ys[y+1]:start=y*width+x
	if start<0 or occupied[start]:return false
	var queue:Array[int]=[start]
	visited[start]=1
	var head=0
	while head<queue.size():
		var cell=queue[head]
		head+=1
		var x=cell%width
		var y=int(cell/width)
		for next in [Vector2i(x-1,y),Vector2i(x+1,y),Vector2i(x,y-1),Vector2i(x,y+1)]:
			if next.x<0 or next.y<0 or next.x>=width or next.y>=height:continue
			var index=next.y*width+next.x
			if occupied[index] or visited[index]:continue
			visited[index]=1
			queue.append(index)
	return queue.size()==open_count

func hazard_fixture(phase: String="telegraph",timer: float=1.4) -> Dictionary:
	game.world_data.hazards_enabled=false
	game.world_data.hazard_timer=999.0
	game.hurt_cd=0.0
	game.dash_left=0.0
	var hazard={"pos":game.player,"radius":35.0,"state":phase,"time":timer,"duration":timer,"hit":false,"theme":int(game.world_data.theme),"serial":1,"damage":20.0,"phase":0.0}
	game.world_data.hazards=[hazard]
	return hazard

func test_hazards():
	fresh()
	var hazard=hazard_fixture()
	check(near(game.World.contact_radius(hazard),hazard.radius+10),"Warning rendering and collision share the same environmental contact-radius helper")
	var locked_position=hazard.pos
	game.World.update_hazards(game,1.21)
	check(hazard.state=="telegraph" and near(game.hp,100) and hazard.pos==locked_position,"Environmental warnings remain harmless, locked, and visible beyond 1.2 seconds")
	game.World.update_hazards(game,0.18)
	check(hazard.state=="telegraph" and near(game.hp,100),"The 1.4-second warning cannot damage during its last pre-release frame")
	game.World.update_hazards(game,0.02)
	check(hazard.state=="active" and near(game.hp,80) and hazard.hit,"A released environmental hazard routes one hit through normal player damage")
	game.hurt_cd=0
	game.World.update_hazards(game,0.2)
	check(near(game.hp,80),"An active hazard cannot deal repeat contact damage after its first hit")
	game.World.update_hazards(game,0.81)
	check(hazard.state=="recovery" and near(game.hp,80),"The active eruption has a harmless recovery phase")
	game.World.update_hazards(game,0.71)
	check(game.world_data.hazards.is_empty(),"A completed eruption removes its warning and damage state")

	fresh()
	hazard=hazard_fixture("active",1.0)
	game.stats.armor=8
	game.World.update_hazards(game,0.0)
	check(near(game.hp,88),"Environmental damage respects the ordinary flat-armor reduction")
	for protection in ["hurt","dash"]:
		fresh()
		hazard=hazard_fixture("active",1.0)
		if protection=="hurt":game.hurt_cd=0.5
		else:game.dash_left=0.18
		game.World.update_hazards(game,0.0)
		check(near(game.hp,100) and hazard.hit,"%s immunity protects against the eruption's one contact"%protection)
		game.hurt_cd=0;game.dash_left=0
		game.World.update_hazards(game,0.1)
		check(near(game.hp,100),"%s-avoided contact cannot hit later in the same eruption"%protection)

	fresh()
	hazard=hazard_fixture("active",1.0)
	game.player=hazard.pos+Vector2(hazard.radius+10.1,0)
	game.World.update_hazards(game,0.0)
	check(near(game.hp,100) and not hazard.hit,"Standing outside the visible environmental hit circle remains safe")
	game.player=hazard.pos
	game.World.update_hazards(game,0.0)
	check(near(game.hp,80),"Walking into the active circle consumes exactly its one available contact")

	for state_name in ["paused","upgrade","loot","menu"]:
		fresh()
		hazard=hazard_fixture()
		game.state=state_name
		var timer=game.world_data.hazard_timer
		game.World.update_hazards(game,20)
		check(near(hazard.time,1.4) and near(game.world_data.hazard_timer,timer) and near(game.hp,100),"%s state freezes environmental phase and spawn clocks"%state_name)
	fresh()
	hazard=hazard_fixture()
	game.pending_choices=1
	game.World.update_hazards(game,20)
	check(near(hazard.time,1.4) and near(game.hp,100),"A pending reward interrupts environmental progression before the modal appears")

	for reason in ["inter_group","complete","portal","dead"]:
		fresh()
		hazard=hazard_fixture("active",1.0)
		if reason in ["inter_group","complete"]:game.enemies.clear()
		if reason=="complete":game.spawn_queue.clear()
		if reason=="portal":game.portal_open=true
		if reason=="dead":game.hp=0
		var before=game.hp
		game.World.update_hazards(game,0.0)
		check(game.world_data.hazards.is_empty() and near(game.hp,before),"%s lifecycle clears environmental hazards without a final invisible hit"%reason)
	fresh()
	hazard_fixture("active",1.0)
	game.stage=6
	game.start_stage()
	check(game.world_data.hazards.is_empty() and near(game.world_data.hazard_timer,5) and game.world_data.generated_stage==6,"Stage entry resets hazards and grants a fresh five-second environmental grace")

	var valid=true
	var max_cap=true
	var generated=0
	var themes={}
	for stage_number in range(1,21):
		fresh(stage_number)
		for cycle in range(20):
			game.world_data.hazard_timer=0.0
			game.World.update_hazards(game,0.0)
			max_cap=max_cap and game.world_data.hazards.size()<=(2 if stage_number<=10 else 3)
			for h in game.world_data.hazards:
				generated+=1
				themes[h.theme]=true
				valid=valid and h.state=="telegraph" and h.time>=1.2 and not h.hit
				valid=valid and game.ARENA.grow(-h.radius-10).has_point(h.pos)
				valid=valid and h.pos.distance_to(game.CENTER)>=game.World.SAFE_CENTER_RADIUS+h.radius+10
				valid=valid and h.pos.distance_to(game.player)>=h.radius+46
				for obstacle in game.obstacles:
					if obstacle.grow(h.radius+10).has_point(h.pos):valid=false
			if cycle%3==2:game.world_data.hazards.clear()
	check(generated>400 and themes.size()==4 and valid,"Generated hazards across all themes preserve warning time, center refuge, walls, arena bounds and spawn distance")
	check(max_cap,"Environmental population never exceeds two early or three late eruptions")
	check(not game.World.can_spawn_hazard(game,game.CENTER,35) and not game.World.can_spawn_hazard(game,game.player,35),"The hazard placement predicate rejects the portal center and the player's feet")
