extends Node2D
## Pocket Wilds - tile overworld: map drawing, grid movement, NPCs, trainer sight, encounters, warps.

const Art = preload("res://scripts/Art.gd")
const TS = 32
const DIRV = {"up": Vector2i(0, -1), "down": Vector2i(0, 1), "left": Vector2i(-1, 0), "right": Vector2i(1, 0)}
const DIRC = {"up": "U", "down": "D", "left": "L", "right": "R"}
const CV = {"U": Vector2i(0, -1), "D": Vector2i(0, 1), "L": Vector2i(-1, 0), "R": Vector2i(1, 0)}
const OPP = {"U": "D", "D": "U", "L": "R", "R": "L"}

var main
var mapd: Dictionary = {}
var rows: Array = []
var W: int = 0
var H: int = 0
var cave: bool = false
var npcs: Array = []
var moving: bool = false
var mv_t: float = 0.0
var from: Vector2i = Vector2i.ZERO
var to: Vector2i = Vector2i.ZERO
var phase: float = 0.0
var exclaim: String = ""
var bump_cd: float = 0.0
var path: Array = []
var path_target = null
var t: float = 0.0
var enc_cd: int = 0
var cam: Vector2 = Vector2.ZERO

func load_map(name: String) -> void:
	mapd = D.MAPS[name]
	rows = mapd["rows"]
	H = rows.size()
	W = rows[0].length()
	cave = mapd["kind"] == "cave"
	moving = false
	path = []
	path_target = null
	refresh_npcs()

func refresh_npcs() -> void:
	npcs = []
	for n in mapd["npcs"]:
		var x: int = n["x"]
		var y: int = n["y"]
		if n["kind"] == "gate" and G.flags.get("gate", false):
			x = n["alt"][0]
			y = n["alt"][1]
		npcs.append({"d": n, "x": x, "y": y, "dir": n["dir"], "ox": 0.0, "oy": 0.0})

func ch(x: int, y: int) -> String:
	if x < 0 or y < 0 or y >= H or x >= W:
		return "W" if cave else "T"
	return rows[y][x]

func npc_at(x: int, y: int) -> Variant:
	for n in npcs:
		if n["x"] == x and n["y"] == y:
			return n
	return null

func solid(x: int, y: int) -> bool:
	if D.SOLID.contains(ch(x, y)):
		return true
	return npc_at(x, y) != null

func is_warp(c: String) -> bool:
	return c >= "0" and c <= "9" and c.length() == 1 and mapd["warps"].has(c)

func _process(delta: float) -> void:
	t += delta
	bump_cd -= delta
	if visible and main != null and main.mode == "over" and not mapd.is_empty():
		_update(delta)
	queue_redraw()

func _update(delta: float) -> void:
	if moving:
		var spd = 8.0 if main.is_held("b") else 4.8
		mv_t += delta * spd
		phase += delta * spd
		if mv_t >= 1.0:
			moving = false
			mv_t = 0.0
			G.px = to.x
			G.py = to.y
			G.steps += 1
			_arrived()
		return
	if main.busy > 0 or main.ui.size() > 0:
		return
	var d = ""
	for k in ["up", "down", "left", "right"]:
		if main.is_held(k):
			d = k
	if d != "":
		path.clear()
		path_target = null
	elif path.size() > 0:
		d = path.pop_front()
	elif path_target != null:
		var tgt: Vector2i = path_target
		path_target = null
		var dv = tgt - Vector2i(G.px, G.py)
		for k in DIRV:
			if DIRV[k] == dv:
				G.dir = DIRC[k]
		on_press("a")
		return
	if d == "":
		phase = 0.0
		return
	try_move(d)

func try_move(d: String) -> void:
	var v: Vector2i = DIRV[d]
	G.dir = DIRC[d]
	var nx = G.px + v.x
	var ny = G.py + v.y
	var c = ch(nx, ny)
	if is_warp(c) and mapd["warps"][c].size() > 3 and not G.flags.get(mapd["warps"][c][3], false):
		path.clear()
		main.interact("sign", mapd["warps"][c][4])
		return
	if solid(nx, ny):
		path.clear()
		path_target = null
		if bump_cd <= 0.0:
			Sfx.play("bump")
			bump_cd = 0.35
		return
	from = Vector2i(G.px, G.py)
	to = Vector2i(nx, ny)
	moving = true
	mv_t = 0.0

