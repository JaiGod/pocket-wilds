extends RefCounted
## Pocket Wilds - pause menu, team, summary, bag, codex, shop, haven and storage screens.

const Art = preload("res://scripts/Art.gd")
const INK = Color("2a2540")

var main

func pause() -> void:
	main.busy += 1
	Sfx.play("select")
	var sel = 0
	while true:
		var opts = ["Team", "Bag", "Codex", "Save", "Sound: " + ("On" if G.sound_on else "Off"), "How to Play", "Quit to Title", "Close"]
		var i = await main.menu(opts, {"rect": Rect2(326, 10, 146, 22 + opts.size() * 24), "row_h": 24, "info": _pause_info, "sel": sel})
		sel = maxi(0, i)
		if i < 0 or i == 7:
			break
		elif i == 0:
			await team()
		elif i == 1:
			await bag()
		elif i == 2:
			await codex()
		elif i == 3:
			if G.save_game():
				Sfx.play("coin")
				main.toast("Journey saved!")
			else:
				main.toast("Could not save.")
		elif i == 4:
			G.set_sound(not G.sound_on)
		elif i == 5:
			await main.how_to()
		elif i == 6:
			if await main.confirm("Return to the title screen? Unsaved progress will be lost."):
				main.busy = 0
				main.title_flow()
				return
	main.busy -= 1

func _pause_info(ci: CanvasItem, _sel: int) -> void:
	var r = Rect2(8, 10, 196, 112)
	main.panel(ci, r, true)
	var cc = G.codex_count()
	main.text(ci, D.MAPS[G.map]["name"], r.position + Vector2(12, 22), 15, Color("ffd24a"))
	main.text(ci, "Coins  %d" % G.money, r.position + Vector2(12, 44), 13, Color.WHITE)
	main.text(ci, "Codex  %d seen / %d bonded" % [cc[0], cc[1]], r.position + Vector2(12, 64), 13, Color.WHITE)
	main.text(ci, "Time  %s" % G.time_str(), r.position + Vector2(12, 84), 13, Color.WHITE)
	main.text(ci, "Sigils", r.position + Vector2(12, 104), 13, Color.WHITE)
	for i in 3:
		Art.charm(ci, r.position + Vector2(70 + i * 20, 100), 7, 0, Color("ffd24a") if G.flags.get("sig%d" % (i + 1), false) else Color(0.35, 0.35, 0.45))

# ------------------------------------------------------------ team
func _mon_row(ci: CanvasItem, r: Rect2, i: int, sel: bool, list: Array) -> void:
	var m = list[i]
	var fainted = m["hp"] <= 0
	ci.draw_rect(Rect2(r.position + Vector2(0, 2), r.size - Vector2(0, 4)), Color(1, 0.86, 0.6, 0.7) if sel else Color(0, 0, 0, 0.04))
	if sel:
		ci.draw_rect(Rect2(r.position + Vector2(0, 2), r.size - Vector2(0, 4)), Color("e8604c"), false, 2)
	Art.creature(ci, m["sp"], r.position + Vector2(26, r.size.y - 5), 0.36, main.t if sel else 0.0, false, false, 0.0, 0.45 if fainted else 1.0)
	main.text(ci, G.mname(m), r.position + Vector2(54, 16), 14, INK if not fainted else Color(0.5, 0.5, 0.55))
	main.text(ci, "Lv%d  %s" % [m["lv"], D.TYPES[G.mtype(m)]], r.position + Vector2(54, 31), 11, D.tcol(G.mtype(m)).darkened(0.35))
	var bx = r.position.x + r.size.x - 150
	main.hp_bar(ci, Vector2(bx, r.position.y + 10), 110, float(m["hp"]) / G.maxhp(m))
	main.text(ci, "FAINTED" if fainted else "%d/%d" % [m["hp"], G.maxhp(m)], Vector2(bx, r.position.y + 31), 11, Color("e8604c") if fainted else INK, 140, HORIZONTAL_ALIGNMENT_LEFT)
	if i == 0 and list == G.party:
		main.text(ci, "LEAD", Vector2(bx + 112, r.position.y + 17), 9, Color("3aa8a0"))

