class_name CharacterArt
extends RefCounted

static func _tempest_colossus(p: Pixels,aim: Vector2,clock: float,phase: String,progress: float):
	p.unit=2.4
	var lift=5.0*absf(_attack(phase,progress))
	var armor=Color("497884")
	p.poly([Vector2(-17,-18),Vector2(-11,-27),Vector2(10,-27),Vector2(18,-17),Vector2(14,12),Vector2(-14,12)],INK)
	p.box(-13,-18,26,25,armor)
	p.box(-8,-22,16,13,Color("6db6c2"))
	for side in [-1,1]:
		p.box(side*12-4,-15,8,11,Color("a2d3db"))
		p.box(side*9-3,8,6,8,INK)
		p.box(side*9-2,9,5,6,Color("b4d3d5"))
		p.limb(Vector2(side*12,-8),Vector2(side*18,-3-lift),Vector2(side*21,5-lift),armor,5)
		p.poly([Vector2(side*5,-22),Vector2(side*11,-36),Vector2(side*12,-23)],Color("f6dc89"))
	p.box(-7,-6,14,10,Color("223e5a"))
	p.poly([Vector2(-1,-9),Vector2(5,-1),Vector2(1,-1),Vector2(3,6),Vector2(-5,-3),Vector2(-1,-3)],Color("ffe886"))
	_eyes(p,-19,Color("385473"),clock,true)
	for i in range(3):
		var a=clock*0.8+i*TAU/3
		var at=Vector2(cos(a)*23,sin(a)*8-30)
		p.box(at.x,at.y,2,3,Color("fff1a6"))
	if phase=="release":_spark(p,Vector2(aim.x*18,-8+aim.y*8),Color("c7ffff"),5)

static func _eclipse_seraph(p: Pixels,aim: Vector2,clock: float,phase: String,progress: float):
	p.unit=2.3
	var spread=2.0*sin(clock*2.0)+4*absf(_attack(phase,progress))
	for side in [-1,1]:
		p.poly([Vector2(side*5,-15),Vector2(side*(34+spread),-28),Vector2(side*27,-3),Vector2(side*15,4)],INK)
		p.poly([Vector2(side*7,-15),Vector2(side*(31+spread),-25),Vector2(side*25,-5),Vector2(side*15,2)],Color("e5d9f2") if side==1 else Color("65518b"))
		for i in range(3):p.line(Vector2(side*(13+i*5),-13-i*2),Vector2(side*(17+i*5),-4-i*3),Color("fff2b9") if side==1 else Color("b093dc"),2)
	p.poly([Vector2(-9,-21),Vector2(9,-21),Vector2(12,13),Vector2(0,19),Vector2(-12,13)],INK)
	p.poly([Vector2(-6,-17),Vector2(6,-17),Vector2(9,11),Vector2(0,15),Vector2(-9,11)],Color("8273a9"))
	p.box(-5,-26,10,11,Color("f1e6d3"))
	_eyes(p,-23,Color("845daa"),clock)
	p.poly([Vector2(-7,-29),Vector2(-4,-36),Vector2(0,-31),Vector2(4,-36),Vector2(7,-29)],Color("ffe292"))
	p.limb(Vector2(-6,-10),Vector2(-12,-4),Vector2(-15,-8-spread),Color("c5afdd"),3)
	p.limb(Vector2(6,-10),Vector2(12,-4),Vector2(15,-8-spread),Color("f0e1c1"),3)
	p.box(-1,-10,2,18,Color("ffdf83"))
	var origin=p.point(Vector2(0,-30))
	p.canvas.draw_arc(origin,23,PI*0.12,PI*0.88,20,Color("fbe8b3")*p.tint,3)
	if phase=="release":
		_spark(p,Vector2(-15,-8-spread),Color("d2b2ff"),4)
		_spark(p,Vector2(15,-8-spread),Color("fff4c9"),4)

## Original, articulated pixel actors. Positions are actor centres, in world pixels.
## moving drives a four-pose limb cycle; idle never cycles the gait or moves the body.
## attack_state: idle, windup, release, recover; weapon and enemy-move prefixes.
## attack_progress is 0..1 within the phase. All drawing is snapped to a 2px grid.

const INK := Color("171526")
const SHADOW := Color("2a243b")

class Pixels extends RefCounted:
	var canvas: Node2D
	var origin: Vector2
	var tint: Color
	var facing: float
	var unit: float = 2.0
	func _init(c: Node2D, p: Vector2, face: float, color: Color):
		canvas=c; origin=p.round(); facing=face; tint=color
	func point(p: Vector2) -> Vector2:
		return origin+Vector2(roundf(p.x)*facing,roundf(p.y))*unit
	func box(x: float,y: float,w: float,h: float,color: Color):
		var a=point(Vector2(x,y))
		if facing<0:a.x-=roundf(w)*unit
		canvas.draw_rect(Rect2(a,Vector2(roundf(w),roundf(h))*unit),color*tint)
	func poly(points: Array, color: Color):
		var vertices=PackedVector2Array()
		for p in points: vertices.append(point(p))
		canvas.draw_colored_polygon(vertices,color*tint)
	func line(a: Vector2,b: Vector2,color: Color,width: int=1):
		# Raster strokes retain the stepped outline, even while weapon joints rotate.
		var count=maxi(1,ceili(maxf(absf(b.x-a.x),absf(b.y-a.y))))
		for i in range(count+1):
			var v=a.lerp(b,float(i)/count).round()
			box(v.x-floorf(width/2.0),v.y-floorf(width/2.0),width,width,color)
	func limb(a: Vector2,elbow: Vector2,hand: Vector2,color: Color,width: int=3):
		line(a,elbow,INK,width+2);line(elbow,hand,INK,width+2)
		line(a,elbow,color,width);line(elbow,hand,color,width)

static func draw_actor(canvas: Node2D, kind: String, pos: Vector2, direction: Vector2, moving: bool, clock: float, attack_state: String, attack_progress: float, tint: Color=Color.WHITE, boss_type: int=0, primary_weapon: String="sword"):
	var facing=-1.0 if direction.x < -0.05 else 1.0
	var p=Pixels.new(canvas,pos,facing,tint)
	var aim=Vector2(direction.x*facing,direction.y).normalized()
	if aim.length_squared()<0.01:aim=Vector2.RIGHT
	var phase=_phase(attack_state)
	var progress=clampf(attack_progress,0.0,1.0)
	var gait=int(floor(clock*9.0))%4 if moving else 0
	var step=([0.0,1.0,0.0,-1.0][gait] if moving else 0.0)
	var active=phase!="idle"
	match kind:
		"owl":_owl(p,aim,step,moving,clock,phase,progress,attack_state,primary_weapon)
		"grunt":_grunt(p,aim,step,phase,progress)
		"archer":_archer(p,aim,step,phase,progress)
		"swift":_swift(p,aim,step,moving,phase,progress)
		"bomber":_bomber(p,step,clock,phase,progress)
		"ghost":_ghost(p,aim,step,moving,clock,phase,progress)
		"herbalist":_herbalist(p,aim,step,phase,progress)
		"sentinel","shield","shield_sentinel","guard":_shield_guard(p,aim,step,phase,progress)
		"assassin","flanker":_assassin(p,aim,step,phase,progress,attack_state)
		"chanter","support":_chanter(p,aim,step,phase,progress,attack_state)
		"hexer","zone":_hexer(p,aim,step,phase,progress)
		"boss":
			match clampi(boss_type,0,5):
				0:_warden(p,aim,step,phase,progress,attack_state)
				1:_alchemist(p,aim,step,clock,phase,progress,attack_state)
				2:_sentinel(p,aim,step,clock,phase,progress,attack_state)
				3:_sovereign(p,aim,step,clock,phase,progress,attack_state)
				4:_tempest_colossus(p,aim,clock,phase,progress)
				5:_eclipse_seraph(p,aim,clock,phase,progress)
		_:
			_grunt(p,aim,step,phase,progress)
	# An attack glint appears on release, never a replacement for the limb motion.
	if active and phase=="release" and progress<0.35 and kind!="ghost":
		p.box(-1,-13 if kind!="boss" else -20,2,1,Color("fff0b5"))

