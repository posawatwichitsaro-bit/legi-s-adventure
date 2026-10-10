extends "res://main.gd"
## Isolated native-render fixture. Never the project's default scene; no save I/O.
## This captures deliberately seeded poses, NOT evidence of naturally reached play.
## Run: godot --path . visual_qa_v7.tscn -- --qa-capture-all
## N/P cycle fixtures; F12 saves the current viewport; A captures the whole set.

const QA_CASES = [
	"blade-focused", "blade-thrust", "blade-cleave", "blade-sweep",
	"moon-homing", "moon-spread", "moon-radial", "moon-fire", "moon-familiar", "moon-shield-hit", "moon-shield-regen",
	"ranger-bow", "ranger-trap-charge", "ranger-rapid-fan",
	"comet-dagger", "comet-long-trail", "comet-double-dash", "comet-poison", "comet-push",
	"menu-classes", "menu-blade-tactics", "menu-moon-tactics", "menu-ranger-tactics", "menu-comet-tactics"
]
var qa_index := 0
var qa_case := ""
var qa_description := ""
var qa_banner: Label
var qa_busy := false
var qa_tactic_filter: Array = []
var qa_annotations: Array = []

func load_profile():
	pass

func save_profile():
	pass

func _ready():
	test_mode = true
	super._ready()
	profile.sfx = false
	profile.shake = false
	selected_skill = ""
	qa_banner = Label.new()
	qa_banner.z_index = 100
	qa_banner.position = Vector2(45,122)
	qa_banner.size = Vector2(865,40)
	qa_banner.add_theme_font_size_override("font_size",13)
	qa_banner.add_theme_color_override("font_color",Color("ffe8a1"))
	qa_banner.add_theme_color_override("font_outline_color",Color("10182b"))
	qa_banner.add_theme_constant_override("outline_size",5)
	ui.add_child(qa_banner)
	setup_case(0)
	if "--qa-capture-all" in OS.get_cmdline_user_args():
		call_deferred("capture_all")

func available_tactics() -> Array:
	var choices = super.available_tactics()
	if qa_tactic_filter.is_empty(): return choices
	return choices.filter(func(u): return u.id in qa_tactic_filter)

func _process(_delta):
	queue_redraw()

func seed_enemy(offset: Vector2, kind: String = "grunt") -> Dictionary:
	spawn_enemy(kind)
	var e: Dictionary = enemies[-1]
	e.pos = player + offset
	e.hp = 250.0
	e.max_hp = 250.0
	e.hit = 0.0
	e.phase = 1.3
	e.spawn_grace = 0.0
	e.facing = Vector2.LEFT
	e.attack_state = "idle"
	e.moving = false
	return e

func seed_tactic(id: String, count: int = 1):
	for i in range(count):
		if not apply_tactic(id): push_error("V7 QA could not apply " + id + " rank " + str(i + 1))

