extends SceneTree

var game
var failures: Array[String] = []
var passed = 0
var saved_profile_text = ""
var had_profile = false

func _initialize():
	call_deferred("run_tests")

func check(condition: bool, message: String):
	if condition:
		passed += 1
		print("PASS: ", message)
	else:
		failures.append(message)
		print("FAIL: ", message)

func run_tests():
	# Save/restore any existing profile so this harness is safe outside CI, too.
	had_profile = FileAccess.file_exists("user://legis_adventure.json")
	if had_profile:
		saved_profile_text = FileAccess.get_file_as_string("user://legis_adventure.json")
	seed(1760)
	game = load("res://main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_process(false)
	game.rng.seed = 1760
	# _ready loads the user's profile even in test mode. Gameplay fixtures must
	# start with the sword and no persistent ability, regardless of that save.
	game.selected_class = 0
	game.selected_skill = ""
	game.start_run()
	game.level = 5
	game.pending_choices = 1
	game.show_tactics()
	var button = game.panel.get_child(1).get_child(2)
	button.pressed.emit()
	var accepted_stats = game.stats.duplicate(true)
	button.pressed.emit()
	check(game.pending_choices == 0 and game.stats == accepted_stats, "Upgrade callback cannot grant reward twice")

	game.start_run()
	game.stage = 5
	game.show_loot()
	button = game.panel.get_child(1).get_child(2)
	button.pressed.emit()
	accepted_stats = game.stats.duplicate(true)
	button.pressed.emit()
	check(game.run_equipment.size() == 1 and game.stats == accepted_stats, "Loot callback cannot grant reward twice")

	game.start_run()
	game.level = 5
	game.pending_choices = 1
	game.show_tactics()
	button = game.panel.get_child(1).get_child(2)
	game.show_menu()
	accepted_stats = game.stats.duplicate(true)
	button.pressed.emit()
	check(game.state == "menu" and game.stats == accepted_stats, "Stale upgrade callback cannot resume an abandoned run")

	game.start_run()
	game.level = 5
	game.pending_choices = 1
	game.show_tactics()
	button = game.panel.get_child(1).get_child(2)
	game.show_tactics()
	accepted_stats = game.stats.duplicate(true)
	button.pressed.emit()
	check(game.state == "tactic" and game.pending_choices == 1 and game.stats == accepted_stats, "Stale upgrade callback cannot act on a subsequent upgrade modal")

	game.start_run()
	game.stage = 5
	game.show_loot()
	button = game.panel.get_child(1).get_child(2)
	game.start_run()
	game.stage = 10
	game.show_loot()
	accepted_stats = game.stats.duplicate(true)
	button.pressed.emit()
	check(game.state == "loot" and not game.boss_reward_taken and game.run_equipment.is_empty() and game.stats == accepted_stats, "Stale loot callback cannot act on a later run's loot modal")

	game.start_run()
	game.World.reset_hazards(game)
	game.world_data["hazards_enabled"] = false
	game.obstacles = [Rect2(220, 250, 24, 100)]
	var next = game.move_actor(Vector2(170, 300), Vector2(130, 0), 12)
	check(next.x < 208, "Fast movement cannot tunnel through solid obstacles")

	game.start_run()
	game.hp = 1
	game.hurt_cd = 0
	game.stats.regen = 0
	game.obstacles.clear()
	game.enemies.clear()
	game.spawn_queue.clear()
	game.World.reset_hazards(game)
	game.world_data["hazards_enabled"] = false
	game.spawn_enemy("grunt")
	var doomed = game.enemies[0]
	doomed.pos = game.player + Vector2(30, 0)
	doomed.hp = 1.0
	doomed.cooldown = 99.0
	# Begin the player's visible windup before the enemy's active attack.
	game.attack_cd = 0
	game.simulate(0.0)
	game.Combat.begin(game, doomed)
	doomed.attack_state = "active"
	doomed.attack_time = 0.12
	doomed.attack_aim = (game.player - doomed.pos).normalized()
	game.sword_time = 0.001
	# Keep the arena uncleared so the stage-clear heal cannot mask damage.
	game.spawn_enemy("archer")
	game.simulate(1.0 / 120.0)
	check(doomed.hp <= 0 and game.hp == 1, "Enemy killed by the sword's active frame cannot finish its own active attack")

	game.start_run()
	game.World.reset_hazards(game)
	game.world_data["hazards_enabled"] = false
	game.obstacles = [Rect2(220, 250, 24, 100)]
	game.player = Vector2(170, 300)
	game.facing = Vector2.RIGHT
	game.stats.speed = 300
	game.attack_cd = 10
	game.dash()
	game.simulate(0.1)
	check(game.player.x <= 208, "Large-delta dash cannot cross a solid obstacle")

	# Each settings/selection callback should persist through a fresh load.
	game.test_mode = false
	game.show_settings()
	var expected_sfx = not game.profile.sfx
	game.panel.get_child(1).get_child(2).pressed.emit()
	game.panel.get_child(1).get_child(4).value = 0.3
	game.profile.best_stage = 20
	game.profile.unlocks = ["heartwood"]
	game.show_classes()
	game.panel.get_child(1).get_child(4).pressed.emit()
	game.show_cosmetics()
	game.panel.get_child(1).get_child(3).pressed.emit()
	game.show_skills()
	game.panel.get_child(1).get_child(3).get_child(0).get_child(0).pressed.emit()
	game.profile.sfx = not expected_sfx
	game.profile.volume = 0.9
	game.selected_class = 0
	game.selected_cosmetic = 0
	game.selected_skill = ""
	game.load_profile()
	check(game.profile.sfx == expected_sfx and is_equal_approx(float(game.profile.volume), 0.3), "Settings callbacks persist sound and volume")
	check(game.selected_class == 2 and game.selected_cosmetic == 1 and game.selected_skill == "heartwood", "Build, cosmetic and starting-ability callbacks persist selections")
	game.test_mode = true

	game.start_run()
	var old_profile = game.profile.duplicate(true)
	var file = FileAccess.open(game.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"best_stage":-50,"wins":-10,"unlocks":null,"equipment":77,"sfx":"no","shake":[],"volume":"loud"}))
	file.close()
	game.load_profile()
	check(game.profile.unlocks is Array and game.profile.equipment is Array, "Corrupt profile collections use safe defaults")
	check(game.profile.best_stage is int and game.profile.best_stage >= 0 and game.profile.best_stage <= 20 and game.profile.wins is int and game.profile.wins >= 0, "Profile records are bounded nonnegative integers")
	check(game.profile.sfx is bool and game.profile.shake is bool and (game.profile.volume is float or game.profile.volume is int) and float(game.profile.volume) >= 0 and float(game.profile.volume) <= 1, "Corrupt setting types are sanitized")
	game.profile = old_profile
	if had_profile:
		file = FileAccess.open(game.SAVE_PATH, FileAccess.WRITE)
		file.store_string(saved_profile_text)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.SAVE_PATH))

	for build_index in range(4):
		game.selected_class = build_index
		game.selected_skill = ""
		game.start_run()
		var upgrade_count = 0
		var loot_count = 0
		var stage_failures = 0
		for stage_number in range(1, 21):
			if game.stage != stage_number:
				stage_failures += 1
				break
			# Exercise natural group cadence and queue exhaustion. Only enemy HP
			# is injected; XP, pickups, modal rewards, and portals remain real.
			for frame in range(3600):
				if game.stage != stage_number or game.state == "won":
					break
				if game.state == "tactic":
					upgrade_count += 1
					game.panel.get_child(1).get_child(2).pressed.emit()
				elif game.state == "loot":
					loot_count += 1
					game.panel.get_child(1).get_child(2).pressed.emit()
				else:
					for enemy in game.enemies:
						enemy.hp = 0
					game.simulate(1.0 / 60)
		check(stage_failures == 0 and game.state == "won" and game.stage == 20 and game.level == 43 and is_equal_approx(game.xp, 82.0) and game.kills == 736, "Build %d completes all 20 grouped arenas with natural EXP totals" % build_index)
		check(upgrade_count == 8 and loot_count == 4 and game.run_equipment.size() == 4 and game.pending_choices == 0, "Build %d receives all eight upgrades and four guardian rewards" % build_index)
		print("BUILD_RESULT: ", build_index, " level=", game.level, " xp=", game.xp, " kills=", game.kills, " upgrades=", upgrade_count, " loot=", loot_count)

	var spawn_failures = 0
	var reachability_failures = 0
	var checked_arenas = 0
	for seed_number in range(100):
		game.rng.seed = seed_number
		for stage_number in range(1, 21):
			game.stage = stage_number
			game.start_stage()
			# Inspect every spawn, including enemies that normally arrive later.
			# This fixture bypasses cadence only for geometry/reachability checks.
			while not game.spawn_queue.is_empty():
				game.spawn_enemy(game.spawn_queue.pop_front())
			checked_arenas += 1
			for enemy in game.enemies:
				if game.blocked(enemy.pos, 28 if enemy.kind == "boss" else 18) or enemy.pos.distance_to(game.player) <= 185:
					spawn_failures += 1
			var inaccessible = inaccessible_enemy_positions()
			if not inaccessible.is_empty():
				reachability_failures += 1
				if reachability_failures <= 5:
					print("UNREACHABLE_SPAWN: seed=", seed_number, " stage=", stage_number, " positions=", inaccessible, " walls=", game.obstacles)
	check(spawn_failures == 0, "All enemy spawn clearances are safe in 2,000 seeded arenas")
	check(reachability_failures == 0, "All enemy spawn positions are player-reachable in 2,000 seeded arenas")
	print("SEED_RESULT: ", checked_arenas, " arenas; unsafe_spawns=", spawn_failures, " unreachable_arenas=", reachability_failures)

	print("REGRESSION_TESTS: ", passed, " passed; ", failures.size(), " failed")
	for failure in failures:
		print(" - ", failure)
	quit(0 if failures.is_empty() else 1)


