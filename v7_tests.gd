extends SceneTree

# These isolated fixtures inject state to test rules, not balance outcomes.
# balance_simulation_v7.gd separately measures unmodified actual combat.
const STEP = 1.0/120.0
const BRANCHES = [
	["blade_thrust","blade_cleave","blade_sweep"],
	["ranger_rapid","ranger_fan","ranger_evasion"],
	["moon_spread","moon_radial","moon_fire","moon_familiar","moon_ward"],
	["comet_echo","comet_length","comet_poison","comet_push"],
]
var game
var passed = 0
var failures: Array[String] = []
func _initialize():call_deferred("run_tests")
func check(condition: bool,message: String):
	if condition:passed+=1;print("PASS: ",message)
	else:failures.append(message);print("FAIL: ",message)
func near(a: float,b: float) -> bool:return absf(a-b)<0.001
func fresh(build: int=0,ability: String=""):
	game.selected_class=build;game.selected_skill=ability
	game.profile.unlocks=[]
	if ability!="":game.profile.unlocks.append(ability)
	game.start_run()
	game.enemies.clear();game.spawn_queue.clear();game.bullets.clear()
	game.obstacles.clear();game.gems.clear();game.potions.clear();game.effects.clear()
	game.World.reset_hazards(game);game.world_data.hazards_enabled=false
	game.player=game.CENTER;game.facing=Vector2.RIGHT
	game.stats.regen=0.0;game.stats.armor=0.0
	game.attack_cd=99;game.bow_cd=99;game.magic_cd=99;game.hurt_cd=0
	game.portal_open=false;game.stage_time=0
func enemy_at(offset: Vector2,health: float=1000.0) -> Dictionary:
	game.spawn_enemy("grunt")
	var enemy=game.enemies.back()
	enemy.pos=game.player+offset;enemy.hp=health;enemy.max_hp=health
	enemy.cooldown=99.0;enemy.spawn_grace=99.0
	return enemy
func attack_steps(duration: float):
	var remaining=duration
	while remaining>0.000001:
		var dt=minf(STEP,remaining)
		game.update_player_attacks(dt,game.nearest_enemy(game.player));remaining-=dt
func upgrade_ids() -> Array:
	var ids=[]
	for upgrade in game.available_tactics():ids.append(upgrade.id)
	return ids
func run_tests():
	seed(7007)
	game=load("res://main.tscn").instantiate();game.test_mode=true
	root.add_child(game);game.set_process(false)
	game.profile.sfx=false;game.profile.shake=false
	test_class_eligibility();test_starting_selection();test_offer_and_stack_caps()
	test_melee_shapes();test_moon_projectiles();test_fire_and_familiar()
	test_poison_and_push();test_shield();test_charges_and_timing()
	test_ranger();test_dash_hit_integration();test_lifecycle()
	print("V7_TESTS: ",passed," passed; ",failures.size()," failed")
	for failure in failures:print(" - ",failure)
	game.free();quit(0 if failures.is_empty() else 1)
func test_class_eligibility():
	for build in range(4):
		fresh(build)
		var offered=upgrade_ids()
		for owner in range(4):
			for id in BRANCHES[owner]:
				check((id in offered)==(owner==build),"Class %d offers %s only to its owning class"%[build,id])
				if owner!=build:
					var before=game.stats.duplicate(true)
					check(not game.apply_tactic(id) and game.tactic_rank(id)==0 and game.stats==before,"Class %d rejects wrong-class %s without side effects"%[build,id])
		check(not game.apply_tactic("unknown_upgrade"),"Class %d safely rejects unknown upgrades"%build)
	for style in BRANCHES[0]:
		fresh(0)
		check(game.apply_tactic(style),"Melee accepts chosen style "+style)
		for other in BRANCHES[0]:check(not game.apply_tactic(other) and other not in upgrade_ids(),"Chosen %s rejects/removes %s repeats or competing styles"%[style,other])