static func _phase(state: String) -> String:
	if state.contains("recover") or state.contains("cooldown"):return "recover"
	if state=="idle" or state=="" or state=="move" or state=="walk" or state.ends_with("_idle") or state.ends_with("_move"):return "idle"
	# A move called charge still has a release and recovery. Only its phase
	# suffix (or the old standalone charge state) may select a windup.
	if state.contains("windup") or state.contains("prepare") or state=="charge":return "windup"
	return "release"

static func _attack(phase: String, progress: float) -> float:
	match phase:
		"windup":return -lerpf(0.25,1.0,progress)
		"release":return lerpf(1.0,0.75,progress)
		"recover":return (1.0-progress)*0.65
	return 0.0

static func _feet(p: Pixels,step: float,color: Color,width: int=3,y: int=7,spread: int=4):
	for side in [-1,1]:
		var stride=step*side
		var x=side*spread+stride
		var lift=-1 if stride>0 else 0
		p.box(x-1,y-1,width,4+lift,INK)
		p.box(x-1,y,width,2+lift,color.darkened(0.25))
		p.box(x-1,y+2+lift,width+1,1,color)

static func _eyes(p: Pixels,y: int,pupil: Color,clock: float=-1.0,wide: bool=false):
	var blink=clock>=0 and fmod(clock,4.8)>4.64
	var spacing=4 if wide else 3
	for x in [-spacing,spacing]:
		p.box(x-1,y,3,1 if blink else 3,Color("fff2d3"))
		if not blink:p.box(x,y+1,1,2,pupil)

static func _sword(p: Pixels,hand: Vector2,angle: float,length: float=11.0,color: Color=Color("c6f1ec")):
	var d=Vector2.RIGHT.rotated(angle)
	var cross=d.orthogonal()
	p.line(hand-d*2,hand+d*length,INK,3)
	p.line(hand+d*2,hand+d*(length-1),color,2)
	p.line(hand+d*3+cross,hand+d*(length-2)+cross,Color("ffffff"),1)
	p.line(hand-cross*3,hand+cross*3,INK,3)
	p.line(hand-cross*2,hand+cross*2,Color("f6c471"),1)
	p.line(hand-d*2,hand,Color("976a56"),1)

static func _bow(p: Pixels,hand: Vector2,aim: Vector2,draw_amount: float,glow: Color=Color("f3cb87")):
	var tangent=aim.orthogonal()
	var top=hand+tangent*7-aim*2
	var bottom=hand-tangent*7-aim*2
	p.line(top,hand+tangent*4+aim*2,INK,3)
	p.line(hand+tangent*4+aim*2,hand-tangent*4+aim*2,INK,3)
	p.line(hand-tangent*4+aim*2,bottom,INK,3)
	p.line(top,hand+tangent*4+aim*2,glow,1)
	p.line(hand+tangent*4+aim*2,hand-tangent*4+aim*2,glow,1)
	p.line(hand-tangent*4+aim*2,bottom,glow,1)
	var string_point=hand-aim*(2+draw_amount*5)
	p.line(top,string_point,Color("ddd3d0"));p.line(string_point,bottom,Color("ddd3d0"))
	if draw_amount>0.05:
		p.line(string_point,hand+aim*6,Color("f7e8ce"))
		p.line(hand+aim*6,hand+aim*4+tangent*2,Color("e9f9ff"))
		p.line(hand+aim*6,hand+aim*4-tangent*2,Color("e9f9ff"))

