class_name ClassProgression
extends RefCounted

# Per-class resources deliberately live outside the multiplicative stat table.
# Level growth and Equipment cannot inflate shields, charges, avoidance or duration.
const D = preload("res://data.gd")
const SHIELD_DELAY = 4.0

static func class_id(g) -> String:
	return str(D.CLASSES[clampi(int(g.selected_class),0,D.CLASSES.size()-1)].id)

static func rank(g, id: String) -> int:
	return g.tactic_rank(id)

static func eligible(g, tactic: Dictionary) -> bool:
	var id = str(tactic.get("id",""))
	if id.is_empty():return false
	var classes = tactic.get("classes",[])
	if not classes.is_empty() and not class_id(g) in classes:return false
	# Support explicit prerequisites for future skills without silently ignoring
	# saved/custom data. Current branches are standalone Starting Skill options.
	var requires = tactic.get("requires",{})
	if requires is String:
		if not requires.is_empty() and rank(g,requires)<1:return false
	elif requires is Array:
		for prerequisite in requires:
			if rank(g,str(prerequisite))<1:return false
	elif requires is Dictionary:
		for prerequisite in requires:
			if rank(g,str(prerequisite))<int(requires[prerequisite]):return false
	var style = str(tactic.get("style",""))
	if not style.is_empty():
		for other in D.TACTICS:
			if other.id!=id and str(other.get("style",""))==style and rank(g,other.id)>0:return false
	return true

static func has_effect(g, tactic: Dictionary) -> bool:
	# Statless branch Tactics must survive the ordinary capped-stat filter.
	return eligible(g,tactic) and rank(g,str(tactic.get("id","")))<int(tactic.get("cap",0)) and not str(tactic.get("effect","")).is_empty()

static func stat_bounds(g, key: String) -> Array:
	var bounds: Array = D.STAT_LIMITS.get(key,[-INF,INF]).duplicate()
	var kind = class_id(g)
	match key:
		"max_hp":
			if kind=="mage":bounds[1]=280.0
		"attack_speed":
			bounds[1]=2.4 if kind=="ranger" else (2.2 if kind=="melee" else 2.0)
		"projectiles":
			bounds[1]=4.0 if kind=="ranger" else 2.0
		"magic":
			bounds[1]=3.0 if kind=="mage" else 2.0
	return bounds

static func shield_max(g) -> float:
	return 35.0+10.0*rank(g,"moon_ward") if class_id(g)=="mage" else 0.0

static func shield_regen(g) -> float:
	return 7.0+rank(g,"moon_ward") if class_id(g)=="mage" else 0.0

static func dash_max(g) -> int:
	return 1+rank(g,"comet_echo") if class_id(g)=="dash" else 1

static func dash_duration(g) -> float:
	return 0.18+0.04*rank(g,"comet_length") if class_id(g)=="dash" else 0.18

static func dash_cooldown(g) -> float:
	return clampf(float(g.stats.get("dash_cooldown",3.0)),1.1,10.0)

static func trap_max(g) -> int:
	return 1+rank(g,"ranger_evasion") if class_id(g)=="ranger" else 0

static func trap_cooldown(g) -> float:
	return 12.0-rank(g,"ranger_evasion") if class_id(g)=="ranger" else 0.0

static func reset_run(g):
	reset_stage(g)

static func reset_stage(g):
	# A new arena deliberately replenishes all class resources. An tactic does
	# not. This also removes partial recharge/damage-delay carryover across runs.
	g.shield=shield_max(g)
	g.shield_delay=0.0
	g.dash_charges=dash_max(g)
	g.dash_recharge=0.0
	g.dash_cd=0.0
	g.trap_charges=trap_max(g)
	g.trap_recharge=0.0

static func sync_dash(g):
	# Legacy dash_cd is only a compatibility view, never a second timer.
	g.dash_cd=maxf(0.0,g.dash_recharge) if g.dash_charges<=0 else 0.0

