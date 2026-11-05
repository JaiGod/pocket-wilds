extends RefCounted
## Pocket Wilds - procedural art. Every creature, tile and character is drawn with code.

const TS = 32
const SIL = Color(0.13, 0.12, 0.2)

static var _sil: bool = false
static var _flash: float = 0.0
static var _alpha: float = 1.0

static func c(col: Color) -> Color:
	var o = SIL if _sil else col
	if _flash > 0.0:
		o = o.lerp(Color.WHITE, _flash)
	o.a *= _alpha
	return o

static func ell(ci: CanvasItem, p: Vector2, r: Vector2, col: Color, n: int = 20) -> void:
	var pts = PackedVector2Array()
	for i in n:
		var a = TAU * i / n
		pts.append(p + Vector2(cos(a) * r.x, sin(a) * r.y))
	ci.draw_colored_polygon(pts, col)

static func tri(ci: CanvasItem, a: Vector2, b: Vector2, d: Vector2, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([a, b, d]), col)

static func leaf(ci: CanvasItem, base: Vector2, tip: Vector2, w: float, col: Color) -> void:
	var m = (base + tip) / 2.0
	var nrm = (tip - base).orthogonal().normalized() * w
	ci.draw_colored_polygon(PackedVector2Array([base, m + nrm, tip, m - nrm]), col)

static func flame(ci: CanvasItem, base: Vector2, h: float, w: float, t: float, c1: Color, c2: Color) -> void:
	var s = sin(t * 9.0) * 3.0
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-w, 0), base + Vector2(-w * 0.6, -h * 0.55), base + Vector2(s, -h), base + Vector2(w * 0.6, -h * 0.5), base + Vector2(w, 0)]), c1)
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-w * 0.5, 0), base + Vector2(s * 0.6, -h * 0.6), base + Vector2(w * 0.5, 0)]), c2)

static func eye(ci: CanvasItem, p: Vector2, r: float, look: float = 1.0) -> void:
	if _sil:
		return
	ci.draw_circle(p, r, c(Color.WHITE))
	ci.draw_circle(p + Vector2(r * 0.25 * look, 0), r * 0.6, c(Color(0.1, 0.08, 0.15)))
	ci.draw_circle(p + Vector2(r * 0.05 * look - r * 0.2, -r * 0.35), r * 0.22, c(Color.WHITE))

## Draw creature `sp` with its feet at `pos`. Faces right unless flip.
static func creature(ci: CanvasItem, sp: int, pos: Vector2, sc: float, t: float, sil: bool = false, flip: bool = false, flash: float = 0.0, alpha: float = 1.0) -> void:
	var d = D.SP[sp]
	_sil = sil
	_flash = flash
	_alpha = alpha
	var s = sc * d["size"]
	ci.draw_set_transform(pos, 0.0, Vector2(-s if flip else s, s))
	ell(ci, Vector2(0, 0), Vector2(30, 6), Color(0, 0, 0, 0.22 * alpha))
	var f: Array = d["feat"]
	var c1: Color = d["c1"]
	var c2: Color = d["c2"]
	var c3: Color = d["c3"]
	var b = sin(t * 3.0 + sp) * 2.0
	match d["plan"]:
		"quad": _quad(ci, f, c1, c2, c3, b, t, false)
		"deer": _quad(ci, f, c1, c2, c3, b, t, true)
		"blob": _blob(ci, f, c1, c2, c3, b, t)
		"fish": _fish(ci, f, c1, c2, c3, b, t)
		"bird": _bird(ci, f, c1, c2, c3, b, t)
		"moth": _moth(ci, f, c1, c2, c3, b, t)
		"golem": _golem(ci, f, c1, c2, c3, b, t)
		"wisp": _wisp(ci, f, c1, c2, c3, b, t)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_sil = false
	_flash = 0.0
	_alpha = 1.0

