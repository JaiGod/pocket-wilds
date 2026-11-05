extends Node2D
## Pocket Wilds - root scene: input, layout, dialog/menu system, transitions, title and story flow.

const Art = preload("res://scripts/Art.gd")
const OverworldScript = preload("res://scripts/Overworld.gd")
const BattleScript = preload("res://scripts/Battle.gd")
const MenusScript = preload("res://scripts/Menus.gd")

const SW = 480
const SH = 320
const KEYS = {
	KEY_UP: "up", KEY_W: "up", KEY_DOWN: "down", KEY_S: "down", KEY_LEFT: "left", KEY_A: "left",
	KEY_RIGHT: "right", KEY_D: "right", KEY_Z: "a", KEY_SPACE: "a", KEY_ENTER: "a", KEY_KP_ENTER: "a",
	KEY_J: "a", KEY_X: "b", KEY_BACKSPACE: "b", KEY_K: "b", KEY_SHIFT: "b", KEY_ESCAPE: "start",
	KEY_P: "start", KEY_C: "start", KEY_M: "mute",
}

class Waiter:
	signal fired(v)

var world: Node2D
var battle: Node2D
var overlay: Node2D
var menus
var font: Font
var panel_sb: StyleBoxFlat
var dark_sb: StyleBoxFlat

var mode: String = "boot"
var ui: Array = []
var so: Vector2 = Vector2.ZERO
var vs: Vector2 = Vector2(SW, SH)
var portrait: bool = false
var touch_seen: bool = false
var held: Dictionary = {}
var touches: Dictionary = {}
var pad: Dictionary = {}
var fade_a: float = 0.0
var wipe_t: float = 0.0
var shake: float = 0.0
var parts: Array = []
var toast_text: String = ""
var toast_t: float = 0.0
var t: float = 0.0
var busy: int = 0
var auto: bool = false
var auto_choices: Array = []
var force_catch: bool = false
var evo: Dictionary = {}
var end_t: float = 0.0

func _ready() -> void:
	font = ThemeDB.fallback_font
	panel_sb = _sb(Color("fbf6e9"), Color("3a3550"))
	dark_sb = _sb(Color(0.08, 0.07, 0.14, 0.92), Color("8fe3c3"))
	world = OverworldScript.new()
	world.main = self
	add_child(world)
	battle = BattleScript.new()
	battle.main = self
	battle.visible = false
	add_child(battle)
	overlay = Node2D.new()
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)
	menus = MenusScript.new()
	menus.main = self
	world.visible = false
	layout()
	_web_hooks()
	if not auto and not OS.has_feature("smoke"):
		title_flow()

# ------------------------------------------------------------ web test hooks
# window.pwState mirrors the game state; window.pwCmd("wild") starts a wild
# battle from the overworld. Used by the automated browser beta test.
var _js_cb = null
var _js_t: float = 0.0

func _web_hooks() -> void:
	if not OS.has_feature("web"):
		return
	_js_cb = JavaScriptBridge.create_callback(_js_cmd)
	JavaScriptBridge.get_interface("window").pwCmd = _js_cb

func _js_cmd(args: Array) -> void:
	var c = str(args[0]) if args.size() > 0 else ""
	if c == "wild" and mode == "over" and busy == 0 and ui.is_empty():
		wild_battle([3, 19, 13, 7][randi() % 4], 4)

func _web_state(delta: float) -> void:
	if _js_cb == null:
		return
	_js_t += delta
	if _js_t < 0.25:
		return
	_js_t = 0.0
	var st = {"mode": mode, "map": G.map, "ui": ui.size(), "busy": busy, "party": G.party.size()}
	JavaScriptBridge.eval("window.pwState=" + JSON.stringify(st), true)

