extends Node
## Pocket Wilds - all static game data: elements, creatures, moves, items, maps, trainers.
## Everything here is original. Autoloaded as "D".

const TYPES = ["Verdant", "Tide", "Terra", "Cinder", "Zephyr", "Lumen"]
const TYPE_COL = ["5cbf4e", "3f8fe0", "b58a52", "ee6a37", "63d4c4", "e8c53a"]
## STRONG[a] = elements that element a hits for double damage.
const STRONG = [[1, 2], [2, 3], [3, 4], [0, 5], [0, 5], [1, 4]]

static func eff(a: int, d: int) -> float:
	if a < 0 or d < 0:
		return 1.0
	if STRONG[a].has(d):
		return 2.0
	if STRONG[d].has(a) or a == d:
		return 0.5
	return 1.0

static func tcol(t: int) -> Color:
	if t < 0:
		return Color("b8b0a0")
	return Color(TYPE_COL[t])

## name: [element (-1 = plain), power, accuracy, effect]
const MV = {
	"Bump": [-1, 35, 95, ""], "Claw Swipe": [-1, 45, 95, ""], "Quick Dash": [-1, 40, 100, "first"],
	"Hype Up": [-1, 0, 100, "atk+"], "Brace": [-1, 0, 100, "def+"], "Snarl": [-1, 0, 95, "atk-"],
	"Leaf Flick": [0, 40, 100, ""], "Vine Lash": [0, 60, 95, ""], "Sap Drain": [0, 55, 100, "drain"],
	"Spore Puff": [0, 0, 90, "atk-"], "Thicket Crush": [0, 90, 85, ""],
	"Splash Jab": [1, 40, 100, ""], "Ripple Shot": [1, 60, 95, ""], "Mist Veil": [1, 0, 100, "def+"],
	"Tidal Crash": [1, 90, 85, ""],
	"Pebble Toss": [2, 40, 100, ""], "Quake Stomp": [2, 65, 95, ""], "Stone Skin": [2, 0, 100, "def+"],
	"Landslide": [2, 95, 80, ""],
	"Spark Nip": [3, 40, 100, ""], "Ember Spit": [3, 60, 95, ""], "Kindle": [3, 0, 100, "atk+"],
	"Blaze Rush": [3, 90, 85, ""],
	"Gust Peck": [4, 40, 100, ""], "Cyclone Slash": [4, 60, 95, ""], "Tailwind": [4, 0, 100, "spd+"],
	"Skystrike": [4, 90, 85, ""],
	"Glint": [5, 40, 100, ""], "Prism Beam": [5, 65, 95, ""], "Soothe Glow": [5, 0, 100, "heal"],
	"Dazzle": [5, 0, 90, "def-"], "Radiant Pulse": [5, 90, 85, ""],
}

## Learnsets by element: [level, move]. A creature knows the last 4 it has learned.
const LEARN = [
	[[1, "Bump"], [1, "Leaf Flick"], [4, "Hype Up"], [8, "Vine Lash"], [12, "Sap Drain"], [17, "Spore Puff"], [22, "Thicket Crush"]],
	[[1, "Bump"], [1, "Splash Jab"], [4, "Brace"], [8, "Ripple Shot"], [12, "Mist Veil"], [17, "Quick Dash"], [22, "Tidal Crash"]],
	[[1, "Bump"], [1, "Pebble Toss"], [4, "Brace"], [8, "Quake Stomp"], [12, "Stone Skin"], [17, "Claw Swipe"], [23, "Landslide"]],
	[[1, "Claw Swipe"], [1, "Spark Nip"], [4, "Snarl"], [8, "Ember Spit"], [12, "Kindle"], [17, "Quick Dash"], [22, "Blaze Rush"]],
	[[1, "Bump"], [1, "Gust Peck"], [4, "Snarl"], [8, "Cyclone Slash"], [12, "Tailwind"], [17, "Quick Dash"], [22, "Skystrike"]],
	[[1, "Bump"], [1, "Glint"], [4, "Hype Up"], [8, "Prism Beam"], [12, "Soothe Glow"], [17, "Dazzle"], [22, "Radiant Pulse"]],
]

