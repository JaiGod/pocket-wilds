extends Node2D
## Pocket Wilds - turn-based battles: damage, elements, stat stages, AI, bonding charms, XP and moves.

const Art = preload("res://scripts/Art.gd")
const FOE_P = Vector2(356, 150)
const ME_P = Vector2(124, 232)
const CHARM_COL = {"charm": Color("e8a040"), "kin": Color("3aa8a0"), "soul": Color("9a6ae8")}

var main
var team: Array = []
var foe: Dictionary = {}
var npc: Dictionary = {}
var me: int = 0
var st: Array = [[0, 0, 0], [0, 0, 0]]
var dhp: Array = [0.0, 0.0]
var dxp: float = 0.0
var off: Array = [Vector2.ZERO, Vector2.ZERO]
var flash: Array = [0.0, 0.0]
var vis: Array = [false, false]
var sk: Array = [1.0, 1.0]
var charm: Dictionary = {}
var t: float = 0.0
var bg: String = "grass"
var participants: Array = []
var run_tries: int = 0
var intro: float = 1.0

func wild() -> bool:
	return npc.is_empty()

func mine() -> Dictionary:
	return G.party[me]

func msg(s: String) -> void:
	await main.say(s, "", true)

func anim(dur: float, f: Callable) -> void:
	if main.auto:
		f.call(1.0)
		return
	var k = 0.0
	while k < 1.0:
		await get_tree().process_frame
		k = minf(1.0, k + get_process_delta_time() / dur)
		f.call(k)

func run(tm: Array, n: Dictionary) -> String:
	team = tm
	npc = n
	foe = team[0]
	me = maxi(0, G.first_alive())
	st = [[0, 0, 0], [0, 0, 0]]
	run_tries = 0
	charm = {}
	var mk = D.MAPS[G.map]["kind"]
	bg = "cave" if mk == "cave" else ("spire" if G.map == "route4" and G.py <= 6 else ("town" if mk == "town" else "grass"))
	vis = [false, true]
	sk = [1.0, 1.0]
	flash = [0.0, 0.0]
	dhp = [float(mine()["hp"]), float(foe["hp"])]
	G.seen[foe["sp"]] = true
	participants = [me]
	intro = 0.0
	await anim(0.55, func(k): intro = k)
	if wild():
		await main.say("A wild %s appeared!" % G.mname(foe))
	else:
		await main.say("%s wants to battle!" % npc["name"])
		await msg("%s sent out %s!" % [npc["name"], G.mname(foe)])
	await send_me(me, false)
	while true:
		var act = await choose()
		var res = await turn(act)
		if res != "":
			await main.wait(0.3)
			return res
	return ""

# ------------------------------------------------------------ choosing
func choose() -> Dictionary:
	while true:
		var m = mine()
		var i = await main.menu(["Fight", "Bag", "Team", "Run"], {"cols": 2, "rect": Rect2(282, 236, 190, 78), "cancel": false, "row_h": 30,
			"prompt": "What will %s do?" % G.mname(m), "prompt_pad": 190})
		if i == 0:
			var mi = await main.menu(m["moves"], {"cols": 2, "rect": Rect2(8, 236, 316, 78), "row_h": 30, "info": _move_info, "draw_row": _move_row})
			if mi >= 0:
				return {"k": "move", "i": mi}
		elif i == 1:
			var id = await main.menus.bag_pick()
			if id == "":
				continue
			var it = D.ITEMS[id]
			if it["kind"] == "charm":
				if not wild():
					await main.say("You can't bond with another trainer's partner!")
					continue
				return {"k": "charm", "id": id}
			var tg = await main.menus.party_pick("Use the %s on which partner?" % it["name"])
			if tg < 0:
				continue
			if not main.menus.item_ok(id, G.party[tg]):
				await main.say("It won't have any effect.")
				continue
			return {"k": "item", "id": id, "tg": tg}
		elif i == 2:
			var s = await main.menus.party_pick("Switch to which partner?")
			if s < 0 or s == me:
				continue
			if G.party[s]["hp"] <= 0:
				await main.say("%s has fainted and can't battle!" % G.mname(G.party[s]))
				continue
			return {"k": "switch", "i": s}
		else:
			return {"k": "run"}
	return {}