func _sb(bg: Color, border: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(3)
	s.set_corner_radius_all(7)
	s.anti_aliasing = false
	return s

# ------------------------------------------------------------ frame
func _process(delta: float) -> void:
	t += delta
	layout()
	shake = maxf(0.0, shake - delta * 30.0)
	var off = Vector2(randf_range(-shake, shake), randf_range(-shake, shake)).round()
	world.position = so + off
	battle.position = so + off
	overlay.position = so
	for w in ui.duplicate():
		if w["type"] == "say":
			w["shown"] = minf(w["text"].length(), w["shown"] + delta * 60.0)
			if w["quick"] and w["shown"] >= w["text"].length() and w == ui[-1]:
				w["hold"] += delta
				if w["hold"] > 0.85:
					_close(w, null)
	for p in parts:
		p["p"] += p["v"] * delta
		p["v"].y += p.get("g", 160.0) * delta
		p["life"] -= delta
	parts = parts.filter(func(p): return p["life"] > 0.0)
	toast_t = maxf(0.0, toast_t - delta)
	if mode == "end":
		end_t += delta
	overlay.queue_redraw()
	_web_state(delta)

func layout() -> void:
	vs = get_viewport_rect().size
	portrait = vs.y > SH + 190
	if portrait:
		so = Vector2(floorf((vs.x - SW) / 2.0), 46)
		var top = so.y + SH + 14
		var cy = top + (vs.y - top) * 0.42
		var r = clampf((vs.y - top) * 0.2, 46, 78)
		pad = {"dpad": [Vector2(vs.x * 0.26, cy), r], "a": [Vector2(vs.x * 0.83, cy - r * 0.35), r * 0.5],
			"b": [Vector2(vs.x * 0.63, cy + r * 0.45), r * 0.44], "start": [Vector2(vs.x * 0.5, minf(vs.y - 30, cy + r * 1.6)), 20],
			"mute": [Vector2(vs.x - 26, 23), 16]}
	else:
		so = ((vs - Vector2(SW, SH)) / 2.0).floor()
		var side = so.x
		if side >= 84:
			var r2 = minf(side * 0.42, 62)
			pad = {"dpad": [Vector2(side / 2.0, vs.y * 0.6), r2], "a": [Vector2(vs.x - side * 0.36, vs.y * 0.55), r2 * 0.48],
				"b": [Vector2(vs.x - side * 0.66, vs.y * 0.68), r2 * 0.42], "start": [Vector2(vs.x - side / 2.0, 34), 18], "mute": [Vector2(side / 2.0, 34), 18]}
		else:
			pad = {"dpad": [Vector2(64, vs.y - 66), 52], "a": [Vector2(vs.x - 44, vs.y - 92), 26],
				"b": [Vector2(vs.x - 98, vs.y - 52), 23], "start": [Vector2(vs.x - 30, 26), 16], "mute": [Vector2(30, 26), 16]}

func pad_visible() -> bool:
	return portrait or touch_seen

# ------------------------------------------------------------ input
func _input(e: InputEvent) -> void:
	if e is InputEventKey:
		var b = KEYS.get(e.keycode, "")
		if b == "":
			return
		if e.pressed:
			if not e.echo or (ui.size() > 0 and b in ["up", "down", "left", "right"]):
				press(b)
			held[b] = true
		else:
			held[b] = false
	elif e is InputEventScreenTouch:
		touch_seen = true
		_pointer(e.position, e.pressed, e.index)
	elif e is InputEventScreenDrag:
		_drag(e.position, e.index)
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_pointer(e.position, e.pressed, -1)
	elif e is InputEventMouseMotion and touches.has(-1):
		_drag(e.position, -1)

func _dpad_dir(p: Vector2) -> String:
	var d = p - pad["dpad"][0]
	if d.length() < 8:
		return ""
	if absf(d.x) > absf(d.y):
		return "right" if d.x > 0 else "left"
	return "down" if d.y > 0 else "up"

func _pointer(p: Vector2, down: bool, idx: int) -> void:
	if down:
		var hit = ""
		if pad_visible():
			for k in pad:
				if p.distance_to(pad[k][0]) <= pad[k][1] * (1.35 if k == "dpad" else 1.25):
					hit = k
					break
		if hit == "dpad":
			var dd = _dpad_dir(p)
			touches[idx] = dd
			if dd != "":
				held[dd] = true
				press(dd)
			return
		if hit != "":
			touches[idx] = hit
			held[hit] = true
			press(hit)
			return
		_tap_screen(p - so)
	else:
		if touches.has(idx):
			held[touches[idx]] = false
			touches.erase(idx)

func _drag(p: Vector2, idx: int) -> void:
	if not touches.has(idx):
		return
	var cur = touches[idx]
	if not cur in ["", "up", "down", "left", "right"]:
		return
	var nd = _dpad_dir(p)
	if nd != cur:
		if cur != "":
			held[cur] = false
		touches[idx] = nd
		if nd != "":
			held[nd] = true
			press(nd)

func _tap_screen(p: Vector2) -> void:
	if ui.size() > 0:
		var w = ui[-1]
		if w["type"] == "say":
			press("a")
			return
		for hr in w.get("hit", []):
			if hr[0].has_point(p):
				if w["sel"] == hr[1]:
					press("a")
				else:
					w["sel"] = hr[1]
					Sfx.play("blip")
				return
		return
	if mode == "end" and end_t > 3.0:
		press("a")
	elif mode == "over" and busy == 0 and Rect2(0, 0, SW, SH).has_point(p):
		world.tap_walk(p)

func press(b: String) -> void:
	if b == "mute":
		G.set_sound(not G.sound_on)
		toast("Sound " + ("on" if G.sound_on else "off"))
		return
	if ui.size() > 0:
		_ui_press(ui[-1], b)
		return
	if mode == "over" and busy == 0:
		world.on_press(b)
	elif mode == "end" and end_t > 3.0 and b == "a":
		end_t = 0.0
		mode = "over"
		Sfx.play_music(D.MAPS[G.map]["music"])

func is_held(b: String) -> bool:
	return held.get(b, false)

# ------------------------------------------------------------ dialog & menus
func say(text: String, speaker: String = "", quick: bool = false) -> void:
	if auto:
		await get_tree().process_frame
		return
	var w = {"type": "say", "text": text, "shown": 0.0, "speaker": speaker, "waiter": Waiter.new(), "quick": quick, "hold": 0.0}
	ui.append(w)
	await w["waiter"].fired

func menu(opts: Array, cfg: Dictionary = {}) -> int:
	if auto:
		await get_tree().process_frame
		if auto_choices.size() > 0:
			return auto_choices.pop_front()
		return 0
	var w = {"type": "menu", "opts": opts, "sel": clampi(cfg.get("sel", 0), 0, maxi(0, opts.size() - 1)), "cfg": cfg, "waiter": Waiter.new(), "scroll": 0, "hit": []}
	ui.append(w)
	return await w["waiter"].fired

func confirm(q: String) -> bool:
	return await menu(["Yes", "No"], {"prompt": q, "rect": Rect2(380, 166, 92, 66)}) == 0

func _close(w: Dictionary, v) -> void:
	ui.erase(w)
	w["waiter"].fired.emit(v)

func _ui_press(w: Dictionary, b: String) -> void:
	if w["type"] == "say":
		if b == "a" or b == "b":
			if w["shown"] < w["text"].length():
				w["shown"] = float(w["text"].length())
			else:
				Sfx.play("blip")
				_close(w, null)
		return
	var cfg: Dictionary = w["cfg"]
	var cols: int = cfg.get("cols", 1)
	var n: int = w["opts"].size()
	var s: int = w["sel"]
	match b:
		"up": s -= cols
		"down": s += cols
		"left": s -= 1 if cols > 1 else 0
		"right": s += 1 if cols > 1 else 0
		"a":
			Sfx.play("select")
			_close(w, s)
			return
		"b", "start":
			if cfg.get("cancel", true):
				Sfx.play("back")
				_close(w, -1)
			return
	if n > 0:
		s = clampi(s, 0, n - 1)
		if s != w["sel"]:
			Sfx.play("blip")
		w["sel"] = s

func toast(text: String) -> void:
	toast_text = text
	toast_t = 2.2

# ------------------------------------------------------------ juice
func burst(p: Vector2, col: Color, n: int = 14, spd: float = 120.0, g: float = 160.0) -> void:
	for i in n:
		var a = randf() * TAU
		parts.append({"p": p, "v": Vector2(cos(a), sin(a)) * randf_range(spd * 0.3, spd), "life": randf_range(0.35, 0.8), "col": col, "s": randf_range(2.0, 4.5), "g": g})

func fade(to: float, dur: float = 0.25) -> void:
	if auto:
		fade_a = to
		return
	var tw = create_tween()
	tw.tween_property(self, "fade_a", to, dur)
	await tw.finished

func wait(sec: float) -> void:
	if auto:
		await get_tree().process_frame
		return
	await get_tree().create_timer(sec).timeout

func wipe() -> void:
	Sfx.play("encounter")
	if auto:
		return
	wipe_t = 0.0
	var tw = create_tween()
	tw.tween_property(self, "wipe_t", 1.0, 0.7)
	await tw.finished

# ------------------------------------------------------------ flow
func title_flow() -> void:
	mode = "title"
	ui.clear()
	world.visible = false
	battle.visible = false
	fade_a = 0.0
	Sfx.play_music("title")
	while true:
		var opts = []
		if G.has_save():
			opts.append("Continue")
		opts.append_array(["New Game", "How to Play", "Sound: " + ("On" if G.sound_on else "Off")])
		var i = await menu(opts, {"rect": Rect2(170, 172, 140, 26 + opts.size() * 24), "cancel": false, "row_h": 24})
		var o: String = opts[i]
		if o == "Continue":
			if G.load_game():
				await start_world()
				toast("Welcome back, explorer!")
				return
			toast("Save could not be loaded.")
		elif o == "New Game":
			if G.has_save() and not await confirm("Start over? Your saved journey will be replaced."):
				continue
			await new_game()
			return
		elif o == "How to Play":
			await how_to()
		else:
			G.set_sound(not G.sound_on)

func how_to() -> void:
	await say("Move with the Arrow keys or WASD (or the D-pad). Z / Space / Enter is A: talk, confirm. X / Backspace is B: cancel, hold to jog.")
	await say("Esc or P opens the menu: Team, Bag, Codex and Save. M toggles sound. On phones use the on-screen buttons, or tap the map to walk.")
	await say("Walk through tall grass to meet wild creatures. Weaken one, then toss a Bonding Charm from your Bag to bond with it.")
	await say("Each element beats two others. Beat three Wardens to earn their sigils, then climb Crown Spire to face the Champion!")

func new_game() -> void:
	G.reset()
	await fade(1.0, 0.3)
	mode = "starter"
	await fade(0.0, 0.3)
	await say("Welcome to the Wilds! I'm Keeper Oda, the Codex keeper of Mossgate.", "Keeper Oda")
	await say("Every explorer begins with one partner. Choose the one whose spirit matches yours!", "Keeper Oda")
	var starters = [1, 5, 9]
	for s in starters:
		G.seen[s] = true
	var pick = 0
	while true:
		pick = await menu(["Mosskit", "Puddlefin", "Cinderpup"], {"cols": 3, "cancel": false, "rect": Rect2(16, 30, 448, 190), "row_h": 160, "sel": pick, "draw_row": _draw_starter})
		if await confirm("Choose %s, the %s creature?" % [D.SP[starters[pick]]["name"], D.TYPES[D.SP[starters[pick]]["type"]]]):
			break
	var m = G.new_mon(starters[pick], 5)
	G.add_mon(m)
	Sfx.play("level")
	await say("You and %s are now partners!" % G.mname(m))
	await say("Take these 5 Bonding Charms and 3 Berry Tonics. The Haven to the east heals your team for free.", "Keeper Oda")
	await say("Head north through Fernway Path. The Wilds are waiting!", "Keeper Oda")
	await fade(1.0, 0.3)
	await start_world()
	G.save_game()

func start_world() -> void:
	mode = "over"
	battle.visible = false
	world.visible = true
	world.load_map(G.map)
	Sfx.play_music(D.MAPS[G.map]["music"])
	await fade(0.0, 0.3)

func warp(w: Array) -> void:
	busy += 1
	Sfx.play("door")
	await fade(1.0, 0.2)
	G.map = w[0]
	G.px = w[1]
	G.py = w[2]
	world.load_map(G.map)
	Sfx.play_music(D.MAPS[G.map]["music"])
	toast(D.MAPS[G.map]["name"])
	await fade(0.0, 0.2)
	busy -= 1

func wild_battle(sp: int, lv: int) -> void:
	busy += 1
	await wipe()
	var res = await _battle([G.new_mon(sp, lv)], {})
	await _after_battle(res, {})
	busy -= 1

func trainer_battle(npc: Dictionary) -> void:
	busy += 1
	world.exclaim = npc["id"]
	Sfx.play("exclaim")
	await wait(0.7)
	world.exclaim = ""
	await world.approach(npc)
	await say(npc["pre"], npc["name"])
	await wipe()
	var team = []
	for e in npc["team"]:
		team.append(G.new_mon(e[0], e[1]))
	var res = await _battle(team, npc)
	await _after_battle(res, npc)
	busy -= 1

func _battle(team: Array, npc: Dictionary) -> String:
	mode = "battle"
	world.visible = false
	battle.visible = true
	wipe_t = 0.0
	var kind = npc.get("kind", "")
	Sfx.play_music("boss" if kind in ["warden", "champion"] else "battle")
	var res = await battle.run(team, npc)
	await fade(1.0, 0.25)
	battle.visible = false
	world.visible = true
	mode = "over"
	Sfx.play_music(D.MAPS[G.map]["music"])
	await fade(0.0, 0.25)
	return res

func _after_battle(res: String, npc: Dictionary) -> void:
	if res == "lose":
		await say("You have no partners left who can battle...")
		var lost = G.money / 2
		G.money -= lost
		await say("You hurried back to the Haven and dropped %d coins on the way." % lost)
		await fade(1.0, 0.3)
		G.heal_all()
		G.map = G.respawn[0]
		G.px = G.respawn[1]
		G.py = G.respawn[2]
		G.dir = "D"
		world.load_map(G.map)
		Sfx.play_music(D.MAPS[G.map]["music"])
		await fade(0.0, 0.3)
		return
	await check_evolutions()
	if res == "win" and not npc.is_empty():
		G.flags[npc["id"]] = true
		await say(npc["post"], npc["name"])
		G.money += int(npc["reward"])
		Sfx.play("coin")
		await say("You received %d coins for winning!" % int(npc["reward"]))
		if npc["kind"] == "warden":
			var names = ["", "Grove Sigil", "Deep Sigil", "Sky Sigil"]
			G.flags["sig%d" % int(npc["sigil"])] = true
			Sfx.play("level")
			burst(Vector2(240, 120), Color("ffe08a"), 40, 200, 40)
			await say("You received the %s! (%d/3 sigils)" % [names[int(npc["sigil"])], G.sigils()])
			G.save_game()
			toast("Progress saved")
		elif npc["kind"] == "champion":
			G.flags["champ"] = true
			G.save_game()
			await ending()

func check_evolutions() -> void:
	for m in G.party:
		var d = D.SP[m["sp"]]
		if d["evo"] > 0 and m["lv"] >= d["evl"] and m["hp"] > 0:
			await evolve(m)

func evolve(m: Dictionary) -> void:
	var old = m["sp"]
	var nw = D.SP[old]["evo"]
	await say("What? %s is glowing!" % D.SP[old]["name"])
	evo = {"old": old, "new": nw, "t": 0.0}
	var prev_mode = mode
	mode = "evolve"
	Sfx.play("evolve")
	for i in 30:
		evo["t"] = i / 30.0
		await wait(0.1)
	var hp_ratio = float(m["hp"]) / G.maxhp(m)
	m["sp"] = nw
	m["hp"] = maxi(1, int(G.maxhp(m) * hp_ratio))
	G.mark_caught(nw)
	evo["t"] = 1.0
	burst(Vector2(240, 140), Color("fff6c0"), 50, 220, 30)
	shake = 6.0
	Sfx.play("level")
	await say("%s evolved into %s!" % [D.SP[old]["name"], D.SP[nw]["name"]])
	evo = {}
	mode = prev_mode

func ending() -> void:
	Sfx.play_music("victory")
	mode = "end"
	end_t = 0.0
	if auto:
		mode = "over"
		return
	while mode == "end":
		await get_tree().process_frame

## A or tap while walking: talk to NPCs, read signs, enter doors.
func interact(kind: String, data) -> void:
	busy += 1
	if kind == "npc":
		await talk(data)
	elif kind == "sign":
		await say(data)
	elif kind == "door":
		if data == "haven":
			await menus.haven()
		elif data == "shop":
			await menus.shop()
		else:
			Sfx.play("door")
			await say(data)
	busy -= 1

func talk(npc: Dictionary) -> void:
	world.face_npc(npc)
	var k = npc["kind"]
	if k in ["trainer", "warden", "champion"]:
		if G.flags.get(npc["id"], false):
			await say(npc["post"], npc["name"])
		else:
			busy -= 1
			await trainer_battle(npc)
			busy += 1
		return
	if k == "gift":
		if G.flags.get(npc["id"], false):
			await say(npc["after"], npc["name"])
		else:
			for l in npc["lines"]:
				await say(l, npc["name"])
			G.add_item(npc["item"], npc["count"])
			G.flags[npc["id"]] = true
			Sfx.play("level")
			await say("You received %d %ss!" % [npc["count"], D.ITEMS[npc["item"]]["name"]])
		return
	if k == "gate":
		if G.flags.get("gate", false):
			await say(npc["after"], npc["name"])
		elif G.sigils() >= 3:
			await say(npc["after"], npc["name"])
			G.flags["gate"] = true
			world.refresh_npcs()
		else:
			await say(npc["lines"][0] + " You have %d." % G.sigils(), npc["name"])
		return
	for l in npc["lines"]:
		await say(l, npc["name"])

# ------------------------------------------------------------ drawing
func _draw_starter(ci: CanvasItem, r: Rect2, i: int, sel: bool) -> void:
	var sp = [1, 5, 9][i]
	if sel:
		ci.draw_rect(r.grow(-4), Color(1, 0.95, 0.75), true)
	Art.creature(ci, sp, r.position + Vector2(r.size.x / 2, 112), 1.15 if sel else 0.95, t, false, false)
	text(ci, D.SP[sp]["name"], r.position + Vector2(0, 134), 16, Color("2a2540"), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	text(ci, D.TYPES[D.SP[sp]["type"]], r.position + Vector2(0, 152), 13, D.tcol(D.SP[sp]["type"]).darkened(0.3), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)

func text(ci: CanvasItem, s: String, p: Vector2, size: int = 14, col: Color = Color("2a2540"), w: float = -1, al: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	ci.draw_string(font, p, s, al, w, size, col)

func outlined(ci: CanvasItem, s: String, p: Vector2, size: int, col: Color, oc: Color, w: float = -1, al: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	ci.draw_string_outline(font, p, s, al, w, size, 6, oc)
	ci.draw_string(font, p, s, al, w, size, col)

func panel(ci: CanvasItem, r: Rect2, dark: bool = false) -> void:
	(dark_sb if dark else panel_sb).draw(ci.get_canvas_item(), r)

func hp_bar(ci: CanvasItem, p: Vector2, w: float, frac: float) -> void:
	frac = clampf(frac, 0.0, 1.0)
	ci.draw_rect(Rect2(p, Vector2(w, 7)), Color("3a3550"))
	var col = Color("5ad06a") if frac > 0.5 else (Color("f0c040") if frac > 0.2 else Color("ee5a4a"))
	ci.draw_rect(Rect2(p + Vector2(1, 1), Vector2((w - 2) * frac, 5)), col)

func _draw_overlay() -> void:
	var ci = overlay
	if mode == "title" or mode == "starter":
		_draw_title(ci)
	elif mode == "evolve":
		_draw_evolve(ci)
	elif mode == "end":
		_draw_end(ci)
	if wipe_t > 0.0 and wipe_t < 1.0:
		for i in 8:
			var wdt = SW * clampf(wipe_t * 1.6 - i * 0.05, 0, 1)
			var x = 0.0 if i % 2 == 0 else SW - wdt
			ci.draw_rect(Rect2(x, i * SH / 8.0, wdt, SH / 8.0 + 1), Color("16121f"))
	for p in parts:
		var a = clampf(p["life"] * 2.0, 0, 1)
		ci.draw_rect(Rect2(p["p"] - Vector2.ONE * p["s"] / 2, Vector2.ONE * p["s"]), Color(p["col"].r, p["col"].g, p["col"].b, a))
	for w in ui:
		_draw_widget(ci, w)
	if toast_t > 0.0:
		var a2 = clampf(toast_t * 3.0, 0, 1)
		var tw = font.get_string_size(toast_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 28
		var tr = Rect2(SW / 2.0 - tw / 2, 8 - (1.0 - a2) * 20, tw, 26)
		panel(ci, tr, true)
		text(ci, toast_text, tr.position + Vector2(0, 18), 14, Color(1, 1, 1, a2), tw, HORIZONTAL_ALIGNMENT_CENTER)
	if fade_a > 0.0:
		ci.draw_rect(Rect2(-so, vs), Color(0.05, 0.04, 0.09, fade_a))
	_draw_frame(ci)

func _draw_widget(ci: CanvasItem, w: Dictionary) -> void:
	if w["type"] == "say":
		var r = Rect2(8, 236, SW - 16, 78)
		panel(ci, r)
		if w["speaker"] != "":
			var sw = font.get_string_size(w["speaker"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 18
			panel(ci, Rect2(18, 222, sw, 22), true)
			text(ci, w["speaker"], Vector2(27, 238), 13, Color("8fe3c3"))
		ci.draw_multiline_string(font, r.position + Vector2(14, 26), w["text"].substr(0, int(w["shown"])), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 30, 15, 3, Color("2a2540"))
		if w["shown"] >= w["text"].length():
			var by = r.end.y - 14 + sin(t * 6.0) * 2.0
			Art.tri(ci, Vector2(r.end.x - 22, by - 4), Vector2(r.end.x - 12, by - 4), Vector2(r.end.x - 17, by + 2), Color("e8604c"))
		return
	var cfg: Dictionary = w["cfg"]
	if cfg.has("prompt"):
		var pr = Rect2(8, 236, SW - 16, 78)
		panel(ci, pr)
		ci.draw_multiline_string(font, pr.position + Vector2(14, 26), cfg["prompt"], HORIZONTAL_ALIGNMENT_LEFT, pr.size.x - 30 - cfg.get("prompt_pad", 0), 15, 3, Color("2a2540"))
	if cfg.has("under"):
		cfg["under"].call(ci, w["sel"])
	var opts: Array = w["opts"]
	var cols: int = cfg.get("cols", 1)
	var rh: float = cfg.get("row_h", 22)
	var r: Rect2 = cfg.get("rect", Rect2(SW - 170, 10, 160, 20 + opts.size() * rh))
	if not cfg.get("no_panel", false):
		panel(ci, r, cfg.get("dark", false))
	var y0 = r.position.y + 10
	if cfg.has("title"):
		text(ci, cfg["title"], Vector2(r.position.x + 12, y0 + 14), 15, Color("e8604c"))
		y0 += 22
	var cw = (r.size.x - 16) / cols
	var vis_rows = maxi(1, int((r.end.y - y0 - 6) / rh))
	var row = w["sel"] / cols
	if row < w["scroll"]:
		w["scroll"] = row
	if row >= w["scroll"] + vis_rows:
		w["scroll"] = row - vis_rows + 1
	var hits = []
	for i in opts.size():
		var rr = i / cols - w["scroll"]
		if rr < 0 or rr >= vis_rows:
			continue
		var cell = Rect2(r.position.x + 8 + (i % cols) * cw, y0 + rr * rh, cw, rh)
		hits.append([cell, i])
		var sel = i == w["sel"]
		if cfg.has("draw_row"):
			cfg["draw_row"].call(ci, cell, i, sel)
		else:
			if sel:
				ci.draw_rect(Rect2(cell.position + Vector2(0, 1), cell.size - Vector2(0, 2)), Color(1, 0.86, 0.6, 0.6))
			var col = Color("2a2540") if not cfg.get("dark", false) else Color.WHITE
			if cfg.has("dim") and cfg["dim"].call(i):
				col = Color(0.55, 0.55, 0.6)
			text(ci, str(opts[i]), cell.position + Vector2(18, rh * 0.5 + 5), 14, col, cell.size.x - 20)
		if sel and not cfg.has("draw_row"):
			Art.tri(ci, cell.position + Vector2(5, rh * 0.5 - 5), cell.position + Vector2(13, rh * 0.5), cell.position + Vector2(5, rh * 0.5 + 5), Color("e8604c"))
	if w["scroll"] > 0:
		Art.tri(ci, Vector2(r.end.x - 20, r.position.y + 12), Vector2(r.end.x - 12, r.position.y + 12), Vector2(r.end.x - 16, r.position.y + 6), Color("e8604c"))
	if (w["scroll"] + vis_rows) * cols < opts.size():
		Art.tri(ci, Vector2(r.end.x - 20, r.end.y - 12), Vector2(r.end.x - 12, r.end.y - 12), Vector2(r.end.x - 16, r.end.y - 6), Color("e8604c"))
	w["hit"] = hits
	if cfg.has("info"):
		cfg["info"].call(ci, w["sel"])

func _draw_title(ci: CanvasItem) -> void:
	var sky = Color("8fd3f0")
	ci.draw_rect(Rect2(-so, vs), sky)
	for i in 6:
		ci.draw_rect(Rect2(-so.x, i * 22, vs.x, 22), sky.lerp(Color("fbe6b0"), i / 7.0))
	for i in 5:
		var cx = fmod(i * 130.0 + t * (8 + i * 3), SW + 160) - 80
		Art.ell(ci, Vector2(cx, 30 + i * 13), Vector2(34, 9), Color(1, 1, 1, 0.75))
	for layer in 3:
		var pts = PackedVector2Array()
		var base = 200 + layer * 30
		var col = [Color("6cc08a"), Color("4ea86a"), Color("3a8a52")][layer]
		pts.append(Vector2(-so.x, vs.y))
		for x in range(-int(so.x), int(SW + so.x) + 20, 20):
			pts.append(Vector2(x, base + sin(x * 0.012 * (layer + 1) + layer + t * 0.1 * layer) * 18))
		pts.append(Vector2(SW + so.x + 20, vs.y))
		ci.draw_colored_polygon(pts, col)
	if mode == "title":
		for i in 6:
			var sp = [1, 5, 9, 19, 23, 13][i]
			var x = fmod(i * 90.0 + t * 30.0, SW + 120) - 60
			Art.creature(ci, sp, Vector2(x, 300 + sin(t * 4 + i) * 3), 0.6, t + i, false, false)
		var ly = 70 + sin(t * 1.5) * 4
		outlined(ci, "POCKET", Vector2(0, ly), 44, Color("fff6dc"), Color("2a2540"), SW, HORIZONTAL_ALIGNMENT_CENTER)
		outlined(ci, "WILDS", Vector2(0, ly + 50), 58, Color("ffd24a"), Color("2a2540"), SW, HORIZONTAL_ALIGNMENT_CENTER)
		Art.charm(ci, Vector2(118, ly - 14), 13, t, Color("e8a040"))
		Art.charm(ci, Vector2(362, ly - 14), 13, -t, Color("3aa8a0"))
		outlined(ci, "a creature-bonding adventure", Vector2(0, ly + 76), 14, Color.WHITE, Color("2a2540"), SW, HORIZONTAL_ALIGNMENT_CENTER)
		text(ci, "Made by Jaineil Rana (JaKing) - JaiGod", Vector2(0, SH - 4), 11, Color(0.15, 0.2, 0.15, 0.8), SW, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		Art.person(ci, Vector2(400, 150), "L", 0, Color("e8e0d0"), Color("6a8fbf"), t, true)

func _draw_evolve(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(-so, vs), Color("1c1530"))
	var e = evo
	var k: float = e["t"]
	for i in 16:
		var a = i * TAU / 16 + t * 0.6
		ci.draw_line(Vector2(240, 140), Vector2(240, 140) + Vector2(cos(a), sin(a)) * 400, Color(1, 0.9, 0.6, 0.05 + 0.08 * k), 10)
	var show_new = k >= 1.0 or sin(t * (4.0 + k * 30.0)) > 0
	var sp = e["new"] if show_new else e["old"]
	Art.creature(ci, sp, Vector2(240, 200), 1.6, t, k < 1.0, false, 0.0 if k >= 1.0 else k * 0.5)

func _draw_end(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(-so, vs), Color("120e24"))
	for i in 60:
		var sx = fmod(i * 97.0, SW)
		var sy = fmod(i * 53.0 + i * i, SH)
		ci.draw_rect(Rect2(sx, sy, 2, 2), Color(1, 1, 1, 0.4 + 0.4 * sin(t * 2 + i)))
	outlined(ci, "CHAMPION OF THE WILDS", Vector2(0, 50), 26, Color("ffd24a"), Color("2a2540"), SW, HORIZONTAL_ALIGNMENT_CENTER)
	var n = G.party.size()
	for i in n:
		var x = SW / 2.0 + (i - (n - 1) / 2.0) * 72
		Art.creature(ci, G.party[i]["sp"], Vector2(x, 150 + sin(t * 3 + i) * 4), 0.7, t + i)
	var cc = G.codex_count()
	var lines = ["You defeated Champion Aurex and the Wilds celebrate!", "Codex: %d seen, %d bonded of 24.  Play time %s" % [cc[0], cc[1], G.time_str()],
		"", "POCKET WILDS", "Design, code, art & music: Jaineil Rana (JaKing)", "Built in Godot 4 - every pixel and note made in code", "part of JaiGod"]
	var y = 200.0 - minf(end_t * 8.0, 40.0)
	for l in lines:
		text(ci, l, Vector2(0, y), 14, Color.WHITE, SW, HORIZONTAL_ALIGNMENT_CENTER)
		y += 18
	if end_t > 3.0:
		text(ci, "Press A to keep exploring - try to complete the Codex!", Vector2(0, SH - 10), 12, Color("8fe3c3", 0.6 + 0.4 * sin(t * 4)), SW, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_frame(ci: CanvasItem) -> void:
	var o = -so
	if portrait:
		var body = Color("2c6e74")
		ci.draw_rect(Rect2(o, Vector2(vs.x, so.y)), body)
		ci.draw_rect(Rect2(o + Vector2(0, so.y + SH), Vector2(vs.x, vs.y - so.y - SH)), body)
		if so.x > 0:
			ci.draw_rect(Rect2(o + Vector2(0, so.y), Vector2(so.x, SH)), body)
			ci.draw_rect(Rect2(Vector2(SW, 0), Vector2(so.x + 1, SH)), body)
		ci.draw_rect(Rect2(-4, -4, SW + 8, SH + 8), Color("1b3f44"), false, 4)
		outlined(ci, "POCKET WILDS", Vector2(14, -14), 18, Color("ffd24a"), Color("16343a"))
		Art.charm(ci, Vector2(156, -20), 7, t, Color("e8a040"))
		var sigs = G.sigils()
		for i in 3:
			ci.draw_circle(Vector2(SW / 2.0 + 40 + i * 18, -20), 6, Color("ffd24a") if i < sigs else Color("1b3f44"))
		for i in 6:
			ci.draw_line(Vector2(SW - 140 + i * 9, vs.y - so.y - 26), Vector2(SW - 150 + i * 9, vs.y - so.y - 12), Color("1b3f44"), 3)
	if not pad_visible():
		return
	var a = 1.0 if portrait else 0.55
	var dp: Vector2 = pad["dpad"][0] - so
	var r: float = pad["dpad"][1]
	if portrait:
		ci.draw_circle(dp, r + 8, Color("235a60"))
	else:
		ci.draw_circle(dp, r, Color(0, 0, 0, 0.18))
	var arm = r * 0.36
	ci.draw_rect(Rect2(dp - Vector2(arm, r * 0.95), Vector2(arm * 2, r * 1.9)), Color(0.13, 0.13, 0.18, a))
	ci.draw_rect(Rect2(dp - Vector2(r * 0.95, arm), Vector2(r * 1.9, arm * 2)), Color(0.13, 0.13, 0.18, a))
	for d in [["up", Vector2(0, -1)], ["down", Vector2(0, 1)], ["left", Vector2(-1, 0)], ["right", Vector2(1, 0)]]:
		var v: Vector2 = d[1]
		var tip = dp + v * r * 0.82
		var col = Color(1, 1, 1, 0.9 * a) if is_held(d[0]) else Color(0.5, 0.5, 0.6, a)
		Art.tri(ci, tip, tip - v * 12 + v.orthogonal() * 8, tip - v * 12 - v.orthogonal() * 8, col)
	for k in [["a", Color("f2c94c"), "A"], ["b", Color("eb5757"), "B"]]:
		var p: Vector2 = pad[k[0]][0] - so
		var rr: float = pad[k[0]][1]
		var cc: Color = k[1]
		if is_held(k[0]):
			cc = cc.lightened(0.3)
		ci.draw_circle(p + Vector2(0, 3), rr, Color(0, 0, 0, 0.3 * a))
		ci.draw_circle(p, rr, Color(cc.r, cc.g, cc.b, a))
		text(ci, k[2], p + Vector2(-rr, rr * 0.35), int(rr * 0.9), Color(0.15, 0.1, 0.1, a), rr * 2, HORIZONTAL_ALIGNMENT_CENTER)
	var sp: Vector2 = pad["start"][0] - so
	var sr: float = pad["start"][1]
	ci.draw_rect(Rect2(sp - Vector2(sr * 1.6, sr * 0.55), Vector2(sr * 3.2, sr * 1.1)), Color(0.13, 0.13, 0.18, a))
	text(ci, "MENU", sp + Vector2(-sr * 1.6, 4), 11, Color(1, 1, 1, a), sr * 3.2, HORIZONTAL_ALIGNMENT_CENTER)
	var mp: Vector2 = pad["mute"][0] - so
	ci.draw_circle(mp, pad["mute"][1], Color(0.13, 0.13, 0.18, a * 0.8))
	ci.draw_rect(Rect2(mp + Vector2(-7, -3), Vector2(4, 6)), Color(1, 1, 1, a))
	Art.tri(ci, mp + Vector2(-4, -3), mp + Vector2(2, -8), mp + Vector2(2, 8), Color(1, 1, 1, a))
	Art.tri(ci, mp + Vector2(-4, 3), mp + Vector2(-4, -3), mp + Vector2(2, 8), Color(1, 1, 1, a))
	if G.sound_on:
		ci.draw_arc(mp + Vector2(3, 0), 6, -0.9, 0.9, 6, Color(1, 1, 1, a), 1.5)
	else:
		ci.draw_line(mp + Vector2(-9, -9), mp + Vector2(9, 9), Color("eb5757"), 2)
