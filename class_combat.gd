extends RefCounted

# Class-only attacks share the game's damage path, collision rules, and run state.
# No timer advances outside live play. All persistent arrays have hard bounds.
const D = preload("res://data.gd")
const FIRE_LIFETIME = 1.4
const FIRE_TICK = 0.35
const FIRE_RADIUS = 17.0
const FIRE_SPACING = 12.0
const MAX_FIRE_PATCHES = 32
const FAMILIAR_INTERVAL = 0.9
const RADIAL_INTERVAL = 2.3
const POISON_LIFETIME = 3.0
const POISON_INTERVAL = 0.5
const MAX_POISON_STACKS = 3
const MAX_HOMING_TURN = 2.8
const MAX_CLASS_BULLETS = 96
const MAX_DASH_GHOSTS = 18

static func live(g) -> bool:
	return g.state == "playing" and g.hp > 0

static func melee_spec(g) -> Dictionary:
	var weapon: String = g.primary_weapon()
	var spec: Dictionary = D.PRIMARY_WEAPONS.get(weapon, D.PRIMARY_WEAPONS.sword).duplicate(true)
	if weapon != "sword": return spec
	spec["cone_dot"] = 0.82
	spec["style"] = "slash"
	# The tactic selector owns exclusivity; deterministic precedence also keeps
	# malformed/legacy saves from combining the damage and area of all styles.
	if g.tactic_rank("blade_thrust") > 0:
		spec.merge({"style":"thrust", "cone_dot":0.96, "reach":1.3, "damage":1.3, "cooldown":0.9}, true)
	elif g.tactic_rank("blade_cleave") > 0:
		spec.merge({"style":"cleave", "cone_dot":0.0, "reach":1.0, "damage":0.8}, true)
	elif g.tactic_rank("blade_sweep") > 0:
		spec.merge({"style":"sweep", "cone_dot":-1.0, "reach":0.9, "damage":0.55}, true)
	return spec

static func _append_bolt(g, pos: Vector2, direction: Vector2, speed: float, damage: float, lifetime: float, kind: String, homing: float = MAX_HOMING_TURN, homing_delay: float = 0.0):
	var count = 0
	for bullet in g.bullets:
		if bullet.get("class_kind", "") != "": count += 1
	if count >= MAX_CLASS_BULLETS: return
	if direction.length_squared() < 0.0001: direction = Vector2.RIGHT
	g.bullets.append({"pos":pos, "vel":direction.normalized() * speed,
		"life":lifetime, "damage":damage, "friendly":true, "magic":true,
		"homing":clampf(homing, 0.0, MAX_HOMING_TURN), "homing_delay":maxf(0.0, homing_delay), "class_kind":kind})

static func release_staff(g):
	if not live(g) or g.primary_weapon() != "staff": return
	var rank = clampi(g.tactic_rank("moon_spread"), 0, 2)
	var count = 1 + 2 * rank
	var volley_multiplier = [1.0, 1.35, 1.65][rank]
	var power = 1.1 + 0.15 * maxf(0.0, minf(3.0, float(g.stats.get("magic", 1.0))) - 1.0)
	var damage = float(g.stats.damage) * power * float(volley_multiplier) / count
	var aim: Vector2 = g.cast_aim
	if aim.length_squared() < 0.0001: aim = g.facing
	for i in range(count):
		var angle = (float(i) - float(count - 1) * 0.5) * 0.22
		_append_bolt(g, g.player, aim.rotated(angle), g.aimed_projectile_speed(260.0), damage, 2.5, "moon", MAX_HOMING_TURN, 0.12 if rank > 0 else 0.0)
	var radial = clampi(g.tactic_rank("moon_radial"), 0, 2)
	if radial > 0 and float(g.class_fx.get("radial_cd", 0.0)) <= 0:
		g.class_fx["radial_cd"] = RADIAL_INTERVAL
		var spark_damage = float(g.stats.damage) * (0.15 if radial == 1 else 0.22)
		for i in range(8):
			_append_bolt(g, g.player, Vector2.RIGHT.rotated(i * TAU / 8.0), 160.0, spark_damage, 1.6, "radial", 0.0)

static func update_bullet(g, b: Dictionary, dt: float):
	if not live(g) or not is_finite(dt) or dt <= 0: return
	if not b.get("friendly", false) or float(b.get("homing", 0.0)) <= 0: return
	# Split volleys travel straight briefly so their fan stays readable. Only
	# the remainder of a frame crossing the delay boundary may steer.
	var delay = maxf(0.0, float(b.get("homing_delay", 0.0)))
	var steering_dt = maxf(0.0, dt - delay)
	if delay > 0: b["homing_delay"] = maxf(0.0, delay - dt)
	if steering_dt <= 0: return
	var target = g.nearest_enemy(b.pos)
	if target == null: return
	var velocity: Vector2 = b.vel
	var desired: Vector2 = target.pos - b.pos
	if desired.length_squared() < 0.0001 or velocity.length_squared() < 0.0001: return
	var turn = minf(MAX_HOMING_TURN, float(b.homing)) * steering_dt
	var difference = wrapf(desired.angle() - velocity.angle(), -PI, PI)
	b.vel = velocity.rotated(clampf(difference, -turn, turn))