static func _owl(p: Pixels,aim: Vector2,step: float,moving: bool,clock: float,phase: String,progress: float,state: String,primary_weapon: String="sword"):
	var a=_attack(phase,progress)
	var feather=Color("a97043")
	var dashing=state.contains("dash")
	var weapon=primary_weapon
	# Old callers may still select a pose by its prefix. The explicit primary
	# remains visible when a different weapon is used as a level-up auxiliary.
	if primary_weapon=="sword":
		if state.contains("bow"):weapon="bow"
		elif state.contains("cast") or state.contains("magic"):weapon="staff"
		elif state.contains("dagger"):weapon="dagger"
	_feet(p,step if not dashing else 2.0,Color("f0b654"),3,7,5 if dashing else 4)
	if weapon=="bow":
		# Quiver and a split teal cape make the ranger legible while at rest.
		p.poly([Vector2(-6,-3),Vector2(-10,5-step),Vector2(-5,4),Vector2(-3,7),Vector2(-1,-2)],INK)
		p.poly([Vector2(-5,-2),Vector2(-8,4-step),Vector2(-4,3),Vector2(-3,5),Vector2(-2,-1)],Color("4f9896"))
		p.line(Vector2(-7,-1),Vector2(-8,-10),INK,3)
		p.line(Vector2(-7,-1),Vector2(-8,-10),Color("ad8058"))
		p.box(-10,-11,3,2,Color("c5f1ea"))
	elif weapon=="dagger":
		# The comet scarf and low paired knives are unlike the broad blade stance.
		var tail=4 if dashing else 1+absf(step)
		p.poly([Vector2(-3,-3),Vector2(-8,-4),Vector2(-10-tail,-1),Vector2(-7-tail,0),Vector2(-9-tail,3),Vector2(-4,1)],INK)
		p.poly([Vector2(-3,-2),Vector2(-7,-3),Vector2(-9-tail,-1),Vector2(-6-tail,0),Vector2(-8-tail,2),Vector2(-4,0)],Color("ec8a8d"))
	# Each wing has its own shoulder, elbow and hand, and opposes the leg cycle.
	p.limb(Vector2(-6,-1),Vector2(-9,1-step),Vector2(-8,5-step),feather)
	p.box(-7,-3,14,11,INK);p.box(-6,-3,12,10,feather)
	p.box(-4,-1,8,8,Color("ebce8c"));p.box(-2,1,4,5,Color("fff0b0"))
	p.box(-6,5,12,2,Color("69758a"));p.box(-1,5,2,2,Color("e8ba65"))
	if weapon=="staff":
		p.poly([Vector2(-5,0),Vector2(-2,1),Vector2(0,7),Vector2(-6,7)],Color("8270b2"))
		p.poly([Vector2(5,0),Vector2(2,1),Vector2(0,7),Vector2(6,7)],Color("8270b2"))
		p.box(-1,2,2,2,Color("e3d4ff"))
	# Tufted owl ears and big cream facial discs retain the existing hero identity.
	p.poly([Vector2(-8,-11),Vector2(-8,-4),Vector2(-4,-8),Vector2(0,-7),Vector2(5,-8),Vector2(9,-11),Vector2(8,0),Vector2(5,2),Vector2(-5,2),Vector2(-8,-1)],INK)
	p.poly([Vector2(-7,-10),Vector2(-6,-3),Vector2(6,-3),Vector2(8,-10),Vector2(3,-7),Vector2(-3,-7)],feather)
	p.box(-7,-5,14,5,Color("e8c182"));p.box(-5,-6,4,6,Color("fff0c0"));p.box(2,-6,4,6,Color("fff0c0"))
	_eyes(p,-5,Color("403248"),clock,true)
	p.box(-6,-6,5,1,Color("674932"));p.box(2,-6,5,1,Color("674932"))
	p.poly([Vector2(-1,-2),Vector2(2,-2),Vector2(0,1)],Color("efae4a"))
	p.box(-5,-1,2,1,Color("d59172"));p.box(5,-1,2,1,Color("d59172"))
	if weapon=="bow":
		var firing=state.contains("bow")
		var draw_amount=progress if phase=="windup" and firing else 0.0
		var hand=Vector2(8,2+step) if phase=="idle" or not firing else Vector2(8,-1)+aim*2
		var bow_aim=Vector2(0.9,0.25).normalized() if phase=="idle" or not firing else aim
		if phase=="recover" and firing:hand=hand.lerp(Vector2(8,2+step),progress)
		p.limb(Vector2(6,0),Vector2(8,1),hand,feather)
		if firing and phase!="idle":p.limb(Vector2(-5,1),Vector2(0,2),hand-aim*(2+draw_amount*5),feather,2)
		_bow(p,hand,bow_aim,draw_amount,Color("aadfcd"))
	elif weapon in ["crossbow","gun"]:
		var hand=Vector2(8,1)+aim*(3 if phase=="release" else 0)
		p.limb(Vector2(6,0),Vector2(8,1),hand,feather)
		var end=hand+aim*12
		p.line(hand-aim*3,end,INK,5)
		p.line(hand-aim*2,end,Color("a6d2d7"),3)
		if weapon=="crossbow":
			p.line(end-aim.orthogonal()*6,end+aim.orthogonal()*6,Color("b87b50"),2)
			p.line(hand,end+aim.orthogonal()*6,Color("f5e5c3"),1)
			p.line(hand,end-aim.orthogonal()*6,Color("f5e5c3"),1)
		else:
			p.box(hand.x-2,hand.y+1,4,4,Color("84646c"))
			if phase=="release":_spark(p,end+aim*3,Color("ffe5a2"),4)
	elif weapon=="staff" or weapon=="magic":
		var casting=state.contains("cast") or state.contains("magic") or state.contains("staff")
		var lift=absf(a) if casting else 0.0
		var hand=Vector2(8,2+step-lift*5)
		if phase=="release" and casting:hand+=aim*3
		p.limb(Vector2(6,0),Vector2(9,1-lift*2),hand,feather)
		_moon_staff(p,hand,Color("d1a6ff"))
		if casting and phase!="idle":
			var offhand=Vector2(-7,-1)+aim*maxf(0,a)*3+Vector2(0,-lift*4)
			p.limb(Vector2(-5,1),Vector2(-8,1-lift*3),offhand,feather,2)
		if phase=="release" and casting:_spark(p,hand+Vector2(0,-9),Color("f4e2ff"),4)
	elif weapon in ["dagger","knife","throwing_knife"]:
		var hand=Vector2(8,4+step)
		var rear=Vector2(-8,4-step)
		var blade_angle=0.85
		if phase=="windup":
			hand=Vector2(3,-2-progress*2);rear=Vector2(-5,1-progress*2);blade_angle=-2.0
		elif phase=="release":
			hand=Vector2(6,0)+aim*(5 if not dashing else 7);rear=Vector2(-7,2)-aim*(2 if not dashing else 4);blade_angle=aim.angle()+0.3-progress*0.8
		elif phase=="recover":
			hand=(Vector2(6,0)+aim*5).lerp(Vector2(8,4+step),progress);blade_angle=lerpf(aim.angle()-0.5,0.85,progress)
		p.limb(Vector2(-5,1),Vector2(-7,3-step),rear,feather,2)
		_dagger(p,rear,aim.angle()+2.5,Color("b6f1eb"))
		p.limb(Vector2(6,0),Vector2(8,1),hand,feather,2)
		_dagger(p,hand,blade_angle,Color("e0f9f1"))
	else:
		var hand=Vector2(8,3+step)
		var angle=-0.8
		if phase=="windup":
			hand=Vector2(6-2*progress,-3-3*progress);angle=aim.angle()-1.6-progress*0.9
		elif phase=="release":
			hand=Vector2(6,0)+aim*4;angle=aim.angle()-0.7+progress*1.2
		elif phase=="recover":
			hand=Vector2(9,1).lerp(Vector2(8,3),progress);angle=lerpf(aim.angle()+0.5,-0.8,progress)
		p.limb(Vector2(6,0),Vector2(8,1),hand,feather)
		if weapon=="axe":
			var d=Vector2.RIGHT.rotated(angle)
			p.line(hand-d*2,hand+d*12,INK,3)
			p.line(hand-d*2,hand+d*12,Color("a87953"),1)
			var tip=hand+d*10
			p.poly([tip-d*3-d.orthogonal()*6,tip+d*3-d.orthogonal()*5,tip+d*4+d.orthogonal()*4,tip-d*2+d.orthogonal()*6],INK)
			p.line(tip-d.orthogonal()*4,tip+d.orthogonal()*4,Color("d5e7eb"),4)
		else:_sword(p,hand,angle,10)
	if moving:p.box(-6+step,8,2,1,Color("dba34c"))

static func _dagger(p: Pixels,hand: Vector2,angle: float,color: Color):
	var d=Vector2.RIGHT.rotated(angle)
	var cross=d.orthogonal()
	p.line(hand-d*2,hand+d*5,INK,3)
	p.line(hand+d,hand+d*4,color,2)
	p.line(hand-cross,hand+cross,Color("f1c88a"),1)
	p.line(hand-d*2,hand,Color("805268"),1)

static func _moon_staff(p: Pixels,hand: Vector2,color: Color):
	p.line(hand+Vector2(0,7),hand-Vector2(0,9),INK,3)
	p.line(hand+Vector2(0,7),hand-Vector2(0,9),Color("9e7baa"),1)
	p.poly([hand+Vector2(0,-13),hand+Vector2(4,-10),hand+Vector2(2,-6),hand+Vector2(-2,-6),hand+Vector2(-4,-10)],INK)
	p.poly([hand+Vector2(0,-12),hand+Vector2(3,-10),hand+Vector2(1,-7),hand+Vector2(-2,-8),hand+Vector2(-3,-10)],color)
	p.box(hand.x-1,hand.y-11,2,3,Color("f1e3ff"))

static func _grunt(p: Pixels,aim: Vector2,step: float,phase: String,progress: float):
	var a=_attack(phase,progress)
	_feet(p,step,Color("bd6077"),3,6,3)
	p.limb(Vector2(-5,-1),Vector2(-7,1+step),Vector2(-7,4+step),Color("ae4c67"),2)
	p.box(-6,-2,12,9,INK);p.box(-5,-2,10,8,Color("a93f60"));p.box(-3,1,6,3,Color("da6b7b"))
	p.poly([Vector2(-7,-9),Vector2(-2,-6),Vector2(3,-6),Vector2(8,-9),Vector2(6,1),Vector2(-5,1)],INK)
	p.box(-6,-6,12,6,Color("df788e"));p.box(-4,-8,8,7,Color("df788e"))
	p.box(-7,-10,2,4,Color("efd2b0"));p.box(6,-10,2,4,Color("efd2b0"))
	_eyes(p,-5,Color("79324c"));p.box(-2,-1,5,1,Color("722b43"));p.box(-1,-1,1,2,Color("fff0ca"));p.box(2,-1,1,2,Color("fff0ca"))
	var hand=Vector2(7,3-step)
	if a<0:hand=Vector2(6,-3-a*-3)
	elif a>0:hand=Vector2(6,0)+aim*4*a
	p.limb(Vector2(5,1),Vector2(7,1),hand,Color("df788e"),2)
	_sword(p,hand,aim.angle()+(-2.0 if a<0 else 0.5 if a>0 else -0.7),6,Color("c5bbcd"))