# ------------------------------------------------------------ turns
func turn(act: Dictionary) -> String:
	var k = act["k"]
	if k == "run":
		if not wild():
			await main.say("There's no running from a trainer battle!")
			return ""
		run_tries += 1
		var chance = 0.45 + 0.3 * spd(0) / maxf(1.0, spd(1)) + run_tries * 0.15
		if randf() < chance or main.auto:
			Sfx.play("door")
			await main.say("You got away safely!")
			return "run"
		await msg("Couldn't get away!")
		return _r(await use_move(1, pick_foe_move()))
	if k == "switch":
		await send_me(act["i"], true)
		return _r(await use_move(1, pick_foe_move()))
	if k == "item":
		G.use_item(act["id"])
		var m = G.party[act["tg"]]
		var line = main.menus.apply_item(act["id"], m)
		Sfx.play("heal")
		if act["tg"] == me:
			main.burst(ME_P + Vector2(0, -50), Color("8fe3a0"), 16, 80, -60)
		await msg(line)
		return _r(await use_move(1, pick_foe_move()))
	if k == "charm":
		if await throw_charm(act["id"]):
			return "caught"
		return _r(await use_move(1, pick_foe_move()))
	var mv: String = mine()["moves"][act["i"]]
	var fm = pick_foe_move()
	var first = 0
	var pm = D.MV[mv][3] == "first"
	var pf = D.MV[fm][3] == "first"
	if pf and not pm:
		first = 1
	elif pm == pf:
		var a = spd(0)
		var b = spd(1)
		if b > a or (b == a and randf() < 0.5):
			first = 1
	var order = [[0, mv], [1, fm]] if first == 0 else [[1, fm], [0, mv]]
	for o in order:
		var r = await use_move(o[0], o[1])
		if r != "":
			return _r(r)
	return ""

func _r(r: String) -> String:
	return "" if r == "skip" else r

func smult(s: int) -> float:
	return (2.0 + s) / 2.0 if s >= 0 else 2.0 / (2.0 - s)

func spd(side: int) -> float:
	var m = mine() if side == 0 else foe
	return G.stat(m, 3) * smult(st[side][2])

func pick_foe_move() -> String:
	var best = foe["moves"][0]
	var bs = -1.0
	var mt = G.mtype(mine())
	for mn in foe["moves"]:
		var mv = D.MV[mn]
		var sc = 0.0
		if mv[1] > 0:
			sc = mv[1] * D.eff(mv[0], mt) * (1.25 if mv[0] == G.mtype(foe) else 1.0) * mv[2] / 100.0
		else:
			match mv[3]:
				"heal": sc = 70.0 if foe["hp"] < G.maxhp(foe) * 0.45 else 0.0
				"atk+": sc = 32.0 if st[1][0] < 2 else 2.0
				"def+": sc = 28.0 if st[1][1] < 2 else 2.0
				"spd+": sc = 26.0 if st[1][2] < 2 else 2.0
				"atk-": sc = 26.0 if st[0][0] > -2 else 2.0
				"def-": sc = 26.0 if st[0][1] > -2 else 2.0
		sc *= randf_range(0.6, 1.3)
		if sc > bs:
			bs = sc
			best = mn
	return best

