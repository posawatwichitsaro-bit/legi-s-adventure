extends RefCounted

# Arena art and environmental hazards use world coordinates. The caller owns
# camera translation; neither this file nor generation ever resizes the viewport.
# Flat landmarks and shallow pools are decorative, while every solid prop has
# exactly one corresponding rectangle in game.obstacles.
const D = preload("res://data.gd")
const SAFE_CENTER_RADIUS = 110.0
const TELEGRAPH_TIME = 1.4
const ACTIVE_TIME = 1.0
const RECOVERY_TIME = 0.7
const HAZARD_NAMES = ["BRAMBLE BURST", "EMBER VENT", "PRISM ERUPTION", "LUNAR SEAL"]
const LAYOUT_NAMES = ["Willow Crossroads", "Ashen Causeways", "Prismatic Courts", "Moonlit Observatory"]

static func generate(g):
	var theme = clampi(int((g.stage - 1) / 5), 0, 3)
	var intensity = 1 + (g.stage - 1) % 5
	g.obstacles.clear()
	g.flowers.clear()
	g.world_data = {"theme":theme, "intensity":intensity, "layout_name":LAYOUT_NAMES[theme],
		"tiles":[], "patches":[], "paths":[], "landmarks":[], "obstacle_styles":[],
		"hazards":[], "hazards_enabled":true, "hazard_timer":5.0, "hazard_serial":0, "generated_stage":g.stage}
	var w: Dictionary = g.world_data
	# A jittered grid keeps all corners populated rather than clustering detail
	# around the spawn. Detail is deterministic for a seeded stage generation.
	for y in range(int(g.ARENA.position.y), int(g.ARENA.end.y), 40):
		for x in range(int(g.ARENA.position.x), int(g.ARENA.end.x), 40):
			w.tiles.append({"rect":Rect2(x, y, minf(40, g.ARENA.end.x - x), minf(40, g.ARENA.end.y - y)), "shade":g.rng.randf_range(-0.025, 0.035)})
			var p = Vector2(x + g.rng.randf_range(6, 34), y + g.rng.randf_range(6, 34))
			if g.ARENA.grow(-8).has_point(p):
				g.flowers.append({"pos":p, "type":g.rng.randi_range(0, 7), "angle":g.rng.randf() * TAU, "size":g.rng.randf_range(0.7, 1.25)})
	for i in range(32 + intensity * 3):
		var p = Vector2(g.rng.randf_range(g.ARENA.position.x + 32, g.ARENA.end.x - 32), g.rng.randf_range(g.ARENA.position.y + 32, g.ARENA.end.y - 32))
		var radius = g.rng.randf_range(24, 64)
		w.patches.append({"pos":p, "radius":radius, "angle":g.rng.randf() * TAU, "shade":g.rng.randf_range(0.025, 0.065)})
	_build_paths(g, theme)
	_build_landmarks(g, theme)
	_build_obstacles(g, theme, intensity)
	reset_hazards(g)

static func _build_paths(g, theme: int):
	var c: Vector2 = g.CENTER
	var a: Rect2 = g.ARENA
	var paths: Array = g.world_data.paths
	match theme:
		0:
			paths.append({"points":PackedVector2Array([Vector2(a.position.x, c.y - 28), c + Vector2(-340, -22), c, c + Vector2(330, 28), Vector2(a.end.x, c.y + 20)]), "width":90.0})
			paths.append({"points":PackedVector2Array([Vector2(c.x - 18, a.position.y), c + Vector2(30, -145), c, c + Vector2(-26, 160), Vector2(c.x + 14, a.end.y)]), "width":80.0})
		1:
			paths.append({"points":PackedVector2Array([Vector2(a.position.x, c.y), Vector2(a.end.x, c.y)]), "width":112.0})
			paths.append({"points":PackedVector2Array([Vector2(c.x, a.position.y), Vector2(c.x, a.end.y)]), "width":84.0})
			paths.append({"points":PackedVector2Array([c + Vector2(-490, -205), c + Vector2(-360, -70), c + Vector2(360, -70), c + Vector2(490, -205)]), "width":34.0})
			paths.append({"points":PackedVector2Array([c + Vector2(-490, 205), c + Vector2(-360, 70), c + Vector2(360, 70), c + Vector2(490, 205)]), "width":34.0})
		2:
			paths.append({"points":PackedVector2Array([Vector2(a.position.x, c.y), c, Vector2(a.end.x, c.y)]), "width":86.0})
			paths.append({"points":PackedVector2Array([Vector2(c.x, a.position.y), c, Vector2(c.x, a.end.y)]), "width":86.0})
			paths.append({"points":PackedVector2Array([c + Vector2(-490, -220), c + Vector2(-490, 220), c + Vector2(490, 220), c + Vector2(490, -220), c + Vector2(-490, -220)]), "width":30.0})
		3:
			paths.append({"points":PackedVector2Array([Vector2(a.position.x, c.y), c + Vector2(-340, 38), c, c + Vector2(340, -38), Vector2(a.end.x, c.y)]), "width":94.0})
			paths.append({"points":PackedVector2Array([Vector2(c.x, a.position.y), c, Vector2(c.x, a.end.y)]), "width":72.0})
			# A continuous thin orbit is a traversable mosaic, never a wall.
			var orbit = PackedVector2Array()
			for i in range(49):
				var angle = TAU * float(i) / 48.0
				orbit.append(c + Vector2(cos(angle) * 480, sin(angle) * 225))
			paths.append({"points":orbit, "width":22.0})