static func _quad(ci, f, c1, c2, c3, b, t, deer) -> void:
	var dk = c1.darkened(0.25)
	var leg = 30.0 if deer else 18.0
	var by = -leg - 10.0
	# tail
	if f.has("tflame"):
		flame(ci, Vector2(-30, by - 2), 26, 9, t, c(c3), c(Color(1, 0.95, 0.6)))
	elif f.has("tleaf"):
		leaf(ci, Vector2(-26, by), Vector2(-46, by - 18 + b), 7, c(c3))
	elif deer:
		ell(ci, Vector2(-28, by - 6), Vector2(5, 7), c(c2))
	else:
		ci.draw_line(Vector2(-26, by), Vector2(-42, by - 14 + b), c(c1), 6)
	# far legs
	for x in [-18.0, 14.0]:
		ci.draw_rect(Rect2(x - 3, by, 7, leg + 10), c(dk))
	ell(ci, Vector2(0, by), Vector2(28 if not deer else 24, 14), c(c1))
	ell(ci, Vector2(2, by + 5), Vector2(18, 6), c(c2))
	if f.has("stripes"):
		for x in [-14.0, -4.0, 6.0]:
			ci.draw_rect(Rect2(x, by - 13, 4, 10), c(dk))
	if f.has("spots"):
		for p in [Vector2(-12, by - 6), Vector2(-2, by - 9), Vector2(8, by - 5), Vector2(-16, by + 1)]:
			ci.draw_circle(p, 3, c(c2))
	if f.has("plates") or f.has("spikes"):
		var pc = c3 if f.has("plates") else c3.lightened(0.1)
		for i in 4:
			var x = -20 + i * 11
			tri(ci, Vector2(x - 6, by - 10), Vector2(x, by - 24 - (i % 2) * 4), Vector2(x + 6, by - 10), c(pc))
	# near legs
	for x in [-12.0, 20.0]:
		ci.draw_rect(Rect2(x - 4, by + 2, 8, leg + 8), c(c1))
		ci.draw_rect(Rect2(x - 5, -4, 10, 4), c(dk))
	# neck + head
	var hp = Vector2(26, by - 18 + b) if not deer else Vector2(24, by - 30 + b)
	if deer:
		ci.draw_line(Vector2(16, by - 4), hp + Vector2(-2, 6), c(c1), 10)
	if f.has("mane"):
		for i in 7:
			var a = -PI * 0.9 + i * 0.32
			var dirv = Vector2(cos(a), sin(a))
			tri(ci, hp + dirv.orthogonal() * 7, hp + dirv * 26, hp - dirv.orthogonal() * 7, c(c3 if i % 2 == 0 else c3.darkened(0.2)))
	if f.has("antlers"):
		var gl = 0.5 + sin(t * 4.0) * 0.5 if f.has("glow") else 0.0
		var ac = c(c3.lerp(Color.WHITE, gl * 0.4))
		for sx in [-1.0, 1.0]:
			var r = hp + Vector2(sx * 5, -10)
			var top = r + Vector2(sx * 10, -22)
			ci.draw_line(r, top, ac, 3)
			ci.draw_line(r + (top - r) * 0.45, r + (top - r) * 0.45 + Vector2(sx * 10, -4), ac, 3)
			ci.draw_line(r + (top - r) * 0.75, r + (top - r) * 0.75 + Vector2(-sx * 6, -8), ac, 3)
		if gl > 0.0 and not _sil:
			ci.draw_circle(hp + Vector2(0, -26), 18, Color(1, 0.95, 0.6, 0.12 * gl * _alpha))
	if f.has("ears"):
		tri(ci, hp + Vector2(-10, -8), hp + Vector2(-8, -26), hp + Vector2(0, -12), c(c1))
		tri(ci, hp + Vector2(0, -12), hp + Vector2(6, -27), hp + Vector2(10, -8), c(c1))
		tri(ci, hp + Vector2(-8, -10), hp + Vector2(-7, -21), hp + Vector2(-2, -12), c(c2))
	elif f.has("eround"):
		ci.draw_circle(hp + Vector2(-7, -11), 6, c(c1))
		ci.draw_circle(hp + Vector2(6, -12), 6, c(c1))
		ci.draw_circle(hp + Vector2(6, -12), 3, c(c2))
	elif deer:
		leaf(ci, hp + Vector2(-6, -6), hp + Vector2(-20, -14), 4, c(c1))
	ci.draw_circle(hp, 14 if not deer else 12, c(c1))
	ell(ci, hp + Vector2(9, 5), Vector2(8, 6), c(c2))
	ci.draw_circle(hp + Vector2(16, 3), 2.5, c(Color(0.15, 0.1, 0.1)))
	if f.has("horn"):
		tri(ci, hp + Vector2(2, -12), hp + Vector2(10, -30), hp + Vector2(10, -10), c(c3.lightened(0.3)))
	if f.has("leaf"):
		leaf(ci, hp + Vector2(-2, -12), hp + Vector2(-6, -32 + b), 7, c(c3))
		ci.draw_line(hp + Vector2(-2, -12), hp + Vector2(-5, -28 + b), c(c3.lightened(0.3)), 1)
	eye(ci, hp + Vector2(5, -3), 4.5)

