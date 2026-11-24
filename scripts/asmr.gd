extends Node
## 자연 소리(ASMR) — 집 화면에서만.
## 집 안: 모닥불 · 밤에 밖: 풀벌레 · 내 땅에 물 블록이 있으면 밖에서 물소리.
## 크기는 Save.d["asmr"] (0 꺼짐 · 1 작게 · 2 보통 · 3 크게), 위 오른쪽 버튼으로 바꿔요. 바뀔 땐 천천히 커지고 작아져요.

const LEVELS := ["꺼짐", "작게", "보통", "크게"]
const LEVEL_DB := [-80.0, -22.0, -15.0, -9.0]
var main: Node3D
var players := {}       # 이름 → AudioStreamPlayer
var vol := {}           # 이름 → 지금 크기(0~1)
var t := 0.0
var want := {}


func setup(m: Node3D) -> void:
	main = m
	for k in ["fire", "crickets", "water"]:
		var st := load("res://assets/asmr/%s.ogg" % k) as AudioStreamOggVorbis
		if st == null:
			continue
		st.loop = true
		var p := AudioStreamPlayer.new()
		p.stream = st
		p.volume_db = -80.0
		add_child(p)
		players[k] = p
		vol[k] = 0.0
		want[k] = 0.0
	_decide()


static func level() -> int:
	return clampi(int(Save.d.get("asmr", 2)), 0, 3)


static func cycle() -> int:
	Save.d["asmr"] = (level() + 1) % 4
	Save.save()
	return level()


func _decide() -> void:
	var inside: bool = main.extra != null and main.extra.inside
	var night := not Mol.is_day()
	var water := false
	if not inside:
		for c in main.land_set:
			if str(main.floor_map.get(c, "")).contains("Water"):
				water = true
				break
	want["fire"] = 1.0 if inside else 0.0
	want["crickets"] = 1.0 if (night and not inside) else 0.0
	want["water"] = 1.0 if water else 0.0


func _process(dt: float) -> void:
	t -= dt
	if t <= 0:
		t = 0.5
		if main:
			_decide()
	var lv := level()
	for k in players:
		var target: float = want.get(k, 0.0) if lv > 0 else 0.0
		vol[k] = move_toward(vol[k], target, dt * 0.6)      # 2초쯤 걸려 바뀜
		var p: AudioStreamPlayer = players[k]
		if vol[k] <= 0.001:
			if p.playing:
				p.stop()
			continue
		if not p.playing:
			p.play(randf() * 10.0)
		p.volume_db = LEVEL_DB[lv] + linear_to_db(vol[k])
