extends "res://main.gd"
# Optional save-disabled SEEDED QA scene. NEVER the shipped default main scene.
# 1..4 guardians; G regular actors; H four-weapon gallery; Q actual player build.
# T/Y/U/I/W windup/active/recover/idle/walk; B next boss move; F live simulation.
var qa_frozen=true
var qa_mode=0
var qa_pose="windup"
var qa_weapon_names=["sword","bow","staff","dagger"]
func _ready():
	test_mode=true
	super._ready()
	profile.sfx=false
	selected_skill=""
	start_run()
	setup_qa(0)
func setup_qa(mode:int):
	qa_mode=mode;stage=(mode+1)*5 if mode<4 else (20 if mode==4 else 1)
	rng.seed=5052026+mode
	start_stage();obstacles.clear();enemies.clear();spawn_queue.clear();bullets.clear();gems.clear();potions.clear()
	World.reset_hazards(self);world_data.hazards_enabled=false
	player=Vector2(600,350);facing=Vector2.LEFT;hp=stats.max_hp;hurt_cd=0
	if mode<4:
		spawn_enemy("boss");enemies[0].pos=Vector2(365,350);enemies[0].cooldown=0
	elif mode==4:
		var kinds=["grunt","swift","archer","bomber","ghost","herbalist","sentinel","assassin","chanter","hexer"]
		for i in range(kinds.size()):
			spawn_enemy(kinds[i]);enemies[-1].pos=Vector2(145+(i%5)*165,235+int(i/5)*185);enemies[-1].cooldown=0
		player=Vector2(480,525)
	else:player=Vector2(480,530)
	total_enemies=enemies.size();toast_time=0;update_camera()
	pose("windup")
func pose(which:String):
	qa_pose=which
	slash_time=0;bow_windup=0;cast_windup=0;release_time=0;bow_release_time=0;cast_release_time=0
	for e in enemies:
		if which=="windup":Combat.begin(self,e);e.attack_time=e.attack_duration*0.5
		elif which=="active":Combat.release(self,e);e.attack_time=e.attack_duration*0.5
		else:e.attack_state=which;e.attack_time=0.2;e.attack_duration=0.4
		e.moving=which=="walk"
		if which=="walk":e.attack_state="idle"
	player_moving=which=="walk";sword_state="idle";sword_time=0.06;sword_aim=Vector2.LEFT;bow_aim=Vector2.LEFT;cast_aim=Vector2.LEFT
	if selected_class in [0,3]:
		sword_state="idle" if which in ["idle","walk"] else which
		if which=="active":slash_time=0.1;slash_angle=PI
	elif selected_class==1:
		if which=="windup":bow_windup=0.1
		if which=="active":release_kind="bow";release_time=0.12;bow_release_time=0.12
	elif selected_class==2:
		if which=="windup":cast_windup=0.14
		if which=="active":release_kind="cast";release_time=0.12;cast_release_time=0.12
	update_hud();queue_redraw()
func _process(delta):
	if not qa_frozen:super._process(delta)
	else:queue_redraw()
	hint.text="SEEDED QA  |  1-4 bosses · G enemies · H weapons · Q build · B move · T/Y/W poses · F live"
func _draw():
	super._draw()
	if font==null:return
	if qa_mode==5:
		var phases=["idle","windup","active"]
		for row in range(3):
			for col in range(4):
				var at=Vector2(180+col*200,230+row*100)
				var weapon=qa_weapon_names[col]
				var prefix="cast" if weapon=="staff" else weapon
				var phase=phases[row]
				var actor_pose="idle" if phase=="idle" else prefix+"_"+("release" if phase=="active" and col in [1,2] else phase)
				Art.draw_actor(self,"owl",at,Vector2.RIGHT,row==0,elapsed,actor_pose,0.5,Color.WHITE,0,weapon)
				draw_string(font,at+Vector2(-72,43),["Blade · sword","Ranger · bow","Weaver · staff","Strider · dagger"][col]+" / "+phase,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("ffe1a5"))
	elif qa_mode==4:
		for e in enemies:draw_string(font,world_to_screen(e.pos)+Vector2(-35,62),e.kind,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("ffe1a5"))
	else:
		for e in enemies:
			draw_string(font,Vector2(310,190),e.attack_pattern.to_upper().replace("_"," ")+" · "+e.attack_state,HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("ffe1a5"))
func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1,KEY_2,KEY_3,KEY_4:setup_qa(event.keycode-KEY_1)
			KEY_G:setup_qa(4)
			KEY_H:setup_qa(5)
			KEY_Q:
				selected_class=(selected_class+1)%4;start_run();setup_qa(qa_mode)
			KEY_T:pose("windup")
			KEY_Y:pose("active")
			KEY_U:pose("recover")
			KEY_I:pose("idle")
			KEY_W:elapsed+=0.14;pose("walk");for e in enemies:e.phase+=0.14
			KEY_F:qa_frozen=not qa_frozen
			KEY_B:
				for e in enemies:Combat.begin(self,e)
			KEY_O:pose("idle");bow_windup=0.1;bow_aim=Vector2.LEFT
			KEY_C:pose("idle");cast_windup=0.14
			KEY_R:pose("active");release_kind="both";release_time=0.12
			KEY_P:
				for e in enemies:e.hp=e.max_hp*0.4
			_:super._unhandled_input(event)