static func _archer(p: Pixels,aim: Vector2,step: float,phase: String,progress: float):
	_feet(p,step,Color("84727f"),3,6,3)
	p.box(-7,-3,3,10,INK);p.box(-7,-5,2,8,Color("bc8767"));p.line(Vector2(-7,-5),Vector2(-7,-10),Color("d3e5d9"))
	p.poly([Vector2(-5,-3),Vector2(5,-3),Vector2(7,7),Vector2(-6,7)],INK)
	p.box(-4,-2,9,8,Color("388f94"));p.box(-4,3,9,2,Color("ad8060"))
	p.poly([Vector2(-7,-4),Vector2(-4,-9),Vector2(2,-12),Vector2(6,-8),Vector2(7,1),Vector2(-7,1)],INK)
	p.poly([Vector2(-6,-4),Vector2(-3,-8),Vector2(2,-10),Vector2(5,-7),Vector2(6,0),Vector2(-6,0)],Color("56bdb5"))
	p.box(-4,-5,9,5,Color("535672"));p.box(-3,-5,7,3,Color("d2caae"));p.box(-3,-4,2,1,INK);p.box(2,-4,2,1,INK)
	p.box(-2,0,5,2,Color("9de0c4"))
	var draw_amount=progress if phase=="windup" else 0.0
	var hand=Vector2(7,-1)+aim*(1 if phase!="recover" else 0)
	p.limb(Vector2(4,1),Vector2(6,1),hand,Color("57b5ac"),2)
	p.limb(Vector2(-3,1),Vector2(0,2+step),hand-aim*(2+draw_amount*5),Color("57b5ac"),2)
	_bow(p,hand,aim,draw_amount,Color("d5ae78"))

static func _swift(p: Pixels,aim: Vector2,step: float,moving: bool,phase: String,progress: float):
	var a=_attack(phase,progress)
	var wing=3+step*2 if moving else 2.0
	# Bat wings fold at the elbow and alternate with the feet rather than translate.
	for side in [-1,1]:
		p.poly([Vector2(side*3,-3),Vector2(side*(8+wing),-8-step),Vector2(side*10,0),Vector2(side*7,-1),Vector2(side*6,3)],INK)
		p.poly([Vector2(side*4,-3),Vector2(side*(7+wing),-6-step),Vector2(side*9,-1),Vector2(side*6,1)],Color("666cca"))
		p.line(Vector2(side*4,-2),Vector2(side*(7+wing),-6-step),Color("a5c6ff"))
	_feet(p,step*2,Color("9296e5"),2,5,2)
	p.box(-4,-4,8,10,INK);p.box(-3,-3,6,8,Color("505790"));p.box(-2,1,4,3,Color("c2cfef"))
	p.poly([Vector2(-5,-10),Vector2(0,-6),Vector2(5,-10),Vector2(4,-1),Vector2(-4,-1)],INK)
	p.poly([Vector2(-4,-8),Vector2(0,-5),Vector2(4,-8),Vector2(3,-2),Vector2(-3,-2)],Color("8b94db"))
	p.box(-3,-4,2,1,Color("f0f8ff"));p.box(2,-4,2,1,Color("f0f8ff"));p.box(-1,-2,2,2,Color("e3e9ff"))
	var hand=Vector2(5,1)+aim*maxf(0,a)*5
	if a<0:hand+=Vector2(-2,-4)
	p.limb(Vector2(3,0),Vector2(5,1-step),hand,Color("7d8ccd"),2)
	_sword(p,hand,aim.angle()+(-1.8 if a<0 else 0.2),5,Color("edf5ff"))

static func _bomber(p: Pixels,step: float,clock: float,phase: String,progress: float):
	var a=absf(_attack(phase,progress))
	_feet(p,step,Color("9c72c5"),3,6,4)
	p.poly([Vector2(-7,-5),Vector2(-3,-8),Vector2(4,-8),Vector2(8,-4),Vector2(8,5),Vector2(4,8),Vector2(-5,8),Vector2(-8,4)],INK)
	p.box(-7,-3,14,8,Color("76519c"));p.box(-5,-6,10,12,Color("76519c"));p.box(-4,-4,8,4,Color("ad83c0"))
	p.box(-4,-3,2,2,Color("fff0b6"));p.box(3,-3,2,2,Color("fff0b6"));p.box(-2,2,4,2,Color("342739"))
	p.box(-3,5,7,2,Color("4b3b6b"));p.box(-1,5,3,2,Color("eac47d"))
	var bomb=Vector2(8,-1-a*7)
	if phase=="release":bomb=Vector2(2+progress*3,1)
	elif phase=="recover":bomb=Vector2(5,1).lerp(Vector2(8,-1),progress)
	p.limb(Vector2(-5,2),Vector2(-8,3+step),Vector2(-8,5+step),Color("9572b0"),2)
	p.limb(Vector2(5,1),Vector2(8,1),bomb+Vector2(0,2),Color("9572b0"),2)
	p.box(bomb.x-3,bomb.y-2,7,6,INK);p.box(bomb.x-2,bomb.y-3,5,8,INK)
	p.box(bomb.x-2,bomb.y-1,5,4,Color("464757"));p.box(bomb.x-1,bomb.y-2,2,2,Color("8990a1"))
	p.line(bomb+Vector2(0,-4),bomb+Vector2(2,-6),Color("bd9871"))
	_spark(p,bomb+Vector2(2,-6),Color("ffd16c"),1+(int(clock*10)%2))

static func _ghost(p: Pixels,aim: Vector2,step: float,moving: bool,clock: float,phase: String,progress: float):
	var a=_attack(phase,progress)
	var skirt=step if moving else 0.0
	p.poly([Vector2(-7,7),Vector2(-7,-3),Vector2(-4,-8),Vector2(0,-10),Vector2(5,-8),Vector2(8,-3),Vector2(8,8),Vector2(4,5+skirt),Vector2(1,8),Vector2(-2,5-skirt),Vector2(-5,8)],INK)
	p.poly([Vector2(-6,5),Vector2(-6,-3),Vector2(-3,-7),Vector2(0,-8),Vector2(4,-7),Vector2(7,-3),Vector2(7,6),Vector2(3,3+skirt),Vector2(1,6),Vector2(-2,3-skirt),Vector2(-4,6)],Color("9ee0df"))
	p.box(-4,-4,8,6,Color("c8f3e8"));p.box(-3,-3,2,3,Color("426b82"));p.box(2,-3,2,3,Color("426b82"));p.box(0,1,2,2,Color("729fad"))
	var reach=4+maxf(0,a)*5
	p.limb(Vector2(-5,0),Vector2(-7,-1-step),Vector2(-8,-3-step),Color("81c6d1"),2)
	p.limb(Vector2(5,0),Vector2(7,-1),Vector2(5,0)+aim*reach+Vector2(0,-absf(a)*2),Color("b3ece4"),2)
	if phase!="idle":_spark(p,Vector2(5,0)+aim*(reach+2),Color("e5ffff"),2)

static func _herbalist(p: Pixels,aim: Vector2,step: float,phase: String,progress: float):
	_feet(p,step,Color("705d45"),2,6,3)
	p.box(-5,-2,11,10,INK);p.box(-4,-1,9,8,Color("5e9160"));p.box(-2,1,5,6,Color("caad7a"))
	p.box(-5,4,11,2,Color("66563d"));p.box(-1,4,2,2,Color("f5d078"))
	p.box(-4,-6,9,6,INK);p.box(-3,-6,7,5,Color("efd5a6"));p.box(-2,-4,1,1,INK);p.box(2,-4,1,1,INK)
	p.poly([Vector2(-7,-4),Vector2(-4,-8),Vector2(-1,-12),Vector2(3,-10),Vector2(5,-6),Vector2(8,-4)],INK)
	p.poly([Vector2(-6,-5),Vector2(-2,-9),Vector2(0,-11),Vector2(3,-9),Vector2(4,-6),Vector2(6,-5)],Color("78b26f"))
	p.box(-5,-5,11,2,Color("a3c989"));p.box(2,-9,2,3,Color("cde5a2"))
	var a=_attack(phase,progress)
	var hand=Vector2(7,2-absf(a)*6)+aim*maxf(0,a)*3
	p.limb(Vector2(-4,1),Vector2(-6,2+step),Vector2(-6,5+step),Color("6ca66e"),2)
	p.limb(Vector2(4,1),Vector2(6,1),hand,Color("6ca66e"),2)
	_flask(p,hand+Vector2(0,-2),Color("adf6aa"))