func use_move(side: int, mn: String) -> String:
	var att = mine() if side == 0 else foe
	var dfn = foe if side == 0 else mine()
	if att["hp"] <= 0 or dfn["hp"] <= 0:
		return ""
	var mv = D.MV[mn]
	var who = G.mname(att) if side == 0 else ("Wild " if wild() else "Foe ") + G.mname(att)
	await msg("%s used %s!" % [who, mn])
	var dir = 1.0 if side == 0 else -1.0
	await anim(0.24, func(k): off[side] = Vector2(dir * sin(k * PI) * 26, -sin(k * PI) * 10))
	off[side] = Vector2.ZERO
	var other = 1 - side
	if randf() * 100.0 > mv[2]:
		Sfx.play("back")
		await msg("But it missed!")
		return ""
	var tp = FOE_P if other == 1 else ME_P
	if mv[1] > 0:
		var a = G.stat(att, 1) * smult(st[side][0])
		var d = G.stat(dfn, 2) * smult(st[other][1])
		var e = D.eff(mv[0], G.mtype(dfn))
		var crit = randf() < 0.0625
		var base = ((2.0 * att["lv"] / 5.0 + 2.0) * mv[1] * a / d) / 50.0 + 2.0
		var dmg = maxi(1, int(base * (1.25 if mv[0] == G.mtype(att) else 1.0) * e * (1.5 if crit else 1.0) * randf_range(0.85, 1.0)))
		dfn["hp"] = maxi(0, dfn["hp"] - dmg)
		flash[other] = 1.0
		main.shake = 7.0 if e > 1.0 or crit else 3.5
		main.burst(tp + Vector2(0, -36), D.tcol(mv[0]), 22 if e > 1.0 else 12, 150)
		Sfx.play("super" if e > 1.0 else ("weak" if e < 1.0 else "hit"))
		await main.wait(0.55)
		if crit:
			await msg("A critical hit!")
		if e > 1.0:
			await msg("It's super effective!")
		elif e < 1.0:
			await msg("It's not very effective...")
		if mv[3] == "drain" and att["hp"] > 0:
			att["hp"] = mini(G.maxhp(att), att["hp"] + maxi(1, dmg / 2))
			await msg("%s drained some energy!" % G.mname(att))
	else:
		var fx: String = mv[3]
		if fx == "heal":
			att["hp"] = mini(G.maxhp(att), att["hp"] + G.maxhp(att) / 2)
			Sfx.play("heal")
			main.burst((ME_P if side == 0 else FOE_P) + Vector2(0, -40), Color("8fe3a0"), 16, 80, -60)
			await msg("%s glowed softly and recovered HP!" % G.mname(att))
		else:
			var tgt_side = side if fx.ends_with("+") else other
			var idx = {"atk": 0, "def": 1, "spd": 2}[fx.substr(0, 3)]
			var delta = 1 if fx.ends_with("+") else -1
			var stat_name = ["Attack", "Defense", "Speed"][idx]
			var tm = mine() if tgt_side == 0 else foe
			if absi(st[tgt_side][idx] + delta) > 4:
				await msg("%s's %s won't go any %s!" % [G.mname(tm), stat_name, "higher" if delta > 0 else "lower"])
			else:
				st[tgt_side][idx] += delta
				Sfx.play("buff" if delta > 0 else "debuff")
				main.burst((ME_P if tgt_side == 0 else FOE_P) + Vector2(0, -40), Color("ffd24a") if delta > 0 else Color("8a9ad8"), 14, 70, -80 if delta > 0 else 120)
				await msg("%s's %s %s!" % [G.mname(tm), stat_name, "rose" if delta > 0 else "fell"])
	if dfn["hp"] <= 0:
		return await on_faint(other)
	return ""

