extends RefCounted

# Every attack commits to a visible shape/heading before release. Contact is safe.
# Shared shape data drives both ground cues and hit tests, including safe holes.
const BOSS_NAMES = ["THORN WARDEN", "EMBER ALCHEMIST", "CRYSTAL SENTINEL", "NIGHT SOVEREIGN"]
const NEW_KINDS = ["sentinel", "assassin", "chanter", "hexer"]
const NEW_BOSS_PATTERNS = ["rootline", "thornwheel", "cinder_cross", "ember_bloom", "prism_lance", "crystal_spokes", "eclipse", "nightfall"]

static func initialize(e: Dictionary, stage: int):
	e.merge({"attack_state":"idle", "attack_time":0.0, "attack_duration":1.0,
		"attack_aim":Vector2.RIGHT, "attack_origin":e.pos, "attack_target":e.pos,
		"attack_hit":false, "attack_pattern":"melee", "attack_index":0,
		"boss_type":clampi(int(stage / 5)-1,0,3), "moving":false,
		"facing":Vector2.RIGHT, "max_hp":e.hp, "haste_time":0.0,
		"flank_sign":-1.0 if sin(e.get("phase",0.0))<0 else 1.0}, false)

static func late_pressure(stage: int) -> float:
	return clampf(float(stage-8)/12.0,0.0,1.0)

static func boss_patterns(e: Dictionary) -> Array:
	match int(e.boss_type):
		0:return ["cleave","rootline","charge","thornwheel"]
		1:return ["blast","cinder_cross","ember_bloom"]
		2:return ["fan","prism_lance","ring","crystal_spokes"]
	return ["cleave","eclipse","charge","nightfall","blast"] if e.hp>e.max_hp*0.5 else ["cleave","eclipse","charge","nightfall","fan","blast"]

static func next_pattern(e: Dictionary) -> String:
	match e.kind:
		"swift","herbalist","grunt":return "melee"
		"ghost":return "lunge"
		"archer":return "shot"
		"bomber":return "explode"
		"sentinel":return "shield_bash"
		"assassin":return "shadow_lunge"
		"chanter":return "chant" if e.attack_index%2==0 else "pulse"
		"hexer":return "hex_pool"
		"boss":
			var patterns=boss_patterns(e)
			return patterns[e.attack_index%patterns.size()]
	return "melee"

static func begin(g, e: Dictionary):
	e.attack_origin=e.pos
	e.attack_target=g.player
	e.attack_aim=(g.player-e.pos).normalized()
	if e.attack_aim==Vector2.ZERO:e.attack_aim=e.facing
	if e.attack_aim==Vector2.ZERO:e.attack_aim=Vector2.RIGHT
	e.facing=e.attack_aim
	e.attack_hit=false
	e.attack_state="windup"
	e.attack_pattern=next_pattern(e)
	var windup=0.55
	match e.kind:
		"swift":windup=0.38
		"ghost","archer":windup=0.65
		"herbalist":windup=0.6
		"bomber":windup=0.9
		"sentinel":windup=0.72
		"assassin":windup=0.66
		"chanter":windup=0.9 if e.attack_pattern=="chant" else 0.75
		"hexer":windup=0.95
		"boss":
			match int(e.boss_type):
				0:windup=0.9
				1:windup=1.0
				2:windup=0.85
				3:windup=0.72 if e.hp>e.max_hp*0.5 else 0.6
			# Larger new hazards get extra warning, even in the final rage phase.
			if e.attack_pattern in NEW_BOSS_PATTERNS:windup=maxf(windup,0.85)
	# Late pressure is bounded; the shortest warning never drops below 0.38s.
	if e.kind!="boss":windup=maxf(0.38,windup*(1.0-0.08*late_pressure(g.stage)))
	e.attack_duration=windup;e.attack_time=windup
	e.attack_index+=1