static func _shield_guard(p: Pixels,aim: Vector2,step: float,phase: String,progress: float):
	# Squared helmet, planted boots and a large stepped kite shield.
	var armor=Color("8a9996")
	var a=_attack(phase,progress)
	_feet(p,step*0.6,Color("b89c68"),4,7,4)
	p.limb(Vector2(-5,-1),Vector2(-8,1+step),Vector2(-8,4+step),armor,3)
	p.line(Vector2(-9,6+step),Vector2(-9,-10+step),INK,3)
	p.line(Vector2(-9,6+step),Vector2(-9,-10+step),Color("bd9e67"))
	p.poly([Vector2(-11,-10+step),Vector2(-9,-15+step),Vector2(-7,-10+step)],Color("d2e8df"))
	p.box(-6,-4,12,11,INK);p.box(-5,-3,10,9,armor)
	p.box(-3,-2,6,7,Color("b9c8bd"));p.box(-5,4,10,2,Color("5b726e"))
	p.box(-7,-11,14,9,INK);p.box(-6,-10,12,7,Color("b0bca8"))
	p.box(-7,-7,14,4,Color("657978"));p.box(-5,-6,10,2,INK)
	p.box(-4,-6,3,1,Color("fff1b8"));p.box(2,-6,3,1,Color("fff1b8"))
	p.box(-1,-12,3,5,Color("d7ba77"));p.box(-5,-10,2,1,Color("e2ddba"))
	var hand=Vector2(7,1-step*0.5)
	if phase=="windup":hand=Vector2(6-progress*3,1-progress*2)
	elif phase=="release":hand=Vector2(7,0)+aim*(5-progress)
	elif phase=="recover":hand=(Vector2(7,0)+aim*4).lerp(hand,progress)
	p.limb(Vector2(5,-1),Vector2(7,-1),hand,armor,3)
	p.poly([hand+Vector2(-4,-6),hand+Vector2(4,-6),hand+Vector2(5,3),hand+Vector2(0,8),hand+Vector2(-5,3)],INK)
	p.poly([hand+Vector2(-3,-5),hand+Vector2(3,-5),hand+Vector2(4,2),hand+Vector2(0,6),hand+Vector2(-4,2)],Color("c8af70"))
	p.poly([hand+Vector2(-2,-4),hand+Vector2(2,-4),hand+Vector2(3,2),hand+Vector2(0,5),hand+Vector2(-3,2)],Color("536b79"))
	p.line(hand+Vector2(0,-3),hand+Vector2(0,3),Color("ecdea1"),1)
	p.line(hand+Vector2(-2,0),hand+Vector2(2,0),Color("ecdea1"),1)
	if a>0 and phase=="release":p.box(hand.x+3,hand.y-4,1,4,Color("fff5cd"))

static func _assassin(p: Pixels,aim: Vector2,step: float,phase: String,progress: float,state: String):
	# Low narrow hood, streaming scarf and independently posed paired knives.
	var cloth=Color("694a83")
	var crouch=2.0*progress if phase=="windup" else 0.0
	var reach=5.0 if phase=="release" else 0.0
	_feet(p,step*1.5,Color("9d7c9a"),2,6,4)
	p.poly([Vector2(-4,-4),Vector2(-11,-3-step),Vector2(-8,0),Vector2(-13,2+step),Vector2(-5,2)],INK)
	p.poly([Vector2(-4,-3),Vector2(-9,-2-step),Vector2(-6,0),Vector2(-10,1+step),Vector2(-5,1)],Color("ce6b99"))
	p.poly([Vector2(-5,-3+crouch),Vector2(4,-4+crouch),Vector2(6,5),Vector2(1,7),Vector2(-6,5)],INK)
	p.box(-4,-2+crouch,8,7-crouch,cloth);p.box(-4,3,9,2,Color("c2869c"))
	p.poly([Vector2(-6,-5+crouch),Vector2(-3,-10+crouch),Vector2(4,-12+crouch),Vector2(6,-7+crouch),Vector2(6,0+crouch),Vector2(-6,0+crouch)],INK)
	p.poly([Vector2(-5,-5+crouch),Vector2(-2,-9+crouch),Vector2(3,-10+crouch),Vector2(5,-6+crouch),Vector2(4,-1+crouch),Vector2(-5,-1+crouch)],cloth)
	p.box(-4,-5+crouch,9,3,Color("262537"));p.box(-3,-4+crouch,3,1,Color("ffa8c4"));p.box(2,-4+crouch,2,1,Color("ffa8c4"))
	p.box(-3,-1+crouch,8,2,Color("b86c9a"))
	var front=Vector2(7,3-step)+aim*reach
	var rear=Vector2(-7,3+step)-aim*reach*0.4
	var angle=aim.angle()+0.7
	if phase=="windup":front=Vector2(2,-1+crouch);rear=Vector2(-2,0+crouch);angle=-2.1
	elif phase=="release":front=Vector2(6,-1)+aim*reach;rear=Vector2(2,2)+aim*reach;angle=aim.angle()-0.3
	elif phase=="recover":front=(Vector2(6,-1)+aim*4).lerp(front,progress);angle=lerpf(aim.angle()-0.3,angle,progress)
	p.limb(Vector2(-4,0+crouch),Vector2(-6,2),rear,Color("967494"),2)
	_dagger(p,rear,angle+0.55,Color("b1e5df"))
	p.limb(Vector2(4,0+crouch),Vector2(6,1),front,Color("967494"),2)
	_dagger(p,front,angle,Color("e6e8ef"))
	if state.contains("shadow") and phase=="windup":p.box(-2,-8+crouch,2,1,Color("f3a5d6"))

static func _chanter(p: Pixels,aim: Vector2,step: float,phase: String,progress: float,state: String):
	# Tall ceremonial fan and a hanging bell identify the group-support enemy.
	var cloth=Color("b18551")
	var a=_attack(phase,progress)
	_feet(p,step*0.65,Color("d4b57a"),2,7,3)
	p.poly([Vector2(-4,-4),Vector2(4,-4),Vector2(8,8),Vector2(2,7+step),Vector2(0,9),Vector2(-3,7-step),Vector2(-7,8)],INK)
	p.poly([Vector2(-3,-3),Vector2(3,-3),Vector2(6,7),Vector2(1,6+step),Vector2(0,7),Vector2(-3,6-step),Vector2(-5,7)],Color("907451"))
	p.box(-2,-3,4,9,Color("e0bc78"));p.box(-1,0,2,2,Color("69c5b2"))
	p.box(-5,-9,10,7,INK);p.box(-4,-8,8,5,Color("d5c5a0"));p.box(-3,-6,2,1,INK);p.box(2,-6,2,1,INK)
	p.box(-1,-4,2,2,Color("5d4b47"))
	p.poly([Vector2(-7,-8),Vector2(-8,-12),Vector2(-4,-11),Vector2(0,-16),Vector2(4,-11),Vector2(8,-12),Vector2(7,-8)],INK)
	p.poly([Vector2(-6,-9),Vector2(-6,-11),Vector2(-3,-10),Vector2(0,-14),Vector2(3,-10),Vector2(6,-11),Vector2(6,-9)],Color("e5c87f"))
	p.box(-1,-12,2,3,Color("88ddc5"))
	var lift=absf(a)*5
	var hand=Vector2(8,2-lift)
	var book_hand=Vector2(-7,3-lift)
	if phase=="release":hand+=aim*3;book_hand.x-=2
	if state.contains("pulse"):
		book_hand=Vector2(-7,2-lift*0.3)
		if phase=="windup":hand=Vector2(8-progress*2,-1-progress*2)
		elif phase=="release":hand=Vector2(7,-1)+aim*(6-progress*2)
		elif phase=="recover":hand=(Vector2(7,-1)+aim*4).lerp(Vector2(8,2),progress)
	p.limb(Vector2(-4,-1),Vector2(-6,1-lift*0.5),book_hand,cloth,2)
	# Open hymn book remains firmly attached to the hand.
	p.poly([book_hand+Vector2(-4,-3),book_hand+Vector2(0,-2),book_hand+Vector2(4,-3),book_hand+Vector2(4,2),book_hand+Vector2(0,3),book_hand+Vector2(-4,2)],INK)
	p.box(book_hand.x-3,book_hand.y-2,3,3,Color("eee0b1"));p.box(book_hand.x+1,book_hand.y-2,3,3,Color("c9ba95"))
	p.limb(Vector2(4,-1),Vector2(6,1-lift*0.5),hand,cloth,2)
	p.line(hand+Vector2(0,5),hand+Vector2(0,-11),INK,3);p.line(hand+Vector2(0,5),hand+Vector2(0,-11),Color("c7a963"))
	p.line(hand+Vector2(0,-11),hand+Vector2(4,-11),Color("e3cc84"))
	p.poly([hand+Vector2(2,-10),hand+Vector2(4,-10),hand+Vector2(6,-6),hand+Vector2(0,-6)],INK)
	p.poly([hand+Vector2(2,-9),hand+Vector2(4,-9),hand+Vector2(5,-7),hand+Vector2(1,-7)],Color("8bd8c4"))
	p.box(hand.x+3,hand.y-6,1,2,Color("f8dda0"))
	if phase=="release":_spark(p,hand+Vector2(3,-9),Color("e3ffbc"),3)

