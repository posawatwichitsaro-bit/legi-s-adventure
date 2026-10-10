extends Node2D

const D = preload("res://data.gd")
const Combat = preload("res://combat.gd")
const Art = preload("res://character_art.gd")
const World = preload("res://world.gd")
const ClassCombat = preload("res://class_combat.gd")
const ClassProgression = preload("res://class_progression.gd")
const VIEW = Rect2(32, 112, 896, 456)
const ARENA = Rect2(32, 112, 1344, 684)
const CENTER = Vector2(704, 454)
const SAVE_PATH = "user://legis_adventure.json"
var rng = RandomNumberGenerator.new()
var state = "menu"
var stage = 1
var level = 1
var xp = 0.0
var hp = 100.0
var stats = {}
var player = CENTER
var facing = Vector2.RIGHT
var dash_left = 0.0
var dash_cd = 0.0
var hurt_cd = 0.0
var attack_cd = 0.0
var magic_cd = 0.0
var bow_cd = 0.0
var elapsed = 0.0
var stage_time = 0.0
var enemies: Array = []
var bullets: Array = []
var gems: Array = []
var potions: Array = []
var stage_clear_healed = false
var healing_feedback = ""
var healing_flash = 0.0
var effects: Array = []
var obstacles: Array = []
var flowers: Array = []
var run_equipment: Array = []
var tactic_ranks: Dictionary = {}
var pending_choices = 0
var boss_reward_taken = false
var portal_open = false
var kills = 0
var total_enemies = 0
var spawn_queue: Array = []
var wave_index = 0
var wave_count = 0
var wave_timer = 0.0
var wave_size = 4
var active_cap = 6
var world_data: Dictionary = {}
var camera_offset = Vector2.ZERO
var selected_class = 0
var selected_skill = ""
var selected_cosmetic = 0
# Legacy profile keys keep existing saves compatible with Class and Skill names.
var profile = {"best_stage":0,"wins":0,"unlocks":[],"equipment":[],"sfx":true,"shake":true,"volume":0.5,"selected_build":0,"selected_ability":"","selected_cosmetic":0}
var ui: CanvasLayer
var panel: Control
var hud: Label
var hint: Label
var textures = {}
var font: Font
var toast_text = ""
var toast_time = 0.0
var slash_angle = 0.0
var slash_time = 0.0
var audio: AudioStreamPlayer
var sound_cd = 0.0
var test_mode = false
var player_moving = false
var sword_state = "idle"
var sword_time = 0.0
var sword_aim = Vector2.RIGHT
var sword_hits: Array = []
var bow_windup = 0.0
var cast_windup = 0.0
var bow_aim = Vector2.RIGHT
var cast_aim = Vector2.RIGHT
var bow_release_time = 0.0
var cast_release_time = 0.0
var release_time = 0.0
var release_kind = ""
var shield = 0.0
var shield_delay = 0.0
var dash_charges = 1
var dash_recharge = 0.0
var trap_charges = 0
var trap_recharge = 0.0
var class_fx: Dictionary = {}
var trail_patches: Array = []


func _ready():
	rng.randomize()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	font = ThemeDB.fallback_font
	for name in ["owl","grunt","archer","swift","bomber","ghost","boss","crystal","portal","herbalist","potion_2","potion_4","potion_6"]:
		if ResourceLoader.exists("res://assets/"+name+".png"):
			textures[name] = load("res://assets/"+name+".png")
	load_profile()
	ui = CanvasLayer.new()
	add_child(ui)
	hud = Label.new()
	hud.position = Vector2(32,17)
	hud.add_theme_font_size_override("font_size",18)
	ui.add_child(hud)
	hint = Label.new()
	hint.position = Vector2(32,575)
	hint.add_theme_font_size_override("font_size",12)
	hint.modulate = Color("aebbd9")
	ui.add_child(hint)
	audio = AudioStreamPlayer.new()
	add_child(audio)
	show_menu()
	if "--self-test" in OS.get_cmdline_user_args():
		test_mode = true
		call_deferred("self_test")

func load_profile():
	if not FileAccess.file_exists(SAVE_PATH): return
	var f = FileAccess.open(SAVE_PATH,FileAccess.READ)
	if not f: return
	var saved = JSON.parse_string(f.get_as_text())
	if not saved is Dictionary: return
	for key in ["best_stage", "wins", "selected_build", "selected_cosmetic"]:
		if saved.get(key) is float or saved.get(key) is int:
			profile[key] = maxi(0,int(saved[key]))
	profile.best_stage = mini(20,profile.best_stage)
	for key in ["sfx", "shake"]:
		if saved.get(key) is bool: profile[key] = saved[key]
	if saved.get("volume") is float or saved.get("volume") is int:
		profile.volume = clampf(float(saved.volume),0,1)
	for key in ["unlocks", "equipment"]:
		profile[key] = []
		if saved.get(key) is Array:
			for value in saved[key]:
				if not value is String or value in profile[key]: continue
				if key == "equipment" and value in D.EQUIPMENT_NAMES: profile[key].append(value)
				if key == "unlocks":
					for tactic in D.TACTICS:
						if value == tactic.id: profile[key].append(value); break
	selected_class = clampi(int(profile.selected_build),0,D.CLASSES.size()-1)
	selected_cosmetic = clampi(int(profile.selected_cosmetic),0,D.COSMETICS.size()-1)
	if D.COSMETICS[selected_cosmetic].stage > profile.best_stage: selected_cosmetic = 0
	selected_skill = saved.get("selected_ability", "") if saved.get("selected_ability", "") is String else ""
	if not selected_skill in profile.unlocks: selected_skill = ""
	validate_starting_skill()

func validate_starting_skill():
	for u in D.TACTICS:
		if u.id == selected_skill and not u.get("classes",[]).is_empty() and not D.CLASSES[selected_class].id in u.classes:
			selected_skill = ""
			return

func save_profile():
	if test_mode: return
	validate_starting_skill()
	profile.version = 7
	profile.selected_build = selected_class
	profile.selected_ability = selected_skill
	profile.selected_cosmetic = selected_cosmetic
	var file = FileAccess.open(SAVE_PATH,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(profile))

func clear_panel():
	if is_instance_valid(panel):
		panel.hide()
		panel.queue_free()
		panel = null

