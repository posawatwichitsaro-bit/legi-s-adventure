extends SceneTree

# Focused healing/combat regressions. Run with:
# godot --headless --path . --script healing_tests.gd
# The real profile is restored before the harness exits.
var game
var failures: Array[String] = []
var passed = 0
var saved_profile_text = ""
var had_profile = false
var life_drain = {}

func _initialize():
	call_deferred("run_tests")

func check(condition: bool, message: String):
	if condition:
		passed += 1
		print("PASS: ", message)
	else:
		failures.append(message)
		print("FAIL: ", message)

func near(actual: float, expected: float) -> bool:
	return absf(actual - expected) < 0.0001

func enemy_at(pos: Vector2, health = 100.0, kind = "grunt") -> Dictionary:
	return {"pos":pos,"hp":health,"kind":kind,"cooldown":99.0,"hit":0.0,"phase":0.0,"dash_hit":false}

func fresh_field(stage_number = 1):
	game.selected_build = 0
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
	game.gems.clear()
	game.potions.clear()
	game.obstacles.clear()
	game.effects.clear()
	game.player = game.CENTER
	game.stats.regen = 0.0
	game.attack_cd = 99.0
	game.bow_cd = 99.0
	game.magic_cd = 99.0
	game.hurt_cd = 99.0
	game.stage_time = 0.0

func keep_arena_open():
	game.enemies.append(enemy_at(Vector2(850, 500), 10000.0))

func find_button(node: Node, prefix: String):
	if node is Button and node.text.begins_with(prefix):
		return node
	for child in node.get_children():
		var found = find_button(child, prefix)
		if found != null:
			return found
	return null

func offer_life_drain():
	game.level = 5
	game.pending_choices = 1
	# Use actual randomly generated choice panels and actual callbacks.
	for attempt in range(160):
		game.show_upgrades()
		var offered = find_button(game.panel, str(life_drain.get("name", "Life Drain")) + "\n")
		if offered != null:
			return offered
	return null