static func on_dash_hit(g, e: Dictionary):
	if not live(g) or g.primary_weapon() != "dagger" or float(e.get("hp", 0.0)) <= 0: return
	var poison = clampi(g.tactic_rank("comet_poison"), 0, 2)
	if poison > 0:
		var active = float(e.get("poison_left", 0.0)) > 0
		e["poison_stacks"] = mini(MAX_POISON_STACKS, (int(e.get("poison_stacks", 0)) if active else 0) + 1)
		e["poison_left"] = POISON_LIFETIME
		e["poison_rank"] = poison
		# Refresh duration but preserve cadence: repeated dashes never postpone DOT.
		if not active: e["poison_tick"] = POISON_INTERVAL
	var knockback = clampi(g.tactic_rank("comet_push"), 0, 2)
	if knockback > 0 and e.get("attack_state", "idle") in ["idle", "recover"]:
		var away: Vector2 = e.pos - g.player
		if away.length_squared() < 0.0001: away = g.facing
		if away.length_squared() < 0.0001: away = Vector2.RIGHT
		e.pos = g.move_actor(e.pos, away.normalized() * (20.0 if knockback == 1 else 32.0), 26.0 if e.get("kind", "") == "boss" else 16.0)

static func tick(g, dt: float, old_player: Vector2):
	if not live(g) or not is_finite(dt) or dt <= 0: return
	g.class_fx["radial_cd"] = maxf(0.0, float(g.class_fx.get("radial_cd", 0.0)) - dt)
	_tick_dash_trail(g, dt, old_player)
	_tick_poison(g, dt)
	_tick_fire(g, dt, old_player)
	_tick_familiar(g, dt)

static func _tick_poison(g, dt: float):
	for e in g.enemies:
		if float(e.get("hp", 0.0)) <= 0: continue
		var left = float(e.get("poison_left", 0.0))
		var stacks = clampi(int(e.get("poison_stacks", 0)), 0, MAX_POISON_STACKS)
		if left <= 0 or stacks <= 0: continue
		var remaining = float(e.get("poison_tick", POISON_INTERVAL)) - minf(dt, left)
		var rank = clampi(int(e.get("poison_rank", 1)), 1, 2)
		# At most six ticks per call, including the final tick at exact expiry.
		var ticks = 0
		while remaining <= 0.000001 and ticks < 6 and e.hp > 0:
			g.damage_enemy(e, stacks * (1.5 if rank == 1 else 2.0), e.pos)
			remaining += POISON_INTERVAL
			ticks += 1
		e["poison_tick"] = remaining
		e["poison_left"] = maxf(0.0, left - dt)
		if e.poison_left <= 0.000001:
			e["poison_left"] = 0.0
			e["poison_stacks"] = 0

static func _tick_fire(g, dt: float, old_player: Vector2):
	# Expire first so old patches cannot be extended by standing still.
	for i in range(g.trail_patches.size() - 1, -1, -1):
		g.trail_patches[i]["time"] = float(g.trail_patches[i].get("time", 0.0)) - dt
		if g.trail_patches[i].time <= 0.000001: g.trail_patches.remove_at(i)
	var rank = clampi(g.tactic_rank("moon_fire"), 0, 2) if g.primary_weapon() == "staff" else 0
	var distance = old_player.distance_to(g.player)
	# Walking only: a dash does not paint an entire arena in a single instant.
	if rank > 0 and g.dash_left <= 0 and distance > 0.0001:
		var last: Vector2 = g.class_fx.get("fire_last", old_player)
		if not g.class_fx.has("fire_last"):
			_add_fire_patch(g, old_player, rank)
			g.class_fx["fire_last"] = old_player
		if last.distance_to(g.player) >= FIRE_SPACING:
			_add_fire_patch(g, g.player, rank)
			g.class_fx["fire_last"] = g.player
	elif rank <= 0:
		g.class_fx.erase("fire_last")
	while g.trail_patches.size() > MAX_FIRE_PATCHES: g.trail_patches.pop_front()
	for e in g.enemies:
		if float(e.get("hp", 0.0)) <= 0: continue
		var cooldown = maxf(0.0, float(e.get("moon_fire_tick", 0.0)) - dt)
		e["moon_fire_tick"] = cooldown
		if cooldown > 0.000001: continue
		var strongest = 0.0
		var source: Vector2 = e.pos
		for patch in g.trail_patches:
			if e.pos.distance_squared_to(patch.pos) <= FIRE_RADIUS * FIRE_RADIUS and float(patch.damage) > strongest:
				strongest = float(patch.damage)
				source = patch.pos
		if strongest > 0:
			# One cooldown per enemy, not per patch. Overlap never multiplies DPS.
			g.damage_enemy(e, strongest, source)
			e["moon_fire_tick"] = FIRE_TICK

