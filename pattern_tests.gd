extends SceneTree

# Late-game roster, guardian geometry, and authoritative attack-window tests.
# No screenshots or runtime balance simulation are substituted for these checks.
const STEP = 1.0 / 120.0
const NEW_KINDS = ["sentinel", "assassin", "chanter", "hexer"]
const BOSS_NEW = [
	{"stage":5, "index":1, "pattern":"rootline", "count":3},
	{"stage":5, "index":3, "pattern":"thornwheel", "count":1},
	{"stage":10, "index":1, "pattern":"cinder_cross", "count":2},
	{"stage":10, "index":2, "pattern":"ember_bloom", "count":4},
	{"stage":15, "index":1, "pattern":"prism_lance", "count":3},
	{"stage":15, "index":3, "pattern":"crystal_spokes", "count":6},
	{"stage":20, "index":1, "pattern":"eclipse", "count":1},
	{"stage":20, "index":3, "pattern":"nightfall", "count":3},
	{"stage":25, "index":0, "pattern":"storm_lanes", "count":3},
	{"stage":25, "index":1, "pattern":"thunder_crown", "count":1},
	{"stage":25, "index":2, "pattern":"storm_sweep", "count":1},
	{"stage":30, "index":0, "pattern":"solar_lance", "count":2},
	{"stage":30, "index":1, "pattern":"dawn_rings", "count":1},
	{"stage":30, "index":2, "pattern":"eclipse_seals", "count":4},
]
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

func fresh_field(stage_number = 11):
	game.selected_class = 0
	game.selected_skill = ""
	game.start_run()
	# Isolate old collision/healing rules from redesigned Class attributes and chance.
	game.stats.max_hp=100.0;game.hp=100.0
	game.stats.critical_rate=0;game.stats.dodge_rate=0;game.stats.block_rate=0
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

func enemy_at(kind: String, offset: Vector2) -> Dictionary:
	game.spawn_enemy(kind)
	var enemy = game.enemies.back()
	enemy.pos = game.player + offset
	enemy.hp = 1000.0
	enemy.max_hp = 1000.0
	enemy.cooldown = 0.0
	enemy.attack_origin = enemy.pos
	enemy.attack_target = enemy.pos
	return enemy

func enemy_steps(enemy: Dictionary, seconds: float, clear_immunity = false):
	var left = seconds
	while left > 0.000001:
		var dt = minf(STEP, left)
		if clear_immunity: game.hurt_cd = 0.0
		game.update_enemy(enemy, dt)
		left -= dt

func until_state(enemy: Dictionary, wanted: String, max_seconds = 4.0) -> bool:
	for frame in range(ceili(max_seconds / STEP)):
		if enemy.attack_state == wanted: return true
		game.update_enemy(enemy, STEP)
	return enemy.attack_state == wanted