# Exact axis-aligned cell decomposition: obstacle boundaries partition the
# player configuration space into cells with uniform occupancy. A flood fill
# over shared edges detects closed pockets without coarse-grid false positives.
func inaccessible_enemy_positions() -> Array:
	var bounds = game.ARENA.grow(-12)
	var xs = [bounds.position.x, bounds.end.x]
	var ys = [bounds.position.y, bounds.end.y]
	for obstacle in game.obstacles:
		var expanded = obstacle.grow(12)
		for x in [expanded.position.x, expanded.end.x]:
			var clamped = clampf(x, bounds.position.x, bounds.end.x)
			if not clamped in xs: xs.append(clamped)
		for y in [expanded.position.y, expanded.end.y]:
			var clamped = clampf(y, bounds.position.y, bounds.end.y)
			if not clamped in ys: ys.append(clamped)
	xs.sort()
	ys.sort()
	var nx = xs.size() - 1
	var ny = ys.size() - 1
	var blocked_cells = PackedByteArray()
	blocked_cells.resize(nx * ny)
	var visited = PackedByteArray()
	visited.resize(nx * ny)
	var queue: Array[int] = []
	var start = -1
	for y in range(ny):
		for x in range(nx):
			var midpoint = Vector2((xs[x] + xs[x + 1]) / 2, (ys[y] + ys[y + 1]) / 2)
			blocked_cells[y * nx + x] = int(game.blocked(midpoint, 12))
			if game.player.x >= xs[x] and game.player.x < xs[x + 1] and game.player.y >= ys[y] and game.player.y < ys[y + 1]:
				start = y * nx + x
	if start >= 0 and not blocked_cells[start]:
		queue.append(start)
		visited[start] = 1
	var head = 0
	while head < queue.size():
		var cell = queue[head]
		head += 1
		var x = cell % nx
		var y = int(cell / nx)
		for neighbor in [Vector2i(x - 1, y), Vector2i(x + 1, y), Vector2i(x, y - 1), Vector2i(x, y + 1)]:
			if neighbor.x < 0 or neighbor.x >= nx or neighbor.y < 0 or neighbor.y >= ny: continue
			var index = neighbor.y * nx + neighbor.x
			if blocked_cells[index] or visited[index]: continue
			visited[index] = 1
			queue.append(index)
	var inaccessible = []
	for enemy in game.enemies:
		var ex = -1
		var ey = -1
		for x in range(nx):
			if enemy.pos.x >= xs[x] and enemy.pos.x < xs[x + 1]: ex = x; break
		for y in range(ny):
			if enemy.pos.y >= ys[y] and enemy.pos.y < ys[y + 1]: ey = y; break
		if ex < 0 or ey < 0 or not visited[ey * nx + ex]:
			inaccessible.append(enemy.pos)
	return inaccessible