func party_pick(prompt: String, cancel: bool = true) -> int:
	var names = []
	for m in G.party:
		names.append(G.mname(m))
	return await main.menu(names, {"rect": Rect2(8, 8, 464, 226), "row_h": 35, "draw_row": _mon_row.bind(G.party), "prompt": prompt, "cancel": cancel})

func team() -> void:
	var sel = 0
	while true:
		var names = []
		for m in G.party:
			names.append(G.mname(m))
		var i = await main.menu(names, {"rect": Rect2(8, 8, 464, 226), "row_h": 35, "draw_row": _mon_row.bind(G.party), "prompt": "Your team (%d/6). Storage holds %d more." % [G.party.size(), G.box.size()], "sel": sel})
		if i < 0:
			return
		sel = i
		var k = await main.menu(["Summary", "Make Lead", "Cancel"], {"rect": Rect2(330, 150, 142, 82), "row_h": 22})
		if k == 0:
			await summary(G.party[i])
		elif k == 1 and i > 0:
			var tmp = G.party[0]
			G.party[0] = G.party[i]
			G.party[i] = tmp
			Sfx.play("buff")
			main.toast("%s now leads the team!" % G.mname(G.party[0]))
			sel = 0

func summary(m: Dictionary) -> void:
	await main.menu(["Back"], {"rect": Rect2(380, 272, 92, 40), "row_h": 22, "under": _summary.bind(m)})

func _summary(ci: CanvasItem, _sel: int, m: Dictionary) -> void:
	var r = Rect2(8, 8, 464, 304)
	main.panel(ci, r)
	var d = D.SP[m["sp"]]
	var tc = D.tcol(d["type"])
	ci.draw_rect(Rect2(20, 20, 170, 170), tc.lightened(0.6))
	Art.ell(ci, Vector2(105, 168), Vector2(60, 12), tc.lightened(0.3))
	Art.creature(ci, m["sp"], Vector2(105, 168), 1.15, main.t)
	main.text(ci, "No.%02d  %s" % [m["sp"], d["name"]], Vector2(204, 38), 18, INK)
	main.text(ci, "%s element   Lv %d" % [D.TYPES[d["type"]], m["lv"]], Vector2(204, 58), 13, tc.darkened(0.35))
	var labels = ["HP", "Attack", "Defense", "Speed"]
	for k in 4:
		var v = G.stat(m, k)
		main.text(ci, labels[k], Vector2(204, 84 + k * 18), 12, INK)
		ci.draw_rect(Rect2(266, 76 + k * 18, 130, 8), Color("e6dccb"))
		ci.draw_rect(Rect2(266, 76 + k * 18, minf(130, v * 1.1), 8), tc)
		main.text(ci, str(v) if k > 0 else "%d/%d" % [m["hp"], v], Vector2(402, 84 + k * 18), 12, INK)
	var need = G.xp_for(m["lv"] + 1) - m["xp"]
	main.text(ci, "XP %d   next level in %d" % [m["xp"], maxi(0, need)], Vector2(204, 162), 12, INK)
	if d["evo"] > 0:
		main.text(ci, "Evolves at Lv %d" % d["evl"], Vector2(204, 180), 12, Color("3aa8a0"))
	for i in m["moves"].size():
		var mv = D.MV[m["moves"][i]]
		var p = Vector2(20 + (i % 2) * 176, 202 + (i / 2) * 30)
		ci.draw_rect(Rect2(p, Vector2(168, 26)), D.tcol(mv[0]).lightened(0.7))
		ci.draw_rect(Rect2(p, Vector2(5, 26)), D.tcol(mv[0]))
		main.text(ci, m["moves"][i], p + Vector2(10, 17), 13, INK)
		main.text(ci, str(mv[1]) if mv[1] > 0 else "-", p + Vector2(0, 17), 11, INK, 162, HORIZONTAL_ALIGNMENT_RIGHT)
	ci.draw_multiline_string(main.font, Vector2(20, 276), d["desc"], HORIZONTAL_ALIGNMENT_LEFT, 350, 12, 2, Color("5a5470"))