func test_starting_selection():
	for build in range(4):
		fresh(build,BRANCHES[(build+1)%4][0])
		check(game.selected_skill=="" and game.tactic_ranks.is_empty(),"Class %d clears a persistent starting skill belonging to another class"%build)
		var ability=BRANCHES[build][0]
		fresh(build,ability)
		check(game.selected_skill==ability and game.tactic_rank(ability)==1,"Class %d consumes one legal starting rank of %s"%[build,ability])
		game.start_run();check(game.tactic_rank(ability)==1,"Class %d restarts without accumulating starting ranks"%build)
	fresh(2)
	check(near(game.hp,70) and near(game.stats.max_hp,70),"Moon Weaver begins at 70 health")
	check(near(game.shield,35),"Moon Weaver begins with a distinct 35-point shield")
	for build in [0,1,3]:
		fresh(build);check(near(game.hp,100) and near(game.shield,0),"Class %d preserves 100 HP and has no mana shield"%build)
func test_offer_and_stack_caps():
	for build in range(4):
		fresh(build);game.pending_choices=1;game.level=5;game.show_tactics()
		var class_offer=false
		var buttons=0
		for child in game.panel.get_child(1).get_children():
			if not child is Button:continue
			buttons+=1
			for upgrade in game.D.TACTICS:
				if child.text.begins_with(upgrade.name) and upgrade.id in BRANCHES[build]:class_offer=true
		check(buttons==3 and class_offer,"Class %d level-five modal offers three choices including a class branch"%build)
		game.clear_panel();game.state="playing";game.pending_choices=0
		for upgrade in game.D.TACTICS:
			for repeat in range(int(upgrade.cap)+5):game.apply_tactic(upgrade.id)
		var ranks=game.tactic_ranks.duplicate(true)
		var stats=game.stats.duplicate(true)
		for upgrade in game.D.TACTICS:game.apply_tactic(upgrade.id)
		check(game.tactic_ranks==ranks and game.stats==stats,"Class %d repeated upgrade requests stop changing capped ranks and stats"%build)
		var limits=true
		for key in game.D.STAT_LIMITS:
			var bounds=game.ClassProgression.stat_bounds(game,key)
			limits=limits and is_finite(float(game.stats[key])) and game.stats[key]>=bounds[0] and game.stats[key]<=bounds[1]
		check(limits and game.stats.lifesteal<=0.1,"Class %d max-stack obeys every effective stat bound and Life Drain limit"%build)
		var wrong_rank=false
		for owner in range(4):
			if owner==build:continue
			for id in BRANCHES[owner]:wrong_rank=wrong_rank or game.tactic_rank(id)>0
		check(not wrong_rank,"Class %d max-stack cannot acquire another class branch"%build)
		var maximum={}
		for key in game.D.STAT_LIMITS:maximum[key]=10000.0 if key!="dash_cooldown" else -10000.0
		game.apply_stats(maximum)
		check(game.available_tactics().is_empty(),"Class %d hides no-op offers after compatible branches and stat ceilings are exhausted"%build)
		game.pending_choices=1;game.hp=game.stats.max_hp*0.5;game.show_tactics()
		var rest=null
		for child in game.panel.get_child(1).get_children():
			if child is Button:rest=child
		check(rest!=null and "NO FURTHER TACTICS" in rest.text,"Class %d exhausted modal has a mastery-rest fallback"%build)
		if rest!=null:rest.pressed.emit()
		check(game.state=="playing" and game.pending_choices==0,"Class %d mastery rest consumes the choice without softlocking"%build)