static func release(g, e: Dictionary):
	e.attack_state="active"
	e.attack_duration=0.18
	match e.attack_pattern:
		"charge","lunge":e.attack_duration=0.42
		"shadow_lunge":e.attack_duration=0.38
		"hex_pool":e.attack_duration=1.0
		"nightfall":e.attack_duration=1.02
		"rootline","thornwheel","cinder_cross","ember_bloom","prism_lance","crystal_spokes","eclipse":e.attack_duration=0.3
	e.attack_time=e.attack_duration
	var pressure=late_pressure(g.stage)
	var shot_damage=1.0+0.15*pressure
	var shot_speed=1.0+0.18*pressure
	match e.attack_pattern:
		"shot":g.enemy_shot(e.pos+e.attack_aim*22,e.attack_aim,(100+g.stage*3)*shot_speed,shot_damage)
		"pulse":
			for i in range(3):
				var aim=e.attack_aim.rotated((i-1)*0.15)
				g.enemy_shot(e.pos+aim*24,aim,140*shot_speed,shot_damage*0.95,"chant")
		"fan":
			for i in range(7):
				var aim=e.attack_aim.rotated((i-3)*0.19)
				g.enemy_shot(e.pos+aim*30,aim,(145+g.stage*2)*shot_speed,shot_damage)
		"ring":
			for i in range(12):
				var aim=Vector2.RIGHT.rotated(i*TAU/12)
				g.enemy_shot(e.pos+aim*30,aim,125*shot_speed,shot_damage)
		"chant":
			for ally in g.enemies:
				if ally!=e and ally.hp>0 and ally.pos.distance_to(e.attack_origin)<=225:
					ally.haste_time=maxf(ally.get("haste_time",0.0),3.0)

static func attack_trigger(e: Dictionary) -> float:
	match next_pattern(e):
		"melee":return 49.0
		"shield_bash":return 74.0
		"explode":return 65.0
		"lunge":return 105.0
		"shadow_lunge":return 135.0
		"cleave":return 125.0
		"charge":return 480.0
		"rootline":return 245.0
		"thornwheel":return 158.0
		"eclipse":return 205.0
		"crystal_spokes":return 230.0
		"shot":return 340.0
		"chant","pulse","hex_pool":return 390.0
	return 480.0

static func select_reachable_boss_pattern(e: Dictionary, distance: float):
	# A ranged build must not hold a short cleave at arm's length forever. Skip
	# unreachable moves only while idle; the selected warning still locks fully.
	if e.kind!="boss" or distance<=attack_trigger(e):return
	var original_index=int(e.attack_index)
	var patterns=boss_patterns(e)
	for offset in range(1,patterns.size()):
		e.attack_index=original_index+offset
		if distance<=attack_trigger(e):return
	e.attack_index=original_index

static func movement_speed(e: Dictionary, stage: int) -> float:
	var speed=(45.0+mini(stage,20)*1.8)*(1.0+0.4*late_pressure(stage))
	match e.kind:
		"swift":speed*=1.8
		"boss":speed*=0.72 if stage>=10 else 0.65
		"ghost":speed*=1.2
		"sentinel":speed*=0.78
		"assassin":speed*=1.6
		"chanter":speed*=0.85
	if e.get("haste_time",0.0)>0:speed*=1.16
	return minf(speed,225.0)

static func recovery_cooldown(e: Dictionary, stage: int) -> float:
	var cooldown=0.7
	match e.kind:
		"sentinel":cooldown=0.85
		"assassin":cooldown=0.8
		"chanter":cooldown=1.15
		"hexer":cooldown=1.35
		"boss":cooldown=0.45 if e.boss_type==3 and e.hp<e.max_hp*0.5 else 0.9
	cooldown*=1.0-0.28*late_pressure(stage)
	if e.get("haste_time",0.0)>0:cooldown/=1.16
	return maxf(0.34,cooldown)

static func incoming_multiplier(e: Dictionary, source: Vector2) -> float:
	# Shield has a readable facing and an exposed recovery. Side/rear hits bypass it.
	if e.get("kind","")!="sentinel" or e.get("attack_state","idle") not in ["idle","windup"]:return 1.0
	var toward=source-e.pos
	if toward.length_squared()<1.0:return 1.0
	return 0.55 if e.get("facing",Vector2.RIGHT).normalized().dot(toward.normalized())>cos(PI*0.39) else 1.0