# ------------------------------------------------------------ items
func bag_ids() -> Array:
	var out = []
	for id in D.SHOP:
		if int(G.bag.get(id, 0)) > 0:
			out.append(id)
	return out

func _bag_row(ci: CanvasItem, r: Rect2, i: int, sel: bool, ids: Array) -> void:
	var id = ids[i]
	if sel:
		ci.draw_rect(Rect2(r.position + Vector2(0, 1), r.size - Vector2(0, 2)), Color(1, 0.86, 0.6, 0.7))
	_item_icon(ci, id, r.position + Vector2(16, r.size.y / 2))
	main.text(ci, D.ITEMS[id]["name"], r.position + Vector2(34, r.size.y / 2 + 5), 14, INK)
	main.text(ci, "x%d" % int(G.bag.get(id, 0)), r.position + Vector2(0, r.size.y / 2 + 5), 13, INK, r.size.x - 10, HORIZONTAL_ALIGNMENT_RIGHT)

func _item_icon(ci: CanvasItem, id: String, p: Vector2) -> void:
	var it = D.ITEMS[id]
	if it["kind"] == "charm":
		Art.charm(ci, p, 9, main.t * 0.5, {"charm": Color("e8a040"), "kin": Color("3aa8a0"), "soul": Color("9a6ae8")}[id])
	elif it["kind"] == "heal":
		ci.draw_rect(Rect2(p + Vector2(-5, -9), Vector2(10, 4)), Color("a8784a"))
		ci.draw_circle(p + Vector2(0, 2), 8, Color("e05a8a") if id == "tonic" else Color("5a8ae0"))
		ci.draw_circle(p + Vector2(-3, -1), 2.5, Color(1, 1, 1, 0.7))
	else:
		Art.leaf(ci, p + Vector2(0, 8), p + Vector2(0, -9), 6, Color("6ad08a"))