static func _blob(ci, f, c1, c2, c3, b, t) -> void:
	var cy = -26.0 + b
	if f.has("cloud"):
		for p in [Vector2(-22, cy + 4), Vector2(22, cy + 4), Vector2(-14, cy - 16), Vector2(14, cy - 16), Vector2(0, cy - 22)]:
			ci.draw_circle(p, 12, c(c2))
	if f.has("ears_long"):
		for sx in [-1.0, 1.0]:
			ell(ci, Vector2(sx * 11, cy - 30), Vector2(6, 16), c(c1))
			ell(ci, Vector2(sx * 11, cy - 30), Vector2(3, 11), c(c2))
	ell(ci, Vector2(-12, -3), Vector2(9, 5), c(c1.darkened(0.25)))
	ell(ci, Vector2(12, -3), Vector2(9, 5), c(c1.darkened(0.25)))
	ci.draw_circle(Vector2(0, cy), 25, c(c1))
	ell(ci, Vector2(0, cy + 9), Vector2(16, 11), c(c2))
	if f.has("spikes"):
		for i in 3:
			var x = -14 + i * 14
			tri(ci, Vector2(x - 6, cy - 20), Vector2(x, cy - 32), Vector2(x + 6, cy - 20), c(c3))
	if f.has("bud"):
		ci.draw_line(Vector2(0, cy - 24), Vector2(0, cy - 34), c(Color("3b8a2c")), 3)
		ell(ci, Vector2(0, cy - 38), Vector2(7, 9), c(c3))
		leaf(ci, Vector2(0, cy - 30), Vector2(-12, cy - 36), 4, c(Color("4f9a3a")))
	if f.has("crown"):
		for i in 6:
			var a = -PI + 0.25 + i * (PI - 0.5) / 5.0
			var p = Vector2(cos(a) * 20, cy - 12 + sin(a) * 16)
			ell(ci, p, Vector2(8, 8), c(c3 if i % 2 == 0 else c3.lightened(0.25)))
	if f.has("horn"):
		tri(ci, Vector2(-5, cy - 22), Vector2(0, cy - 44), Vector2(5, cy - 22), c(Color("f6ecd0")))
	if f.has("drop"):
		tri(ci, Vector2(-6, cy - 22), Vector2(0, cy - 38), Vector2(6, cy - 22), c(c3))
		ci.draw_circle(Vector2(0, cy - 22), 6, c(c3))
	eye(ci, Vector2(-9, cy - 4), 6, 0.0)
	eye(ci, Vector2(9, cy - 4), 6, 0.0)
	if not _sil:
		ci.draw_circle(Vector2(-16, cy + 4), 3, c(Color(1, 0.5, 0.55, 0.5)))
		ci.draw_circle(Vector2(16, cy + 4), 3, c(Color(1, 0.5, 0.55, 0.5)))
		ci.draw_arc(Vector2(0, cy + 4), 4, 0.3, PI - 0.3, 8, c(Color(0.2, 0.1, 0.1)), 1.5)