func setup_case(index: int):
	qa_index = posmod(index,QA_CASES.size())
	qa_case = QA_CASES[qa_index]
	qa_tactic_filter.clear()
	qa_annotations.clear()
	selected_skill = ""
	selected_class = 0
	if "moon" in qa_case: selected_class = 2
	elif "ranger" in qa_case: selected_class = 1
	elif "comet" in qa_case: selected_class = 3
	rng.seed = 7072026
	start_run()
	enemies.clear(); spawn_queue.clear(); bullets.clear(); effects.clear()
	World.reset_hazards(self)
	# A fixture may pose actors in the clear centre; world artwork stays native.
	player = CENTER
	facing = Vector2.RIGHT
	hurt_cd = 0.0
	toast_time = 0.0
	elapsed = 1.25
	wave_index = 1; wave_count = 1
	qa_description = "Actual game render; deterministic pose, no saved progress."
	if qa_case.begins_with("blade-"):
		if qa_case != "blade-focused": seed_tactic(qa_case.replace("-","_"))
		for angle in [-PI,-PI / 2.0,0.0,PI / 2.0]: seed_enemy(Vector2.RIGHT.rotated(angle) * 135.0)
		sword_aim = Vector2.RIGHT
		sword_state = "active"
		sword_time = melee_duration("active") * 0.7
		slash_time = sword_time
		slash_angle = 0.0
		var spec = ClassCombat.melee_spec(self)
		qa_description = "%s | %.0f degree arc | %.0f px reach | %.1f attack damage" % [str(spec.get("style","slash")).to_upper(),rad_to_deg(acos(float(spec.cone_dot)) * 2.0),melee_range(),melee_damage()]
	elif qa_case.begins_with("moon-"):
		seed_enemy(Vector2(235,-66))
		cast_aim = Vector2.RIGHT
		if qa_case in ["moon-spread","moon-fire"]: seed_tactic("moon_spread",2)
		if qa_case in ["moon-radial","moon-familiar"]: seed_tactic("moon_radial",2)
		if qa_case == "moon-fire":
			seed_tactic("moon_fire",2)
			player = CENTER - Vector2(88,0)
			for i in range(8):
				var old = player
				player += Vector2(14,0)
				ClassCombat.tick(self,0.055,old)
			qa_description = "Moonfire rank 2 | native fire patch rendering | Lunar Fan 5-bolt spread"
		elif qa_case == "moon-familiar":
			seed_tactic("moon_familiar")
			ClassCombat.tick(self,0.01,player)
			ClassCombat.tick(self,1.75,player)
			qa_description = "Orbiting Familiar | homing familiar bolt + Moonburst radial sparks"
		elif qa_case.begins_with("moon-shield"):
			seed_tactic("moon_ward",2)
			shield = ClassProgression.shield_max(self)
			damage_player(24.0)
			hurt_cd = 0.0
			if qa_case == "moon-shield-regen":
				ClassProgression.tick(self,4.2)
				ClassProgression.tick(self,0.7)
			qa_description = "Waxing Ward rank 2 | health %.0f/%.0f | shield %.1f/%.0f | delay %.1fs" % [hp,stats.max_hp,shield,ClassProgression.shield_max(self),shield_delay]
		else: qa_description = "Homing staff bolts | %s | target is above the initial aim" % qa_case.trim_prefix("moon-")
		ClassCombat.release_staff(self)
		for i in range(15):
			for b in bullets:
				ClassCombat.update_bullet(self,b,0.02)
				b.pos += b.vel * 0.02
		cast_release_time = 0.15
	elif qa_case.begins_with("ranger-"):
		var target = seed_enemy(Vector2(235,0))
		if qa_case == "ranger-rapid-fan":
			seed_tactic("ranger_rapid",2); seed_tactic("ranger_fan",2)
		if qa_case == "ranger-trap-charge":
			seed_tactic("ranger_evasion",2)
			trap_charges = ClassProgression.trap_max(self)
			ClassProgression.avoid_trap(self)
			ClassProgression.tick(self,3.3)
			world_data.hazards.append({"pos":player + Vector2(-105,50),"radius":38.0,"state":"active","time":0.3,"duration":0.6,"hit":true,"theme":0,"serial":1,"damage":12.0,"phase":0.0})
		bow_windup = 0.01; bow_aim = Vector2.RIGHT
		update_player_attacks(0.02,target)
		for b in bullets: b.pos += b.vel * 0.31
		bow_release_time = 0.13
		qa_description = "Native bow volley | %d arrows | attack speed %.2f | trap charges %d/%d" % [bullets.size(),stats.attack_speed,trap_charges,ClassProgression.trap_max(self)]
	elif qa_case.begins_with("comet-"):
		var target = seed_enemy(Vector2(130,0))
		if qa_case in ["comet-long-trail","comet-poison"]: seed_tactic("comet_length",2)
		if qa_case in ["comet-double-dash","comet-push"]: seed_tactic("comet_echo")
		if qa_case == "comet-poison": seed_tactic("comet_poison",2)
		if qa_case == "comet-push": seed_tactic("comet_push",2)
		if qa_case != "comet-dagger":
			dash_charges = ClassProgression.dash_max(self)
			dash()
			player = CENTER - Vector2(100,0)
			for i in range(7):
				var old = player
				player += Vector2(18,0)
				ClassCombat.tick(self,0.025,old)
			if qa_case == "comet-poison":
				for i in range(3): ClassCombat.on_dash_hit(self,target)
			if qa_case == "comet-push":
				var before: Vector2 = target.pos
				ClassCombat.on_dash_hit(self,target)
				qa_annotations.append({"pos":before,"text":"BEFORE"})
				qa_annotations.append({"pos":target.pos,"text":"PUSHED"})
				qa_description = "Comet Impact rank 2 | native knockback %.0f px | committed attacks cannot be pushed" % before.distance_to(target.pos)
		else:
			sword_state = "active"; sword_time = melee_duration("active") * 0.7
			slash_time = sword_time; slash_angle = 0.0
		if qa_case != "comet-push": qa_description = "Native %s | dash %.2fs | charges %d/%d | poison markers %d" % [qa_case.trim_prefix("comet-"),ClassProgression.dash_duration(self),dash_charges,ClassProgression.dash_max(self),int(target.get("poison_stacks",0))]
	elif qa_case == "menu-classes":
		show_menu(); show_classes()
		qa_description = "Class selector readability / class identity"
	elif qa_case.begins_with("menu-"):
		match selected_class:
			0: qa_tactic_filter = ["blade_thrust","blade_cleave","blade_sweep"]
			1: qa_tactic_filter = ["ranger_fan","ranger_rapid","ranger_evasion"]
			2:
				seed_tactic("moon_spread"); seed_tactic("moon_radial")
				qa_tactic_filter = ["moon_fire","moon_familiar","moon_ward"]
			3:
				seed_tactic("comet_echo"); seed_tactic("comet_length")
				qa_tactic_filter = ["comet_length","comet_poison","comet_push"]
		level = 5; pending_choices = 1
		show_tactics()
		qa_description = "Native Tactic menu; class choices seeded for long-description readability."
	total_enemies = maxi(1,enemies.size())
	update_camera()
	if not qa_case.begins_with("menu-"): update_hud()
	qa_banner.position.y = 4 if qa_case.begins_with("menu-") else 122
	qa_banner.text = "SEEDED QA  |  %02d/%02d  |  %s\n%s" % [qa_index + 1,QA_CASES.size(),qa_case.to_upper(),qa_description]
	queue_redraw()

