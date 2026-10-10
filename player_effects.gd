extends RefCounted
const D = preload("res://data.gd")

static func dot(e: Dictionary, kind: String, power: float, cap: int, duration: float):
	if e.hp<=0:return
	var active=float(e.get(kind+"_left",0.0))>0
	e[kind+"_stacks"]=mini(cap,(int(e.get(kind+"_stacks",0)) if active else 0)+1)
	e[kind+"_left"]=duration
	e[kind+"_power"]=maxf(power,float(e.get(kind+"_power",0.0)) if active else 0.0)
	if not active:e[kind+"_tick"]=0.5

static func slow(e: Dictionary, strength: float, duration: float):
	if e.hp<=0:return
	e["slow_left"]=maxf(float(e.get("slow_left",0.0)),duration)
	e["slow_factor"]=minf(float(e.get("slow_factor",1.0)),strength)

static func on_hit(g, e: Dictionary, damage: float, weapon: String, element: String):
	if weapon in ["dagger","throwing_knife"] and g.ClassProgression.class_id(g)=="dash":
		for kind in ["poison","bleed"]:
			var rank=g.active_skill_rank(kind)
			if rank>0:dot(e,kind,(2.0 if kind=="poison" else 2.5)+g.stats.damage*0.035,3 if rank==1 else 5,3.0)
	if g.active_skill_rank("stagger")>0 or g.active_skill_rank("pin")>0:
		slow(e,0.65,1.0+0.25*maxi(g.active_skill_rank("stagger"),g.active_skill_rank("pin")))
	if weapon=="staff":
		match element:
			"fire":
				var rank=g.active_skill_rank("fire")
				dot(e,"burn",g.stats.damage*(0.14+rank*0.025),1,2.5)
				if rank>0:
					for other in g.enemies:
						if other!=e and other.hp>0 and other.pos.distance_to(e.pos)<65:
							dot(other,"burn",g.stats.damage*0.1,1,2.0)
			"ice":slow(e,maxf(0.35,0.7-g.active_skill_rank("ice")*0.12),1.5+g.active_skill_rank("ice")*0.5)
			"lightning":
				var last:Vector2=e.pos
				var visited=[e]
				for i in range(2+g.active_skill_rank("lightning")):
					var other=null
					var distance=135.0
					for candidate in g.enemies:
						if candidate.hp>0 and not candidate in visited and candidate.pos.distance_to(last)<distance:
							distance=candidate.pos.distance_to(last);other=candidate
					if other==null:break
					visited.append(other)
					g.damage_enemy(other,damage*0.4,last,true,false)
					g.effects.append({"pos":last.lerp(other.pos,0.5),"a":last,"b":other.pos,"time":0.18,"color":Color("fff59c"),"radius":8.0})
					last=other.pos
	var bounce=g.active_skill_rank("ricochet")
	if bounce>0 and weapon in ["bow","crossbow","gun"]:
		var closest=null
		var distance=135.0
		for other in g.enemies:
			if other!=e and other.hp>0 and other.pos.distance_to(e.pos)<distance:
				distance=other.pos.distance_to(e.pos);closest=other
		if closest!=null:g.damage_enemy(closest,damage*(0.25+bounce*0.1),e.pos,true,false)
	var blast=g.active_skill_rank("explosive")
	if blast>0 and weapon=="gun":
		for other in g.enemies:
			if other!=e and other.hp>0 and other.pos.distance_to(e.pos)<55+blast*10:
				g.damage_enemy(other,damage*0.3,e.pos,true,false)
		g.effects.append({"pos":e.pos,"time":0.25,"color":Color("ffbd71"),"radius":55.0})

static func tick(g, dt: float):
	for e in g.enemies:
		if e.hp<=0:continue
		e["slow_left"]=maxf(0.0,float(e.get("slow_left",0.0))-dt)
		if e.slow_left<=0:e["slow_factor"]=1.0
		for kind in ["poison","bleed","burn"]:
			var left=float(e.get(kind+"_left",0.0))
			if left<=0:continue
			var time=float(e.get(kind+"_tick",0.5))-minf(dt,left)
			var stacks=clampi(int(e.get(kind+"_stacks",0)),0,5)
			var count=0
			while time<=0.000001 and e.hp>0 and count<8:
				g.damage_enemy(e,float(e.get(kind+"_power",0.0))*stacks,e.pos,false,false)
				time+=0.5;count+=1
			e[kind+"_tick"]=time;e[kind+"_left"]=maxf(0.0,left-dt)
			if e[kind+"_left"]<=0:e[kind+"_stacks"]=0

static func shockwave(g, aim: Vector2):
	var rank=g.active_skill_rank("shockwave")
	if rank<=0:return
	g.bullets.append({"pos":g.player,"vel":aim*290,"life":1.0,"damage":g.stats.damage*(0.4+rank*0.15),"friendly":true,"magic":false,"weapon":g.primary_weapon(),"pierce":3,"hit_ids":[],"variant":"shockwave"})