static func tick(g, e: Dictionary, dt: float):
	if g.state!="playing" or g.hp<=0 or e.hp<=0:return
	initialize(e,g.stage)
	e.hit=maxf(0,e.hit-dt);e.phase+=dt;e.cooldown-=dt
	e.haste_time=maxf(0,e.haste_time-dt)
	e.moving=false
	var distance=g.player.distance_to(e.pos)
	var toward=(g.player-e.pos).normalized()
	if e.attack_state=="idle":
		if e.cooldown<=0:select_reachable_boss_pattern(e,distance)
		if distance<=attack_trigger(e) and e.cooldown<=0:
			begin(g,e)
		else:
			var move=toward
			if e.kind in ["archer","chanter","hexer"]:
				if distance<145:move=-toward
				elif distance<240:move=Vector2.ZERO
			elif e.kind=="assassin" and distance>90:
				# Flank while approaching, then commit to a straight, dodgeable lunge.
				move=(toward*(0.9 if distance>210 else 0.6)+toward.orthogonal()*e.flank_sign*0.65).normalized()
			elif distance<30:move=Vector2.ZERO
			var previous=e.pos
			e.pos=g.move_actor(e.pos,move*movement_speed(e,g.stage)*dt,26 if e.kind=="boss" else 16)
			# Only idle actors separate. Windups stay anchored to displayed cues.
			for other in g.enemies:
				if other==e or other.hp<=0:continue
				var away=e.pos-other.pos
				if away.length_squared()<500 and away.length_squared()>1:
					e.pos=g.move_actor(e.pos,away.normalized()*22*dt,14)
			e.moving=e.pos.distance_squared_to(previous)>0.0001
			if e.moving and move.length_squared()>0.001:e.facing=move
	else:
		var was_active=e.attack_state=="active"
		e.attack_time=maxf(0,e.attack_time-dt)
		if was_active and e.attack_time<=0:
			finish_active(e)
			return
		if e.attack_state=="windup" and e.attack_time<=0:release(g,e)
		if e.attack_state=="active":
			if e.attack_pattern in ["charge","lunge","shadow_lunge"]:
				var speed=410.0 if e.attack_pattern=="charge" else (310.0 if e.attack_pattern=="shadow_lunge" else 220.0)
				# Release can occur partway through a simulation step. Never let its
				# first movement step extend the endpoint shown during the windup.
				var progress=maxf(0.0,(e.pos-e.attack_origin).dot(e.attack_aim))
				var next_progress=minf(lunge_distance(e.attack_pattern),progress+speed*dt)
				var intended=e.attack_origin+e.attack_aim*next_progress
				var next_pos=g.move_actor(e.pos,intended-e.pos,26 if e.kind=="boss" else 16)
				# A committed charge stops against walls instead of axis-sliding
				# sideways beyond its honestly marked capsule.
				if next_pos.distance_squared_to(intended)<0.000001:
					e.moving=e.pos.distance_squared_to(intended)>0.000001
					e.pos=intended
			if attack_connects(e,g.player) and not e.attack_hit:
				e.attack_hit=true
				var damage=(17+g.stage*0.7) if e.kind=="boss" else (18+g.stage if e.kind=="bomber" else 8+g.stage*0.8)
				if e.kind=="sentinel":damage*=1.12
				if e.kind=="assassin":damage*=1.15
				g.damage_player(damage*(1.0+0.15*late_pressure(g.stage)))
		elif e.attack_state=="recover" and e.attack_time<=0:
			e.attack_state="idle"
			e.cooldown=recovery_cooldown(e,g.stage)
	# Dash damage is a distinct player action, never passive contact.
	if g.dash_left>0 and g.player.distance_to(e.pos)<38 and not e.dash_hit:
		e.dash_hit=true
		if g.stats.dash_damage>0:
			g.damage_enemy(e,g.stats.damage+g.stats.dash_damage)
			g.ClassCombat.on_dash_hit(g,e)

static func finish_active(e: Dictionary):
	if e.attack_pattern=="explode":e.hp=0
	e.attack_state="recover"
	e.attack_duration=0.48 if e.kind=="sentinel" else 0.4
	e.attack_time=e.attack_duration

static func lunge_distance(pattern: String) -> float:
	return 172.2 if pattern=="charge" else (117.8 if pattern=="shadow_lunge" else 92.4)