static func _fish(ci, f, c1, c2, c3, b, t) -> void:
	var cy = -30.0 + b
	var lg = f.has("long")
	var tl = -58.0 if lg else -42.0
	var sw = sin(t * 5.0) * 6.0
	tri(ci, Vector2(-24, cy), Vector2(tl, cy - 18 + sw), Vector2(tl + 6, cy + 16 + sw), c(c3))
	if lg:
		ell(ci, Vector2(-34, cy + 2), Vector2(18, 8), c(c1))
	if f.has("feet"):
		ell(ci, Vector2(-8, -3), Vector2(8, 4), c(c3))
		ell(ci, Vector2(10, -3), Vector2(8, 4), c(c3))
		ci.draw_rect(Rect2(-10, cy + 10, 5, cy * -1 - 12), c(c1.darkened(0.2)))
		ci.draw_rect(Rect2(8, cy + 10, 5, cy * -1 - 12), c(c1.darkened(0.2)))
	tri(ci, Vector2(-14, cy - 14), Vector2(-4, cy - 34), Vector2(8, cy - 15), c(c3))
	ell(ci, Vector2(0, cy), Vector2(30, 19), c(c1))
	ell(ci, Vector2(2, cy + 8), Vector2(22, 8), c(c2))
	for i in 3:
		ci.draw_arc(Vector2(-10 + i * 8, cy - 2), 6, -0.8, 0.8, 6, c(c1.darkened(0.2)), 1.5)
	if f.has("fin"):
		tri(ci, Vector2(2, cy + 4), Vector2(-10, cy + 20 + sw * 0.5), Vector2(10, cy + 10), c(c3.lightened(0.15)))
	if f.has("crest"):
		for i in 3:
			leaf(ci, Vector2(14 + i * 4, cy - 16), Vector2(2 + i * 6, cy - 40 + i * 4), 4, c(c3.lightened(0.2)))
	ci.draw_arc(Vector2(24, cy + 6), 5, 0.2, 1.6, 6, c(Color(0.15, 0.1, 0.2)), 1.5)
	eye(ci, Vector2(16, cy - 5), 5.5)

static func _bird(ci, f, c1, c2, c3, b, t) -> void:
	var cy = -30.0 + b
	var flap = sin(t * 7.0)
	if f.has("long"):
		for i in 3:
			leaf(ci, Vector2(-16, cy + 2), Vector2(-48, cy - 10 + i * 10), 5, c(c3 if i != 1 else c1))
	else:
		tri(ci, Vector2(-16, cy - 4), Vector2(-32, cy - 10), Vector2(-30, cy + 8), c(c3))
	ci.draw_line(Vector2(-5, cy + 14), Vector2(-7, 0), c(Color("e8a040")), 3)
	ci.draw_line(Vector2(5, cy + 14), Vector2(5, 0), c(Color("e8a040")), 3)
	var r = Vector2(22, 19) if not f.has("fluff") else Vector2(24, 22)
	ell(ci, Vector2(0, cy), r, c(c1))
	ell(ci, Vector2(4, cy + 6), Vector2(14, 11), c(c2))
	if f.has("fluff") and not _sil:
		for p in [Vector2(-18, cy - 12), Vector2(-22, cy + 4), Vector2(-10, cy - 20), Vector2(14, cy - 18)]:
			ci.draw_circle(p, 6, c(c1.lightened(0.15)))
	if f.has("stripes"):
		for i in 3:
			ci.draw_line(Vector2(-14 + i * 6, cy - 14), Vector2(-8 + i * 6, cy + 2), c(c3), 2)
	var wp = Vector2(-6, cy - 2)
	ci.draw_colored_polygon(PackedVector2Array([wp, wp + Vector2(-26, -10 - flap * 16), wp + Vector2(-18, 4 - flap * 8), wp + Vector2(-4, 12)]), c(c1.darkened(0.18)))
	var hp = Vector2(14, cy - 18)
	if f.has("crest"):
		for i in 3:
			leaf(ci, hp + Vector2(-4, -8), hp + Vector2(-14 - i * 6, -26 + i * 6), 4, c(c3))
	ci.draw_circle(hp, 13, c(c1))
	tri(ci, hp + Vector2(10, -3), hp + Vector2(24, 2), hp + Vector2(10, 6), c(Color("f0b030")))
	eye(ci, hp + Vector2(4, -3), 4.5)