static func tick(g, dt: float):
	if g.state!="playing" or g.hp<=0 or dt<=0 or not is_finite(dt):return
	var shield_time=dt
	if g.shield_delay>0:
		shield_time=maxf(0.0,dt-g.shield_delay)
		g.shield_delay=maxf(0.0,g.shield_delay-dt)
	g.shield=clampf(g.shield+shield_regen(g)*shield_time,0.0,shield_max(g))
	# Serial charge recovery: using another charge never restarts an existing
	# recharge. Carry a long frame's leftover time into the next missing charge.
	g.dash_charges=clampi(g.dash_charges,0,dash_max(g))
	if g.dash_charges<dash_max(g):
		if g.dash_recharge<=0:g.dash_recharge=dash_cooldown(g)
		g.dash_recharge-=dt
		while g.dash_recharge<=0 and g.dash_charges<dash_max(g):
			g.dash_charges+=1
			if g.dash_charges<dash_max(g):g.dash_recharge+=dash_cooldown(g)
		if g.dash_charges>=dash_max(g):g.dash_recharge=0.0
	else:g.dash_recharge=0.0
	sync_dash(g)
	g.trap_charges=clampi(g.trap_charges,0,trap_max(g))
	if g.trap_charges<trap_max(g):
		if g.trap_recharge<=0:g.trap_recharge=trap_cooldown(g)
		g.trap_recharge-=dt
		while g.trap_recharge<=0 and g.trap_charges<trap_max(g):
			g.trap_charges+=1
			if g.trap_charges<trap_max(g):g.trap_recharge+=trap_cooldown(g)
		if g.trap_charges>=trap_max(g):g.trap_recharge=0.0
	else:g.trap_recharge=0.0

static func try_dash(g) -> bool:
	if g.state!="playing" or g.hp<=0 or g.dash_left>0 or g.dash_charges<=0:return false
	g.dash_charges-=1
	if g.dash_recharge<=0:g.dash_recharge=dash_cooldown(g)
	sync_dash(g)
	return true

static func absorb_damage(g, postarmor: float) -> float:
	# The caller first rejects immunity/dead/non-playing hits and applies armor.
	# Every accepted hit, even one absorbed in full, resets the 4-second delay;
	# the caller grants the normal 0.65-second hurt window regardless of HP loss.
	if postarmor<=0 or not is_finite(postarmor):return 0.0
	if class_id(g)!="mage":return postarmor
	g.shield_delay=SHIELD_DELAY
	var absorbed=minf(maxf(0.0,g.shield),postarmor)
	g.shield=maxf(0.0,g.shield-absorbed)
	return postarmor-absorbed

static func avoid_trap(g) -> bool:
	# Only World's already-active, intersecting, unconsumed environmental hit
	# path may call this. Enemy attacks/projectiles never spend trap charges.
	if class_id(g)!="ranger" or g.state!="playing" or g.hp<=0 or g.hurt_cd>0 or g.dash_left>0 or g.trap_charges<=0:return false
	g.trap_charges-=1
	if g.trap_recharge<=0:g.trap_recharge=trap_cooldown(g)
	# No hurt_cd or generic immunity: a different simultaneous hazard can hit.
	return true

static func on_tactic(g, id: String):
	# apply_tactic increments the rank BEFORE calling this hook. Added charge
	# capacity starts empty; existing recharge progress is preserved, not reset.
	if id=="comet_echo" and class_id(g)=="dash":
		g.dash_charges=clampi(g.dash_charges,0,dash_max(g))
		if g.dash_charges<dash_max(g) and g.dash_recharge<=0:g.dash_recharge=dash_cooldown(g)
		sync_dash(g)
	elif id=="ranger_evasion" and class_id(g)=="ranger":
		g.trap_charges=clampi(g.trap_charges,0,trap_max(g))
		if g.trap_charges<trap_max(g):
			g.trap_recharge=trap_cooldown(g) if g.trap_recharge<=0 else minf(g.trap_recharge,trap_cooldown(g))
	elif id=="moon_ward" and class_id(g)=="mage":
		# More shield capacity does not erase an accepted-hit recharge delay.
		g.shield=clampf(g.shield,0.0,shield_max(g))