func _draw():
	super._draw()
	if font == null:return
	draw_set_transform(-camera_offset)
	for annotation in qa_annotations:
		draw_arc(annotation.pos,20,0,TAU,16,Color("ffdc92"),1)
		draw_string(font,annotation.pos + Vector2(-22,39),annotation.text,HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("ffe8a1"))
	draw_set_transform(Vector2.ZERO)

func save_capture():
	await RenderingServer.frame_post_draw
	var folder = ProjectSettings.globalize_path("res://screenshots")
	DirAccess.make_dir_recursive_absolute(folder)
	var filename = "seeded-v7-%02d-%s.png" % [qa_index + 1,qa_case]
	var result = get_viewport().get_texture().get_image().save_png(folder.path_join(filename))
	print("V7_NATIVE_CAPTURE ",filename," result=",result," | ",qa_description)

func capture_all():
	if qa_busy:return
	qa_busy = true
	for i in range(QA_CASES.size()):
		setup_case(i)
		await get_tree().process_frame
		await get_tree().process_frame
		await save_capture()
	qa_busy = false
	setup_case(0)
	print("V7_NATIVE_CAPTURE_COMPLETE ",QA_CASES.size()," SEEDED fixtures; no profile I/O")

func _unhandled_input(event):
	if qa_busy:return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_N: setup_case(qa_index + 1)
			KEY_P: setup_case(qa_index - 1)
			KEY_F12: save_capture()
			KEY_A: capture_all()