func _arrived() -> void:
	var c = ch(G.px, G.py)
	if is_warp(c):
		path.clear()
		main.warp(mapd["warps"][c])
		return
	for n in npcs:
		var k = n["d"]["kind"]
		if k in ["trainer", "warden", "champion"] and not G.flags.get(n["d"]["id"], false) and _sees(n):
			path.clear()
			path_target = null
			main.trainer_battle(n["d"])
			return
	if (c == "," or c == ":") and mapd["enc"].size() > 0 and G.party.size() > 0:
		enc_cd += 1
		if enc_cd > 2 and randf() < 0.13:
			enc_cd = 0
			path.clear()
			path_target = null
			var e = _pick_enc()
			main.wild_battle(e[0], randi_range(e[1], e[2]))

func _pick_enc() -> Array:
	var tot = 0
	for e in mapd["enc"]:
		tot += e[3]
	var r = randi() % tot
	for e in mapd["enc"]:
		r -= e[3]
		if r < 0:
			return e
	return mapd["enc"][0]

func _sees(n: Dictionary) -> bool:
	var v: Vector2i = CV[n["dir"]]
	for i in range(1, int(n["d"].get("sight", 0)) + 1):
		var p = Vector2i(n["x"], n["y"]) + v * i
		if p == Vector2i(G.px, G.py):
			return true
		if solid(p.x, p.y):
			return false
	return false

func on_press(b: String) -> void:
	if moving:
		return
	if b == "start":
		main.menus.pause()
	elif b == "a":
		var v: Vector2i = CV[G.dir]
		var x = G.px + v.x
		var y = G.py + v.y
		var n: Variant = npc_at(x, y)
		if n != null:
			main.interact("npc", n["d"])
			return
		var key = "%d,%d" % [x, y]
		var c = ch(x, y)
		if c == "O" and mapd["signs"].has(key):
			main.interact("sign", mapd["signs"][key])
		elif c in ["A", "S", "D"] and mapd["doors"].has(key):
			main.interact("door", mapd["doors"][key])

func face_npc(d: Dictionary) -> void:
	for n in npcs:
		if n["d"]["id"] == d["id"]:
			n["dir"] = OPP[G.dir]

func approach(d: Dictionary) -> void:
	var n: Variant = null
	for x in npcs:
		if x["d"]["id"] == d["id"]:
			n = x
	if n == null:
		return
	var v: Vector2i = CV[n["dir"]]
	for i in 8:
		var nx = n["x"] + v.x
		var ny = n["y"] + v.y
		if (nx == G.px and ny == G.py) or solid(nx, ny):
			break
		if main.auto:
			n["x"] = nx
			n["y"] = ny
			continue
		var k = 0.0
		while k < 1.0:
			await get_tree().process_frame
			k = minf(1.0, k + get_process_delta_time() * 5.0)
			n["ox"] = v.x * k * TS
			n["oy"] = v.y * k * TS
		n["x"] = nx
		n["y"] = ny
		n["ox"] = 0.0
		n["oy"] = 0.0
	G.dir = OPP[n["dir"]]

## Tap / click on the map: walk there with a short breadth-first path.
func tap_walk(p: Vector2) -> void:
	if moving and path.size() > 0:
		path.clear()
	var tile = Vector2i(floori((p.x + cam.x) / TS), floori((p.y + cam.y) / TS))
	var me = Vector2i(G.px, G.py)
	if tile == me:
		return
	var goals = []
	var interact = solid(tile.x, tile.y)
	if interact:
		for v in CV.values():
			if not solid(tile.x + v.x, tile.y + v.y) or tile + v == me:
				goals.append(tile + v)
	else:
		goals.append(tile)
	var prev = {me: me}
	var q = [me]
	var found = null
	while q.size() > 0 and prev.size() < 500:
		var cur: Vector2i = q.pop_front()
		if goals.has(cur):
			found = cur
			break
		for k in DIRV:
			var nb: Vector2i = cur + DIRV[k]
			if prev.has(nb) or solid(nb.x, nb.y):
				continue
			if is_warp(ch(nb.x, nb.y)) and not goals.has(nb):
				continue
			prev[nb] = cur
			q.append(nb)
	if found == null:
		return
	var steps = []
	var c: Vector2i = found
	while c != me:
		var pv: Vector2i = prev[c]
		for k in DIRV:
			if DIRV[k] == c - pv:
				steps.push_front(k)
		c = pv
	path = steps
	path_target = tile if interact else null