func test_melee_shapes():
	var cases=[
		{"id":"","hit":[true,false,false],"range":1.0,"damage":1.0,"cooldown":0.85},
		{"id":"blade_thrust","hit":[true,false,false],"range":1.3,"damage":1.3,"cooldown":0.9},
		{"id":"blade_cleave","hit":[true,true,false],"range":1.0,"damage":0.8,"cooldown":0.85},
		{"id":"blade_sweep","hit":[true,true,true],"range":0.9,"damage":0.55,"cooldown":0.85}]
	for spec in cases:
		fresh(0,spec.id)
		var front=enemy_at(Vector2(40,0))
		var side=enemy_at(Vector2(20,35))
		var rear=enemy_at(Vector2(-40,0))
		game.attack_cd=0;game.update_player_attacks(0,front)
		var label="normal" if spec.id=="" else spec.id
		check(game.sword_state=="windup" and near(front.hp,1000),label+" anticipates before damage")
		check(near(game.attack_cd,spec.cooldown/game.stats.attack_speed),label+" uses its explicit cooldown")
		attack_steps(0.125)
		var targets=[front,side,rear]
		for i in range(targets.size()):check((targets[i].hp<1000)==spec.hit[i],"%s geometry target %d matches its selected arc"%[label,i])
		check(near(front.hp,1000-game.stats.damage*spec.damage) and near(game.melee_range(),game.stats.range*spec.range),label+" applies its area/damage/reach tradeoff")
		var before=front.hp
		attack_steps(0.04);check(near(front.hp,before),label+" hits each target only once per swing")
	fresh(0,"blade_thrust")
	var far=enemy_at(Vector2(95,0))
	game.attack_cd=0;game.update_player_attacks(0,far);attack_steps(0.125)
	check(far.hp<1000,"Thrust reaches beyond the normal 78-pixel range")
	fresh(0)
	var diagonal=enemy_at(Vector2(35,15))
	var outside=enemy_at(Vector2(35,30))
	game.sword_state="active";game.sword_time=0.1;game.sword_aim=Vector2.RIGHT
	game.update_player_attacks(0,diagonal)
	check(diagonal.hp<1000 and near(outside.hp,1000),"Base slash uses a narrow forward cone")
func test_moon_projectiles():
	for rank in range(3):
		fresh(2)
		for i in range(rank):game.apply_tactic("moon_spread")
		var target=enemy_at(Vector2(200,0))
		game.magic_cd=0;game.update_player_attacks(0,target);attack_steps(0.275)
		check(game.bullets.is_empty(),"Moon spread rank %d preserves full staff anticipation"%rank)
		attack_steps(0.01)
		var count=1+2*rank
		var damage=0.0
		var homing=true
		for b in game.bullets:damage+=b.damage;homing=homing and near(b.homing,2.8) and b.class_kind=="moon"
		check(game.bullets.size()==count and homing,"Moon spread rank %d emits %d bounded-homing bolts"%[rank,count])
		check(near(damage,game.stats.damage*1.1*[1.0,1.35,1.65][rank]),"Moon spread rank %d splits a bounded total volley"%rank)
		var bolt=game.bullets[0]
		var speed=bolt.vel.length();var before=bolt.vel.angle()
		target.pos=bolt.pos+Vector2(0,200);game.ClassCombat.update_bullet(game,bolt,0.1)
		check(absf(wrapf(bolt.vel.angle()-before,-PI,PI))<=0.2801 and near(bolt.vel.length(),speed),"Moon spread rank %d turns within 2.8 rad/s without speed gain"%rank)
		if rank>0:
			check(near(bolt.vel.angle(),before),"Spread fan stays straight during its 0.12-second readable launch")
			game.ClassCombat.update_bullet(game,bolt,0.1)
			check(near(absf(wrapf(bolt.vel.angle()-before,-PI,PI)),0.224),"Spread homing uses only the frame remainder after its delay")
	fresh(2,"moon_radial");game.ClassCombat.release_staff(game)
	check(game.bullets.size()==9,"Moon radial adds eight sparks alongside one staff bolt")
	game.ClassCombat.release_staff(game)
	check(game.bullets.size()==10,"Radial cooldown prevents duplicate bursts from rapid staff calls")
	game.ClassCombat.tick(game,2.3,game.player);game.ClassCombat.release_staff(game)
	check(game.bullets.size()==19,"Radial reopens after its independent 2.3-second cadence")
	for i in range(500):game.ClassCombat.release_staff(game)
	check(game.bullets.size()<=96,"Adversarial staff calls obey the 96 class-projectile limit")
