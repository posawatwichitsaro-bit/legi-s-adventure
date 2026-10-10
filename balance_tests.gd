extends SceneTree

# Upgrade ranks, exhausted reward pools, and effective-stat ceiling regressions.
# Run with: godot --headless --path . --script balance_tests.gd
# Any existing player profile is restored before this harness exits.
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

func near(actual: float, expected: float) -> bool:
	return absf(actual - expected) < 0.0001

func fresh_run(build_index: int = 0):
	game.selected_build = build_index
	game.selected_ability = ""
	game.start_run()
	game.level = 5

func upgrade_build(upgrade: Dictionary) -> int:
	var classes = upgrade.get("classes",[])
	if not classes.is_empty():
		for i in game.D.BUILDS.size():
			if game.D.BUILDS[i].id in classes:return i
	# The primary Ranger can use all three Split Shot ranks; auxiliary bows
	# intentionally become ineffective at two arrows, before rank three.
	return 1 if upgrade.id=="split_shot" else 0

func resource_snapshot() -> Array:
	return [game.shield, game.shield_delay, game.dash_charges, game.dash_recharge,
		game.trap_charges, game.trap_recharge, game.dash_cd]

func buttons_in(node: Node) -> Array:
	var result: Array = []
	if node is Button:
		result.append(node)
	for child in node.get_children():
		result.append_array(buttons_in(child))
	return result

func shown_buttons() -> Array:
	return buttons_in(game.panel) if is_instance_valid(game.panel) else []

func button_upgrade_id(button: Button) -> String:
	for upgrade in game.D.UPGRADES:
		if button.text.begins_with(str(upgrade.name) + "\n"):
			return upgrade.id
	return ""

func offered_ids() -> Array:
	var ids: Array = []
	for upgrade in game.available_upgrades():
		ids.append(upgrade.id)
	return ids

func cap_all_except(ids: Array):
	for upgrade in game.D.UPGRADES:
		game.upgrade_ranks[upgrade.id] = 0 if upgrade.id in ids else game.upgrade_cap(upgrade.id)

func all_stats_bounded() -> bool:
	for key in game.D.STAT_LIMITS:
		var bounds = game.ClassProgression.stat_bounds(game,key)
		var value = float(game.stats.get(key, NAN))
		if not is_finite(value) or value < float(bounds[0]) - 0.0001 or value > float(bounds[1]) + 0.0001:
			print("UNBOUNDED_STAT: ", key, "=", value, " expected ", bounds)
			return false
	return true

func advance_reward_panel():
	# Normal gameplay displays the next pending reward on the next simulation tick.
	if game.pending_choices > 0 and game.state != "upgrade":
		game.show_upgrades()

