extends Node
## Pocket Wilds - every sound is synthesized at runtime (no audio files). Autoloaded as "Sfx".

const RATE = 22050
const MRATE = 16000
var players: Array = []
var cache: Dictionary = {}
var music: AudioStreamPlayer
var cur_music: String = ""
var next_player: int = 0

## Original melodies (MIDI note numbers, -1 = rest), one entry per step.
const SONGS = {
	"title": {"step": 0.22, "lead": [72, -1, 79, 76, 77, -1, 74, -1, 72, 74, 76, 79, 81, -1, 79, -1, 77, 76, 74, -1, 72, -1, 74, 76, 74, -1, 71, -1, 72, -1, -1, -1],
		"bass": [48, 45, 41, 43, 48, 45, 43, 43]},
	"town": {"step": 0.2, "lead": [72, -1, 76, 79, 77, 76, 74, -1, 72, 74, 76, 72, 74, -1, 67, -1, 69, 72, 74, 77, 76, 74, 72, -1, 71, 72, 74, 76, 72, -1, -1, -1],
		"bass": [48, 48, 53, 53, 45, 45, 43, 43]},
	"route": {"step": 0.17, "lead": [69, 72, 76, -1, 74, 72, 71, -1, 69, 71, 72, 74, 76, -1, 79, -1, 77, 76, 74, 72, 74, -1, 71, -1, 72, 71, 69, 67, 69, -1, -1, -1],
		"bass": [45, 45, 41, 41, 43, 43, 40, 40]},
	"cave": {"step": 0.26, "lead": [57, -1, 60, -1, 64, -1, 63, -1, 60, -1, 57, -1, 55, -1, -1, -1, 57, -1, 60, -1, 65, -1, 64, -1, 62, -1, 60, -1, 59, -1, -1, -1],
		"bass": [33, 33, 36, 36, 31, 31, 28, 28]},
	"battle": {"step": 0.13, "lead": [76, 76, 79, 76, 81, 79, 76, 74, 76, 76, 79, 76, 83, 81, 79, -1, 77, 77, 81, 77, 84, 81, 77, 76, 74, 76, 77, 79, 76, -1, 74, -1],
		"bass": [45, 45, 45, 45, 41, 41, 43, 43]},
	"boss": {"step": 0.12, "lead": [69, 72, 76, 72, 69, 72, 77, 76, 74, 71, 67, 71, 74, 76, 77, 79, 81, 79, 77, 76, 77, 76, 74, 72, 71, 72, 74, 76, 71, -1, 68, -1],
		"bass": [45, 45, 41, 41, 43, 43, 40, 40]},
	"victory": {"step": 0.18, "lead": [72, 76, 79, 84, -1, 79, 84, -1, 81, 77, 81, 86, -1, 84, -1, -1, 79, 83, 86, 91, -1, 86, 88, -1, 84, -1, 79, -1, 84, -1, -1, -1],
		"bass": [48, 48, 41, 41, 43, 43, 48, 48]},
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 6:
		var p = AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		players.append(p)
	music = AudioStreamPlayer.new()
	music.volume_db = -13.0
	add_child(music)

static func _hz(n: int) -> float:
	return 440.0 * pow(2.0, (n - 69) / 12.0)

func _tone(out: PackedFloat32Array, f0: float, f1: float, dur: float, wave: String, vol: float) -> void:
	var n = int(dur * RATE)
	var ph = 0.0
	for i in n:
		var t = float(i) / n
		ph += lerpf(f0, f1, t) / RATE
		var x = fmod(ph, 1.0)
		var v = 0.0
		if wave == "sq":
			v = 1.0 if x < 0.5 else -1.0
		elif wave == "tri":
			v = absf(x * 4.0 - 2.0) - 1.0
		else:
			v = randf() * 2.0 - 1.0
		var env = minf(1.0, t * 40.0) * (1.0 - t)
		out.append(v * vol * env)

func _make(name: String) -> PackedFloat32Array:
	var o = PackedFloat32Array()
	match name:
		"blip": _tone(o, 880, 880, 0.045, "sq", 0.18)
		"select": _tone(o, 660, 990, 0.07, "sq", 0.2)
		"back": _tone(o, 520, 330, 0.07, "sq", 0.18)
		"bump": _tone(o, 140, 90, 0.07, "tri", 0.5)
		"hit":
			_tone(o, 0, 0, 0.06, "noise", 0.45)
			_tone(o, 240, 70, 0.12, "tri", 0.6)
		"super":
			_tone(o, 0, 0, 0.05, "noise", 0.5)
			_tone(o, 300, 900, 0.08, "sq", 0.25)
			_tone(o, 900, 120, 0.14, "tri", 0.6)
		"weak": _tone(o, 200, 120, 0.12, "tri", 0.45)
		"faint": _tone(o, 700, 90, 0.55, "tri", 0.5)
		"buff":
			for n in [64, 68, 71, 76]:
				_tone(o, _hz(n), _hz(n), 0.06, "sq", 0.15)
		"debuff":
			for n in [76, 71, 68, 64]:
				_tone(o, _hz(n), _hz(n), 0.06, "sq", 0.15)
		"throw": _tone(o, 300, 1200, 0.22, "tri", 0.4)
		"shake": _tone(o, 420, 300, 0.09, "tri", 0.45)
		"catch":
			for n in [72, 76, 79, 84, 79, 84]:
				_tone(o, _hz(n), _hz(n), 0.09, "sq", 0.17)
		"breakout":
			_tone(o, 0, 0, 0.1, "noise", 0.4)
			_tone(o, 600, 200, 0.15, "sq", 0.2)
		"heal":
			for n in [72, 76, 79, 84, 88]:
				_tone(o, _hz(n), _hz(n), 0.1, "tri", 0.4)
		"level":
			for n in [67, 72, 76, 79, 84]:
				_tone(o, _hz(n), _hz(n), 0.08, "sq", 0.17)
		"encounter":
			for n in [60, 63, 66, 69, 72, 75, 78, 81]:
				_tone(o, _hz(n), _hz(n), 0.04, "sq", 0.18)
		"door": _tone(o, 200, 400, 0.12, "tri", 0.4)
		"coin":
			_tone(o, 988, 988, 0.06, "sq", 0.16)
			_tone(o, 1319, 1319, 0.14, "sq", 0.16)
		"evolve":
			for n in [60, 64, 67, 72, 76, 79, 84, 88, 91, 96]:
				_tone(o, _hz(n), _hz(n), 0.07, "tri", 0.45)
		"exclaim": _tone(o, 1200, 1500, 0.1, "sq", 0.18)
		_: _tone(o, 440, 440, 0.05, "sq", 0.15)
	return o

func _wav(samples: PackedFloat32Array, rate: int, loop: bool) -> AudioStreamWAV:
	var w = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	var b = PackedByteArray()
	b.resize(samples.size() * 2)
	for i in samples.size():
		b.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 30000.0))
	w.data = b
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w