# ------------------------------------------------------------ drawing
func player_px() -> Vector2:
	if moving:
		return Vector2(from).lerp(Vector2(to), mv_t) * TS
	return Vector2(G.px, G.py) * TS

func _draw() -> void:
	if mapd.is_empty() or main == null:
		return
	var pp = player_px()
	cam = pp + Vector2(16, 16) - Vector2(240, 160)
	cam.x = clampf(cam.x, 0, W * TS - 480)
	cam.y = clampf(cam.y, 0, H * TS - 320)
	cam = cam.round()
	var vis = Rect2(-main.so, main.vs)
	var x0 = floori((vis.position.x + cam.x) / TS) - 1
	var x1 = floori((vis.end.x + cam.x) / TS) + 1
	var y0 = floori((vis.position.y + cam.y) / TS) - 1
	var y1 = floori((vis.end.y + cam.y) / TS) + 2
	var prow = maxi(from.y, to.y) if moving else G.py
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			Art.tile(self, ch(x, y), Vector2(x * TS, y * TS) - cam, x, y, t, cave)
		for x in range(x0, x1 + 1):
			if ch(x, y) == "T":
				Art.tree(self, Vector2(x * TS, y * TS) - cam, x, y, t)
		for n in npcs:
			if n["y"] == y:
				_draw_npc(n)
		if y == prow:
			var pos = pp - cam
			Art.person(self, pos, G.dir, phase if moving else 0.0, Color("2f9e8f"), Color("e8604c"), t)
			var under = to if moving else Vector2i(G.px, G.py)
			if ch(under.x, under.y) == ",":
				for i in 3:
					var bx = pos + Vector2(6 + i * 10, 31)
					Art.tri(self, bx + Vector2(-5, 0), bx + Vector2(sin(t * 2) * 2, -9), bx + Vector2(5, 0), Color("4a9c42"))
	if cave:
		var c = pp - cam + Vector2(16, 16)
		for i in 7:
			draw_arc(c, 120 + i * 32, 0, TAU, 48, Color(0.03, 0.02, 0.06, 0.2), 34)
		draw_arc(c, 420, 0, TAU, 48, Color(0.03, 0.02, 0.06, 0.7), 200)

func _draw_npc(n: Dictionary) -> void:
	var d = n["d"]
	var p = Vector2(n["x"] * TS + n["ox"], n["y"] * TS + n["oy"]) - cam
	var special = d["kind"] in ["warden", "champion"]
	var walking = n["ox"] != 0.0 or n["oy"] != 0.0
	Art.person(self, p, n["dir"], fmod(t * 5.0, 2.0) if walking else 0.0, Color(d["look"][0]), Color(d["look"][1]), t, special)
	if special and not G.flags.get(d["id"], false):
		var cy = p.y - 12 + sin(t * 3.0) * 2.0
		Art.tri(self, Vector2(p.x + 10, cy), Vector2(p.x + 16, cy - 8), Vector2(p.x + 22, cy), Color("ffd24a"))
	if exclaim == d["id"]:
		var b = Vector2(p.x + 16, p.y - 14)
		draw_circle(b, 10, Color.WHITE)
		draw_rect(Rect2(b + Vector2(-1.5, -7), Vector2(3, 8)), Color("e8604c"))
		draw_rect(Rect2(b + Vector2(-1.5, 3), Vector2(3, 3)), Color("e8604c"))