static func _build_landmarks(g, theme: int):
	var w: Dictionary = g.world_data
	var c: Vector2 = g.CENTER
	var layout = []
	match theme:
		0:layout = [[Vector2(-400, -192), "pond", 82.0], [Vector2(390, 190), "pond", 68.0], [Vector2(380, -190), "garden", 78.0], [Vector2(-380, 185), "garden", 72.0]]
		1:layout = [[Vector2(-420, -190), "caldera", 90.0], [Vector2(390, 185), "caldera", 82.0], [Vector2(400, -200), "furnace", 74.0], [Vector2(-405, 190), "furnace", 74.0]]
		2:layout = [[Vector2(-390, -185), "prism", 84.0], [Vector2(390, 185), "prism", 84.0], [Vector2(400, -185), "mosaic", 74.0], [Vector2(-400, 185), "mosaic", 74.0]]
		3:layout = [[Vector2(-390, -190), "moon", 86.0], [Vector2(390, 190), "moon", 78.0], [Vector2(380, -195), "stars", 94.0], [Vector2(-400, 185), "stars", 90.0]]
	for entry in layout:
		w.landmarks.append({"pos":c + entry[0], "kind":entry[1], "radius":entry[2], "phase":g.rng.randf() * TAU})

static func _build_obstacles(g, theme: int, intensity: int):
	# Widely spaced islands, a broad central cross, and a 64 px perimeter route.
	# There are no linked walls or enclosed pockets. Each theme authors a
	# different cluster rhythm; later arenas add small props, never chokepoints.
	var anchors = []
	match theme:
		0:anchors = [Vector2(-535,-190), Vector2(-250,-220), Vector2(260,-195), Vector2(540,-160), Vector2(-525,180), Vector2(-225,225), Vector2(235,190), Vector2(535,230)]
		1:anchors = [Vector2(-550,-135), Vector2(-220,-245), Vector2(255,-225), Vector2(530,-130), Vector2(-540,145), Vector2(-245,245), Vector2(250,235), Vector2(530,145)]
		2:anchors = [Vector2(-550,-235), Vector2(-235,-155), Vector2(235,-155), Vector2(550,-235), Vector2(-550,235), Vector2(-235,155), Vector2(235,155), Vector2(550,235)]
		3:anchors = [Vector2(-555,-150), Vector2(-260,-235), Vector2(270,-230), Vector2(540,-155), Vector2(-535,155), Vector2(-275,235), Vector2(270,230), Vector2(555,160)]
	for i in range(anchors.size()):
		var size = Vector2(36 + (i % 3) * 8, 30 + ((i + theme) % 3) * 7)
		var p: Vector2 = g.CENTER + anchors[i] + Vector2(g.rng.randf_range(-15,15), g.rng.randf_range(-12,12))
		_add_obstacle(g, Rect2((p - size / 2).round(), size), i)
	# Small detached props scatter into each quadrant, staying out of all broad
	# central and perimeter routes. Spacing includes a full 48 px walk gap.
	var wanted = 8 + intensity * 2
	for i in range(wanted):
		for attempt in range(80):
			var p = Vector2(g.rng.randf_range(g.ARENA.position.x + 102, g.ARENA.end.x - 102), g.rng.randf_range(g.ARENA.position.y + 88, g.ARENA.end.y - 88))
			var size = Vector2(g.rng.randi_range(24, 38), g.rng.randi_range(22, 34)).snapped(Vector2(2,2))
			if _add_obstacle(g, Rect2((p - size / 2).round(), size), i + 8):break