func on_faint(side: int) -> String:
	Sfx.play("faint")
	await anim(0.45, func(k): sk[side] = 1.0 - k * 0.98; off[side] = Vector2(0, k * 20))
	vis[side] = false
	sk[side] = 1.0
	off[side] = Vector2.ZERO
	if side == 1:
		await msg("%s%s fainted!" % ["Wild " if wild() else "Foe ", G.mname(foe)])
		await give_xp()
		var nx = -1
		for i in team.size():
			if team[i]["hp"] > 0:
				nx = i
				break
		if nx < 0:
			if not wild():
				Sfx.play_music("victory")
			return "win"
		foe = team[nx]
		G.seen[foe["sp"]] = true
		st[1] = [0, 0, 0]
		dhp[1] = float(foe["hp"])
		participants = [me]
		vis[1] = true
		await anim(0.3, func(k): sk[1] = k)
		await msg("%s sent out %s!" % [npc["name"], G.mname(foe)])
		return "skip"
	await msg("%s fainted!" % G.mname(mine()))
	if G.alive_count() == 0:
		return "lose"
	var s = -1
	while s < 0 or G.party[s]["hp"] <= 0:
		if main.auto:
			s = G.first_alive()
			break
		s = await main.menus.party_pick("Choose your next partner!", false)
	await send_me(s, false)
	return "skip"

func send_me(i: int, recall: bool) -> void:
	if recall:
		await msg("Come back, %s!" % G.mname(mine()))
		await anim(0.2, func(k): sk[0] = 1.0 - k * 0.98)
		vis[0] = false
	me = i
	st[0] = [0, 0, 0]
	if not participants.has(i):
		participants.append(i)
	dhp[0] = float(mine()["hp"])
	dxp = _xp_frac(mine())
	vis[0] = true
	sk[0] = 0.02
	main.burst(ME_P + Vector2(0, -40), Color("fff6c0"), 18, 120, 40)
	Sfx.play("select")
	await anim(0.3, func(k): sk[0] = maxf(0.02, sin(k * PI * 0.5) * (1.0 + 0.15 * sin(k * PI))))
	sk[0] = 1.0
	await msg("Go, %s!" % G.mname(mine()))

func _xp_frac(m: Dictionary) -> float:
	var a = G.xp_for(m["lv"])
	var b = G.xp_for(m["lv"] + 1)
	return clampf(float(m["xp"] - a) / maxf(1.0, b - a), 0.0, 1.0)

func give_xp() -> void:
	var amt = G.xp_yield(foe, not wild())
	var shared = 0
	for i in G.party.size():
		var m = G.party[i]
		if m["hp"] <= 0 or m["lv"] >= 60:
			continue
		var gain = amt if participants.has(i) else int(amt * 0.4)
		m["xp"] += gain
		if i == me:
			await msg("%s gained %d XP!" % [G.mname(m), gain])
		else:
			shared = gain
		while m["lv"] < 60 and m["xp"] >= G.xp_for(m["lv"] + 1):
			var old_max = G.maxhp(m)
			m["lv"] += 1
			m["hp"] = mini(G.maxhp(m), m["hp"] + G.maxhp(m) - old_max)
			Sfx.play("level")
			if i == me:
				dxp = 0.0
				main.burst(ME_P + Vector2(0, -50), Color("ffd24a"), 20, 110, -40)
			await main.say("%s grew to level %d!" % [G.mname(m), m["lv"]])
			for mvn in G.learned_at(m["sp"], m["lv"]):
				await learn(m, mvn, i == me)
	if shared > 0:
		await msg("Your other partners gained %d XP too." % shared)

func learn(m: Dictionary, mvn: String, ask: bool) -> void:
	var mv: Array = m["moves"]
	if mv.has(mvn):
		return
	if mv.size() < 4:
		mv.append(mvn)
		Sfx.play("buff")
		await main.say("%s learned %s!" % [G.mname(m), mvn])
		return
	if not ask:
		var old = mv.pop_front()
		mv.append(mvn)
		await main.say("%s forgot %s and learned %s!" % [G.mname(m), old, mvn])
		return
	await main.say("%s wants to learn %s, but it already knows 4 moves." % [G.mname(m), mvn])
	var opts = mv.duplicate()
	opts.append("Keep old moves")
	var k = await main.menu(opts, {"title": "Forget which move?", "rect": Rect2(140, 30, 200, 160), "cancel": false})
	if k < 0 or k >= 4:
		await main.say("%s did not learn %s." % [G.mname(m), mvn])
		return
	var old2 = mv[k]
	mv[k] = mvn
	Sfx.play("buff")
	await main.say("1, 2 and... poof! %s forgot %s and learned %s!" % [G.mname(m), old2, mvn])

