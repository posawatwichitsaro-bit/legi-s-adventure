extends SceneTree
var game
func _initialize():call_deferred("capture")
func shot(name:String):
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var result=root.get_texture().get_image().save_png("res://screenshots/redesign/"+name+".png")
	if result!=OK:push_error("Screenshot failed "+name)
func capture():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots/redesign"))
	game=load("res://main.tscn").instantiate();game.test_mode=true
	root.add_child(game);game.set_process(false)
	game.selected_class=0;game.selected_option="sword";game.show_menu()
	await shot("menu")
	game.show_classes();await shot("classes")
	for cls in range(4):
		game.selected_class=cls;game.selected_option="";game.validate_starting_option()
		game.show_skills();await shot("options-"+str(cls))
	game.selected_class=0;game.selected_option="sword";game.start_run()
	game.level=10;game.pending_choices=1;game.show_tactics();await shot("tactics")
	game.pending_choices=0;game.clear_panel();game.state="playing";game.stage=5
	game.PlayerSkills.offer(game);await shot("skills")
	game.state="playing";game.clear_panel();game.show_loot();await shot("equipment")
	for number in [25,30]:
		game.selected_class=2;game.selected_option="light";game.start_run()
		game.stage=number;game.start_stage();game.spawn_queue.clear();game.enemies.clear();game.obstacles.clear()
		game.World.reset_hazards(game);game.world_data.hazards_enabled=false
		game.player=game.CENTER+Vector2(-130,30);game.update_camera()
		game.spawn_enemy("boss");var boss=game.enemies[0]
		boss.pos=game.CENTER+Vector2(80,-10);boss.phase=1.8;game.elapsed=1.8;boss.spawn_grace=0
		game.Combat.begin(game,boss)
		boss.attack_pattern="storm_lanes" if number==25 else "eclipse_seals"
		game.cast_aim=(boss.pos-game.player).normalized();game.ClassCombat.release_staff(game)
		for b in game.bullets:b.pos+=b.vel*.24
		game.update_hud();game.toast("TEMPEST COLOSSUS" if number==25 else "ECLIPSE SERAPH")
		await shot("boss-"+str(number))
	game.selected_class=3;game.selected_option="throwing_knife";game.start_run()
	game.learn_skill("dash_poison_1");game.learn_skill("dash_bleed_1");game.show_pause();await shot("pause")
	print("VISUAL_QA: 12 captures")
	game.queue_free();await process_frame;quit()