static func _add_fire_patch(g, pos: Vector2, rank: int):
	if g.blocked(pos, 2.0): return
	while g.trail_patches.size() >= MAX_FIRE_PATCHES: g.trail_patches.pop_front()
	g.trail_patches.append({"pos":pos, "time":FIRE_LIFETIME, "damage":float(g.stats.damage) * (0.12 if rank == 1 else 0.18), "phase":float(g.elapsed) * 9.0})

static func _tick_familiar(g, dt: float):
	if g.primary_weapon() != "staff" or g.tactic_rank("moon_familiar") <= 0:
		g.class_fx.erase("familiar")
		return
	if not g.class_fx.has("familiar"):
		g.class_fx["familiar"] = {"pos":g.player + Vector2(-28, -35), "phase":0.0, "cooldown":FAMILIAR_INTERVAL, "flash":0.0}
	var familiar: Dictionary = g.class_fx.familiar
	familiar.phase = fmod(float(familiar.phase) + dt * 1.8, TAU)
	var destination: Vector2 = g.player + Vector2(cos(familiar.phase) * 34.0, sin(familiar.phase) * 18.0 - 46.0)
	familiar.pos = (familiar.pos as Vector2).move_toward(destination, 250.0 * dt)
	# A single non-colliding spirit follows/orbits without becoming a blocker.
	if familiar.pos.distance_squared_to(g.player) > 180.0 * 180.0: familiar.pos = destination
	familiar.flash = maxf(0.0, float(familiar.flash) - dt)
	familiar.cooldown = maxf(0.0, float(familiar.cooldown) - dt)
	var target = g.nearest_enemy(familiar.pos)
	if familiar.cooldown <= 0.000001 and target != null:
		_append_bolt(g, familiar.pos, target.pos - familiar.pos, 230.0, float(g.stats.damage) * 0.35, 2.0, "familiar")
		familiar.cooldown = FAMILIAR_INTERVAL
		familiar.flash = 0.15

static func _tick_dash_trail(g, dt: float, old_player: Vector2):
	var ghosts: Array = g.class_fx.get("dash_ghosts", [])
	for i in range(ghosts.size() - 1, -1, -1):
		ghosts[i].time -= dt
		if ghosts[i].time <= 0: ghosts.remove_at(i)
	var cooldown = maxf(0.0, float(g.class_fx.get("dash_ghost_cd", 0.0)) - dt)
	if g.primary_weapon() == "dagger" and g.dash_left > 0 and old_player.distance_squared_to(g.player) > 0.01 and cooldown <= 0:
		while ghosts.size() >= MAX_DASH_GHOSTS: ghosts.pop_front()
		ghosts.append({"pos":old_player, "time":0.24, "aim":g.facing})
		cooldown = 0.022
	g.class_fx["dash_ghosts"] = ghosts
	g.class_fx["dash_ghost_cd"] = cooldown

static func _draw_shield(g):
	if g.primary_weapon() != "staff" or g.shield <= 0: return
	# Broken, pixel-stepped corners leave the floor warning and owl readable.
	# Accepted hits reset shield_delay to four seconds in ClassProgression.
	var flash = clampf((float(g.shield_delay) - 3.7) / 0.3, 0.0, 1.0)
	var alpha = 0.20 + 0.035 * sin(float(g.elapsed) * 2.4) + flash * 0.55
	var color = Color(0.69, 0.65, 1.0, alpha)
	var origin: Vector2 = g.player + Vector2(0, -2)
	for i in range(4):
		var angle = i * PI * 0.5
		for offset in [Vector2(0, -23), Vector2(-4, -19), Vector2(4, -19), Vector2(-8, -15), Vector2(8, -15)]:
			var at: Vector2 = (origin + offset.rotated(angle)).round()
			g.draw_rect(Rect2(at - Vector2.ONE, Vector2(3, 3)), color)