static func _moth(ci, f, c1, c2, c3, b, t) -> void:
	var cy = -40.0 + b * 2.0
	var big = f.has("big")
	var flap = 0.75 + 0.25 * sin(t * 8.0)
	var wr = Vector2(30, 22) * (1.25 if big else 1.0)
	for sx in [-1.0, 1.0]:
		ell(ci, Vector2(sx * wr.x * 0.7 * flap, cy - 8), Vector2(wr.x * flap, wr.y), c(c1.lightened(0.08)))
		ell(ci, Vector2(sx * wr.x * 0.5 * flap, cy + 14), Vector2(wr.x * 0.6 * flap, wr.y * 0.6), c(c1.darkened(0.12)))
		if f.has("spots"):
			ci.draw_circle(Vector2(sx * wr.x * 0.75 * flap, cy - 10), 7, c(c2))
			ci.draw_circle(Vector2(sx * wr.x * 0.75 * flap, cy - 10), 3.5, c(c3))
	ell(ci, Vector2(0, cy + 2), Vector2(9, 20), c(c1.darkened(0.3)))
	for i in 3:
		ci.draw_line(Vector2(-8, cy + 8 + i * 6), Vector2(8, cy + 8 + i * 6), c(c2.darkened(0.2)), 1.5)
	ci.draw_circle(Vector2(0, cy - 20), 10, c(c1.darkened(0.15)))
	ci.draw_line(Vector2(-4, cy - 28), Vector2(-12, cy - 42), c(c1.darkened(0.4)), 2)
	ci.draw_line(Vector2(4, cy - 28), Vector2(12, cy - 42), c(c1.darkened(0.4)), 2)
	ci.draw_circle(Vector2(-12, cy - 42), 3, c(c3))
	ci.draw_circle(Vector2(12, cy - 42), 3, c(c3))
	eye(ci, Vector2(-4, cy - 21), 3.5, 0.0)
	eye(ci, Vector2(4, cy - 21), 3.5, 0.0)

static func _golem(ci, f, c1, c2, c3, b, t) -> void:
	var dk = c1.darkened(0.3)
	var by = -8.0
	ci.draw_rect(Rect2(-18, by - 6, 12, 14), c(dk))
	ci.draw_rect(Rect2(6, by - 6, 12, 14), c(dk))
	ci.draw_rect(Rect2(-24, by - 44 + b, 48, 40), c(c1))
	ci.draw_rect(Rect2(-24, by - 44 + b, 48, 6), c(c2))
	ci.draw_rect(Rect2(-14, by - 26 + b, 28, 16), c(c2.darkened(0.08)))
	ci.draw_line(Vector2(-10, by - 34 + b), Vector2(4, by - 22 + b), c(dk), 2)
	ci.draw_rect(Rect2(-36, by - 38 + b * 1.5, 12, 26), c(c1.darkened(0.12)))
	ci.draw_rect(Rect2(24, by - 38 + b * 1.5, 12, 26), c(c1.darkened(0.12)))
	ci.draw_rect(Rect2(-16, by - 66 + b, 32, 24), c(c1))
	ci.draw_rect(Rect2(-16, by - 66 + b, 32, 4), c(c2))
	if f.has("crystal"):
		var g = 0.5 + 0.5 * sin(t * 3.0)
		for p in [[-10, 14], [0, 24], [10, 16]]:
			var base = Vector2(p[0], by - 66 + b)
			ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-5, 0), base + Vector2(0, -p[1]), base + Vector2(5, 0)]), c(c3.lerp(Color.WHITE, g * 0.3)))
		if not _sil:
			ci.draw_circle(Vector2(0, by - 80 + b), 16, Color(c3.r, c3.g, c3.b, 0.15 * g * _alpha))
	if _sil:
		return
	var ec = c(c3.lerp(Color.WHITE, 0.3))
	ci.draw_rect(Rect2(-10, by - 57 + b, 7, 5), ec)
	ci.draw_rect(Rect2(4, by - 57 + b, 7, 5), ec)