func run_tests():
	seed(129751)
	game = load("res://main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_process(false)
	game.rng.seed = 129751
	test_roster_progression()
	test_sentinel()
	test_sentinel_mitigation()
	test_assassin()
	test_chanter()
	test_hexer()
	test_lunge_cue_containment()
	test_lunges_stop_at_walls()
	test_shape_boundaries()
	test_new_guardian_moves()
	test_nightfall_sequence()
	test_natural_guardian_cycles()
	test_far_guardian_reachability()
	test_late_pressure_bounds()
	test_expired_hazard_windows()
	test_dead_and_stale_attacks()
	print("PATTERN_TESTS: ", passed, " passed; ", failures.size(), " failed")
	for failure in failures: print(" - ", failure)
	quit(0 if failures.is_empty() else 1)

func test_roster_progression():
	game.start_run()
	for stage_number in range(1, 21):
		game.stage = stage_number
		game.start_stage()
		var counts = {}
		for enemy in game.enemies: counts[enemy.kind] = counts.get(enemy.kind, 0) + 1
		for kind in game.spawn_queue: counts[kind] = counts.get(kind, 0) + 1
		var correct = true
		for kind in NEW_KINDS:
			var unlocked = stage_number >= (6 if kind in ["sentinel", "assassin"] else 11)
			correct = correct and (counts.get(kind, 0) > 0) == unlocked
		check(correct, "Stage %02d introduces new roles only at their intended progression gates" % stage_number)
		check(game.enemies.size() + game.spawn_queue.size() == ceili((8 + stage_number * 2 + (1 if stage_number % 5 == 0 else 0)) * 1.25) and counts.get("herbalist", 0) == 1 and counts.get("archer", 0) > 0 and counts.get("grunt", 0) > 0, "Stage %02d supplies its 25%% larger roster, one healer carrier, and basic melee/ranged roles across all groups" % stage_number)
	for kind in NEW_KINDS:
		fresh_field()
		var enemy = enemy_at(kind, Vector2.ZERO)
		enemy.cooldown = 99.0
		game.simulate(STEP)
		check(near(game.hp, 100.0) and enemy.attack_state == "idle", "%s idle overlap has no passive collision damage" % kind.capitalize())
		enemy.cooldown = 0.0
		game.update_enemy(enemy, 0.0)
		enemy_steps(enemy, 0.2)
		check(enemy.attack_state == "windup" and near(game.hp, 100.0) and game.bullets.is_empty(), "%s overlap stays harmless throughout its visible initial warning" % kind.capitalize())

func test_sentinel():
	fresh_field()
	var sentinel = enemy_at("sentinel", Vector2(-35, 0))
	game.update_enemy(sentinel, 0.0)
	check(sentinel.attack_pattern == "shield_bash" and sentinel.attack_state == "windup", "Sentinel commits to a visible shield-bash attack")
	var origin = sentinel.pos
	var aim = sentinel.attack_aim
	game.player = origin - Vector2(35, 0)
	until_state(sentinel, "active")
	check(near(game.hp, 100.0) and sentinel.attack_aim == aim and sentinel.pos == origin, "Sentinel's anchored frontal bash misses a dodge behind its shield")
	game.player = origin + Vector2(35, 0)
	game.update_enemy(sentinel, 0.0)
	var after_hit = game.hp
	enemy_steps(sentinel, 0.05, true)
	check(after_hit < 100.0 and near(game.hp, after_hit) and sentinel.attack_hit, "Sentinel bash connects once even if invulnerability is forcibly removed")
	until_state(sentinel, "recover")
	game.hurt_cd = 0.0
	game.player = sentinel.pos
	game.update_enemy(sentinel, 0.0)
	check(near(game.hp, after_hit), "Sentinel recovery is harmless while overlapping")

func test_assassin():
	fresh_field()
	var assassin = enemy_at("assassin", Vector2(-90, 0))
	game.update_enemy(assassin, 0.0)
	var origin = assassin.pos
	var aim = assassin.attack_aim
	game.player += Vector2(0, 130)
	until_state(assassin, "recover")
	check(assassin.attack_pattern == "shadow_lunge" and assassin.pos.x > origin.x and near(assassin.pos.y, origin.y) and assassin.attack_aim == aim and near(game.hp, 100.0), "Assassin follows its committed lunge lane and misses a sideways dodge")
	fresh_field()
	assassin = enemy_at("assassin", Vector2(-90, 0))
	game.update_enemy(assassin, 0.0)
	until_state(assassin, "active")
	for frame in range(100):
		game.hurt_cd = 0.0
		game.update_enemy(assassin, STEP)
		if assassin.attack_hit: break
	var after_hit = game.hp
	enemy_steps(assassin, 0.2, true)
	check(after_hit < 100.0 and near(game.hp, after_hit) and assassin.attack_hit, "Assassin lunge hits its lane once for the entire movement window")

func test_chanter():
	fresh_field()
	var chanter = enemy_at("chanter", Vector2(-120, 0))
	var ally = enemy_at("grunt", Vector2(-80, 60))
	var distant = enemy_at("grunt", Vector2(250, 160))
	ally.cooldown = 99.0
	distant.cooldown = 99.0
	game.update_enemy(chanter, 0.0)
	enemy_steps(chanter, 0.2)
	check(chanter.attack_pattern == "chant" and float(ally.get("haste_time", 0)) == 0 and game.bullets.is_empty(), "Chanter cannot grant support or emit projectiles before its chant finishes")
	until_state(chanter, "active")
	check(float(ally.get("haste_time", 0)) > 0 and float(distant.get("haste_time", 0)) == 0 and near(game.hp, 100.0) and game.bullets.is_empty(), "Chant hastes only nearby living allies and inflicts no direct contact damage")
	var duration = float(ally.get("haste_time", 0))
	game.update_enemy(ally, 0.25)
	check(float(ally.get("haste_time", 0)) < duration and float(ally.get("haste_time", 0)) >= 0, "Chanter's ally haste counts down instead of becoming permanent")
	until_state(chanter, "idle")
	chanter.cooldown = 0.0
	game.update_enemy(chanter, 0.0)
	check(chanter.attack_pattern == "pulse" and chanter.attack_state == "windup" and game.bullets.is_empty(), "Chanter alternates its support chant with a separately telegraphed pulse")
	var aim = chanter.attack_aim
	game.player += Vector2(0, 130)
	until_state(chanter, "active")
	var released = game.bullets.size() == 3
	for i in range(game.bullets.size()):
		released = released and not game.bullets[i].friendly and game.bullets[i].vel.normalized().is_equal_approx(aim.rotated((i - 1) * 0.15))
	enemy_steps(chanter, 0.05)
	check(released and game.bullets.size() == 3 and near(game.hp, 100.0), "Chanter pulse releases exactly three locked-direction hostile shots once")

func test_hexer():
	fresh_field()
	var hexer = enemy_at("hexer", Vector2(-180, 0))
	game.update_enemy(hexer, 0.0)
	var marked = hexer.attack_target
	game.player += Vector2(100, 0)
	until_state(hexer, "active")
	check(hexer.attack_pattern == "hex_pool" and hexer.attack_target == marked and near(game.hp, 100.0), "Hexer leaves its marked pool anchored and misses a player who leaves the circle")
	game.player = marked
	game.update_enemy(hexer, 0.0)
	var after_hit = game.hp
	enemy_steps(hexer, 0.75, true)
	check(after_hit < 100.0 and near(game.hp, after_hit) and hexer.attack_state == "active" and hexer.attack_hit, "Hexer's lingering pool has a real active window but can damage only once per cast")
	until_state(hexer, "recover")
	game.hurt_cd = 0.0
	game.update_enemy(hexer, 0.0)
	check(near(game.hp, after_hit), "Expired hex pool is harmless even at its exact former center")

func test_shape_boundaries():
	var shapes = [
		{"shape":{"type":"circle", "center":Vector2.ZERO, "radius":40.0}, "in":Vector2(39.9, 0), "out":Vector2(40.1, 0)},
		{"shape":{"type":"annulus", "center":Vector2.ZERO, "inner":58.0, "radius":132.0}, "in":Vector2(80, 0), "out":Vector2(57.9, 0)},
		{"shape":{"type":"lane", "a":Vector2.ZERO, "b":Vector2(100, 0), "radius":14.0}, "in":Vector2(50, 13.9), "out":Vector2(50, 14.1)},
		{"shape":{"type":"sector", "center":Vector2.ZERO, "radius":76.0, "aim":Vector2.RIGHT, "half":1.05}, "in":Vector2.RIGHT.rotated(1.04) * 50, "out":Vector2.RIGHT.rotated(1.06) * 50},
	]
	for entry in shapes:
		check(game.Combat.shape_contains(entry.shape, entry["in"]) and not game.Combat.shape_contains(entry.shape, entry["out"]), "%s telegraph geometry respects its declared interior and exterior boundary" % str(entry.shape.type).capitalize())
	var ring = {"type":"annulus", "center":Vector2.ZERO, "inner":58.0, "radius":132.0}
	check(not game.Combat.shape_contains(ring, Vector2.ZERO) and not game.Combat.shape_contains(ring, Vector2(132.1, 0)), "Annular hazards preserve their safe central hole and safe outer edge")

func hazard_and_safe(enemy: Dictionary) -> Array:
	var origin = enemy.attack_origin
	var target = enemy.attack_target
	match enemy.attack_pattern:
		"storm_lanes":return [origin+Vector2(150,0),origin+Vector2(150,40)]
		"thunder_crown","dawn_rings":return [origin+Vector2(120,0),origin]
		"storm_sweep":return [origin+Vector2(80,0),origin-Vector2(80,0)]
		"solar_lance":return [origin+Vector2(150,48),origin+Vector2(150,0)]
		"eclipse_seals":return [target+Vector2(74,0),target]
		"rootline": return [origin + Vector2(66, 0), origin]
		"thornwheel": return [origin + Vector2(90, 0), origin]
		"cinder_cross": return [target + Vector2(70, 0), target + Vector2(70, 70)]
		"ember_bloom": return [target + Vector2(68, 0), target]
		"prism_lance": return [origin + Vector2(140, 0), origin + Vector2(140, 33)]
		"crystal_spokes": return [origin + Vector2(130, 0), origin + Vector2.RIGHT.rotated(PI / 6) * 130]
		"eclipse": return [origin + Vector2(110, 0), origin]
		"nightfall": return [target, target + Vector2(100, 0)]
	return [target, origin]

func test_new_guardian_moves():
	for entry in BOSS_NEW:
		fresh_field(entry.stage)
		var boss = enemy_at("boss", Vector2(-100, 0))
		boss.attack_index = entry.index
		game.update_enemy(boss, 0.0)
		check(boss.attack_pattern == entry.pattern and boss.attack_state == "windup" and boss.attack_duration >= 0.6, "%s is reachable from its guardian's normal sequence with a visible warning" % entry.pattern.capitalize())
		var points = hazard_and_safe(boss)
		var origin = boss.attack_origin
		var aim = boss.attack_aim
		var target = boss.attack_target
		var preview = game.Combat.attack_shapes(boss, true).duplicate(true)
		check(preview.size() == entry.count, "%s exposes every marked component before release" % entry.pattern.capitalize())
		game.player = points[1]
		enemy_steps(boss, 0.2)
		check(boss.attack_state == "windup" and near(game.hp, 100.0) and game.bullets.is_empty(), "%s cannot damage or emit hidden projectiles during anticipation" % entry.pattern.capitalize())
		until_state(boss, "active")
		check(boss.attack_origin == origin and boss.attack_target == target and boss.attack_aim == aim and game.Combat.attack_shapes(boss, true) == preview, "%s retains the exact geometry shown before the player dodged" % entry.pattern.capitalize())
		check(near(game.hp, 100.0) and not game.Combat.attack_connects(boss, points[1]) and game.Combat.attack_connects(boss, points[0]), "%s has a tested safe dodge pocket and damaging marked region" % entry.pattern.capitalize())
		game.player = points[0]
		game.update_enemy(boss, 0.0)
		var after_hit = game.hp
		enemy_steps(boss, 0.055, true)
		check(after_hit < 100.0 and near(game.hp, after_hit) and boss.attack_hit, "%s deals at most one hit during an active attack even without invulnerability" % entry.pattern.capitalize())
		until_state(boss, "recover")
		game.hurt_cd = 0.0
		game.update_enemy(boss, 0.0)
		check(near(game.hp, after_hit), "%s recovery has no leftover hazard damage" % entry.pattern.capitalize())
		# Runtime collision must agree with the displayed shape union on a dense grid.
		boss.attack_state = "active"
		var geometry_agrees = true
		var shapes = game.Combat.attack_shapes(boss)
		for y in range(160, 540, 19):
			for x in range(80, 880, 19):
				var point = Vector2(x, y)
				var marked = false
				for shape in shapes: marked = marked or game.Combat.shape_contains(shape, point)
				geometry_agrees = geometry_agrees and game.Combat.attack_connects(boss, point) == marked
		check(geometry_agrees, "%s authoritative hit detection matches its telegraph-shape union across the arena" % entry.pattern.capitalize())

func test_nightfall_sequence():
	fresh_field(20)
	var boss = enemy_at("boss", Vector2(-100, 0))
	boss.attack_index = 3
	game.update_enemy(boss, 0.0)
	var preview = game.Combat.attack_shapes(boss, true)
	game.player += Vector2(150, 0)
	until_state(boss, "active")
	var first = game.Combat.attack_shapes(boss)
	check(preview.size() == 3 and first.size() == 1 and first[0].center == preview[0].center, "Nightfall warns all three positions but activates only its first marked beat")
	game.player = first[0].center
	game.update_enemy(boss, 0.0)
	var after_hit = game.hp
	enemy_steps(boss, 0.35, true)
	var second = game.Combat.attack_shapes(boss)
	check(second.size() == 1 and second[0].center == preview[1].center and second[0].center != first[0].center, "Nightfall's second beat moves only to the second premarked position")
	game.player = second[0].center
	game.hurt_cd = 0.0
	game.update_enemy(boss, 0.0)
	enemy_steps(boss, 0.34, true)
	var third = game.Combat.attack_shapes(boss)
	check(third.size() == 1 and third[0].center == preview[2].center and third[0].center != second[0].center, "Nightfall's final beat moves only to the third premarked position")
	game.player = third[0].center
	game.hurt_cd = 0.0
	game.update_enemy(boss, 0.0)
	check(after_hit < 100.0 and near(game.hp, after_hit), "Nightfall shares one-hit protection across all three beats")

func test_dead_and_stale_attacks():
	for kind in NEW_KINDS:
		fresh_field()
		var enemy = enemy_at(kind, Vector2(-30, 0))
		game.update_enemy(enemy, 0.0)
		enemy.hp = 0.0
		game.update_enemy(enemy, 5.0)
		check(near(game.hp, 100.0) and game.bullets.is_empty() and not enemy.attack_hit, "A %s killed during anticipation cannot finish a delayed attack" % kind)
	for entry in BOSS_NEW:
		fresh_field(entry.stage)
		var boss = enemy_at("boss", Vector2(-100, 0))
		boss.attack_index = entry.index
		game.update_enemy(boss, 0.0)
		game.enemies.erase(boss)
		game.update_enemy(boss, 5.0)
		check(near(game.hp, 100.0) and game.bullets.is_empty() and not boss.attack_hit, "A removed guardian's %s cannot damage through a stale reference" % entry.pattern)

func test_sentinel_mitigation():
	for attack_state in ["idle", "windup", "active", "recover"]:
		for side in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP]:
			fresh_field()
			var sentinel = enemy_at("sentinel", Vector2(-60, 0))
			sentinel.facing = Vector2.RIGHT
			sentinel.attack_state = attack_state
			game.hp = 40.0
			game.stats.lifesteal = 0.1
			var expected = 11.0 if side == Vector2.RIGHT and attack_state in ["idle", "windup"] else 20.0
			var dealt = game.damage_enemy(sentinel, 20.0, sentinel.pos + side * 35)
			check(near(dealt, expected) and near(sentinel.hp, 1000.0 - expected) and near(game.hp, 40.0 + expected * 0.1), "Sentinel %s %s hit applies directional shielding before actual-damage Life Drain" % [attack_state, str(side)])
	fresh_field()
	var sentinel = enemy_at("sentinel", Vector2(-60, 0))
	sentinel.facing = Vector2.RIGHT
	sentinel.hp = 5.0
	game.hp = 40.0
	game.stats.lifesteal = 0.1
	var dealt = game.damage_enemy(sentinel, 100.0, sentinel.pos + Vector2(30, 0))
	check(near(dealt, 5.0) and near(game.hp, 40.5), "Shielded overkill drains only remaining health, never pre-mitigation or nominal damage")
	for side in [Vector2.RIGHT, Vector2.LEFT]:
		fresh_field()
		sentinel = enemy_at("sentinel", Vector2(-60, 0))
		sentinel.facing = Vector2.RIGHT
		sentinel.cooldown = 99.0
		game.bullets.append({"pos":sentinel.pos + side * 10, "vel":-side * 340, "life":1.0, "damage":20.0, "friendly":true, "magic":false})
		game.simulate(0.0)
		check(near(sentinel.hp, 1000.0 - (11.0 if side == Vector2.RIGHT else 20.0)) and game.bullets.is_empty(), "Sentinel projectile impact uses the actual incoming side %s for shield protection" % str(side))