func modal(title: String, subtitle: String) -> VBoxContainer:
	clear_panel()
	panel = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(panel)
	var shade = ColorRect.new()
	shade.color = Color(0.025,0.035,0.075,0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(shade)
	var box = VBoxContainer.new()
	box.position = Vector2(100,70)
	box.size = Vector2(760,460)
	box.add_theme_constant_override("separation",12)
	panel.add_child(box)
	var title_label = Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size",34)
	title_label.modulate = Color("ffe69a")
	box.add_child(title_label)
	var sub = Label.new()
	sub.text = subtitle
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size",15)
	sub.modulate = Color("b3c8e8")
	box.add_child(sub)
	return box

func wrap_button_text(text: String) -> String:
	var lines: Array[String] = []
	for source in text.split("\n"):
		var line = ""
		for word in source.split(" "):
			if line.length()+word.length()+1>80 and not line.is_empty():
				lines.append(line);line=""
			line += (" " if not line.is_empty() else "") + word
		lines.append(line)
	return "\n".join(lines)

func button(parent: Control, text: String, callback: Callable, color = Color("253552")) -> Button:
	var b = Button.new()
	b.text = wrap_button_text(text)
	b.custom_minimum_size = Vector2(0,46)
	b.add_theme_font_size_override("font_size",16)
	b.add_theme_color_override("font_color",Color("f2f5ff"))
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = color.lightened(0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	b.add_theme_stylebox_override("normal",style)
	var hover = style.duplicate()
	hover.bg_color = color.lightened(0.2)
	b.add_theme_stylebox_override("hover",hover)
	b.add_theme_stylebox_override("focus",hover)
	# Ignore signals queued by a panel that was already dismissed/replaced.
	var owner_panel = panel
	b.pressed.connect(func():
		if is_instance_valid(owner_panel) and owner_panel == panel and not owner_panel.is_queued_for_deletion():
			callback.call()
	)
	parent.add_child(b)
	return b

func show_menu():
	state = "menu"
	class_fx.clear();trail_patches.clear()
	spawn_queue.clear()
	World.reset_hazards(self)
	enemies.clear()
	bullets.clear()
	hud.text = ""
	hint.text = "WASD / arrows or hold left mouse to move   •   Space / right mouse to dash   •   Esc to pause"
	var box = modal("LEGI'S ADVENTURE", "A tiny owl. A very big adventure.\n20 wild arenas • 4 guardians • one more run")
	var spacer = TextureRect.new()
	spacer.texture = textures.get("owl")
	spacer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spacer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spacer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	spacer.custom_minimum_size.y = 52
	box.add_child(spacer)
	button(box,"START ADVENTURE  →",start_run,Color("416946"))
	var row = HBoxContainer.new()
	box.add_child(row)
	button(row,"CLASS: " + str(D.CLASSES[selected_class].name),show_classes).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button(row,"COSMETICS",show_cosmetics).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button(box,"STARTING SKILL  ·  " + skill_name(selected_skill),show_skills)
	var row2 = HBoxContainer.new()
	box.add_child(row2)
	button(row2,"EQUIPMENT JOURNAL",show_equipment).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button(row2,"SETTINGS",show_settings).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var label = Label.new()
	label.text = "BEST STAGE %02d / 20     •     %d VICTORIES" % [profile.best_stage,profile.wins]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = Color("93a7c8")
	box.add_child(label)
	hint.z_index=5
	queue_redraw()

func skill_name(id: String) -> String:
	for u in D.TACTICS:
		if u.id == id: return u.name
	return "None (" + str(D.CLASSES[selected_class].weapon_label) + " primary)"

func show_classes():
	var box = modal("CHOOSE YOUR CLASS","Your Class equips its automatic primary weapon from level 1.\nTactics can add other attack types. All stats keep their final limits.")
	for i in D.CLASSES.size():
		var class_def = D.CLASSES[i]
		button(box,class_def.name + "  ·  " + class_def.weapon_label.to_upper() + "\n" + class_def.description,func(): selected_class=i; save_profile(); show_menu())
	button(box,"BACK",show_menu)

func show_cosmetics():
	var box = modal("WARDROBE","Permanent colors earned by defeating guardians.")
	for i in D.COSMETICS.size():
		var cosmetic = D.COSMETICS[i]
		var unlocked = int(profile.best_stage) >= int(cosmetic.stage)
		var b = button(box,cosmetic.name + ("  ✓" if i==selected_cosmetic else "") + ("" if unlocked else "  ·  Clear stage %d" % cosmetic.stage),func(): selected_cosmetic=i; save_profile(); show_cosmetics(),cosmetic.color.darkened(0.6))
		b.disabled = not unlocked
	button(box,"BACK",show_menu)

func show_skills():
	var box = modal("CHOOSE YOUR STARTING SKILL","Tactics you discover unlock Skills for future runs.\nEquip one Skill at rank 1. Discoveries stay unlocked after death.")
	button(box,"NONE  ·  " + str(D.CLASSES[selected_class].weapon_label) + " primary only",func(): selected_skill="";save_profile();show_menu())
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size.y = 245
	box.add_child(scroll)
	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for u in D.TACTICS:
		if u.id in profile.unlocks and (u.get("classes",[]).is_empty() or D.CLASSES[selected_class].id in u.classes):
			button(list,u.name + "  ·  " + u.description,func(): selected_skill=u.id;save_profile();show_menu())
	if profile.unlocks.is_empty():
		var l = Label.new()
		l.text = "Reach level 5 and choose a Tactic to unlock your first Skill."
		list.add_child(l)
	button(box,"BACK",show_menu)

func show_equipment():
	var box = modal("EQUIPMENT JOURNAL","Guardians offer three randomized Equipment rewards. Choose one.\nBonuses stack for this run; discovered names stay in this journal.")
	var l = Label.new()
	l.text = "DISCOVERED EQUIPMENT\n\n" + ("No Equipment yet. Defeat the stage 5 guardian!" if profile.equipment.is_empty() else "\n".join(profile.equipment))
	l.custom_minimum_size.y=220
	l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	button(box,"BACK",show_menu)

func show_settings():
	var box=modal("SETTINGS","Move with WASD / arrows, or hold left mouse to follow the pointer.\nDash: Space / right mouse. Pause: Escape.")
	button(box,"SOUND EFFECTS: " + ("ON" if profile.sfx else "OFF"),func():profile.sfx=not profile.sfx;save_profile();show_settings())
	button(box,"HIT FLASH: " + ("ON" if profile.shake else "OFF"),func():profile.shake=not profile.shake;save_profile();show_settings())
	var slider=HSlider.new()
	slider.min_value=0;slider.max_value=1;slider.step=0.05;slider.value=profile.volume
	slider.value_changed.connect(func(v):profile.volume=v;save_profile())
	box.add_child(slider)
	button(box,"WINDOW / FULLSCREEN",func(): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN))
	button(box,"BACK",show_menu)

func start_run():
	clear_panel()
	stats={"max_hp":100.0,"damage":18.0,"speed":150.0,"attack_speed":1.0,"range":78.0,"projectiles":0.0,"magic":0.0,"dash_damage":0.0,"dash_cooldown":3.0,"pickup":75.0,"regen":0.15,"armor":0.0,"lifesteal":0.0}
	level=1;xp=0;stage=1;kills=0;elapsed=0;hp=100;pending_choices=0
	run_equipment.clear()
	tactic_ranks.clear()
	class_fx.clear();trail_patches.clear()
	validate_starting_skill()
	# Equip the chosen class before applying its one optional Starting Skill.
	apply_stats(D.CLASSES[selected_class].starting_stats)
	ClassProgression.reset_run(self)
	for u in D.TACTICS:
		if u.id==selected_skill: apply_tactic(u.id)
	hp=stats.max_hp
	start_stage()

func start_stage():
	state="playing"
	clear_panel()
	player=CENTER;facing=Vector2.RIGHT
	class_fx.clear();trail_patches.clear()
	ClassProgression.reset_stage(self)
	dash_cd=0;dash_left=0;hurt_cd=1.5;attack_cd=0.3
	bow_cd=0.3 if primary_weapon()=="bow" else 0.8
	magic_cd=0.3 if primary_weapon()=="staff" else 1.0
	enemies.clear();bullets.clear();gems.clear();potions.clear();effects.clear();obstacles.clear();flowers.clear()
	portal_open=false;boss_reward_taken=false;stage_clear_healed=false;stage_time=0
	healing_flash=0;healing_feedback=""
	sword_state="idle";sword_time=0;sword_hits.clear();slash_time=0
	bow_windup=0;cast_windup=0;release_time=0;release_kind="";player_moving=false
	bow_release_time=0;cast_release_time=0;bow_aim=facing;cast_aim=facing;sword_aim=facing
	var palette=D.THEMES[mini(3,int((stage-1)/5))]
	World.generate(self)
	spawn_queue.clear()
	var tier=mini(3,int((stage-1)/5))
	wave_size=4+tier;active_cap=6+tier*2
	var has_boss=stage%5==0
	# Increase the COMPLETE v5 roster by 25%, rounding up once, not per group.
	total_enemies=int(ceil((8+stage*2+(1 if has_boss else 0))*1.25))
	for i in range(total_enemies-(1 if has_boss else 0)):
		spawn_queue.append(spawn_kind(i))
	if has_boss:spawn_queue.append("boss")
	wave_index=0;wave_count=int(ceil(float(total_enemies)/wave_size));wave_timer=0
	update_waves(0)
	update_camera()
	update_hud()
	toast("STAGE %02d  ·  %s" % [stage,palette.name])

func remaining_enemies() -> int:
	return enemies.size()+spawn_queue.size()

func update_waves(dt: float):
	if state!="playing" or hp<=0 or spawn_queue.is_empty():return
	wave_timer=maxf(0,wave_timer-dt)
	var next_size=mini(wave_size,spawn_queue.size())
	if wave_timer>0 or enemies.size()+next_size>active_cap:return
	for i in range(next_size):
		spawn_enemy(spawn_queue.pop_front())
		enemies[-1]["spawn_grace"]=0.85
	wave_index+=1;wave_timer=3.0
	if wave_index>1:toast("GROUP %d / %d  ·  %d foes still to arrive" % [wave_index,wave_count,spawn_queue.size()])

func update_camera():
	camera_offset=Vector2(clampf(player.x-VIEW.get_center().x,0,ARENA.size.x-VIEW.size.x),clampf(player.y-VIEW.get_center().y,0,ARENA.size.y-VIEW.size.y)).round()

func screen_to_world(pos: Vector2) -> Vector2:
	return pos+camera_offset

func world_to_screen(pos: Vector2) -> Vector2:
	return pos-camera_offset

func spawn_kind(index: int) -> String:
	# Exactly one carrier remains in each arena. Later tiers add different roles
	# instead of replacing all previous variants with one new enemy.
	if index==4:return "herbalist"
	if stage<=5:
		if index>3 and index%5==0:return "swift"
		return "grunt" if index%3!=0 else "archer"
	var mix=[]
	if stage<=10:
		mix=["grunt","archer","sentinel","swift","grunt","assassin","archer","bomber","grunt","sentinel","assassin","archer"]
	elif stage<=15:
		mix=["sentinel","archer","assassin","chanter","grunt","hexer","ghost","bomber","archer","sentinel","swift","assassin","hexer","grunt"]
	else:
		mix=["sentinel","hexer","assassin","archer","grunt","chanter","ghost","bomber","sentinel","archer","assassin","hexer","swift","grunt","chanter","ghost"]
	return mix[index%mix.size()]

func spawn_enemy(kind: String):
	var radius=28 if kind=="boss" else 18
	var pos=CENTER
	for attempt in range(100):
		pos=Vector2(rng.randf_range(ARENA.position.x+radius+8,ARENA.end.x-radius-8),rng.randf_range(ARENA.position.y+radius+8,ARENA.end.y-radius-8))
		if pos.distance_to(player)>220 and pos.distance_to(player)<480 and not blocked(pos,radius):break
	if blocked(pos,radius) or pos.distance_to(player)<=185:
		for y in range(int(ARENA.position.y)+40,int(ARENA.end.y)-40,30):
			for x in range(int(ARENA.position.x)+40,int(ARENA.end.x)-40,30):
				var candidate=Vector2(x,y)
				if candidate.distance_to(player)>185 and not blocked(candidate,radius):pos=candidate;break
	var tier_health=1.0+clampf(float(stage-5)/15.0,0.0,1.0)*0.2
	var health=(35.0+stage*6)*tier_health
	var health_multipliers={"archer":0.55,"swift":0.7,"sentinel":1.65,"assassin":0.9,"chanter":1.1,"hexer":1.0}
	health*=float(health_multipliers.get(kind,1.0))
	if kind=="boss":health=(250+stage*36)*tier_health
	var enemy={"pos":pos,"hp":health,"kind":kind,"cooldown":rng.randf_range(0.5,2.5),"hit":0.0,"phase":rng.randf()*TAU,"dash_hit":false}
	Combat.initialize(enemy,stage)
	enemies.append(enemy)

func blocked(pos: Vector2, radius: float) -> bool:
	if not ARENA.grow(-radius).has_point(pos):return true
	for rect in obstacles:
		if rect.grow(radius).has_point(pos):return true
	return false

func move_actor(pos: Vector2, velocity: Vector2, radius: float) -> Vector2:
	# Sweep in small increments so dashes/frame stalls cannot jump through walls.
	var next=pos
	var steps=maxi(1,int(ceil(velocity.length()/6.0)))
	var step=velocity/steps
	for i in range(steps):
		if not blocked(next+Vector2(step.x,0),radius):next.x+=step.x
		if not blocked(next+Vector2(0,step.y),radius):next.y+=step.y
	return next

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:
			if state=="playing":show_pause()
			elif state=="paused":resume()
		if event.keycode==KEY_SPACE and state=="playing":dash()
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT and state=="playing":dash()

func show_pause():
	state="paused"
	var box=modal("TAKE A BREATHER","Stage %d  ·  Level %d  ·  %d enemies defeated\nRun equipment: %s" % [stage,level,kills, "None" if run_equipment.is_empty() else ", ".join(run_equipment)])
	button(box,"RESUME",resume,Color("416946"))
	button(box,"RETURN TO MENU (ends this run)",show_menu)

func resume():
	clear_panel();state="playing"

func dash():
	if not ClassProgression.try_dash(self):return
	dash_left=ClassProgression.dash_duration(self)
	hurt_cd=maxf(hurt_cd,0.26)
	for enemy in enemies:enemy.dash_hit=false
	beep(550,0.08)

func _process(delta):
	toast_time=maxf(0,toast_time-delta)
	sound_cd=maxf(0,sound_cd-delta)
	if state=="playing":
		# Bound collision steps and stop immediately when a modal interrupts play.
		var remaining=minf(delta,0.25)
		while remaining>0 and state=="playing":
			var step=minf(remaining,1.0/120.0)
			simulate(step)
			remaining-=step
	queue_redraw()

func simulate(dt: float):
	if state!="playing":return
	if hp<=0:end_run(false);return
	healing_flash=maxf(0,healing_flash-dt)
	elapsed+=dt;stage_time+=dt
	ClassProgression.tick(self,dt)
	dash_left=maxf(0,dash_left-dt);hurt_cd=maxf(0,hurt_cd-dt)
	attack_cd-=dt;magic_cd-=dt;bow_cd-=dt;slash_time=maxf(0,slash_time-dt)
	hp=minf(stats.max_hp,hp+stats.regen*dt)
	var direction=Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if direction==Vector2.ZERO and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var distance=screen_to_world(get_global_mouse_position())-player
		if distance.length()>8:direction=distance.normalized()
	if direction.length()>0:facing=direction.normalized()
	var velocity=facing*stats.speed*4.2 if dash_left>0 else direction.normalized()*stats.speed
	var old_player=player
	player=move_actor(player,velocity*dt,12)
	player_moving=player.distance_squared_to(old_player)>0.0001
	update_camera()
	ClassCombat.tick(self,dt,old_player)
	update_waves(dt)
	World.update_hazards(self,dt)
	if hp<=0:end_run(false);return
	if dash_left>0:effects.append({"pos":player,"time":0.2,"color":Color("96f4ff"),"radius":12.0})
	var target=nearest_enemy(player)
	update_player_attacks(dt,target)
	for enemy in enemies:
		update_enemy(enemy,dt)
	if hp<=0:end_run(false);return
	for i in range(bullets.size()-1,-1,-1):
		var b=bullets[i]
		ClassCombat.update_bullet(self,b,dt)
		b.pos+=b.vel*dt;b.life-=dt
		var remove=b.life<=0 or blocked(b.pos,2)
		if not remove:
			if b.friendly:
				for enemy in enemies:
					if enemy.hp>0 and enemy.pos.distance_to(b.pos)<(28 if enemy.kind=="boss" else 17):
						damage_enemy(enemy,b.damage,b.pos);remove=true;break
			elif b.pos.distance_to(player)<14:
				damage_player(b.damage);remove=true
		if remove:bullets.remove_at(i)
		if hp<=0:end_run(false);return
	for i in range(enemies.size()-1,-1,-1):
		var enemy=enemies[i]
		if enemy.hp<=0:
			kills+=1
			if enemy.kind=="herbalist":spawn_potion(enemy.pos)
			gems.append({"pos":enemy.pos,"value":(2.0+floor((stage-1)/5.0))*(12 if enemy.kind=="boss" else 1)})
			effects.append({"pos":enemy.pos,"time":0.35,"color":Color("ffdc89"),"radius":20.0})
			enemies.remove_at(i)
	if hp<=0:end_run(false);return
	for i in range(gems.size()-1,-1,-1):
		var gem=gems[i]
		var distance=gem.pos.distance_to(player)
		if distance<stats.pickup or remaining_enemies()==0:gem.pos=gem.pos.move_toward(player,240*dt)
		if distance<18:gain_xp(gem.value);gems.remove_at(i);beep(900,0.04)
	for i in range(potions.size()-1,-1,-1):
		var potion=potions[i]
		var distance=potion.pos.distance_to(player)
		if distance<stats.pickup or remaining_enemies()==0:potion.pos=potion.pos.move_toward(player,240*dt)
		if potion.pos.distance_to(player)<18:
			heal_player(stats.max_hp*potion.fraction,"POTION %d%%" % roundi(potion.fraction*100))
			potions.remove_at(i);beep(740,0.08)
	for i in range(effects.size()-1,-1,-1):
		effects[i].time-=dt
		if effects[i].time<=0:effects.remove_at(i)
	if hp<=0:end_run(false);return
	if pending_choices>0:
		show_tactics();return
	if remaining_enemies()==0 and gems.is_empty() and potions.is_empty() and not portal_open:
		heal_stage_clear()
		if stage%5==0 and not boss_reward_taken:show_loot();return
		open_portal()
	if portal_open and player.distance_to(CENTER)<28 and stage_time>2:
		if stage>=20:end_run(true)
		else:stage+=1;start_stage()
	update_hud()

func update_enemy(enemy: Dictionary, dt: float):
	if not enemies.has(enemy):return
	if enemy.get("spawn_grace",0)>0:
		enemy.spawn_grace=maxf(0,enemy.spawn_grace-dt);return
	Combat.tick(self,enemy,dt)

func primary_weapon() -> String:
	return D.CLASSES[clampi(selected_class,0,D.CLASSES.size()-1)].weapon

func melee_duration(phase_name: String) -> float:
	return float(ClassCombat.melee_spec(self).get(phase_name,0.12))

func melee_range() -> float:
	return stats.range*float(ClassCombat.melee_spec(self).get("reach",1.0))

func melee_damage() -> float:
	return stats.damage*float(ClassCombat.melee_spec(self).get("damage",1.0))

func aimed_projectile_speed(base_speed: float) -> float:
	return base_speed+maxf(0,stats.range-78.0)

func update_player_attacks(dt: float, target):
	if state!="playing" or hp<=0:return
	var weapon=primary_weapon()
	release_time=maxf(0,release_time-dt)
	bow_release_time=maxf(0,bow_release_time-dt)
	cast_release_time=maxf(0,cast_release_time-dt)
	# Only melee classes enter this state machine. A ranged class never has an
	# invisible sword, even if an old state was left behind by a test/transition.
	if weapon in ["sword","dagger"]:
		var spec=ClassCombat.melee_spec(self)
		if sword_state=="idle":
			if target!=null and attack_cd<=0:
				sword_aim=(target.pos-player).normalized()
				if sword_aim==Vector2.ZERO:sword_aim=facing
				sword_state="windup";sword_time=spec.windup;sword_hits.clear()
				attack_cd=spec.cooldown/maxf(0.3,stats.attack_speed)
		else:
			var was_active=sword_state=="active"
			sword_time=maxf(0,sword_time-dt)
			if was_active and sword_time<=0:sword_state="recover";sword_time=spec.recover
			if sword_state=="windup" and sword_time<=0:
				sword_state="active";sword_time=spec.active
				slash_angle=sword_aim.angle();slash_time=spec.active;beep(310 if weapon=="dagger" else 220,0.025)
			if sword_state=="active":
				for enemy in enemies:
					var relative=enemy.pos-player
					if enemy.hp>0 and not sword_hits.has(enemy) and relative.length()<melee_range() and (relative.length()<1 or spec.cone_dot<=-1 or sword_aim.dot(relative.normalized())>spec.cone_dot):
						sword_hits.append(enemy);damage_enemy(enemy,melee_damage())
			elif sword_state=="recover" and sword_time<=0:sword_state="idle"
	else:
		sword_state="idle";sword_time=0;sword_hits.clear();slash_time=0
	if bow_windup>0:
		bow_windup=maxf(0,bow_windup-dt)
		if bow_windup<=0:
			release_kind="bow";release_time=0.18;bow_release_time=0.18
			for i in range(clampi(int(stats.projectiles),1,4)):
				var spread=(float(i)-float(clampi(int(stats.projectiles),1,4)-1)/2)*0.13
				bullets.append({"pos":player,"vel":bow_aim.rotated(spread)*aimed_projectile_speed(340.0),"life":2.5,"damage":stats.damage*0.9,"friendly":true,"magic":false})
	elif target!=null and (weapon=="bow" or stats.projectiles>=1) and bow_cd<=0:
		bow_cd=(0.85 if weapon=="bow" else 1.4)/maxf(0.4,stats.attack_speed)
		bow_windup=0.2;bow_aim=(target.pos-player).normalized()
		if bow_aim==Vector2.ZERO:bow_aim=facing
	if cast_windup>0:
		cast_windup=maxf(0,cast_windup-dt)
		if cast_windup<=0:
			release_kind="cast";release_time=0.22;cast_release_time=0.22
			if weapon=="staff":
				ClassCombat.release_staff(self)
			else:
				for i in range(8):
					bullets.append({"pos":player,"vel":Vector2.RIGHT.rotated(i*TAU/8)*160,"life":1.6,"damage":stats.damage*(0.15+maxf(0,minf(2,stats.magic)-1)*0.05),"friendly":true,"magic":true})
	elif target!=null and (weapon=="staff" or stats.magic>=1) and magic_cd<=0:
		magic_cd=0.95/maxf(0.5,stats.attack_speed) if weapon=="staff" else 2.3
		cast_windup=0.28;cast_aim=(target.pos-player).normalized()
		if cast_aim==Vector2.ZERO:cast_aim=facing

func nearest_enemy(pos: Vector2):
	var result=null
	var distance=INF
	for e in enemies:
		if e.hp<=0:continue
		var d=pos.distance_squared_to(e.pos)
		if d<distance:distance=d;result=e
	return result

func enemy_shot(pos:Vector2,dir:Vector2,speed:float,damage_multiplier:float=1.0,variant:String="normal"):
	bullets.append({"pos":pos,"vel":dir*speed,"life":5.0,"damage":(7+stage*0.6)*damage_multiplier,"friendly":false,"magic":false,"variant":variant})

func spawn_potion(pos: Vector2):
	# Every herbalist drops one bottle. Small/medium/large odds: 60/30/10%.
	var roll=rng.randf()
	var fraction=0.02 if roll<0.6 else (0.04 if roll<0.9 else 0.06)
	potions.append({"pos":pos,"fraction":fraction})

func heal_player(amount: float, source: String) -> float:
	if hp<=0 or amount<=0:return 0.0
	var restored=minf(amount,maxf(0,stats.max_hp-hp))
	hp+=restored
	if restored>0:
		healing_feedback="%s  +%.1f HP" % [source,restored]
		healing_flash=1.2
	return restored

func heal_stage_clear():
	if stage_clear_healed or hp<=0:return
	stage_clear_healed=true
	heal_player(stats.max_hp*0.1,"ARENA CLEAR")
	update_hud()

func damage_enemy(enemy: Dictionary,damage: float,source:Vector2=Vector2.INF) -> float:
	if enemy.hp<=0 or damage<=0:return 0.0
	if source==Vector2.INF:source=player
	damage*=Combat.incoming_multiplier(enemy,source)
	var dealt=minf(damage,enemy.hp)
	enemy.hp-=dealt;enemy.hit=0.1
	heal_player(dealt*stats.get("lifesteal",0.0),"LIFE DRAIN")
	effects.append({"pos":enemy.pos+Vector2(rng.randf_range(-9,9),-15),"time":0.35,"color":Color("ffffff"),"radius":3.0})
	return dealt

func damage_player(damage:float):
	if state!="playing" or hp<=0 or hurt_cd>0 or dash_left>0:return
	if damage<=0:return
	hp-=ClassProgression.absorb_damage(self,maxf(1,damage-stats.armor));hurt_cd=0.65
	beep(100,0.13)

func needed_xp() -> float:return 6.0+level*3.0

func gain_xp(amount:float):
	xp+=amount
	while xp>=needed_xp():
		xp-=needed_xp();level+=1
		# Equal 3% baseline growth for every active stat; lower cooldown is better.
		for key in stats:
			if key=="lifesteal":continue # Fixed 10% ability, never scaled by leveling.
			if key=="dash_cooldown":stats[key]/=1.03
			else:stats[key]*=1.03
		var bonuses=D.CLASSES[selected_class].stats
		for key in bonuses:stats[key]+=float(bonuses[key])*0.18
		clamp_stats()
		hp=minf(stats.max_hp,hp+12)
		toast("LEVEL %d  ·  Stats +3%%  ·  Class bonus" % level)
		if level%5==0:pending_choices+=1

func clamp_stats():
	for key in D.STAT_LIMITS:
		if stats.has(key):
			var bounds=ClassProgression.stat_bounds(self,key)
			stats[key]=clampf(float(stats[key]),bounds[0],bounds[1])
	hp=minf(hp,stats.max_hp)

func tactic_cap(id: String) -> int:
	for tactic in D.TACTICS:
		if tactic.id==id:return int(tactic.cap)
	return 0

func tactic_rank(id: String) -> int:
	var value=tactic_ranks.get(id,0)
	if not (value is int or value is float):return 0
	if not is_finite(float(value)):return 0
	return clampi(int(value),0,tactic_cap(id))

func available_tactics() -> Array:
	return D.TACTICS.filter(func(u):
		return ClassProgression.eligible(self,u) and tactic_rank(u.id)<tactic_cap(u.id) and (u.id!="life_drain" or stats.get("lifesteal",0.0)<=0) and (ClassProgression.has_effect(self,u) or not effective_tactic_changes(u).is_empty())
	)

func tactic_changes(tactic: Dictionary) -> Dictionary:
	var changes=tactic.stats.duplicate()
	var scales=tactic.get("rank_scales",[])
	if not scales.is_empty():
		var factor=float(scales[mini(tactic_rank(tactic.id),scales.size()-1)])
		for key in changes:changes[key]*=factor
	return changes

func effective_tactic_changes(tactic: Dictionary) -> Dictionary:
	var changes=tactic_changes(tactic)
	var effective={}
	for key in changes:
		var current=float(stats.get(key,0.0))
		var bounds=ClassProgression.stat_bounds(self,key)
		var change=clampf(current+float(changes[key]),bounds[0],bounds[1])-current
		if not is_zero_approx(change):effective[key]=change
	return effective

func apply_tactic(id: String) -> bool:
	if tactic_rank(id)>=tactic_cap(id):return false
	if id=="life_drain" and stats.get("lifesteal",0.0)>0:return false
	for tactic in D.TACTICS:
		if tactic.id==id:
			if not ClassProgression.eligible(self,tactic):return false
			if effective_tactic_changes(tactic).is_empty() and not ClassProgression.has_effect(self,tactic):return false
			var changes=tactic_changes(tactic)
			tactic_ranks[id]=tactic_rank(id)+1
			apply_stats(changes)
			ClassProgression.on_tactic(self,id)
			return true
	return false

func apply_stats(changes:Dictionary):
	for key in changes:
		if key=="lifesteal":stats[key]=0.1 # Unique ability; applying again cannot stack.
		elif stats.has(key):stats[key]+=float(changes[key])
	clamp_stats()
	if changes.has("max_hp"):hp=minf(stats.max_hp,hp+float(changes.max_hp))

func show_tactics():
	if pending_choices<=0:return
	state="tactic"
	var choices=available_tactics()
	# Use the run RNG, so seeded balance and regression tests reproduce choices.
	for i in range(choices.size()-1,0,-1):
		var j=rng.randi_range(0,i)
		var swap=choices[i];choices[i]=choices[j];choices[j]=swap
	# Guarantee one meaningful class branch when available, retaining two hybrid choices.
	for i in range(choices.size()):
		if choices[i].has("classes"):
			var class_choice=choices[i];choices.remove_at(i);choices.push_front(class_choice)
			break
	var box=modal("CHOOSE YOUR TACTIC","LEVEL %d  ·  Choose one randomly offered Tactic
Tactic ranks reset each run. Starting Skills use rank 1; stat limits apply." % level)
	if choices.is_empty():
		button(box,"NO FURTHER TACTICS\nRest: restore 10% maximum HP, then continue.",func():
			heal_player(stats.max_hp*0.1,"MASTERY REST")
			pending_choices=maxi(0,pending_choices-1);clear_panel();state="playing"
		,Color("354868")).custom_minimum_size.y=78
		return
	for i in range(mini(3,choices.size())):
		var tactic=choices[i]
		var changes=effective_tactic_changes(tactic)
		var parts=[]
		for key in changes:
			parts.append("%+.2f %s" % [changes[key],"melee reach / aimed-shot speed" if key=="range" else key.replace("_"," ")])
		var description=tactic.description if tactic.id=="life_drain" or tactic.has("classes") else "Next: " + " / ".join(parts)
		var label=tactic.name + "\nRank %d/%d → %d/%d  ·  " % [tactic_rank(tactic.id),tactic.cap,tactic_rank(tactic.id)+1,tactic.cap] + description
		button(box,label,func():
			if not apply_tactic(tactic.id):return
			if not tactic.id in profile.unlocks:profile.unlocks.append(tactic.id)
			save_profile();pending_choices=maxi(0,pending_choices-1);clear_panel();state="playing"
		,Color("354868")).custom_minimum_size.y=78

func random_equipment() -> Dictionary:
	var names=D.EQUIPMENT_NAMES
	var keys=["damage","max_hp","speed","attack_speed","range","pickup","regen","armor"]
	for i in range(keys.size()-1,0,-1):
		var j=rng.randi_range(0,i)
		var swap=keys[i];keys[i]=keys[j];keys[j]=swap
	var changes={}
	var descriptions=[]
	for i in range(2):
		var key=keys[i]
		var base={"damage":5.0,"max_hp":20.0,"speed":10.0,"attack_speed":0.18,"range":10.0,"pickup":15.0,"regen":0.3,"armor":1.5}[key]
		var value=snappedf(base*rng.randf_range(0.8,1.5)*(1+stage/20.0),0.1)
		changes[key]=value
		descriptions.append("+%s %s" % [str(value),"reach / shot speed" if key=="range" else key.replace("_"," ")])
	return {"name":names[rng.randi_range(0,names.size()-1)],"stats":changes,"description":"   /   ".join(descriptions)}

func show_loot():
	state="loot"
	profile.best_stage=maxi(int(profile.best_stage),stage)
	save_profile()
	var box=modal("CHOOSE YOUR EQUIPMENT","Guardian defeated! Choose one randomized Equipment reward. Bonuses stack within stat limits.\nA new wardrobe color may now be available.")
	for i in range(3):
		var item=random_equipment()
		button(box,item.name+"\n"+item.description,func():
			apply_stats(item.stats);run_equipment.append(item.name)
			if not item.name in profile.equipment:profile.equipment.append(item.name)
			save_profile();boss_reward_taken=true;clear_panel();state="playing"
		,Color("665036")).custom_minimum_size.y=78

func open_portal():
	portal_open=true
	profile.best_stage=maxi(int(profile.best_stage),stage)
	save_profile()
	toast("ARENA CLEAR!  Enter the center portal" if stage<20 else "THE FINAL PORTAL IS OPEN!")

func end_run(won:bool):
	hp=maxf(0,hp)
	state="won" if won else "dead"
	class_fx.clear();trail_patches.clear();bullets.clear();effects.clear()
	dash_left=0
	spawn_queue.clear()
	World.reset_hazards(self)
	update_hud()
	if won:profile.wins+=1;profile.best_stage=20
	save_profile()
	var box=modal("HOME, A HERO." if won else "EVERY OWL RISES AGAIN.","%s\nStage %d  ·  Level %d  ·  %d foes defeated\nDiscovered Skills and Cosmetics stay unlocked for future runs." % ["All twenty arenas conquered!" if won else "Your run ends here. Your discoveries don't.",stage,level,kills])
	button(box,"ONE MORE ADVENTURE",start_run,Color("416946"))
	button(box,"MAIN MENU",show_menu)

func update_hud():
	hud.text="STAGE %02d / 20   %s          LEVEL %02d          %d FOES LEFT" % [stage,str(D.THEMES[mini(3,int((stage-1)/5))].name).to_upper(),level,remaining_enemies()]
	hint.text="HP %d/%d  •  %s  •  %s  •  %s  •  Esc: pause" % [ceil(hp),ceil(stats.max_hp),str(D.CLASSES[selected_class].weapon_label).to_upper(),"DASH %d/%d%s" % [dash_charges,ClassProgression.dash_max(self)," +%.1fs" % dash_recharge if dash_recharge>0 else ""], "ENTER THE CENTER PORTAL" if portal_open else "WASD / hold left mouse: move"]

func toast(text:String):toast_text=text;toast_time=3

func beep(frequency:float,duration:float):
	if test_mode or not profile.sfx or sound_cd>0:return
	sound_cd=0.045
	var stream=AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_8_BITS;stream.mix_rate=22050
	var data=PackedByteArray()
	data.resize(int(duration*22050))
	for i in data.size():
		var envelope=1-float(i)/data.size()
		data[i]=int(128+((1 if sin(i*TAU*frequency/22050)>0 else -1)*25*envelope))
	stream.data=data
	audio.stream=stream;audio.volume_db=linear_to_db(maxf(0.001,float(profile.volume)));audio.play()

func sprite(name:String,pos:Vector2,size:Vector2,color=Color.WHITE):
	if textures.has(name):draw_texture_rect(textures[name],Rect2((pos-size/2).round(),size),false,color)
	else:draw_rect(Rect2(pos-size/2,size),color)

func _draw():
	draw_rect(Rect2(0,0,960,600),Color("10182b"))
	if state=="menu":
		for x in range(0,960,32):
			for y in range(0,600,32):
				if (int(x/32)+int(y/32))%2==0:draw_rect(Rect2(x,y,32,32),Color("152039"))
		return
	var theme=D.THEMES[mini(3,int((stage-1)/5))]
	draw_set_transform(-camera_offset)
	World.draw_floor(self)
	World.draw_hazards(self)
	if portal_open:
		draw_circle(CENTER,33+sin(elapsed*5)*3,Color(0.45,0.9,1,0.15))
		sprite("portal",CENTER,Vector2(64,64))
	for gem in gems:sprite("crystal",gem.pos,Vector2(13,13))
	for potion in potions:
		var tier=roundi(potion.fraction*100)
		draw_circle(potion.pos,13,Color(0.35,1.0,0.65,0.12))
		sprite("potion_%d" % tier,potion.pos+Vector2(0,sin(elapsed*5)*2),Vector2(24,24))
		draw_string(font,potion.pos+Vector2(-10,-16),"%d%%" % tier,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("adffd2"))
	for enemy in enemies:
		if enemy.get("spawn_grace",0)>0:
			draw_arc(enemy.pos,24,0,TAU,20,Color("b9e6ff"),2)
			draw_string(font,enemy.pos+Vector2(-22,-25),"ARRIVING",HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("b9e6ff"))
		else:Combat.draw_cues(self,enemy)
	for enemy in enemies:
		var tint=Color.WHITE
		if enemy.kind=="ghost" and sin(enemy.phase*2)>0 and enemy.get("attack_state","idle")=="idle":tint.a=0.55
		if enemy.hit>0:tint=Color(2,2,2,1)
		var size=Vector2(56,56) if enemy.kind=="boss" else Vector2(32,32)
		draw_ellipse_shadow(enemy.pos,size.x*0.4)
		var phase_name=enemy.get("attack_state","idle")
		if phase_name!="idle":phase_name=enemy.get("attack_pattern","melee")+"_"+phase_name
		var progress=1.0-float(enemy.get("attack_time",0))/maxf(0.01,float(enemy.get("attack_duration",1)))
		Art.draw_actor(self,enemy.kind,enemy.pos,enemy.get("facing",Vector2.RIGHT),enemy.get("moving",false),enemy.phase,phase_name,progress,tint,int(enemy.get("boss_type",0)))
	for b in bullets:
		var color=Color("9dffff") if b.friendly else Color("ff6687")
		if b.magic:color=Color("c796ff")
		if b.get("variant","")=="hex":color=Color("ce91ed")
		if b.get("variant","")=="chant":color=Color("ffc778")
		var direction=b.vel.normalized()
		if b.friendly and not b.magic:
			var side=direction.orthogonal()
			draw_line(b.pos-direction*10,b.pos,color,2)
			draw_line(b.pos,b.pos-direction*4+side*3,Color("f6ffff"),2)
			draw_line(b.pos,b.pos-direction*4-side*3,Color("f6ffff"),2)
		else:
			draw_rect(Rect2(b.pos-Vector2(3,3),Vector2(6,6)),color)
			if b.friendly:
				draw_line(b.pos,b.pos-direction*10,color.darkened(0.2),2)
				draw_rect(Rect2(b.pos-Vector2(1,1),Vector2(2,2)),Color("f8eeff"))
	ClassCombat.draw(self)
	for effect in effects:
		var color=effect.color;color.a=minf(1,effect.time*3)
		draw_arc(effect.pos,effect.radius*(1.5-effect.time),0,TAU,12,color,2)
	var tint=D.COSMETICS[selected_cosmetic].color
	if hurt_cd>0 and profile.shake and sin(elapsed*45)>0:tint.a=0.45
	draw_ellipse_shadow(player,17)
	var weapon=primary_weapon()
	var player_pose="idle"
	var pose_progress=0.0
	var pose_direction=facing
	if weapon in ["sword","dagger"] and sword_state!="idle":
		player_pose=weapon+"_"+sword_state
		pose_progress=1.0-sword_time/melee_duration(sword_state);pose_direction=sword_aim
	elif weapon=="bow":
		if bow_release_time>0:
			player_pose="bow_release";pose_progress=1.0-bow_release_time/0.18;pose_direction=bow_aim
		if bow_windup>0:
			player_pose="bow_windup";pose_progress=1.0-bow_windup/0.2;pose_direction=bow_aim
	elif weapon=="staff":
		if cast_release_time>0:
			player_pose="cast_release";pose_progress=1.0-cast_release_time/0.22;pose_direction=cast_aim
		if cast_windup>0:
			player_pose="cast_windup";pose_progress=1.0-cast_windup/0.28;pose_direction=cast_aim
	if weapon=="dagger" and dash_left>0:
		player_pose="dash";pose_progress=1.0-dash_left/0.18;pose_direction=facing
	Art.draw_actor(self,"owl",player,pose_direction,player_moving,elapsed,player_pose,pose_progress,tint,0,weapon)
	# Every auxiliary has independent feedback, including simultaneous releases.
	# Its art never replaces or disguises the equipped primary weapon.
	if weapon!="bow" and (bow_windup>0 or bow_release_time>0):
		Art.draw_auxiliary(self,player,bow_aim,1.0-bow_windup/0.2 if bow_windup>0 else -1.0,-1.0,"bow",bow_release_time)
	if weapon!="staff" and (cast_windup>0 or cast_release_time>0):
		Art.draw_auxiliary(self,player,cast_aim,-1.0,1.0-cast_windup/0.28 if cast_windup>0 else -1.0,"cast",cast_release_time)
	if healing_flash>0:
		draw_arc(player,26,0,TAU,20,Color(0.5,1,0.65,minf(1,healing_flash)),2)

	if dash_left>0:draw_arc(player,24,0,TAU,16,Color("c8ffff"),2)
	if slash_time>0 and weapon in ["sword","dagger"]:
		var spec=ClassCombat.melee_spec(self)
		var slash_color=Color("b6f5ff") if weapon=="dagger" else Color("fff3b0")
		slash_color.a=clampf(slash_time/spec.active,0.0,1.0)
		var half_angle=acos(float(spec.cone_dot))
		# Outer arc follows the actual damaging reach and cone, not a larger hint.
		draw_arc(player,melee_range(),slash_angle-half_angle,slash_angle+half_angle,18,slash_color,3)
		draw_arc(player,melee_range()*0.72,slash_angle-half_angle,slash_angle+half_angle,14,Color(1,1,1,slash_color.a),2)
	# Reset translation before drawing every screen-space overlay. Mask world at HUD edges.
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(0,0,960,112),Color("10182b"))
	draw_rect(Rect2(0,568,960,32),Color("10182b"))
	draw_rect(Rect2(0,112,32,456),Color("10182b"))
	draw_rect(Rect2(928,112,32,456),Color("10182b"))
	if healing_flash>0:draw_string(font,Vector2(32,100),healing_feedback,HORIZONTAL_ALIGNMENT_LEFT,420,14,Color("a5ffb7"))
	draw_navigation()
	# Named guardians have their own health meter; cues are world-space above.
	for enemy in enemies:
		if enemy.kind!="boss" or enemy.hp<=0:continue
		var boss_type=int(enemy.get("boss_type",0))
		var label=Combat.BOSS_NAMES[boss_type]
		if boss_type==3 and enemy.hp<enemy.get("max_hp",enemy.hp)*0.5:label+="  ·  PHASE II"
		draw_rect(Rect2(320,124,320,31),Color(0.04,0.06,0.1,0.85))
		draw_string(font,Vector2(327,137),label,HORIZONTAL_ALIGNMENT_CENTER,306,11,Color("ffe1a5"))
		draw_rect(Rect2(327,144,306,5),Color("393345"))
		draw_rect(Rect2(327,144,306*clampf(enemy.hp/enemy.get("max_hp",enemy.hp),0,1),5),Color("ef8a85"))
		break
	# HUD: player health, experience and remaining-enemy progress.
	draw_rect(Rect2(32,48,235,12),Color("273348"))
	draw_rect(Rect2(32,48,235*clampf(hp/maxf(1,stats.get("max_hp",100)),0,1),12),Color("ff6584"))
	draw_rect(Rect2(288,48,245,12),Color("273348"))
	draw_rect(Rect2(288,48,245*xp/needed_xp(),12),Color("8be2ee"))
	draw_rect(Rect2(553,48,375,12),Color("273348"))
	draw_rect(Rect2(553,48,375*float(remaining_enemies())/maxi(1,total_enemies),12),Color("ffcf75"))
	draw_string(font,Vector2(32,80),"HEALTH",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("afbdd3"))
	draw_string(font,Vector2(288,80),"EXPERIENCE  %d / %d" % [xp,needed_xp()],HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("afbdd3"))
	draw_string(font,Vector2(553,80),"GROUP %d/%d  ·  %d ACTIVE + %d QUEUED" % [wave_index,wave_count,enemies.size(),spawn_queue.size()],HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("afbdd3"))
	var resource_text = ""
	if selected_class==2:
		draw_rect(Rect2(32,87,150,7),Color("273348"))
		draw_rect(Rect2(32,87,150*shield/maxf(1,ClassProgression.shield_max(self)),7),Color("b5a3ff"))
		resource_text="MANA SHIELD %d/%d  ·  %s" % [ceil(shield),ClassProgression.shield_max(self),"REGEN %.1fs" % shield_delay if shield_delay>0 else "+%d/s" % ClassProgression.shield_regen(self)]
		draw_string(font,Vector2(193,94),resource_text,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("d1c3ff"))
	elif selected_class==1:
		resource_text="TRAP EVADE %d/%d%s  ·  map traps only" % [trap_charges,ClassProgression.trap_max(self),"  +%.1fs" % trap_recharge if trap_recharge>0 else ""]
	elif selected_class==0:
		resource_text="STYLE: " + ("THRUST · narrow / 130%" if tactic_rank("blade_thrust")>0 else ("CLEAVE · half circle / 80%" if tactic_rank("blade_cleave")>0 else ("SWEEP · full circle / 55%" if tactic_rank("blade_sweep")>0 else "FOCUSED SLASH · narrow / 100%")))
	elif selected_class==3:
		resource_text="COMET DASH %.2fs  ·  POISON %d/2  ·  PUSH %d/2" % [ClassProgression.dash_duration(self),tactic_rank("comet_poison"),tactic_rank("comet_push")]
	if selected_class!=2:draw_string(font,Vector2(32,98),resource_text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("c7deff"))
	if toast_time>0 and state=="playing":
		draw_rect(Rect2(200,158,560,27),Color(0.05,0.08,0.14,0.85))
		draw_string(font,Vector2(208,177),toast_text,HORIZONTAL_ALIGNMENT_CENTER,544,15,Color("fff0b3"))

func draw_navigation():
	# Warnings at the viewport edge preserve awareness of off-screen windups.
	for e in enemies:
		if e.hp<=0 or e.get("attack_state","")!="windup":continue
		var at=world_to_screen(e.pos)
		if VIEW.grow(-16).has_point(at):continue
		at=at.clamp(VIEW.position+Vector2(14,16),VIEW.end-Vector2(14,16))
		draw_circle(at,10,Color("efaa65"))
		draw_string(font,at+Vector2(-3,5),"!",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("271f2b"))
	# Small whole-arena map makes the expanded space legible without hiding action.
	var box=Rect2(42 if world_to_screen(player).x>740 and world_to_screen(player).y>440 else 816,465,102,91)
	draw_rect(box,Color(0.04,0.06,0.1,0.8))
	var scale_map=Vector2(94.0/ARENA.size.x,70.0/ARENA.size.y)
	var origin=box.position+Vector2(4,15)
	draw_string(font,box.position+Vector2(4,11),"ARENA",HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("afbdd3"))
	for rect in obstacles:draw_rect(Rect2(origin+(rect.position-ARENA.position)*scale_map,rect.size*scale_map),Color("657181"))
	for e in enemies:draw_circle(origin+(e.pos-ARENA.position)*scale_map,2,Color("ff8b89"))
	if portal_open:draw_circle(origin+(CENTER-ARENA.position)*scale_map,3,Color("95f6ff"))
	draw_rect(Rect2(origin+(camera_offset)*scale_map,VIEW.size*scale_map),Color("8d9dad"),false,1)
	draw_circle(origin+(player-ARENA.position)*scale_map,2.5,Color("fff1b0"))
	if portal_open:
		var screen_center=world_to_screen(CENTER)
		if not VIEW.grow(-36).has_point(screen_center):
			var at=screen_center.clamp(VIEW.position+Vector2(30,30),VIEW.end-Vector2(30,30))
			draw_circle(at,12,Color("83e8ff"))
			draw_string(font,at+Vector2(-5,5),"P",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("10182b"))

func draw_ellipse_shadow(pos:Vector2,radius:float):
	draw_rect(Rect2(pos+Vector2(-radius,12),Vector2(radius*2,6)),Color(0,0,0,0.2))

func self_test():
	var failures=[]
	start_run()
	if remaining_enemies()!=13 or enemies.size()!=4:failures.append("stage 1 grouped population")
	for enemy in enemies:
		if enemy.pos.distance_to(player)<180:failures.append("safe spawn")
	var old_level=level
	gain_xp(100)
	if level<=old_level:failures.append("XP progression")
	dash();var before=hp;damage_player(100)
	if hp!=before:failures.append("dash invulnerability")
	for number in range(1,21):
		stage=number;start_stage()
		var bosses=0;var ranged=0
		for enemy in enemies:
			if enemy.kind=="boss":bosses+=1
			if enemy.kind=="archer":ranged+=1
		for kind in spawn_queue:
			if kind=="boss":bosses+=1
			if kind=="archer":ranged+=1
		if bosses!=(1 if number%5==0 else 0):failures.append("boss stage %d"%number)
		if ranged==0:failures.append("ranged stage %d"%number)
		for i in range(20):simulate(1.0/60)
		if number%5==0:
			var item=random_equipment()
			if item.stats.size()!=2:failures.append("equipment generation")
	stage=20;end_run(true)
	if state!="won":failures.append("victory")
	start_run();end_run(false)
	if state!="dead":failures.append("death")
	start_run()
	if stage!=1 or level!=1 or not run_equipment.is_empty():failures.append("run reset")
	show_pause();resume()
	if state!="playing":failures.append("pause resume")
	# Exercise all three actual choice callbacks, loot, portal, and unlock paths.
	for choice_index in range(3):
		start_run();level=5;pending_choices=1;show_tactics()
		var choice_box=panel.get_child(1)
		choice_box.get_child(2+choice_index).pressed.emit()
		if state!="playing" or pending_choices!=0:failures.append("tactic callback")
		if profile.unlocks.is_empty():failures.append("persistent discovery")
		stage=5;start_stage();enemies.clear();spawn_queue.clear();gems.clear();simulate(0.01)
		if state!="loot":failures.append("boss reward transition")
		panel.get_child(1).get_child(2+choice_index).pressed.emit()
		if not boss_reward_taken or run_equipment.size()!=1:failures.append("loot callback")
		stage_time=0;simulate(0.01)
		if not portal_open:failures.append("portal opens")
		stage_time=3;player=CENTER;simulate(0.01)
		if stage!=6:failures.append("portal advances")
	start_run();stage=20;start_stage();enemies.clear();spawn_queue.clear();gems.clear();boss_reward_taken=true;stage_time=3;simulate(0.01)
	if state!="won":failures.append("stage20 portal victory")
	print("SELF_TEST: ","PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