static func _wisp(ci, f, c1, c2, c3, b, t) -> void:
	var cy = -40.0 + b * 3.0
	if f.has("wings"):
		for sx in [-1.0, 1.0]:
			var a = sin(t * 6.0) * 0.2
			ell(ci, Vector2(sx * 26, cy - 4 + a * 20), Vector2(18, 10), c(Color(c2.r, c2.g, c2.b, 0.55)))
	for i in 4:
		var tt = t * 2.0 + i
		ci.draw_circle(Vector2(sin(tt * 1.7) * 18, cy + 26 + i * 6), 3.5 - i * 0.6, c(c3))
	var s = sin(t * 6.0) * 4.0
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-20, cy + 6), Vector2(-16, cy - 14), Vector2(-4 + s, cy - 40), Vector2(6, cy - 26), Vector2(12 - s * 0.5, cy - 44), Vector2(20, cy - 10), Vector2(20, cy + 6), Vector2(0, cy + 22)]), c(c1))
	ci.draw_circle(Vector2(0, cy + 2), 19, c(c1))
	ci.draw_circle(Vector2(0, cy + 4), 12, c(c2))
	if f.has("halo"):
		ci.draw_arc(Vector2(0, cy - 44), 15, 0, TAU, 24, c(c3), 3)
	eye(ci, Vector2(-7, cy), 5, 0.0)
	eye(ci, Vector2(7, cy), 5, 0.0)

# ------------------------------------------------------------ tiles
static func h(x: int, y: int) -> int:
	return absi((x * 73856093) ^ (y * 19349663)) % 1000

static func ground(ci: CanvasItem, p: Vector2, x: int, y: int, cave: bool) -> void:
	if cave:
		ci.draw_rect(Rect2(p, Vector2(TS, TS)), Color("3a3046"))
		if h(x, y) % 3 == 0:
			ci.draw_rect(Rect2(p + Vector2(h(x, y) % 24, 8 + h(y, x) % 18), Vector2(4, 3)), Color("4a3f58"))
		return
	ci.draw_rect(Rect2(p, Vector2(TS, TS)), Color("7cc46a"))
	var k = h(x, y)
	if k % 3 == 0:
		var q = p + Vector2(4 + k % 20, 6 + (k / 10) % 18)
		ci.draw_line(q, q + Vector2(-2, -4), Color("5fa84f"), 1)
		ci.draw_line(q, q + Vector2(2, -4), Color("5fa84f"), 1)