func test_fire_and_familiar():
	fresh(2,"moon_fire")
	var enemy=enemy_at(Vector2.ZERO)
	game.hp=30;game.stats.lifesteal=0.1
	for i in range(100):game.ClassCombat._add_fire_patch(game,enemy.pos,2)
	check(game.trail_patches.size()==32,"Fire trail has a hard 32-patch limit")
	game.ClassCombat.tick(game,0.01,game.player)
	var expected=game.stats.damage*0.18
	check(near(enemy.hp,1000-expected) and near(game.hp,30+expected*0.1),"Overlapping fire deals and life-drains only one bounded tick")
	var after=enemy.hp
	game.ClassCombat.tick(game,0.1,game.player)
	check(near(enemy.hp,after),"Fire overlap cannot bypass the per-enemy 0.35-second gate")
	game.ClassCombat.tick(game,2.0,game.player)
	check(game.trail_patches.is_empty() and near(enemy.hp,after),"Expired stationary fire disappears without extra damage")
	var start=game.player
	game.player+=Vector2(20,0);game.ClassCombat.tick(game,STEP,start)
	check(not game.trail_patches.is_empty(),"Walking with Moonfire creates visible ground patches")
	game.trail_patches.clear();game.class_fx.erase("fire_last")
	game.dash_left=0.1;start=game.player;game.player+=Vector2(60,0)
	game.ClassCombat.tick(game,STEP,start)
	check(game.trail_patches.is_empty(),"Dashing does not paint fire along its whole distance")
	fresh(2,"moon_familiar");enemy=enemy_at(Vector2(200,0))
	game.ClassCombat.tick(game,0.89,game.player)
	check(game.class_fx.has("familiar") and game.bullets.is_empty(),"One familiar follows before its first 0.9-second shot")
	game.ClassCombat.tick(game,0.011,game.player)
	check(game.bullets.size()==1 and game.bullets[0].class_kind=="familiar" and near(game.bullets[0].damage,6.3),"Familiar fires one homing bolt at 35% damage")
	check(not game.apply_tactic("moon_familiar"),"Familiar cannot stack into multiple companions")
	game.class_fx.familiar.pos=game.player+Vector2(999,0)
	game.ClassCombat.tick(game,STEP,game.player)
	check(game.class_fx.familiar.pos.distance_to(game.player)<180,"Familiar recovers from excessive displacement")
func test_poison_and_push():
	fresh(3,"comet_poison")
	var enemy=enemy_at(Vector2(30,0))
	for i in range(50):game.ClassCombat.on_dash_hit(game,enemy)
	check(enemy.poison_stacks==3 and near(enemy.poison_left,3),"Poison refresh caps at three stacks with finite three-second duration")
	game.hp=30;game.stats.lifesteal=0.1
	for i in range(6):game.ClassCombat.tick(game,0.5,game.player)
	check(near(enemy.hp,973) and near(game.hp,32.7),"Triple rank-one poison deals six 4.5-damage ticks with actual-damage healing")
	var after=enemy.hp
	for i in range(10):game.ClassCombat.tick(game,1.0,game.player)
	check(enemy.poison_stacks==0 and near(enemy.hp,after),"Expired poison cannot damage or heal indefinitely")
	enemy.hp=1;game.ClassCombat.on_dash_hit(game,enemy)
	var hp_before=game.hp
	game.ClassCombat.tick(game,3.0,game.player)
	check(near(enemy.hp,0) and near(game.hp,hp_before+0.1),"Poison overkill heals only from the target's one remaining HP")
	fresh(3,"comet_push");enemy=enemy_at(Vector2(30,0));enemy.attack_state="idle"
	var position=enemy.pos
	game.ClassCombat.on_dash_hit(game,enemy)
	check(near(enemy.pos.distance_to(position),20),"Comet Push moves an idle foe twenty collision-checked pixels")
	enemy.attack_state="windup";position=enemy.pos;game.ClassCombat.on_dash_hit(game,enemy)
	check(enemy.pos==position,"Comet Push cannot invalidate a committed windup's position")
	game.apply_tactic("comet_push");enemy.attack_state="recover";position=enemy.pos
	game.obstacles=[Rect2(position+Vector2(20,-30),Vector2(20,60))]
	game.ClassCombat.on_dash_hit(game,enemy)
	check(enemy.pos.x<=position.x+5,"Comet Push respects enemy-radius wall collision")