func _item_info(ci: CanvasItem, sel: int, ids: Array, r: Rect2) -> void:
	main.panel(ci, r, true)
	if sel < 0 or sel >= ids.size():
		return
	var it = D.ITEMS[ids[sel]]
	main.text(ci, it["name"], r.position + Vector2(12, 22), 14, Color("ffd24a"))
	ci.draw_multiline_string(main.font, r.position + Vector2(12, 42), it["desc"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24, 12, 5, Color.WHITE)

func bag_pick() -> String:
	var ids = bag_ids()
	if ids.is_empty():
		await main.say("Your bag is empty. Visit a Trading Post!")
		return ""
	var names = []
	for id in ids:
		names.append(D.ITEMS[id]["name"])
	var i = await main.menu(names, {"rect": Rect2(8, 8, 284, 226), "row_h": 30, "title": "Bag  -  %d coins" % G.money, "draw_row": _bag_row.bind(ids), "info": _item_info.bind(ids, Rect2(300, 8, 172, 226))})
	return "" if i < 0 else ids[i]

func item_ok(id: String, m: Dictionary) -> bool:
	var it = D.ITEMS[id]
	if it["kind"] == "heal":
		return m["hp"] > 0 and m["hp"] < G.maxhp(m)
	if it["kind"] == "revive":
		return m["hp"] <= 0
	return false

func apply_item(id: String, m: Dictionary) -> String:
	var it = D.ITEMS[id]
	if it["kind"] == "heal":
		var before = m["hp"]
		m["hp"] = mini(G.maxhp(m), m["hp"] + int(it["val"]))
		return "%s recovered %d HP!" % [G.mname(m), m["hp"] - before]
	m["hp"] = maxi(1, int(G.maxhp(m) * it["val"]))
	return "%s is back on its feet!" % G.mname(m)

func bag() -> void:
	while true:
		var id = await bag_pick()
		if id == "":
			return
		var it = D.ITEMS[id]
		if it["kind"] == "charm":
			await main.say("Bonding Charms are tossed at wild creatures during battle.")
			continue
		var tg = await party_pick("Use the %s on which partner?" % it["name"])
		if tg < 0:
			continue
		if not item_ok(id, G.party[tg]):
			await main.say("It won't have any effect.")
			continue
		G.use_item(id)
		Sfx.play("heal")
		await main.say(apply_item(id, G.party[tg]))

# ------------------------------------------------------------ codex
func codex() -> void:
	var names = []
	for i in range(1, 25):
		names.append(D.SP[i]["name"])
	var sel = 0
	while true:
		var cc = G.codex_count()
		var i = await main.menu(names, {"cols": 6, "rect": Rect2(8, 8, 284, 304), "row_h": 66, "title": "Codex   %d seen  %d bonded" % [cc[0], cc[1]], "draw_row": _codex_cell, "info": _codex_info, "sel": sel})
		if i < 0:
			return
		sel = i
		Sfx.play("level" if G.caught[i + 1] else "back")

func _codex_cell(ci: CanvasItem, r: Rect2, i: int, sel: bool) -> void:
	var sp = i + 1
	ci.draw_rect(Rect2(r.position + Vector2(1, 1), r.size - Vector2(2, 2)), Color(1, 0.86, 0.6, 0.8) if sel else Color(0, 0, 0, 0.05))
	if sel:
		ci.draw_rect(Rect2(r.position + Vector2(1, 1), r.size - Vector2(2, 2)), Color("e8604c"), false, 2)
	if G.seen[sp] or G.caught[sp]:
		Art.creature(ci, sp, r.position + Vector2(r.size.x / 2, r.size.y - 12), 0.4, main.t if sel else 0.0, not G.caught[sp])
	else:
		main.text(ci, "?", r.position + Vector2(0, r.size.y / 2 + 6), 18, Color(0.6, 0.6, 0.68), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	main.text(ci, "%02d" % sp, r.position + Vector2(4, 12), 9, Color(0.4, 0.38, 0.5))
	if G.caught[sp]:
		Art.charm(ci, r.position + Vector2(r.size.x - 8, 9), 4, 0, Color("e8a040"))

func _codex_info(ci: CanvasItem, sel: int) -> void:
	var sp = sel + 1
	var d = D.SP[sp]
	var r = Rect2(300, 8, 172, 304)
	main.panel(ci, r)
	var known = G.caught[sp]
	var tc = D.tcol(d["type"]) if known else Color(0.75, 0.74, 0.8)
	ci.draw_rect(Rect2(312, 20, 148, 130), tc.lightened(0.55))
	Art.creature(ci, sp, Vector2(386, 138), 1.0, main.t, not known)
	main.text(ci, "No.%02d" % sp, Vector2(312, 170), 12, Color(0.4, 0.38, 0.5))
	main.text(ci, d["name"] if G.seen[sp] or known else "???", Vector2(312, 190), 17, INK)
	if known:
		main.text(ci, D.TYPES[d["type"]] + " element", Vector2(312, 208), 12, tc.darkened(0.35))
		ci.draw_multiline_string(main.font, Vector2(312, 228), d["desc"], HORIZONTAL_ALIGNMENT_LEFT, 150, 12, 6, Color("5a5470"))
	elif G.seen[sp]:
		ci.draw_multiline_string(main.font, Vector2(312, 212), "Seen in the wild, but not bonded yet. Bond with it to reveal its colors and notes.", HORIZONTAL_ALIGNMENT_LEFT, 150, 12, 6, Color("5a5470"))
	else:
		ci.draw_multiline_string(main.font, Vector2(312, 212), "Not yet discovered. Keep exploring the Wilds!", HORIZONTAL_ALIGNMENT_LEFT, 150, 12, 6, Color("5a5470"))

# ------------------------------------------------------------ shop
func _shop_row(ci: CanvasItem, r: Rect2, i: int, sel: bool) -> void:
	var id = D.SHOP[i]
	if sel:
		ci.draw_rect(Rect2(r.position + Vector2(0, 1), r.size - Vector2(0, 2)), Color(1, 0.86, 0.6, 0.7))
	_item_icon(ci, id, r.position + Vector2(16, r.size.y / 2))
	main.text(ci, D.ITEMS[id]["name"], r.position + Vector2(34, r.size.y / 2 + 5), 14, INK)
	var price = D.ITEMS[id]["price"]
	main.text(ci, "%d" % price, r.position + Vector2(0, r.size.y / 2 + 5), 13, INK if G.money >= price else Color("c04a3a"), r.size.x - 10, HORIZONTAL_ALIGNMENT_RIGHT)

func _shop_info(ci: CanvasItem, sel: int) -> void:
	var r = Rect2(300, 8, 172, 226)
	_item_info(ci, sel, D.SHOP, r)
	main.text(ci, "Coins: %d" % G.money, r.position + Vector2(12, r.size.y - 30), 13, Color("ffd24a"))
	main.text(ci, "In bag: %d" % int(G.bag.get(D.SHOP[sel], 0)), r.position + Vector2(12, r.size.y - 12), 12, Color.WHITE)

func shop() -> void:
	Sfx.play("door")
	await main.say("Welcome to the Trading Post! Charms, tonics, seeds - take a look.", "Shopkeeper")
	var names = []
	for id in D.SHOP:
		names.append(D.ITEMS[id]["name"])
	var sel = 0
	while true:
		var i = await main.menu(names, {"rect": Rect2(8, 8, 284, 226), "row_h": 30, "title": "Trading Post", "draw_row": _shop_row, "info": _shop_info, "sel": sel, "prompt": "Press A to buy one. B to leave."})
		if i < 0:
			break
		sel = i
		var id = D.SHOP[i]
		var price = int(D.ITEMS[id]["price"])
		if G.money < price:
			Sfx.play("back")
			main.toast("Not enough coins!")
			continue
		G.money -= price
		G.add_item(id)
		Sfx.play("coin")
		main.toast("Bought a %s!" % D.ITEMS[id]["name"])
	await main.say("Come again! Safe travels.", "Shopkeeper")

# ------------------------------------------------------------ haven
func haven() -> void:
	Sfx.play("door")
	G.respawn = [G.map, G.px, G.py]
	await main.say("Welcome to the Haven! Rest here and your partners will be good as new.", "Haven Keeper")
	while true:
		var i = await main.menu(["Heal team", "Storage", "Save", "Leave"], {"rect": Rect2(340, 120, 132, 108), "row_h": 22, "prompt": "How can I help?"})
		if i == 0:
			await main.fade(0.75, 0.25)
			G.heal_all()
			Sfx.play("heal")
			await main.wait(1.0)
			await main.fade(0.0, 0.25)
			main.burst(Vector2(240, 150), Color("8fe3a0"), 30, 140, -40)
			await main.say("Your team is fully rested! Your journey was saved.", "Haven Keeper")
			G.save_game()
		elif i == 1:
			await storage()
		elif i == 2:
			G.save_game()
			Sfx.play("coin")
			main.toast("Journey saved!")
		else:
			break
	await main.say("Take care out there!", "Haven Keeper")

func storage() -> void:
	while true:
		var i = await main.menu(["Deposit", "Withdraw", "Back"], {"rect": Rect2(340, 120, 132, 86), "row_h": 22, "prompt": "Storage: %d partners resting here." % G.box.size()})
		if i == 0:
			if G.party.size() <= 1:
				await main.say("You can't deposit your last partner!")
				continue
			var k = await party_pick("Deposit which partner?")
			if k >= 0:
				var m = G.party.pop_at(k)
				G.heal_all()
				m["hp"] = G.maxhp(m)
				G.box.append(m)
				main.toast("%s went to Storage." % G.mname(m))
		elif i == 1:
			if G.box.is_empty():
				await main.say("Storage is empty. Bond with more creatures!")
				continue
			if G.party.size() >= 6:
				await main.say("Your team is full. Deposit someone first.")
				continue
			var names = []
			for m in G.box:
				names.append(G.mname(m))
			var k = await main.menu(names, {"rect": Rect2(8, 8, 464, 226), "row_h": 35, "draw_row": _mon_row.bind(G.box), "prompt": "Withdraw which partner?"})
			if k >= 0:
				var m = G.box.pop_at(k)
				G.party.append(m)
				main.toast("%s joined your team!" % G.mname(m))
		else:
			return