func test_far_guardian_reachability():
	for stage_number in [5, 10, 15, 20]:
		for distance in [220.0, 400.0]:
			fresh_field(stage_number)
			var boss = enemy_at("boss", Vector2(-distance, 0))
			game.update_enemy(boss, 0.0)
			var expected = "blast" if stage_number == 10 else ("fan" if stage_number == 15 else ("rootline" if stage_number == 5 and distance == 220.0 else "charge"))
			check(boss.attack_state == "windup" and boss.attack_pattern == expected, "Stage %d guardian selects %s at %.0f pixels instead of stalling on short melee" % [stage_number, expected, distance])
			check(boss.attack_aim == Vector2.RIGHT and boss.attack_target == game.player and near(game.hp, 100.0), "Stage %d guardian's far-target selection retains a harmless locked warning at %.0f pixels" % [stage_number, distance])

func test_late_pressure_bounds():
	for kind in ["grunt", "archer", "swift", "bomber", "ghost", "herbalist"] + NEW_KINDS:
		fresh_field(20)
		var enemy = enemy_at(kind, Vector2(-30, 0))
		var early_speed = game.Combat.movement_speed(enemy, 6)
		var late_speed = game.Combat.movement_speed(enemy, 20)
		var early_cd = game.Combat.recovery_cooldown(enemy, 6)
		var late_cd = game.Combat.recovery_cooldown(enemy, 20)
		game.update_enemy(enemy, 0.0)
		check(late_speed > early_speed and late_speed <= 225.0 and late_cd < early_cd and late_cd >= 0.34 and enemy.attack_duration >= 0.38, "%s late-game pressure increases movement and cadence within speed, cooldown, and warning floors" % kind.capitalize())
		enemy.haste_time = 3.0
		check(game.Combat.movement_speed(enemy, 20) <= 225.0 and game.Combat.recovery_cooldown(enemy, 20) >= 0.34, "%s chant haste cannot bypass the late-game speed or recovery limits" % kind.capitalize())

