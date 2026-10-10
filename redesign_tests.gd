extends SceneTree
const STEP=1.0/120.0
var game
var passed=0
var failures=[]
func _initialize():call_deferred("run")
func check(ok:bool,message:String):
	if ok:passed+=1
	else:failures.append(message);print("FAIL: ",message)
func near(a:float,b:float)->bool:return absf(a-b)<0.001
func fresh(cls:int=0,option:String=""):
	game.selected_class=cls;game.selected_option=option;game.rng.seed=888
	game.start_run();game.enemies.clear();game.spawn_queue.clear();game.bullets.clear()
	game.obstacles.clear();game.gems.clear();game.potions.clear();game.effects.clear()
	game.World.reset_hazards(game);game.world_data.hazards_enabled=false
	game.stats.regen=0;game.stats.critical_rate=0;game.stats.dodge_rate=0;game.stats.block_rate=0
	game.attack_cd=0;game.bow_cd=0;game.magic_cd=0;game.hurt_cd=0
	game.stage_time=0;game.portal_open=false
func foe(offset:Vector2=Vector2(40,0),health:float=1000)->Dictionary:
	game.spawn_enemy("grunt")
	var e=game.enemies.back()
	e.pos=game.player+offset;e.hp=health;e.max_hp=health;e.cooldown=99;e.spawn_grace=99
	return e
func attacks(seconds:float):
	for i in range(ceili(seconds/STEP)):
		game.attack_cd-=STEP;game.bow_cd-=STEP;game.magic_cd-=STEP
		game.update_player_attacks(STEP,game.nearest_enemy(game.player))
func click_first():
	var found=[]
	for child in game.panel.find_children("*","Button",true,false):found.append(child)
	if found.is_empty():check(false,"choice panel has a button");return
	found[0].pressed.emit()
