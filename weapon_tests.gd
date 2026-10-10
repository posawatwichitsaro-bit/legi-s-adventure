extends SceneTree

# Exclusive primary-weapon and intentional secondary-weapon contracts.
# Run with: godot --headless --path . --script weapon_tests.gd
const STEP = 1.0 / 120.0
const PRIMARY = ["sword", "bow", "staff", "dagger"]
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

func fresh_field(build = 0, stage_number = 1):
	game.selected_build = build
	game.selected_ability = ""
	game.start_run()
	if stage_number != 1:
		game.stage = stage_number
		game.start_stage()
	game.enemies.clear()
	game.spawn_queue.clear()
	game.World.reset_hazards(game)
	game.world_data["hazards_enabled"] = false
	game.bullets.clear()
	game.obstacles.clear()
	game.gems.clear()
	game.potions.clear()
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

func enemy_at(offset: Vector2, health = 1000.0) -> Dictionary:
	game.spawn_enemy("grunt")
	var enemy = game.enemies.back()
	enemy.pos = game.player + offset
	enemy.hp = health
	enemy.max_hp = health
	enemy.cooldown = 99.0
	return enemy

func arm_primary(build: int):
	if build == 1: game.bow_cd = 0.0
	elif build == 2: game.magic_cd = 0.0
	else: game.attack_cd = 0.0

func attack_steps(duration: float):
	var remaining = duration
	while remaining > 0.000001:
		var dt = minf(STEP, remaining)
		game.update_player_attacks(dt, game.nearest_enemy(game.player))
		remaining -= dt

