extends Node
## 작은 신스: 웹 버전 tone(f0, f1, dur, vol, type) 과 같은 효과음.

const RATE := 22050.0
var player: AudioStreamPlayer
var pb: AudioStreamGeneratorPlayback
var voices: Array = []    # [phase, t, f0, f1, dur, vol, kind]
var muted := false


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.12
	player = AudioStreamPlayer.new()
	player.stream = gen
	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM   # 웹에서도 실시간 합성
	add_child(player)
	player.play()
	pb = player.get_stream_playback()


func tone(f0: float, f1: float, dur: float, vol: float, kind := "sine") -> void:
	if muted or voices.size() > 24:
		return
	voices.append([0.0, 0.0, f0, f1, dur, vol, kind])


func _process(_dt: float) -> void:
	if pb == null:
		return
	var n := pb.get_frames_available()
	if n <= 0:
		return
	var buf := PackedVector2Array()
	buf.resize(n)
	var dt := 1.0 / RATE
	for v in voices:
		var ph: float = v[0]
		var t: float = v[1]
		var f0: float = v[2]
		var f1: float = maxf(v[3], 1.0)
		var dur: float = v[4]
		var vol: float = v[5]
		var kind: String = v[6]
		for i in n:
			if t >= dur:
				break
			var k := t / dur
			var f := f0 * pow(f1 / f0, k)
			var g := vol * pow(0.001 / vol, k) if vol > 0.001 else 0.0
			ph = fmod(ph + f * dt, 1.0)
			var s: float
			match kind:
				"square": s = 1.0 if ph < 0.5 else -1.0
				"saw": s = ph * 2.0 - 1.0
				"triangle": s = 1.0 - 4.0 * absf(ph - 0.5)
				_: s = sin(ph * TAU)
			var a := s * g * 0.6
			buf[i] += Vector2(a, a)
			t += dt
		v[0] = ph
		v[1] = t
	voices = voices.filter(func(v): return v[1] < v[4])
	pb.push_buffer(buf)