func run_tests():
	had_profile = FileAccess.file_exists("user://legis_adventure.json")
	if had_profile:
		saved_profile_text = FileAccess.get_file_as_string("user://legis_adventure.json")
	seed(98241)
	game = load("res://main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_process(false)
	game.rng.seed = 98241
	for upgrade in game.D.UPGRADES:
		if upgrade.id == "life_drain":
			life_drain = upgrade
	check(not life_drain.is_empty(), "Life Drain is an obtainable special upgrade")
	if life_drain.is_empty():
		finish()
		return

	test_base_pickup()
	test_heal_helper()
	test_potion_rolls()
	test_potion_collection()
	test_herbalists()
	test_stage_clear_heal()
	test_damage_accounting()
	test_attack_routes()
	test_life_drain_progression()
	test_life_drain_callbacks()
	test_life_drain_persistence()
	finish()

func test_base_pickup():
	var all_builds_match = true
	for build_index in range(game.D.BUILDS.size()):
		game.selected_build = build_index
		game.selected_ability = ""
		game.start_run()
		all_builds_match = all_builds_match and near(game.stats.pickup, 75.0)
	check(all_builds_match, "All four builds begin with the wider 75-pixel pickup radius")
	game.selected_ability = "treasure_magnet"
	game.start_run()
	check(near(game.stats.pickup, 111.0), "Treasure Magnet adds its existing 36 pixels to the new base radius")

func test_heal_helper():
	fresh_field()
	game.hp = 70.0
	var restored = game.heal_player(15.0, "test")
	check(near(restored, 15.0) and near(game.hp, 85.0), "Healing reports the health actually restored")
	game.hp = 98.0
	restored = game.heal_player(20.0, "test")
	check(near(restored, 2.0) and near(game.hp, 100.0), "Healing is capped at current maximum health")
	restored = game.heal_player(20.0, "test")
	check(near(restored, 0.0) and near(game.hp, 100.0), "Healing at full health reports zero")
	game.hp = 60.0
	var zero_heal = game.heal_player(0.0, "test")
	var negative_heal = game.heal_player(-10.0, "test")
	check(near(zero_heal, 0.0) and near(negative_heal, 0.0) and near(game.hp, 60.0), "Zero and negative healing cannot reduce health")
	game.hp = 0.0
	restored = game.heal_player(100.0, "test")
	check(near(restored, 0.0) and near(game.hp, 0.0), "Healing cannot revive a player at zero health")
	game.hp = -5.0
	restored = game.heal_player(100.0, "test")
	check(near(restored, 0.0) and game.hp <= 0.0, "Healing cannot revive a player below zero health")
	fresh_field()
	keep_arena_open()
	game.hp = 0.0
	game.stats.regen = 100.0
	game.simulate(0.01)
	check(game.state == "dead" and game.hp <= 0.0, "Regeneration cannot revive a dead player during simulation")

func test_potion_rolls():
	fresh_field()
	game.rng.seed = 47822
	var counts = [0, 0, 0]
	var valid = true
	var pos = Vector2(250, 350)
	for roll in range(12000):
		game.potions.clear()
		game.spawn_potion(pos)
		if game.potions.size() != 1:
			valid = false
			continue
		var potion = game.potions[0]
		if not potion.has("pos") or not potion.has("fraction") or potion.pos != pos:
			valid = false
			continue
		if near(potion.fraction, 0.02):
			counts[0] += 1
		elif near(potion.fraction, 0.04):
			counts[1] += 1
		elif near(potion.fraction, 0.06):
			counts[2] += 1
		else:
			valid = false
	check(valid, "Potion spawns preserve position and contain only 2%, 4%, or 6% healing fractions")
	check(absf(counts[0] / 12000.0 - 0.60) < 0.025 and absf(counts[1] / 12000.0 - 0.30) < 0.025 and absf(counts[2] / 12000.0 - 0.10) < 0.025, "12,000 seeded potion drops follow the 60% / 30% / 10% weights")
	print("POTION_WEIGHTS: 2%=", counts[0], " 4%=", counts[1], " 6%=", counts[2])

func test_potion_collection():
	fresh_field()
	keep_arena_open()
	game.spawn_potion(game.player)
	var fraction = game.potions[0].fraction
	game.stats.max_hp = 250.0
	game.hp = 100.0
	game.simulate(0.0)
	check(game.potions.is_empty() and near(game.hp, 100.0 + 250.0 * fraction), "Potion collection uses current maximum health, not maximum health at drop time")
	var after_collection = game.hp
	game.simulate(0.0)
	check(near(game.hp, after_collection), "A collected potion heals only once")
	game.hp = 249.0
	game.potions.append({"pos":game.player,"fraction":0.06})
	game.simulate(0.0)
	check(game.potions.is_empty() and near(game.hp, 250.0), "A potion near full health is consumed and capped")
	game.potions.append({"pos":game.player,"fraction":0.02})
	game.simulate(0.0)
	check(game.potions.is_empty() and near(game.hp, 250.0), "Full-health players can collect potions without stalling arena clear")

	fresh_field()
	keep_arena_open()
	var inside = game.player + Vector2(74, 0)
	game.gems.append({"pos":inside,"value":0.0})
	game.potions.append({"pos":inside,"fraction":0.02})
	game.simulate(0.1)
	check(game.gems[0].pos == game.potions[0].pos and game.gems[0].pos.distance_to(game.player) < 74.0, "Crystals and potions share the same pickup magnet radius and speed")
	game.gems.clear()
	game.potions.clear()
	var outside = game.player + Vector2(76, 0)
	game.gems.append({"pos":outside,"value":0.0})
	game.potions.append({"pos":outside,"fraction":0.02})
	game.simulate(0.1)
	check(game.gems[0].pos == outside and game.potions[0].pos == outside, "Neither pickup is magnetized outside the current pickup radius")
	game.apply_stats({"pickup":36.0})
	game.simulate(0.1)
	check(game.gems[0].pos == game.potions[0].pos and game.potions[0].pos != outside, "Pickup upgrades expand crystal and potion attraction together")

	fresh_field()
	game.player = Vector2(200, 340)
	game.hp = 40.0
	var distant = Vector2(850, 500)
	game.gems.append({"pos":distant,"value":0.0})
	game.potions.append({"pos":distant,"fraction":0.04})
	game.simulate(0.01)
	check(game.gems[0].pos != distant and game.potions[0].pos != distant and not game.portal_open, "An empty arena draws in distant crystals and potions before opening the portal")
	for frame in range(500):
		if game.portal_open:
			break
		game.simulate(1.0 / 60.0)
	check(game.gems.is_empty() and game.potions.is_empty() and game.portal_open and near(game.hp, 54.0), "The last potion is collected and healed before the once-per-stage 10% clear bonus")

	fresh_field()
	keep_arena_open()
	game.hp = 0.0
	game.potions.append({"pos":game.player,"fraction":0.06})
	game.simulate(0.0)
	check(game.state == "dead" and game.hp <= 0.0, "A nearby potion cannot rescue a player who has already died")

func test_herbalists():
	var arena_counts_ok = true
	var replacement_ok = true
	for stage_number in range(1, 21):
		game.stage = stage_number
		game.start_stage()
		var roster: Array[String] = []
		for enemy in game.enemies:
			roster.append(enemy.kind)
		roster.append_array(game.spawn_queue)
		var expected_count = ceili((8 + stage_number * 2 + (1 if stage_number % 5 == 0 else 0)) * 1.25)
		arena_counts_ok = arena_counts_ok and roster.count("herbalist") == 1 and roster.count("boss") == (1 if stage_number % 5 == 0 else 0) and roster.size() == expected_count and game.total_enemies == expected_count and game.remaining_enemies() == expected_count
		replacement_ok = replacement_ok and roster[4] == "herbalist"
	check(arena_counts_ok, "All 20 active-plus-queued rosters contain exactly one herbalist and preserve guardian count within the 25% larger total")
	check(replacement_ok, "Each herbalist retains roster index four across initial and queued groups")

	fresh_field()
	game.hp = 40.0
	var pos = game.player + Vector2(80, 0)
	game.enemies.append(enemy_at(pos, 0.0, "herbalist"))
	game.simulate(0.0)
	check(game.kills == 1 and game.enemies.is_empty() and game.gems.size() == 1 and near(game.gems[0].value, 2.0), "Defeated herbalists award normal kill credit and unchanged crystal EXP")
	check(game.potions.size() == 1 and game.potions[0].pos == pos and near(game.hp, 40.0), "A defeated herbalist drops one collectible potion without healing remotely")
	game.simulate(0.0)
	check(game.potions.size() == 1 and game.kills == 1, "A removed herbalist cannot drop a second potion")
	fresh_field()
	game.enemies.append(enemy_at(pos, 0.0, "grunt"))
	game.enemies.append(enemy_at(pos + Vector2(60, 0), 0.0, "boss"))
	game.simulate(0.0)
	check(game.potions.is_empty(), "Ordinary enemies and guardians do not gain unintended potion drops")

func test_stage_clear_heal():
	fresh_field()
	game.player = Vector2(220, 340)
	game.stats.max_hp = 200.0
	game.hp = 50.0
	keep_arena_open()
	game.simulate(0.0)
	check(not game.stage_clear_healed and near(game.hp, 50.0), "Living enemies prevent stage-clear healing")
	game.enemies[0].hp = 0.0
	game.simulate(0.0)
	check(not game.stage_clear_healed and not game.gems.is_empty() and near(game.hp, 50.0), "Uncollected crystals prevent stage-clear healing")
	game.gems.clear()
	game.potions.append({"pos":Vector2(850, 500),"fraction":0.02})
	game.simulate(0.0)
	check(not game.stage_clear_healed and not game.portal_open and near(game.hp, 50.0), "Uncollected potions prevent stage-clear healing and portal opening")
	game.potions.clear()
	game.simulate(0.0)
	check(game.stage_clear_healed and game.portal_open and near(game.hp, 70.0), "Stage clear restores 10% of current maximum health")
	game.hp = 50.0
	game.simulate(0.0)
	game.simulate(0.0)
	check(near(game.hp, 50.0), "An open portal cannot repeatedly grant the stage-clear heal")
	game.potions.append({"pos":game.player,"fraction":0.04})
	game.stage = 2
	game.start_stage()
	check(not game.stage_clear_healed and game.potions.is_empty() and not game.portal_open, "Starting a new arena resets the clear-heal guard and removes old potions")
	game.enemies.clear()
	game.spawn_queue.clear()
	game.World.reset_hazards(game)
	game.world_data["hazards_enabled"] = false
	game.gems.clear()
	game.hp = 195.0
	game.stats.regen = 0.0
	game.simulate(0.0)
	check(near(game.hp, 200.0) and game.stage_clear_healed, "Stage-clear healing caps at maximum health")

	fresh_field(5)
	game.stats.max_hp = 200.0
	game.hp = 50.0
	game.simulate(0.0)
	check(game.state == "loot" and game.stage_clear_healed and near(game.hp, 70.0), "Guardian arenas grant clear healing before displaying equipment choices")
	game.panel.get_child(1).get_child(2).pressed.emit()
	game.hp = 50.0
	game.stats.regen = 0.0
	game.simulate(0.0)
	check(game.portal_open and game.stage_clear_healed and near(game.hp, 50.0), "Accepting guardian loot cannot grant the clear heal a second time")

	fresh_field(20)
	game.hp = 50.0
	game.boss_reward_taken = true
	game.stage_time = 3.0
	game.simulate(0.0)
	check(game.state == "won" and near(game.hp, 60.0) and game.stage_clear_healed, "The final arena grants healing before entering the victory portal")
	fresh_field()
	game.hp = 0.0
	game.simulate(0.0)
	check(game.state == "dead" and game.hp <= 0.0 and not game.stage_clear_healed, "Stage-clear healing never revives a dead player")

func test_damage_accounting():
	fresh_field()
	game.hp = 40.0
	var enemy = enemy_at(game.player + Vector2(50, 0), 50.0)
	var dealt = game.damage_enemy(enemy, 20.0)
	check(near(dealt, 20.0) and near(enemy.hp, 30.0) and near(game.hp, 40.0), "Damage returns actual enemy HP removed and does not heal without Life Drain")
	game.stats.lifesteal = 0.1
	dealt = game.damage_enemy(enemy, 20.0)
	check(near(dealt, 20.0) and near(enemy.hp, 10.0) and near(game.hp, 42.0), "Life Drain restores exactly 10% of actual damage")
	dealt = game.damage_enemy(enemy, 100.0)
	check(near(dealt, 10.0) and near(enemy.hp, 0.0) and near(game.hp, 43.0), "Overkill grants healing only for the victim's remaining health")
	dealt = game.damage_enemy(enemy, 100.0)
	check(near(dealt, 0.0) and near(enemy.hp, 0.0) and near(game.hp, 43.0), "Repeated hits on a dead enemy cannot grant Life Drain")
	enemy.hp = 50.0
	var zero_damage = game.damage_enemy(enemy, 0.0)
	var negative_damage = game.damage_enemy(enemy, -20.0)
	check(near(zero_damage, 0.0) and near(negative_damage, 0.0) and near(enemy.hp, 50.0) and near(game.hp, 43.0), "Zero or negative damage neither heals enemies nor triggers Life Drain")
	game.hp = 99.0
	dealt = game.damage_enemy(enemy, 30.0)
	check(near(dealt, 30.0) and near(game.hp, 100.0), "Life Drain caps player health while preserving actual damage reporting")
	game.hp = 0.0
	dealt = game.damage_enemy(enemy, 10.0)
	check(near(dealt, 10.0) and near(game.hp, 0.0), "Life Drain cannot revive the player")

func prepare_attack_target(distance: float, health = 100.0):
	fresh_field()
	game.hp = 40.0
	game.stats.damage = 20.0
	game.stats.lifesteal = 0.1
	game.enemies.append(enemy_at(game.player + Vector2(distance, 0), health))

func test_attack_routes():
	prepare_attack_target(40.0)
	game.attack_cd = 0.0
	game.simulate(0.0)
	check(game.sword_state == "windup" and near(game.enemies[0].hp, 100.0) and near(game.hp, 40.0), "Automatic sword windup cannot grant damage or Life Drain early")
	for frame in range(16):
		game.simulate(1.0 / 120.0)
	check(near(game.enemies[0].hp, 80.0) and near(game.hp, 42.0), "Automatic sword active-window damage uses Life Drain")

	prepare_attack_target(70.0)
	game.stats.projectiles = 1.0
	game.bow_cd = 0.0
	game.simulate(0.0)
	check(game.bow_windup > 0 and game.bullets.is_empty(), "Bow windup does not release its projectile early")
	for frame in range(26):
		game.simulate(1.0 / 120.0)
	var bow_spawned = game.bullets.size() == 1 and not game.bullets[0].magic
	check(bow_spawned, "Bow attack produces its normal friendly projectile")
	if bow_spawned:
		game.bullets[0].pos = game.enemies[0].pos
		game.bullets[0].vel = Vector2.ZERO
		game.simulate(0.0)
		check(near(game.enemies[0].hp, 82.0) and near(game.hp, 41.8), "Bow projectile hits use actual-damage Life Drain")

	prepare_attack_target(70.0)
	game.stats.magic = 1.0
	game.magic_cd = 0.0
	game.simulate(0.0)
	check(game.cast_windup > 0 and game.bullets.is_empty(), "Magic windup does not release its projectiles early")
	for frame in range(35):
		game.simulate(1.0 / 120.0)
	var magic_spawned = game.bullets.size() == 8 and game.bullets[0].magic
	check(magic_spawned, "Magic attack produces its normal eight radial projectiles")
	if magic_spawned:
		game.bullets[0].pos = game.enemies[0].pos
		game.bullets[0].vel = Vector2.ZERO
		game.simulate(0.0)
		check(near(game.enemies[0].hp, 97.0) and near(game.hp, 40.3), "Magic projectile hits use actual-damage Life Drain")

	prepare_attack_target(30.0, 150.0)
	game.stats.dash_damage = 30.0
	game.dash_cd = 0.0
	game.dash()
	game.simulate(0.0)
	check(near(game.enemies[0].hp, 100.0) and near(game.hp, 45.0), "Dash damage uses Life Drain")
	game.simulate(0.0)
	check(near(game.enemies[0].hp, 100.0) and near(game.hp, 45.0), "A single dash cannot drain the same enemy twice")
	# V7: dash_cd is only a view; a second action must await real charge recovery.
	game.dash_left = 0.0
	game.ClassProgression.tick(game,game.stats.dash_cooldown)
	game.dash()
	game.simulate(0.0)
	check(near(game.enemies[0].hp, 50.0) and near(game.hp, 50.0), "A new dash can damage and drain the enemy again")

func test_life_drain_progression():
	fresh_field()
	check(near(game.stats.lifesteal, 0.0) and near(life_drain.stats.lifesteal, 0.1), "Life Drain starts inactive and its upgrade grants exactly 10%")
	game.gain_xp(4000.0)
	check(near(game.stats.lifesteal, 0.0), "Level growth never activates unacquired Life Drain")
	game.apply_stats(life_drain.stats)
	game.apply_stats(life_drain.stats)
	check(near(game.stats.lifesteal, 0.1), "Repeated stat application cannot stack Life Drain above 10%")
	var before_damage = game.stats.damage
	game.gain_xp(4000.0)
	check(near(game.stats.lifesteal, 0.1) and game.stats.damage > before_damage, "Level growth preserves Life Drain at exactly 10% while other stats grow")

func test_life_drain_callbacks():
	fresh_field()
	var offered = offer_life_drain()
	check(offered != null, "Random special-upgrade choices can offer Life Drain")
	if offered == null:
		return
	offered.pressed.emit()
	check(near(game.stats.lifesteal, 0.1) and game.pending_choices == 0 and "life_drain" in game.profile.unlocks, "Choosing Life Drain activates it and permanently discovers its starting ability")
	offered.pressed.emit()
	check(near(game.stats.lifesteal, 0.1) and game.pending_choices == 0, "Double-clicking Life Drain cannot stack healing or consume a second reward")
	var excluded = true
	var complete_choices = true
	for attempt in range(100):
		game.pending_choices = 1
		game.show_upgrades()
		excluded = excluded and find_button(game.panel, str(life_drain.name) + "\n") == null
		complete_choices = complete_choices and game.panel.get_child(1).get_child_count() == 5
	check(excluded and complete_choices, "Active Life Drain is excluded from 100 subsequent three-choice upgrade panels")

	fresh_field()
	offered = offer_life_drain()
	if offered != null:
		game.show_menu()
		offered.pressed.emit()
		check(game.state == "menu" and near(game.stats.lifesteal, 0.0), "A dismissed Life Drain callback cannot alter an abandoned run")
	fresh_field()
	offered = offer_life_drain()
	if offered != null:
		game.show_upgrades()
		offered.pressed.emit()
		check(game.state == "upgrade" and game.pending_choices == 1 and near(game.stats.lifesteal, 0.0), "A stale Life Drain callback cannot alter a newer upgrade panel")
	fresh_field()
	offered = offer_life_drain()
	if offered != null:
		game.start_run()
		game.pending_choices = 1
		game.show_upgrades()
		offered.pressed.emit()
		check(game.state == "upgrade" and game.pending_choices == 1 and near(game.stats.lifesteal, 0.0), "A stale Life Drain callback cannot carry healing into a new run")

func test_life_drain_persistence():
	fresh_field()
	game.profile.unlocks = []
	game.test_mode = false
	var offered = offer_life_drain()
	check(offered != null, "Persistence scenario obtains Life Drain through a real choice")
	if offered == null:
		game.test_mode = true
		return
	offered.pressed.emit()
	game.show_abilities()
	var equip = find_button(game.panel, str(life_drain.name) + "  ·  ")
	check(equip != null, "Discovered Life Drain appears in the starting-ability menu")
	if equip == null:
		game.test_mode = true
		return
	equip.pressed.emit()
	game.selected_ability = ""
	game.profile.unlocks = []
	game.load_profile()
	check(game.selected_ability == "life_drain" and game.profile.unlocks.count("life_drain") == 1, "Life Drain discovery and equipped selection survive a profile reload")
	game.start_run()
	check(near(game.stats.lifesteal, 0.1), "An equipped Life Drain ability is active from the first frame of a new run")
	game.hp = 0.0
	game.end_run(false)
	game.start_run()
	check(game.stage == 1 and near(game.stats.lifesteal, 0.1) and "life_drain" in game.profile.unlocks, "Death preserves the discovered and equipped Life Drain starting ability")
	game.show_abilities()
	var unequip = find_button(game.panel, "NONE")
	if unequip != null:
		unequip.pressed.emit()
	game.load_profile()
	game.start_run()
	check(game.selected_ability == "" and near(game.stats.lifesteal, 0.0) and "life_drain" in game.profile.unlocks, "Unequipping Life Drain removes its run effect while preserving the permanent unlock")
	game.test_mode = true

func finish():
	if had_profile:
		var file = FileAccess.open("user://legis_adventure.json", FileAccess.WRITE)
		file.store_string(saved_profile_text)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://legis_adventure.json"))
	print("HEALING_TESTS: ", passed, " passed; ", failures.size(), " failed")
	for failure in failures:
		print(" - ", failure)
	quit(0 if failures.is_empty() else 1)