static func _hexer(p: Pixels,aim: Vector2,step: float,phase: String,progress: float):
	# Crooked brim, asymmetric trailing robe and a hooked ground-casting staff.
	var cloth=Color("526f74")
	var a=_attack(phase,progress)
	_feet(p,step*0.65,Color("719195"),2,7,3)
	p.poly([Vector2(-4,-4),Vector2(4,-4),Vector2(7,8),Vector2(3,7+step),Vector2(1,9),Vector2(-2,7-step),Vector2(-8,8)],INK)
	p.poly([Vector2(-3,-3),Vector2(3,-3),Vector2(5,7),Vector2(2,6+step),Vector2(1,7),Vector2(-2,6-step),Vector2(-6,7)],cloth)
	p.box(-2,-2,3,8,Color("719285"));p.box(-3,3,8,2,Color("3e485b"))
	p.box(-5,-8,11,7,INK);p.box(-4,-7,9,5,Color("354052"));p.box(-3,-5,3,1,Color("bfeca9"));p.box(2,-5,2,1,Color("bfeca9"))
	p.poly([Vector2(-9,-7),Vector2(-5,-10),Vector2(-1,-15),Vector2(6,-16),Vector2(3,-12),Vector2(5,-9),Vector2(9,-7)],INK)
	p.poly([Vector2(-7,-8),Vector2(-4,-9),Vector2(0,-14),Vector2(4,-15),Vector2(1,-12),Vector2(4,-9),Vector2(7,-8)],Color("627e83"))
	p.box(-5,-8,11,2,Color("8db793"));p.box(0,-10,2,2,Color("d8e4ac"))
	var hand=Vector2(8,3-step)
	var offhand=Vector2(-7,2+step)
	if phase=="windup":hand=Vector2(8,-2-progress*3);offhand=Vector2(-6,-2-progress*3)
	elif phase=="release":hand=Vector2(7,4)+aim*2;offhand=Vector2(-4,3)+aim*4
	elif phase=="recover":hand=Vector2(8,6).lerp(hand,progress);offhand=Vector2(-3,5).lerp(offhand,progress)
	p.limb(Vector2(-4,0),Vector2(-7,1),offhand,cloth,2)
	p.limb(Vector2(4,0),Vector2(7,1),hand,cloth,2)
	p.line(hand+Vector2(0,7),hand+Vector2(0,-10),INK,3);p.line(hand+Vector2(0,7),hand+Vector2(0,-10),Color("a4957b"))
	p.line(hand+Vector2(0,-10),hand+Vector2(-4,-12),INK,3);p.line(hand+Vector2(0,-10),hand+Vector2(-4,-12),Color("a4957b"))
	p.line(hand+Vector2(-4,-12),hand+Vector2(-6,-9),Color("d6c4a0"),1)
	p.poly([hand+Vector2(-5,-9),hand+Vector2(-2,-7),hand+Vector2(-5,-4),hand+Vector2(-8,-7)],INK)
	p.poly([hand+Vector2(-5,-8),hand+Vector2(-3,-7),hand+Vector2(-5,-5),hand+Vector2(-7,-7)],Color("afd992"))
	if phase=="release":_spark(p,offhand+Vector2(0,2),Color("def2ab"),2)

static func _flask(p: Pixels,at: Vector2,color: Color):
	p.box(at.x-1,at.y-3,3,3,INK);p.box(at.x-2,at.y-1,5,5,INK)
	p.box(at.x-1,at.y,3,3,color);p.box(at.x-1,at.y-3,3,1,Color("ceae72"));p.box(at.x-1,at.y,1,1,Color("ffffff"))

static func _spark(p: Pixels,at: Vector2,color: Color,size: int):
	p.box(at.x-size,at.y,size*2+1,1,color);p.box(at.x,at.y-size,1,size*2+1,color)

static func _warden(p: Pixels,aim: Vector2,step: float,phase: String,progress: float,state: String):
	var bark=Color("667543")
	var a=_attack(phase,progress)
	var roots=state.contains("rootline")
	var wheel=state.contains("thornwheel")
	_feet(p,step,bark,5,9,7)
	p.limb(Vector2(-9,-2),Vector2(-12,1+step),Vector2(-11,7+step),bark,4)
	p.poly([Vector2(-10,-7),Vector2(10,-7),Vector2(11,9),Vector2(5,12),Vector2(-7,11),Vector2(-11,6)],INK)
	p.box(-9,-6,18,15,bark);p.box(-6,-4,12,12,Color("7e9250"));p.box(-3,-3,6,11,Color("4c5c36"))
	p.line(Vector2(-7,-1),Vector2(-6,7),Color("b0bd67"));p.line(Vector2(6,-2),Vector2(5,5),Color("a7b864"))
	p.box(-7,-12,14,10,INK);p.box(-6,-11,12,8,Color("929b59"));p.box(-5,-8,4,2,Color("f3d98b"));p.box(2,-8,4,2,Color("f3d98b"));p.box(-1,-5,3,2,Color("394634"))
	# Asymmetric branch antlers and a leafy mantle identify the garden guardian.
	for side in [-1,1]:
		p.line(Vector2(side*5,-11),Vector2(side*9,-17),INK,3)
		p.line(Vector2(side*5,-11),Vector2(side*9,-17),Color("b39a60"))
		p.line(Vector2(side*7,-14),Vector2(side*12,-15),Color("b39a60"))
		p.box(side*10-2,-16,4,2,Color("8abd6b"))
		p.poly([Vector2(side*7,-7),Vector2(side*13,-7),Vector2(side*11,-2)],Color("99ba5d"))
	var hand=Vector2(12,3-step)
	if phase=="windup":hand=Vector2(10,-3-progress*7)
	elif phase=="release":hand=Vector2(10,0)+aim*6
	elif phase=="recover":hand=Vector2(12,-1).lerp(Vector2(12,3),progress)
	var angle=aim.angle()-2.2 if a<0 else aim.angle()+0.5 if a>0 else -0.6
	if roots:
		if phase=="windup":hand=Vector2(11,-2-progress*4);angle=-PI/2
		elif phase=="release":hand=Vector2(12,-2+progress*3);angle=PI/2
		elif phase=="recover":hand=Vector2(12,1).lerp(Vector2(12,3),progress);angle=lerpf(PI/2,-0.6,progress)
	elif wheel:
		if phase=="windup":hand=Vector2(5,-10-progress*4);angle=PI
		elif phase=="release":hand=Vector2(11,1);angle=progress*PI*1.25-0.4
		elif phase=="recover":hand=Vector2(11,1).lerp(Vector2(12,3),progress);angle=lerpf(PI*0.85,-0.6,progress)
		var brace=hand-Vector2.RIGHT.rotated(angle)*3
		p.limb(Vector2(-9,-2),Vector2(-11,-8 if phase=="windup" else 1),brace,bark,4)
	p.limb(Vector2(9,-3),Vector2(12,-7 if wheel and phase=="windup" else -1),hand,bark,4)
	var tip=hand+Vector2.RIGHT.rotated(angle)*13
	p.line(hand-Vector2.RIGHT.rotated(angle)*3,tip,INK,4);p.line(hand,tip,Color("a48653"),2)
	p.poly([tip+Vector2(-4,-4),tip+Vector2(4,-4),tip+Vector2(6,1),tip+Vector2(2,5),tip+Vector2(-4,2)],INK)
	p.poly([tip+Vector2(-3,-3),tip+Vector2(3,-3),tip+Vector2(5,0),tip+Vector2(2,4),tip+Vector2(-3,1)],Color("bad08a"))
	if state.contains("charge") and phase=="windup":p.box(-5,-6,10,1,Color("fff3a7"))
	if roots and phase=="release":p.box(tip.x-3,tip.y+2,7,1,Color("dded9c"))

