extends Node
## Headless smoke test: data integrity, battles, bonding, evolution, menus and save/load.
## Run: godot --headless --path . res://tests/Smoke.tscn   (prints SMOKE OK)

var fails = 0
var main

func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", what)

func _ready() -> void:
	_data()
	main = load("res://scenes/Main.tscn").instantiate()
	main.auto = true
	add_child(main)
	await get_tree().process_frame
	await _flows()
	print("SMOKE OK" if fails == 0 else "SMOKE FAILED (%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)

func _data() -> void:
	check(D.SP.size() == 25, "24 species")
	var names = {}
	for i in range(1, 25):
		var s = D.SP[i]
		check(not names.has(s["name"]), "unique name " + s["name"])
		names[s["name"]] = true
		check(s["evo"] == 0 or (s["evo"] > i and s["evo"] <= 24), "evo ref " + s["name"])
	var per = [0, 0, 0, 0, 0, 0]
	for i in range(1, 25):
		per[D.SP[i]["type"]] += 1
	check(per == [4, 4, 4, 4, 4, 4], "4 per element")
	for l in D.LEARN:
		for e in l:
			check(D.MV.has(e[1]), "move exists " + e[1])
	var ok_species = {}
	for k in D.MAPS:
		var m = D.MAPS[k]
		var rows = m["rows"]
		for r in rows:
			check(r.length() == rows[0].length(), "row width " + k)
		for c in m["warps"]:
			var w = m["warps"][c]
			check(D.MAPS.has(w[0]), "warp target " + k)
			var tr = D.MAPS[w[0]]["rows"]
			var tc = tr[w[2]][w[1]]
			check(not D.SOLID.contains(tc) and not (tc >= "0" and tc <= "9"), "warp arrival walkable %s->%s (%s)" % [k, w[0], tc])
		for n in m["npcs"]:
			check(not D.SOLID.contains(rows[n["y"]][n["x"]]), "npc on walkable " + n["id"])
			if n.has("team"):
				for e in n["team"]:
					check(e[0] >= 1 and e[0] <= 24, "team species " + n["id"])
		for key in m["doors"]:
			var p = key.split(",")
			check("ASD".contains(rows[int(p[1])][int(p[0])]), "door tile " + k + " " + key)
		for key in m["signs"]:
			var p = key.split(",")
			check(rows[int(p[1])][int(p[0])] == "O", "sign tile " + k + " " + key)
		for e in m["enc"]:
			ok_species[e[0]] = true
	for i in range(1, 25):
		if D.SP[i]["evo"] > 0:
			check(ok_species.has(i) or i in [1, 5, 9], "base form catchable " + D.SP[i]["name"])
	check(D.eff(3, 0) == 2.0 and D.eff(0, 3) == 0.5 and D.eff(4, 5) == 2.0 and D.eff(0, 4) == 0.5, "type chart")

func _flows() -> void:
	G.delete_save()
	G.reset()
	await main.new_game()
	check(G.party.size() == 1 and G.party[0]["sp"] == 1, "starter chosen")
	check(G.has_save(), "saved after new game")
	# render every map
	for k in D.MAPS:
		main.world.load_map(k)
		main.world.queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
	main.world.load_map("mossgate")
	G.party[0]["lv"] = 30
	G.party[0]["moves"] = G.moves_at(1, 30)
	G.heal_all()
	# wild battle (auto picks Fight -> move 0 until someone faints)
	await main.wild_battle(19, 3)
	check(main.mode == "over", "back to overworld after wild battle")
	check(G.seen[19], "seen wild")
	# bonding
	main.force_catch = true
	main.auto_choices = [1, 0]
	G.bag["charm"] = 3
	await main.wild_battle(3, 4)
	main.force_catch = false
	check(G.caught[3] and G.party.size() == 2, "caught Budling")
	# trainer battle + reward
	var money = G.money
	var npc = D.MAPS["route1"]["npcs"][0]
	await main.trainer_battle(npc)
	check(G.flags.get("r1_pip", false) and G.money > money, "trainer defeated & paid")
	# warden sigil
	await main.trainer_battle(D.MAPS["route2"]["npcs"][2])
	check(G.sigils() == 1, "warden sigil")
	# evolution
	G.party[1]["lv"] = 18
	await main.check_evolutions()
	check(G.party[1]["sp"] == 4 and G.caught[4], "Budling evolved")
	# lose path
	G.party = [G.new_mon(23, 2)]
	await main.wild_battle(16, 40)
	check(G.party[0]["hp"] == G.maxhp(G.party[0]) and G.map == G.respawn[0], "blackout respawn")
	# level up + move learning
	var m = G.new_mon(9, 7)
	m["xp"] = G.xp_for(8) - 1
	G.party = [m]
	main.battle.foe = G.new_mon(3, 2)
	main.battle.npc = {}
	main.battle.participants = [0]
	main.battle.me = 0
	await main.battle.give_xp()
	check(m["lv"] >= 8 and m["moves"].has("Ember Spit"), "level up learns move")
	# save / load roundtrip
	G.box.append(G.new_mon(13, 6))
	check(G.save_game(), "save")
	var caught = G.caught.duplicate()
	G.reset()
	check(G.load_game(), "load")
	check(G.caught == caught and G.box.size() == 1 and typeof(G.party[0]["lv"]) == TYPE_INT, "load roundtrip")
	# items
	G.party[0]["hp"] = 1
	check(main.menus.item_ok("tonic", G.party[0]), "tonic usable")
	main.menus.apply_item("tonic", G.party[0])
	check(G.party[0]["hp"] > 1, "tonic heals")
	# draw battle + menus once (no crash)
	main.mode = "battle"
	main.battle.visible = true
	main.battle.foe = G.new_mon(24, 30)
	main.battle.intro = 1.0
	main.battle.vis = [true, true]
	main.battle.queue_redraw()
	await get_tree().process_frame
	main.auto = false
	main.menu(["a"], {"draw_row": main.menus._mon_row.bind(G.party), "info": main.menus._codex_info})
	main.say("Testing the dialog box.")
	await get_tree().process_frame
	await get_tree().process_frame
	main.ui.clear()
	main.mode = "end"
	await get_tree().process_frame
	main.mode = "title"
	await get_tree().process_frame
	main.mode = "evolve"
	main.evo = {"old": 1, "new": 2, "t": 0.5}
	await get_tree().process_frame
	main.auto = true
	main.mode = "over"
	G.delete_save()
