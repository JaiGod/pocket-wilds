extends Node
## Pocket Wilds - player progress, creature math and saving. Autoloaded as "G".

const SAVE_PATH = "user://pocketwilds.save"
const SAVE_VERSION = 1

var party: Array = []
var box: Array = []
var bag: Dictionary = {}
var money: int = 0
var flags: Dictionary = {}
var seen: Array = []
var caught: Array = []
var map: String = "mossgate"
var px: int = 10
var py: int = 8
var dir: String = "D"
var respawn: Array = ["mossgate", 16, 5]
var playtime: float = 0.0
var sound_on: bool = true
var steps: int = 0

func _ready() -> void:
	reset()
	_load_settings()

func _process(delta: float) -> void:
	playtime += delta

func reset() -> void:
	party = []
	box = []
	bag = {"charm": 5, "tonic": 3}
	money = 500
	flags = {}
	seen = []
	caught = []
	for i in 25:
		seen.append(false)
		caught.append(false)
	map = "mossgate"
	px = 10
	py = 8
	dir = "D"
	respawn = ["mossgate", 16, 5]
	playtime = 0.0
	steps = 0

# ------------------------------------------------------------ creatures
func new_mon(sp: int, lv: int) -> Dictionary:
	var m = {"sp": sp, "lv": lv, "xp": xp_for(lv), "hp": 0, "moves": moves_at(sp, lv)}
	m["hp"] = maxhp(m)
	return m

func moves_at(sp: int, lv: int) -> Array:
	var out = []
	for e in D.LEARN[D.SP[sp]["type"]]:
		if e[0] <= lv and not out.has(e[1]):
			out.append(e[1])
	while out.size() > 4:
		out.pop_front()
	return out

func learned_at(sp: int, lv: int) -> Array:
	var out = []
	for e in D.LEARN[D.SP[sp]["type"]]:
		if e[0] == lv:
			out.append(e[1])
	return out

func xp_for(lv: int) -> int:
	return int(0.6 * lv * lv * lv)

func stat(m: Dictionary, k: int) -> int:
	var b: float = D.SP[m["sp"]]["base"][k]
	var lv: int = m["lv"]
	if k == 0:
		return int(b * 2.0 * lv / 100.0) + lv + 10
	return int(b * 2.0 * lv / 100.0) + 5

func maxhp(m: Dictionary) -> int:
	return stat(m, 0)

func mname(m: Dictionary) -> String:
	return D.SP[m["sp"]]["name"]

func mtype(m: Dictionary) -> int:
	return D.SP[m["sp"]]["type"]

func xp_yield(m: Dictionary, trainer: bool) -> int:
	var b = D.SP[m["sp"]]["base"]
	var s = b[0] + b[1] + b[2] + b[3]
	return int(s * m["lv"] / 12.0 * (1.5 if trainer else 1.0))

func alive_count() -> int:
	var n = 0
	for m in party:
		if m["hp"] > 0:
			n += 1
	return n

func first_alive() -> int:
	for i in party.size():
		if party[i]["hp"] > 0:
			return i
	return -1

func heal_all() -> void:
	for m in party:
		m["hp"] = maxhp(m)

func sigils() -> int:
	var n = 0
	for k in ["sig1", "sig2", "sig3"]:
		if flags.get(k, false):
			n += 1
	return n

func codex_count() -> Array:
	var s = 0
	var c = 0
	for i in range(1, 25):
		if seen[i]:
			s += 1
		if caught[i]:
			c += 1
	return [s, c]

func mark_caught(sp: int) -> void:
	seen[sp] = true
	caught[sp] = true

func add_mon(m: Dictionary) -> String:
	mark_caught(m["sp"])
	if party.size() < 6:
		party.append(m)
		return "party"
	box.append(m)
	return "box"

func add_item(id: String, n: int = 1) -> void:
	bag[id] = int(bag.get(id, 0)) + n

func use_item(id: String) -> bool:
	if int(bag.get(id, 0)) <= 0:
		return false
	bag[id] = int(bag[id]) - 1
	if bag[id] <= 0:
		bag.erase(id)
	return true

func time_str() -> String:
	var t = int(playtime)
	return "%d:%02d" % [t / 3600, (t / 60) % 60]

# ------------------------------------------------------------ saving
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> bool:
	var d = {"v": SAVE_VERSION, "party": party, "box": box, "bag": bag, "money": money, "flags": flags,
		"seen": seen, "caught": caught, "map": map, "px": px, "py": py, "dir": dir,
		"respawn": respawn, "playtime": playtime, "steps": steps}
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d))
	f.close()
	return true

func load_game() -> bool:
	if not has_save():
		return false
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) != TYPE_DICTIONARY or not d.has("party"):
		return false
	reset()
	party = _fix_list(d["party"])
	box = _fix_list(d.get("box", []))
	bag = {}
	for k in d.get("bag", {}):
		bag[k] = int(d["bag"][k])
	money = int(d.get("money", 0))
	flags = d.get("flags", {})
	var s = d.get("seen", [])
	var c = d.get("caught", [])
	for i in 25:
		seen[i] = bool(s[i]) if i < s.size() else false
		caught[i] = bool(c[i]) if i < c.size() else false
	map = str(d.get("map", "mossgate"))
	if not D.MAPS.has(map):
		map = "mossgate"
	px = int(d.get("px", 10))
	py = int(d.get("py", 8))
	dir = str(d.get("dir", "D"))
	var r = d.get("respawn", ["mossgate", 16, 5])
	respawn = [str(r[0]), int(r[1]), int(r[2])]
	playtime = float(d.get("playtime", 0))
	steps = int(d.get("steps", 0))
	return party.size() > 0

func _fix_list(a) -> Array:
	var out = []
	for m in a:
		var sp = int(m["sp"])
		if sp < 1 or sp > 24:
			continue
		var mv = []
		for x in m.get("moves", []):
			if D.MV.has(str(x)):
				mv.append(str(x))
		var fixed = {"sp": sp, "lv": int(m["lv"]), "xp": int(m["xp"]), "hp": int(m["hp"]), "moves": mv}
		if mv.is_empty():
			fixed["moves"] = moves_at(sp, fixed["lv"])
		out.append(fixed)
	return out

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)

func _load_settings() -> void:
	var f = FileAccess.open("user://pocketwilds.cfg", FileAccess.READ)
	if f:
		sound_on = f.get_as_text().strip_edges() != "mute"
		f.close()
	AudioServer.set_bus_mute(0, not sound_on)

func set_sound(on: bool) -> void:
	sound_on = on
	AudioServer.set_bus_mute(0, not on)
	var f = FileAccess.open("user://pocketwilds.cfg", FileAccess.WRITE)
	if f:
		f.store_string("on" if on else "mute")
		f.close()
