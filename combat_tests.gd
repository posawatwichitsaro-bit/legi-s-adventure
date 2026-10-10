extends SceneTree

# Deterministic combat state-machine regressions. Run from the project folder:
# godot --headless --path . --script combat_tests.gd
# These tests never save or alter the player's persistent profile.
const STEP = 1.0 / 120.0
const REGULAR_KINDS = ["grunt", "archer", "swift", "bomber", "ghost", "herbalist", "sentinel", "assassin", "chanter", "hexer"]
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

func near(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001

func fresh_field(stage_number = 1):
	game.selected_class = 0
	game.selected_skill = ""
	game.start_run()
	if stage_number != 1:
		game.stage = stage_number
		game.start_stage()
	game.enemies.clear()
	game.spawn_queue.clear()
	game.World.reset_hazards(game)
	game.world_data["hazards_enabled"] = false
	game.bullets.clear()
	game.gems.clear()
	game.potions.clear()
	game.obstacles.clear()
	game.effects.clear()
	game.player = game.CENTER
	game.facing = Vector2.RIGHT
	game.stats.regen = 0.0
	game.stats.armor = 0.0
	game.attack_cd = 99.0
	game.bow_cd = 99.0
	game.magic_cd = 99.0
	game.hurt_cd = 0.0
	game.stage_time = 0.0

func enemy_at(kind: String, pos: Vector2, health = 1000.0) -> Dictionary:
	game.spawn_enemy(kind)
	var enemy = game.enemies.back()
	enemy.pos = pos
	enemy.hp = health
	enemy.max_hp = health
	enemy.cooldown = 0.0
	enemy.attack_origin = pos
	enemy.attack_target = pos
	return enemy

func enemy_steps(enemy: Dictionary, duration: float):
	var remaining = duration
	while remaining > 0.000001:
		var dt = minf(STEP, remaining)
		game.update_enemy(enemy, dt)
		remaining -= dt

func until_enemy_state(enemy: Dictionary, wanted: String, max_seconds = 3.0) -> bool:
	for frame in range(ceili(max_seconds / STEP)):
		if enemy.attack_state == wanted:
			return true
		game.update_enemy(enemy, STEP)
	return enemy.attack_state == wanted

func player_steps(duration: float):
	var remaining = duration
	while remaining > 0.000001:
		var dt = minf(STEP, remaining)
		game.update_player_attacks(dt, game.nearest_enemy(game.player))
		remaining -= dt

func arm_active(enemy: Dictionary, pattern = "melee", duration = 0.18):
	game.Combat.begin(game, enemy)
	enemy.attack_pattern = pattern
	enemy.attack_state = "active"
	enemy.attack_time = duration
	enemy.attack_duration = duration

func run_tests():
	seed(542619)
	game = load("res://main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_process(false)
	game.rng.seed = 542619
	test_spawn_contract()
	test_no_passive_contact()
	test_melee_windows()
	test_lunges_and_blasts()
	test_ranged_release()
	test_immunity()
	test_player_sword()
	test_player_casts()
	test_interruption_guards()
	test_guardian_patterns()
	test_frame_stall()
	print("COMBAT_TESTS: ", passed, " passed; ", failures.size(), " failed")
	for failure in failures:
		print(" - ", failure)
	quit(0 if failures.is_empty() else 1)

func test_spawn_contract():
	var fields = ["attack_state", "attack_time", "attack_duration", "attack_aim", "attack_origin", "attack_target", "attack_hit", "attack_pattern", "attack_index", "boss_type", "max_hp", "facing", "moving"]
	var valid = true
	for kind in REGULAR_KINDS + ["boss"]:
		fresh_field()
		var enemy = enemy_at(kind, game.player + Vector2(160, 0))
		for field in fields:
			valid = valid and enemy.has(field)
		valid = valid and enemy.attack_state == "idle" and not enemy.attack_hit and enemy.attack_time == 0
	check(valid, "Every spawned enemy initializes all attack and animation state safely")
	var stages_valid = true
	for boss_type in range(4):
		game.stage = (boss_type + 1) * 5
		game.start_stage()
		# Materialize the complete roster only for guardian identity inspection.
		while not game.spawn_queue.is_empty():
			game.spawn_enemy(game.spawn_queue.pop_front())
		var bosses: Array = []
		for enemy in game.enemies:
			if enemy.kind == "boss": bosses.append(enemy)
		stages_valid = stages_valid and bosses.size() == 1 and bosses[0].boss_type == boss_type
	check(stages_valid, "Guardian stages 5, 10, 15 and 20 spawn the four corresponding guardian types")

func test_no_passive_contact():
	for kind in REGULAR_KINDS + ["boss"]:
		fresh_field()
		var enemy = enemy_at(kind, game.player)
		enemy.cooldown = 99.0
		game.simulate(STEP)
		check(near(game.hp, 100.0) and enemy.attack_state == "idle", "%s touching an idle player causes no collision damage" % kind.capitalize())
		enemy.cooldown = 0.0
		game.simulate(0.0)
		var started = enemy.attack_state == "windup"
		enemy_steps(enemy, 0.2)
		check(started and enemy.attack_state == "windup" and near(game.hp, 100.0) and game.bullets.is_empty(), "%s overlapping during windup causes no early damage or projectile release" % kind.capitalize())
	for boss_type in range(1, 4):
		fresh_field((boss_type + 1) * 5)
		var boss = enemy_at("boss", game.player)
		boss.cooldown = 99.0
		game.simulate(STEP)
		var safe_idle = near(game.hp, 100.0) and boss.attack_state == "idle"
		boss.cooldown = 0.0
		game.update_enemy(boss, 0.0)
		enemy_steps(boss, 0.2)
		check(safe_idle and near(game.hp, 100.0) and boss.attack_state == "windup" and game.bullets.is_empty(), "%s overlapping in idle and windup causes no collision damage" % game.Combat.BOSS_NAMES[boss_type])

func test_melee_windows():
	for kind in ["grunt", "swift", "herbalist", "boss"]:
		fresh_field()
		var enemy = enemy_at(kind, game.player - Vector2(30, 0))
		game.update_enemy(enemy, 0.0)
		var locked_aim = enemy.attack_aim
		var locked_target = enemy.attack_target
		game.player = enemy.pos - Vector2(35, 0)
		var active = until_enemy_state(enemy, "active")
		check(active and enemy.attack_aim == locked_aim and enemy.attack_target == locked_target and near(game.hp, 100.0), "%s locks its telegraph and can be dodged behind during windup" % kind.capitalize())
		game.player = enemy.pos + Vector2(30, 0)
		game.update_enemy(enemy, 0.0)
		var after_hit = game.hp
		for frame in range(6):
			game.hurt_cd = 0.0
			game.update_enemy(enemy, STEP)
		check(after_hit < 100.0 and near(game.hp, after_hit) and enemy.attack_hit, "%s active swing deals at most one hit even when invulnerability is cleared" % kind.capitalize())
		until_enemy_state(enemy, "recover")
		game.hurt_cd = 0.0
		game.player = enemy.pos
		enemy_steps(enemy, 0.15)
		check(enemy.attack_state == "recover" and near(game.hp, after_hit), "%s recovery has no damaging contact hitbox" % kind.capitalize())
	fresh_field()
	var enemy = enemy_at("grunt", game.player - Vector2(30, 0))
	arm_active(enemy)
	enemy.attack_time = STEP * 0.5
	game.update_enemy(enemy, STEP)
	check(enemy.attack_state == "recover" and near(game.hp, 100.0), "Entering on the first expired melee frame cannot cause a late hit")

func test_lunges_and_blasts():
	for kind in ["ghost", "boss"]:
		fresh_field()
		var enemy = enemy_at(kind, game.player - Vector2(90, 0))
		if kind == "boss": enemy.attack_index = 2
		game.update_enemy(enemy, 0.0)
		var origin = enemy.pos
		var aim = enemy.attack_aim
		game.player += Vector2(0, 140)
		until_enemy_state(enemy, "recover")
		check(near(game.hp, 100.0) and enemy.pos.x > origin.x and near(enemy.pos.y, origin.y) and enemy.attack_aim == aim, "%s lunge follows its marked direction and misses a sideways dodge" % kind.capitalize())
		fresh_field()
		enemy = enemy_at(kind, game.player - Vector2(90, 0))
		if kind == "boss": enemy.attack_index = 2
		game.update_enemy(enemy, 0.0)
		until_enemy_state(enemy, "recover")
		check(game.hp < 100.0 and enemy.attack_hit, "%s lunge connects when the player stays inside its marked lane" % kind.capitalize())
	fresh_field()
	var bomber = enemy_at("bomber", game.player - Vector2(45, 0))
	game.update_enemy(bomber, 0.0)
	game.player += Vector2(130, 0)
	until_enemy_state(bomber, "recover")
	check(near(game.hp, 100.0) and bomber.hp <= 0, "A bomber explodes only after warning and can be escaped beyond its marked radius")
	fresh_field()
	bomber = enemy_at("bomber", game.player - Vector2(45, 0))
	game.update_enemy(bomber, 0.0)
	until_enemy_state(bomber, "active")
	check(game.hp < 100.0 and bomber.attack_hit, "A bomber's active explosion damages a player who stays inside the marked radius")
	fresh_field(10)
	var boss = enemy_at("boss", game.player - Vector2(200, 0))
	game.update_enemy(boss, 0.0)
	var marked = boss.attack_target
	game.player += Vector2(100, 0)
	until_enemy_state(boss, "active")
	check(boss.attack_pattern == "blast" and boss.attack_target == marked and near(game.hp, 100.0), "Ember Alchemist's blast stays on its marked ground and misses a player who leaves")
	game.player = marked
	game.update_enemy(boss, 0.0)
	var after_hit = game.hp
	game.hurt_cd = 0.0
	game.update_enemy(boss, STEP)
	check(after_hit < 100.0 and near(game.hp, after_hit), "A marked guardian blast damages once during its active window")

func test_ranged_release():
	for entry in [{"kind":"archer", "stage":1, "index":0, "count":1, "pattern":"shot"}, {"kind":"boss", "stage":15, "index":0, "count":7, "pattern":"fan"}, {"kind":"boss", "stage":15, "index":2, "count":12, "pattern":"ring"}]:
		fresh_field(entry.stage)
		var enemy = enemy_at(entry.kind, game.player - Vector2(200, 0))
		enemy.attack_index = entry.index
		game.update_enemy(enemy, 0.0)
		var aim = enemy.attack_aim
		enemy_steps(enemy, enemy.attack_duration - STEP * 2)
		check(enemy.attack_state == "windup" and game.bullets.is_empty(), "%s projectiles remain queued throughout the windup" % entry.pattern.capitalize())
		game.player += Vector2(0, 160)
		until_enemy_state(enemy, "active")
		var released = game.bullets.size() == entry.count
		var direction_locked = enemy.attack_aim == aim
		if entry.pattern == "shot" and not game.bullets.is_empty():
			direction_locked = direction_locked and game.bullets[0].vel.normalized().is_equal_approx(aim)
		enemy_steps(enemy, 0.1)
		check(released and game.bullets.size() == entry.count and direction_locked, "%s releases exactly %d projectile(s) once using its telegraphed direction" % [entry.pattern.capitalize(), entry.count])

func test_immunity():
	fresh_field()
	var enemy = enemy_at("grunt", game.player - Vector2(30, 0))
	arm_active(enemy)
	game.hurt_cd = 0.5
	game.update_enemy(enemy, 0.0)
	check(near(game.hp, 100.0) and enemy.attack_hit, "Existing damage invulnerability blocks a melee connection and consumes that swing")
	game.hurt_cd = 0.0
	game.update_enemy(enemy, STEP)
	check(near(game.hp, 100.0), "A blocked swing cannot hit again when invulnerability ends")
	var second = enemy_at("swift", game.player - Vector2(35, 0))
	arm_active(second)
	game.update_enemy(second, 0.0)
	var after_hit = game.hp
	var third = enemy_at("herbalist", game.player - Vector2(25, 0))
	arm_active(third)
	game.update_enemy(third, 0.0)
	check(after_hit < 100.0 and near(game.hp, after_hit) and game.hurt_cd > 0, "A successful attack grants invulnerability against a simultaneous second enemy")
	fresh_field()
	enemy = enemy_at("grunt", game.player - Vector2(30, 0))
	arm_active(enemy)
	game.dash()
	game.update_enemy(enemy, 0.0)
	check(near(game.hp, 100.0) and enemy.attack_hit and game.dash_left > 0, "Dashing through an active enemy swing prevents its damage")
	fresh_field()
	enemy_at("grunt", game.player + Vector2(200, 0)).cooldown = 99.0
	game.hurt_cd = 0.5
	game.enemy_shot(game.player, Vector2.ZERO, 100)
	game.simulate(0.0)
	check(near(game.hp, 100.0) and game.bullets.is_empty(), "Damage invulnerability also blocks and consumes an overlapping hostile projectile")
	game.hurt_cd = 0.0
	game.enemy_shot(game.player, Vector2.ZERO, 100)
	game.simulate(0.0)
	check(game.hp < 100.0 and game.bullets.is_empty(), "A released hostile projectile damages an unprotected player on impact")

func test_player_sword():
	fresh_field()
	var target = enemy_at("grunt", game.player + Vector2(40, 0))
	target.cooldown = 99.0
	game.attack_cd = 0.0
	game.update_player_attacks(0.0, target)
	player_steps(0.10)
	check(game.sword_state == "windup" and near(target.hp, 1000.0), "The sword has a visible 0.12-second windup before any damage")
	var aim = game.sword_aim
	target.pos = game.player + Vector2(-40, 0)
	player_steps(0.04)
	check(game.sword_state == "active" and game.sword_aim == aim and near(target.hp, 1000.0), "The sword's locked heading cannot instantly retarget an enemy that dodges behind")
	target.pos = game.player + Vector2(40, 0)
	game.update_player_attacks(0.0, target)
	var health_after_hit = target.hp
	player_steps(0.06)
	check(near(health_after_hit, 1000.0 - game.stats.damage) and near(target.hp, health_after_hit), "One sword active window hits the same enemy at most once")
	var second = enemy_at("grunt", game.player + Vector2(35, 10))
	game.update_player_attacks(0.0, second)
	check(near(second.hp, 1000.0 - game.stats.damage) and near(target.hp, health_after_hit), "A sword sweep can hit a different target without re-hitting the first")
	player_steps(0.1)
	var third = enemy_at("grunt", game.player + Vector2(35, -10))
	game.update_player_attacks(0.0, third)
	check(game.sword_state == "recover" and near(third.hp, 1000.0), "Sword recovery cannot damage newly overlapping enemies")
	player_steps(0.15)
	check(game.sword_state == "idle", "The sword returns to idle after its recovery window")
	game.attack_cd = 0.0
	game.update_player_attacks(0.0, target)
	player_steps(0.14)
	check(near(target.hp, health_after_hit - game.stats.damage), "A later sword swing may damage the same surviving enemy again")
	fresh_field()
	target = enemy_at("grunt", game.player + Vector2(40, 0))
	game.attack_cd = 0.0
	game.update_player_attacks(0.0, target)
	target.pos = game.player + Vector2(200, 0)
	player_steps(0.15)
	check(near(target.hp, 1000.0), "Leaving sword range during windup avoids the active hit")
	target.pos = game.player + Vector2(40, 0)
	game.sword_time = STEP * 0.5
	game.update_player_attacks(STEP, target)
	check(game.sword_state == "recover" and near(target.hp, 1000.0), "Entering sword range on the first expired active frame cannot cause a late hit")

func test_player_casts():
	fresh_field()
	var target = enemy_at("grunt", game.player + Vector2(200, 0))
	game.stats.projectiles = 2.0
	game.bow_cd = 0.0
	game.update_player_attacks(0.0, target)
	var aim = game.bow_aim
	player_steps(0.18)
	check(game.bow_windup > 0 and game.bullets.is_empty(), "Player bow draws for 0.20 seconds before releasing arrows")
	target.pos = game.player + Vector2(0, 200)
	player_steps(0.04)
	var arrows_once = game.bullets.size() == 2 and game.bow_aim == aim and game.release_kind == "bow"
	player_steps(0.1)
	check(arrows_once and game.bullets.size() == 2, "Bow release produces its configured arrow count once with a locked draw direction")
	fresh_field()
	target = enemy_at("grunt", game.player + Vector2(200, 0))
	game.stats.magic = 1.0
	game.magic_cd = 0.0
	game.update_player_attacks(0.0, target)
	player_steps(0.26)
	check(game.cast_windup > 0 and game.bullets.is_empty(), "Player magic visibly channels for 0.28 seconds before its burst")
	player_steps(0.04)
	var burst_once = game.bullets.size() == 8 and game.release_kind == "cast"
	player_steps(0.1)
	check(burst_once and game.bullets.size() == 8, "Magic release emits exactly eight radial projectiles once")

func test_interruption_guards():
	for mode in ["paused", "tactic", "loot", "menu", "dead", "won"]:
		fresh_field()
		var enemy = enemy_at("grunt", game.player - Vector2(30, 0))
		arm_active(enemy)
		game.attack_cd = 0.0
		game.update_player_attacks(0.0, enemy)
		game.enemy_shot(game.player, Vector2.RIGHT, 100)
		game.state = mode
		var before_enemy = enemy.duplicate(true)
		var before_bullet = game.bullets[0].duplicate(true)
		var before_sword = game.sword_time
		game.update_enemy(enemy, 1.0)
		game.update_player_attacks(1.0, enemy)
		game.simulate(1.0)
		game.damage_player(10.0)
		check(near(game.hp, 100.0) and enemy == before_enemy and game.bullets[0] == before_bullet and game.sword_time == before_sword, "%s state freezes attacks and cannot receive combat damage" % mode.capitalize())
	fresh_field()
	var enemy = enemy_at("grunt", game.player - Vector2(30, 0))
	arm_active(enemy)
	enemy.hp = 0.0
	game.update_enemy(enemy, 1.0)
	check(near(game.hp, 100.0) and not enemy.attack_hit, "An enemy killed during its attack cannot finish a damaging swing")
	fresh_field()
	enemy = enemy_at("grunt", game.player - Vector2(30, 0))
	arm_active(enemy)
	game.hp = 0.0
	game.update_enemy(enemy, 1.0)
	game.update_player_attacks(1.0, enemy)
	game.simulate(STEP)
	check(game.state == "dead" and game.hp <= 0 and not enemy.attack_hit, "A zero-health player ends the run before any further attack can progress")
	fresh_field()
	enemy = enemy_at("grunt", game.player + Vector2(200, 0))
	enemy.cooldown = 99.0
	game.hp = 1.0
	game.bullets.append({"pos":enemy.pos, "vel":Vector2.ZERO, "life":1.0, "damage":20.0, "friendly":true, "magic":false})
	game.enemy_shot(game.player, Vector2.ZERO, 100)
	game.simulate(0.0)
	check(game.state == "dead" and near(enemy.hp, 1000.0), "A lethal hostile projectile stops later same-tick friendly projectile damage")
	fresh_field()
	enemy = enemy_at("archer", game.player - Vector2(200, 0))
	game.update_enemy(enemy, 0.0)
	enemy.hp = 0.0
	game.update_enemy(enemy, 2.0)
	check(game.bullets.is_empty(), "An archer killed during its windup cannot release a delayed arrow")
	fresh_field()
	enemy = enemy_at("grunt", game.player - Vector2(30, 0))
	arm_active(enemy)
	game.enemies.erase(enemy)
	game.update_enemy(enemy, STEP)
	check(near(game.hp, 100.0) and not enemy.attack_hit, "An enemy reference removed from the arena cannot deal a stale hit")
	fresh_field()
	enemy = enemy_at("archer", game.player - Vector2(200, 0))
	game.update_enemy(enemy, 0.0)
	game.attack_cd = 0.0
	game.bow_cd = 0.0
	game.magic_cd = 0.0
	game.stats.projectiles = 1.0
	game.stats.magic = 1.0
	game.update_player_attacks(0.0, enemy)
	game.enemy_shot(game.player, Vector2.RIGHT, 100)
	game.stage += 1
	game.start_stage()
	game.hurt_cd = 0.0
	game.update_enemy(enemy, 5.0)
	check(game.sword_state == "idle" and game.sword_hits.is_empty() and game.bow_windup == 0 and game.cast_windup == 0 and game.bullets.is_empty() and near(game.hp, 100.0), "A new stage clears all sword/cast/projectile state and invalidates old enemy windups")
	fresh_field()
	enemy = enemy_at("grunt", game.player + Vector2(30, 0))
	game.attack_cd = 0.0
	game.update_player_attacks(0.0, enemy)
	game.show_pause()
	var timer = game.sword_time
	game._process(1.0)
	game.resume()
	game.update_player_attacks(STEP, enemy)
	check(game.sword_state == "windup" and near(game.sword_time, timer - STEP) and near(enemy.hp, 1000.0), "Resuming pause continues the remaining windup rather than skipping to an attack")

func test_guardian_patterns():
	var expected = [["cleave", "rootline", "charge", "thornwheel"], ["blast", "cinder_cross", "ember_bloom"], ["fan", "prism_lance", "ring", "crystal_spokes"], ["cleave", "eclipse", "charge", "nightfall", "blast"]]
	var fingerprints: Array = []
	for boss_type in range(4):
		fresh_field((boss_type + 1) * 5)
		var boss = enemy_at("boss", game.player - Vector2(100, 0))
		var patterns: Array = []
		var has_windups = true
		for attack in range(expected[boss_type].size()):
			boss.attack_state = "idle"
			boss.cooldown = 0.0
			game.update_enemy(boss, 0.0)
			patterns.append(boss.attack_pattern)
			has_windups = has_windups and boss.attack_state == "windup" and boss.attack_duration >= 0.6
		fingerprints.append(str(patterns))
		check(patterns == expected[boss_type] and has_windups, "%s has its own expected, consistently telegraphed attack sequence" % game.Combat.BOSS_NAMES[boss_type])
	var unique = true
	for i in range(fingerprints.size()):
		for j in range(i + 1, fingerprints.size()):
			unique = unique and fingerprints[i] != fingerprints[j]
	check(unique, "The four guardians have four distinct attack-pattern fingerprints")
	fresh_field(20)
	var sovereign = enemy_at("boss", game.player - Vector2(100, 0))
	sovereign.hp = sovereign.max_hp * 0.4
	var rage_patterns: Array = []
	var faster = true
	for attack in range(6):
		sovereign.attack_state = "idle"
		sovereign.cooldown = 0.0
		game.update_enemy(sovereign, 0.0)
		rage_patterns.append(sovereign.attack_pattern)
		faster = faster and near(sovereign.attack_duration, 0.85 if sovereign.attack_pattern in ["eclipse", "nightfall"] else 0.6)
	check(rage_patterns == ["cleave", "eclipse", "charge", "nightfall", "fan", "blast"] and faster, "Below half health the Night Sovereign gains a spread with 0.60-second warnings and longer 0.85-second new-hazard cues")

func test_frame_stall():
	fresh_field()
	var enemy = enemy_at("grunt", game.player)
	game._process(5.0)
	check(enemy.attack_state == "windup" and near(game.hp, 100.0) and game.elapsed <= 0.251, "A long rendered-frame stall is bounded and cannot skip a new enemy windup")