func test_shield():
	fresh(2);game.damage_player(20)
	check(near(game.hp,70) and near(game.shield,15) and near(game.shield_delay,4),"Shield absorbs accepted damage before HP and starts its four-second delay")
	game.hurt_cd=0;game.damage_player(20)
	check(near(game.hp,65) and near(game.shield,0),"Broken shield passes only unabsorbed damage to HP")
	game.ClassProgression.tick(game,3.9);check(near(game.shield,0),"Shield waits for its full delay")
	game.ClassProgression.tick(game,0.2)
	check(near(game.shield,0.7),"A frame crossing the delay recharges only its remaining 0.1 seconds")
	game.ClassProgression.tick(game,20)
	check(near(game.shield,35) and near(game.hp,65),"Shield capacity does not silently heal HP")
	game.apply_tactic("moon_ward");game.apply_tactic("moon_ward")
	check(near(game.ClassProgression.shield_max(game),55) and near(game.ClassProgression.shield_regen(game),9),"Two Ward ranks cap shield at 55 and regen at nine per second")
	check(near(game.shield,35),"Added shield capacity is not an instant shield refill")
	game.shield=10;game.shield_delay=2;game.hurt_cd=1;game.damage_player(999)
	check(near(game.shield,10) and near(game.shield_delay,2),"Rejected immune hits neither consume shield nor restart delay")
	game.hurt_cd=0;game.damage_player(0);check(near(game.shield,10),"Zero damage cannot drain shield")
func test_charges_and_timing():
	for build in range(4):
		fresh(build);game.dash()
		check(game.dash_charges==0 and near(game.dash_left,0.18),"Class %d spends its one normal 0.18-second dash charge"%build)
		var recharge=game.dash_recharge
		game.dash()
		check(game.dash_charges==0 and near(game.dash_recharge,recharge),"Class %d cannot spam dash while active or empty"%build)
		game.dash_left=0;game.ClassProgression.tick(game,recharge-0.001)
		check(game.dash_charges==0,"Class %d recharge cannot finish early"%build)
		game.ClassProgression.tick(game,0.002);check(game.dash_charges==1,"Class %d recovers one dash after full recharge"%build)
	fresh(3,"comet_echo")
	check(game.dash_charges==2 and game.ClassProgression.dash_max(game)==2,"Comet Echo provides a two-charge stage-entry reserve")
	game.dash();game.dash_left=0;game.dash()
	check(game.dash_charges==0,"Comet spends its two charges in separate dash windows")
	game.dash_left=0
	var interval=game.stats.dash_cooldown
	game.ClassProgression.tick(game,interval+0.01)
	check(game.dash_charges==1 and game.dash_recharge>0,"Spent Comet charges recharge serially")
	game.ClassProgression.tick(game,interval)
	check(game.dash_charges==2 and near(game.dash_recharge,0),"Second charge needs the next full interval")
	game.apply_tactic("comet_length");game.apply_tactic("comet_length");game.dash()
	check(near(game.dash_left,0.26) and near(game.ClassProgression.dash_duration(game),0.26),"Comet Length caps dash duration at 0.26 seconds")
	fresh(3);game.dash();game.dash_left=0
	game.ClassProgression.tick(game,1);var before=game.dash_recharge
	game.apply_tactic("comet_echo")
	check(game.dash_charges==0 and near(game.dash_recharge,before),"Unlocking a second dash preserves recharge progress and grants no free charge")
	game.ClassProgression.tick(game,20)
	check(game.dash_charges==2 and near(game.dash_recharge,0),"Large resource ticks remain bounded to maximum dash capacity")