static func _add_obstacle(g, rect: Rect2, style: int) -> bool:
	if not g.ARENA.grow(-62).encloses(rect):return false
	if rect.grow(110).has_point(g.CENTER):return false
	# Keep a 184 px east/west lane and a 164 px north/south lane.
	if rect.position.x < g.CENTER.x + 82 and rect.end.x > g.CENTER.x - 82:return false
	if rect.position.y < g.CENTER.y + 92 and rect.end.y > g.CENTER.y - 92:return false
	for existing in g.obstacles:
		if existing.grow(48).intersects(rect):return false
	g.obstacles.append(rect)
	g.world_data.obstacle_styles.append(style)
	return true

static func draw_floor(g):
	if g.world_data.is_empty():return
	var w: Dictionary = g.world_data
	var theme: Dictionary = D.THEMES[int(w.theme)]
	var floor_color: Color = theme.floor
	g.draw_rect(g.ARENA.grow(7), theme.wall.darkened(0.55))
	g.draw_rect(g.ARENA, floor_color)
	for tile in w.tiles:
		var color = floor_color.lightened(tile.shade) if tile.shade >= 0 else floor_color.darkened(-tile.shade)
		g.draw_rect(tile.rect, color)
	for patch in w.patches:
		var points = _polygon(patch.pos, patch.radius, 7, patch.angle, Vector2(1.0, 0.55))
		# Clip broad patches to the arena so the readable boundary stays clean.
		for i in range(points.size()):points[i] = points[i].clamp(g.ARENA.position + Vector2(2,2), g.ARENA.end - Vector2(2,2))
		g.draw_colored_polygon(points, floor_color.darkened(patch.shade))
	_draw_paths(g, int(w.theme))
	for landmark in w.landmarks:_draw_landmark(g, landmark, int(w.theme))
	for flower in g.flowers:_draw_detail(g, flower, int(w.theme))
	_draw_center(g, int(w.theme))
	for i in range(g.obstacles.size()):_draw_obstacle(g, g.obstacles[i], int(w.theme), int(w.obstacle_styles[i]))
	_draw_border(g, int(w.theme))

static func _draw_paths(g, theme: int):
	var colors = [Color("777b59"), Color("79544a"), Color("526c88"), Color("615273")]
	var path_color: Color = colors[theme]
	for path in g.world_data.paths:
		var points: PackedVector2Array = path.points
		for i in range(1, points.size()):
			g.draw_line(points[i-1], points[i], path_color.darkened(0.15), path.width + 6)
			g.draw_line(points[i-1], points[i], path_color, path.width)
			if theme == 2:
				g.draw_line(points[i-1], points[i], path_color.lightened(0.07), 2)
			elif theme == 3 and path.width < 30:
				g.draw_line(points[i-1], points[i], Color("807191"), 1)
		# A small repeated surface motif distinguishes each road material.
		for i in range(1, points.size()):
			var length: float = points[i-1].distance_to(points[i])
			var direction = (points[i] - points[i-1]).normalized()
			for step in range(16, int(length), 35):
				var p = points[i-1] + direction * step
				if not g.ARENA.grow(-10).has_point(p):continue
				var side = direction.orthogonal()
				if theme == 0:
					g.draw_rect(Rect2(p + side * 16, Vector2(7,3)), path_color.lightened(0.11))
				elif theme == 1:
					g.draw_line(p - side * path.width * 0.37, p + side * path.width * 0.37, path_color.darkened(0.17), 2)
				elif theme == 2:
					g.draw_polyline(_closed(_polygon(p, 5, 4, 0)), path_color.lightened(0.2), 1)
				elif path.width > 30:
					g.draw_circle(p + side * 21, 2, path_color.lightened(0.22))