const ITEMS = {
	"charm": {"name": "Bonding Charm", "price": 200, "kind": "charm", "val": 1.0, "desc": "A woven charm. Toss it at a weakened wild creature to bond with it."},
	"kin": {"name": "Kinship Charm", "price": 600, "kind": "charm", "val": 1.7, "desc": "A sturdier charm with a stronger pull. Better bonding odds."},
	"soul": {"name": "Soulbond Charm", "price": 1500, "kind": "charm", "val": 3.0, "desc": "A radiant charm. Even strong wild creatures find it hard to resist."},
	"tonic": {"name": "Berry Tonic", "price": 150, "kind": "heal", "val": 30, "desc": "Sweet berry juice. Restores 30 HP."},
	"elixir": {"name": "Grand Elixir", "price": 500, "kind": "heal", "val": 120, "desc": "A potent brew. Restores 120 HP."},
	"rally": {"name": "Rally Seed", "price": 800, "kind": "revive", "val": 0.5, "desc": "Revives a fainted creature with half its HP."},
}
const SHOP = ["charm", "kin", "soul", "tonic", "elixir", "rally"]

var SP = [null]

func _init() -> void:
	_s("Mosskit", 0, 2, 16, [46, 50, 48, 54], "quad", "6dbb4b", "f2e7b6", "3b8a2c", "ears,leaf,tleaf", 0.85, "A curious sprout-cub. The moss on its back grows thicker on rainy days.")
	_s("Thornmane", 0, 0, 0, [72, 80, 72, 76], "quad", "4f9a3a", "e9dca4", "c2457a", "ears,mane,spikes,tleaf", 1.15, "Its mane of bramble thorns bristles whenever it guards its forest den.")
	_s("Budling", 0, 4, 18, [50, 44, 52, 44], "blob", "9fd67c", "f6f0d0", "ef7fa8", "bud", 0.8, "It sways to the rhythm of the wind. Its bud only opens for true friends.")
	_s("Petalorn", 0, 0, 0, [80, 68, 84, 58], "blob", "6fb85a", "f6f0d0", "f08fb8", "crown,horn", 1.1, "A crown of petals hides the sturdy horn it uses to dig up sweet roots.")
	_s("Puddlefin", 1, 6, 16, [48, 50, 50, 50], "fish", "5aa7e6", "d8eef9", "2f6fb3", "feet,fin", 0.85, "This hopping fish waddles from puddle to puddle on stubby little feet.")
	_s("Torrentail", 1, 0, 0, [78, 80, 76, 72], "fish", "3a7fd0", "cfe6f7", "79d2f0", "crest,fin,long", 1.2, "Its long tail whips up currents strong enough to spin a mill wheel.")
	_s("Drizzlop", 1, 8, 18, [56, 42, 50, 46], "blob", "a8d8f0", "ffffff", "5aa7e6", "cloud,drop", 0.85, "A squishy cloud-blob. It rains tiny showers whenever it laughs.")
	_s("Mistraven", 1, 0, 0, [72, 74, 62, 92], "bird", "5b78a8", "c9d6ea", "2c3e66", "crest,stripes", 1.1, "It glides through fog banks, its dark feathers beaded with cold dew.")
	_s("Cinderpup", 3, 10, 16, [44, 56, 42, 58], "quad", "f07a3a", "ffe0b0", "ffcc33", "ears,tflame", 0.85, "Its tail flickers like a candle. It sneezes sparks when it gets excited.")
	_s("Blazehound", 3, 0, 0, [70, 90, 64, 82], "quad", "d4442c", "ffd29a", "ffb020", "ears,mane,tflame,horn", 1.2, "A loyal blazing hound whose mane roars brighter the harder it battles.")
	_s("Ashmite", 3, 12, 18, [40, 50, 40, 60], "moth", "8a7f78", "f0a040", "ff6a2a", "spots", 0.8, "It nests in warm ash and nibbles on charcoal crumbs for breakfast.")
	_s("Scorchmoth", 3, 0, 0, [64, 80, 58, 94], "moth", "e8742c", "ffd36a", "7a2a10", "spots,big", 1.15, "The eyespots on its glowing wings shimmer like embers at dusk.")
	_s("Pebbit", 2, 14, 17, [50, 52, 58, 40], "blob", "a99a86", "e8dcc6", "6e6252", "ears_long,spikes", 0.85, "It stores smooth pebbles in its cheeks and polishes them for fun.")
	_s("Bouldrake", 2, 0, 0, [82, 86, 94, 48], "quad", "8a6d4c", "cdb894", "5e4a35", "plates,horn", 1.2, "Rocky plates armor its back. It naps buried in hillsides for weeks.")
	_s("Cragling", 2, 16, 20, [52, 50, 66, 30], "golem", "9a9488", "c8c2b4", "7fd0e0", "", 0.85, "A little block of living stone. It stacks rocks to make new friends.")
	_s("Monolox", 2, 0, 0, [88, 84, 106, 38], "golem", "6e6a62", "aaa49a", "9be8ff", "crystal", 1.25, "Ancient crystals grow from its head and hum softly in the deep dark.")
	_s("Breezel", 4, 18, 17, [42, 50, 40, 66], "quad", "7fd8c8", "f2fff9", "3e9e90", "eround,stripes", 0.8, "This slippery critter rides gusts the way surfers ride waves.")
	_s("Galecrest", 4, 0, 0, [66, 78, 62, 100], "bird", "58c2b0", "f2fff9", "2f7f75", "crest,long", 1.15, "Its broad crest catches the wind so it can hover for hours.")
	_s("Puffwing", 4, 20, 18, [46, 44, 44, 56], "bird", "f4dc8a", "fff6d8", "f0a040", "fluff", 0.75, "A fluffy chick that is more fluff than bird. It bounces when it lands.")
	_s("Stormaw", 4, 0, 0, [72, 88, 64, 86], "bird", "7a6a9a", "d8d0ea", "f4dc4a", "crest,stripes,long", 1.2, "It dives from thunderheads with a cry that seems to split the sky.")
	_s("Dawnfawn", 5, 22, 20, [48, 46, 48, 58], "deer", "e6c27a", "fff3d6", "fff3d6", "spots", 0.9, "Its spots glow faintly at sunrise. Lost travelers follow it home.")
	_s("Solstag", 5, 0, 0, [82, 80, 76, 86], "deer", "f6f0e0", "ffe08a", "ffd24a", "antlers,glow", 1.25, "Its radiant antlers light up the whole forest on the longest nights.")
	_s("Wispip", 5, 24, 19, [42, 52, 42, 58], "wisp", "c8b6f6", "ffffff", "f4dc8a", "", 0.75, "A shy flicker of light that likes to hide inside lanterns and jars.")
	_s("Lumivane", 5, 0, 0, [72, 86, 66, 88], "wisp", "9a86e8", "f6f0ff", "ffe08a", "halo,wings", 1.15, "Its halo of light guides lost creatures safely out of the deep woods.")