# ------------------------------------------------------------ bonding
func throw_charm(id: String) -> bool:
	G.use_item(id)
	var it = D.ITEMS[id]
	await msg("You tossed a %s!" % it["name"])
	Sfx.play("throw")
	var start = Vector2(60, 250)
	var land = FOE_P + Vector2(0, -40)
	charm = {"p": start, "rot": 0.0, "col": CHARM_COL.get(id, Color("e8a040"))}
	await anim(0.5, func(k): charm["p"] = start.lerp(land, k) + Vector2(0, -sin(k * PI) * 110); charm["rot"] = k * 12.0)
	flash[1] = 1.0
	main.burst(land, Color("fff6c0"), 24, 140, 0)
	await anim(0.3, func(k): sk[1] = maxf(0.02, 1.0 - k))
	vis[1] = false
	await anim(0.3, func(k): charm["p"] = land.lerp(FOE_P + Vector2(0, -10), k))
	var p = clampf(D.SP[foe["sp"]]["rate"] * it["val"] * (1.0 - 0.66 * foe["hp"] / float(G.maxhp(foe))), 0.04, 0.97)
	if main.force_catch:
		p = 1.0
	var shakes = 0
	for i in 3:
		await main.wait(0.45)
		if randf() < pow(p, 1.0 / 3.0):
			shakes += 1
			Sfx.play("shake")
			await anim(0.35, func(k): charm["rot"] = sin(k * TAU * 2) * 0.6)
		else:
			break
	if shakes == 3:
		await main.wait(0.3)
		Sfx.play("catch")
		main.burst(charm["p"], Color("ffd24a"), 34, 160, 60)
		await main.say("Gotcha! You bonded with %s!" % G.mname(foe))
		var first_time = not G.caught[foe["sp"]]
		await give_xp()
		var where = G.add_mon(foe)
		if first_time:
			await main.say("%s's data was added to the Codex!" % G.mname(foe))
		if where == "box":
			await main.say("Your team is full, so %s was sent to Storage." % G.mname(foe))
		charm = {}
		return true
	Sfx.play("breakout")
	charm = {}
	vis[1] = true
	main.burst(FOE_P + Vector2(0, -40), Color("fff6c0"), 18, 140, 0)
	await anim(0.25, func(k): sk[1] = k)
	await msg(["Oh no! It broke free right away!", "Argh! Almost had it!", "So close! It wriggled out!"][shakes])
	return false

# ------------------------------------------------------------ drawing
func _process(delta: float) -> void:
	t += delta
	if not visible:
		return
	for i in 2:
		flash[i] = maxf(0.0, flash[i] - delta * 3.0)
	if G.party.size() > me:
		var m = mine()
		dhp[0] = move_toward(dhp[0], m["hp"], G.maxhp(m) * delta * 1.1)
		dxp = move_toward(dxp, _xp_frac(m), delta * 0.9)
	if not foe.is_empty():
		dhp[1] = move_toward(dhp[1], foe["hp"], G.maxhp(foe) * delta * 1.1)
	queue_redraw()