static func _draw_landmark(g, l: Dictionary, theme: int):
	var p: Vector2 = l.pos
	var r: float = l.radius
	var floor_color: Color = D.THEMES[theme].floor
	var accent: Color = D.THEMES[theme].accent
	match l.kind:
		"pond":
			g.draw_colored_polygon(_polygon(p, r, 12, l.phase, Vector2(1,0.55)), Color("304d43"))
			g.draw_colored_polygon(_polygon(p, r - 9, 12, l.phase, Vector2(1,0.52)), Color("426f67"))
			for i in range(6):
				var q = p + Vector2(-r * 0.6 + i * r * 0.22, sin(i * 2.2) * r * 0.23)
				g.draw_line(q, q + Vector2(14,0), Color("6a9381"), 2)
				if i % 2 == 0:
					g.draw_circle(q + Vector2(4,8), 5, Color("668c55"))
					g.draw_rect(Rect2(q + Vector2(3,6), Vector2(3,3)), Color("d1b395"))
		"garden":
			g.draw_colored_polygon(_polygon(p, r, 8, 0, Vector2(1,0.65)), floor_color.darkened(0.14))
			for row in range(-2,3):
				for col in range(-3,4):
					var q = p + Vector2(col * 17, row * 16)
					g.draw_rect(Rect2(q, Vector2(8,3)), Color("5b7751"))
					g.draw_rect(Rect2(q + Vector2(2,-3), Vector2(3,3)), Color("c6b77c") if (col + row) % 2 == 0 else Color("a79ca5"))
		"caldera":
			g.draw_colored_polygon(_polygon(p, r, 10, l.phase, Vector2(1,0.67)), Color("47363a"))
			g.draw_colored_polygon(_polygon(p, r - 13, 10, l.phase, Vector2(1,0.6)), Color("664347"))
			for i in range(8):
				var a = i * TAU / 8.0
				var q = p + Vector2(cos(a), sin(a) * 0.58) * (r - 17)
				g.draw_line(q, q + Vector2(cos(a + 0.7),sin(a + 0.7)) * 15, Color("ac7153"), 3)
			g.draw_circle(p, 17, Color("774746"))
			g.draw_arc(p, 26, 0, PI * 1.65, 12, Color("a96b54"), 2)
		"furnace":
			g.draw_colored_polygon(_polygon(p, r, 4, PI / 4, Vector2(1,0.7)), Color("523a3d"))
			for i in range(-2,3):
				g.draw_line(p + Vector2(-42,i * 13), p + Vector2(42,i * 13), Color("80534b"), 4)
				g.draw_line(p + Vector2(i * 17,-31), p + Vector2(i * 17,31), Color("3f343b"), 2)
			g.draw_arc(p, r * 0.86, PI * 0.15, PI * 0.85, 12, Color("a77259"), 3)
		"prism":
			var points = _polygon(p, r, 6, 0, Vector2(1,0.68))
			g.draw_colored_polygon(points, Color("2d425f"))
			g.draw_polyline(_closed(points), Color("638ba2"), 3)
			var inner = _polygon(p, r * 0.7, 6, 0, Vector2(1,0.68))
			g.draw_colored_polygon(inner, Color("405e7a"))
			for i in range(6):
				g.draw_line(p, inner[i], Color("63849a"), 2)
			g.draw_colored_polygon(_polygon(p, 22, 6, 0, Vector2(1,0.68)), Color("698fa4"))
		"mosaic":
			g.draw_colored_polygon(_polygon(p, r, 4, PI / 4), floor_color.darkened(0.15))
			for radius in [r * 0.85, r * 0.58, r * 0.29]:
				g.draw_polyline(_closed(_polygon(p, radius, 4, PI / 4)), Color("63819b"), 2)
			for i in range(4):
				var q = p + Vector2.RIGHT.rotated(i * PI / 2) * r * 0.52
				g.draw_rect(Rect2(q - Vector2(3,3), Vector2(6,6)), Color("83aabc"))
		"moon":
			g.draw_circle(p, r, Color("3b3153"))
			g.draw_arc(p, r - 7, 0, TAU, 36, Color("76618d"), 3)
			g.draw_circle(p, r * 0.57, Color("8b779a"))
			g.draw_circle(p + Vector2(r * 0.23,-r * 0.13), r * 0.52, Color("3b3153"))
			for i in range(8):
				var q = p + Vector2.RIGHT.rotated(i * TAU / 8) * (r - 17)
				g.draw_rect(Rect2(q - Vector2(2,2), Vector2(4,4)), Color("a899b5"))
		"stars":
			g.draw_colored_polygon(_polygon(p, r, 8, l.phase, Vector2(1,0.65)), floor_color.darkened(0.16))
			var points = PackedVector2Array()
			for i in range(6):points.append(p + Vector2(cos(i * 2.1 + l.phase) * r * 0.7, sin(i * 1.7) * r * 0.47))
			g.draw_polyline(points, Color("756186"), 2)
			for q in points:
				g.draw_line(q - Vector2(4,0), q + Vector2(4,0), Color("b5a5bf"), 2)
				g.draw_line(q - Vector2(0,4), q + Vector2(0,4), Color("b5a5bf"), 2)
	# Stage-within-theme intensifies floor inscriptions without adding blockers.
	for i in range(int(g.world_data.intensity)):
		var q = p + Vector2(-24 + i * 12, r * 0.72 + 8)
		g.draw_rect(Rect2(q, Vector2(5,2)), Color(accent,0.35))