static func _alchemist(p: Pixels,aim: Vector2,step: float,clock: float,phase: String,progress: float,state: String):
	_feet(p,step,Color("82625a"),4,10,6)
	p.poly([Vector2(-8,-7),Vector2(8,-7),Vector2(12,12),Vector2(-11,12)],INK)
	p.poly([Vector2(-7,-6),Vector2(7,-6),Vector2(10,10),Vector2(-9,10)],Color("a24546"))
	p.box(-3,-3,7,12,Color("de9061"));p.box(-8,5,17,3,Color("5d3f41"))
	p.box(-7,6,3,4,Color("f8b568"));p.box(5,6,3,4,Color("f0cf82"))
	p.box(-7,-13,14,10,INK);p.box(-6,-12,12,8,Color("d2936d"))
	p.box(-8,-11,17,4,Color("573e4d"));p.box(-6,-10,5,3,Color("a1e1d6"));p.box(2,-10,5,3,Color("fce59b"));p.box(-1,-9,3,1,Color("b39075"))
	p.box(-3,-5,7,2,Color("f1d8b0"));p.box(-1,-4,3,2,Color("e6bd8e"))
	# Tall split flame-shaped hat and two visible potions.
	p.poly([Vector2(-7,-13),Vector2(-6,-19),Vector2(-1,-15),Vector2(3,-21),Vector2(7,-13)],INK)
	p.poly([Vector2(-6,-13),Vector2(-5,-17),Vector2(-1,-14),Vector2(3,-18),Vector2(6,-13)],Color("f19b58"))
	var a=_attack(phase,progress)
	var hand=Vector2(12,2)+aim*maxf(0,a)*4+Vector2(0,-absf(a)*7)
	var other=Vector2(-11,5+step)
	var cross=state.contains("cinder_cross")
	var bloom=state.contains("ember_bloom")
	if cross:
		if phase=="windup":hand=Vector2(3,-5).lerp(Vector2(-5,-7),progress);other=Vector2(-3,-2).lerp(Vector2(5,-3),progress)
		elif phase=="release":hand=Vector2(16,-2+progress*4);other=Vector2(-16,-2+progress*4)
		elif phase=="recover":hand=Vector2(16,2).lerp(Vector2(12,2),progress);other=Vector2(-16,2).lerp(Vector2(-11,5),progress)
	elif bloom:
		if phase=="windup":hand=Vector2(11,-6-progress*7);other=Vector2(-11,-6-progress*7)
		elif phase=="release":hand=Vector2(15,-7+progress*8);other=Vector2(-15,-7+progress*8)
		elif phase=="recover":hand=Vector2(15,1).lerp(Vector2(12,2),progress);other=Vector2(-15,1).lerp(Vector2(-11,5),progress)
	p.limb(Vector2(-8,-3),Vector2(-10,-5 if bloom else step),other,Color("bc6250"),3)
	_flask(p,other+Vector2(0,-3),Color("fdca70"))
	p.limb(Vector2(8,-4),Vector2(10,-5 if bloom else -2),hand,Color("bc6250"),3)
	_flask(p,hand+Vector2(0,-3),Color("ffae59"))
	if phase=="windup" or phase=="release":
		_spark(p,hand+Vector2(0,-7),Color("ffe8a1"),2+int(absf(a)*2))
		p.box(hand.x+4,hand.y-8-int(clock*10)%3,1,2,Color("ffac60"))
		if cross or bloom:_spark(p,other+Vector2(0,-7),Color("ffe8a1"),2+int(absf(a)*2))

static func _sentinel(p: Pixels,aim: Vector2,step: float,clock: float,phase: String,progress: float,state: String):
	var a=_attack(phase,progress)
	var lance=state.contains("prism_lance")
	var spokes=state.contains("crystal_spokes")
	_feet(p,step,Color("809acb"),4,10,6)
	p.poly([Vector2(-9,-8),Vector2(9,-8),Vector2(10,8),Vector2(0,13),Vector2(-10,8)],INK)
	p.poly([Vector2(-8,-7),Vector2(8,-7),Vector2(9,7),Vector2(0,11),Vector2(-9,7)],Color("6b77b0"))
	p.poly([Vector2(0,-7),Vector2(6,-2),Vector2(3,7),Vector2(0,10),Vector2(-4,5),Vector2(-5,-2)],Color("acd5e5"))
	p.poly([Vector2(0,-6),Vector2(4,-2),Vector2(0,5),Vector2(-3,-1)],Color("dcf8ee"))
	p.box(-6,-13,13,7,INK);p.box(-5,-12,11,6,Color("8da7ca"));p.box(-4,-9,9,2,Color("e4feff"));p.box(-1,-9,3,2,Color("485b98"))
	for side in [-1,1]:
		p.poly([Vector2(side*5,-12),Vector2(side*8,-19),Vector2(side*9,-10)],INK)
		p.poly([Vector2(side*6,-12),Vector2(side*8,-17),Vector2(side*8,-10)],Color("b6eef1"))
		var hand=Vector2(side*(12+maxf(0,a)*5),1-absf(a)*5+step*side)
		if lance:
			if side<0:hand=Vector2(-7,-2-absf(a)*2)
			elif phase=="windup":hand=Vector2(8-progress*3,-2)
			elif phase=="release":hand=Vector2(8,-3)+aim*(8-progress*2)
			elif phase=="recover":hand=(Vector2(8,-3)+aim*6).lerp(Vector2(12,1),progress)
		elif spokes:
			if phase=="windup":hand=Vector2(side*(10+progress*2),-7-progress*5)
			elif phase=="release":hand=Vector2(side*19,-3+progress*2)
			elif phase=="recover":hand=Vector2(side*19,-1).lerp(Vector2(side*12,1),progress)
		p.limb(Vector2(side*8,-5),Vector2(side*12,-3),hand,Color("809bc9"),4)
		if lance and side>0:
			var tip=hand+aim*(10 if phase=="release" else 7)
			var cross=aim.orthogonal()*3
			p.poly([hand-aim*3-cross,tip,hand-aim*3+cross],INK)
			p.poly([hand-aim*2-cross*0.55,tip-aim,hand-aim*2+cross*0.55],Color("c7f6ee"))
			p.line(hand,tip-aim,Color("ffffff"))
		else:
			p.poly([hand+Vector2(-3,-2),hand+Vector2(0,-7),hand+Vector2(3,-2),hand+Vector2(2,4),hand+Vector2(-2,4)],INK)
			p.poly([hand+Vector2(-2,-2),hand+Vector2(0,-5),hand+Vector2(2,-2),hand+Vector2(1,3),hand+Vector2(-1,3)],Color("bde9f0"))
		if phase=="release":_spark(p,hand+aim*4,Color("f2ffff"),3)
	p.poly([Vector2(-2,-14),Vector2(0,-21),Vector2(3,-14),Vector2(0,-11)],Color("c7aef2"))