func test_lunge_cue_containment():
	for entry in [{"kind":"ghost", "stage":1, "index":0}, {"kind":"assassin", "stage":11, "index":0}, {"kind":"boss", "stage":5, "index":2}]:
		fresh_field(entry.stage)
		var enemy = enemy_at(entry.kind, Vector2(-90, 0))
		enemy.attack_index = entry.index
		game.update_enemy(enemy, 0.0)
		var lane = game.Combat.attack_shapes(enemy, true)[0]
		var radius = lane.radius
		game.player += Vector2(0, 170)
		var contained = true
		var max_travel = 0.0
		for frame in range(240):
			game.update_enemy(enemy, STEP)
			if enemy.attack_state == "active":
				max_travel = maxf(max_travel, enemy.pos.distance_to(enemy.attack_origin))
				# The leading edge of each active circle must remain inside the shown capsule.
				var leading_inside = enemy.pos + enemy.attack_aim * (radius - 0.01)
				contained = contained and game.Combat.shape_contains(lane, leading_inside)
			if enemy.attack_state == "recover": break
		check(contained, "%s actual lunge damage stays within its premarked capsule (travel %.3f, shown %.3f)" % [entry.kind.capitalize(), max_travel, lane.a.distance_to(lane.b)])

func test_natural_guardian_cycles():
	var sequences = [
		{"stage":5, "rage":false, "expected":["cleave", "rootline", "charge", "thornwheel"]},
		{"stage":10, "rage":false, "expected":["blast", "cinder_cross", "ember_bloom"]},
		{"stage":15, "rage":false, "expected":["fan", "prism_lance", "ring", "crystal_spokes"]},
		{"stage":20, "rage":false, "expected":["cleave", "eclipse", "charge", "nightfall", "blast"]},
		{"stage":20, "rage":true, "expected":["cleave", "eclipse", "charge", "nightfall", "fan", "blast"]},
	]
	for entry in sequences:
		fresh_field(entry.stage)
		var boss = enemy_at("boss", Vector2(-100, 0))
		if entry.rage: boss.hp = boss.max_hp * 0.4
		game.hurt_cd = 99.0
		var seen = []
		for frame in range(7200):
			# Keep in encounter range while allowing every real active/recovery/cooldown.
			if boss.attack_state == "idle": game.player = boss.pos + Vector2(100, 0)
			var before = boss.attack_state
			game.update_enemy(boss, STEP)
			if before == "idle" and boss.attack_state == "windup": seen.append(boss.attack_pattern)
			if seen.size() >= entry.expected.size() * 2: break
		check(seen == entry.expected + entry.expected, "Stage %d guardian%s naturally completes and repeats its entire attack cycle without forced attack-state resets" % [entry.stage, " in rage" if entry.rage else ""])