static func _draw_detail(g, d: Dictionary, theme: int):
	var p: Vector2 = d.pos.round()
	var kind: int = d.type
	var floor_color: Color = D.THEMES[theme].floor
	# Keep the sanctuary comparatively calm so the portal and player are clear.
	if p.distance_to(g.CENTER) < SAFE_CENTER_RADIUS and kind < 5:return
	match theme:
		0:
			if kind <= 2:
				g.draw_line(p + Vector2(-3,2), p + Vector2(-4,-3), Color("5c8556"), 2)
				g.draw_line(p + Vector2(1,3), p + Vector2(3,-4), Color("6b955e"), 2)
				if kind == 0:g.draw_rect(Rect2(p + Vector2(1,-5), Vector2(4,3)), Color("ccb786") if int(p.x) % 2 == 0 else Color("cfa9b5"))
			elif kind == 3:
				g.draw_rect(Rect2(p, Vector2(7,3)), Color("668074"))
				g.draw_rect(Rect2(p + Vector2(1,-2), Vector2(4,2)), Color("7f9580"))
			else:g.draw_rect(Rect2(p,Vector2(3,2)),floor_color.lightened(0.13))
		1:
			if kind <= 2:
				g.draw_line(p + Vector2(-6,-2), p, Color("443338"), 2)
				g.draw_line(p, p + Vector2(4,6), Color("443338"), 2)
				if kind == 0:g.draw_line(p, p + Vector2(5,-4), Color("b67752"), 1)
			elif kind == 3:
				g.draw_colored_polygon(_polygon(p, 5, 5, d.angle, Vector2(1,0.65)), Color("875850"))
			else:g.draw_rect(Rect2(p,Vector2(2,2)),Color("ac7860") if kind == 4 else floor_color.lightened(0.11))
		2:
			if kind <= 2:
				g.draw_line(p + Vector2(-6,3), p, Color("567891"), 1)
				g.draw_line(p, p + Vector2(7,3), Color("567891"), 1)
				if kind == 0:g.draw_line(p, p + Vector2(2,-7), Color("739aad"), 1)
			elif kind == 3:
				g.draw_colored_polygon(PackedVector2Array([p + Vector2(-4,2), p + Vector2(0,-4), p + Vector2(4,2), p + Vector2(0,5)]), Color("7ba1b4"))
			else:g.draw_rect(Rect2(p,Vector2(2,2)),floor_color.lightened(0.18))
		3:
			if kind <= 2:
				g.draw_line(p + Vector2(-5,1), p + Vector2(5,1), Color("746086"), 1)
				g.draw_line(p + Vector2(0,-4), p + Vector2(0,6), Color("746086"), 1)
				if kind == 0:g.draw_rect(Rect2(p,Vector2(2,2)),Color("b7a1c5"))
			elif kind == 3:
				g.draw_arc(p, 5, 0, PI, 6, Color("826b95"), 2)
			else:g.draw_rect(Rect2(p,Vector2(2,2)),floor_color.lightened(0.13))