func _draw() -> void:
	if foe.is_empty() or main == null:
		return
	var full = Rect2(-main.so, main.vs)
	_draw_bg(full)
	var slide = (1.0 - intro) * 320.0
	Art.ell(self, FOE_P + Vector2(-slide, 0), Vector2(80, 17), _plat())
	Art.ell(self, ME_P + Vector2(slide, 0), Vector2(94, 19), _plat())
	if vis[1]:
		Art.creature(self, foe["sp"], FOE_P + off[1] + Vector2(-slide, 0), 1.0 * sk[1], t, false, true, flash[1])
	if vis[0] and G.party.size() > me:
		Art.creature(self, mine()["sp"], ME_P + off[0] + Vector2(slide, 0), 1.3 * sk[0], t, false, false, flash[0])
	if not charm.is_empty():
		Art.charm(self, charm["p"], 10, charm["rot"], charm["col"])
	if intro >= 1.0:
		_draw_foe_box()
		if vis[0]:
			_draw_me_box()

func _plat() -> Color:
	match bg:
		"cave": return Color("4a3e5a")
		"spire": return Color("c8c0dc")
		"town": return Color("c8b07a")
	return Color("6aa858")

func _draw_bg(r: Rect2) -> void:
	var sky = [Color("9ad8f2"), Color("e6f6ff")]
	var ground = Color("8fcf72")
	match bg:
		"cave":
			sky = [Color("1a1426"), Color("3a2e4c")]
			ground = Color("2e2540")
		"spire":
			sky = [Color("5a3a8a"), Color("f6b07a")]
			ground = Color("a89ac8")
		"town":
			ground = Color("dcc58e")
	for i in 10:
		var y0 = r.position.y + (190 - r.position.y) * i / 10.0
		draw_rect(Rect2(r.position.x, y0, r.size.x, (190 - r.position.y) / 10.0 + 1), sky[0].lerp(sky[1], i / 9.0))
	draw_rect(Rect2(r.position.x, 150, r.size.x, r.end.y - 150), ground)
	draw_rect(Rect2(r.position.x, 150, r.size.x, 4), ground.lightened(0.15))
	if bg == "cave":
		for i in 9:
			var x = i * 60.0 - 10
			Art.tri(self, Vector2(x, r.position.y), Vector2(x + 14, 40 + (i * 37) % 50), Vector2(x + 28, r.position.y), Color("120e1c"))
		for i in 12:
			draw_circle(Vector2(fmod(i * 83.0, 480), 30 + (i * 41) % 100), 2, Color(0.6, 0.85, 1.0, 0.3 + 0.3 * sin(t * 2 + i)))
	elif bg == "spire":
		for i in 5:
			Art.ell(self, Vector2(fmod(i * 120.0 + t * 6, 600) - 60, 40 + i * 18), Vector2(40, 7), Color(1, 0.85, 0.8, 0.5))
	else:
		for i in 4:
			Art.ell(self, Vector2(fmod(i * 140.0 + t * 8, 620) - 70, 30 + i * 16), Vector2(36, 9), Color(1, 1, 1, 0.8))
		for i in 8:
			var x = i * 64.0 - 20
			draw_circle(Vector2(x, 146), 26, Color("5aa85a").darkened(0.1 * (i % 2)))
	for i in 14:
		var gx = fmod(i * 47.0, 480)
		var gy = 170 + (i * 29) % 60
		draw_line(Vector2(gx, gy), Vector2(gx + 3, gy - 6), ground.darkened(0.15), 2)