func test_expired_hazard_windows():
	for entry in BOSS_NEW:
		fresh_field(entry.stage)
		var boss = enemy_at("boss", Vector2(-100, 0))
		boss.attack_index = entry.index
		game.update_enemy(boss, 0.0)
		var points = hazard_and_safe(boss)
		game.player = points[1]
		until_state(boss, "active")
		boss.attack_time = STEP * 0.5
		game.player = points[0]
		game.update_enemy(boss, STEP)
		check(boss.attack_state == "recover" and near(game.hp, 100.0) and not boss.attack_hit, "%s cannot hit a player who enters on the first expired active frame" % entry.pattern.capitalize())

func test_lunges_stop_at_walls():
	for entry in [{"kind":"ghost", "stage":1, "index":0}, {"kind":"assassin", "stage":11, "index":0}, {"kind":"boss", "stage":5, "index":2}]:
		fresh_field(entry.stage)
		game.player = Vector2(380, 380)
		var enemy = enemy_at(entry.kind, Vector2(-80, -80))
		enemy.attack_index = entry.index
		game.obstacles = [Rect2(335, 250, 20, 200)]
		# Start directly so the ghost's shorter trigger does not obscure the movement check.
		game.Combat.begin(game, enemy)
		var lane = game.Combat.attack_shapes(enemy, true)[0]
		var locked_aim = enemy.attack_aim
		var inline = true
		var blocked_safe = true
		for frame in range(240):
			game.update_enemy(enemy, STEP)
			var displacement = enemy.pos - enemy.attack_origin
			inline = inline and absf(displacement.cross(locked_aim)) < 0.001
			blocked_safe = blocked_safe and not game.blocked(enemy.pos, 26 if entry.kind == "boss" else 16)
			if enemy.attack_state == "recover": break
		check(inline and blocked_safe and near(game.hp, 100.0) and game.Combat.shape_contains(lane, enemy.pos), "%s diagonal lunge stops at a wall without sliding outside its marked lane or tunneling" % entry.kind.capitalize())