static func _draw_center(g, theme: int):
	var c: Vector2 = g.CENTER
	var colors = [Color("849071"), Color("8b6658"), Color("7695ad"), Color("927ca5")]
	var col: Color = colors[theme]
	# This is a quiet inlaid compass, not an active hazard warning.
	g.draw_arc(c, 83, 0, TAU, 48, Color(col,0.42), 2)
	for i in range(8):
		var dir = Vector2.RIGHT.rotated(i * TAU / 8)
		g.draw_line(c + dir * 77, c + dir * 87, Color(col,0.7), 3)
	g.draw_colored_polygon(_polygon(c, 22, 4, 0), Color(col,0.18))
	g.draw_polyline(_closed(_polygon(c, 14, 4, 0)), Color(col,0.5), 2)

static func _draw_obstacle(g, rect: Rect2, theme: int, style: int):
	var p: Vector2 = rect.position
	var s: Vector2 = rect.size
	var wall: Color = D.THEMES[theme].wall
	g.draw_rect(Rect2(p + Vector2(4,6),s),Color(0,0,0,0.24))
	g.draw_rect(rect,wall.darkened(0.42))
	match theme:
		0:
			g.draw_rect(Rect2(p + Vector2(1,0),s - Vector2(2,6)),Color("3d714b"))
			g.draw_rect(Rect2(p + Vector2(4,3),s - Vector2(8,14)),Color("568052"))
			for i in range(4):
				var q = p + Vector2(5 + (i * 11 + style * 7) % int(s.x - 9), 4 + (i * 7 + style * 3) % int(s.y - 12))
				g.draw_rect(Rect2(q,Vector2(6,3)),Color("789755"))
			g.draw_rect(Rect2(p + Vector2(3,s.y - 6),Vector2(s.x - 6,4)),Color("496445"))
		1:
			g.draw_rect(Rect2(p + Vector2(1,0),s - Vector2(2,7)),Color("79514b"))
			g.draw_colored_polygon(PackedVector2Array([p + Vector2(3,2),p + Vector2(s.x - 4,2),p + Vector2(s.x - 9,s.y * 0.5),p + Vector2(4,s.y * 0.7)]),Color("956650"))
			g.draw_line(p + Vector2(s.x * 0.6,2),p + Vector2(s.x * 0.45,s.y * 0.5),Color("4c383a"),3)
			g.draw_line(p + Vector2(s.x * 0.45,s.y * 0.5),p + Vector2(s.x * 0.68,s.y - 4),Color("c98657"),2)
		2:
			g.draw_rect(Rect2(p + Vector2(1,0),s - Vector2(2,5)),Color("4e7e9c"))
			g.draw_colored_polygon(PackedVector2Array([p + Vector2(2,2),p + Vector2(s.x * 0.55,2),p + Vector2(s.x * 0.55,s.y - 7),p + Vector2(2,s.y * 0.58)]),Color("81b6c8"))
			g.draw_colored_polygon(PackedVector2Array([p + Vector2(s.x * 0.55,2),p + Vector2(s.x - 2,5),p + Vector2(s.x - 2,s.y - 7),p + Vector2(s.x * 0.55,s.y - 7)]),Color("5d96b3"))
			g.draw_line(p + Vector2(4,4),p + Vector2(s.x * 0.5,4),Color("b8d7dd"),2)
		3:
			g.draw_rect(Rect2(p + Vector2(1,0),s - Vector2(2,6)),Color("6b5481"))
			g.draw_rect(Rect2(p + Vector2(3,3),Vector2(s.x - 6,5)),Color("927398"))
			g.draw_rect(Rect2(p + Vector2(5,10),s - Vector2(10,18)),Color("4e4069"))
			var center = rect.get_center() - Vector2(0,1)
			g.draw_polyline(_closed(_polygon(center,6,4,0)),Color("b194c1"),2)
			g.draw_rect(Rect2(p + Vector2(2,s.y - 6),Vector2(s.x - 4,3)),Color("84658d"))

static func _draw_border(g, theme: int):
	var a: Rect2 = g.ARENA
	var wall: Color = D.THEMES[theme].wall
	for x in range(int(a.position.x), int(a.end.x), 24):
		var width = minf(22,a.end.x - x)
		g.draw_rect(Rect2(x,a.position.y - 5,width,5),wall.lightened(0.12))
		g.draw_rect(Rect2(x,a.end.y,width,5),wall.darkened(0.2))
	for y in range(int(a.position.y), int(a.end.y), 24):
		var height = minf(22,a.end.y - y)
		g.draw_rect(Rect2(a.position.x - 5,y,5,height),wall.lightened(0.06))
		g.draw_rect(Rect2(a.end.x,y,5,height),wall.darkened(0.18))