static func _sovereign(p: Pixels,aim: Vector2,step: float,clock: float,phase: String,progress: float,state: String):
	var a=_attack(phase,progress)
	var eclipse=state.contains("eclipse")
	var nightfall=state.contains("nightfall")
	# The sovereign has a crown, layered split cape, mask, scepter and long sabre.
	p.poly([Vector2(-8,-8),Vector2(8,-8),Vector2(14,12),Vector2(8,10+step),Vector2(5,14),Vector2(0,10),Vector2(-5,14),Vector2(-9,10-step),Vector2(-14,12)],INK)
	p.poly([Vector2(-7,-7),Vector2(7,-7),Vector2(12,10),Vector2(7,8+step),Vector2(4,12),Vector2(0,8),Vector2(-4,12),Vector2(-8,8-step),Vector2(-12,10)],Color("5e387e"))
	_feet(p,step,Color("b496c7"),3,10,5)
	p.box(-6,-6,13,15,INK);p.box(-5,-5,11,13,Color("8961a8"));p.box(-2,-4,5,12,Color("392b58"))
	p.box(-5,4,11,2,Color("e2bc73"));p.box(-1,3,3,4,Color("d8a4de"))
	p.box(-7,-13,15,9,INK);p.box(-6,-12,13,7,Color("a582bc"));p.box(-5,-10,11,4,Color("302440"))
	p.box(-4,-9,3,1,Color("e9c8ff"));p.box(3,-9,3,1,Color("e9c8ff"));p.box(-1,-7,3,2,Color("ded3e2"))
	p.poly([Vector2(-8,-17),Vector2(-4,-14),Vector2(0,-20),Vector2(4,-14),Vector2(9,-17),Vector2(6,-11),Vector2(-6,-11)],INK)
	p.poly([Vector2(-7,-16),Vector2(-3,-13),Vector2(0,-18),Vector2(4,-13),Vector2(8,-16),Vector2(5,-12),Vector2(-5,-12)],Color("e9c278"))
	p.box(-1,-15,3,2,Color("c578dc"))
	var offhand=Vector2(-11,2-absf(a)*3)
	if eclipse:
		if phase=="windup":offhand=Vector2(-10+progress*4,-4-progress*6)
		elif phase=="release":offhand=Vector2(-5,-10)
		elif phase=="recover":offhand=Vector2(-5,-10).lerp(Vector2(-11,2),progress)
	elif nightfall:
		if phase=="windup":offhand=Vector2(-11,-2-progress*7)
		elif phase=="release":offhand=Vector2(-11,-8+fmod(progress*3.0,1.0)*14)
		elif phase=="recover":offhand=Vector2(-11,6).lerp(Vector2(-11,2),progress)
	p.limb(Vector2(-6,-3),Vector2(-10,-1),offhand,Color("9b77b9"),3)
	p.line(offhand+Vector2(0,7),offhand-Vector2(0,10),INK,3);p.line(offhand+Vector2(0,7),offhand-Vector2(0,10),Color("d5ae75"))
	p.poly([offhand+Vector2(0,-14),offhand+Vector2(3,-10),offhand+Vector2(0,-7),offhand+Vector2(-3,-10)],Color("ce9de8"))
	var hand=Vector2(10,1-step)
	if a<0:hand=Vector2(8,-7-progress*2)
	elif a>0:hand=Vector2(8,-2)+aim*6
	var blade_angle=aim.angle()+(-2.2 if a<0 else -0.5+progress*1.3 if a>0 else -0.9)
	if eclipse or nightfall:
		hand=Vector2(12,3+step);blade_angle=0.95
		if phase=="release" and nightfall:hand=Vector2(12,0)+aim*2;blade_angle=aim.angle()+0.7
	p.limb(Vector2(6,-3),Vector2(9,-1),hand,Color("9b77b9"),3)
	_sword(p,hand,blade_angle,14,Color("d6c4f1"))
	if eclipse and phase!="idle":
		var orb=offhand+Vector2(0,-13)
		var size=3+int(absf(a)*2)
		p.poly([orb+Vector2(0,-size),orb+Vector2(size,0),orb+Vector2(0,size),orb+Vector2(-size,0)],Color("ebc2ef"))
		p.box(orb.x-1,orb.y-2,3,4,Color("523668"))
	if state.contains("cast") or state.contains("nova") or eclipse or nightfall:
		_spark(p,offhand+Vector2(0,-10),Color("f1ceff"),3+int(absf(a)*2))


static func draw_auxiliary(canvas: Node2D, pos: Vector2, direction: Vector2, bow_windup: float=-1.0, cast_windup: float=-1.0, release_kind: String="", release_time: float=0.0):
	## Optional overlay for simultaneous player attacks, without redrawing the owl.
	## Windups are normalized progress (0..1), with -1 meaning inactive.
	## release_time is remaining feedback time in seconds (normally 0..0.2).
	var facing=-1.0 if direction.x < -0.05 else 1.0
	var p=Pixels.new(canvas,pos,facing,Color.WHITE)
	var aim=Vector2(direction.x*facing,direction.y).normalized()
	if aim.length_squared()<0.01:aim=Vector2.RIGHT
	var bow_release=release_time>0 and (release_kind.contains("bow") or release_kind.contains("both"))
	var cast_release=release_time>0 and (release_kind.contains("cast") or release_kind.contains("magic") or release_kind.contains("both"))
	if bow_windup>=0 or bow_release:
		var hand=Vector2(-11,0)
		p.limb(Vector2(-6,0),Vector2(-9,2),hand,Color("a97043"),2)
		_bow(p,hand,aim,clampf(bow_windup,0.0,1.0) if not bow_release else 0.0,Color("b9e1e9"))
		if bow_release:
			var arrow=hand+aim*(8+(0.2-clampf(release_time,0,0.2))*35)
			p.line(arrow-aim*5,arrow,Color("e8ffff"))
			p.line(arrow,arrow-aim*2+aim.orthogonal()*2,Color("e8ffff"))
			p.line(arrow,arrow-aim*2-aim.orthogonal()*2,Color("e8ffff"))
	if cast_windup>=0 or cast_release:
		var orb=Vector2(-9,-13)
		var charge=clampf(cast_windup,0.0,1.0)
		var size=2+int(charge*2)
		p.box(-9,-7,1,2,Color("9c79bb"));p.box(-10,-10,1,1,Color("c1a0de"))
		p.poly([orb+Vector2(0,-size-1),orb+Vector2(size+1,0),orb+Vector2(0,size+1),orb+Vector2(-size-1,0)],INK)
		p.poly([orb+Vector2(0,-size),orb+Vector2(size,0),orb+Vector2(0,size),orb+Vector2(-size,0)],Color("b88cdc"))
		p.box(orb.x-1,orb.y-1,2,2,Color("f0dcff"))
		if cast_release:
			_spark(p,orb,Color("f9eaff"),5)
			for side in [-1,1]:p.box(orb.x+side*6,orb.y+side*4,2,2,Color("c9a9ec"))
