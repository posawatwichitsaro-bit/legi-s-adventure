extends "res://main.gd"
# Optional, isolated SEEDED QA fixture. Never the default scene; no profile I/O.
# 1-4: themes. T/Y/U: hazard warning/active/recovery. F: frozen/live.
# C: camera waypoint. G: reset real wave encounter. P: seeded portal scenario.
# B: build. R: reset. N: seed-clear current group. F12: native capture. V: diagnostics.
var qa_frozen = true
var qa_theme = 0
var qa_pose = "telegraph"
var qa_waypoint = 0
var qa_scenario = "hazards"
var qa_capture_pending = false

func load_profile():
	pass

func _ready():
	test_mode = true
	super._ready()
	profile.sfx = false
	selected_ability = ""
	start_run()
	setup_qa(0)

func setup_qa(theme_index: int, pose_fixture: bool = true):
	qa_theme = clampi(theme_index,0,3)
	qa_scenario = "hazards"
	qa_waypoint = 0
	qa_frozen = true
	stage = 1 + qa_theme * 5
	rng.seed = 6062026 + qa_theme
	start_stage()
	hurt_cd = 0
	toast_time = 0
	if pose_fixture:pose_hazards("telegraph")
	else:qa_pose="natural"
	update_camera()
	update_qa_hud()

func pose_hazards(which: String):
	qa_pose = which
	qa_frozen = true
	if world_data.get("hazards",[]).is_empty():
		for offset in [Vector2(170,0),Vector2(-220,55)]:
			world_data.hazards.append({"pos":CENTER+offset,"radius":38.0,"state":"telegraph","time":1.4,"duration":1.4,"hit":false,"theme":qa_theme,"serial":1,"damage":12.0,"phase":0.0})
	var duration = World.TELEGRAPH_TIME if which == "telegraph" else (World.ACTIVE_TIME if which == "active" else World.RECOVERY_TIME)
	for hazard in world_data.get("hazards",[]):
		hazard["state"] = which
		hazard["time"] = duration*0.5
		hazard["duration"] = duration
		hazard["hit"] = false
	update_qa_hud()
	queue_redraw()

func move_waypoint():
	qa_waypoint = (qa_waypoint + 1) % 6
	var points = [CENTER, Vector2(150,210),Vector2(1250,210),Vector2(1250,690),Vector2(150,690),CENTER]
	var wanted: Vector2 = points[qa_waypoint]
	if qa_waypoint == 5:
		var hazards: Array = world_data.get("hazards",[])
		if not hazards.is_empty(): wanted = hazards[0].get("pos",CENTER) + Vector2(0,110)
	if blocked(wanted,12):
		for distance in [32,64,96,128,160]:
			var found = false
			for direction in [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP]:
				var candidate = wanted + direction * distance
				if not blocked(candidate,12): wanted=candidate;found=true;break
			if found:break
	player = wanted
	facing = Vector2.RIGHT
	update_camera()
	update_qa_hud()
	queue_redraw()

func setup_live_waves():
	setup_qa(qa_theme,false)
	qa_scenario = "waves"
	qa_pose = "natural"
	qa_frozen = false
	update_qa_hud()

func setup_portal():
	setup_qa(qa_theme)
	qa_scenario = "portal"
	enemies.clear();spawn_queue.clear();bullets.clear();gems.clear();potions.clear()
	boss_reward_taken = true
	open_portal()
	player = Vector2(1240,680)
	if blocked(player,12):player=Vector2(1200,700)
	stage_time = 3
	qa_pose = "safe"
	update_camera()
	update_qa_hud()

func update_qa_hud():
	update_hud()
	hint.text = "SEEDED QA  |  1-4 themes  T/Y/U hazard poses  F live  C camera  G waves  N seed clear  P portal  F12 capture"

func _process(delta):
	var previous_stage=stage
	if not qa_frozen:super._process(delta)
	else:queue_redraw()
	if stage!=previous_stage:qa_scenario="post-portal";qa_pose="natural"
	update_qa_hud()

func _draw():
	super._draw()
	if font == null:return
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(32,87,896,24),Color("10182b"))
	var label = "SEEDED QA  |  %s  |  %s %s  |  CAMERA %.0f,%.0f  |  POS %.0f,%.0f  |  HP %.0f  DASH %.1f" % ["FROZEN" if qa_frozen else "LIVE",qa_scenario.to_upper(),qa_pose.to_upper(),camera_offset.x,camera_offset.y,player.x,player.y,hp,dash_cd]
	draw_string(font,Vector2(34,104),label,HORIZONTAL_ALIGNMENT_LEFT,890,12,Color("ffe0a0"))

func save_capture():
	if qa_capture_pending:return
	qa_capture_pending=true
	await RenderingServer.frame_post_draw
	var folder = ProjectSettings.globalize_path("res://screenshots")
	DirAccess.make_dir_recursive_absolute(folder)
	var filename = "seeded-v6-%d-%s-%s-view%d.png" % [qa_theme+1,qa_scenario,qa_pose,qa_waypoint]
	var result=get_viewport().get_texture().get_image().save_png(folder.path_join(filename))
	print("V6_NATIVE_CAPTURE ",filename," result=",result)
	qa_capture_pending=false

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1,KEY_2,KEY_3,KEY_4:setup_qa(event.keycode-KEY_1)
			KEY_T:pose_hazards("telegraph")
			KEY_Y:pose_hazards("active")
			KEY_U:pose_hazards("recovery")
			KEY_F:qa_frozen = not qa_frozen
			KEY_C:move_waypoint()
			KEY_G:setup_live_waves()
			KEY_P:setup_portal()
			KEY_N:enemies.clear();bullets.clear();World.reset_hazards(self);qa_scenario="seeded-group-clear";qa_pose="natural";qa_frozen=true;update_qa_hud()
			KEY_B:selected_build=(selected_build+1)%4;start_run();setup_qa(qa_theme)
			KEY_R:setup_qa(qa_theme)
			KEY_F12:save_capture()
			KEY_V:print("V6_QA_STATUS ",{"stage":stage,"state":state,"player":player,"camera":camera_offset,"hp":hp,"dash":dash_cd,"active":enemies.size(),"queued":spawn_queue.size(),"wave":wave_index,"portal":portal_open})
			_:super._unhandled_input(event)
	else:super._unhandled_input(event)