static func reset_hazards(g):
	if g.world_data.is_empty():return
	g.world_data.hazards = []
	g.world_data.hazard_timer = 5.0
	g.world_data.hazard_serial = 0

static func _living_enemies(g) -> int:
	var count = 0
	for enemy in g.enemies:
		if enemy.hp > 0:count += 1
	return count

static func can_spawn_hazard(g, pos: Vector2, radius: float) -> bool:
	if not g.ARENA.grow(-radius - 12).has_point(pos):return false
	if pos.distance_to(g.CENTER) < SAFE_CENTER_RADIUS + radius + 12:return false
	# No warning appears underneath the player. The shape then stays locked;
	# walking into it later is a conscious positioning choice.
	if pos.distance_to(g.player) < radius + 48:return false
	for obstacle in g.obstacles:
		if obstacle.grow(radius + 12).has_point(pos):return false
	for existing in g.world_data.get("hazards",[]):
		if pos.distance_to(existing.pos) < radius + existing.radius + 42:return false
	return true

static func _spawn_hazard(g) -> bool:
	var w: Dictionary = g.world_data
	var radius = g.rng.randf_range(30.0,36.0 + float(w.intensity))
	var pos: Vector2 = g.CENTER
	var found = false
	for attempt in range(100):
		if attempt < 70:
			pos = g.player + Vector2.RIGHT.rotated(g.rng.randf() * TAU) * g.rng.randf_range(100,320)
		else:
			pos = Vector2(g.rng.randf_range(g.ARENA.position.x + 60,g.ARENA.end.x - 60),g.rng.randf_range(g.ARENA.position.y + 60,g.ARENA.end.y - 60))
		if can_spawn_hazard(g,pos,radius):found = true;break
	if not found:return false
	w.hazard_serial += 1
	w.hazards.append({"pos":pos.round(), "radius":radius, "state":"telegraph", "time":TELEGRAPH_TIME,
		"duration":TELEGRAPH_TIME, "hit":false, "theme":w.theme, "serial":w.hazard_serial,
		"damage":9.0 + mini(g.stage,20) * 0.5, "phase":g.rng.randf() * TAU})
	return true

static func contact_radius(hazard: Dictionary) -> float:
	return float(hazard.radius) + 10.0

static func update_hazards(g, dt: float):
	if g.world_data.is_empty():return
	var w: Dictionary = g.world_data
	# remaining_enemies includes future waves. No ambient danger remains while
	# collecting the last drops, choosing a relic, or entering the portal.
	if g.remaining_enemies() <= 0 or g.portal_open or g.hp <= 0:
		w.hazards.clear()
		return
	if g.state != "playing" or g.pending_choices > 0:return
	if _living_enemies(g) == 0:
		# Between waves there must be no invisible or active lingering damage.
		w.hazards.clear()
		w.hazard_timer = maxf(float(w.hazard_timer),2.0)
		return
	for i in range(w.hazards.size() - 1,-1,-1):
		var hazard: Dictionary = w.hazards[i]
		hazard.time -= maxf(dt,0.0)
		if hazard.time <= 0:
			match hazard.state:
				"telegraph":
					hazard.state = "active";hazard.time = ACTIVE_TIME;hazard.duration = ACTIVE_TIME
				"active":
					hazard.state = "recovery";hazard.time = RECOVERY_TIME;hazard.duration = RECOVERY_TIME
				"recovery":
					w.hazards.remove_at(i)
					continue
		if hazard.state == "active" and not hazard.hit and g.player.distance_to(hazard.pos) <= contact_radius(hazard):
			# One contact per eruption, including a contact avoided with a dash.
			# The shared damage function preserves armor and every hurt iframe.
			hazard.hit = true
			g.damage_player(hazard.damage)
			if g.hp <= 0:
				w.hazards.clear()
				return
	w.hazard_timer -= maxf(dt,0.0)
	var cap = 2 if g.stage <= 10 else 3
	if w.hazard_timer <= 0 and w.get("hazards_enabled",true):
		var batch = 2 if g.stage >= 11 else 1
		for i in range(batch):
			if w.hazards.size() >= cap:break
			_spawn_hazard(g)
		var pressure = clampf(float(g.stage - 1) / 19.0,0,1)
		w.hazard_timer = g.rng.randf_range(5.4 - pressure * 2.4,7.0 - pressure * 2.4)