func hazard_at(pos: Vector2) -> Dictionary:
	return {"pos":pos,"radius":27.0,"state":"active","time":0.3,"duration":0.3,"hit":false,"theme":0,"serial":999,"damage":20.0,"phase":0.0}
func test_ranger():
	fresh(1)
	check(near(game.stats.speed,175) and near(game.stats.attack_speed,1.15),"Ranger starts faster in both movement and attack cadence")
	var enemy=enemy_at(Vector2(200,0))
	game.apply_tactic("ranger_rapid");game.apply_tactic("ranger_rapid")
	check(near(game.stats.attack_speed,1.55),"Two Quickdraw ranks add a bounded 0.4 attack speed")
	game.apply_tactic("ranger_fan");game.apply_tactic("ranger_fan")
	game.bow_cd=0;game.update_player_attacks(0,enemy);attack_steps(0.205)
	check(game.bullets.size()==3 and near(game.bow_cd,0.85/1.55),"Two Star Fan ranks create a three-arrow volley at Quickdraw's actual cooldown")
	check(game.trap_charges==1 and game.ClassProgression.trap_max(game)==1,"Ranger begins with one independent map-trap dodge")
	game.apply_tactic("ranger_evasion");game.apply_tactic("ranger_evasion")
	check(game.trap_charges==1 and game.ClassProgression.trap_max(game)==3 and near(game.trap_recharge,10),"Trail Instinct raises capacity to three without filling new slots")
	game.ClassProgression.tick(game,10.01)
	check(game.trap_charges==2 and game.trap_recharge>0,"Trap charges regenerate serially at the upgraded ten-second cadence")
	game.ClassProgression.tick(game,10);check(game.trap_charges==3,"Ranger reaches its bounded three-charge reserve")
	var before_hp=game.hp
	game.world_data.hazards=[hazard_at(game.player)]
	game.World.update_hazards(game,0)
	check(game.trap_charges==2 and near(game.hp,before_hp) and near(game.hurt_cd,0),"One active map hazard spends one trap charge without granting general immunity")
	game.World.update_hazards(game,0)
	check(game.trap_charges==2,"The same eruption cannot consume another charge")
	game.damage_player(20)
	check(game.trap_charges==2 and near(game.hp,before_hp-20),"Ordinary enemy damage bypasses trap evasion and consumes no charge")
	game.hurt_cd=1;game.world_data.hazards=[hazard_at(game.player)];game.World.update_hazards(game,0)
	check(game.trap_charges==2,"Existing hurt immunity avoids wasting a trap charge")
	game.hurt_cd=0;game.dash_left=0.1;game.world_data.hazards=[hazard_at(game.player)];game.World.update_hazards(game,0)
	check(game.trap_charges==2,"Existing dash immunity avoids wasting a trap charge")
	game.dash_left=0;game.trap_charges=0;game.world_data.hazards=[hazard_at(game.player)];game.World.update_hazards(game,0)
	check(near(game.hp,before_hp-40),"A map hazard deals normal damage when evasion charges are empty")