func play(name: String) -> void:
	if not G.sound_on:
		return
	if not cache.has(name):
		cache[name] = _wav(_make(name), RATE, false)
	var p: AudioStreamPlayer = players[next_player]
	next_player = (next_player + 1) % players.size()
	p.stream = cache[name]
	p.play()

func _song(name: String) -> AudioStreamWAV:
	var s = SONGS[name]
	var step: float = s["step"]
	var lead: Array = s["lead"]
	var bass: Array = s["bass"]
	var ns = int(step * MRATE)
	var total = ns * lead.size()
	var o = PackedFloat32Array()
	o.resize(total)
	var ph = 0.0
	var pb = 0.0
	for k in lead.size():
		var n: int = lead[k]
		var fb = _hz(bass[k * bass.size() / lead.size()])
		var fl = _hz(n) if n >= 0 else 0.0
		for i in ns:
			var t = float(i) / ns
			var v = 0.0
			if n >= 0:
				ph += fl / MRATE
				v += (absf(fmod(ph, 1.0) * 4.0 - 2.0) - 1.0) * 0.34 * (1.0 - t * 0.7)
			pb += fb / MRATE
			v += (0.16 if fmod(pb, 1.0) < 0.5 else -0.16) * (1.0 - t * 0.5)
			if k % 2 == 0 and i < ns / 6:
				v += (randf() - 0.5) * 0.12 * (1.0 - i / (ns / 6.0))
			o[k * ns + i] = v
	return _wav(o, MRATE, true)

func play_music(name: String) -> void:
	if name == cur_music:
		return
	cur_music = name
	if name == "" or not SONGS.has(name):
		music.stop()
		return
	var key = "m_" + name
	if not cache.has(key):
		cache[key] = _song(name)
	music.stream = cache[key]
	music.play()