func run_tests():
	had_profile = FileAccess.file_exists("user://legis_adventure.json")
	if had_profile:
		saved_profile_text = FileAccess.get_file_as_string("user://legis_adventure.json")
	seed(310742)
	game = load("res://main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_process(false)
	game.rng.seed = 310742
	test_data_contract()
	test_every_upgrade_cap()
	test_rank_validation()
	test_starting_rank_reset()
	test_class_eligibility()
	test_available_pools()
	test_saturated_stats_pool()
	test_choice_safety()
	test_exhausted_pool()
	test_effective_bounds()
	test_profile_compatibility()
	finish()

func test_data_contract():
	fresh_run()
	var unique_ids: Array = []
	var valid = true
	for upgrade in game.D.UPGRADES:
		valid = valid and upgrade.get("cap") is int and int(upgrade.get("cap", 0)) > 0
		valid = valid and upgrade.id not in unique_ids and game.upgrade_cap(upgrade.id) == upgrade.get("cap", 0)
		unique_ids.append(upgrade.id)
	check(valid, "Every upgrade has a unique ID and an explicit positive integer cap")
	var scales_valid = true
	for upgrade in game.D.UPGRADES:
		if not upgrade.has("rank_scales"):
			continue
		var scales = upgrade.rank_scales
		scales_valid = scales_valid and scales.size() == upgrade.cap
		var previous = 1.0
		for factor in scales:
			scales_valid = scales_valid and float(factor) > 0 and float(factor) <= previous
			previous = float(factor)
	check(scales_valid, "Diminishing-return upgrade scales cover every rank with positive non-increasing bonuses")
	var valid_bounds = true
	for key in game.stats:
		valid_bounds = valid_bounds and game.D.STAT_LIMITS.has(key)
	for key in game.D.STAT_LIMITS:
		var bounds = game.D.STAT_LIMITS[key]
		valid_bounds = valid_bounds and bounds is Array and bounds.size() == 2
		if bounds is Array and bounds.size() == 2:
			valid_bounds = valid_bounds and is_finite(float(bounds[0])) and is_finite(float(bounds[1])) and bounds[0] <= bounds[1]
	check(valid_bounds and all_stats_bounded(), "Every effective stat has finite ordered limits containing the starting stats")
	check(game.upgrade_cap("life_drain") == 1, "Life Drain remains a unique one-rank upgrade")

func test_every_upgrade_cap():
	for upgrade in game.D.UPGRADES:
		fresh_run(upgrade_build(upgrade))
		var valid = game.upgrade_rank(upgrade.id) == 0
		var unlocks_before = game.profile.unlocks.duplicate()
		for rank in range(1, game.upgrade_cap(upgrade.id) + 1):
			var before = game.stats.duplicate(true)
			var applied = game.apply_upgrade(upgrade.id)
			valid = valid and applied and game.upgrade_rank(upgrade.id) == rank and all_stats_bounded()
			var rank_scale = float(upgrade.rank_scales[rank - 1]) if upgrade.has("rank_scales") else 1.0
			for key in upgrade.stats:
				var expected = clampf(float(before[key]) + float(upgrade.stats[key]) * rank_scale, float(game.ClassProgression.stat_bounds(game,key)[0]), float(game.ClassProgression.stat_bounds(game,key)[1]))
				if key == "lifesteal":
					expected = 0.1
				valid = valid and near(float(game.stats[key]), expected)
		check(valid, "%s applies its stat or branch benefit once per rank on an eligible class" % upgrade.name)
		var capped_stats = game.stats.duplicate(true)
		var capped_ranks = game.upgrade_ranks.duplicate(true)
		var capped_hp = game.hp
		var capped_resources = resource_snapshot()
		var refused = true
		for attempt in range(4):
			refused = not game.apply_upgrade(upgrade.id) and refused
		check(refused and game.stats == capped_stats and game.upgrade_ranks == capped_ranks and near(game.hp, capped_hp) and resource_snapshot()==capped_resources, "%s refuses all over-cap applications without side effects" % upgrade.name)
		check(game.profile.unlocks == unlocks_before, "%s direct application does not change permanent discoveries" % upgrade.name)

func test_rank_validation():
	fresh_run()
	game.upgrade_ranks["unknown_upgrade"] = 900
	var before = game.stats.duplicate(true)
	check(game.upgrade_cap("unknown_upgrade") == 0 and game.upgrade_rank("unknown_upgrade") == 0 and not game.apply_upgrade("unknown_upgrade") and game.stats == before, "Unknown upgrade IDs cannot acquire a rank or change stats")
	var valid = true
	for upgrade in game.D.UPGRADES:
		for value in [-100, 0, 999999, null, "999", {}, [], true, 1.5, INF, NAN]:
			game.upgrade_ranks[upgrade.id] = value
			var rank = game.upgrade_rank(upgrade.id)
			valid = valid and rank is int and rank >= 0 and rank <= game.upgrade_cap(upgrade.id)
	check(valid, "Malformed and out-of-range rank values always read as bounded integers")

func test_starting_rank_reset():
	for upgrade in game.D.UPGRADES:
		fresh_run(upgrade_build(upgrade))
		game.upgrade_ranks["keen_edge"] = game.upgrade_cap("keen_edge")
		game.selected_ability = upgrade.id
		game.start_run()
		var valid = game.upgrade_rank(upgrade.id) == 1 and all_stats_bounded()
		for other in game.D.UPGRADES:
			if other.id != upgrade.id:
				valid = valid and game.upgrade_rank(other.id) == 0
		var repeated_stats = game.stats.duplicate(true)
		game.start_run()
		valid = valid and game.stats == repeated_stats and game.upgrade_rank(upgrade.id) == 1
		check(valid, "%s starts at rank one and resets cleanly on every run" % upgrade.name)
	fresh_run()
	check(game.upgrade_ranks.is_empty() and near(game.stats.lifesteal, 0.0), "An unequipped fresh run has no inherited ranks or Life Drain")
	game.selected_ability = "not_an_upgrade"
	game.start_run()
	check(game.upgrade_ranks.is_empty(), "An unknown starting selection cannot create a run rank")

func test_class_eligibility():
	for build_index in game.D.BUILDS.size():
		for upgrade in game.D.UPGRADES:
			if not upgrade.has("classes"):continue
			fresh_run(build_index)
			var right_class = game.D.BUILDS[build_index].id in upgrade.classes
			var before_stats=game.stats.duplicate(true)
			var before_resources=resource_snapshot()
			var applied=game.apply_upgrade(upgrade.id)
			check(applied==right_class and game.upgrade_rank(upgrade.id)==(1 if right_class else 0), "%s %s direct %s" % [game.D.BUILDS[build_index].name,"accepts" if right_class else "rejects",upgrade.name])
			if not right_class:
				check(game.stats==before_stats and resource_snapshot()==before_resources, "Wrong-class %s leaves stats and resources unchanged" % upgrade.name)
				game.selected_ability=upgrade.id
				game.start_run()
				check(game.selected_ability=="" and game.upgrade_ranks.is_empty(), "Wrong-class starting %s is cleared without acquiring power" % upgrade.name)
	for selected_style in ["blade_thrust","blade_cleave","blade_sweep"]:
		fresh_run()
		var accepted=game.apply_upgrade(selected_style)
		var forbidden=[]
		for other_style in ["blade_thrust","blade_cleave","blade_sweep"]:
			if other_style!=selected_style:
				forbidden.append(other_style not in offered_ids() and not game.apply_upgrade(other_style))
		check(accepted and forbidden==[true,true], "%s excludes and rejects both conflicting styles" % selected_style)
	# Two-arrow auxiliaries deliberately exhaust Split Shot early rather than
	# consuming a third rank that has no effect.
	fresh_run()
	check(game.apply_upgrade("split_shot") and game.apply_upgrade("split_shot") and not game.apply_upgrade("split_shot") and game.upgrade_rank("split_shot")==2 and "split_shot" not in offered_ids(), "Auxiliary Split Shot stops at two arrows without wasting rank three")

func test_available_pools():
	for build_index in game.D.BUILDS.size():
		fresh_run(build_index)
		var expected=[]
		for upgrade in game.D.UPGRADES:
			if not upgrade.has("classes") or game.D.BUILDS[build_index].id in upgrade.classes:expected.append(upgrade.id)
		var actual=offered_ids()
		expected.sort();actual.sort()
		check(actual==expected, "Build %d initially offers all generic and only its own class branches" % build_index)
	fresh_run()
	game.stats.lifesteal = 0.1
	check("life_drain" not in offered_ids(), "Already-active Life Drain is excluded even without a recorded rank")
	check(not game.apply_upgrade("life_drain") and game.upgrade_rank("life_drain") == 0 and near(game.stats.lifesteal, 0.1), "Already-active Life Drain cannot consume another rank through direct application")
	fresh_run()
	for count in [0, 1, 2, 3]:
		var eligible: Array = []
		for i in range(count):
			eligible.append(game.D.UPGRADES[i].id)
		cap_all_except(eligible)
		var available = offered_ids()
		var exact_pool = available.size() == count
		for id in eligible:
			exact_pool = exact_pool and id in available
		check(exact_pool, "%d remaining upgrades produce exactly the eligible pool" % count)
		game.pending_choices = 1
		game.show_upgrades()
		var choices = shown_buttons()
		var valid_buttons = choices.size() == maxi(1, count)
		var seen: Array = []
		for choice in choices:
			var id = button_upgrade_id(choice)
			if count > 0:
				valid_buttons = valid_buttons and id in eligible and id not in seen
				seen.append(id)
		check(valid_buttons, "%d remaining upgrades render safely without maxed or duplicate choices" % count)
	fresh_run()
	game.pending_choices = 1
	game.show_upgrades()
	check(shown_buttons().size() == 3, "A full pool still offers three special upgrades")
	var labels_valid = true
	for choice in shown_buttons():
		var id = button_upgrade_id(choice)
		var rank_label = "Rank %d/%d" % [game.upgrade_rank(id), game.upgrade_cap(id)]
		labels_valid = labels_valid and rank_label in choice.text
	check(labels_valid, "Upgrade choices visibly show their current rank and cap")
	fresh_run()
	game.show_upgrades()
	check(game.state == "playing" and shown_buttons().is_empty(), "No upgrade modal or reward appears without a pending choice")

func test_saturated_stats_pool():
	var excluded = true
	var branches_remain = true
	for upgrade in game.D.UPGRADES:
		fresh_run(upgrade_build(upgrade))
		for key in upgrade.stats:
			game.stats[key] = game.ClassProgression.stat_bounds(game,key)[0 if float(upgrade.stats[key]) < 0 else 1]
		if upgrade.stats.is_empty():
			branches_remain = branches_remain and upgrade.id in offered_ids() and game.ClassProgression.has_effect(game,upgrade) and game.effective_upgrade_changes(upgrade).is_empty()
		else:
			excluded = excluded and upgrade.id not in offered_ids() and game.effective_upgrade_changes(upgrade).is_empty()
	check(excluded, "Every stat upgrade disappears when all affected stats reach its class's beneficial limits")
	check(branches_remain, "Every eligible statless branch remains meaningful despite an empty stat delta")
	fresh_run()
	for key in game.D.STAT_LIMITS:
		game.stats[key] = game.ClassProgression.stat_bounds(game,key)[0 if key == "dash_cooldown" else 1]
	game.hp = 20.0
	game.pending_choices = 2
	game.show_upgrades()
	var choices = shown_buttons()
	var styles_only=choices.size()==3
	for choice in choices:
		styles_only=styles_only and button_upgrade_id(choice) in ["blade_thrust","blade_cleave","blade_sweep"]
	check(game.upgrade_ranks.is_empty() and styles_only, "Stat saturation preserves all three unchosen Blade styles rather than prematurely offering rest")
	if choices.size()==3:choices[0].pressed.emit()
	advance_reward_panel()
	choices=shown_buttons()
	check(game.available_upgrades().is_empty() and choices.size()==1 and button_upgrade_id(choices[0])=="", "Choosing one saturated-build style exhausts its mutually exclusive branches and offers rest")
	if choices.size() == 1:choices[0].pressed.emit()
	check(game.pending_choices == 0 and near(game.hp, 60.0) and game.state == "playing", "A stat-saturated build claims one branch and one rest heal, then continues")

	fresh_run()
	cap_all_except(["farshot"])
	game.stats.damage = game.D.STAT_LIMITS.damage[1]
	game.stats.range = game.D.STAT_LIMITS.range[1] - 5.0
	game.pending_choices = 1
	game.show_upgrades()
	choices = shown_buttons()
	var partial_valid = choices.size() == 1 and button_upgrade_id(choices[0]) == "farshot"
	if partial_valid:
		partial_valid = "+5.00 melee reach / aimed-shot speed" in choices[0].text and "damage" not in choices[0].text
		choices[0].pressed.emit()
		partial_valid = partial_valid and near(game.stats.range, game.D.STAT_LIMITS.range[1]) and near(game.stats.damage, game.D.STAT_LIMITS.damage[1]) and game.upgrade_rank("farshot") == 1
	check(partial_valid and "farshot" not in offered_ids(), "A partially capped compound upgrade advertises only its actual benefit, then disappears when fully saturated")

func test_choice_safety():
	fresh_run()
	game.pending_choices = 2
	game.show_upgrades()
	var chosen = shown_buttons()[0]
	var chosen_id = button_upgrade_id(chosen)
	chosen.pressed.emit()
	var accepted_stats = game.stats.duplicate(true)
	var accepted_ranks = game.upgrade_ranks.duplicate(true)
	chosen.pressed.emit()
	check(game.pending_choices == 1 and game.upgrade_rank(chosen_id) == 1 and game.stats == accepted_stats and game.upgrade_ranks == accepted_ranks, "A repeated upgrade callback cannot consume a second pending choice")
	advance_reward_panel()
	chosen.pressed.emit()
	check(game.pending_choices == 1 and game.stats == accepted_stats and game.upgrade_ranks == accepted_ranks, "An old callback cannot consume the next pending reward")
	var second = shown_buttons()[0]
	second.pressed.emit()
	check(game.pending_choices == 0 and game.state == "playing", "The next valid upgrade consumes exactly the remaining reward and resumes play")

	fresh_run()
	game.pending_choices = 1
	game.show_upgrades()
	var stale = shown_buttons()[0]
	game.show_upgrades()
	accepted_stats = game.stats.duplicate(true)
	stale.pressed.emit()
	check(game.pending_choices == 1 and game.state == "upgrade" and game.upgrade_ranks.is_empty() and game.stats == accepted_stats, "Replacing an upgrade modal invalidates its previous buttons")
	stale = shown_buttons()[0]
	game.show_menu()
	stale.pressed.emit()
	check(game.state == "menu" and game.upgrade_ranks.is_empty() and game.stats == accepted_stats, "Leaving the run invalidates the old upgrade choice")

	fresh_run()
	game.pending_choices = 1
	game.show_upgrades()
	stale = shown_buttons()[0]
	fresh_run()
	game.pending_choices = 1
	game.show_upgrades()
	stale.pressed.emit()
	check(game.state == "upgrade" and game.pending_choices == 1 and game.upgrade_ranks.is_empty(), "A previous run's callback cannot acquire ranks in a new run")

func test_exhausted_pool():
	fresh_run()
	cap_all_except([])
	game.hp = 20.0
	game.pending_choices = 3
	var initial_stats = game.stats.duplicate(true)
	var initial_ranks = game.upgrade_ranks.duplicate(true)
	var discoveries = game.profile.unlocks.duplicate()
	var valid = true
	for remaining in [2, 1, 0]:
		advance_reward_panel()
		var choices = shown_buttons()
		if choices.size() != 1:
			valid = false
			break
		var rest = choices[0]
		var hp_before = game.hp
		rest.pressed.emit()
		valid = valid and near(game.hp, hp_before + game.stats.max_hp * 0.1) and game.pending_choices == remaining
		var hp_after = game.hp
		rest.pressed.emit()
		valid = valid and near(game.hp, hp_after) and game.pending_choices == remaining
	check(valid and game.state == "playing" and game.pending_choices == 0, "An exhausted pool grants one 10% rest heal per pending choice, with no double grants or softlock")
	check(game.stats == initial_stats and game.upgrade_ranks == initial_ranks and game.profile.unlocks == discoveries, "Rest rewards leave stats, upgrade ranks, and discoveries unchanged")

	fresh_run()
	cap_all_except([])
	game.hp = 95.0
	game.pending_choices = 1
	game.show_upgrades()
	shown_buttons()[0].pressed.emit()
	check(near(game.hp, game.stats.max_hp), "An exhausted-pool heal caps at maximum health")
	fresh_run()
	cap_all_except([])
	game.hp = 0.0
	game.pending_choices = 1
	game.show_upgrades()
	shown_buttons()[0].pressed.emit()
	check(near(game.hp, 0.0) and game.pending_choices == 0, "An exhausted-pool heal cannot revive a player at zero HP")

	fresh_run()
	cap_all_except([])
	game.hp = 20.0
	game.pending_choices = 1
	game.show_upgrades()
	var stale = shown_buttons()[0]
	game.show_upgrades()
	stale.pressed.emit()
	check(near(game.hp, 20.0) and game.pending_choices == 1, "A replaced rest modal cannot heal or consume its replacement's reward")
	stale = shown_buttons()[0]
	game.show_menu()
	stale.pressed.emit()
	check(near(game.hp, 20.0) and game.state == "menu", "A dismissed rest reward cannot heal an abandoned run")

	fresh_run()
	cap_all_except(["keen_edge"])
	game.upgrade_ranks.keen_edge = game.upgrade_cap("keen_edge") - 1
	game.hp = 20.0
	game.pending_choices = 2
	game.show_upgrades()
	var final_upgrade = shown_buttons()[0]
	final_upgrade.pressed.emit()
	advance_reward_panel()
	var last_choices = shown_buttons()
	check(game.available_upgrades().is_empty() and last_choices.size() == 1 and button_upgrade_id(last_choices[0]) == "", "Taking the last available rank transitions the next pending reward to rest")
	if last_choices.size() == 1:
		last_choices[0].pressed.emit()
	check(game.pending_choices == 0 and game.state == "playing" and near(game.hp, 30.0), "A mixed final-upgrade/rest sequence resolves every pending reward")

func test_effective_bounds():
	fresh_run()
	for key in game.D.STAT_LIMITS:
		game.stats[key] = float(game.D.STAT_LIMITS[key][1]) + 1000000.0
	game.clamp_stats()
	check(all_stats_bounded(), "The shared clamp enforces every stat's upper bound")
	for key in game.D.STAT_LIMITS:
		game.stats[key] = float(game.D.STAT_LIMITS[key][0]) - 1000000.0
	game.clamp_stats()
	check(all_stats_bounded(), "The shared clamp enforces every stat's lower bound")
	fresh_run()
	var huge_bonus = {}
	for key in game.D.STAT_LIMITS:
		huge_bonus[key] = -1000000.0 if key == "dash_cooldown" else 1000000.0
	game.apply_stats(huge_bonus)
	check(all_stats_bounded() and game.hp <= game.stats.max_hp, "Equipment-style stat bonuses cannot bypass ceilings, cooldown floor, or maximum health")
	for build_index in range(game.D.BUILDS.size()):
		fresh_run()
		game.selected_build = build_index
		game.start_run()
		for upgrade in game.D.UPGRADES:
			for rank in range(game.upgrade_cap(upgrade.id)):
				game.apply_upgrade(upgrade.id)
		var ranks_before_growth = game.upgrade_ranks.duplicate(true)
		game.stage = 20
		for item_index in range(80):
			game.apply_stats(game.random_equipment().stats)
		for gained_level in range(250):
			game.gain_xp(game.needed_xp())
		check(all_stats_bounded() and game.hp <= game.stats.max_hp and near(game.stats.lifesteal, 0.1), "Build %d stays within final limits after all upgrades, 80 relics, and 250 levels" % build_index)
		check(game.upgrade_ranks == ranks_before_growth, "Build %d level growth and relics never acquire extra upgrade ranks" % build_index)

func write_profile(payload):
	var file = FileAccess.open(game.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()

func test_profile_compatibility():
	fresh_run()
	write_profile({"unlocks":["keen_edge", "life_drain", "keen_edge", "unknown", 3], "selected_ability":"keen_edge", "upgrade_ranks":{"keen_edge":999, "life_drain":1}, "stats":{"damage":999999, "lifesteal":0.9}})
	game.load_profile()
	check(game.profile.unlocks == ["keen_edge", "life_drain"] and not game.profile.has("upgrade_ranks") and not game.profile.has("stats"), "Legacy profiles sanitize discovery IDs and ignore injected run ranks and stats")
	game.start_run()
	check(game.upgrade_rank("keen_edge") == 1 and game.upgrade_rank("life_drain") == 0 and near(game.stats.damage, 24.0) and near(game.stats.lifesteal, 0.0), "Loading saved selections grants only one starting rank, never saved run power")
	game.apply_upgrade("heartwood")
	var before_ranks = game.upgrade_ranks.duplicate(true)
	write_profile({"unlocks":null, "selected_ability":42, "upgrade_ranks":["heartwood", 999], "stats":"invalid"})
	game.load_profile()
	check(game.upgrade_ranks == before_ranks and game.selected_ability == "" and game.profile.unlocks.is_empty(), "Malformed profile loading cannot replace live run ranks or equip an invalid ability")
	game.start_run()
	check(game.upgrade_ranks.is_empty(), "A fresh run after malformed profile loading has no leaked ranks")

	game.test_mode = false
	game.save_profile()
	var saved_before = FileAccess.get_file_as_string(game.SAVE_PATH)
	game.apply_upgrade("keen_edge")
	check(FileAccess.get_file_as_string(game.SAVE_PATH) == saved_before, "Direct upgrade application never writes the profile")
	game.save_profile()
	var saved = JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
	check(saved is Dictionary and not saved.has("upgrade_ranks") and not saved.has("stats"), "Explicit profile saves retain discoveries and selections without run ranks or stats")
	game.test_mode = true

func finish():
	if had_profile:
		var file = FileAccess.open("user://legis_adventure.json", FileAccess.WRITE)
		file.store_string(saved_profile_text)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://legis_adventure.json"))
	print("BALANCE_TESTS: ", passed, " passed; ", failures.size(), " failed")
	for failure in failures:
		print(" - ", failure)
	quit(0 if failures.is_empty() else 1)