func test_lifecycle():
	for frozen_state in ["paused","tactic","loot","menu","dead","won"]:
		fresh(2,"moon_familiar")
		game.shield=0;game.shield_delay=1;game.dash_charges=0;game.dash_recharge=1
		game.trail_patches=[{"pos":game.player,"time":1.0,"damage":1.0}]
		var enemy=enemy_at(Vector2(20,0));enemy.poison_left=3;enemy.poison_tick=0.5;enemy.poison_stacks=3;enemy.poison_rank=1
		game.state=frozen_state
		game.simulate(20);game.ClassCombat.tick(game,20,game.player);game.ClassProgression.tick(game,20);game.dash()
		check(near(game.shield,0) and near(game.shield_delay,1) and game.dash_charges==0 and near(game.dash_recharge,1) and near(enemy.hp,1000) and near(game.trail_patches[0].time,1) and game.bullets.is_empty(),frozen_state+" freezes shield, charges, DOT, familiar and dash")
	fresh(3,"comet_poison")
	var enemy=enemy_at(Vector2(20,0));game.ClassCombat.on_dash_hit(game,enemy)
	game.class_fx["dash_ghosts"]=[{"pos":game.player,"time":1.0,"aim":game.facing}]
	game.trail_patches=[{"pos":game.player,"time":1.0,"damage":1.0}]
	game.dash_charges=0;game.dash_recharge=2;game.start_stage()
	check(game.class_fx.is_empty() and game.trail_patches.is_empty() and game.dash_charges==game.ClassProgression.dash_max(game),"Stage entry clears effects and restores class resources")
	var poisoned=false
	for e in game.enemies:poisoned=poisoned or e.get("poison_left",0)>0
	check(not poisoned,"New-stage foes cannot inherit prior poison")
	game.class_fx["radial_cd"]=2;game.trail_patches.append({"pos":game.player,"time":1,"damage":1});game.end_run(false)
	check(game.class_fx.is_empty() and game.trail_patches.is_empty(),"Death clears class effects and damaging ground patches")
	fresh(2,"moon_ward");game.shield=0;game.shield_delay=4;game.start_run()
	check(near(game.shield,game.ClassProgression.shield_max(game)) and near(game.shield_delay,0),"New run restores selected-class shield and clears old delay")
func test_dash_hit_integration():
	fresh(3,"comet_poison")
	var enemy=enemy_at(Vector2(20,0));enemy.spawn_grace=0
	game.dash()
	game.Combat.tick(game,enemy,0)
	var after=enemy.hp
	game.Combat.tick(game,enemy,0)
	check(near(after,960) and near(enemy.hp,after) and enemy.poison_stacks==1,"One actual dash damages and poisons an overlapping enemy exactly once")
	game.dash_left=0;game.ClassProgression.tick(game,game.stats.dash_cooldown);game.dash()
	game.Combat.tick(game,enemy,0)
	check(near(enemy.hp,920) and enemy.poison_stacks==2,"A separately recharged dash can damage and add one poison stack again")
	fresh(3,"comet_length")
	game.apply_tactic("comet_length");game.dash()
	var start=game.player
	for i in range(31):game.simulate(STEP)
	check(game.player.distance_to(start)>145 and game.player.distance_to(start)<165,"Extended dash travels through normal collision movement at its bounded duration")
	fresh(2,"moon_ward")
	game.apply_tactic("moon_ward")
	var capacity=game.ClassProgression.shield_max(game)
	game.gain_xp(100000)
	check(near(game.ClassProgression.shield_max(game),capacity) and near(game.ClassProgression.shield_regen(game),9),"Level growth cannot multiply fixed shield capacity or regeneration")
	fresh(1,"ranger_evasion")
	game.apply_tactic("ranger_evasion");game.ClassProgression.tick(game,30)
	enemy=enemy_at(Vector2(200,0))
	game.world_data.hazards=[hazard_at(game.player),hazard_at(game.player),hazard_at(game.player),hazard_at(game.player)]
	game.World.update_hazards(game,0)
	check(game.trap_charges==0 and near(game.hp,80),"Four simultaneous eruptions consume three trap charges then deal one normal hit")