func run_tests():
	seed(781153)
	game = load("res://main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_process(false)
	game.rng.seed = 781153
	test_primary_contract()
	test_no_passive_damage()
	test_dagger_windows()
	test_bow_primary()
	test_staff_primary()
	test_cooldowns_and_caps()
	test_primary_cadence()
	test_range_benefits()
	test_intentional_secondary_attacks()
	test_interruption_and_reset()
	print("WEAPON_TESTS: ", passed, " passed; ", failures.size(), " failed")
	for failure in failures: print(" - ", failure)
	quit(0 if failures.is_empty() else 1)

func test_primary_contract():
	for build in range(4):
		fresh_field(build)
		check(game.primary_weapon() == PRIMARY[build], "%s path declares exactly its intended primary weapon" % PRIMARY[build].capitalize())
		check(near(game.stats.projectiles, 1.0 if build == 1 else 0.0) and near(game.stats.magic, 1.0 if build == 2 else 0.0) and near(game.stats.dash_damage, 22.0 if build == 3 else 0.0), "%s starts with only its own ranged or dash capability" % PRIMARY[build].capitalize())
		game.attack_cd = 0.0
		game.bow_cd = 0.0
		game.magic_cd = 0.0
		game.update_player_attacks(STEP, null)
		check(game.sword_state == "idle" and game.bow_windup == 0 and game.cast_windup == 0 and game.bullets.is_empty(), "%s cannot start an automatic attack without a living target" % PRIMARY[build].capitalize())
		var target = enemy_at(Vector2(35, 0))
		game.update_player_attacks(0.0, target)
		check((game.sword_state == "windup") == (build in [0, 3]) and (game.bow_windup > 0) == (build == 1) and (game.cast_windup > 0) == (build == 2), "%s starts only its exclusive primary, with no hidden attack channels" % PRIMARY[build].capitalize())
		attack_steps(0.065)
		check(near(target.hp, 1000.0) and game.bullets.is_empty(), "%s cannot deal damage or emit projectiles during early anticipation" % PRIMARY[build].capitalize())
		attack_steps(0.25)
		if build in [1, 2]:
			check(game.sword_state == "idle" and near(target.hp, 1000.0) and game.bullets.size() == 1, "%s release never adds an invisible melee hit or duplicate volley" % PRIMARY[build].capitalize())
		else:
			check(game.bullets.is_empty() and near(target.hp, 1000.0 - game.stats.damage * (0.82 if build == 3 else 1.0)), "%s release remains melee-only with its intended damage" % PRIMARY[build].capitalize())

func test_no_passive_damage():
	for build in range(4):
		fresh_field(build)
		var target = enemy_at(Vector2.ZERO)
		game.simulate(0.2)
		check(near(target.hp, 1000.0) and near(game.hp, 100.0) and game.sword_state == "idle" and game.bullets.is_empty(), "%s touching an enemy while all attacks are idle does no passive damage" % PRIMARY[build].capitalize())

func test_dagger_windows():
	fresh_field(3)
	var target = enemy_at(Vector2(40, 0))
	arm_primary(3)
	game.update_player_attacks(0.0, target)
	var aim = game.sword_aim
	attack_steps(0.075)
	check(game.sword_state == "windup" and near(game.sword_time, 0.005) and near(target.hp, 1000.0), "Dagger keeps its full 0.08-second anticipation")
	target.pos = game.player - Vector2(40, 0)
	attack_steps(0.01)
	check(game.sword_state == "active" and game.sword_aim == aim and near(target.hp, 1000.0), "Dagger locks its heading and misses a target that dodges behind")
	target.pos = game.player + Vector2(40, 0)
	game.update_player_attacks(0.0, target)
	var after_hit = target.hp
	attack_steps(0.04)
	check(near(after_hit, 1000.0 - 18.0 * 0.82) and near(target.hp, after_hit), "Dagger's active window deals exactly 82% base damage once per target")
	var far_target = enemy_at(Vector2(65, 0))
	var side_target = enemy_at(Vector2(0, 40))
	var close_target = enemy_at(Vector2(35, 8))
	game.update_player_attacks(0.0, close_target)
	check(near(far_target.hp, 1000.0) and near(side_target.hp, 1000.0) and near(close_target.hp, after_hit), "Dagger's 78% reach and narrow cone exclude distant and sideways targets while allowing another forward target")
	game.sword_time = STEP * 0.5
	var late_target = enemy_at(Vector2(30, 0))
	game.update_player_attacks(STEP, late_target)
	check(game.sword_state == "recover" and near(late_target.hp, 1000.0), "Dagger's expired active frame cannot hit a newly overlapping target")
	attack_steps(0.101)
	check(game.sword_state == "idle", "Dagger returns to idle after its 0.10-second recovery")
	game.attack_cd = 0.0
	game.update_player_attacks(0.0, target)
	attack_steps(0.085)
	check(near(target.hp, 1000.0 - 2 * 18.0 * 0.82), "A later dagger swing can damage a surviving target again")

func test_bow_primary():
	fresh_field(1)
	var target = enemy_at(Vector2(200, 0))
	arm_primary(1)
	game.update_player_attacks(0.0, target)
	var aim = game.bow_aim
	attack_steps(0.195)
	check(game.bow_windup > 0 and game.bullets.is_empty(), "Primary bow preserves its full 0.20-second visible draw")
	target.pos = game.player + Vector2(0, 180)
	attack_steps(0.01)
	check(game.bullets.size() == 1 and game.bow_aim == aim and game.bullets[0].vel.normalized().is_equal_approx(aim), "Primary bow releases exactly one arrow along its locked draw heading")
	if game.bullets.size() == 1:
		var arrow = game.bullets[0]
		check(arrow.friendly and not arrow.magic and near(arrow.damage, 16.2) and near(arrow.vel.length(), 340.0), "Primary bow arrow has its declared friendly type, speed and 90% damage")
	attack_steps(0.4)
	check(game.bullets.size() == 1 and game.sword_state == "idle" and game.cast_windup == 0, "A completed primary draw cannot release twice or start an unrelated weapon")
	for count in [1.0, 1.99, 2.0, 3.0, 4.0, 99.0]:
		fresh_field(1)
		target = enemy_at(Vector2(200, 0))
		game.stats.projectiles = count
		arm_primary(1)
		game.update_player_attacks(0.0, target)
		attack_steps(0.21)
		var expected = clampi(int(count), 1, 4)
		var correct = game.bullets.size() == expected
		for i in range(game.bullets.size()):
			correct = correct and near(game.bullets[i].vel.angle(), (i - (expected - 1) / 2.0) * 0.13) and near(game.bullets[i].damage, 16.2)
		check(correct, "Bow projectile count %.2f floors and caps to %d correctly spread arrows" % [count, expected])

func test_staff_primary():
	fresh_field(2)
	var target = enemy_at(Vector2(200, 0))
	arm_primary(2)
	game.update_player_attacks(0.0, target)
	var aim = game.get("cast_aim")
	attack_steps(0.275)
	check(game.cast_windup > 0 and game.bullets.is_empty(), "Staff preserves its full 0.28-second channel before emitting damage")
	target.pos = game.player + Vector2(0, 180)
	attack_steps(0.01)
	check(game.bullets.size() == 1 and game.get("cast_aim") == aim and game.bullets[0].vel.normalized().is_equal_approx(Vector2.RIGHT), "Staff releases one targeted bolt using its locked heading, rather than a radial burst")
	if game.bullets.size() == 1:
		var bolt = game.bullets[0]
		check(bolt.friendly and bolt.magic and near(bolt.damage, 19.8) and near(bolt.vel.length(), 260.0) and near(bolt.life, 2.5), "Staff bolt has the declared magic type, 110% damage, speed and lifetime")
		game.hp = 40.0
		game.stats.lifesteal = 0.1
		bolt.pos = target.pos
		bolt.vel = Vector2.ZERO
		game.simulate(0.0)
		check(near(target.hp, 980.2) and near(game.hp, 41.98) and game.bullets.is_empty(), "Staff impact deals actual damage once and routes healing through Life Drain")
	for power in [1.0, 2.0, 3.0]:
		fresh_field(2)
		target = enemy_at(Vector2(200, 0))
		game.stats.magic = power
		arm_primary(2)
		game.update_player_attacks(0.0, target)
		attack_steps(0.29)
		check(game.bullets.size() == 1 and near(game.bullets[0].damage, 18.0 * (1.1 + 0.2 * (power - 1))) and game.sword_state == "idle", "Staff power %d strengthens one bolt without secretly enabling sword or radial damage" % int(power))

func test_cooldowns_and_caps():
	for build in range(4):
		fresh_field(build)
		var target = enemy_at(Vector2(200, 0))
		game.apply_stats({"attack_speed": 999.0, "damage": 999.0, "range": 999.0, "projectiles": 999.0, "magic": 999.0})
		arm_primary(build)
		game.update_player_attacks(0.0, target)
		var actual_cd = game.bow_cd if build == 1 else (game.magic_cd if build == 2 else game.attack_cd)
		var base_cd = 0.62 if build == 3 else (0.95 if build == 2 else 0.85)
		check(near(game.stats.attack_speed, 2.2) and near(actual_cd, base_cd / 2.2), "%s primary cooldown obeys the shared attack-speed cap without skipping anticipation" % PRIMARY[build].capitalize())
		check(near(game.stats.damage, 80.0) and near(game.stats.range, 145.0) and near(game.stats.projectiles, 4.0) and near(game.stats.magic, 3.0), "%s still obeys shared damage, reach, projectile and magic caps" % PRIMARY[build].capitalize())
		for upgrade in game.D.UPGRADES:
			for attempt in range(upgrade.cap + 2): game.apply_upgrade(upgrade.id)
		var before = game.stats.duplicate(true)
		for upgrade in game.D.UPGRADES: game.apply_upgrade(upgrade.id)
		check(game.stats == before and game.stats.attack_speed <= 2.2 and game.stats.damage <= 80.0 and game.stats.projectiles <= 4.0 and game.stats.magic <= 3.0, "%s cannot overstack capped upgrades through its exclusive primary" % PRIMARY[build].capitalize())

func test_range_benefits():
	for build in [1, 2]:
		for reach in [1.0, 78.0, 106.0, 145.0]:
			fresh_field(build)
			game.stats.range = reach
			var target = enemy_at(Vector2(200, 0))
			arm_primary(build)
			game.update_player_attacks(0.0, target)
			attack_steps(0.29)
			var base_speed = 340.0 if build == 1 else 260.0
			check(game.bullets.size() == 1 and near(game.bullets[0].vel.length(), base_speed + maxf(0, reach - 78.0)) and near(game.bullets[0].life, 2.5), "%s reach %.0f applies only its declared bounded aimed-projectile speed bonus" % [PRIMARY[build].capitalize(), reach])
		fresh_field(build)
		var before = game.stats.range
		check(game.apply_upgrade("long_reach") and game.stats.range > before, "%s can obtain a useful Long Reach upgrade instead of a dead melee stat" % PRIMARY[build].capitalize())
	fresh_field(0)
	game.stats.range = 145.0
	game.stats.magic = 1.0
	var target = enemy_at(Vector2(200, 0))
	game.magic_cd = 0.0
	game.update_player_attacks(0.0, target)
	attack_steps(0.29)
	var unchanged = game.bullets.size() == 8
	for bullet in game.bullets: unchanged = unchanged and near(bullet.vel.length(), 160.0) and near(bullet.life, 1.6)
	check(unchanged, "Long Reach does not accidentally increase secondary radial-magic speed or lifetime")

func test_intentional_secondary_attacks():
	for build in range(4):
		fresh_field(build)
		var target = enemy_at(Vector2(200, 0))
		game.apply_upgrade("split_shot")
		game.apply_upgrade("starlight")
		game.attack_cd = 0.0
		game.bow_cd = 0.0
		game.magic_cd = 0.0
		game.update_player_attacks(0.0, target)
		var expected_bow_cd = (0.85 if build == 1 else 1.4) / game.stats.attack_speed
		var expected_magic_cd = (0.95 if build == 2 else 2.3) / game.stats.attack_speed
		check(near(game.bow_cd, expected_bow_cd) and near(game.magic_cd, expected_magic_cd), "%s explicit secondary unlocks keep primary and secondary cooldowns distinct" % PRIMARY[build].capitalize())
		attack_steps(0.30)
		var arrow_count = 0
		var magic_count = 0
		for bullet in game.bullets:
			if bullet.magic: magic_count += 1
			else: arrow_count += 1
		check(arrow_count == (2 if build == 1 else 1) and magic_count == (1 if build == 2 else 8), "%s only acquires extra attack channels through explicit upgrades, with no duplicate primary release" % PRIMARY[build].capitalize())
		check(game.sword_state == "idle" if build in [1, 2] else game.sword_aim == Vector2.RIGHT, "%s retains its original primary identity after acquiring ranged upgrades" % PRIMARY[build].capitalize())

func test_interruption_and_reset():
	for build in range(4):
		for mode in ["paused", "upgrade", "loot", "menu", "dead", "won"]:
			fresh_field(build)
			var target = enemy_at(Vector2(35, 0))
			arm_primary(build)
			game.update_player_attacks(0.0, target)
			var timers = [game.sword_time, game.bow_windup, game.cast_windup]
			game.state = mode
			game.update_player_attacks(2.0, target)
			check([game.sword_time, game.bow_windup, game.cast_windup] == timers and near(target.hp, 1000.0) and game.bullets.is_empty(), "%s primary freezes safely in %s state" % [PRIMARY[build].capitalize(), mode])
		fresh_field(build)
		var target = enemy_at(Vector2(35, 0))
		arm_primary(build)
		game.update_player_attacks(0.0, target)
		var reset_ok = true
		for stage_number in range(1, 21):
			game.stage = stage_number
			game.start_stage()
			reset_ok = reset_ok and game.primary_weapon() == PRIMARY[build] and game.sword_state == "idle" and game.sword_hits.is_empty() and game.bow_windup == 0 and game.cast_windup == 0 and game.bullets.is_empty()
		check(reset_ok, "%s remains exclusive and clears unfinished attack state across all 20 stages" % PRIMARY[build].capitalize())
		game.start_run()
		check(game.primary_weapon() == PRIMARY[build] and game.stage == 1 and game.upgrade_ranks.is_empty(), "%s replay starts cleanly with its chosen primary and no stale run ranks" % PRIMARY[build].capitalize())

func test_primary_cadence():
	for build in range(4):
		fresh_field(build)
		game.stats.attack_speed = 2.2
		var target = enemy_at(Vector2(35, 0), 10000.0)
		arm_primary(build)
		game.update_player_attacks(0.0, target)
		var releases = 0
		# Two seconds avoids a substep-quantization boundary at the fourth dagger release.
		for frame in range(240):
			var previous_sword = game.sword_state
			var previous_bow = game.bow_release_time
			var previous_cast = game.cast_release_time
			game.simulate(STEP)
			if build in [0, 3] and previous_sword != "active" and game.sword_state == "active": releases += 1
			if build == 1 and game.bow_release_time > previous_bow: releases += 1
			if build == 2 and game.cast_release_time > previous_cast: releases += 1
		var expected = [5, 5, 4, 7][build]
		check(releases == expected, "%s capped-speed runtime releases exactly %d attacks in the first two seconds (observed %d) without skipping phases or duplicating fire" % [PRIMARY[build].capitalize(), expected, releases])