# Shapes describe player-centre hit areas, just as the original combat did.
# preview=true includes the full travel lane and all future nightfall beats.
static func attack_shapes(e: Dictionary, preview: bool=false) -> Array:
	var shapes: Array=[]
	var origin:Vector2=e.attack_origin
	var aim:Vector2=e.attack_aim
	var target:Vector2=e.attack_target
	match e.attack_pattern:
		"melee","cleave","shield_bash":
			var radius=108.0 if e.attack_pattern=="cleave" else (76.0 if e.attack_pattern=="shield_bash" else 55.0)
			var half=acos(-0.2) if e.attack_pattern=="cleave" else (1.05 if e.attack_pattern=="shield_bash" else acos(0.2))
			shapes.append({"type":"sector","center":e.pos,"radius":radius,"aim":aim,"half":half})
		"charge","lunge","shadow_lunge":
			var radius=43.0 if e.attack_pattern=="charge" else (29.0 if e.attack_pattern=="shadow_lunge" else 32.0)
			if preview:
				var length=lunge_distance(e.attack_pattern)
				shapes.append({"type":"lane","a":origin,"b":origin+aim*length,"radius":radius})
			else:shapes.append({"type":"circle","center":e.pos,"radius":radius})
		"blast","hex_pool":shapes.append({"type":"circle","center":target,"radius":49.0 if e.attack_pattern=="hex_pool" else 70.0})
		"explode":shapes.append({"type":"circle","center":origin,"radius":77.0})
		"rootline":
			for length in [66.0,130.0,194.0]:shapes.append({"type":"circle","center":origin+aim*length,"radius":34.0})
		"thornwheel":shapes.append({"type":"annulus","center":origin,"inner":58.0,"radius":132.0})
		"cinder_cross":
			for dir in [aim,aim.orthogonal()]:shapes.append({"type":"lane","a":target-dir*132.0,"b":target+dir*132.0,"radius":19.0})
		"ember_bloom":
			for i in range(4):shapes.append({"type":"circle","center":target+aim.rotated(i*PI/2)*68.0,"radius":40.0})
		"prism_lance":
			for offset in [-66.0,0.0,66.0]:
				var start=origin+aim.orthogonal()*offset
				shapes.append({"type":"lane","a":start,"b":start+aim*300.0,"radius":14.0})
		"crystal_spokes":
			for i in range(6):shapes.append({"type":"lane","a":origin,"b":origin+aim.rotated(i*TAU/6)*210.0,"radius":13.0})
		"eclipse":shapes.append({"type":"annulus","center":origin,"inner":76.0,"radius":182.0})
		"nightfall":
			var elapsed=maxf(0,e.attack_duration-e.attack_time)
			for i in range(3):
				# All positions lock at the initial windup; each outlined seal lights once.
				if preview or (elapsed>=i*0.34 and elapsed<i*0.34+0.28):
					var shift=[0.0,-95.0,95.0][i]
					shapes.append({"type":"circle","center":target+aim.orthogonal()*shift,"radius":45.0,"beat":i})
	return shapes

static func shape_contains(shape: Dictionary, point: Vector2) -> bool:
	match shape.type:
		"circle":return point.distance_to(shape.center)<shape.radius
		"annulus":
			var distance=point.distance_to(shape.center)
			return distance>shape.inner and distance<shape.radius
		"lane":return point.distance_to(Geometry2D.get_closest_point_to_segment(point,shape.a,shape.b))<shape.radius
		"sector":
			var offset=point-shape.center
			return offset.length()<shape.radius and (offset.length_squared()<0.001 or shape.aim.dot(offset.normalized())>cos(shape.half))
	return false

static func attack_connects(e: Dictionary, point: Vector2) -> bool:
	for shape in attack_shapes(e):
		if shape_contains(shape,point):return true
	return false

static func draw_shape(g, shape: Dictionary, col: Color, fill: Color, active: bool):
	var width=3.0 if active else 1.5
	match shape.type:
		"circle":
			g.draw_circle(shape.center,shape.radius,fill)
			g.draw_arc(shape.center,shape.radius,0,TAU,40,col,width)
		"annulus":
			# Fill a strip, never a disc: the empty centre is genuinely safe.
			for i in range(48):
				var a=Vector2.RIGHT.rotated(i*TAU/48)
				var b=Vector2.RIGHT.rotated((i+1)*TAU/48)
				g.draw_colored_polygon(PackedVector2Array([shape.center+a*shape.inner,shape.center+a*shape.radius,shape.center+b*shape.radius,shape.center+b*shape.inner]),fill)
			g.draw_arc(shape.center,shape.inner,0,TAU,48,col,width)
			g.draw_arc(shape.center,shape.radius,0,TAU,48,col,width)
		"lane":
			var side=(shape.b-shape.a).normalized().orthogonal()*shape.radius
			var angle=(shape.b-shape.a).angle()
			g.draw_colored_polygon(PackedVector2Array([shape.a-side,shape.b-side,shape.b+side,shape.a+side]),fill)
			g.draw_line(shape.a-side,shape.b-side,col,width);g.draw_line(shape.a+side,shape.b+side,col,width)
			var cap_points=PackedVector2Array([shape.b])
			for i in range(17):cap_points.append(shape.b+Vector2.RIGHT.rotated(angle-PI/2+i*PI/16)*shape.radius)
			g.draw_colored_polygon(cap_points,fill)
			cap_points=PackedVector2Array([shape.a])
			for i in range(17):cap_points.append(shape.a+Vector2.RIGHT.rotated(angle+PI/2+i*PI/16)*shape.radius)
			g.draw_colored_polygon(cap_points,fill)
			g.draw_arc(shape.b,shape.radius,angle-PI/2,angle+PI/2,18,col,width)
			g.draw_arc(shape.a,shape.radius,angle+PI/2,angle+PI*1.5,18,col,width)
		"sector":
			var angle=shape.aim.angle()
			var points=PackedVector2Array([shape.center])
			for i in range(25):points.append(shape.center+Vector2.RIGHT.rotated(angle-shape.half+i*shape.half/12)*shape.radius)
			g.draw_colored_polygon(points,fill)
			g.draw_arc(shape.center,shape.radius,angle-shape.half,angle+shape.half,32,col,width)
			g.draw_line(shape.center,points[1],col,1);g.draw_line(shape.center,points[-1],col,1)