static func draw(g):
	# Deliberately pixel-sized primitives; no texture dependencies or extra nodes.
	# Call inside main's translated world draw, before the player is drawn.
	_draw_shield(g)
	if g.primary_weapon() == "sword" and g.sword_state == "active" and g.tactic_rank("blade_thrust") > 0:
		var aim: Vector2 = g.sword_aim.normalized()
		var tip: Vector2 = g.player + aim * float(g.stats.range) * 1.3
		var side: Vector2 = aim.orthogonal()
		var alpha = clampf(float(g.slash_time) / 0.12, 0.0, 1.0)
		g.draw_line(g.player + aim * 17.0, tip, Color(1.0, 0.94, 0.67, alpha), 4.0)
		g.draw_line(tip - aim * 10.0 + side * 4.0, tip, Color(1.0, 1.0, 1.0, alpha), 2.0)
		g.draw_line(tip - aim * 10.0 - side * 4.0, tip, Color(1.0, 1.0, 1.0, alpha), 2.0)
	for ghost in g.class_fx.get("dash_ghosts", []):
		var alpha = clampf(float(ghost.time) / 0.24, 0.0, 1.0) * 0.45
		var at: Vector2 = ghost.pos.round()
		var tint = Color(0.40, 0.87, 1.0, alpha)
		g.draw_rect(Rect2(at + Vector2(-8, -10), Vector2(16, 17)), tint)
		g.draw_rect(Rect2(at + Vector2(-11, -12), Vector2(6, 7)), tint)
		g.draw_rect(Rect2(at + Vector2(5, -12), Vector2(6, 7)), tint)
		g.draw_line(at, at - (ghost.aim as Vector2) * 20.0, tint, 2.0)
	for patch in g.trail_patches:
		var at: Vector2 = patch.pos.round()
		var alpha = clampf(float(patch.time) / 0.4, 0.0, 0.80)
		var flicker = int(float(g.elapsed) * 12.0 + float(patch.get("phase", 0.0))) % 3
		g.draw_rect(Rect2(at + Vector2(-10, -3), Vector2(20, 6)), Color(0.40, 0.19, 0.66, alpha * 0.6))
		for i in range(3):
			var height = 6.0 + 2.0 * ((i + flicker) % 3)
			g.draw_rect(Rect2(at + Vector2(i * 6 - 8, -height), Vector2(4, height + 1)), Color(0.63, 0.43, 1.0, alpha))
			g.draw_rect(Rect2(at + Vector2(i * 6 - 7, -height + 4), Vector2(2, height - 3)), Color(0.86, 0.91, 1.0, alpha))
	for e in g.enemies:
		if float(e.get("hp", 0.0)) <= 0 or float(e.get("poison_left", 0.0)) <= 0: continue
		var count = clampi(int(e.get("poison_stacks", 0)), 0, MAX_POISON_STACKS)
		for i in range(count):
			g.draw_rect(Rect2((e.pos as Vector2).round() + Vector2(i * 5 - (count - 1) * 2.5 - 1, -25), Vector2(3, 4)), Color("b8f46e"))
	for b in g.bullets:
		if not b.get("friendly", false) or float(b.get("homing", 0.0)) <= 0: continue
		var at: Vector2 = b.pos.round()
		var tint = Color("8fe7ff") if b.get("class_kind", "") == "familiar" else Color("dfbbff")
		g.draw_rect(Rect2(at + Vector2(-5, -1), Vector2(10, 2)), Color(tint, 0.6))
		g.draw_rect(Rect2(at + Vector2(-1, -5), Vector2(2, 10)), Color(tint, 0.6))
		g.draw_line(at - (b.vel as Vector2).normalized() * 6, at - (b.vel as Vector2).normalized() * 15, Color(tint, 0.45), 2.0)
	if g.class_fx.has("familiar"):
		var familiar: Dictionary = g.class_fx.familiar
		var at: Vector2 = (familiar.pos as Vector2).round()
		var flap = -2.0 if sin(float(familiar.phase) * 4.0) > 0 else 1.0
		var body = Color("d9eeff") if familiar.flash <= 0 else Color("ffffff")
		g.draw_rect(Rect2(at + Vector2(-6, -6), Vector2(12, 13)), Color("5969a1"))
		g.draw_rect(Rect2(at + Vector2(-5, -7), Vector2(10, 11)), body)
		g.draw_rect(Rect2(at + Vector2(-7, -9), Vector2(4, 6)), body)
		g.draw_rect(Rect2(at + Vector2(3, -9), Vector2(4, 6)), body)
		g.draw_rect(Rect2(at + Vector2(-10, flap - 1), Vector2(4, 5)), Color("a1cfff"))
		g.draw_rect(Rect2(at + Vector2(6, flap - 1), Vector2(4, 5)), Color("a1cfff"))
		g.draw_rect(Rect2(at + Vector2(-3, -3), Vector2(2, 3)), Color("35405c"))
		g.draw_rect(Rect2(at + Vector2(2, -3), Vector2(2, 3)), Color("35405c"))
		g.draw_rect(Rect2(at + Vector2(0, 1), Vector2(2, 2)), Color("c19ce8"))