func _chip(p: Vector2, tp: int) -> void:
	var col = D.tcol(tp)
	draw_rect(Rect2(p, Vector2(52, 14)), col)
	main.text(self, D.TYPES[tp].to_upper() if tp >= 0 else "PLAIN", p + Vector2(0, 11), 9, Color(1, 1, 1) if tp != 5 and tp != 4 else Color("2a2540"), 52, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_foe_box() -> void:
	var r = Rect2(14, 14, 210, 56)
	main.panel(self, r)
	main.text(self, G.mname(foe), r.position + Vector2(12, 21), 15)
	main.text(self, "Lv%d" % foe["lv"], r.position + Vector2(0, 21), 13, Color("2a2540"), r.size.x - 12, HORIZONTAL_ALIGNMENT_RIGHT)
	_chip(r.position + Vector2(12, 28), G.mtype(foe))
	main.text(self, "HP", r.position + Vector2(72, 40), 10, Color("e8604c"))
	main.hp_bar(self, r.position + Vector2(90, 33), 108, dhp[1] / G.maxhp(foe))
	if wild() and G.caught[foe["sp"]]:
		Art.charm(self, r.position + Vector2(r.size.x - 14, 46), 6, 0, Color("e8a040"))
	elif not wild():
		for i in team.size():
			draw_circle(r.position + Vector2(96 + i * 12, 50), 4, Color("e8604c") if team[i]["hp"] > 0 else Color(0.6, 0.6, 0.65))

func _draw_me_box() -> void:
	var m = mine()
	var r = Rect2(262, 160, 210, 70)
	main.panel(self, r)
	main.text(self, G.mname(m), r.position + Vector2(12, 21), 15)
	main.text(self, "Lv%d" % m["lv"], r.position + Vector2(0, 21), 13, Color("2a2540"), r.size.x - 12, HORIZONTAL_ALIGNMENT_RIGHT)
	_chip(r.position + Vector2(12, 28), G.mtype(m))
	main.text(self, "HP", r.position + Vector2(72, 40), 10, Color("e8604c"))
	main.hp_bar(self, r.position + Vector2(90, 33), 108, dhp[0] / G.maxhp(m))
	main.text(self, "%d / %d" % [int(ceil(dhp[0])), G.maxhp(m)], r.position + Vector2(0, 56), 12, Color("2a2540"), r.size.x - 12, HORIZONTAL_ALIGNMENT_RIGHT)
	draw_rect(Rect2(r.position + Vector2(12, 61), Vector2(186, 4)), Color("d8d0c0"))
	draw_rect(Rect2(r.position + Vector2(12, 61), Vector2(186 * dxp, 4)), Color("4aa8e8"))

func _move_row(ci: CanvasItem, r: Rect2, i: int, sel: bool) -> void:
	var mn: String = mine()["moves"][i]
	var col = D.tcol(D.MV[mn][0])
	ci.draw_rect(Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 4)), col.lightened(0.55) if sel else col.lightened(0.78))
	ci.draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(5, r.size.y - 4)), col)
	main.text(ci, mn, r.position + Vector2(14, r.size.y / 2 + 5), 14, Color("2a2540"))
	if sel:
		ci.draw_rect(Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 4)), Color("e8604c"), false, 2)

func _move_info(ci: CanvasItem, sel: int) -> void:
	var r = Rect2(328, 236, 144, 78)
	main.panel(ci, r, true)
	var mv = D.MV[mine()["moves"][sel]]
	main.text(ci, (D.TYPES[mv[0]] if mv[0] >= 0 else "Plain"), r.position + Vector2(12, 22), 14, D.tcol(mv[0]).lightened(0.2))
	if mv[1] > 0:
		main.text(ci, "Power %d  Acc %d" % [mv[1], mv[2]], r.position + Vector2(12, 42), 12, Color.WHITE)
		var e = D.eff(mv[0], G.mtype(foe))
		var s = "Super effective!" if e > 1.0 else ("Not very effective" if e < 1.0 else "Normal damage")
		main.text(ci, s, r.position + Vector2(12, 62), 12, Color("ffd24a") if e > 1.0 else (Color("a0a0b8") if e < 1.0 else Color("8fe3c3")))
	else:
		var fxd = {"atk+": "Raises your Attack", "def+": "Raises your Defense", "spd+": "Raises your Speed", "atk-": "Lowers foe Attack", "def-": "Lowers foe Defense", "heal": "Restores half HP"}
		main.text(ci, fxd.get(mv[3], ""), r.position + Vector2(12, 42), 12, Color.WHITE)
		main.text(ci, "Status move", r.position + Vector2(12, 62), 12, Color("8fe3c3"))