static func draw_cues(g, e: Dictionary):
	if e.hp<=0:return
	if e.get("haste_time",0.0)>0:
		g.draw_arc(e.pos,22,0,TAU,18,Color("e2abff"),2)
	if e.kind=="sentinel" and e.get("attack_state","idle") in ["idle","windup"]:
		var angle=e.facing.angle()
		g.draw_arc(e.pos,23,angle-PI*0.39,angle+PI*0.39,12,Color("a8ddec"),3)
	if e.get("attack_state","idle") not in ["windup","active"]:return
	var active=e.attack_state=="active"
	var col=Color("ffe5ac") if active else Color("ff966f")
	if e.attack_pattern=="hex_pool":col=Color("ebb5ff") if active else Color("bd88e8")
	var fill=col;fill.a=0.22 if active else 0.1
	var shapes=attack_shapes(e,true)
	for shape in shapes:
		var shape_active=active
		if e.attack_pattern=="nightfall":
			var elapsed=maxf(0,e.attack_duration-e.attack_time)
			shape_active=active and elapsed>=shape.beat*0.34 and elapsed<shape.beat*0.34+0.28
			if active and elapsed>=shape.beat*0.34+0.28:continue
		var shape_col=col
		var shape_fill=fill
		if active and not shape_active:shape_col=Color("ff966f");shape_fill=shape_col;shape_fill.a=0.08
		draw_shape(g,shape,shape_col,shape_fill,shape_active)
		if e.attack_pattern=="nightfall":
			for mark in range(int(shape.beat)+1):g.draw_circle(shape.center+Vector2((mark-shape.beat/2.0)*9,-12),2.5,shape_col)
	match e.attack_pattern:
		"blast","hex_pool":
			g.draw_line(e.attack_target-Vector2(12,0),e.attack_target+Vector2(12,0),col,2)
			g.draw_line(e.attack_target-Vector2(0,12),e.attack_target+Vector2(0,12),col,2)
			if active:g.draw_arc(e.attack_target,30,0,TAU,12,col,4)
		"shot","fan","pulse":
			var count=7 if e.attack_pattern=="fan" else (3 if e.attack_pattern=="pulse" else 1)
			var spread=0.15 if e.attack_pattern=="pulse" else 0.19
			for i in range(count):
				var aim=e.attack_aim.rotated((i-(count-1)/2.0)*spread)
				g.draw_line(e.pos+aim*24,e.pos+aim*155,col,1)
		"ring":
			for i in range(12):
				var aim=Vector2.RIGHT.rotated(i*TAU/12)
				g.draw_line(e.pos+aim*30,e.pos+aim*105,col,1)
		"chant":
			var support=Color("c2a9ff");support.a=0.6 if active else 0.3
			g.draw_arc(e.attack_origin,225,0,TAU,48,support,2)
			for ally in g.enemies:
				if ally!=e and ally.hp>0 and ally.pos.distance_to(e.attack_origin)<=225:
					g.draw_line(e.pos,ally.pos,support,1)
	if not active:
		var fraction=1.0-e.attack_time/e.attack_duration
		g.draw_arc(e.pos,23 if e.kind!="boss" else 37,-PI/2,-PI/2+TAU*fraction,24,col,3)