static func tile(ci: CanvasItem, ch: String, p: Vector2, x: int, y: int, t: float, cave: bool) -> void:
	var r = Rect2(p, Vector2(TS, TS))
	match ch:
		".":
			ground(ci, p, x, y, false)
		",":
			ci.draw_rect(r, Color("5fae52"))
			for i in 3:
				for j in 2:
					var bx = p + Vector2(4 + i * 10 + (j * 5), 14 + j * 14)
					var sw = sin(t * 2.0 + x * 0.7 + y * 0.3) * 2.0
					tri(ci, bx + Vector2(-5, 0), bx + Vector2(sw, -14), bx + Vector2(5, 0), Color("3f8c3a") if j == 0 else Color("4a9c42"))
		"f":
			ground(ci, p, x, y, false)
			var cols = [Color("f6e05a"), Color("f088b0"), Color("ffffff")]
			for i in 3:
				var q = p + Vector2(6 + (h(x + i, y) % 20), 6 + (h(x, y + i) % 20))
				for k in 4:
					ci.draw_circle(q + Vector2(cos(k * 1.57) * 2.5, sin(k * 1.57) * 2.5), 2, cols[(x + y + i) % 3])
				ci.draw_circle(q, 1.5, Color("e89030"))
		"=":
			ci.draw_rect(r, Color("d8bf86"))
			var k = h(x, y)
			ci.draw_circle(p + Vector2(6 + k % 20, 8 + (k / 7) % 16), 2, Color("bba06a"))
			ci.draw_circle(p + Vector2(20 - k % 9, 22 - (k / 3) % 8), 1.5, Color("c8ad78"))
		"+":
			ci.draw_rect(r, Color("d6d2e4"))
			ci.draw_rect(Rect2(p + Vector2(1, 1), Vector2(14, 14)), Color("e6e2f2"))
			ci.draw_rect(Rect2(p + Vector2(17, 17), Vector2(14, 14)), Color("e6e2f2"))
		"~":
			ci.draw_rect(r, Color("3f8fd8"))
			var o = fmod(t * 8.0 + x * 5 + y * 11, 32.0)
			ci.draw_line(p + Vector2(o - 8, 10), p + Vector2(o, 10), Color("8cc8f4"), 2)
			ci.draw_line(p + Vector2(fmod(o + 16, 32) - 6, 24), p + Vector2(fmod(o + 16, 32), 24), Color("6cb0ec"), 2)
		"T":
			ground(ci, p, x, y, false)
		"#":
			ci.draw_rect(r, Color("9a8a76"))
			ci.draw_rect(Rect2(p + Vector2(0, 22), Vector2(TS, 10)), Color("7a6a58"))
			ci.draw_line(p + Vector2(4, 8), p + Vector2(14, 14), Color("b8a890"), 2)
		"W":
			ci.draw_rect(r, Color("231b2e"))
			ci.draw_rect(Rect2(p + Vector2(0, 24), Vector2(TS, 8)), Color("16101e"))
			if h(x, y) % 4 == 0:
				tri(ci, p + Vector2(8, 24), p + Vector2(14, 8), p + Vector2(20, 24), Color("3a2e4a"))
			if h(x, y) % 9 == 1:
				ci.draw_circle(p + Vector2(22, 12), 3, Color(0.6, 0.85, 1.0, 0.5 + 0.3 * sin(t * 2 + x)))
		"_":
			ground(ci, p, x, y, true)
		":":
			ground(ci, p, x, y, true)
			ci.draw_rect(Rect2(p + Vector2(6, 18), Vector2(6, 4)), Color("50445e"))
			ci.draw_rect(Rect2(p + Vector2(20, 8), Vector2(5, 3)), Color("50445e"))
		"R", "r", "q":
			var rc = Color("3aa8a0") if ch == "R" else (Color("e0a040") if ch == "r" else Color("a8604a"))
			ci.draw_rect(r, rc)
			for i in 4:
				ci.draw_line(p + Vector2(0, i * 8 + 6), p + Vector2(TS, i * 8 + 6), rc.darkened(0.2), 2)
		"H", "A", "S", "D":
			ci.draw_rect(r, Color("f2e8d0"))
			ci.draw_rect(Rect2(p + Vector2(0, 28), Vector2(TS, 4)), Color("c8b898"))
			if ch == "H":
				ci.draw_rect(Rect2(p + Vector2(8, 8), Vector2(16, 12)), Color("6aa0d0"))
				ci.draw_rect(Rect2(p + Vector2(15, 8), Vector2(2, 12)), Color("f2e8d0"))
			else:
				ci.draw_rect(Rect2(p + Vector2(7, 6), Vector2(18, 26)), Color("7a5236"))
				ci.draw_circle(p + Vector2(21, 20), 1.5, Color("f0d060"))
				if ch == "A":
					leaf(ci, p + Vector2(16, 18), p + Vector2(16, 6), 5, Color("6ad08a"))
				elif ch == "S":
					ci.draw_circle(p + Vector2(16, 12), 5, Color("f0c040"))
		"O":
			ground(ci, p, x, y, cave)
			ci.draw_rect(Rect2(p + Vector2(14, 16), Vector2(4, 14)), Color("7a5236"))
			ci.draw_rect(Rect2(p + Vector2(5, 5), Vector2(22, 13)), Color("a8784a"))
			ci.draw_rect(Rect2(p + Vector2(8, 8), Vector2(16, 2)), Color("6a4a2a"))
			ci.draw_rect(Rect2(p + Vector2(8, 12), Vector2(12, 2)), Color("6a4a2a"))
		_:
			# warp tiles
			if cave:
				ground(ci, p, x, y, true)
				ci.draw_rect(Rect2(p + Vector2(4, 0), Vector2(24, 32)), Color(0, 0, 0, 0.5))
			else:
				ci.draw_rect(r, Color("d8bf86"))

