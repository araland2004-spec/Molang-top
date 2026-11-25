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
	if muted or voices.size() >= 12:      # 동시에 12개까지 (많이 겹치면 어차피 안 들리고 계산만 무거움)
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
		# 높이·크기 변화를 샘플마다 pow 로 다시 구하지 않고, 한 번 구한 뒤 곱해 나감 (같은 소리, 계산은 훨씬 가벼움)
		var k0 := t / dur
		var f := f0 * pow(f1 / f0, k0)
		var g := vol * pow(0.001 / vol, k0) if vol > 0.001 else 0.0
		var rf := pow(f1 / f0, dt / dur)
		var rg := pow(0.001 / vol, dt / dur) if vol > 0.001 else 1.0
		var kk := 1 if kind == "square" else (2 if kind == "saw" else (3 if kind == "triangle" else 0))
		for i in n:
			if t >= dur:
				break
			ph += f * dt
			if ph >= 1.0:
				ph -= 1.0
			f *= rf
			g *= rg
			var s: float
			if kk == 0: s = sin(ph * TAU)
			elif kk == 1: s = 1.0 if ph < 0.5 else -1.0
			elif kk == 2: s = ph * 2.0 - 1.0
			else: s = 1.0 - 4.0 * absf(ph - 0.5)
			var a := s * g * 0.6
			buf[i] += Vector2(a, a)
			t += dt
		v[0] = ph
		v[1] = t
	voices = voices.filter(func(v): return v[1] < v[4])
	pb.push_buffer(buf)
