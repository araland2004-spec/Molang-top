extends SceneTree
## 스테이지 자동 플레이 봇 (밤마다 GitHub Actions 「stage-qa」가 돌림)
## godot --headless --path . --script res://tools/stage_bot.gd -- <시작 단계> <끝 단계> <판 수>
## 단계마다 「같은 숫자를 노려 던지는」 봇으로 여러 번 플레이해서 한 줄씩 출력:
## QA|단계|목표|목표값|던지기|클리어 수|판 수|평균 남은 던지기|이상(NaN·판 밖 등) 횟수

func _aim(core) -> void:
	var best = null
	var bs := -1e9
	var baim := 0.0
	var bp := 0.5
	for q in core.queue:
		for b in core.blobs:
			if b.row or b.lane or b.t != q.t:
				continue
			var d := Vector2(b.cx - q.cx, b.cy - q.cy)
			if d.y < 10:
				continue
			var sc: float = b.t * 10 - d.length() * 0.02
			if sc > bs:
				bs = sc; best = q; baim = atan2(d.x, d.y); bp = clampf(0.25 + d.length() / 700.0, 0.25, 0.8)
	if best == null:
		best = core.queue[randi() % core.queue.size()]
		baim = randf_range(-0.5, 0.5)
		bp = randf_range(0.3, 0.7)
	core.sel = best; core.aim = baim; core.pull = bp
	core.release(true)


func _bad(core) -> bool:
	for b in core.blobs:
		if not (is_finite(b.cx) and is_finite(b.cy)) or b.cx < -60 or b.cx > core.W + 60 or b.cy < -60 or b.cy > core.H + 60:
			return true
	return false


func _play(core, idx: int) -> Array:
	core.mode = "stage"
	core.stage_idx = idx
	core.new_game()
	var res := {"kind": "", "bad": 0}
	var cb := func(k, _r): res["kind"] = k
	core.finished.connect(cb)
	for f in 60:
		core.sim_step(1.0 / 60.0)
	var guard := 0
	while res["kind"] == "" and guard < 500:
		guard += 1
		for f in 50:
			core.sim_step(1.0 / 60.0)
			if res["kind"] != "":
				break
		if _bad(core):
			res["bad"] += 1
			break
		if res["kind"] != "" or core.queue.is_empty() or not core.can_throw():
			continue
		_aim(core)
	if res["kind"] == "":
		for f in 300:
			core.sim_step(1.0 / 60.0)
			if res["kind"] != "":
				break
	core.finished.disconnect(cb)
	return [res["kind"] == "clear", core.throws_left, res["bad"]]


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var from := int(a[0]) if a.size() > 0 else 1
	var to := int(a[1]) if a.size() > 1 else 9999
	var runs := int(a[2]) if a.size() > 2 else 3
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/mollang_data.json"))
	var core = load("res://scripts/game_core.gd").new()
	root.add_child(core)
	core.stages = data["stages"]
	to = mini(to, core.stages.size())
	seed(20261123 + from)
	for n in range(from, to + 1):
		var wins := 0
		var left := 0
		var bad := 0
		for r in runs:
			var o := _play(core, n - 1)
			if o[0]:
				wins += 1
				left += int(o[1])
			bad += int(o[2])
		var st: Dictionary = core.stages[n - 1]
		print("QA|%d|%s|%s|%d|%d|%d|%.1f|%d" % [n, st["goal"], str(st.get("t", st.get("v", ""))), int(st["throws"]), wins, runs, (float(left) / wins) if wins else 0.0, bad])
	quit()