static func tree(ci: CanvasItem, p: Vector2, x: int, y: int, t: float) -> void:
	var k = h(x, y)
	ci.draw_rect(Rect2(p + Vector2(12, 18), Vector2(8, 14)), Color("6a4a2e"))
	ell(ci, p + Vector2(16, 30), Vector2(13, 4), Color(0, 0, 0, 0.18))
	var sway = sin(t * 1.3 + x) * 0.8
	var base = Color("2f7d3a") if k % 2 == 0 else Color("3a8a3e")
	ci.draw_circle(p + Vector2(16 + sway, 10), 16, base.darkened(0.15))
	ci.draw_circle(p + Vector2(11 + sway, 6), 10, base)
	ci.draw_circle(p + Vector2(21 + sway, 8), 10, base)
	ci.draw_circle(p + Vector2(13 + sway, 1), 5, base.lightened(0.18))

## Little top-down explorer / NPC. `p` is the tile's top-left.
static func person(ci: CanvasItem, p: Vector2, dir: String, phase: float, hat: Color, shirt: Color, t: float, special: bool = false) -> void:
	var cx = p.x + 16
	var bob = absf(sin(phase * PI)) * -2.0
	ell(ci, Vector2(cx, p.y + 29), Vector2(10, 3.5), Color(0, 0, 0, 0.25))
	var lg = sin(phase * PI) * 3.0
	ci.draw_rect(Rect2(cx - 6, p.y + 20 + bob, 5, 8 + lg), Color("3a3a50"))
	ci.draw_rect(Rect2(cx + 1, p.y + 20 + bob, 5, 8 - lg), Color("3a3a50"))
	if special:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(cx - 9, p.y + 12 + bob), Vector2(cx + 9, p.y + 12 + bob), Vector2(cx + 12, p.y + 27), Vector2(cx - 12, p.y + 27)]), shirt.darkened(0.3))
	ci.draw_rect(Rect2(cx - 8, p.y + 11 + bob, 16, 11), shirt)
	ci.draw_rect(Rect2(cx - 10, p.y + 12 + bob, 3, 8), shirt.darkened(0.15))
	ci.draw_rect(Rect2(cx + 7, p.y + 12 + bob, 3, 8), shirt.darkened(0.15))
	var hc = Vector2(cx, p.y + 6 + bob)
	ci.draw_circle(hc, 8, Color("f2c9a0"))
	ci.draw_colored_polygon(PackedVector2Array([hc + Vector2(-9, -1), hc + Vector2(-7, -8), hc + Vector2(0, -11), hc + Vector2(7, -8), hc + Vector2(9, -1)]), hat)
	if dir == "U":
		ell(ci, hc + Vector2(0, 1), Vector2(8, 6), hat)
	else:
		var ex = 0.0
		if dir == "L":
			ex = -3.0
		elif dir == "R":
			ex = 3.0
		if dir == "D":
			ci.draw_rect(Rect2(hc + Vector2(-4, 0), Vector2(2, 3)), Color("222"))
			ci.draw_rect(Rect2(hc + Vector2(2, 0), Vector2(2, 3)), Color("222"))
		else:
			ci.draw_rect(Rect2(hc + Vector2(ex - 1, 0), Vector2(2, 3)), Color("222"))

static func charm(ci: CanvasItem, p: Vector2, r: float, rot: float, col: Color) -> void:
	var pts = PackedVector2Array()
	for i in 8:
		var a = rot + i * TAU / 8.0
		var rr = r if i % 2 == 0 else r * 0.62
		pts.append(p + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, col)
	ci.draw_circle(p, r * 0.38, Color("fff6dc"))
	ci.draw_circle(p, r * 0.18, col.darkened(0.3))