func run():
	game=load("res://main.tscn").instantiate();game.test_mode=true
	root.add_child(game);game.set_process(false)
	var expected=[130,90,55,85]
	var cooldowns=[3,3,4,2]
	for cls in range(4):
		for option in game.D.CLASSES[cls].options:
			fresh(cls,option)
			check(game.hp==expected[cls],"starting HP "+option)
			check(game.stats.dodge_cooldown==cooldowns[cls],"starting Dodge cooldown "+option)
			check(game.selected_option==option,"starting option "+option)
			check(game.available_tactics().size()>=30,"eligible Tactic breadth "+option)
			for s in game.PlayerSkills.available(game):
				check(game.D.CLASSES[cls].id in s.classes,"no other Class Skill")
			var e=foe(Vector2(35,0))
			attacks(0.55 if option in ["knife","dagger"] else 1.0)
			if cls==2 or option in ["bow","crossbow","gun","throwing_knife"]:
				check(not game.bullets.is_empty(),"ranged release "+option)
				for bullet in game.bullets:
					check(bullet.get("weapon","") in [game.primary_weapon(),"staff"],"no auxiliary weapon")
			else:check(e.hp<1000,"melee hit "+option)
		fresh(cls)
		var old=game.stats.duplicate()
		game.gain_xp(game.needed_xp())
		check(game.level==2,"one level growth")
		check(game.stats.critical_rate==old.critical_rate if cls!=3 else game.stats.critical_rate>old.critical_rate,"specialty growth")
		game.stats.dodge_rate=2;game.stats.block_rate=2;game.stats.dodge_cooldown=0
		game.clamp_stats()
		check(near(game.stats.dodge_rate,.7) and near(game.stats.block_rate,.9),"probability caps")
		check(game.stats.dodge_cooldown==(1 if cls==3 else 2),"cooldown floor")
	fresh()
	var e=foe()
	game.stats.critical_rate=1;game.stats.critical_damage=.5
	check(near(game.damage_enemy(e,20),30),"critical 150 percent")
	check(near(game.damage_enemy(e,20,Vector2.INF,false,false),20),"DOT does not crit")
	fresh();game.stats.dodge_rate=1;game.stats.block_rate=1
	game.damage_player(40)
	check(game.hp==130 and game.dodge_recovery==3,"Dodge prevents full damage and starts recovery")
	game.damage_player(40)
	check(game.hp==110,"Block rolls during Dodge cooldown")
	game.hurt_cd=0;game.dodge_recovery=0
	game.damage_player(20,"trap")
	check(game.hp==90 and game.dodge_recovery==0,"traps bypass probability")
	game.hurt_cd=0;game.damage_player(10,"dot")
	check(game.hp==80,"DOT bypasses probability")
	fresh();game.stats.dodge_rate=1;game.stats.block_rate=1
	e=foe(Vector2.ZERO);e.kind="boss";e.spawn_grace=0;e.attack_pattern="blast";e.attack_state="active"
	e.attack_target=game.player;e.attack_duration=.18;e.attack_time=.18
	game.update_enemy(e,0)
	check(near(game.hp,112.3) and game.dodge_recovery==0,"boss ground fire bypasses Dodge and Block through actual attack path")
	fresh(2);game.stats.dodge_rate=0;game.stats.block_rate=1;game.stats.armor=3
	game.damage_player(40)
	check(near(game.shield,3) and game.hp==55,"Block then Armor then Mage Armor")
	game.hurt_cd=0;game.damage_player(20,"projectile")
	check(game.shield==0 and game.hp==51,"remaining damage reaches HP")
	game.ClassProgression.tick(game,3)
	check(game.shield==0,"Mage Armor delay")
	game.ClassProgression.tick(game,2)
	check(near(game.shield,5),"Mage Armor starts recharge after four seconds")
	fresh()
	check(not game.learn_skill("melee_extra_attack_2"),"upgrade requires I")
	check(not game.learn_skill("mage_spread_1"),"reject other Class")
	check(game.learn_skill("melee_extra_attack_1"),"learn Extra Attack I")
	check(not game.learn_skill("melee_extra_attack_1"),"never learn duplicate")
	e=foe(Vector2(40,0));attacks(.6)
	check(near(1000-e.hp,36),"two full-damage swings")
	check(game.learn_skill("melee_extra_attack_2"),"learn Extra Attack II")
	check(game.active_skill_rank("extra_attack")==2 and game.skill_choices_taken==2,"II replaces I and counts choice")
	check(game.learn_skill("melee_shockwave_1"),"learn weapon-specific Skill")
	check(game.apply_tactic("switch_melee_knife"),"switch via Tactic")
	check(game.active_skill_rank("shockwave")==0 and "melee_shockwave_1" in game.learned_skills,"incompatible Skill dormant")
	check(game.apply_tactic("switch_melee_sword") and game.active_skill_rank("shockwave")==1,"switch restores Skill")
	while game.skill_choices_taken<5:
		var choices=game.PlayerSkills.available(game)
		check(not choices.is_empty(),"enough eligible Skills for five rewards")
		if choices.is_empty():break
		game.learn_skill(choices[0].id)
	check(game.PlayerSkills.available(game).is_empty(),"Skill selection cap five")
	fresh(3,"throwing_knife");game.learn_skill("dash_poison_1");game.learn_skill("dash_poison_2");game.learn_skill("dash_bleed_1")
	e=foe(Vector2(100,0),10000)
	for i in range(10):game.damage_enemy(e,10,e.pos,true,true,"","throwing_knife")
	check(near(10000-e.hp,100),"knife direct damage retained")
	check(e.poison_stacks==5 and e.bleed_stacks==3,"bounded separate DOT stacks")
	var before=e.hp;game.PlayerEffects.tick(game,.5)
	check(e.hp<before and e.poison_left>0 and e.bleed_left>0,"poison and bleed coexist")
	var timer=e.poison_tick;game.damage_enemy(e,1,e.pos)
	check(e.poison_tick==timer and e.poison_left==3,"refresh preserves DOT cadence")
	game.PlayerEffects.tick(game,3)
	check(e.poison_stacks==0 and e.bleed_stacks==0,"DOT expires")
	fresh();game.stats.max_hp=500;game.stats.damage=120;game.hp=500
	for tactic in game.D.TACTICS:game.tactic_ranks[tactic.id]=tactic.cap
	game.pending_choices=1;game.show_tactics();click_first()
	check(game.stats.max_hp==510 and game.stats.damage==121 and game.pending_choices==0,"exhaustion fallback increases basic stats beyond ordinary caps")
	check(game.stats.dodge_rate==0 and game.stats.dodge_cooldown==3,"exhaustion does not alter rates or cooldowns")
	for element in ["fire","ice","lightning","light"]:
		fresh(2,element);e=foe(Vector2(100,0));var other=foe(Vector2(140,0))
		game.damage_enemy(e,10,game.player,true,true,element,"staff")
		match element:
			"fire":check(e.get("burn_left",0)>0,"Fire burn")
			"ice":check(e.get("slow_factor",1)<1,"Ice slow")
			"lightning":check(other.hp<1000,"Lightning chains")
			"light":
				game.cast_aim=Vector2.RIGHT;game.ClassCombat.release_staff(game)
				check(game.bullets[0].pierce>=2,"Light pierces")
	fresh(2,"lightning");game.stats.critical_rate=1
	e=foe(Vector2(100,0),1);var chained=foe(Vector2(140,0))
	game.rng.seed=888
	game.damage_enemy(e,20,game.player,true,true,"lightning","staff")
	check(near(chained.hp,988),"chain rolls its own Crit without inheriting first Crit or overkill")
	# Exercise ordinary and boss reward panels through their real Button signals.
	fresh();game.stage=5;game.skill_reward_taken=false;game.boss_reward_taken=false
	game.simulate(.01)
	check(game.state=="skill","boss Skill panel first")
	click_first();game.simulate(.01)
	check(game.state=="loot","Equipment separate after Skill")
	click_first();game.simulate(.01)
	check(game.portal_open and game.skill_choices_taken==1 and game.run_equipment.size()==1,"boss rewards settle before portal")
	fresh();game.stage=30;game.stage_time=3;game.skill_choices_taken=5
	game.simulate(.01);game.simulate(.01)
	check(game.state=="loot","sixth boss Equipment without sixth Skill")
	click_first();game.simulate(.01)
	check(game.state=="won","stage thirty victory")
	# Real file IO uses a dedicated sandbox path, never the player's live saves.
	fresh(3,"dagger");game.allow_checkpoint_io=true
	game.checkpoint_path="res://redesign-test-checkpoint.json"
	game.stage=5;game.learn_skill("dash_poison_1");game.boss_reward_taken=true;game.skill_reward_taken=true
	game.run_equipment=["Dewdrop Blade"];game.hp=60;game.pending_choices=1
	check(not game.RunCheckpoint.save(game),"do not save unresolved rewards")
	game.pending_choices=0
	check(game.RunCheckpoint.save(game),"write local checkpoint")
	var data=game.RunCheckpoint.read(game)
	check(not data.is_empty() and data.learned_skills.size()==1,"read valid checkpoint")
	var previous_damage=game.stats.damage
	game.stage=6;game.hp=55
	check(game.RunCheckpoint.save(game),"overwrite latest checkpoint")
	game.stage=7;game.start_stage()
	var expected_walls=str(game.obstacles);var expected_spawn=game.enemies[0].pos
	game.selected_class=0;game.selected_option="sword";game.start_run()
	check(game.RunCheckpoint.restore(game),"restore checkpoint")
	check(game.stage==7 and game.selected_class==3 and game.hp==55 and game.stats.damage==previous_damage,"resume next stage and same build")
	check(game.skill_choices_taken==1 and game.active_skill_rank("poison")==1 and game.run_equipment.size()==1,"resume Skill and Equipment counters")
	check(str(game.obstacles)==expected_walls and game.enemies[0].pos==expected_spawn,"checkpoint retains RNG and next-stage generation")
	var corrupt=game.RunCheckpoint.read(game)
	corrupt.learned_skills=["mage_spread_1"]
	var file=FileAccess.open(game.checkpoint_path,FileAccess.WRITE);file.store_string(JSON.stringify(corrupt));file.close()
	check(game.RunCheckpoint.read(game).is_empty(),"invalid cross-Class checkpoint rejected")
	game.RunCheckpoint.complete(game)
	check(not FileAccess.file_exists(game.checkpoint_path),"completion removes checkpoint")
	game.allow_checkpoint_io=false
	# Both new bosses have distinct patterns and reachable, honestly drawn geometry.
	for number in [25,30]:
		fresh();game.stage=number;game.start_stage();game.enemies.clear();game.spawn_enemy("boss")
		var boss=game.enemies[0]
		check(boss.boss_type==number/5-1,"new boss type")
		var patterns=game.Combat.boss_patterns(boss)
		check(patterns.size()>=4,"new boss move set")
		for pattern in patterns:
			boss.attack_pattern=pattern;boss.attack_origin=game.CENTER;boss.attack_target=game.CENTER+Vector2(130,0);boss.attack_aim=Vector2.RIGHT
			boss.attack_duration=1;boss.attack_time=.5
			for shape in game.Combat.attack_shapes(boss,true):
				check(shape.has("type"),"new boss preview shape")
		check(game.Combat.movement_speed(boss,30)>game.Combat.movement_speed(boss,20),"difficulty scales past twenty")
		if number==25:
			boss.attack_index=2;game.Combat.select_reachable_boss_pattern(boss,300)
			check(game.Combat.next_pattern(boss)!="storm_sweep","Tempest does not stall on an out-of-range sweep")
	# Every offered Skill has a real implemented effect; prerequisites stay satisfiable.
	for cls in range(4):
		for option in game.D.CLASSES[cls].options:
			fresh(cls,option)
			for i in range(5):
				var choices=game.PlayerSkills.available(game)
				check(not choices.is_empty(),"five compatible choices "+option)
				if not choices.is_empty():check(game.learn_skill(choices[0].id),"learn compatible choice "+option)
	print("REDESIGN: ",passed," passed, ",failures.size()," failed")
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