func _s(n: String, t: int, evo: int, evl: int, base: Array, plan: String, c1: String, c2: String, c3: String, feat: String, size: float, desc: String) -> void:
	var is_final = evo == 0
	SP.append({"name": n, "type": t, "evo": evo, "evl": evl, "base": base, "plan": plan,
		"c1": Color(c1), "c2": Color(c2), "c3": Color(c3), "feat": feat.split(","), "size": size,
		"desc": desc, "rate": 0.42 if is_final else 0.9})

# ------------------------------------------------------------------ MAPS
# Legend: . grass  , tall grass  T tree  ~ water  = path  f flowers  # cliff
# W cave wall  _ cave floor  : cave floor (encounters)  + spire plaza
# R/r/q roofs  H wall  A haven door  S shop door  D house door  O sign  0-9 warps
const SOLID = "T~#WRrqHASDO"

const MAPS = {
	"mossgate": {"name": "Mossgate", "kind": "town", "music": "town", "rows": [
		"TTTTTTTTT00TTTTTTTTT",
		"T........==........T",
		"T.qqqq...==...RRRR.T",
		"T.qqqq...==...RRRR.T",
		"T.HDHH...==...HHAH.T",
		"T..=.....==.....=..T",
		"T..==============..T",
		"T........==........T",
		"T.ff.....==...rrr..T",
		"T.ff.....==...rrr..T",
		"T........==...HSH..T",
		"T........========..T",
		"T..~~~......O.....fT",
		"T..~~~............fT",
		"T.ff..........ff...T",
		"TTTTTTTTTTTTTTTTTTTT"],
		"warps": {"0": ["route1", 9, 20]},
		"doors": {"3,4": "Your family's cottage. A note on the door reads: 'Be brave out there, explorer!'", "16,4": "haven", "15,10": "shop"},
		"signs": {"12,12": "MOSSGATE - where every journey takes root. North: Fernway Path."},
		"enc": [],
		"npcs": [
			{"id": "oda", "x": 7, "y": 7, "dir": "R", "name": "Keeper Oda", "kind": "npc", "look": ["e8e0d0", "6a8fbf"], "lines": ["The Codex fills in every time you bond with a new creature. I want to see all 24!", "Three Wardens guard sigils across the Wilds. Earn all three, then challenge the Champion atop Crown Spire."]},
			{"id": "m_kid", "x": 12, "y": 13, "dir": "D", "name": "Kid", "kind": "npc", "look": ["ffcc33", "e0505a"], "lines": ["Wild creatures hide in tall grass! Weaken them first, then toss a Bonding Charm.", "Hold B (or X) while walking to jog faster!"]},
			{"id": "m_gard", "x": 5, "y": 8, "dir": "D", "name": "Gardener", "kind": "npc", "look": ["7a5a3a", "8bbf5a"], "lines": ["Elements matter! Verdant beats Tide and Terra. Tide beats Terra and Cinder.", "Terra beats Cinder and Zephyr. Cinder beats Verdant and Lumen. Zephyr beats Verdant and Lumen. Lumen beats Tide and Zephyr!"]},
		]},
	"route1": {"name": "Fernway Path", "kind": "route", "music": "route", "rows": [
		"TTTTTTTTT22TTTTTTTTT",
		"T,,,,....==....,,,,T",
		"T,,,,....==....,,,,T",
		"T,,TT....==...TT,,,T",
		"T........==........T",
		"T..,,,,..==..,,,,..T",
		"T..,,,,..==..,,,,..T",
		"TTT,,,,..==..,,,,TTT",
		"T........==........T",
		"T..O.....==........T",
		"T.TTTT...==...TTTT.T",
		"T,,,,,...==...,,,,,T",
		"T,,,,,...==...,,,,,T",
		"T,,,,,...==...,,,,,T",
		"T........==........T",
		"T..ff....==....ff..T",
		"T~~~~....==....~~~~T",
		"T~~~~....==....~~~~T",
		"T.,,,....==....,,,.T",
		"T.,,,....==....,,,.T",
		"T........==........T",
		"TTTTTTTTT11TTTTTTTTT"],
		"warps": {"1": ["mossgate", 9, 1], "2": ["route2", 10, 20]},
		"doors": {}, "signs": {"3,9": "FERNWAY PATH - North: Bramble Trail. South: Mossgate."},
		"enc": [[19, 2, 4, 30], [3, 2, 4, 30], [17, 3, 4, 25], [7, 3, 5, 15]],
		"npcs": [
			{"id": "r1_pip", "x": 11, "y": 8, "dir": "L", "name": "Scout Pip", "kind": "trainer", "sight": 3, "look": ["4a9a5a", "e8b040"], "team": [[19, 4], [3, 4]], "reward": 150, "pre": "Hey! Our eyes met, so we battle. That's the scout code!", "post": "Aw, you're good! Keep exploring!"},
			{"id": "r1_moe", "x": 8, "y": 13, "dir": "R", "name": "Angler Moe", "kind": "trainer", "sight": 3, "look": ["3a6a9a", "d0d0c0"], "team": [[7, 5]], "reward": 160, "pre": "No bites today... how about a battle instead?", "post": "That's one that got away!"},
		]},
	"route2": {"name": "Bramble Trail", "kind": "route", "music": "route", "rows": [
		"TTTTTTTTT#3#TTTTTTTT",
		"TTTTTTTT##=##TTTTTTT",
		"T.ff....#.=.#....ffT",
		"T.......f.=.f......T",
		"T...TT....=....TT..T",
		"T,,,,.....=.....,,,T",
		"T,,,,,....=....,,,,T",
		"T,,,,,,...=...,,,,,T",
		"T.........=........T",
		"T..TTT....====.....T",
		"T..,,,.......=.....T",
		"T..,,,.......=..O..T",
		"T..,,,.......=.....T",
		"TT..........==....TT",
		"T,,,,,,,....=,,,,,,T",
		"T,,,,,,,....=,,,,,,T",
		"T...........=......T",
		"T....~~~~...=......T",
		"T....~~~~...=..ff..T",
		"T.........===......T",
		"T.........=........T",
		"TTTTTTTTTT4TTTTTTTTT"],
		"warps": {"4": ["route1", 9, 1], "3": ["cave", 10, 14, "sig1", "Thorny brambles seal the cave mouth. Warden Bryn's sigil could part them."]},
		"doors": {}, "signs": {"16,11": "BRAMBLE TRAIL - Warden Bryn tends the grove beside Hollowdeep Cave."},
		"enc": [[3, 5, 8, 20], [13, 6, 8, 20], [11, 6, 8, 20], [17, 6, 8, 20], [23, 7, 9, 10], [19, 5, 7, 10]],
		"npcs": [
			{"id": "r2_gus", "x": 14, "y": 11, "dir": "L", "name": "Hiker Gus", "kind": "trainer", "sight": 2, "look": ["8a5a3a", "a0763a"], "team": [[13, 7], [15, 8]], "reward": 260, "pre": "These rocks and I go way back. Let's rumble!", "post": "Solid as a boulder, you are."},
			{"id": "r2_lia", "x": 8, "y": 15, "dir": "R", "name": "Scout Lia", "kind": "trainer", "sight": 4, "look": ["d05a8a", "5ab0d0"], "team": [[17, 8], [11, 8]], "reward": 260, "pre": "I've been training all week. Show me what you've got!", "post": "Back to training for me!"},
			{"id": "bryn", "x": 11, "y": 2, "dir": "L", "name": "Warden Bryn", "kind": "warden", "sigil": 1, "sight": 1, "look": ["3a8a3a", "2e6a2a"], "team": [[3, 9], [1, 10], [4, 12]], "reward": 900, "pre": "I am Bryn, Warden of the Grove. My Verdant partners grow stronger with every challenger. Let's see your roots!", "post": "Your bond runs deep. Take the Grove Sigil - the brambles of Hollowdeep will part for you."},
		]},
	"cave": {"name": "Hollowdeep Cave", "kind": "cave", "music": "cave", "rows": [
		"WWWWWWWWWWW5WWWWWWWW",
		"WWWWWWWWWW___WWWWWWW",
		"WW::::::::___WWWWWWW",
		"WW::::::::::::WWWWWW",
		"WW::WWWWWWWWWWWWWWWW",
		"WW::::::::::::::::WW",
		"WW::::_____:::::::WW",
		"WWWWWWWWWWWWWWWW::WW",
		"WW________________WW",
		"WW::::::::::______WW",
		"WW::WWWWWWWWWWWWWWWW",
		"WW::____::::::____WW",
		"WW________________WW",
		"WWWWWWWWWW__WWWWWWWW",
		"WWWWWWWWWW__WWWWWWWW",
		"WWWWWWWWWW6WWWWWWWWW"],
		"warps": {"6": ["route2", 10, 1], "5": ["route3", 9, 16, "sig2", "A heavy stone door blocks the way. It bears the mark of Warden Korr."]},
		"doors": {}, "signs": {},
		"enc": [[13, 10, 13, 25], [15, 11, 14, 25], [11, 11, 13, 20], [23, 12, 14, 15], [7, 11, 13, 15]],
		"npcs": [
			{"id": "c_dax", "x": 17, "y": 8, "dir": "L", "name": "Miner Dax", "kind": "trainer", "sight": 4, "look": ["e8c040", "6a6a7a"], "team": [[13, 12], [15, 13]], "reward": 420, "pre": "Watch your step down here... and watch my team!", "post": "Guess I'll go back to digging."},
			{"id": "c_ivy", "x": 17, "y": 5, "dir": "L", "name": "Spelunker Ivy", "kind": "trainer", "sight": 5, "look": ["5a3a8a", "9a7ad0"], "team": [[23, 13], [11, 13]], "reward": 420, "pre": "My lantern creatures light the way. Let's battle in the glow!", "post": "My lights flickered out..."},
			{"id": "korr", "x": 12, "y": 1, "dir": "L", "name": "Warden Korr", "kind": "warden", "sigil": 2, "sight": 1, "look": ["6a5a4a", "4a3a2a"], "team": [[15, 15], [13, 16], [14, 18]], "reward": 1600, "pre": "Stone remembers every footstep. I am Korr, Warden of the Deep. Can you move a mountain?", "post": "The mountain moves for you. Take the Deep Sigil - the stone door will open."},
		]},
	"route3": {"name": "Glimmer Ridge", "kind": "route", "music": "route", "rows": [
		"TTTTTTTTT88TTTTTTTTT",
		"T........==........T",
		"T.,,,,...==...,,,,.T",
		"T.,,,,...==...,,,,.T",
		"T........==........T",
		"TTTT..~~~==~~~..TTTT",
		"T,,,..~~~==~~~..,,,T",
		"T,,,.....==.....,,,T",
		"T,,,..f..==..f..,,,T",
		"T........==........T",
		"T..TTTT..==..TTTT..T",
		"T..,,,,,,==,,,,,,..T",
		"T..,,,,,,==,,,,,,..T",
		"T........==..O.....T",
		"T.ff.....==.....ff.T",
		"T##......==......##T",
		"T###.....==.....###T",
		"TTTTTTTTT77TTTTTTTTT"],
		"warps": {"7": ["cave", 11, 1], "8": ["town2", 9, 14]},
		"doors": {}, "signs": {"13,13": "GLIMMER RIDGE - Brightwater lies just to the north."},
		"enc": [[7, 13, 16, 20], [17, 14, 16, 15], [21, 14, 16, 20], [15, 14, 16, 15], [19, 14, 16, 15], [1, 15, 15, 5], [5, 15, 15, 5], [9, 15, 15, 5]],
		"npcs": [
			{"id": "r3_juno", "x": 8, "y": 7, "dir": "R", "name": "Ranger Juno", "kind": "trainer", "sight": 2, "look": ["3a7a5a", "c09a5a"], "team": [[23, 15], [17, 16]], "reward": 500, "pre": "Rangers protect the ridge. Prove you respect the Wilds!", "post": "You treat your partners well. Go on."},
			{"id": "r3_rook", "x": 11, "y": 12, "dir": "L", "name": "Ace Rook", "kind": "trainer", "sight": 2, "look": ["1a1a2a", "c03a3a"], "team": [[9, 16], [13, 16]], "reward": 520, "pre": "Ace trainers don't lose. Ready?", "post": "...Okay, I lost. Don't tell anyone."},
		]},
	"town2": {"name": "Brightwater", "kind": "town", "music": "town", "rows": [
		"TTTTTTTTT99TTTTTTTTT",
		"T~~......==......~~T",
		"T~.......==.......~T",
		"T..RRRR..==..rrr...T",
		"T..RRRR..==..rrr...T",
		"T..HHAH..==..HSH...T",
		"T........==........T",
		"T..==============..T",
		"T..=..f.......f.=..T",
		"T..=..qqqq......=..T",
		"T..=..qqqq...O..=..T",
		"T..=..HDHH......=..T",
		"T..=............=..T",
		"T..==============..T",
		"T........==........T",
		"TTTTTTTTT88TTTTTTTTT"],
		"warps": {"8": ["route3", 9, 1], "9": ["route4", 9, 21]},
		"doors": {"5,5": "haven", "14,5": "shop", "7,11": "A retired explorer lives here. 'The Champion's team covers many elements. Bring variety!'"},
		"signs": {"13,10": "BRIGHTWATER - the lakeside town. North: Skyreach Road and Crown Spire."},
		"enc": [],
		"npcs": [
			{"id": "lin", "x": 12, "y": 6, "dir": "D", "name": "Keeper Lin", "kind": "gift", "item": "kin", "count": 3, "look": ["f0e0c0", "9a6ad0"], "lines": ["Oda's student, are you? Take these Kinship Charms!"], "after": "Kinship Charms bond more easily. Use them on rare finds!"},
			{"id": "b_tip", "x": 11, "y": 9, "dir": "D", "name": "Sailor", "kind": "npc", "look": ["ffffff", "3a5ab0"], "lines": ["Warden Sela on Skyreach Road commands Zephyr creatures.", "Terra and Lumen moves hit Zephyr hard. Remember that!"]},
			{"id": "b_kid", "x": 17, "y": 10, "dir": "L", "name": "Kid", "kind": "npc", "look": ["3a2a1a", "f0a030"], "lines": ["When your party is full, new partners go to Storage. Visit any Haven to swap them!"]},
		]},
	"route4": {"name": "Skyreach Road", "kind": "route", "music": "route", "rows": [
		"TTTTTTTTTTTTTTTTTTTT",
		"TTT##############TTT",
		"TTT#++++++++++++#TTT",
		"TTT#++++++++++++#TTT",
		"TTT#++++++++++++#TTT",
		"TTT#######+######TTT",
		"TTTTTTTTTT=TTTTTTTTT",
		"T.........=........T",
		"T.ff......=.....ff.T",
		"T,,,,,....=....,,,,T",
		"T,,,,,....=....,,,,T",
		"T.........=........T",
		"TTTT......=......TTT",
		"T,,,,,,...=...,,,,,T",
		"T,,,,,,...=...,,,,,T",
		"T.........=..O.....T",
		"T..~~~~...=...~~~~.T",
		"T..~~~~...=...~~~~.T",
		"T........==........T",
		"T,,,,....==.....,,,T",
		"T,,,,....==.....,,,T",
		"T........==........T",
		"TTTTTTTTT00TTTTTTTTT"],
		"warps": {"0": ["town2", 9, 1]},
		"doors": {}, "signs": {"13,15": "SKYREACH ROAD - Crown Spire ahead. Only holders of 3 Warden Sigils may pass."},
		"enc": [[21, 18, 22, 20], [19, 18, 21, 15], [11, 19, 22, 15], [7, 19, 22, 15], [23, 19, 22, 15], [13, 19, 22, 10], [1, 20, 20, 4], [5, 20, 20, 4], [9, 20, 20, 4]],
		"npcs": [
			{"id": "gate", "x": 10, "y": 6, "dir": "D", "name": "Spire Guard", "kind": "gate", "alt": [11, 7], "look": ["c0c0d0", "4a4a6a"], "lines": ["Halt! Only explorers with all 3 Warden Sigils may climb Crown Spire."], "after": "Three sigils! The Champion awaits you at the top. Good luck!"},
			{"id": "sela", "x": 11, "y": 11, "dir": "L", "name": "Warden Sela", "kind": "warden", "sigil": 3, "sight": 1, "look": ["e0f0ff", "4ab0c0"], "team": [[19, 22], [17, 23], [20, 24], [18, 25]], "reward": 2400, "pre": "The wind carries every story to me. I am Sela, Warden of the Sky. Let's see if yours soars!", "post": "What a gale! Take the Sky Sigil. The Champion will want to meet you."},
			{"id": "r4_wren", "x": 11, "y": 13, "dir": "L", "name": "Sage Wren", "kind": "trainer", "sight": 1, "look": ["d0c0f0", "7a5ab0"], "team": [[21, 21], [7, 21]], "reward": 700, "pre": "The light and the rain are old friends. Meet them!", "post": "Balance... you have it."},
			{"id": "r4_vale", "x": 9, "y": 9, "dir": "R", "name": "Ace Vale", "kind": "trainer", "sight": 1, "look": ["f0f0f0", "202040"], "team": [[20, 22], [12, 22]], "reward": 720, "pre": "Nobody reaches the Spire without getting past me!", "post": "Fine, fine. You've earned the climb."},
			{"id": "aurex", "x": 10, "y": 2, "dir": "D", "name": "Champion Aurex", "kind": "champion", "sight": 2, "look": ["ffd24a", "b03a5a"], "team": [[24, 28], [16, 29], [6, 29], [10, 30], [22, 31]], "reward": 5000, "pre": "So you're the explorer everyone in the Wilds is talking about. I'm Aurex, Champion of Crown Spire. Give me everything you've got!", "post": "Incredible... The title of Champion is yours. The Wilds are lucky to have you."},
		]},
}
