extends Node
## All sounds are synthesized at startup (no audio files, tiny build).

const RATE := 22050
const POOL := 6

var roll_stream: AudioStreamWAV
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_streams["hit"] = _make(_hit())
	_streams["pocket"] = _make(_chime([1046.5, 1568.0], 0.09, 0.5))
	_streams["win"] = _make(_chime([523.25, 659.25, 783.99, 1046.5, 1318.5], 0.11, 0.9))
	_streams["fall"] = _make(_fall())
	_streams["click"] = _make(_click())
	roll_stream = _make(_roll(), true)
	apply_settings()


func apply_settings() -> void:
	AudioServer.set_bus_mute(0, not Settings.sound)


func play(sound: String, volume := 1.0, pitch := 1.0) -> void:
	if not Settings.sound or not _streams.has(sound):
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = _streams[sound]
	p.volume_db = linear_to_db(clampf(volume, 0.0001, 1.0))
	p.pitch_scale = pitch
	p.play()


# --- synthesis --------------------------------------------------------------

func _make(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


## Wooden knock: low sine thump + short noise click.
func _hit() -> PackedFloat32Array:
	var n := int(RATE * 0.09)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var thump := sin(TAU * (210.0 - 600.0 * t) * t) * exp(-t * 45.0)
		var click := randf_range(-1, 1) * exp(-t * 400.0) * 0.5
		s[i] = (thump + click) * 0.8
	return s


## Bell-like notes, one after another.
func _chime(freqs: Array, step: float, length: float) -> PackedFloat32Array:
	var n := int(RATE * (length + step * freqs.size()))
	var s := PackedFloat32Array()
	s.resize(n)
	for k in freqs.size():
		var f: float = freqs[k]
		var start := int(RATE * step * k)
		for i in range(start, n):
			var t := float(i - start) / RATE
			var env := exp(-t * 5.0) * minf(t * 200.0, 1.0)
			s[i] += (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t) + 0.12 * sin(TAU * f * 3.0 * t)) * env * 0.28
	return s


func _fall() -> PackedFloat32Array:
	var n := int(RATE * 0.45)
	var s := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += TAU * (600.0 - 900.0 * t) / RATE
		s[i] = sin(phase) * exp(-t * 4.0) * 0.35
	return s


func _click() -> PackedFloat32Array:
	var n := int(RATE * 0.04)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		s[i] = sin(TAU * 900.0 * t) * exp(-t * 120.0) * 0.4
	return s


## Low rumble loop for rolling (brown noise, faded at the seam).
func _roll() -> PackedFloat32Array:
	var n := RATE
	var s := PackedFloat32Array()
	s.resize(n)
	var v := 0.0
	var lp := 0.0
	for i in n:
		v = clampf(v + randf_range(-1, 1) * 0.08, -1.0, 1.0) * 0.995
		lp += (v - lp) * 0.2
		s[i] = lp * 1.6
	# Crossfade the end into the start so the loop doesn't click.
	var fade := int(RATE * 0.05)
	for i in fade:
		var a := float(i) / fade
		s[n - fade + i] = s[n - fade + i] * (1.0 - a) + s[i] * a
	return s