static func draw_hazards(g):
	if g.world_data.is_empty() or g.hp <= 0 or g.portal_open or g.remaining_enemies() <= 0:return
	for h in g.world_data.hazards:
		var p: Vector2 = h.pos
		# The displayed boundary includes the same player-center contact padding
		# as the damage test, so no damaging space extends beyond the warning.
		var r: float = contact_radius(h)
		var progress = clampf(1.0 - float(h.time) / maxf(0.001,float(h.duration)),0,1)
		var accent: Color = D.THEMES[int(h.theme)].accent
		if h.state == "telegraph":
			# Strong yellow boundary and a closing timer; hollow interior always
			# remains readable over every one of the four themed floors.
			g.draw_circle(p,r,Color(0.07,0.04,0.03,0.34))
			g.draw_arc(p,r + 3,0,TAU,32,Color("33242b"),5)
			g.draw_arc(p,r + 3,0,TAU,32,Color("ffc75f"),2)
			g.draw_arc(p,r - 4,-PI / 2,-PI / 2 + TAU * progress,32,Color("ffe6a1"),3)
			g.draw_line(p + Vector2(-3,-10),p + Vector2(-3,2),Color("ffe6a1"),3)
			g.draw_rect(Rect2(p + Vector2(-4,7),Vector2(4,4)),Color("ffe6a1"))
			for i in range(4):
				var dir = Vector2.RIGHT.rotated(i * PI / 2)
				g.draw_line(p + dir * (r + 6),p + dir * (r + 11),Color("ffc75f"),2)
		elif h.state == "active":
			g.draw_circle(p,r,Color(accent,0.38))
			g.draw_arc(p,r + 2,0,TAU,32,Color("492234"),6)
			g.draw_arc(p,r + 2,0,TAU,32,Color("ff6e7d"),3)
			g.draw_arc(p,r - 2,0,TAU,32,Color("fff0c5"),2)
			_draw_active_hazard(g,h,progress)
		else:
			g.draw_circle(p,r,Color(accent,(1.0 - progress) * 0.1))
			for i in range(8):
				var angle = i * TAU / 8
				g.draw_arc(p,r,angle,angle + 0.33,4,Color(accent,(1.0 - progress) * 0.55),1)

static func _draw_active_hazard(g, h: Dictionary, progress: float):
	var p: Vector2 = h.pos
	var r: float = h.radius
	var accent: Color = D.THEMES[int(h.theme)].accent
	for i in range(7):
		var angle = i * TAU / 7 + h.phase
		var q = p + Vector2.RIGHT.rotated(angle) * r * 0.55
		match int(h.theme):
			0:
				g.draw_line(q + Vector2(-4,8),q + Vector2(1,-9),Color("c0e291"),3)
				g.draw_line(q + Vector2(1,-6),q + Vector2(6,-2),Color("87bb70"),3)
			1:
				var rise = 13 + sin(progress * 18 + i) * 4
				g.draw_colored_polygon(PackedVector2Array([q + Vector2(-5,6),q + Vector2(-2,-rise),q + Vector2(5,6)]),Color("ffd091"))
				g.draw_line(q,q + Vector2(0,-7),Color("fff3c4"),2)
			2:
				g.draw_colored_polygon(PackedVector2Array([q + Vector2(-4,6),q + Vector2(0,-12),q + Vector2(6,3),q + Vector2(1,8)]),accent)
				g.draw_line(q + Vector2(0,-8),q + Vector2(0,5),Color("e5faff"),2)
			3:
				g.draw_line(q + Vector2(-5,0),q + Vector2(5,0),Color("edccff"),2)
				g.draw_line(q + Vector2(0,-7),q + Vector2(0,5),Color("edccff"),2)
	if int(h.theme) == 3:
		g.draw_arc(p,r * (0.4 + progress * 0.35),0,TAU,24,Color("ead0ff"),2)

static func _polygon(center: Vector2, radius: float, sides: int, angle: float = 0.0, scale: Vector2 = Vector2.ONE) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(sides):
		var a = angle + i * TAU / float(sides)
		points.append((center + Vector2(cos(a),sin(a)) * scale * radius).round())
	return points

static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result = points.duplicate()
	if not result.is_empty():result.append(result[0])
	return result
